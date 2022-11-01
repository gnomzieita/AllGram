//  Converted to Swift 5.4 by Swiftify v5.4.25812 - https://swiftify.com/
/*
 Copyright 2016 OpenMarket Ltd

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

class ForgotPasswordInputsView: MXKAuthInputsView {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passWordTextField: UITextField!
    @IBOutlet weak var repeatPasswordTextField: UITextField!
    @IBOutlet weak var emailContainer: UIView!
    @IBOutlet weak var passwordContainer: UIView!
    @IBOutlet weak var repeatPasswordContainer: UIView!
    @IBOutlet weak var emailSeparator: UIView!
    @IBOutlet weak var passwordSeparator: UIView!
    @IBOutlet weak var repeatPasswordSeparator: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var nextStepButton: UIButton!
    private var mxCurrentOperation: MXHTTPOperation?
    /// The current set of parameters ready to use.
    private var parameters: [AnyHashable : Any]?
    /// The block called when the parameters are ready and the user confirms he has checked his email.
    private var didPrepareParametersCallback: ((_ parameters: [AnyHashable : Any]?, _ error: Error?) -> Void)?

    class func nib() -> UINib? {
        return UINib(
            nibName: NSStringFromClass(self.self),
            bundle: Bundle(for: ForgotPasswordInputsView))
    }

    func awakeFromNib() {
        super.awakeFromNib()

        nextStepButton.setTitle(Bundle.mxk_localizedString(forKey: "auth_reset_password_next_step_button"), for: .normal)
        nextStepButton.setTitle(Bundle.mxk_localizedString(forKey: "auth_reset_password_next_step_button"), for: .highlighted)
        nextStepButton.isEnabled = true

        emailTextField.placeholder = NSLocalizedString("auth_email_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        passWordTextField.placeholder = NSLocalizedString("auth_new_password_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        repeatPasswordTextField.placeholder = NSLocalizedString("auth_repeat_new_password_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

        // Apply placeholder color
        customizeRendering()
    }

    func destroy() {
        super.destroy()

        mxCurrentOperation = nil

        parameters = nil
        didPrepareParametersCallback = nil
    }

    func layoutSubviews() {
        super.layoutSubviews()

        var lastItemFrame: CGRect

        if !repeatPasswordContainer.isHidden {
            lastItemFrame = repeatPasswordContainer.frame
        } else if !nextStepButton.isHidden {
            lastItemFrame = nextStepButton.frame
        } else {
            lastItemFrame = messageLabel.frame
        }

        viewHeightConstraint.constant = lastItemFrame.origin.y + lastItemFrame.size.height
    }

    // MARK: - Override MXKView

    func customizeRendering() {
        super.customizeRendering()

        messageLabel.textColor = ThemeService.shared.theme.textPrimaryColor

        emailTextField.textColor = ThemeService.shared.theme.textPrimaryColor
        passWordTextField.textColor = ThemeService.shared.theme.textPrimaryColor
        repeatPasswordTextField.textColor = ThemeService.shared.theme.textPrimaryColor

        emailSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor
        passwordSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor
        repeatPasswordSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor

        messageLabel.numberOfLines = 0

        nextStepButton.layer.cornerRadius = 5
        nextStepButton.clipsToBounds = true
        nextStepButton.backgroundColor = ThemeService.shared.theme.tintColor

        if emailTextField.placeholder != nil {
            emailTextField.attributedPlaceholder = NSAttributedString(
                string: emailTextField.placeholder ?? "",
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
        if repeatPasswordTextField.placeholder != nil {
            repeatPasswordTextField.attributedPlaceholder = NSAttributedString(
                string: repeatPasswordTextField.placeholder ?? "",
                attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                ])
        }
    }

    // MARK: -

    func setAuthSession(_ authSession: MXAuthenticationSession?, withAuthType authType: MXKAuthenticationType) -> Bool {
        if authType == MXKAuthenticationTypeForgotPassword {
            type = MXKAuthenticationTypeForgotPassword

            // authSession is not used here, filled it by default (it should be nil).
            currentSession = authSession

            // Reset UI in initial step
            reset()

            return true
        }

        return false
    }

    func validateParameters() -> String? {
        // Check the validity of the parameters
        var errorMsg: String? = nil

        if (emailTextField.text?.count ?? 0) == 0 {
            MXLogDebug("[ForgotPasswordInputsView] Missing email")
            errorMsg = NSLocalizedString("auth_reset_password_missing_email", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        } else if (passWordTextField.text?.count ?? 0) == 0 {
            MXLogDebug("[ForgotPasswordInputsView] Missing Passwords")
            errorMsg = NSLocalizedString("auth_reset_password_missing_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        } else if (passWordTextField.text?.count ?? 0) < 6 {
            MXLogDebug("[ForgotPasswordInputsView] Invalid Passwords")
            errorMsg = NSLocalizedString("auth_invalid_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        } else if (repeatPasswordTextField.text == passWordTextField.text) == false {
            MXLogDebug("[ForgotPasswordInputsView] Passwords don't match")
            errorMsg = NSLocalizedString("auth_password_dont_match", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        } else {
            // Check validity of the non empty email
            if MXTools.isEmailAddress(emailTextField.text) == false {
                MXLogDebug("[ForgotPasswordInputsView] Invalid email")
                errorMsg = NSLocalizedString("auth_invalid_email", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            }
        }

        return errorMsg
    }

    func prepareParameters(_ callback: @escaping (_ parameters: [AnyHashable : Any]?, _ error: Error?) -> Void) {
        if callback != nil {
            // Prepare here parameters dict by checking each required fields.
            parameters = nil
            didPrepareParametersCallback = nil

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
                // Retrieve the REST client from delegate
                var restClient: MXRestClient?

                if delegate && delegate.responds(to: Selector("authInputsViewThirdPartyIdValidationRestClient:")) {
                    restClient = delegate.authInputsViewThirdPartyIdValidationRestClient(self)
                }

                if let restClient = restClient {
                    checkIdentityServerRequirement(restClient, success: { [self] in

                        // Launch email validation
                        let clientSecret = MXTools.generateSecret()

                        weak var weakSelf = self
                        restClient.forgetPassword(
                            forEmail: emailTextField.text,
                            clientSecret: clientSecret,
                            sendAttempt: 1,
                            success: { sid in
                                let strongSelf = weakSelf
                                if let strongSelf = strongSelf {
                                    strongSelf?.didPrepareParametersCallback = callback

                                    var threepidCreds = [
                                        "client_secret": clientSecret,
                                        "sid": sid ?? ""
                                    ]
                                    if restClient.identityServer {
                                        let identServerURL = URL(string: restClient.identityServer)
                                        threepidCreds["id_server"] = identServerURL?.host ?? ""
                                    }

                                    strongSelf?.parameters = [
                                        "auth": [
                                        "threepid_creds": threepidCreds,
                                        "type": kMXLoginFlowTypeEmailIdentity
                                    ],
                                        "new_password": strongSelf.passWordTextField.text ?? ""
                                    ]

                                    strongSelf.hideInputsContainer()

                                    strongSelf?.messageLabel.text = String.localizedStringWithFormat(NSLocalizedString("auth_reset_password_email_validation_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), strongSelf.emailTextField.text ?? "")

                                    strongSelf?.messageLabel.isHidden = false

                                    strongSelf.nextStepButton.addTarget(
                                        strongSelf,
                                        action: #selector(didCheckEmail(_:)),
                                        for: .touchUpInside)

                                    strongSelf?.nextStepButton.isHidden = false
                                }
                            },
                            failure: { [self] error in
                                MXLogDebug("[ForgotPasswordInputsView] Failed to request email token")

                                // Ignore connection cancellation error
                                if ((error as NSError?)?.domain == NSURLErrorDomain) && (error as NSError?)?.code == Int(NSURLErrorCancelled) {
                                    return
                                }

                                var errorMessage: String?

                                // Translate the potential MX error.
                                let mxError = MXError(nsError: error)
                                if mxError != nil && (mxError.errcode == kMXErrCodeStringThreePIDNotFound) {
                                    errorMessage = NSLocalizedString("auth_email_not_found", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                } else if mxError != nil && (mxError.errcode == kMXErrCodeStringServerNotTrusted) {
                                    errorMessage = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                                } else if (error as NSError?)?.userInfo["error"] != nil {
                                    errorMessage = (error as NSError?)?.userInfo["error"] as? String
                                } else {
                                    errorMessage = error?.localizedDescription
                                }

                                if let weakSelf = weakSelf {
                                    let self = weakSelf

                                    if inputsAlert {
                                        inputsAlert.dismiss(animated: false)
                                    }

                                    inputsAlert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "error"), message: errorMessage, preferredStyle: .alert)

                                    inputsAlert.addAction(
                                        UIAlertAction(
                                            title: Bundle.mxk_localizedString(forKey: "ok"),
                                            style: .default,
                                            handler: { [self] action in

                                                if weakSelf != nil {
                                                    let self = weakSelf
                                                    inputsAlert = nil
                                                    if delegate && delegate.responds(to: #selector(AuthenticationViewController.authInputsViewDidCancelOperation(_:))) {
                                                        delegate.authInputsViewDidCancelOperation(self)
                                                    }
                                                }

                                            }))

                                    delegate.authInputsView(self, presentAlertController: inputsAlert)
                                }
                            })
                    }, failure: { error in
                        callback(nil, error!)
                    })

                    // Async response
                    return
                } else {
                    MXLogDebug("[ForgotPasswordInputsView] Operation failed during the email identity stage")
                }
            }

            callback(nil, NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
            ]))
        }
    }

    func areAllRequiredFieldsSet() -> Bool {
        // Keep enable the submit button.
        return true
    }

    func dismissKeyboard() {
        passWordTextField.resignFirstResponder()
        emailTextField.resignFirstResponder()
        repeatPasswordTextField.resignFirstResponder()

        super.dismissKeyboard()
    }

    func password() -> String? {
        return passWordTextField.text
    }

    func nextStep() {
        // Here the password has been reseted with success
        didPrepareParametersCallback = nil
        parameters = nil

        hideInputsContainer()

        messageLabel.text = String.localizedStringWithFormat(NSLocalizedString("auth_reset_password_success_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), emailTextField.text ?? "")

        messageLabel.isHidden = false
    }

    // MARK: - Internals

    func reset() {
        // Cancel email validation request
        mxCurrentOperation?.cancel()
        mxCurrentOperation = nil

        parameters = nil
        didPrepareParametersCallback = nil

        // Reset UI by hidding all items
        hideInputsContainer()

        messageLabel.text = NSLocalizedString("auth_reset_password_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        messageLabel.isHidden = false

        emailContainer.isHidden = false
        passwordContainer.isHidden = false
        repeatPasswordContainer.isHidden = false

        layoutIfNeeded()
    }

    func checkIdentityServerRequirement(_ mxRestClient: MXRestClient?, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        mxRestClient?.supportedMatrixVersions({ matrixVersions in

            MXLogDebug("[ForgotPasswordInputsView] checkIdentityServerRequirement: %@", matrixVersions?.doesServerRequireIdentityServerParam ? "YES" : "NO")

            if matrixVersions?.doesServerRequireIdentityServerParam && !mxRestClient?.identityServer {
                failure(
                    NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "auth_reset_password_error_is_required")
                                    ]))
            } else {
                success()
            }

        }, failure: failure)
    }

    // MARK: - actions

    @objc func didCheckEmail(_ sender: Any?) {
        if (sender as? UIButton) == nextStepButton {
            if let didPrepareParametersCallback = didPrepareParametersCallback {
                didPrepareParametersCallback(parameters, nil)
            }
        }
    }

    // MARK: - UITextField delegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.returnKeyType == .done {
            // "Done" key has been pressed
            textField.resignFirstResponder()

            // Launch authentication now
            delegate.authInputsViewDidPressDoneKey(self)
        } else {
            //"Next" key has been pressed
            if textField == emailTextField {
                passWordTextField.becomeFirstResponder()
            } else if textField == passWordTextField {
                repeatPasswordTextField.becomeFirstResponder()
            }
        }

        return true
    }

    // MARK: -

    func hideInputsContainer() {
        // Hide all inputs container
        passwordContainer.isHidden = true
        emailContainer.isHidden = true
        repeatPasswordContainer.isHidden = true

        // Hide other items
        messageLabel.isHidden = true
        nextStepButton.isHidden = true
    }
}
