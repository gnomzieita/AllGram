//  Converted to Swift 5.4 by Swiftify v5.4.25812 - https://swiftify.com/
/*
 Copyright 2016 OpenMarket Ltd
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

/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2019 New Vector Ltd

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

import MatrixKit

class AuthInputsView: MXKAuthInputsView, MXKCountryPickerViewControllerDelegate {
    /// The current email validation
    private var submittedEmail: MXK3PID?
    /// The current msisdn validation
    private var submittedMSISDN: MXK3PID?
    private var phoneNumberPickerNavigationController: UINavigationController?
    private var phoneNumberCountryPicker: CountryPickerViewController?
    private var nbPhoneNumber: NBPhoneNumber?
    /// The set of parameters ready to use for a registration.
    private var externalRegistrationParameters: [AnyHashable : Any]?

    @IBOutlet weak var userLoginTextField: UITextField!
    @IBOutlet weak var passWordTextField: UITextField!
    @IBOutlet weak var repeatPasswordTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var userLoginContainer: UIView!
    @IBOutlet weak var emailContainer: UIView!
    @IBOutlet weak var phoneContainer: UIView!
    @IBOutlet weak var passwordContainer: UIView!
    @IBOutlet weak var repeatPasswordContainer: UIView!
    @IBOutlet weak var userLoginSeparator: UIView!
    @IBOutlet weak var emailSeparator: UIView!
    @IBOutlet weak var phoneSeparator: UIView!
    @IBOutlet weak var passwordSeparator: UIView!
    @IBOutlet weak var repeatPasswordSeparator: UIView!
    @IBOutlet weak var countryCodeButton: UIButton!
    @IBOutlet weak var isoCountryCodeLabel: UILabel!
    @IBOutlet weak var callingCodeLabel: UILabel!
    @IBOutlet weak var userLoginContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var passwordContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var emailContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var phoneContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var recaptchaContainer: UIView!
    @IBOutlet weak var termsView: TermsView!
    @IBOutlet weak var ssoButtonContainer: TermsView!
    @IBOutlet weak var ssoButton: UIButton!
    /// Tell whether some third-party identifiers may be added during the account registration.

    var areThirdPartyIdentifiersSupported: Bool {
        return isFlowSupported(kMXLoginFlowTypeEmailIdentity) || isFlowSupported(kMXLoginFlowTypeMSISDN)
    }
    /// Tell whether at least one third-party identifier is required to create a new account.

    var isThirdPartyIdentifierRequired: Bool {
        // Check first whether some 3pids are supported
        if !areThirdPartyIdentifiersSupported {
            return false
        }

        // Check whether an account may be created without third-party identifiers.
        for loginFlow in currentSession.flows {
            if (loginFlow.stages.firstIndex(of: kMXLoginFlowTypeEmailIdentity) ?? NSNotFound) == NSNotFound && (loginFlow.stages.firstIndex(of: kMXLoginFlowTypeMSISDN) ?? NSNotFound) == NSNotFound {
                // There is a flow with no 3pids
                return false
            }
        }

        return true
    }
    /// Tell whether all the supported third-party identifiers are required to create a new account.

    var areAllThirdPartyIdentifiersRequired: Bool {
        // Check first whether some 3pids are required
        if !isThirdPartyIdentifierRequired {
            return false
        }

        let isEmailIdentityFlowSupported = isFlowSupported(kMXLoginFlowTypeEmailIdentity)
        let isMSISDNFlowSupported = isFlowSupported(kMXLoginFlowTypeMSISDN)

        for loginFlow in currentSession.flows {
            if isEmailIdentityFlowSupported {
                if (loginFlow.stages.firstIndex(of: kMXLoginFlowTypeEmailIdentity) ?? NSNotFound) == NSNotFound {
                    return false
                } else if isMSISDNFlowSupported {
                    if (loginFlow.stages.firstIndex(of: kMXLoginFlowTypeMSISDN) ?? NSNotFound) == NSNotFound {
                        return false
                    }
                }
            } else if isMSISDNFlowSupported {
                if (loginFlow.stages.firstIndex(of: kMXLoginFlowTypeMSISDN) ?? NSNotFound) == NSNotFound {
                    return false
                }
            }
        }

        return true
    }
    /// Update the registration inputs layout by hidding the third-party identifiers fields (YES by default).
    /// Set NO to show these fields and hide the others.

    private var _thirdPartyIdentifiersHidden = false
    var thirdPartyIdentifiersHidden: Bool {
        get {
            _thirdPartyIdentifiersHidden
        }
        set(thirdPartyIdentifiersHidden) {
            hideInputsContainer()

            var lastViewContainer: UIView?

            if thirdPartyIdentifiersHidden {
                passWordTextField.returnKeyType = .next

                userLoginTextField.attributedPlaceholder = NSAttributedString(
                    string: NSLocalizedString("auth_user_name_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
                    attributes: [
                        NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                    ])

                userLoginContainer.isHidden = false
                passwordContainer.isHidden = false
                repeatPasswordContainer.isHidden = false

                passwordContainerTopConstraint.constant = 50

                lastViewContainer = repeatPasswordContainer
            } else {
                if isFlowSupported(kMXLoginFlowTypeEmailIdentity) {
                    if isThirdPartyIdentifierRequired {
                        emailTextField.placeholder = NSLocalizedString("auth_email_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    } else {
                        emailTextField.placeholder = NSLocalizedString("auth_optional_email_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    }

                    emailTextField.attributedPlaceholder = NSAttributedString(
                        string: emailTextField.placeholder ?? "",
                        attributes: [
                            NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                        ])

                    emailContainer.isHidden = false

                    messageLabel.isHidden = false
                    messageLabel.text = NSLocalizedString("auth_add_email_message_2", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                    lastViewContainer = emailContainer
                }

                if isFlowSupported(kMXLoginFlowTypeMSISDN) {
                    phoneTextField.returnKeyType = .done

                    if isThirdPartyIdentifierRequired {
                        phoneTextField.placeholder = NSLocalizedString("auth_phone_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    } else {
                        phoneTextField.placeholder = NSLocalizedString("auth_optional_phone_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    }

                    phoneTextField.attributedPlaceholder = NSAttributedString(
                        string: phoneTextField.placeholder ?? "",
                        attributes: [
                            NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                        ])

                    phoneContainer.isHidden = false

                    if !emailContainer.isHidden {
                        emailTextField.returnKeyType = .next

                        phoneContainerTopConstraint.constant = 50
                        messageLabel.text = NSLocalizedString("auth_add_email_phone_message_2", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    } else {
                        phoneContainerTopConstraint.constant = 0

                        messageLabel.isHidden = false
                        messageLabel.text = NSLocalizedString("auth_add_phone_message_2", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    }

                    lastViewContainer = phoneContainer
                }

                if !messageLabel.isHidden {
                    messageLabel.sizeToFit()

                    let frame = messageLabel.frame

                    let offset = frame.origin.y + frame.size.height

                    emailContainerTopConstraint.constant = offset
                    phoneContainerTopConstraint.constant += offset
                }
            }

            currentLastContainer = lastViewContainer

            _thirdPartyIdentifiersHidden = thirdPartyIdentifiersHidden
        }
    }
    /// Tell whether a second third-party identifier is waiting for being added to the new account.
    private(set) var isThirdPartyIdentifierPending = false
    /// Tell whether the flow requires a Single-Sign-On flow.
    private(set) var isSingleSignOnRequired = false
    /// The current selected country code

    private var _isoCountryCode: String?
    var isoCountryCode: String? {
        get {
            _isoCountryCode
        }
        set(isoCountryCode) {
            _isoCountryCode = isoCountryCode

            let callingCode = NBPhoneNumberUtil.sharedInstance().getCountryCode(forRegion: isoCountryCode)

            callingCodeLabel.text = "+\(callingCode?.stringValue ?? "")"

            isoCountryCodeLabel.text = isoCountryCode

            // Update displayed phone
            textFieldDidChange(phoneTextField)
        }
    }
    /// The current view container displayed at last position.

    private var _currentLastContainer: UIView?
    private var currentLastContainer: UIView? {
        get {
            _currentLastContainer
        }
        set(currentLastContainer) {
            _currentLastContainer = currentLastContainer

            let frame = _currentLastContainer?.frame
            viewHeightConstraint.constant = (frame?.origin.y ?? 0.0) + (frame?.size.height ?? 0.0)
        }
    }

    class func nib() -> UINib? {
        return UINib(
            nibName: NSStringFromClass(self.self),
            bundle: Bundle(for: AuthInputsView))
    }

    func awakeFromNib() {
        super.awakeFromNib()

        thirdPartyIdentifiersHidden = true
        isThirdPartyIdentifierPending = false
        isSingleSignOnRequired = false

        userLoginTextField.placeholder = NSLocalizedString("auth_user_id_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        repeatPasswordTextField.placeholder = NSLocalizedString("auth_repeat_password_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        passWordTextField.placeholder = NSLocalizedString("auth_password_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

        // Apply placeholder color
        customizeRendering()
    }

    func destroy() {
        super.destroy()

        submittedEmail = nil
        submittedMSISDN = nil
    }

    func layoutSubviews() {
        super.layoutSubviews()

        if currentLastContainer != nil {
            #warning("Swiftify: Skipping redundant initializing to itself")
            //currentLastContainer = currentLastContainer
        }
    }

    // MARK: - Override MXKView

    func customizeRendering() {
        super.customizeRendering()

        repeatPasswordTextField.textColor = ThemeService.shared.theme.textPrimaryColor
        userLoginTextField.textColor = ThemeService.shared.theme.textPrimaryColor
        passWordTextField.textColor = ThemeService.shared.theme.textPrimaryColor

        emailTextField.textColor = ThemeService.shared.theme.textPrimaryColor
        phoneTextField.textColor = ThemeService.shared.theme.textPrimaryColor

        isoCountryCodeLabel.textColor = ThemeService.shared.theme.textPrimaryColor
        callingCodeLabel.textColor = ThemeService.shared.theme.textPrimaryColor

        countryCodeButton.tintColor = ThemeService.shared.theme.textSecondaryColor

        messageLabel.textColor = ThemeService.shared.theme.textSecondaryColor
        messageLabel.numberOfLines = 0

        userLoginSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor
        emailSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor
        phoneSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor
        passwordSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor
        repeatPasswordSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor

        ssoButton.layer.cornerRadius = 5
        ssoButton.clipsToBounds = true
        ssoButton.setTitle(NSLocalizedString("auth_login_single_sign_on", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), for: .normal)
        ssoButton.setTitle(NSLocalizedString("auth_login_single_sign_on", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), for: .highlighted)
        ssoButton.backgroundColor = ThemeService.shared.theme.tintColor

        if userLoginTextField.placeholder != nil {
            userLoginTextField.attributedPlaceholder = NSAttributedString(
                string: userLoginTextField.placeholder ?? "",
                attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                ])
        }

        if repeatPasswordTextField.placeholder != nil {
            repeatPasswordTextField.attributedPlaceholder = NSAttributedString(
                string: repeatPasswordTextField.placeholder ?? "",
                attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                ])
        }

        if passWordTextField.placeholder != nil {
            passWordTextField.attributedPlaceholder = NSAttributedString(
                string: passWordTextField.placeholder ?? "",
                attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                ])
        }

        if phoneTextField.placeholder != nil {
            phoneTextField.attributedPlaceholder = NSAttributedString(
                string: phoneTextField.placeholder ?? "",
                attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                ])
        }

        if emailTextField.placeholder != nil {
            emailTextField.attributedPlaceholder = NSAttributedString(
                string: emailTextField.placeholder ?? "",
                attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                ])
        }
    }

    // MARK: -

    func setAuthSession(_ authSession: MXAuthenticationSession?, withAuthType authType: MXKAuthenticationType) -> Bool {
        if type == MXKAuthenticationTypeLogin || type == MXKAuthenticationTypeRegister {
            // Validate first the provided session
            let validSession = validate(authSession)

            // Cancel email validation if any
            if submittedEmail != nil {
                submittedEmail?.cancelCurrentRequest()
                submittedEmail = nil
            }

            // Cancel msisdn validation if any
            if submittedMSISDN != nil {
                submittedMSISDN?.cancelCurrentRequest()
                submittedMSISDN = nil
            }

            // Reset external registration parameters
            externalRegistrationParameters = nil

            // Reset UI by hidding all items
            hideInputsContainer()

            if super.setAuthSession(validSession, withAuthType: authType) {
                if authType == MXKAuthenticationTypeLogin {
                    isSingleSignOnRequired = false

                    if isFlowSupported(kMXLoginFlowTypePassword) {
                        let showPhoneTextField = BuildSettings.authScreenShowPhoneNumber

                        passWordTextField.returnKeyType = .done
                        phoneTextField.returnKeyType = .next

                        userLoginTextField.placeholder = NSLocalizedString("auth_user_id_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                        messageLabel.text = NSLocalizedString("or", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                        phoneTextField.placeholder = NSLocalizedString("auth_phone_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                        userLoginTextField.attributedPlaceholder = NSAttributedString(
                            string: userLoginTextField.placeholder ?? "",
                            attributes: [
                                NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                            ])
                        phoneTextField.attributedPlaceholder = NSAttributedString(
                            string: phoneTextField.placeholder ?? "",
                            attributes: [
                                NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                            ])

                        userLoginContainer.isHidden = false
                        messageLabel.isHidden = !showPhoneTextField
                        phoneContainer.isHidden = !showPhoneTextField
                        passwordContainer.isHidden = false

                        messageLabelTopConstraint.constant = 59

                        var phoneContainerTopConstraintConstant: CGFloat = 0.0
                        var passwordContainerTopConstraintConstant: CGFloat = 0.0

                        if showPhoneTextField {
                            phoneContainerTopConstraintConstant = 70
                            passwordContainerTopConstraintConstant = 150
                        } else {
                            passwordContainerTopConstraintConstant = 50
                        }

                        phoneContainerTopConstraint.constant = phoneContainerTopConstraintConstant
                        passwordContainerTopConstraint.constant = passwordContainerTopConstraintConstant

                        currentLastContainer = passwordContainer
                    } else if isFlowSupported(kMXLoginFlowTypeCAS) || isFlowSupported(kMXLoginFlowTypeSSO) {

                        ssoButtonContainer.hidden = false
                        currentLastContainer = ssoButtonContainer

                        isSingleSignOnRequired = true
                    }
                } else {
                    // Update the registration inputs layout by hidding third-party ids fields.
                    #warning("Swiftify: Skipping redundant initializing to itself")
                    //thirdPartyIdentifiersHidden = thirdPartyIdentifiersHidden
                }

                return true
            }
        }

        return false
    }

    func validateParameters() -> String? {
        // Consider everything is fine when external registration parameters are ready to use
        if externalRegistrationParameters != nil {
            return nil
        }

        // Check the validity of the parameters
        var errorMsg: String? = nil

        // Remove whitespace in user login text field
        let userLogin = userLoginTextField.text
        userLoginTextField.text = userLogin?.trimmingCharacters(in: CharacterSet.whitespaces)

        if type == MXKAuthenticationTypeLogin {
            if isFlowSupported(kMXLoginFlowTypePassword) {
                // Check required fields
                if ((userLoginTextField.text?.count ?? 0) == 0 && nbPhoneNumber == nil) || (passWordTextField.text?.count ?? 0) == 0 {
                    MXLogDebug("[AuthInputsView] Invalid user/password")
                    errorMsg = NSLocalizedString("auth_invalid_login_param", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                }
            } else {
                errorMsg = Bundle.mxk_localizedString(forKey: "not_supported_yet")
            }
        } else if type == MXKAuthenticationTypeRegister {
            if thirdPartyIdentifiersHidden {
                if (userLoginTextField.text?.count ?? 0) == 0 {
                    MXLogDebug("[AuthInputsView] Invalid user name")
                    errorMsg = NSLocalizedString("auth_invalid_user_name", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                } else if (passWordTextField.text?.count ?? 0) == 0 {
                    MXLogDebug("[AuthInputsView] Missing Passwords")
                    errorMsg = NSLocalizedString("auth_missing_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                } else if (passWordTextField.text?.count ?? 0) < 6 {
                    MXLogDebug("[AuthInputsView] Invalid Passwords")
                    errorMsg = NSLocalizedString("auth_invalid_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                } else if (repeatPasswordTextField.text == passWordTextField.text) == false {
                    MXLogDebug("[AuthInputsView] Passwords don't match")
                    errorMsg = NSLocalizedString("auth_password_dont_match", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                } else {
                    // Check validity of the non empty user name
                    let user = userLoginTextField.text
                    var regex: NSRegularExpression? = nil
                    do {
                        regex = try NSRegularExpression(pattern: "^[a-z0-9.\\-_]+$", options: .caseInsensitive)
                    } catch {
                    }

                    if regex?.firstMatch(in: user ?? "", options: [], range: NSRange(location: 0, length: user?.count ?? 0)) == nil {
                        MXLogDebug("[AuthInputsView] Invalid user name")
                        errorMsg = NSLocalizedString("auth_invalid_user_name", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    }
                }
            } else {
                // Check email field
                if isFlowSupported(kMXLoginFlowTypeEmailIdentity) && (emailTextField.text?.count ?? 0) == 0 {
                    if areAllThirdPartyIdentifiersRequired {
                        MXLogDebug("[AuthInputsView] Missing email")
                        errorMsg = NSLocalizedString("auth_missing_email", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    } else if isFlowSupported(kMXLoginFlowTypeMSISDN) && (phoneTextField.text?.count ?? 0) == 0 && isThirdPartyIdentifierRequired {
                        MXLogDebug("[AuthInputsView] Missing email or phone number")
                        errorMsg = NSLocalizedString("auth_missing_email_or_phone", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    }
                }

                if errorMsg == nil {
                    // Check phone field
                    if isFlowSupported(kMXLoginFlowTypeMSISDN) && (phoneTextField.text?.count ?? 0) == 0 {
                        if areAllThirdPartyIdentifiersRequired {
                            MXLogDebug("[AuthInputsView] Missing phone")
                            errorMsg = NSLocalizedString("auth_missing_phone", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                        }
                    }

                    if errorMsg == nil {
                        // Check email/phone validity
                        if (emailTextField.text?.count ?? 0) != 0 {
                            // Check validity of the non empty email
                            if !MXTools.isEmailAddress(emailTextField.text) {
                                MXLogDebug("[AuthInputsView] Invalid email")
                                errorMsg = NSLocalizedString("auth_invalid_email", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                            }
                        }

                        if errorMsg == nil && nbPhoneNumber != nil {
                            // Check validity of the non empty phone
                            if !NBPhoneNumberUtil.sharedInstance().isValidNumber(nbPhoneNumber) {
                                MXLogDebug("[AuthInputsView] Invalid phone number")
                                errorMsg = NSLocalizedString("auth_invalid_phone", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                            }
                        }
                    }
                }
            }
        }

        return errorMsg
    }

    func prepareParameters(_ callback: @escaping (_ parameters: [AnyHashable : Any]?, _ error: Error?) -> Void) {
        if callback != nil {
            // Return external registration parameters if any
            if let externalRegistrationParameters = externalRegistrationParameters {
                // We trigger here a registration based on external inputs. All the required data are handled by the session id.
                MXLogDebug("[AuthInputsView] prepareParameters: return external registration parameters")
                callback(externalRegistrationParameters, nil)

                // CAUTION: Do not reset this dictionary here, it is used later to handle this registration until the end (see [updateAuthSessionWithCompletedStages:didUpdateParameters:])

                return
            }

            // Prepare here parameters dict by checking each required fields.
            var parameters: [AnyHashable : Any]? = nil

            // Check the validity of the parameters
            let errorMsg = validateParameters()
            if let errorMsg = errorMsg {
                if inputsAlert {
                    inputsAlert.dismiss(animated: false)
                }

                inputsAlert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "error"), message: errorMsg, preferredStyle: .alert)

                inputsAlert.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "ok"),
                        style: .default,
                        handler: { action in

                            inputsAlert = nil

                        }))

                delegate.authInputsView(self, presentAlertController: inputsAlert)
            } else {
                // Handle here the supported login flow
                if type == MXKAuthenticationTypeLogin {
                    if isFlowSupported(kMXLoginFlowTypePassword) {
                        // Check whether the user login has been set.
                        let user = userLoginTextField.text

                        if (user?.count ?? 0) != 0 {
                            // Check whether user login is an email or a username.
                            if MXTools.isEmailAddress(user) {
                                parameters = [
                                    "type": kMXLoginFlowTypePassword,
                                    "identifier": [
                                    "type": kMXLoginIdentifierTypeThirdParty,
                                    "medium": kMX3PIDMediumEmail,
                                    "address": user ?? ""
                                ],
                                    "password": passWordTextField.text ?? "",
                                // Patch: add the old login api parameters for an email address (medium and address),
                                // to keep logging in against old HS.
                                    "medium": kMX3PIDMediumEmail,
                                    "address": user ?? ""
                                ]
                            } else {
                                parameters = [
                                    "type": kMXLoginFlowTypePassword,
                                    "identifier": [
                                    "type": kMXLoginIdentifierTypeUser,
                                    "user": user ?? ""
                                ],
                                    "password": passWordTextField.text ?? "",
                                // Patch: add the old login api parameters for a username (user),
                                // to keep logging in against old HS.
                                    "user": user ?? ""
                                ]
                            }
                        } else if let nbPhoneNumber = nbPhoneNumber {
                            let countryCode = NBPhoneNumberUtil.sharedInstance().getRegionCode(for: nbPhoneNumber)
                            var e164: String? = nil
                            do {
                                e164 = try NBPhoneNumberUtil.sharedInstance().format(nbPhoneNumber, numberFormat: NBEPhoneNumberFormatE164)
                            } catch {
                            }
                            var msisdn: String?
                            if e164?.hasPrefix("+") ?? false {
                                msisdn = (e164 as NSString?)?.substring(from: 1)
                            } else if e164?.hasPrefix("00") ?? false {
                                msisdn = (e164 as NSString?)?.substring(from: 2)
                            }

                            if msisdn != nil && countryCode != "" {
                                parameters = [
                                    "type": kMXLoginFlowTypePassword,
                                    "identifier": [
                                    "type": kMXLoginIdentifierTypePhone,
                                    "country": countryCode,
                                    "number": msisdn ?? ""
                                ],
                                    "password": passWordTextField.text ?? ""
                                ]
                            }
                        }
                    }

                    // For soft logout, pass the device_id currently used
                    if parameters != nil && softLogoutCredentials {
                        var parametersWithDeviceId = parameters
                        parametersWithDeviceId?["device_id"] = softLogoutCredentials.deviceId
                        parameters = parametersWithDeviceId
                    }
                } else if type == MXKAuthenticationTypeRegister {
                    // Check whether a phone number has been set, and if it is not handled yet
                    if nbPhoneNumber != nil && !isFlowCompleted(kMXLoginFlowTypeMSISDN) {
                        MXLogDebug("[AuthInputsView] Prepare msisdn stage")

                        // Retrieve the REST client from delegate
                        var restClient: MXRestClient?

                        if delegate && delegate.responds(to: Selector("authInputsViewThirdPartyIdValidationRestClient:")) {
                            restClient = delegate.authInputsViewThirdPartyIdValidationRestClient(self)
                        }

                        if let restClient = restClient {
                            MXWeakify(self)
                            checkIdentityServerRequirement(restClient, success: { [self] identityServerRequired in
                                MXStrongifyAndReturnIfNil(self)

                                if identityServerRequired && !restClient.identityServer {
                                    callback(
                                        nil,
                                        NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                                                                                    NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "auth_phone_is_required")
                                                                                ]))
                                    return
                                }

                                // Check whether a second 3pid is available
                                isThirdPartyIdentifierPending = !emailContainer.isHidden && (emailTextField.text?.count ?? 0) != 0 && !isFlowCompleted(kMXLoginFlowTypeEmailIdentity)

                                // Launch msisdn validation
                                var e164: String? = nil
                                do {
                                    e164 = try NBPhoneNumberUtil.sharedInstance().format(nbPhoneNumber, numberFormat: NBEPhoneNumberFormatE164)
                                } catch {
                                }
                                var msisdn: String?
                                if e164?.hasPrefix("+") ?? false {
                                    msisdn = (e164 as NSString?)?.substring(from: 1)
                                } else if e164?.hasPrefix("00") ?? false {
                                    msisdn = (e164 as NSString?)?.substring(from: 2)
                                }
                                submittedMSISDN = MXK3PID.init(medium: kMX3PIDMediumMSISDN, andAddress: msisdn)

                                submittedMSISDN?.requestValidationToken(
                                    withMatrixRestClient: restClient,
                                    isDuringRegistration: true,
                                    nextLink: nil,
                                    success: { [self] in

                                        showValidationMSISDNDialog(toPrepareParameters: callback)

                                    },
                                    failure: { error in

                                        MXLogDebug("[AuthInputsView] Failed to request msisdn token")

                                        // Ignore connection cancellation error
                                        if ((error as NSError?)?.domain == NSURLErrorDomain) && (error as NSError?)?.code == Int(NSURLErrorCancelled) {
                                            return
                                        }

                                        // Translate the potential MX error.
                                        let mxError = MXError(nsError: error)
                                        if mxError != nil && ((mxError.errcode == kMXErrCodeStringThreePIDInUse) || (mxError.errcode == kMXErrCodeStringServerNotTrusted)) {
                                            var userInfo: [AnyHashable : Any]?
                                            if (error as NSError?)?.userInfo != nil {
                                                userInfo = (error as NSError?)?.userInfo
                                            } else {
                                                userInfo = [:]
                                            }

                                            userInfo?[NSLocalizedFailureReasonErrorKey] = nil

                                            if mxError.errcode == kMXErrCodeStringThreePIDInUse {
                                                userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_phone_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                                userInfo?["error"] = NSLocalizedString("auth_phone_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                            } else {
                                                userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                                userInfo?["error"] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                            }

                                            error = NSError(domain: (error as NSError?)?.domain ?? "", code: (error as NSError?)?.code ?? 0, userInfo: userInfo as? [String : Any])
                                        }

                                        callback(nil, error!)

                                    })


                            }, failure: { error in
                                callback(nil, error!)
                            })

                            // Async response
                            return
                        }
                        MXLogDebug("[AuthInputsView] Authentication failed during the msisdn stage")
                    } else if !emailContainer.isHidden && (emailTextField.text?.count ?? 0) != 0 && !isFlowCompleted(kMXLoginFlowTypeEmailIdentity) {
                        MXLogDebug("[AuthInputsView] Prepare email identity stage")

                        // Retrieve the REST client from delegate
                        var restClient: MXRestClient?

                        if delegate && delegate.responds(to: Selector("authInputsViewThirdPartyIdValidationRestClient:")) {
                            restClient = delegate.authInputsViewThirdPartyIdValidationRestClient(self)
                        }

                        if let restClient = restClient {
                            MXWeakify(self)
                            checkIdentityServerRequirement(restClient, success: { [self] identityServerRequired in
                                MXStrongifyAndReturnIfNil(self)

                                if identityServerRequired && !restClient.identityServer {
                                    callback(
                                        nil,
                                        NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                                                                                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "auth_email_is_required")
                                                                                    ]))
                                    return
                                }

                                // Check whether a second 3pid is available
                                isThirdPartyIdentifierPending = nbPhoneNumber != nil && !isFlowCompleted(kMXLoginFlowTypeMSISDN)

                                // Launch email validation
                                submittedEmail = MXK3PID.init(medium: kMX3PIDMediumEmail, andAddress: emailTextField.text)

                                let identityServer = restClient.identityServer

                                submittedEmail?.requestValidationToken(
                                    withMatrixRestClient: restClient,
                                    isDuringRegistration: true,
                                    nextLink: nil,
                                    success: { [self] in
                                        var threepidCreds: [AnyHashable : Any]? = nil
                                        if let clientSecret = submittedEmail?.clientSecret, let sid = submittedEmail?.sid {
                                            threepidCreds = [
                                                "client_secret": clientSecret,
                                                "sid": sid
                                            ]
                                        }
                                        if identityServer != "" {
                                            let identServerURL = URL(string: identityServer)
                                            threepidCreds?["id_server"] = identServerURL?.host
                                        }

                                        var parameters: [AnyHashable : Any]?
                                        if let threepidCreds = threepidCreds {
                                            parameters = [
                                                "auth": [
                                                "session": currentSession.session,
                                                "threepid_creds": threepidCreds,
                                                "type": kMXLoginFlowTypeEmailIdentity
                                            ],
                                                "username": userLoginTextField.text ?? "",
                                                "password": passWordTextField.text ?? ""
                                            ]
                                        }

                                        hideInputsContainer()

                                        messageLabel.text = NSLocalizedString("auth_email_validation_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                        messageLabel.isHidden = false

                                        callback(parameters, nil)

                                    },
                                    failure: { error in

                                        MXLogDebug("[AuthInputsView] Failed to request email token")

                                        // Ignore connection cancellation error
                                        if ((error as NSError?)?.domain == NSURLErrorDomain) && (error as NSError?)?.code == Int(NSURLErrorCancelled) {
                                            return
                                        }

                                        // Translate the potential MX error.
                                        let mxError = MXError(nsError: error)
                                        if mxError != nil && ((mxError.errcode == kMXErrCodeStringThreePIDInUse) || (mxError.errcode == kMXErrCodeStringServerNotTrusted)) {
                                            var userInfo: [AnyHashable : Any]?
                                            if (error as NSError?)?.userInfo != nil {
                                                userInfo = (error as NSError?)?.userInfo
                                            } else {
                                                userInfo = [:]
                                            }

                                            userInfo?[NSLocalizedFailureReasonErrorKey] = nil

                                            if mxError.errcode == kMXErrCodeStringThreePIDInUse {
                                                userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_email_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                                userInfo?["error"] = NSLocalizedString("auth_email_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                            } else {
                                                userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                                userInfo?["error"] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                            }

                                            error = NSError(domain: (error as NSError?)?.domain ?? "", code: (error as NSError?)?.code ?? 0, userInfo: userInfo as? [String : Any])
                                        }
                                        callback(nil, error!)

                                    })
                            }, failure: { error in
                                callback(nil, error!)
                            })

                            // Async response
                            return
                        }
                        MXLogDebug("[AuthInputsView] Authentication failed during the email identity stage")
                    } else if isFlowSupported(kMXLoginFlowTypeRecaptcha) && !isFlowCompleted(kMXLoginFlowTypeRecaptcha) {
                        MXLogDebug("[AuthInputsView] Prepare reCaptcha stage")

                        displayRecaptchaForm({ [self] response in

                            if (response?.count ?? 0) != 0 {
                                var parameters = [
                                    "auth": [
                                    "session": currentSession.session,
                                    "response": response ?? "",
                                    "type": kMXLoginFlowTypeRecaptcha
                                ],
                                    "username": userLoginTextField.text ?? "",
                                    "password": passWordTextField.text ?? ""
                                ]

                                callback(parameters, nil)
                            } else {
                                MXLogDebug("[AuthInputsView] reCaptcha stage failed")
                                callback(nil, NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                                    NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
                                ]))
                            }

                        })

                        // Async response
                        return
                    } else if isFlowSupported(kMXLoginFlowTypeDummy) && !isFlowCompleted(kMXLoginFlowTypeDummy) {
                        parameters = [
                            "auth": [
                            "session": currentSession.session,
                            "type": kMXLoginFlowTypeDummy
                        ],
                            "username": userLoginTextField.text ?? "",
                            "password": passWordTextField.text ?? ""
                        ]
                    } else if isFlowSupported(kMXLoginFlowTypePassword) && !isFlowCompleted(kMXLoginFlowTypePassword) {
                        // Note: this use case was not tested yet.
                        parameters = [
                            "auth": [
                            "session": currentSession.session,
                            "username": userLoginTextField.text ?? "",
                            "password": passWordTextField.text ?? "",
                            "type": kMXLoginFlowTypePassword
                        ]
                        ]
                    } else if isFlowSupported(kMXLoginFlowTypeTerms) && !isFlowCompleted(kMXLoginFlowTypeTerms) {
                        MXLogDebug("[AuthInputsView] Prepare terms stage")

                        MXWeakify(self)
                        displayTermsView({ [self] in
                            MXStrongifyAndReturnIfNil(self)

                            var parameters = [
                                "auth": [
                                "session": currentSession.session,
                                "type": kMXLoginFlowTypeTerms
                            ],
                                "username": userLoginTextField.text ?? "",
                                "password": passWordTextField.text ?? ""
                            ]
                            callback(parameters, nil)
                        })

                        // Async response
                        return
                    }
                }
            }

            callback(parameters, nil)
        }
    }

    func updateAuthSession(withCompletedStages completedStages: [AnyHashable]?, didUpdateParameters callback: @escaping (_ parameters: [AnyHashable : Any]?, _ error: Error?) -> Void) {
        if callback != nil {
            if currentSession {
                currentSession.completed = completedStages

                let isMSISDNFlowCompleted = isFlowCompleted(kMXLoginFlowTypeMSISDN)
                let isEmailFlowCompleted = isFlowCompleted(kMXLoginFlowTypeEmailIdentity)

                // Check the supported use cases
                if isMSISDNFlowCompleted && isThirdPartyIdentifierPending {
                    MXLogDebug("[AuthInputsView] Prepare a new third-party stage")

                    // Here an email address is available, we add it to the authentication session.
                    prepareParameters(callback)

                    return
                } else if (isMSISDNFlowCompleted || isEmailFlowCompleted) && isFlowSupported(kMXLoginFlowTypeRecaptcha) && !isFlowCompleted(kMXLoginFlowTypeRecaptcha) {
                    MXLogDebug("[AuthInputsView] Display reCaptcha stage")

                    if externalRegistrationParameters != nil {
                        displayRecaptchaForm({ response in

                            if (response?.count ?? 0) != 0 {
                                // We finalize here a registration triggered from external inputs. All the required data are handled by the session id
                                let parameters = [
                                    "auth": [
                                    "session": currentSession.session,
                                    "response": response ?? "",
                                    "type": kMXLoginFlowTypeRecaptcha
                                ]
                                ]
                                callback(parameters, nil)
                            } else {
                                MXLogDebug("[AuthInputsView] reCaptcha stage failed")
                                callback(nil, NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                                    NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
                                ]))
                            }
                        })
                    } else {
                        prepareParameters(callback)
                    }

                    return
                } else if isFlowSupported(kMXLoginFlowTypeTerms) && !isFlowCompleted(kMXLoginFlowTypeTerms) {
                    MXLogDebug("[AuthInputsView] Prepare a new terms stage")

                    if externalRegistrationParameters != nil {
                        displayTermsView({ [self] in

                            let parameters = [
                                "auth": [
                                "session": currentSession.session,
                                "type": kMXLoginFlowTypeTerms
                            ]
                            ]
                            callback(parameters, nil)
                        })
                    } else {
                        prepareParameters(callback)
                    }

                    return
                }
            }

            MXLogDebug("[AuthInputsView] updateAuthSessionWithCompletedStages failed")
            callback(nil, NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
            ]))
        }
    }

    func setExternalRegistrationParameters(_ registrationParameters: [AnyHashable : Any]?) -> Bool {
        // Presently we only support a registration based on next_link associated to a successful email validation.
        var homeserverURL: String?
        var identityURL: String?

        // Check the current authentication type
        if authType != MXKAuthenticationTypeRegister {
            MXLogDebug("[AuthInputsView] setExternalRegistrationParameters failed: wrong auth type")
            return false
        }

        // Retrieve the REST client from delegate
        var restClient: MXRestClient?
        if delegate && delegate.responds(to: Selector("authInputsViewThirdPartyIdValidationRestClient:")) {
            restClient = delegate.authInputsViewThirdPartyIdValidationRestClient(self)
        }

        if let restClient = restClient {
            // Sanity check on homeserver
            let hs_url = registrationParameters?["hs_url"]
            if hs_url != nil && (hs_url is NSString) {
                homeserverURL = hs_url as? String

                if (homeserverURL == restClient.homeserver) == false {
                    MXLogDebug("[AuthInputsView] setExternalRegistrationParameters failed: wrong homeserver URL")
                    return false
                }
            }

            // Sanity check on identity server
            let is_url = registrationParameters?["is_url"]
            if is_url != nil && (is_url is NSString) {
                identityURL = is_url as? String

                if (identityURL == restClient.identityServer) == false {
                    MXLogDebug("[AuthInputsView] setExternalRegistrationParameters failed: wrong identity server URL")
                    return false
                }
            }
        } else {
            MXLogDebug("[AuthInputsView] setExternalRegistrationParameters failed: not supported")
            return false
        }

        // Retrieve other parameters
        var clientSecret: String?
        var sid: String?
        var sessionId: String?

        var value = registrationParameters?["client_secret"]
        if value != nil && (value is NSString) {
            clientSecret = value as? String
        }
        value = registrationParameters?["sid"]
        if value != nil && (value is NSString) {
            sid = value as? String
        }
        value = registrationParameters?["session_id"]
        if value != nil && (value is NSString) {
            sessionId = value as? String
        }

        // Check validity of the required parameters
        if (homeserverURL?.count ?? 0) == 0 || (clientSecret?.count ?? 0) == 0 || (sid?.count ?? 0) == 0 || (sessionId?.count ?? 0) == 0 {
            MXLogDebug("[AuthInputsView] setExternalRegistrationParameters failed: wrong parameters")
            return false
        }

        // Prepare the registration parameters (Ready to use)

        var threepidCreds = [
            "client_secret": clientSecret ?? "",
            "sid": sid ?? ""
        ]
        if let identityURL = identityURL {
            let identServerURL = URL(string: identityURL)
            threepidCreds["id_server"] = identServerURL?.host ?? ""
        }

        externalRegistrationParameters = [
            "auth": [
            "session": sessionId ?? "",
            "threepid_creds": threepidCreds,
            "type": kMXLoginFlowTypeEmailIdentity
        ]
        ]

        // Hide all inputs by default
        hideInputsContainer()

        return true
    }

    func setSoftLogoutCredentials(_ credentials: MXCredentials?) {
        softLogoutCredentials = credentials
        userLoginTextField.text = softLogoutCredentials.userId()
        userLoginContainer.isHidden = true
        phoneContainer.isHidden = true

        displaySoftLogoutMessage()
    }

    func displaySoftLogoutMessage() {
        // Take some shortcuts and make some assumptions (Riot uses MXFileStore and MXRealmCryptoStore) to
        // retrieve data to display as quick as possible
        let cryptoStore = MXRealmCryptoStore(credentials: softLogoutCredentials)
        let keyBackupNeeded = cryptoStore.inboundGroupSessions(toBackup: 1).count > 0

        let fileStore = MXFileStore(credentials: softLogoutCredentials)
        fileStore.asyncUsers(withUserIds: [softLogoutCredentials.userId()], success: { [self] users in

            let myUser = users.first
            fileStore.close()

            displaySoftLogoutMessage(withUserDisplayname: myUser?.displayname, andKeyBackupNeeded: keyBackupNeeded)

        }, failure: { [self] error in
            MXLogDebug("[AuthInputsView] displaySoftLogoutMessage: Cannot load displayname. Error: %@", error)
            displaySoftLogoutMessage(withUserDisplayname: nil, andKeyBackupNeeded: keyBackupNeeded)
        })
    }

    func displaySoftLogoutMessage(withUserDisplayname userDisplayname: String?, andKeyBackupNeeded keyBackupNeeded: Bool) {
        // Use messageLabel for this message
        messageLabelTopConstraint.constant = 8
        messageLabel.textColor = ThemeService.shared.theme.textPrimaryColor
        messageLabel.isHidden = false

        let message = NSMutableAttributedString(
            string: NSLocalizedString("auth_softlogout_sign_in", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
            attributes: [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)
            ])

        message.append(NSAttributedString(string: "\n\n"))

        var string = String.localizedStringWithFormat(NSLocalizedString("auth_softlogout_reason", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), softLogoutCredentials.homeServerName, userDisplayname ?? "", softLogoutCredentials.userId() ?? "")
        message.append(
            NSAttributedString(
                string: string,
                attributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)
                ]))

        if keyBackupNeeded {
            message.append(NSAttributedString(string: "\n\n"))
            string = NSLocalizedString("auth_softlogout_recover_encryption_keys", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            message.append(
                NSAttributedString(
                    string: string,
                    attributes: [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)
                    ]))
        }

        messageLabel.attributedText = message
    }

    func areAllRequiredFieldsSet() -> Bool {
        // Keep enable the submit button.
        return true
    }

    func dismissKeyboard() {
        userLoginTextField.resignFirstResponder()
        passWordTextField.resignFirstResponder()
        emailTextField.resignFirstResponder()
        phoneTextField.resignFirstResponder()
        repeatPasswordTextField.resignFirstResponder()

        super.dismissKeyboard()
    }

    @objc func dismissCountryPicker() {
        phoneNumberCountryPicker?.withdrawViewController(animated: true, completion: nil)
        phoneNumberCountryPicker?.destroy()
        phoneNumberCountryPicker = nil

        phoneNumberPickerNavigationController?.dismiss(animated: true)
        phoneNumberPickerNavigationController = nil
    }

    func userId() -> String? {
        return userLoginTextField.text
    }

    func password() -> String? {
        return passWordTextField.text
    }

    @IBAction func selectPhoneNumberCountry(_ sender: Any) {
        if delegate.responds(to: #selector(AuthenticationViewController.authInputsView(_:present:animated:))) {
            phoneNumberCountryPicker = CountryPickerViewController()
            phoneNumberCountryPicker?.delegate = self
            phoneNumberCountryPicker?.showCountryCallingCode = true

            phoneNumberPickerNavigationController = RiotNavigationController()

            // Set Riot navigation bar colors
            ThemeService.shared.theme.applyStyle(on: phoneNumberPickerNavigationController?.navigationBar)

            if let phoneNumberCountryPicker = phoneNumberCountryPicker {
                phoneNumberPickerNavigationController?.pushViewController(phoneNumberCountryPicker, animated: false)
            }

            let leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "back_icon"), style: .plain, target: self, action: #selector(dismissCountryPicker))
            phoneNumberCountryPicker?.navigationItem.leftBarButtonItem = leftBarButtonItem

            delegate.authInputsView(self, present: phoneNumberPickerNavigationController, animated: true)
        }
    }

    func resetThirdPartyIdentifiers() {
        dismissKeyboard()

        emailTextField.text = nil
        phoneTextField.text = nil

        nbPhoneNumber = nil
    }

    // MARK: - MXKCountryPickerViewControllerDelegate

    func countryPickerViewController(_ countryPickerViewController: MXKCountryPickerViewController?, didSelectCountry isoCountryCode: String?) {
        self.isoCountryCode = isoCountryCode

        do {
            nbPhoneNumber = try NBPhoneNumberUtil.sharedInstance().parse(phoneTextField.text, defaultRegion: isoCountryCode)
        } catch {
        }
        formatNewPhoneNumber()

        dismissCountryPicker()
    }

    // MARK: - UITextField delegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == userLoginTextField && type == MXKAuthenticationTypeLogin {
            if MXTools.isMatrixUserIdentifier(userLoginTextField.text) {
                if delegate && delegate.responds(to: #selector(AuthenticationViewController.authInputsView(_:autoDiscoverServerWithDomain:))) {
                    let domain = userLoginTextField.text?.components(separatedBy: ":")[1]
                    delegate.authInputsView(self, autoDiscoverServerWithDomain: domain)
                }
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.returnKeyType == .done {
            // "Done" key has been pressed
            textField.resignFirstResponder()

            // Launch authentication now
            delegate.authInputsViewDidPressDoneKey(self)
        } else {
            //"Next" key has been pressed
            if textField == userLoginTextField || textField == phoneTextField {
                passWordTextField.becomeFirstResponder()
            } else if textField == passWordTextField {
                repeatPasswordTextField.becomeFirstResponder()
            } else if textField == emailTextField {
                phoneTextField.becomeFirstResponder()
            }
        }

        return true
    }

    // MARK: - TextField listener

    @IBAction func textFieldDidChange(_ sender: Any) {
        let textField = sender as? UITextField

        if textField == phoneTextField {
            do {
                nbPhoneNumber = try NBPhoneNumberUtil.sharedInstance().parse(phoneTextField.text, defaultRegion: isoCountryCode)
            } catch {
            }

            formatNewPhoneNumber()
        }
    }

    // MARK: -

    func hideInputsContainer() {
        // Hide all inputs container
        userLoginContainer.isHidden = true
        passwordContainer.isHidden = true
        emailContainer.isHidden = true
        phoneContainer.isHidden = true
        repeatPasswordContainer.isHidden = true

        // Hide other items
        messageLabelTopConstraint.constant = 8
        messageLabel.isHidden = true
        recaptchaContainer.isHidden = true
        termsView.hidden = true
        ssoButtonContainer.hidden = true

        currentLastContainer = nil
    }

    func formatNewPhoneNumber() {
        if let nbPhoneNumber = nbPhoneNumber {
            var formattedNumber: String? = nil
            do {
                formattedNumber = try NBPhoneNumberUtil.sharedInstance().format(nbPhoneNumber, numberFormat: NBEPhoneNumberFormatINTERNATIONAL)
            } catch {
            }
            let prefix = callingCodeLabel.text
            if formattedNumber?.hasPrefix(prefix ?? "") ?? false {
                // Format the display phone number
                phoneTextField.text = (formattedNumber as NSString?)?.substring(from: prefix?.count ?? 0)
            }
        }
    }

    func displayRecaptchaForm(_ callback: @escaping (_ response: String?) -> Void) -> Bool {
        // Retrieve the site key
        var siteKey: String?

        let recaptchaParams = currentSession.params[kMXLoginFlowTypeRecaptcha]
        if recaptchaParams != nil && (recaptchaParams is [AnyHashable : Any]) {
            let recaptchaParamsDict = recaptchaParams as? [AnyHashable : Any]
            siteKey = recaptchaParamsDict?["public_key"] as? String
        }

        // Retrieve the REST client from delegate
        var restClient: MXRestClient?

        if delegate && delegate.responds(to: Selector("authInputsViewThirdPartyIdValidationRestClient:")) {
            restClient = delegate.authInputsViewThirdPartyIdValidationRestClient(self)
        }

        // Sanity check
        if (siteKey?.count ?? 0) != 0 && restClient != nil && callback != nil {
            hideInputsContainer()

            messageLabel.isHidden = false
            messageLabel.text = NSLocalizedString("auth_recaptcha_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

            recaptchaContainer.isHidden = false
            currentLastContainer = recaptchaContainer

            // IB does not support WKWebview in a xib before iOS 11
            // So, add it by coding

            // Do some cleaning/reset before
            for view in recaptchaContainer.subviews {
                view.removeFromSuperview()
            }

            let reCaptchaWebView = MXKAuthenticationRecaptchaWebView()
            reCaptchaWebView.translatesAutoresizingMaskIntoConstraints = false
            recaptchaContainer.addSubview(reCaptchaWebView)

            // Disable the webview scrollView to avoid 2 scrollviews on the same screen
            reCaptchaWebView.scrollView.isScrollEnabled = false

            recaptchaContainer.addConstraints(
                NSLayoutConstraint.constraints(
                    withVisualFormat: "|-[view]-|",
                    options: [],
                    metrics: nil,
                    views: [
                        "view": reCaptchaWebView
                    ]))
            recaptchaContainer.addConstraints(
                NSLayoutConstraint.constraints(
                    withVisualFormat: "V:|-[view]-|",
                    options: [],
                    metrics: nil,
                    views: [
                        "view": reCaptchaWebView
                    ]))


            reCaptchaWebView.openRecaptchaWidget(withSiteKey: siteKey, fromHomeServer: restClient?.homeserver, callback: callback)

            return true
        }

        return false
    }

    // Tell whether a flow type is supported or not by this view.
    func isSupportedFlowType(_ flowType: MXLoginFlowType) -> Bool {
        if flowType.isEqual(toString: kMXLoginFlowTypePassword) {
            return true
        } else if flowType.isEqual(toString: kMXLoginFlowTypeEmailIdentity) {
            return true
        } else if flowType.isEqual(toString: kMXLoginFlowTypeRecaptcha) {
            return true
        } else if flowType.isEqual(toString: kMXLoginFlowTypeMSISDN) {
            return true
        } else if flowType.isEqual(toString: kMXLoginFlowTypeDummy) {
            return true
        } else if flowType.isEqual(toString: kMXLoginFlowTypeTerms) {
            return true
        } else if flowType.isEqual(toString: kMXLoginFlowTypeCAS) || flowType.isEqual(toString: kMXLoginFlowTypeSSO) {
            return true
        }

        return false
    }

    func validate(_ authSession: MXAuthenticationSession?) -> MXAuthenticationSession? {
        // Check whether the listed flows in this authentication session are supported
        var supportedFlows: [AnyHashable] = []

        if let flows = authSession?.flows {
            for flow in flows {
                guard let flow = flow as? MXLoginFlow else {
                    continue
                }
                // Check whether flow type is defined
                if flow.type {
                    if isSupportedFlowType(flow.type) {
                        // Check here all stages
                        var isSupported = true
                        if flow.stages.count {
                            for stage in flow.stages {
                                if isSupportedFlowType(stage) == false {
                                    MXLogDebug("[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? "login" : "register"), stage)
                                    isSupported = false
                                    break
                                }
                            }
                        } else {
                            flow.stages = [flow.type]
                        }

                        if isSupported {
                            supportedFlows.append(flow)
                        }
                    } else {
                        MXLogDebug("[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? "login" : "register"), flow.type)
                    }
                } else {
                    // Check here all stages
                    var isSupported = true
                    if flow.stages.count {
                        for stage in flow.stages {
                            if isSupportedFlowType(stage) == false {
                                MXLogDebug("[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? "login" : "register"), stage)
                                isSupported = false
                                break
                            }
                        }
                    }

                    if isSupported {
                        supportedFlows.append(flow)
                    }
                }
            }
        }

        if supportedFlows.count != 0 {
            if supportedFlows.count == authSession?.flows.count {
                // Return the original session.
                return authSession
            } else {
                // Keep only the supported flow.
                let updatedAuthSession = MXAuthenticationSession()
                updatedAuthSession.session = authSession?.session
                updatedAuthSession.params = authSession?.params
                updatedAuthSession.flows = supportedFlows
                return updatedAuthSession
            }
        }

        return nil
    }

    func showValidationMSISDNDialog(toPrepareParameters callback: @escaping (_ parameters: [AnyHashable : Any]?, _ error: Error?) -> Void) {
        weak var weakSelf = self

        if inputsAlert {
            inputsAlert.dismiss(animated: false)
        }

        if inputsAlert {
            inputsAlert.dismiss(animated: false)
        }

        inputsAlert = UIAlertController(title: NSLocalizedString("auth_msisdn_validation_title", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), message: NSLocalizedString("auth_msisdn_validation_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), preferredStyle: .alert)

        inputsAlert.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "cancel"),
                style: .default,
                handler: { [self] action in

                    if let weakSelf = weakSelf {
                        let self = weakSelf
                        inputsAlert = nil

                        if delegate && delegate.responds(to: #selector(AuthenticationViewController.authInputsViewDidCancelOperation(_:))) {
                            delegate.authInputsViewDidCancelOperation(self)
                        }
                    }

                }))

        inputsAlert.addTextField(configurationHandler: { textField in

            textField?.isSecureTextEntry = false
            textField?.placeholder = nil
            textField?.keyboardType = .decimalPad

        })

        inputsAlert.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "submit"),
                style: .default,
                handler: { [self] action in

                    if let weakSelf = weakSelf {
                        let self = weakSelf
                        let textField = inputsAlert.textFields?.first
                        let smsCode = textField?.text
                        inputsAlert = nil

                        if (smsCode?.count ?? 0) != 0 {
                            submittedMSISDN?.submitValidationToken(smsCode, success: { [self] in

                                // Retrieve the identity service from delegate
                                var identityService: MXIdentityService?

                                if delegate && delegate.responds(to: Selector("authInputsViewThirdPartyIdValidationIdentityService:")) {
                                    identityService = delegate.authInputsViewThirdPartyIdValidationIdentityService(self)
                                }

                                let identityServer = identityService?.identityServer

                                if let identityServer = identityServer {
                                    let identServerURL = URL(string: identityServer)
                                    var parameters: [AnyHashable : Any]?
                                    if let clientSecret = submittedMSISDN?.clientSecret, let sid = submittedMSISDN?.sid {
                                        parameters = [
                                            "auth": [
                                            "session": currentSession.session,
                                            "threepid_creds": [
                                            "client_secret": clientSecret,
                                            "id_server": identServerURL?.host ?? "",
                                            "sid": sid
                                        ],
                                            "type": kMXLoginFlowTypeMSISDN
                                        ],
                                            "username": userLoginTextField.text ?? "",
                                            "password": passWordTextField.text ?? ""
                                        ]
                                    }

                                    callback(parameters, nil)
                                } else {
                                    MXLogDebug("[AuthInputsView] Failed to retrieve identity server URL")
                                }

                            }, failure: { [self] error in

                                MXLogDebug("[AuthInputsView] Failed to submit the sms token")

                                // Ignore connection cancellation error
                                if ((error as NSError?)?.domain == NSURLErrorDomain) && (error as NSError?)?.code == Int(NSURLErrorCancelled) {
                                    return
                                }

                                // Alert user
                                var title = (error as NSError?)?.userInfo[NSLocalizedFailureReasonErrorKey] as? String
                                var msg = (error as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String
                                if title == nil {
                                    if msg != nil {
                                        title = msg
                                        msg = nil
                                    } else {
                                        title = Bundle.mxk_localizedString(forKey: "error")
                                    }
                                }

                                inputsAlert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

                                inputsAlert.addAction(
                                    UIAlertAction(
                                        title: Bundle.mxk_localizedString(forKey: "ok"),
                                        style: .default,
                                        handler: { [self] action in

                                            if weakSelf != nil {
                                                let self = weakSelf
                                                inputsAlert = nil

                                                // Ask again for the token
                                                showValidationMSISDNDialog(toPrepareParameters: callback)
                                            }

                                        }))

                                inputsAlert.mxk_setAccessibilityIdentifier("AuthInputsViewErrorAlert")
                                delegate.authInputsView(self, presentAlertController: inputsAlert)

                            })
                        } else {
                            // Ask again for the token
                            showValidationMSISDNDialog(toPrepareParameters: callback)
                        }
                    }

                }))

        inputsAlert.mxk_setAccessibilityIdentifier("AuthInputsViewMsisdnValidationAlert")
        delegate.authInputsView(self, presentAlertController: inputsAlert)
    }

    func displayTermsView(_ onAcceptedCallback: () -> ()) -> Bool {
        // Extract data
        let loginTermsData = currentSession.params[kMXLoginFlowTypeTerms] as? [AnyHashable : Any]
        let loginTerms: MXLoginTerms? = nil
        MXJSONModelSetMXJSONModel(loginTerms, MXLoginTerms.self, loginTermsData)

        if let loginTerms = loginTerms {
            hideInputsContainer()

            messageLabel.isHidden = false
            messageLabel.text = NSLocalizedString("auth_accept_policies", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

            termsView.hidden = false
            currentLastContainer = termsView

            termsView.delegate = delegate
            termsView.displayTerms(with: loginTerms, onAccepted: onAcceptedCallback)

            return true
        }

        return false
    }

    // MARK: - Flow state

    /// Check if a flow (kMXLoginFlowType*) is part of the required flows steps.
    /// - Parameter flow: the flow type to check.
    /// - Returns: YES if the the flow must be implemented.
    func isFlowSupported(_ flow: String?) -> Bool {
        for loginFlow in currentSession.flows {
            if (loginFlow.type == flow) || (loginFlow.stages.firstIndex(of: flow ?? "") ?? NSNotFound) != NSNotFound {
                return true
            }
        }

        return false
    }

    /// Check if a flow (kMXLoginFlowType*) has already been completed.
    /// - Parameter flow: the flow type to check.
    /// - Returns: YES if the the flow has been completedd.
    func isFlowCompleted(_ flow: String?) -> Bool {
        if currentSession.completed && (currentSession.completed.firstIndex(of: flow ?? "") ?? NSNotFound) != NSNotFound {
            return true
        }

        return false
    }

    func checkIdentityServerRequirement(
        _ mxRestClient: MXRestClient?,
        success: @escaping (_ identityServerRequired: Bool) -> Void,
        failure: @escaping (_ error: Error?) -> Void
    ) {
        mxRestClient?.supportedMatrixVersions({ matrixVersions in

            MXLogDebug("[AuthInputsView] checkIdentityServerRequirement: %@", matrixVersions?.doesServerRequireIdentityServerParam ? "YES" : "NO")
            success((matrixVersions?.doesServerRequireIdentityServerParam)!)

        }, failure: failure)
    }
}