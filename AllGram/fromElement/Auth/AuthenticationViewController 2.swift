//  Converted to Swift 5.4 by Swiftify v5.4.25812 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2020 New Vector Ltd

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
import UIKit

class AuthenticationViewController {
    /// The default country code used to initialize the mobile phone number input.
    private var defaultCountryCode: String?
    /// Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    private var kThemeServiceDidChangeThemeNotificationObserver: Any?
    /// Observe AppDelegateUniversalLinkDidChangeNotification to handle universal link changes.
    private var universalLinkDidChangeNotificationObserver: Any?
    /// Server discovery.
    private var autoDiscovery: MXAutoDiscovery?
    // successful login credentials
    private var loginCredentials: MXCredentials?
    // Check false display of this screen only once
    private var didCheckFalseAuthScreenDisplay = false
    
    private var authSession: MXAuthenticationSession?

    // MXKAuthenticationViewController has already a `delegate` member
    weak var authVCDelegate: AuthenticationViewControllerDelegate?
    @IBOutlet weak var navigationBackView: UIView!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var navigationBarSeparatorView: UIView!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var rightBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var optionsContainer: UIView!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var submitButtonMinLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var serverOptionsContainer: UIView!
    @IBOutlet weak var customServersTickButton: UIButton!
    @IBOutlet weak var customServersContainer: UIView!
    @IBOutlet weak var homeServerContainer: UIView!
    @IBOutlet weak var identityServerContainer: UIView!
    @IBOutlet weak var homeServerSeparator: UIView!
    @IBOutlet weak var identityServerSeparator: UIView!
    @IBOutlet weak var softLogoutClearDataContainer: UIView!
    @IBOutlet weak var softLogoutClearDataLabel: UILabel!
    @IBOutlet weak var softLogoutClearDataButton: UIButton!

    private var isIdentityServerConfigured: Bool {
//        return identityServerTextField.text.length > 0
        true
    }
    
    @IBOutlet private weak var socialLoginContainerView: UIView!
    // Current SSO flow containing Identity Providers. Used for `socialLoginListView`
    private var currentLoginSSOFlow: MXLoginSSOFlow?
    // Current SSO transaction id used to identify and validate the SSO authentication callback
    private var ssoCallbackTxnId: String?
    private var crossSigningService: CrossSigningService?
    private var firstViewAppearing = false
    private var errorPresenter: MXKErrorAlertPresentation?

    // MARK: -

    func finalizeInit() {
        
        // Set a default country code
        // Note: this value is used only when no MCC and no local country code is available.
        defaultCountryCode = "GB"

        didCheckFalseAuthScreenDisplay = false

        firstViewAppearing = true

        crossSigningService = CrossSigningService()
        errorPresenter = MXKErrorAlertPresentation()
    }

    func viewDidLoad() {

        let defaultHomeServerUrl = "https://allgram.me"

        let defaultIdentityServerUrl = "https://allgram.me"

        // Initialize the auth inputs display
        let authSession = MXAuthenticationSession(fromJSON: [
            "flows": [[
            "stages": [kMXLoginFlowTypePassword]
        ]]
        ])
        authInputsView.setAuthSession(authSession, withAuthType: MXKAuthenticationTypeLogin)
        
    }
    
    
    func setSoftLogoutCredentials(_ softLogoutCredentials: MXCredentials?) {

        // Customise the screen for soft logout
        customServersTickButton.isHidden = true
        rightBarButtonItem.title = nil
        mainNavigationItem.title = NSLocalizedString("auth_softlogout_signed_out", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

        showSoftLogoutClearDataContainer()
    }

    func showSoftLogoutClearDataContainer() {
        let message = NSMutableAttributedString(
            string: NSLocalizedString("auth_softlogout_clear_data", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
            attributes: [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)
            ])

        message.append(NSAttributedString(string: "\n\n"))

        let string = "\(NSLocalizedString("auth_softlogout_clear_data_message_1", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""))\n\n\(NSLocalizedString("auth_softlogout_clear_data_message_2", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""))"

        message.append(
            NSAttributedString(
                string: string,
                attributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)
                ]))
        softLogoutClearDataLabel.attributedText = message

        softLogoutClearDataContainer.isHidden = false
        refreshContentViewHeightConstraint()
    }

    /// Filter and prioritise flows supported by the app.
    /// - Parameter authSession: the auth session coming from the HS.
    /// - Returns: a new auth session
    func handleSupportedFlows(in authSession: MXAuthenticationSession?) -> MXAuthenticationSession? {
        var ssoFlow: MXLoginSSOFlow?
        var passwordFlow: MXLoginFlow?
        var supportedFlows: [AnyHashable] = []

        if let flows = authSession?.flows {
            for flow in flows {
                guard let flow = flow as? MXLoginFlow else {
                    continue
                }
                // Remove known flows we do not support
                if flow.type != kMXLoginFlowTypeToken {
                    supportedFlows.append(flow)
                }

                if flow.type == kMXLoginFlowTypePassword {
                    passwordFlow = flow
                }

                if flow is MXLoginSSOFlow {
                    ssoFlow = flow as? MXLoginSSOFlow
                }
            }
        }

        // Prioritise SSO over other flows
        if let ssoFlow = ssoFlow {
            supportedFlows.removeAll()
            supportedFlows.append(ssoFlow)

            // If the SSO contains Identity Providers list and password
            // Display both social login and password input
            if (ssoFlow.identityProviders.count != 0) && passwordFlow != nil {
                if let passwordFlow = passwordFlow {
                    supportedFlows.append(passwordFlow)
                }
            }
        }

        if supportedFlows.count != authSession?.flows.count {
            let updatedAuthSession = MXAuthenticationSession()
            updatedAuthSession.session = authSession?.session
            updatedAuthSession.params = authSession?.params
            updatedAuthSession.flows = supportedFlows as? [MXLoginFlow]
            return updatedAuthSession
        } else {
            return authSession
        }
    }

    func handle(_ authSession: MXAuthenticationSession?) {
        var authSession = authSession
        // Make some cleaning from the server response according to what the app supports
        authSession = handleSupportedFlows(in: authSession)

        currentLoginSSOFlow = logginSSOFlowWithProviders(fromFlows: authSession?.flows)
    }

    func isAuthSessionContainsPasswordFlow() -> Bool {
        var containsPassword = false

        if authSession != nil {
            containsPassword = containsPasswordFlow(inFlows: authSession!.flows)
        }

        return containsPassword
    }

    func containsPasswordFlow(inFlows loginFlows: [MXLoginFlow]?) -> Bool {
        for loginFlow in loginFlows ?? [] {
            if loginFlow.type == kMXLoginFlowTypePassword {
                return true
            }
        }

        return false
    }

    func logginSSOFlowWithProviders(fromFlows loginFlows: [MXLoginFlow]?) -> MXLoginSSOFlow? {
        var ssoFlowWithProviders: MXLoginSSOFlow?

        for loginFlow in loginFlows ?? [] {
            if loginFlow is MXLoginSSOFlow {
                let ssoFlow = loginFlow as? MXLoginSSOFlow

                if ((ssoFlow?.identityProviders.count) != nil) {
                    ssoFlowWithProviders = ssoFlow
                    break
                }
            }
        }

        return ssoFlowWithProviders
    }

    func onSuccessfulLogin(_ credentials: MXCredentials?) {
        //  Is pin protection forced?
        if PinCodePreferences.shared().forcePinProtection {
            loginCredentials = credentials

            var viewMode = SetPinCoordinatorViewModeSetPin as? SetPinCoordinatorViewMode
            switch authType {
            case MXKAuthenticationTypeLogin:
                viewMode = SetPinCoordinatorViewModeSetPinAfterLogin
            case MXKAuthenticationTypeRegister:
                viewMode = SetPinCoordinatorViewModeSetPinAfterRegister
            default:
                break
            }
        }

        afterSetPinFlowCompleted(with: credentials)
    }

    func afterSetPinFlowCompleted(with credentials: MXCredentials?) {
        // Check whether a third party identifiers has not been used
        if authInputsView is AuthInputsView {
            let authInputsview = authInputsView as? AuthInputsView
            if authInputsview?.isThirdPartyIdentifierPending ?? false {
                // Alert user
                if alert {
                    alert.dismiss(animated: false)
                }

                alert = UIAlertController(title: NSLocalizedString("warning", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), message: NSLocalizedString("auth_add_email_and_phone_warning", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), preferredStyle: .alert)

                alert.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "ok"),
                        style: .default,
                        handler: { action in

                            super.onSuccessfulLogin(credentials)

                        }))

                present(alert, animated: true)
                return
            }
        }

        super.onSuccessfulLogin(credentials)
    }

    // MARK: - MXKAuthenticationViewControllerDelegate

    func authenticationViewController(_ authenticationViewController: MXKAuthenticationViewController?, didLogWithUserId userId: String?) {

        let account = MXKAccountManager.shared().account(forUserId: userId)
        let session = account?.mxSession

        let botCreationEnabled = UserDefaults.standard.bool(forKey: "enableBotCreation")

        // Create DM with Riot-bot on new account creation.
        if authType == MXKAuthenticationTypeRegister && botCreationEnabled {
            let roomCreationParameters = MXRoomCreationParameters(user: "@riot-bot:matrix.org")
            session?.createRoom(with: roomCreationParameters, success: nil, failure: { error in
                MXLogDebug("[AuthenticationVC] Create chat with riot-bot failed")
            })
        }

        // Wait for session change to present complete security screen if needed
        registerSessionStateChangeNotification(for: session)
    }

    func registerSessionStateChangeNotification(for session: MXSession?) {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionStateDidChange(_:)), name: kMXSessionStateDidChangeNotification, object: session)
    }

    func unregisterSessionStateChangeNotification() {
        NotificationCenter.default.removeObserver(self, name: kMXSessionStateDidChangeNotification, object: nil)
    }

    @objc func sessionStateDidChange(_ notification: Notification?) {
        let session = notification?.object as? MXSession

        if session?.state == MXSessionStateStoreDataReady {
            if session?.crypto.crossSigning {
                // Do not make key share requests while the "Complete security" is not complete.
                // If the device is self-verified, the SDK will restore the existing key backup.
                // Then, it  will re-enable outgoing key share requests
                session?.crypto.setOutgoingKeyRequestsEnabled(false, onComplete: nil)
            }
        } else if session?.state == MXSessionStateRunning {
            unregisterSessionStateChangeNotification()

            if session?.crypto.crossSigning {
                session?.crypto.crossSigning.refreshState(withSuccess: { [self] stateUpdated in

                    MXLogDebug("[AuthenticationVC] sessionStateDidChange: crossSigning.state: %@", NSNumber(value: session?.crypto.crossSigning.state))

                    switch session?.crypto.crossSigning.state {
                    case MXCrossSigningStateNotBootstrapped:
                        // TODO: This is still not sure we want to disable the automatic cross-signing bootstrap
                        // if the admin disabled e2e by default.
                        // Do like riot-web for the moment
                        if session?.vc_homeserverConfiguration().isE2EEByDefaultEnabled {
                            // Bootstrap cross-signing on user's account
                            // We do it for both registration and new login as long as cross-signing does not exist yet
                            if authInputsView.password.length {
                                MXLogDebug("[AuthenticationVC] sessionStateDidChange: Bootstrap with password")

                                session?.crypto.crossSigning.setup(withPassword: authInputsView.password, success: { [self] in
                                    MXLogDebug("[AuthenticationVC] sessionStateDidChange: Bootstrap succeeded")
                                    dismiss()
                                }, failure: { [self] error in
                                    MXLogDebug("[AuthenticationVC] sessionStateDidChange: Bootstrap failed. Error: %@", error)
                                    session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
                                    dismiss()
                                })
                            } else {
                                // Try to setup cross-signing without authentication parameters in case if a grace period is enabled
                                crossSigningService?.setupCrossSigningWithoutAuthentication(for: session, success: { [self] in
                                    MXLogDebug("[AuthenticationVC] sessionStateDidChange: Bootstrap succeeded without credentials")
                                    dismiss()
                                }, failure: { [self] error in
                                    MXLogDebug("[AuthenticationVC] sessionStateDidChange: Do not know how to bootstrap cross-signing. Skip it.")
                                    session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
                                    dismiss()
                                })
                            }
                        } else {
                            session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
                            dismiss()
                        }
                    case MXCrossSigningStateCrossSigningExists:
                        MXLogDebug("[AuthenticationVC] sessionStateDidChange: Complete security")

                        // Ask the user to verify this session
                        userInteractionEnabled = true
                        authenticationActivityIndicator.stopAnimating()

                        presentCompleteSecurity(with: session)
                    default:
                        MXLogDebug("[AuthenticationVC] sessionStateDidChange: Nothing to do")
                        session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
                        dismiss()
                    }

                }, failure: { [self] error in
                    MXLogDebug("[AuthenticationVC] sessionStateDidChange: Fail to refresh crypto state with error: %@", error)
                    session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
                    dismiss()
                })
            } else {
                dismiss()
            }
        }
    }

    // MARK: - MXKAuthInputsViewDelegate

    @objc func authInputsView(_ authInputsView: MXKAuthInputsView?, present viewControllerToPresent: UIViewController?, animated: Bool) {
        dismissKeyboard()
        if let viewControllerToPresent = viewControllerToPresent {
            present(viewControllerToPresent, animated: animated)
        }
    }

    @objc func authInputsViewDidCancelOperation(_ authInputsView: MXKAuthInputsView?) {
        cancel()
    }

    @objc func authInputsView(_ authInputsView: MXKAuthInputsView?, autoDiscoverServerWithDomain domain: String?) {
        tryServerDiscovery(onDomain: domain)
    }

    // MARK: - Server discovery

    func tryServerDiscovery(onDomain domain: String?) {
        autoDiscovery = MXAutoDiscovery(domain: domain)

        MXWeakify(self)
        autoDiscovery?.findClientConfig({ [self] discoveredClientConfig in
            MXStrongifyAndReturnIfNil(self)

            autoDiscovery = nil

            switch discoveredClientConfig.action {
            case MXDiscoveredClientConfigActionPrompt:
                customiseServers(with: discoveredClientConfig.wellKnown)
            case MXDiscoveredClientConfigActionFailPrompt, MXDiscoveredClientConfigActionFailError:
                // Alert user
                if alert {
                    alert.dismiss(animated: false)
                }

                alert = UIAlertController(
                    title: NSLocalizedString("auth_autodiscover_invalid_response", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
                    message: nil,
                    preferredStyle: .alert)

                alert.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "ok"),
                        style: .default,
                        handler: { [self] action in

                            alert = nil
                        }))

                present(alert, animated: true)
            default:
                // Fail silently
                break
            }

        }, failure: { [self] error in
            MXStrongifyAndReturnIfNil(self)

            autoDiscovery = nil

            // Fail silently
        })
    }

    func customiseServers(with wellKnown: MXWellKnown?) {
        if customServersContainer.isHidden {
            // Check wellKnown data with application default servers
            // If different, use custom servers
            if (defaultHomeServerUrl != wellKnown?.homeServer.baseUrl) || (defaultIdentityServerUrl != wellKnown?.identityServer.baseUrl) {
                showCustomHomeserver(wellKnown?.homeServer.baseUrl, andIdentityServer: wellKnown?.identityServer.baseUrl)
            }
        } else {
            if (defaultHomeServerUrl == wellKnown?.homeServer.baseUrl) && (defaultIdentityServerUrl == wellKnown?.identityServer.baseUrl) {
                // wellKnown matches with application default servers
                // Hide custom servers
                hideCustomServers(true)
            } else {
                let customHomeServerURL = UserDefaults.standard.object(forKey: "customHomeServerURL") as? String
                let customIdentityServerURL = UserDefaults.standard.object(forKey: "customIdentityServerURL") as? String

                if (customHomeServerURL != wellKnown?.homeServer.baseUrl) || (customIdentityServerURL != wellKnown?.identityServer.baseUrl) {
                    // Update custom servers
                    showCustomHomeserver(wellKnown?.homeServer.baseUrl, andIdentityServer: wellKnown?.identityServer.baseUrl)
                }
            }
        }
    }

    func showCustomHomeserver(_ homeserver: String?, andIdentityServer identityServer: String?) {
        // Store the wellknown data into NSUserDefaults before displaying them
        UserDefaults.standard.set(homeserver, forKey: "customHomeServerURL")

        if let identityServer = identityServer {
            UserDefaults.standard.set(identityServer, forKey: "customIdentityServerURL")
        } else {
            UserDefaults.standard.removeObject(forKey: "customIdentityServerURL")
        }

        // And show custom servers
        hideCustomServers(false)
    }

    // MARK: - KeyVerificationCoordinatorBridgePresenterDelegate

    func keyVerificationCoordinatorBridgePresenterDelegateDidComplete(_ coordinatorBridgePresenter: KeyVerificationCoordinatorBridgePresenter, otherUserId: String, otherDeviceId: String) {
        let crypto = coordinatorBridgePresenter.session.crypto
        if !crypto?.backup.hasPrivateKeyInCryptoStore || !crypto?.backup.enabled {
            MXLogDebug("[AuthenticationVC][MXKeyVerification] requestAllPrivateKeys: Request key backup private keys")
            crypto?.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
        }
        dismiss()
    }

    func keyVerificationCoordinatorBridgePresenterDelegateDidCancel(_ coordinatorBridgePresenter: KeyVerificationCoordinatorBridgePresenter) {
        dismiss()
    }

    // MARK: - SetPinCoordinatorBridgePresenterDelegate

    func setPinCoordinatorBridgePresenterDelegateDidComplete(_ coordinatorBridgePresenter: SetPinCoordinatorBridgePresenter?) {
        coordinatorBridgePresenter?.dismissWith(animated: true, completion: nil)
        setPinCoordinatorBridgePresenter = nil

        afterSetPinFlowCompleted(with: loginCredentials)
    }

    func setPinCoordinatorBridgePresenterDelegateDidCancel(_ coordinatorBridgePresenter: SetPinCoordinatorBridgePresenter?) {
        //  enable the view again
        setUserInteractionEnabled(true)

        //  stop the spinner
        authenticationActivityIndicator.stopAnimating()

        //  then, just close the enter pin screen
        coordinatorBridgePresenter?.dismissWith(animated: true, completion: nil)
        setPinCoordinatorBridgePresenter = nil
    }

    // MARK: - Social login view management

    func isSocialLoginViewShown() -> Bool {
        return socialLoginListView?.superview && !socialLoginListView?.isHidden && currentLoginSSOFlow?.identityProviders.count
    }

    func socialLoginViewHeightFittingWidth(_ width: CGFloat) -> CGFloat {
        let identityProviders = currentLoginSSOFlow?.identityProviders

        if (identityProviders?.count ?? 0) == 0 && socialLoginListView != nil {
            return 0.0
        }

        return SocialLoginListView.contentViewHeight(withIdentityProviders: identityProviders, mode: socialLoginListView?.mode, fitting: contentView()?.frame.size.width)
    }

    func showSocialLoginView(with loginSSOFlow: MXLoginSSOFlow?, andMode mode: SocialLoginButtonMode) {
        var listView = socialLoginListView

        if listView == nil {
            listView = SocialLoginListView.instantiate()
            socialLoginContainerView.vc_addSubView(matchingParent: listView)
            socialLoginListView = listView
            listView?.delegate = self
        }

        listView?.update(with: loginSSOFlow?.identityProviders, mode: mode)

        refreshContentViewHeightConstraint()
    }

    func hideSocialLoginView() {
        socialLoginListView?.removeFromSuperview()
        refreshContentViewHeightConstraint()
    }

    func updateSocialLoginViewVisibility() {
        var socialLoginButtonMode = SocialLoginButtonModeContinue as? SocialLoginButtonMode

        var showSocialLoginView = currentLoginSSOFlow != nil ? true : false

        switch authType {
        case MXKAuthenticationTypeForgotPassword:
            showSocialLoginView = false
        case MXKAuthenticationTypeRegister:
            socialLoginButtonMode = SocialLoginButtonModeSignUp
        case MXKAuthenticationTypeLogin:
            if (authInputsView as? AuthInputsView)?.isSingleSignOnRequired ?? false {
                socialLoginButtonMode = SocialLoginButtonModeContinue
            } else {
                socialLoginButtonMode = SocialLoginButtonModeSignIn
            }
        default:
            break
        }

        if showSocialLoginView {
            if let socialLoginButtonMode = socialLoginButtonMode {
                self.showSocialLoginView(with: currentLoginSSOFlow, andMode: socialLoginButtonMode)
            }
        } else {
            hideSocialLoginView()
        }
    }

    // MARK: - SocialLoginListViewDelegate

    func socialLoginListView(_ socialLoginListView: SocialLoginListView?, didTapSocialButtonWithIdentifier identifier: String?) {
        presentSSOAuthentication(forIdentityProviderIdentifier: identifier)
    }

    // MARK: - SSOIdentityProviderAuthenticationPresenter

    func presentSSOAuthentication(forIdentityProviderIdentifier identityProviderIdentifier: String?) {
        let homeServerStringURL = homeServerTextField.text

        if homeServerStringURL == "" {
            return
        }

        let ssoAuthenticationService = SSOAuthenticationService(homeserverStringURL: homeServerStringURL)

        let presenter = SSOAuthenticationPresenter(ssoAuthenticationService: ssoAuthenticationService)

        presenter.delegate = self

        // Generate a unique identifier that will identify the success callback URL
        let transactionId = MXTools.generateTransactionId()

        presenter.present(forIdentityProviderIdentifier: identityProviderIdentifier, with: transactionId, from: self, animated: true)

        ssoCallbackTxnId = transactionId
        ssoAuthenticationPresenter = presenter
    }

    func presentDefaultSSOAuthentication() {
        presentSSOAuthentication(forIdentityProviderIdentifier: nil)
    }

    func dismissSSOAuthenticationPresenter() {
        ssoAuthenticationPresenter?.dismissWith(animated: true, completion: nil)
        ssoAuthenticationPresenter = nil
    }

    // TODO: Move to SDK
    func login(withToken loginToken: String?) {
        let parameters = [
            "type": kMXLoginFlowTypeToken,
            "token": loginToken ?? ""
        ]

        login(withParameters: parameters)
    }

    // MARK: - SSOAuthenticationPresenterDelegate

    func ssoAuthenticationPresenterDidCancel(_ presenter: SSOAuthenticationPresenter?) {
        dismissSSOAuthenticationPresenter()
    }

    func ssoAuthenticationPresenter(_ presenter: SSOAuthenticationPresenter?, authenticationDidFailWithError error: Error?) {
        dismissSSOAuthenticationPresenter()
        errorPresenter?.presentError(from: self, forError: error, animated: true, handler: nil)
    }

    func ssoAuthenticationPresenter(_ presenter: SSOAuthenticationPresenter?, authenticationSucceededWithToken token: String?) {
        dismissSSOAuthenticationPresenter()
        login(withToken: token)
    }
}

@objc protocol AuthenticationViewControllerDelegate: NSObjectProtocol {
    func authenticationViewControllerDidDismiss(_ authenticationViewController: AuthenticationViewController?)
}
