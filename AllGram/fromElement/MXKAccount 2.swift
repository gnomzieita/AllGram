//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

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

/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

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

import AFNetworking
import MatrixSDK

/// Posted when account user information (display name, picture, presence) has been updated.
/// The notification object is the matrix user id of the account./// Posted when the activity of the Apple Push Notification Service has been changed.
/// The notification object is the matrix user id of the account./// Posted when the activity of the Push notification based on PushKit has been changed.
/// The notification object is the matrix user id of the account./// MXKAccount error domain/// Block called when a certificate change is observed during authentication challenge from a server.
/// - Parameters:
///   - mxAccount: the account concerned by this certificate change.
///   - certificate: the server certificate to evaluate.
/// - Returns: YES to accept/trust this certificate, NO to cancel/ignore it.
typealias MXKAccountOnCertificateChange = (MXKAccount?, Data?) -> Bool
let kMXKAccountUserInfoDidChangeNotification = "kMXKAccountUserInfoDidChangeNotification"
let kMXKAccountAPNSActivityDidChangeNotification = "kMXKAccountAPNSActivityDidChangeNotification"
let kMXKAccountPushKitActivityDidChangeNotification = "kMXKAccountPushKitActivityDidChangeNotification"
let kMXKAccountErrorDomain = "kMXKAccountErrorDomain"
private var _onCertificateChangeBlock: MXKAccountOnCertificateChange?
/// HTTP status codes for error cases on initial sync requests, for which errors will not be propagated to the client.
private var initialSyncSilentErrorsHTTPStatusCodes: [NSNumber]?

/// `MXKAccount` object contains the credentials of a logged matrix user. It is used to handle matrix
/// session and presence for this user.
class MXKAccount: NSObject, NSCoding {
    // We will notify user only once on session failure
    private var notifyOpenSessionFailure = false
    // The timer used to postpone server sync on failure
    private var initialServerSyncTimer: Timer?
    // Reachability observer
    private var reachabilityObserver: Any?
    // Session state observer
    private var sessionStateObserver: Any?
    // Handle user's settings change
    private var userUpdateListener: Any?
    // Used for logging application start up
    private var openSessionStartDate: Date?
    // Event notifications listener
    private var notificationCenterListener: Any?
    // Internal list of ignored rooms
    private var ignoredRooms: [AnyHashable]?
    // If a server sync is in progress, the pause is delayed at the end of sync (except if resume is called).
    private var isPauseRequested = false
    // Background sync management
    private var backgroundSyncDone: MXOnBackgroundSyncDone?
    private var backgroundSyncFails: MXOnBackgroundSyncFail?
    private var backgroundSyncTimer: Timer?
    // Observe UIApplicationSignificantTimeChangeNotification to refresh MXRoomSummaries on time formatting change.
    private var UIApplicationSignificantTimeChangeNotificationObserver: Any?
    // Observe NSCurrentLocaleDidChangeNotification to refresh MXRoomSummaries on time formatting change.
    private var NSCurrentLocaleDidChangeNotificationObserver: Any?

    /// The account's credentials: homeserver, access token, user id.
    private(set) var mxCredentials: MXCredentials?
    /// The identity server URL.

    private var _identityServerURL: String?
    var identityServerURL: String? {
        get {
            _identityServerURL
        }
        set(identityServerURL) {
            if (identityServerURL?.count ?? 0) != 0 {
                _identityServerURL = identityServerURL
                mxCredentials?.identityServer = identityServerURL

                // Update services used in MXSession
                mxSession?.setIdentityServer(mxCredentials?.identityServer, andAccessToken: mxCredentials?.identityServerAccessToken)
            } else {
                _identityServerURL = nil
                mxSession?.setIdentityServer(nil, andAccessToken: nil)
            }

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()
        }
    }
    /// The antivirus server URL, if any (nil by default).
    /// Set a non-null url to configure the antivirus scanner use.

    private var _antivirusServerURL: String?
    var antivirusServerURL: String? {
        get {
            _antivirusServerURL
        }
        set(antivirusServerURL) {
            _antivirusServerURL = antivirusServerURL
            // Update the current session if any
            mxSession?.antivirusServerURL = antivirusServerURL

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()
        }
    }
    /// The Push Gateway URL used to send event notifications to (nil by default).
    /// This URL should be over HTTPS and never over HTTP.

    private var _pushGatewayURL: String?
    var pushGatewayURL: String? {
        get {
            _pushGatewayURL
        }
        set(pushGatewayURL) {
            _pushGatewayURL = (pushGatewayURL?.count ?? 0) != 0 ? pushGatewayURL : nil

            MXLogDebug("[MXKAccount][Push] setPushGatewayURL: %@", _pushGatewayURL)

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()
        }
    }
    /// The matrix REST client used to make matrix API requests.
    private(set) var mxRestClient: MXRestClient?
    /// The matrix session opened with the account (nil by default).
    private(set) var mxSession: MXSession?
    /// The account user's display name (nil by default, available if matrix session `mxSession` is opened).
    /// The notification `kMXKAccountUserInfoDidChangeNotification` is posted in case of change of this property.

    var userDisplayName: String? {
        if let mxSession = mxSession {
            return mxSession.myUser.displayname
        }
        return nil
    }
    /// The account user's avatar url (nil by default, available if matrix session `mxSession` is opened).
    /// The notification `kMXKAccountUserInfoDidChangeNotification` is posted in case of change of this property.

    var userAvatarUrl: String? {
        if let mxSession = mxSession {
            return mxSession.myUser.avatarUrl
        }
        return nil
    }
    /// The account display name based on user id and user displayname (if any).

    var fullDisplayName: String? {
        if (userDisplayName?.count ?? 0) != 0 {
            if let userId = mxCredentials?.userId {
                return "\(userDisplayName ?? "") (\(userId))"
            }
            return nil
        } else {
            return mxCredentials?.userId
        }
    }
    /// The 3PIDs linked to this account.
    /// [self load3PIDs] must be called to update the property.

    private var _threePIDs: [MXThirdPartyIdentifier]?
    var threePIDs: [MXThirdPartyIdentifier]? {
        return _threePIDs
    }
    /// The email addresses linked to this account.
    /// This is a subset of self.threePIDs.

    var linkedEmails: [String]? {
        var linkedEmails: [String]? = []

        for threePID in threePIDs ?? [] {
            if threePID.medium == kMX3PIDMediumEmail {
                linkedEmails?.append(threePID.address)
            }
        }

        return linkedEmails
    }
    /// The phone numbers linked to this account.
    /// This is a subset of self.threePIDs.

    var linkedPhoneNumbers: [String]? {
        var linkedPhoneNumbers: [String]? = []

        for threePID in threePIDs ?? [] {
            if threePID.medium == kMX3PIDMediumMSISDN {
                linkedPhoneNumbers?.append(threePID.address)
            }
        }

        return linkedPhoneNumbers
    }
    /// The account user's device.
    /// [self loadDeviceInformation] must be called to update the property.
    private(set) var device: MXDevice?
    /// The account user's presence (`MXPresenceUnknown` by default, available if matrix session `mxSession` is opened).
    /// The notification `kMXKAccountUserInfoDidChangeNotification` is posted in case of change of this property.
    private(set) var userPresence: MXPresence?
    /// The account user's tint color: a unique color fixed by the user id. This tint color may be used to highlight
    /// rooms which belong to this account's user.

    private var _userTintColor: UIColor?
    var userTintColor: UIColor? {
        if _userTintColor == nil {
            _userTintColor = MXKTools.color(withRGBValue: mxCredentials?.userId.hash())
        }

        return _userTintColor
    }
    /// The Apple Push Notification Service activity for this account. YES when APNS is turned on (locally available and synced with server).

    var pushNotificationServiceIsActive: Bool {
        let pushNotificationServiceIsActive = MXKAccountManager.shared()?.isAPNSAvailable && hasPusherForPushNotifications && mxSession != nil
        MXLogDebug("[MXKAccount][Push] pushNotificationServiceIsActive: %@", NSNumber(value: pushNotificationServiceIsActive))

        return pushNotificationServiceIsActive
    }
    /// Transient information storage.

    private var _others: [String : NSCoding?]?
    var others: [String : NSCoding?]? {
        if _others == nil {
            _others = [:]
        }

        return _others
    }
    /// Flag to indicate that an APNS pusher has been set on the homeserver for this device.
    private(set) var hasPusherForPushNotifications = false
    /// The Push notification activity (based on PushKit) for this account.
    /// YES when Push is turned on (locally available and enabled homeserver side).

    var isPushKitNotificationActive: Bool {
        let isPushKitNotificationActive = MXKAccountManager.shared()?.isPushAvailable && hasPusherForPushKitNotifications && mxSession != nil
        MXLogDebug("[MXKAccount][Push] isPushKitNotificationActive: %@", NSNumber(value: isPushKitNotificationActive))

        return isPushKitNotificationActive
    }
    /// Flag to indicate that a PushKit pusher has been set on the homeserver for this device.
    private(set) var hasPusherForPushKitNotifications = false
    /// Enable In-App notifications based on Remote notifications rules.
    /// NO by default.

    private var _enableInAppNotifications = false
    var enableInAppNotifications: Bool {
        get {
            _enableInAppNotifications
        }
        set(enableInAppNotifications) {
            MXLogDebug("[MXKAccount] setEnableInAppNotifications: %@", NSNumber(value: enableInAppNotifications))

            _enableInAppNotifications = enableInAppNotifications

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()
        }
    }
    /// Disable the account without logging out (NO by default).
    /// A matrix session is automatically opened for the account when this property is toggled from YES to NO.
    /// The session is closed when this property is set to YES.

    private var _disabled = false
    var disabled: Bool {
        get {
            _disabled
        }
        set(disabled) {
            if _disabled != disabled {
                _disabled = disabled

                if _disabled {
                    deletePusher()
                    enablePushKitNotifications(false, success: { _ in }, failure: { _ in })

                    // Close session (keep the storage).
                    closeSession(false)
                } else if mxSession == nil {
                    // Open a new matrix session
                    weak var store: MXStore? = MXKAccountManager.shared()?.storeClass?.init() as? MXStore

                    openSession(with: store)
                }

                // Archive updated field
                MXKAccountManager.shared()?.saveAccounts()
            }
        }
    }
    /// Manage the online presence event.
    /// The presence event must not be sent if the application is launched by a push notification.
    var hideUserPresence = false
    /// Flag indicating if the end user has been warned about encryption and its limitations.

    private var _warnedAboutEncryption = false
    var warnedAboutEncryption: Bool {
        get {
            _warnedAboutEncryption
        }
        set(warnedAboutEncryption) {
            _warnedAboutEncryption = warnedAboutEncryption

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()
        }
    }
    /// Flag indicating whether to show decrypted content in notifications.
    /// NO by default

    private var _showDecryptedContentInNotifications = false
    var showDecryptedContentInNotifications: Bool {
        get {
            _showDecryptedContentInNotifications
        }
        set(showDecryptedContentInNotifications) {
            _showDecryptedContentInNotifications = showDecryptedContentInNotifications

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()
        }
    }
    // MARK: - Soft logout

    /// Flag to indicate if the account has been logged out by the homeserver admin.
    private(set) var isSoftLogout = false
    private var backgroundTask: MXBackgroundTask?
    private var backgroundSyncBgTask: MXBackgroundTask?

    override class func load() {
        // TODO: [Swiftify] ensure that the code below is executed only once (`dispatch_once()` is deprecated)
        {
            initialSyncSilentErrorsHTTPStatusCodes = [
                NSNumber(value: 504),
                NSNumber(value: 522),
                NSNumber(value: 524),
                NSNumber(value: 599)
            ]
        }
    }

    /// Register the MXKAccountOnCertificateChange block that will be used to handle certificate change during account use.
    /// This block is nil by default, any new certificate is ignored/untrusted (this will abort the connection to the server).
    /// - Parameter onCertificateChangeBlock: the block that will be used to handle certificate change.
    class func register(onCertificateChangeBlock: MXKAccountOnCertificateChange) {
        _onCertificateChangeBlock = onCertificateChangeBlock
    }

    /// Get the color code related to a specific presence.
    /// - Parameter presence: a user presence
    /// - Returns: color defined for the provided presence (nil if no color is defined).
    class func presenceColor(_ presence: MXPresence) -> UIColor? {
        switch presence {
        case MXPresenceOnline:
            return MXKAppSettings.standard().presenceColorForOnlineUser()
        case MXPresenceUnavailable:
            return MXKAppSettings.standard().presenceColorForUnavailableUser()
        case MXPresenceOffline:
            return MXKAppSettings.standard().presenceColorForOfflineUser()
        case MXPresenceUnknown:
            fallthrough
        default:
            return nil
        }
    }

    /// Init `MXKAccount` instance with credentials. No matrix session is opened by default.
    /// - Parameter credentials: user's credentials
    init(credentials: MXCredentials?) {
        super.init()
            notifyOpenSessionFailure = true

            // Report credentials and alloc REST client.
            mxCredentials = credentials
            prepareRESTClient()

            userPresence = MXPresenceUnknown

            // Refresh device information
            loadDeviceInformation({ _ in }, failure: { _ in })

            registerDataDidChangeIdentityServerNotification()
            registerIdentityServiceDidChangeAccessTokenNotification()
    }

    deinit {
        closeSession(false)
        mxSession = nil

        mxRestClient?.close()
        mxRestClient = nil
    }

    // MARK: - NSCoding

    required init?(coder: NSCoder) {
        super.init()

        notifyOpenSessionFailure = true

        let homeServerURL = coder.decodeObject(forKey: "homeserverurl") as? String
        let userId = coder.decodeObject(forKey: "userid") as? String
        let accessToken = coder.decodeObject(forKey: "accesstoken") as? String
        identityServerURL = coder.decodeObject(forKey: "identityserverurl") as? String
        let identityServerAccessToken = coder.decodeObject(forKey: "identityserveraccesstoken") as? String

        mxCredentials = MXCredentials(
            homeServer: homeServerURL,
            userId: userId,
            accessToken: accessToken)

        mxCredentials?.identityServer = identityServerURL
        mxCredentials?.identityServerAccessToken = identityServerAccessToken
        mxCredentials?.deviceId = coder.decodeObject(forKey: "deviceId")
        mxCredentials?.allowedCertificate = coder.decodeObject(forKey: "allowedCertificate")

        prepareRESTClient()

        registerDataDidChangeIdentityServerNotification()
        registerIdentityServiceDidChangeAccessTokenNotification()

        if coder.decodeObject(forKey: "threePIDs") != nil {
            threePIDs = coder.decodeObject(forKey: "threePIDs") as? [MXThirdPartyIdentifier]
        }

        if coder.decodeObject(forKey: "device") != nil {
            device = coder.decodeObject(forKey: "device") as? MXDevice
        }

        userPresence = MXPresenceUnknown

        if coder.decodeObject(forKey: "antivirusserverurl") != nil {
            antivirusServerURL = coder.decodeObject(forKey: "antivirusserverurl") as? String
        }

        if coder.decodeObject(forKey: "pushgatewayurl") != nil {
            pushGatewayURL = coder.decodeObject(forKey: "pushgatewayurl") as? String
        }

        hasPusherForPushNotifications = coder.decodeBool(forKey: "_enablePushNotifications")
        hasPusherForPushKitNotifications = coder.decodeBool(forKey: "enablePushKitNotifications")
        enableInAppNotifications = coder.decodeBool(forKey: "enableInAppNotifications")

        disabled = coder.decodeBool(forKey: "disabled")
        isSoftLogout = coder.decodeBool(forKey: "isSoftLogout")

        warnedAboutEncryption = coder.decodeBool(forKey: "warnedAboutEncryption")

        showDecryptedContentInNotifications = coder.decodeBool(forKey: "showDecryptedContentInNotifications")

        others = coder.decodeObject(forKey: "others") as? [String : NSCoding?]

        // Refresh device information
        loadDeviceInformation({ _ in }, failure: { _ in })
    }

    func encode(with coder: NSCoder) {
        coder.encode(mxCredentials?.homeServer, forKey: "homeserverurl")
        coder.encode(mxCredentials?.userId, forKey: "userid")
        coder.encode(mxCredentials?.accessToken, forKey: "accesstoken")
        coder.encode(mxCredentials?.identityServerAccessToken, forKey: "identityserveraccesstoken")

        if mxCredentials?.deviceId {
            coder.encode(mxCredentials?.deviceId, forKey: "deviceId")
        }

        if mxCredentials?.allowedCertificate {
            coder.encode(mxCredentials?.allowedCertificate, forKey: "allowedCertificate")
        }

        if let threePIDs = threePIDs {
            coder.encode(threePIDs, forKey: "threePIDs")
        }

        if device != nil {
            coder.encode(device, forKey: "device")
        }

        if identityServerURL != nil {
            coder.encode(identityServerURL, forKey: "identityserverurl")
        }

        if antivirusServerURL != nil {
            coder.encode(antivirusServerURL, forKey: "antivirusserverurl")
        }

        if pushGatewayURL != nil {
            coder.encode(pushGatewayURL, forKey: "pushgatewayurl")
        }

        coder.encode(hasPusherForPushNotifications, forKey: "_enablePushNotifications")
        coder.encode(hasPusherForPushKitNotifications, forKey: "enablePushKitNotifications")
        coder.encode(enableInAppNotifications, forKey: "enableInAppNotifications")

        coder.encode(disabled, forKey: "disabled")
        coder.encode(isSoftLogout, forKey: "isSoftLogout")

        coder.encode(warnedAboutEncryption, forKey: "warnedAboutEncryption")

        coder.encode(showDecryptedContentInNotifications, forKey: "showDecryptedContentInNotifications")

        coder.encode(others, forKey: "others")
    }

    /// Enable Push notification based on Apple Push Notification Service (APNS).
    /// This method creates or removes a pusher on the homeserver.
    /// - Parameters:
    ///   - enable: YES to enable it.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func enablePushNotifications(
        _ enable: Bool,
        success: @escaping () -> Void,
        failure: @escaping (Error?) -> Void
    ) {
        MXLogDebug("[MXKAccount][Push] enablePushNotifications: %@", NSNumber(value: enable))

        if enable {
            if MXKAccountManager.shared()?.isAPNSAvailable {
                MXLogDebug("[MXKAccount][Push] enablePushNotifications: Enable Push for %@ account", mxCredentials?.userId)

                // Create/restore the pusher
                enableAPNSPusher(true, success: {

                    MXLogDebug("[MXKAccount][Push] enablePushNotifications: Enable Push: Success")
                    if success != nil {
                        success()
                    }
                }, failure: { error in

                    MXLogDebug("[MXKAccount][Push] enablePushNotifications: Enable Push: Error: %@", error)
                    if failure != nil {
                        failure(error)
                    }
                })
            } else {
                MXLogDebug("[MXKAccount][Push] enablePushNotifications: Error: Cannot enable Push")

                let error = NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: [
                    NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "account_error_push_not_allowed")
                ])
                if failure != nil {
                    failure(error)
                }
            }
        } else if hasPusherForPushNotifications {
            MXLogDebug("[MXKAccount][Push] enablePushNotifications: Disable APNS for %@ account", mxCredentials?.userId)

            // Delete the pusher, report the new value only on success.
            enableAPNSPusher(
                false,
                success: {

                    MXLogDebug("[MXKAccount][Push] enablePushNotifications: Disable Push: Success")
                    if success != nil {
                        success()
                    }
                },
                failure: { error in

                    MXLogDebug("[MXKAccount][Push] enablePushNotifications: Disable Push: Error: %@", error)
                    if failure != nil {
                        failure(error)
                    }
                })
        }
    }

    /// Enable Push notification based on PushKit.
    /// This method creates or removes a pusher on the homeserver.
    /// - Parameters:
    ///   - enable: YES to enable it.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func enablePushKitNotifications(
        _ enable: Bool,
        success: @escaping () -> Void,
        failure: @escaping (Error?) -> Void
    ) {
        MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: %@", NSNumber(value: enable))

        if enable {
            if MXKAccountManager.shared()?.isPushAvailable {
                MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: Enable Push for %@ account", mxCredentials?.userId)

                // Create/restore the pusher
                enablePushKitPusher(true, success: {

                    MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: Enable Push: Success")
                    if success != nil {
                        success()
                    }
                }, failure: { error in

                    MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: Enable Push: Error: %@", error)
                    if failure != nil {
                        failure(error)
                    }
                })
            } else {
                MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: Error: Cannot enable Push")

                let error = NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: [
                    NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "account_error_push_not_allowed")
                ])
                failure(error)
            }
        } else if hasPusherForPushKitNotifications {
            MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: Disable Push for %@ account", mxCredentials?.userId)

            // Delete the pusher, report the new value only on success.
            enablePushKitPusher(false, success: {

                MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: Disable Push: Success")
                if success != nil {
                    success()
                }
            }, failure: { error in

                MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: Disable Push: Error: %@", error)
                if failure != nil {
                    failure(error)
                }
            })
        } else {
            MXLogDebug("[MXKAccount][Push] enablePushKitNotifications: PushKit is already disabled for %@", mxCredentials?.userId)
            if success != nil {
                success()
            }
        }
    }

    /// Set the display name of the account user.
    /// - Parameters:
    ///   - displayname: the new display name.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.

    // MARK: - Matrix user's profile

    func setUserDisplayName(_ displayname: String?, success: @escaping () -> Void, failure: @escaping (_ error: Error?) -> Void) {
        if mxSession != nil && mxSession?.myUser {
            mxSession?.myUser.setDisplayName(
                displayname,
                success: { [self] in
                    if success != nil {
                        success()
                    }

                    NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountUserInfoDidChangeNotification), object: mxCredentials?.userId)
                },
                failure: failure)
        } else if failure != nil {
            failure(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "account_error_matrix_session_is_not_opened")
            ]))
        }
    }

    /// Set the avatar url of the account user.
    /// - Parameters:
    ///   - avatarUrl: the new avatar url.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func setUserAvatarUrl(_ avatarUrl: String?, success: @escaping () -> Void, failure: @escaping (_ error: Error?) -> Void) {
        if mxSession != nil && mxSession?.myUser {
            mxSession?.myUser.setAvatarUrl(
                avatarUrl,
                success: { [self] in
                    if success != nil {
                        success()
                    }

                    NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountUserInfoDidChangeNotification), object: mxCredentials?.userId)
                },
                failure: failure)
        } else if failure != nil {
            failure(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "account_error_matrix_session_is_not_opened")
            ]))
        }
    }

    /// Update the account password.
    /// - Parameters:
    ///   - oldPassword: the old password.
    ///   - newPassword: the new password.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func changePassword(_ oldPassword: String?, with newPassword: String?, success: @escaping () -> Void, failure: @escaping (_ error: Error?) -> Void) {
        if mxSession != nil {
            mxRestClient?.changePassword(
                oldPassword,
                with: newPassword,
                success: {

                    if success != nil {
                        success()
                    }

                },
                failure: failure)
        } else if failure != nil {
            failure(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "account_error_matrix_session_is_not_opened")
            ]))
        }
    }

    /// Load the 3PIDs linked to this account.
    /// This method must be called to refresh self.threePIDs and self.linkedEmails.
    /// - Parameters:
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func load3PIDs(_ success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        mxRestClient?.threePIDs({ [self] threePIDs2 in

            threePIDs = threePIDs2

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()

            if success != nil {
                success()
            }

        }, failure: { error in
            if failure != nil {
                failure(error)
            }
        })
    }

    /// Load the current device information for this account.
    /// This method must be called to refresh self.device.
    /// - Parameters:
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func loadDeviceInformation(_ success: @escaping () -> Void, failure: @escaping (_ error: Error?) -> Void) {
        if mxCredentials?.deviceId {
            mxRestClient?.device(byDeviceId: mxCredentials?.deviceId, success: { [self] device in

                self.device = device

                // Archive updated field
                MXKAccountManager.shared()?.saveAccounts()

                if success != nil {
                    success()
                }

            }, failure: { error in

                if failure != nil {
                    failure(error)
                }

            })
        } else {
            device = nil
            if success != nil {
                success()
            }
        }
    }

    func setUserPresence(_ presence: MXPresence, andStatusMessage statusMessage: String?, completion: @escaping () -> Void) {
        userPresence = presence

        if mxSession != nil && !hideUserPresence {
            // Update user presence on server side
            mxSession?.myUser.setPresence(
                userPresence,
                andStatusMessage: statusMessage,
                success: { [self] in
                    MXLogDebug("[MXKAccount] %@: set user presence (%lu) succeeded", mxCredentials?.userId, UInt(userPresence))
                    if completion != nil {
                        completion()
                    }

                    NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountUserInfoDidChangeNotification), object: mxCredentials?.userId)
                },
                failure: { [self] error in
                    MXLogDebug("[MXKAccount] %@: set user presence (%lu) failed", mxCredentials?.userId, UInt(userPresence))
                })
        } else if hideUserPresence {
            MXLogDebug("[MXKAccount] %@: set user presence is disabled.", mxCredentials?.userId)
        }
    }

    /// Create a matrix session based on the provided store.
    /// When store data is ready, the live stream is automatically launched by synchronising the session with the server.
    /// In case of failure during server sync, the method is reiterated until the data is up-to-date with the server.
    /// This loop is stopped if you call [MXCAccount closeSession:], it is suspended if you call [MXCAccount pauseInBackgroundTask].
    /// - Parameter store: the store to use for the session.

    // MARK: -

    /// Create a matrix session based on the provided store.
    /// When store data is ready, the live stream is automatically launched by synchronising the session with the server.
    /// In case of failure during server sync, the method is reiterated until the data is up-to-date with the server.
    /// This loop is stopped if you call [MXCAccount closeSession:], it is suspended if you call [MXCAccount pauseInBackgroundTask].
    /// - Parameter store: the store to use for the session.
    func openSession(with store: MXStore?) {
        // Sanity check
        if mxCredentials == nil || mxRestClient == nil {
            MXLogDebug("[MXKAccount] Matrix session cannot be created without credentials")
            return
        }

        // Close potential session (keep associated store).
        closeSession(false)

        openSessionStartDate = Date()

        // Instantiate new session
        mxSession = MXSession(matrixRestClient: mxRestClient)

        // Check whether an antivirus url is defined.
        if antivirusServerURL != nil {
            // Enable the antivirus scanner in the current session.
            mxSession?.antivirusServerURL = antivirusServerURL
        }

        // Set default MXEvent -> NSString formatter
        let eventFormatter = MXKEventFormatter(matrixSession: mxSession)
        eventFormatter.isForSubtitle = true

        // Apply the event types filter to display only the wanted event types.
        eventFormatter.eventTypesFilterForMessages = MXKAppSettings.standard().eventsFilterForMessages

        mxSession?.roomSummaryUpdateDelegate = eventFormatter

        // Observe UIApplicationSignificantTimeChangeNotification to refresh to MXRoomSummaries if date/time are shown.
        // UIApplicationSignificantTimeChangeNotification is posted if DST is updated, carrier time is updated
        UIApplicationSignificantTimeChangeNotificationObserver = NotificationCenter.default.addObserver(forName: UIApplicationDelegate.significantTimeChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in
            onDateTimeFormatUpdate()
        })


        // Observe NSCurrentLocaleDidChangeNotification to refresh MXRoomSummaries if date/time are shown.
        // NSCurrentLocaleDidChangeNotification is triggered when the time swicthes to AM/PM to 24h time format
        NSCurrentLocaleDidChangeNotificationObserver = NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in
            onDateTimeFormatUpdate()
        })

        // Force a date refresh for all the last messages.
        onDateTimeFormatUpdate()

        // Register session state observer
        sessionStateObserver = NotificationCenter.default.addObserver(forName: kMXSessionStateDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

            // Check whether the concerned session is the associated one
            if (notif?.object as? MXSession) == mxSession {
                onMatrixSessionStateChange()
            }
        })

        MXWeakify(self)

        mxSession?.setStore(store, success: { [self] in

            // Complete session registration by launching live stream
            MXStrongifyAndReturnIfNil(self)

            // Refresh pusher state
            refreshAPNSPusher()
            refreshPushKitPusher()

            // Launch server sync
            launchInitialServerSync()

        }, failure: { [self] error in

            // This cannot happen. Loading of MXFileStore cannot fail.
            MXStrongifyAndReturnIfNil(self)
            mxSession = nil

            if let sessionStateObserver = sessionStateObserver {
                NotificationCenter.default.removeObserver(sessionStateObserver)
            }
            sessionStateObserver = nil

        })
    }

    /// Close the matrix session.
    /// - Parameter clearStore: set YES to delete all store data.
    func closeSession(_ clearStore: Bool) {
        MXLogDebug("[MXKAccount] closeSession (%tu)", clearStore)

        if NSCurrentLocaleDidChangeNotificationObserver != nil {
            if let NSCurrentLocaleDidChangeNotificationObserver = NSCurrentLocaleDidChangeNotificationObserver {
                NotificationCenter.default.removeObserver(NSCurrentLocaleDidChangeNotificationObserver)
            }
            NSCurrentLocaleDidChangeNotificationObserver = nil
        }

        if UIApplicationSignificantTimeChangeNotificationObserver != nil {
            if let UIApplicationSignificantTimeChangeNotificationObserver = UIApplicationSignificantTimeChangeNotificationObserver {
                NotificationCenter.default.removeObserver(UIApplicationSignificantTimeChangeNotificationObserver)
            }
            UIApplicationSignificantTimeChangeNotificationObserver = nil
        }

        removeNotificationListener()

        if reachabilityObserver != nil {
            if let reachabilityObserver = reachabilityObserver {
                NotificationCenter.default.removeObserver(reachabilityObserver)
            }
            reachabilityObserver = nil
        }

        if sessionStateObserver != nil {
            if let sessionStateObserver = sessionStateObserver {
                NotificationCenter.default.removeObserver(sessionStateObserver)
            }
            sessionStateObserver = nil
        }

        initialServerSyncTimer?.invalidate()
        initialServerSyncTimer = nil

        if userUpdateListener != nil {
            mxSession?.myUser.removeListener(userUpdateListener)
            userUpdateListener = nil
        }

        if mxSession != nil {
            // Reset room data stored in memory
            MXKRoomDataSourceManager.removeSharedManager(forMatrixSession: mxSession)

            if clearStore {
                // Force a reload of device keys at the next session start.
                // This will fix potential UISIs other peoples receive for our messages.
                mxSession?.crypto.resetDeviceKeys()

                // Clean other stores
                mxSession?.scanManager.deleteAllAntivirusScans()
                mxSession?.aggregations.resetData()
            } else {
                // For recomputing of room summaries as they are a cache of computed data
                mxSession?.resetRoomsSummariesLastMessage()
            }

            // Close session
            mxSession?.close()

            if clearStore {
                mxSession?.store.deleteAllData()
            }

            mxSession = nil
        }

        notifyOpenSessionFailure = true
    }

    /// Invalidate the access token, close the matrix session and delete all store data.
    /// @note This method is equivalent to `logoutSendingServerRequest:completion:` with `sendLogoutServerRequest` parameter to YES
    /// - Parameter completion: the block to execute at the end of the operation (independently if it succeeded or not).
    func logout(_ completion: @escaping () -> Void) {
        if mxSession == nil {
            MXLogDebug("[MXKAccount] logout: Need to open the closed session to make a logout request")
            weak var store: MXStore? = MXKAccountManager.shared()?.storeClass?.init() as? MXStore
            mxSession = MXSession(matrixRestClient: mxRestClient)

            MXWeakify(self)
            mxSession?.setStore(store, success: { [self] in
                MXStrongifyAndReturnIfNil(self)

                logout(completion)

            }, failure: { error in
                completion()
            })
            return
        }

        deletePusher()
        enablePushKitNotifications(false, success: { _ in }, failure: { _ in })

        let operation = mxSession?.logout({ [self] in

            closeSession(true)
            if completion != nil {
                completion()
            }

        }, failure: { [self] error in

            // Close the session even if the logout request failed
            closeSession(true)
            if completion != nil {
                completion()
            }

        })

        // Do not retry on failure.
        operation?.maxNumberOfTries = 1
    }

    // Logout locally, do not send server request
    func logoutLocally(_ completion: @escaping () -> Void) {
        deletePusher()
        enablePushKitNotifications(false, success: { _ in }, failure: { _ in })

        mxSession?.enableCrypto(false, success: { [self] in
            closeSession(true)
            if completion != nil {
                completion()
            }

        }, failure: { [self] error in

            // Close the session even if the logout request failed
            closeSession(true)
            if completion != nil {
                completion()
            }

        })
    }

    /// Invalidate the access token, close the matrix session and delete all store data.
    /// - Parameters:
    ///   - sendLogoutServerRequest: indicate to send logout request to homeserver.
    ///   - completion: the block to execute at the end of the operation (independently if it succeeded or not).
    func logoutSendingServerRequest(
        _ sendLogoutServerRequest: Bool,
        completion: @escaping () -> Void
    ) {
        if sendLogoutServerRequest {
            logout(completion)
        } else {
            logoutLocally(completion)
        }
    }

    /// Soft logout the account.
    /// The matix session is stopped but the data is kept.

    // MARK: - Soft logout

    func softLogout() {
        isSoftLogout = true
        MXKAccountManager.shared()?.saveAccounts()

        // Stop SDK making requests to the homeserver
        mxSession?.close()
    }

    /// Hydrate the account using the credentials provided.
    /// - Parameter credentials: the new credentials.
    func hydrate(with credentials: MXCredentials?) {
        // Sanity check
        if mxCredentials?.userId == credentials?.userId {
            mxCredentials = credentials
            isSoftLogout = false
            MXKAccountManager.shared()?.saveAccounts()

            prepareRESTClient()
        } else {
            MXLogDebug("[MXKAccount] hydrateWithCredentials: Error: users ids mismatch: %@ vs %@", credentials?.userId, mxCredentials?.userId)
        }
    }

    func deletePusher() {
        if pushNotificationServiceIsActive {
            enableAPNSPusher(false, success: { _ in }, failure: { _ in })
        }
    }

    /// Pause the current matrix session.
    /// @warning: This matrix session is paused without using background task if no background mode handler
    /// is set in the MXSDKOptions sharedInstance (see `backgroundModeHandler`).
    func pauseInBackgroundTask() {
        // Reset internal flag
        isPauseRequested = false

        if mxSession != nil && mxSession?.state == MXSessionStateRunning {
            weak var handler = MXSDKOptions.sharedInstance().backgroundModeHandler
            if let handler = handler {
                if !backgroundTask?.isRunning {
                    backgroundTask = handler.startBackgroundTask(withName: "[MXKAccount] pauseInBackgroundTask", expirationHandler: nil)
                }
            }

            // Pause SDK
            mxSession?.pause()

            // Update user presence
            weak var weakSelf = self
            setUserPresence(MXPresenceUnavailable, andStatusMessage: nil) { [self] in

                if let weakSelf = weakSelf {
                    let self = weakSelf

                    if backgroundTask?.isRunning {
                        backgroundTask?.stop()
                        backgroundTask = nil
                    }
                }

            }
        } else {
            // Cancel pending actions
            if let reachabilityObserver = reachabilityObserver {
                NotificationCenter.default.removeObserver(reachabilityObserver)
            }
            reachabilityObserver = nil
            initialServerSyncTimer?.invalidate()
            initialServerSyncTimer = nil

            if mxSession?.state == MXSessionStateSyncInProgress || mxSession?.state == MXSessionStateInitialised || mxSession?.state == MXSessionStateStoreDataReady {
                // Make sure the SDK finish its work before the app goes sleeping in background
                weak var handler = MXSDKOptions.sharedInstance().backgroundModeHandler
                if let handler = handler {
                    if !backgroundTask?.isRunning {
                        backgroundTask = handler.startBackgroundTask(withName: "[MXKAccount] pauseInBackgroundTask", expirationHandler: nil)
                    }
                }

                MXLogDebug("[MXKAccount] Pause is delayed at the end of sync (current state %tu)", mxSession?.state)
                isPauseRequested = true
            }
        }
    }

    /// Resume the current matrix session.
    func resume() {
        isPauseRequested = false

        if let mxSession = mxSession {
            cancelBackgroundSync()

            if mxSession.state == MXSessionStatePaused || mxSession.state == MXSessionStatePauseRequested {
                // Resume SDK and update user presence
                mxSession.resume({ [self] in
                    setUserPresence(MXPresenceOnline, andStatusMessage: nil) { _ in }

                    refreshAPNSPusher()
                    refreshPushKitPusher()
                })
            } else if mxSession.state == MXSessionStateStoreDataReady || mxSession.state == MXSessionStateInitialSyncFailed {
                // The session initialisation was uncompleted, we try to complete it here.
                launchInitialServerSync()

                refreshAPNSPusher()
                refreshPushKitPusher()
            } else if mxSession.state == MXSessionStateSyncInProgress {
                refreshAPNSPusher()
                refreshPushKitPusher()
            }

            // Cancel background task
            if backgroundTask?.isRunning {
                backgroundTask?.stop()
                backgroundTask = nil
            }
        }
    }

    /// Close the potential matrix session and open a new one if the account is not disabled.
    /// - Parameter clearCache: set YES to delete all store data.
    func reload(_ clearCache: Bool) {
        // close potential session
        closeSession(clearCache)

        if !disabled {
            // Open a new matrix session
            weak var store: MXStore? = MXKAccountManager.shared()?.storeClass?.init() as? MXStore
            openSession(with: store)
        }
    }

    // MARK: - Push notifications

    // Refresh the APNS pusher state for this account on this device.
    func refreshAPNSPusher() {
        MXLogDebug("[MXKAccount][Push] refreshAPNSPusher")

        // Check the conditions required to run the pusher
        if pushNotificationServiceIsActive {
            MXLogDebug("[MXKAccount][Push] refreshAPNSPusher: Refresh APNS pusher for %@ account", mxCredentials?.userId)

            // Create/restore the pusher
            enableAPNSPusher(
                true,
                success: { _ in },
                failure: { error in
                    MXLogDebug("[MXKAccount][Push] ;: Error: %@", error)
                })
        } else if hasPusherForPushNotifications {
            if MXKAccountManager.shared()?.apnsDeviceToken != nil {
                if mxSession != nil {
                    // Turn off pusher if user denied remote notification.
                    MXLogDebug("[MXKAccount][Push] refreshAPNSPusher: Disable APNS pusher for %@ account (notifications are denied)", mxCredentials?.userId)
                    enableAPNSPusher(false, success: { _ in }, failure: { _ in })
                }
            } else {
                MXLogDebug("[MXKAccount][Push] refreshAPNSPusher: APNS pusher for %@ account is already disabled. Reset _hasPusherForPushNotifications", mxCredentials?.userId)
                hasPusherForPushNotifications = false
                MXKAccountManager.shared()?.saveAccounts()
            }
        }
    }

    // Enable/Disable the APNS pusher for this account on this device on the homeserver.
    func enableAPNSPusher(_ enabled: Bool, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        MXLogDebug("[MXKAccount][Push] enableAPNSPusher: %@", NSNumber(value: enabled))

        #if DEBUG
        let appId = UserDefaults.standard.object(forKey: "pusherAppIdDev") as? String
        #else
        let appId = UserDefaults.standard.object(forKey: "pusherAppIdProd") as? String
        #endif

        let locKey = MXKAppSettings.standardAppSettings.notificationBodyLocalizationKey

        let pushData = [
            "url": pushGatewayURL ?? "",
            "format": "event_id_only",
            "default_payload": [
            "aps": [
            "mutable-content": NSNumber(value: 1),
            "alert": [
            "loc-key": locKey,
            "loc-args": []
        ]
        ]
        ]
        ]

        enablePusher(enabled, appId: appId, token: MXKAccountManager.shared()?.apnsDeviceToken, pushData: pushData, success: { [self] in

            MXLogDebug("[MXKAccount][Push] enableAPNSPusher: Succeeded to update APNS pusher for %@ (%d)", mxCredentials?.userId, enabled)

            hasPusherForPushNotifications = enabled
            MXKAccountManager.shared()?.saveAccounts()

            if success != nil {
                success()
            }

            NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountAPNSActivityDidChangeNotification), object: mxCredentials?.userId)

        }, failure: { [self] error in

            // Ignore error if the client try to disable an unknown token
            if !enabled {
                // Check whether the token was unknown
                let mxError = MXError(nsError: error)
                if mxError != nil && (mxError.errcode == kMXErrCodeStringUnknown) {
                    MXLogDebug("[MXKAccount][Push] enableAPNSPusher: APNS was already disabled for %@!", mxCredentials?.userId)

                    // Ignore the error
                    if success != nil {
                        success()
                    }

                    NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountAPNSActivityDidChangeNotification), object: mxCredentials?.userId)

                    return
                }

                MXLogDebug("[MXKAccount][Push] enableAPNSPusher: Failed to disable APNS %@! (%@)", mxCredentials?.userId, error)
            } else {
                MXLogDebug("[MXKAccount][Push] enableAPNSPusher: Failed to send APNS token for %@! (%@)", mxCredentials?.userId, error)
            }

            if failure != nil {
                failure(error)
            }

            NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountAPNSActivityDidChangeNotification), object: mxCredentials?.userId)
        })
    }

    // Refresh the PushKit pusher state for this account on this device.
    func refreshPushKitPusher() {
        MXLogDebug("[MXKAccount][Push] refreshPushKitPusher")

        // Check the conditions required to run the pusher
        if !MXKAppSettings.standard().allowPushKitPushers {
            // Turn off pusher if PushKit pushers are not allowed
            MXLogDebug("[MXKAccount][Push] refreshPushKitPusher: Disable PushKit pusher for %@ account (pushers are not allowed)", mxCredentials?.userId)
            enablePushKitPusher(false, success: { _ in }, failure: { _ in })
        } else if isPushKitNotificationActive {
            MXLogDebug("[MXKAccount][Push] refreshPushKitPusher: Refresh PushKit pusher for %@ account", mxCredentials?.userId)

            // Create/restore the pusher
            enablePushKitPusher(
                true,
                success: { _ in },
                failure: { error in
                    MXLogDebug("[MXKAccount][Push] refreshPushKitPusher: Error: %@", error)
                })
        } else if hasPusherForPushKitNotifications {
            if MXKAccountManager.shared()?.pushDeviceToken != nil {
                if mxSession != nil {
                    // Turn off pusher if user denied remote notification.
                    MXLogDebug("[MXKAccount][Push] refreshPushKitPusher: Disable PushKit pusher for %@ account (notifications are denied)", mxCredentials?.userId)
                    enablePushKitPusher(false, success: { _ in }, failure: { _ in })
                }
            } else {
                MXLogDebug("[MXKAccount][Push] refreshPushKitPusher: PushKit pusher for %@ account is already disabled. Reset _hasPusherForPushKitNotifications", mxCredentials?.userId)
                hasPusherForPushKitNotifications = false
                MXKAccountManager.shared()?.saveAccounts()
            }
        }
    }

    // Enable/Disable the pusher based on PushKit for this account on this device on the homeserver.
    func enablePushKitPusher(_ enabled: Bool, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        MXLogDebug("[MXKAccount][Push] enablePushKitPusher: %@", NSNumber(value: enabled))

        if enabled && !MXKAppSettings.standard().allowPushKitPushers {
            //  sanity check, if accidently try to enable the pusher
            MXLogDebug("[MXKAccount][Push] enablePushKitPusher: Do not enable it because PushKit pushers not allowed")
            if failure != nil {
                failure(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: nil))
            }
            return
        }

        var appIdKey: String?
        #if DEBUG
        appIdKey = "pushKitAppIdDev"
        #else
        appIdKey = "pushKitAppIdProd"
        #endif

        let appId = UserDefaults.standard.object(forKey: appIdKey ?? "") as? String

        var pushData = [
            "url": pushGatewayURL ?? ""
        ]

        let options = MXKAccountManager.shared()?.pushOptions
        if (options?.count ?? 0) != 0 {
            for (k, v) in options { pushData[k] = v }
        }

        let token = MXKAccountManager.shared()?.pushDeviceToken
        if token == nil {
            //  sanity check, if no token there is no point of calling the endpoint
            MXLogDebug("[MXKAccount][Push] enablePushKitPusher: Failed to update PushKit pusher to %@ for %@. (token is missing)", NSNumber(value: enabled), mxCredentials?.userId)
            if failure != nil {
                failure(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: nil))
            }
            return
        }
        enablePusher(enabled, appId: appId, token: token, pushData: pushData, success: { [self] in

            MXLogDebug("[MXKAccount][Push] enablePushKitPusher: Succeeded to update PushKit pusher for %@. Enabled: %@. Token: %@", mxCredentials?.userId, NSNumber(value: enabled), MXKTools.log(forPushToken: token))

            hasPusherForPushKitNotifications = enabled
            MXKAccountManager.shared()?.saveAccounts()

            if success != nil {
                success()
            }

            NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountPushKitActivityDidChangeNotification), object: mxCredentials?.userId)

        }, failure: { [self] error in

            // Ignore error if the client try to disable an unknown token
            if !enabled {
                // Check whether the token was unknown
                let mxError = MXError(nsError: error)
                if mxError != nil && (mxError.errcode == kMXErrCodeStringUnknown) {
                    MXLogDebug("[MXKAccount][Push] enablePushKitPusher: Push was already disabled for %@!", mxCredentials?.userId)

                    // Ignore the error
                    if success != nil {
                        success()
                    }

                    NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountPushKitActivityDidChangeNotification), object: mxCredentials?.userId)

                    return
                }

                MXLogDebug("[MXKAccount][Push] enablePushKitPusher: Failed to disable Push %@! (%@)", mxCredentials?.userId, error)
            } else {
                MXLogDebug("[MXKAccount][Push] enablePushKitPusher: Failed to send Push token for %@! (%@)", mxCredentials?.userId, error)
            }

            if failure != nil {
                failure(error)
            }

            NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountPushKitActivityDidChangeNotification), object: mxCredentials?.userId)
        })
    }

    func enablePusher(_ enabled: Bool, appId: String?, token: Data?, pushData: [AnyHashable : Any]?, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        MXLogDebug("[MXKAccount][Push] enablePusher: %@", NSNumber(value: enabled))

        // Refuse to try & turn push on if we're not logged in, it's nonsensical.
        if mxCredentials == nil {
            MXLogDebug("[MXKAccount][Push] enablePusher: Not setting push token because we're not logged in")
            return
        }

        // Check whether the Push Gateway URL has been configured.
        if pushGatewayURL == nil {
            MXLogDebug("[MXKAccount][Push] enablePusher: Not setting pusher because the Push Gateway URL is undefined")
            return
        }

        if appId == nil {
            MXLogDebug("[MXKAccount][Push] enablePusher: Not setting pusher because pusher app id is undefined")
            return
        }

        var appDisplayName: String? = nil
        if let object = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") {
            appDisplayName = "\(object) (iOS)"
        }

        let b64Token = token?.base64EncodedString(options: [])

        let deviceLang = NSLocale.preferredLanguages[0]

        var profileTag = UserDefaults.standard.value(forKey: "pusherProfileTag") as? String
        if profileTag == nil {
            profileTag = ""
            let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            for i in 0..<16 {
                let c = UInt8(alphabet[alphabet.index(alphabet.startIndex, offsetBy: UInt(Int(arc4random()) % alphabet.count))])
                profileTag = (profileTag ?? "") + "\(c)"
            }
            MXLogDebug("[MXKAccount][Push] enablePusher: Generated fresh profile tag: %@", profileTag)
            UserDefaults.standard.setValue(profileTag, forKey: "pusherProfileTag")
        } else {
            MXLogDebug("[MXKAccount][Push] enablePusher: Using existing profile tag: %@", profileTag)
        }

        let kind = (enabled ? "http" : NSNull()) as? NSObject

        // Use the append flag to handle multiple accounts registration.
        var append = false
        // Check whether a pusher is running for another account
        let activeAccounts = MXKAccountManager.shared()?.activeAccounts
        for account in activeAccounts ?? [] {
            if (account.mxCredentials?.userId != mxCredentials?.userId) && account.pushNotificationServiceIsActive {
                append = true
                break
            }
        }
        MXLogDebug("[MXKAccount][Push] enablePusher: append flag: %d", append)

        let restCli = mxRestClient

        restCli?.setPusherWithPushkey(b64Token, kind: kind, appId: appId, appDisplayName: appDisplayName, deviceDisplayName: UIDevice.current.name, profileTag: profileTag, lang: deviceLang, data: pushData, append: append, success: success, failure: failure)
    }

    // MARK: - Push notification listeners
    /// Register a listener to push notifications for the account's session.
    /// The listener will be called when a push rule matches a live event.
    /// Note: only one listener is supported. Potential existing listener is removed.
    /// You may use `[MXCAccount updateNotificationListenerForRoomId:]` to disable/enable all notifications from a specific room.
    /// - Parameter onNotification: the block that will be called once a live event matches a push rule.

    // MARK: - InApp notifications

    func listen(toNotifications onNotification: MXOnNotification) {
        // Check conditions required to add notification listener
        if mxSession == nil || onNotification == nil {
            return
        }

        // Remove existing listener (if any)
        removeNotificationListener()

        // Register on notification center
        notificationCenterListener = mxSession?.notificationCenter.listen(toNotifications: { [self] event, roomState, rule in
            // Apply first the event filter defined in the related room data source
            let roomDataSourceManager = MXKRoomDataSourceManager.sharedManager(forMatrixSession: mxSession)
            roomDataSourceManager?.roomDataSource(forRoom: event?.roomId, create: false, onComplete: { [self] roomDataSource in
                if let roomDataSource = roomDataSource {
                    if let type = event?.type {
                        if !roomDataSource.eventFormatter.eventTypesFilterForMessages || (roomDataSource.eventFormatter.eventTypesFilterForMessages.firstIndex(of: type) ?? NSNotFound) != NSNotFound {
                            // Check conditions to report this notification
                            if let roomId = event?.roomId {
                                if nil == ignoredRooms || (ignoredRooms?.firstIndex(of: roomId) ?? NSNotFound) == NSNotFound {
                                    onNotification(event, roomState, rule)
                                }
                            }
                        }
                    }
                }
            })
        })
    }

    /// Unregister the listener.
    func removeNotificationListener() {
        if notificationCenterListener != nil {
            mxSession?.notificationCenter.removeListener(notificationCenterListener)
            notificationCenterListener = nil
        }
        ignoredRooms = nil
    }

    /// Update the listener to ignore or restore notifications from a specific room.
    /// - Parameters:
    ///   - roomID: the id of the concerned room.
    ///   - isIgnored: YES to disable notifications from the specified room. NO to restore them.
    func updateNotificationListener(forRoomId roomID: String?, ignore isIgnored: Bool) {
        if isIgnored {
            if ignoredRooms == nil {
                ignoredRooms = []
            }
            ignoredRooms?.append(roomID ?? "")
        } else if let ignoredRooms = ignoredRooms {
            ignoredRooms.removeAll { $0 as AnyObject === roomID as AnyObject }
        }
    }

    // MARK: - Internals

    @objc func launchInitialServerSync() {
        // Complete the session registration when store data is ready.

        // Cancel potential reachability observer and pending action
        if let reachabilityObserver = reachabilityObserver {
            NotificationCenter.default.removeObserver(reachabilityObserver)
        }
        reachabilityObserver = nil
        initialServerSyncTimer?.invalidate()
        initialServerSyncTimer = nil

        // Sanity check
        if mxSession == nil || (mxSession?.state != MXSessionStateStoreDataReady && mxSession?.state != MXSessionStateInitialSyncFailed) {
            MXLogDebug("[MXKAccount] Initial server sync is applicable only when store data is ready to complete session initialisation")
            return
        }

        // Use /sync filter corresponding to current settings and homeserver capabilities
        MXWeakify(self)
        buildSyncFilter({ [self] syncFilter in
            MXStrongifyAndReturnIfNil(self)

            // Make sure the filter is compatible with the previously used one
            MXWeakify(self)
            checkSyncFilterCompatibility(syncFilter) { [self] compatible in
                MXStrongifyAndReturnIfNil(self)

                if !compatible {
                    // Else clear the cache
                    MXLogDebug("[MXKAccount] New /sync filter not compatible with previous one. Clear cache")

                    reload(true)
                    return
                }

                // Launch mxSession
                MXWeakify(self)
                mxSession?.start(withSyncFilter: syncFilter, onServerSyncDone: { [self] in
                    MXStrongifyAndReturnIfNil(self)

                    if let openSessionStartDate = openSessionStartDate {
                        MXLogDebug("[MXKAccount] %@: The session is ready. Matrix SDK session has been started in %0.fms.", mxCredentials?.userId, Date().timeIntervalSince(openSessionStartDate) * 1000)
                    }

                    setUserPresence(MXPresenceOnline, andStatusMessage: nil) { _ in }

                }, failure: { [self] error in
                    MXStrongifyAndReturnIfNil(self)

                    MXLogDebug("[MXKAccount] Initial Sync failed. Error: %@", error)

                    let isClientTimeout = ((error as NSError?)?.domain == NSURLErrorDomain) && (error as NSError?)?.code == Int(NSURLErrorTimedOut)
                    let httpResponse = MXHTTPOperation.urlResponse(fromError: error)
                    let isServerTimeout = httpResponse != nil && initialSyncSilentErrorsHTTPStatusCodes?.contains(NSNumber(value: httpResponse?.statusCode ?? 0)) ?? false

                    if isClientTimeout || isServerTimeout {
                        //  do not propogate this error to the client
                        //  the request will be retried or postponed according to the reachability status
                        MXLogDebug("[MXKAccount] Initial sync failure did not propagated")
                    } else if notifyOpenSessionFailure && error != nil {
                        // Notify MatrixKit user only once
                        notifyOpenSessionFailure = false
                        let myUserId = mxSession?.myUser.userId
                        NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != nil ? [
                            kMXKErrorUserIdKey: myUserId ?? ""
                        ] : nil)
                    }

                    // Check if it is a network connectivity issue
                    let networkReachabilityManager = AFNetworkReachabilityManager.shared()
                    MXLogDebug("[MXKAccount] Network reachability: %d", networkReachabilityManager?.isReachable)

                    if networkReachabilityManager?.isReachable {
                        // The problem is not the network
                        // Postpone a new attempt in 10 sec
                        initialServerSyncTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(launchInitialServerSync), userInfo: self, repeats: false)
                    } else {
                        // The device is not connected to the internet, wait for the connection to be up again before retrying
                        // Add observer to launch a new attempt according to reachability.
                        reachabilityObserver = NotificationCenter.default.addObserver(forName: AFNetworkingReachabilityDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] note in

                            let statusItem = note?.userInfo?[AFNetworkingReachabilityNotificationStatusItem] as? NSNumber
                            if let statusItem = statusItem {
                                let reachabilityStatus = statusItem.intValue
                                if reachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi || reachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN {
                                    // New attempt
                                    launchInitialServerSync()
                                }
                            }

                        })
                    }
                })
            }
        })
    }

    func onMatrixSessionStateChange() {
        if mxSession?.state == MXSessionStateRunning {
            // Check if pause has been requested
            if isPauseRequested {
                MXLogDebug("[MXKAccount] Apply the pending pause.")
                pauseInBackgroundTask()
                return
            }

            // Check whether the session was not already running
            if userUpdateListener == nil {
                // Register listener to user's information change
                userUpdateListener = mxSession?.myUser.listen(toUserUpdate: { [self] event in
                    // Consider events related to user's presence
                    if event?.eventType == MXEventTypePresence {
                        userPresence = MXTools.presence(event?.content["presence"])
                    }

                    // Here displayname or other information have been updated, post update notification.
                    NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountUserInfoDidChangeNotification), object: mxCredentials?.userId)
                })

                // User information are just up-to-date (`mxSession` is running), post update notification.
                NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountUserInfoDidChangeNotification), object: mxCredentials?.userId)
            }
        } else if mxSession?.state == MXSessionStateStoreDataReady || mxSession?.state == MXSessionStateSyncInProgress {
            // Remove listener (if any), this action is required to handle correctly matrix sdk handler reload (see clear cache)
            if userUpdateListener != nil {
                mxSession?.myUser.removeListener(userUpdateListener)
                userUpdateListener = nil
            } else {
                // Here the initial server sync is in progress. The session is not running yet, but some user's information are available (from local storage).
                // We post update notification to let observer take into account this user's information even if they may not be up-to-date.
                NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountUserInfoDidChangeNotification), object: mxCredentials?.userId)
            }
        } else if mxSession?.state == MXSessionStatePaused {
            isPauseRequested = false
        } else if mxSession?.state == MXSessionStateUnknownToken {
            // Logout this account
            MXKAccountManager.shared()?.remove(self) { _ in }
        } else if mxSession?.state == MXSessionStateSoftLogout {
            // Soft logout this account
            MXKAccountManager.shared()?.softLogout(self)
        }
    }

    func prepareRESTClient() {
        if mxCredentials == nil {
            return
        }

        mxRestClient = MXRestClient(credentials: mxCredentials) { [self] certificate in

            if let _onCertificateChangeBlock = _onCertificateChangeBlock {
                if _onCertificateChangeBlock(self, certificate) {
                    // Update the certificate in credentials
                    mxCredentials?.allowedCertificate = certificate

                    // Archive updated field
                    MXKAccountManager.shared()?.saveAccounts()

                    return true
                }

                mxCredentials?.ignoredCertificate = certificate

                // Archive updated field
                MXKAccountManager.shared()?.saveAccounts()
            }
            return false

        }
    }

    func onDateTimeFormatUpdate() {
        if mxSession?.roomSummaryUpdateDelegate is MXKEventFormatter {
            let eventFormatter = mxSession?.roomSummaryUpdateDelegate as? MXKEventFormatter

            // Update the date and time formatters
            eventFormatter?.initDateTimeFormatters()

            let dispatchGroup = DispatchGroup()

            if let roomsSummaries = mxSession?.roomsSummaries {
                for summary in roomsSummaries {
                    guard let summary = summary as? MXRoomSummary else {
                        continue
                    }
                    dispatchGroup.enter()
                    summary.mxSession.event(
                        withEventId: summary.lastMessage.eventId,
                        inRoom: summary.roomId,
                        success: { [self] event in

                            if let event = event {
                                if summary.lastMessage.others == nil {
                                    summary.lastMessage.others = [AnyHashable : Any]()
                                }
                                if let date = eventFormatter?.dateString(from: event, withTime: true) {
                                    summary.lastMessage.others["lastEventDate"] = date
                                }
                                mxSession?.store.storeSummary(forRoom: summary.roomId, summary: summary)
                            }

                            dispatchGroup.leave()
                        },
                        failure: { error in
                            dispatchGroup.leave()
                        })
                }
            }

            dispatch_group_notify(dispatchGroup, DispatchQueue.main, { [self] in

                // Commit store changes done
                if mxSession?.store.responds(to: Selector("commit")) ?? false {
                    mxSession?.store.commit()
                }

                // Broadcast the change which concerns all the room summaries.
                NotificationCenter.default.post(name: kMXRoomSummaryDidChangeNotification, object: nil, userInfo: nil)

            })
        }
    }

    // MARK: - Crypto
    /// Delete the device id.
    /// Call this method when the current device id cannot be used anymore.

    // MARK: - Crypto

    func resetDeviceId() {
        mxCredentials?.deviceId = nil

        // Archive updated field
        MXKAccountManager.shared()?.saveAccounts()
    }

    // MARK: - backgroundSync management

    func cancelBackgroundSync() {
        if backgroundSyncBgTask?.isRunning {
            MXLogDebug("[MXKAccount] The background Sync is cancelled.")

            if let mxSession = mxSession {
                if mxSession.state == MXSessionStateBackgroundSyncInProgress {
                    mxSession.pause()
                }
            }

            onBackgroundSyncDone(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: nil))
        }
    }

    func onBackgroundSyncDone(_ error: Error?) {
        if backgroundSyncTimer != nil {
            backgroundSyncTimer?.invalidate()
            backgroundSyncTimer = nil
        }

        if backgroundSyncFails != nil && error != nil {
            backgroundSyncFails?(error)
        }

        if backgroundSyncDone != nil && error == nil {
            backgroundSyncDone?()
        }

        backgroundSyncDone = nil
        backgroundSyncFails = nil

        // End background task
        if backgroundSyncBgTask?.isRunning {
            backgroundSyncBgTask?.stop()
            backgroundSyncBgTask = nil
        }
    }

    @objc func onBackgroundSyncTimerOut() {
        cancelBackgroundSync()
    }

    /// Perform a background sync by keeping the user offline.
    /// @warning: This operation failed when no background mode handler is set in the
    /// MXSDKOptions sharedInstance (see `backgroundModeHandler`).
    /// - Parameters:
    ///   - timeout: the timeout in milliseconds.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func backgroundSync(_ timeout: UInt, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        // Check whether a background mode handler has been set.
        weak var handler = MXSDKOptions.sharedInstance().backgroundModeHandler
        if let handler = handler {
            // Only work when the application is suspended.
            // Check conditions before launching background sync
            if mxSession != nil && mxSession?.state == MXSessionStatePaused {
                MXLogDebug("[MXKAccount] starts a background Sync")

                backgroundSyncDone = success
                backgroundSyncFails = failure

                MXWeakify(self)

                backgroundSyncBgTask = handler.startBackgroundTask(withName: "[MXKAccount] backgroundSync:success:failure:", expirationHandler: { [self] in

                    MXStrongifyAndReturnIfNil(self)

                    MXLogDebug("[MXKAccount] the background Sync fails because of the bg task timeout")
                    cancelBackgroundSync()
                })

                // ensure that the backgroundSync will be really done in the expected time
                // the request could be done but the treatment could be long so add a timer to cancel it
                // if it takes too much time
                backgroundSyncTimer = Timer(
                    fireAt: Date(timeIntervalSinceNow: TimeInterval((timeout - 1) / 1000)),
                    interval: 0,
                    target: self,
                    selector: #selector(onBackgroundSyncTimerOut),
                    userInfo: nil,
                    repeats: false)

                if let backgroundSyncTimer = backgroundSyncTimer {
                    RunLoop.main.add(backgroundSyncTimer, forMode: .default)
                }

                mxSession?.backgroundSync(timeout, success: { [self] in
                    MXLogDebug("[MXKAccount] the background Sync succeeds")
                    onBackgroundSyncDone(nil)

                }, failure: { [self] error in

                    MXLogDebug("[MXKAccount] the background Sync fails")
                    onBackgroundSyncDone(error)

                })
            } else {
                MXLogDebug("[MXKAccount] cannot start background Sync (invalid state %tu)", mxSession?.state)
                failure(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: nil))
            }
        } else {
            MXLogDebug("[MXKAccount] cannot start background Sync")
            failure(NSError(domain: kMXKAccountErrorDomain, code: 0, userInfo: nil))
        }
    }

    // MARK: - Sync filter
    /// Check if the homeserver supports room members lazy loading.
    /// - Parameter completion: the check result.

    // MARK: - Sync filter

    func supportLazyLoadOfRoomMembers(_ completion: @escaping (_ supportLazyLoadOfRoomMembers: Bool) -> Void) {
        let onUnsupportedLazyLoadOfRoomMembers: ((Error?) -> Void)? = { error in
            completion(false)
        }

        // Check if the server supports LL sync filter
        let filter = syncFilter(withLazyLoadOfRoomMembers: true)
        mxSession?.store.filterId(forFilter: filter, success: { [self] filterId in

            if filterId != nil {
                // The LL filter is already in the store. The HS supports LL
                completion(true)
            } else {
                // Check the Matrix versions supported by the HS
                mxSession?.supportedMatrixVersions({ matrixVersions in

                    if matrixVersions?.supportLazyLoadMembers {
                        // The HS supports LL
                        completion(true)
                    } else {
                        onUnsupportedLazyLoadOfRoomMembers?(nil)
                    }

                }, failure: onUnsupportedLazyLoadOfRoomMembers)
            }
        }, failure: onUnsupportedLazyLoadOfRoomMembers)
    }

    /// Build the sync filter according to application settings and HS capability.
    /// - Parameter completion: the block providing the sync filter to use.
    func buildSyncFilter(_ completion: @escaping (_ syncFilter: MXFilterJSONModel?) -> Void) {
        // Check settings
        let syncWithLazyLoadOfRoomMembersSetting = MXKAppSettings.standard().syncWithLazyLoadOfRoomMembers

        if syncWithLazyLoadOfRoomMembersSetting {
            // Check if the server supports LL sync filter before enabling it
            supportLazyLoadOfRoomMembers({ [self] supportLazyLoadOfRoomMembers in

                if supportLazyLoadOfRoomMembers {
                    completion(syncFilter(withLazyLoadOfRoomMembers: true)!)
                } else {
                    // No support from the HS
                    // Disable the setting. That will avoid to make a request at every startup
                    MXKAppSettings.standard().syncWithLazyLoadOfRoomMembers = false
                    completion(syncFilter(withLazyLoadOfRoomMembers: false)!)
                }
            })
        } else {
            completion(syncFilter(withLazyLoadOfRoomMembers: false)!)
        }
    }

    /// Compute the sync filter to use according to the device screen size.
    /// - Parameter syncWithLazyLoadOfRoomMembers: enable LL support.
    /// - Returns: the sync filter to use.
    func syncFilter(withLazyLoadOfRoomMembers syncWithLazyLoadOfRoomMembers: Bool) -> MXFilterJSONModel? {
        var syncFilter: MXFilterJSONModel?
        var limit = 10

        // Define a message limit for /sync requests that is high enough so that
        // a full page of room messages can be displayed without an additional
        // server request.

        // This limit value depends on the device screen size. So, the rough rule is:
        //    - use 10 for small phones (5S/SE)
        //    - use 15 for phones (6/6S/7/8)
        //    - use 20 for phablets (.Plus/X/XR/XS/XSMax)
        //    - use 30 for iPads
        let userInterfaceIdiom = UIDevice.current.userInterfaceIdiom
        if userInterfaceIdiom == .phone {
            let screenHeight = UIScreen.main.nativeBounds.size.height
            if screenHeight == 1334 {
                limit = 15
            } else if screenHeight > 1334 {
                limit = 20
            }
        } else if userInterfaceIdiom == .pad {
            limit = 30
        }

        // Set that limit in the filter
        if syncWithLazyLoadOfRoomMembers {
            syncFilter = MXFilterJSONModel.syncFilterForLazyLoading(withMessageLimit: limit)
        } else {
            syncFilter = MXFilterJSONModel.syncFilter(withMessageLimit: limit)
        }

        // TODO: We could extend the filter to match other settings (self.showAllEventsInRoomHistory,
        // self.eventsFilterForMessages, etc).

        return syncFilter
    }

    /// Check the sync filter we want to use is compatible with the one previously used.
    /// - Parameters:
    ///   - syncFilter: the sync filter to use.
    ///   - completion: the block called to indicated the compatibility.
    func checkSyncFilterCompatibility(_ syncFilter: MXFilterJSONModel?, completion: @escaping (_ compatible: Bool) -> Void) {
        // There is no compatibility issue if no /sync was done before
        if !mxSession?.store.eventStreamToken {
            completion(true)
        } else if syncFilter == nil && !mxSession?.syncFilterId {
            // A nil filter implies a nil mxSession.syncFilterId. So, there is no filter change
            completion(true)
        } else if syncFilter == nil || !mxSession?.syncFilterId {
            // Change from no filter with using a filter or vice-versa. So, there is a filter change
            MXLogDebug(
                "[MXKAccount] checkSyncFilterCompatibility: Incompatible filter. New or old is nil. mxSession.syncFilterId: %@ - syncFilter: %@",
                mxSession?.syncFilterId,
                syncFilter?.jsonDictionary)
            completion(false)
        } else {
            // Check the filter is the one previously set
            // It must be already in the store
            MXWeakify(self)
            mxSession?.store.filterId(forFilter: syncFilter, success: { [self] filterId in
                MXStrongifyAndReturnIfNil(self)

                // Note: We could be more tolerant here
                // We could accept filter hot change if the change is limited to the `limit` filter value
                // But we do not have this requirement yet
                let compatible = filterId == mxSession?.syncFilterId
                if !compatible {
                    MXLogDebug(
                        "[MXKAccount] checkSyncFilterCompatibility: Incompatible filter ids. mxSession.syncFilterId: %@ -  store.filterId: %@ - syncFilter: %@",
                        mxSession?.syncFilterId,
                        filterId,
                        syncFilter?.jsonDictionary)
                }
                completion(compatible)

            }, failure: { error in
                // Should never happen
                completion(false)
            })
        }
    }

    // MARK: - Identity Server updates

    func registerDataDidChangeIdentityServerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataDidChangeIdentityServerNotification(_:)), name: kMXSessionAccountDataDidChangeIdentityServerNotification, object: nil)
    }

    @objc func handleDataDidChangeIdentityServerNotification(_ notification: Notification?) {
        let mxSession = notification?.object as? MXSession
        if mxSession == self.mxSession {
            if mxCredentials?.identityServer != self.mxSession?.accountDataIdentityServer {
                identityServerURL = self.mxSession?.accountDataIdentityServer
                mxCredentials?.identityServer = identityServerURL
                mxCredentials?.identityServerAccessToken = nil

                // Archive updated field
                MXKAccountManager.shared()?.saveAccounts()
            }
        }
    }

    // MARK: - Identity Server Access Token updates

    func identityService(_ identityService: MXIdentityService?, didUpdateAccessToken accessToken: String?) {
        mxCredentials?.identityServerAccessToken = accessToken
    }

    func registerIdentityServiceDidChangeAccessTokenNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleIdentityServiceDidChangeAccessTokenNotification(_:)), name: MXIdentityServiceDidChangeAccessTokenNotification, object: nil)
    }

    @objc func handleIdentityServiceDidChangeAccessTokenNotification(_ notification: Notification?) {
        let userInfo = notification?.userInfo

        let userId = userInfo?[MXIdentityServiceNotificationUserIdKey] as? String
        let identityServer = userInfo?[MXIdentityServiceNotificationIdentityServerKey] as? String
        let accessToken = userInfo?[MXIdentityServiceNotificationAccessTokenKey] as? String

        if userId != nil && identityServer != nil && accessToken != nil && (mxCredentials?.identityServer == identityServer) {
            mxCredentials?.identityServerAccessToken = accessToken

            // Archive updated field
            MXKAccountManager.shared()?.saveAccounts()
        }
    }
}