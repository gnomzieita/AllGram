//  Converted to Swift 5.4 by Swiftify v5.4.25812 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import MatrixSDK

typealias MX3PIDMedium = String

enum MXK3PIDAuthState : Int {
    case unknown
    case tokenRequested
    case tokenReceived
    case tokenSubmitted
    case authenticated
}


class MXK3PID {
    private var mxRestClient: MXRestClient?
    private var currentRequest: MXHTTPOperation?

    /// The type of the third party media.
    private(set) var medium: MX3PIDMedium?
    /// The third party media (email address, msisdn,...).
    private(set) var address: String?
    /// The current client secret key used during third party validation.
    private(set) var clientSecret: String?
    /// The current session identifier during third party validation.
    private(set) var sid: String?
    /// The id of the user on Matrix.
    /// nil if unknown or not yet resolved.
    var userId: String?
    private(set) var validationState: MXK3PIDAuthState!
    private var sendAttempt = 0
    private var identityService: MXIdentityService?
    private var submitUrl: String?

    /// Initialise the instance with a 3PID.
    /// - Parameters:
    ///   - medium: the medium.
    ///   - address: the id of the contact on this medium.
    /// - Returns: the new instance.
    init(medium: String?, andAddress address: String?) {
        self.medium = medium
        self.address = address
        clientSecret = MXTools.generateSecret()
    }

    /// Cancel the current request, and reset parameters
    func cancelCurrentRequest() {
        validationState = .unknown

        currentRequest?.cancel()
        currentRequest = nil
        mxRestClient = nil
        identityService = nil

        sendAttempt = 1
        sid = nil
        // Removed potential linked userId
        userId = nil
    }

    /// Start the validation process 
    /// The identity server will send a validation token by email or sms.
    /// In case of email, the end user must click on the link in the received email
    /// to validate their email address in order to be able to call add3PIDToUser successfully.
    /// In case of phone number, the end user must send back the sms token
    /// in order to be able to call add3PIDToUser successfully.
    /// - Parameters:
    ///   - restClient: used to make matrix API requests during validation process.
    ///   - isDuringRegistration:  tell whether this request occurs during a registration flow.
    ///   - nextLink: the link the validation page will automatically open. Can be nil.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func requestValidationToken(
        withMatrixRestClient restClient: MXRestClient?,
        isDuringRegistration: Bool,
        nextLink: String?,
        success: @escaping () -> Void,
        failure: @escaping (_ error: Error?) -> Void
    ) {
        // Sanity Check
        if validationState != .tokenRequested && restClient != nil {
            // Reset if the current state is different than "Unknown"
            if validationState != .unknown {
                cancelCurrentRequest()
            }

            let identityServer = restClient?.identityServer
            if let identityServer = identityServer {
                // Use same identity server as REST client for validation token submission
                identityService = MXIdentityService(__identityServer: identityServer, accessToken: nil, andHomeserverRestClient: restClient!)
            }

            if medium?.isEqual(kMX3PIDMediumEmail) != nil {
                validationState = .tokenRequested
                mxRestClient = restClient

                currentRequest = mxRestClient?.requestToken(forEmail: address, isDuringRegistration: isDuringRegistration, clientSecret: clientSecret, sendAttempt: UInt(sendAttempt), nextLink: nextLink, success: { [self] sid in

                    validationState = .tokenReceived
                    currentRequest = nil
                    self.sid = sid

                    success()

                }, failure: { [unowned self] error in

                    // Return in unknown state
                    validationState = .unknown
                    currentRequest = nil
                    // Increment attempt counter
                    sendAttempt += 1

                    failure(error)

                })
            } else if medium?.isEqual(kMX3PIDMediumMSISDN) != nil {
                validationState = .tokenRequested
                mxRestClient = restClient

                let phoneNumber = "+\(address ?? "")"

                currentRequest = mxRestClient?.requestToken(forPhoneNumber: phoneNumber, isDuringRegistration: isDuringRegistration, countryCode: nil, clientSecret: clientSecret, sendAttempt: UInt(sendAttempt), nextLink: nextLink, success: { [self] sid, msisdn, submitUrl in

                    validationState = .tokenReceived
                    currentRequest = nil
                    self.sid = sid
                    self.submitUrl = submitUrl

                    success()

                }, failure: { [self] error in

                    // Return in unknown state
                    validationState = .unknown
                    currentRequest = nil
                    // Increment attempt counter
                    sendAttempt += 1

                    failure(error)

                })
            }
        }
    }

    /// Submit the received validation token.
    /// - Parameters:
    ///   - token: the validation token.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func submitValidationToken(
        _ token: String?,
        success: @escaping () -> Void,
        failure: @escaping (_ error: Error?) -> Void
    ) {
        // Sanity Check
        if validationState == .tokenReceived {
            if let submitUrl = submitUrl {
                validationState = .tokenSubmitted

                currentRequest = submitMsisdnTokenOtherUrl(submitUrl, token: token, medium: medium, clientSecret: clientSecret, sid: sid, success: { [self] in

                    validationState = .authenticated
                    currentRequest = nil

                    success()

                }, failure: { [self] error in

                    // Return in previous state
                    validationState = .tokenReceived
                    currentRequest = nil

                    failure(error)

                })
            } else if let identityService = identityService {
                validationState = .tokenSubmitted

                currentRequest = identityService.submit3PIDValidationToken(token!, medium: medium!, clientSecret: clientSecret!, sid: sid!) { [unowned self] response in
                    switch response {
                    case .success():
                        validationState = .authenticated
                        currentRequest = nil

                        success()
                    case .failure(let error):
                        // Return in previous state
                        validationState = .tokenReceived
                        currentRequest = nil

                        failure(error)
                    }
                }
            } else {
                failure(nil)
            }
        } else {
            failure(nil)
        }
    }

    func submitMsisdnTokenOtherUrl(
        _ url: String?,
        token: String?,
        medium: String?,
        clientSecret: String?,
        sid: String?,
        success: @escaping () -> Void,
        failure: @escaping (Error?) -> Void
    ) -> MXHTTPOperation? {
        let parameters = [
            "sid": sid ?? "",
            "client_secret": clientSecret ?? "",
            "token": token ?? ""
        ]

        let httpClient = MXHTTPClient(baseURL: nil, andOnUnrecognizedCertificateBlock: nil)
        return httpClient!.request(
            withMethod: "POST",
            path: url,
            parameters: parameters,
            success: { JSONResponse in
                success()
            },
            failure: failure)
    }

    /// Link a 3rd party id to the user.
    /// - Parameters:
    ///   - bind: whether the homeserver should also bind this third party identifier
    /// to the account's Matrix ID with the identity server.
    ///   - success: A block object called when the operation succeeds. It provides the raw
    /// server response.
    ///   - failure: A block object called when the operation fails.
    func add3PID(
        toUser bind: Bool,
        success: @escaping () -> Void,
        failure: @escaping (_ error: Error?) -> Void
    ) {
        if medium?.isEqual(kMX3PIDMediumEmail) != nil || medium?.isEqual(kMX3PIDMediumMSISDN) != nil {
            currentRequest = mxRestClient?.addThirdPartyIdentifier (sid!, clientSecret: clientSecret!, bind: bind) { [unowned self] response in
                switch response {
                case .success:
                    userId = mxRestClient?.credentials.userId
                    currentRequest = nil
                    
                    success()
                case .failure(let error):
                    currentRequest = nil

                    failure(error)
                }
            }
            return
        }

        // Here the validation process failed
        failure(nil)
    }
}
