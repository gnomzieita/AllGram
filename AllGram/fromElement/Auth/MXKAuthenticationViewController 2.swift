//  Converted to Swift 5.4 by Swiftify v5.4.25812 - https://swiftify.com/
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

import AFNetworking
import UIKit
import MatrixSDK

/// `MXKAuthenticationViewController` delegate.
@objc protocol MXKAuthenticationViewControllerDelegate: NSObjectProtocol {
    /// Tells the delegate the authentication process succeeded to add a new account.
    /// - Parameters:
    ///   - authenticationViewController: the `MXKAuthenticationViewController` instance.
    ///   - userId: the user id of the new added account.
    func authenticationViewController(_ authenticationViewController: MXKAuthenticationViewController?, didLogWithUserId userId: String?)
}

/// This view controller should be used to manage registration or login flows with matrix homeserver.
/// Only the flow based on password is presently supported. Other flows should be added later.
/// You may add a delegate to be notified when a new account has been added successfully.
class MXKAuthenticationViewController: MXKViewController, UITextFieldDelegate, MXKAuthInputsViewDelegate {
    /// Reference to any opened alert view.
    var alert: UIAlertController?
    /// Tell whether the password has been reseted with success.
    /// Used to return on login screen on submit button pressed.
    var isPasswordReseted = false

    /// The matrix REST client used to make matrix API requests.
    private var mxRestClient: MXRestClient?
    /// Current request in progress.
    private var mxCurrentOperation: MXHTTPOperation?
    /// The MXKAuthInputsView class or a sub-class used when logging in.
    private var loginAuthInputsViewClass: AnyClass?
    /// The MXKAuthInputsView class or a sub-class used when registering.
    private var registerAuthInputsViewClass: AnyClass?
    /// The MXKAuthInputsView class or a sub-class used to handle forgot password case.
    private var forgotPasswordAuthInputsViewClass: AnyClass?
    /// Customized block used to handle unrecognized certificate (nil by default).
    private var onUnrecognizedCertificateCustomBlock: MXHTTPClientOnUnrecognizedCertificate?
    /// The current authentication fallback URL (if any).
    private var authenticationFallback: String?
    /// The cancel button added in navigation bar when fallback page is opened.
    private var cancelFallbackBarButton: UIBarButtonItem?
    /// The timer used to postpone the registration when the authentication is pending (for example waiting for email validation)
    private var registrationTimer: Timer?
    /// Identity Server discovery.
    private var autoDiscovery: MXAutoDiscovery?
    private var checkIdentityServerOperation: MXHTTPOperation?

    @IBOutlet weak var welcomeImageView: UIImageView!
    @IBOutlet var authenticationScrollView: UIScrollView!
    @IBOutlet weak var authScrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var subTitleLabel: UILabel!
    @IBOutlet weak var authInputsContainerView: UIView!
    @IBOutlet weak var authInputContainerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var authInputContainerViewMinHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var homeServerLabel: UILabel!
    @IBOutlet weak var homeServerTextField: UITextField!
    @IBOutlet weak var homeServerInfoLabel: UILabel!
    @IBOutlet weak var identityServerContainer: UIView!
    @IBOutlet weak var identityServerLabel: UILabel!
    @IBOutlet weak var identityServerTextField: UITextField!
    @IBOutlet weak var identityServerInfoLabel: UILabel!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var authSwitchButton: UIButton!
    @IBOutlet var authenticationActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var authenticationActivityIndicatorContainerView: UIView!
    @IBOutlet weak var noFlowLabel: UILabel!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var authFallbackContentView: UIView!
    //  WKWebView is not available to be created from xib because of NSCoding support below iOS 11. So we're using a container view.
    // See this: https://stackoverflow.com/questions/46221577/xcode-9-gm-wkwebview-nscoding-support-was-broken-in-previous-versions
    @IBOutlet weak var authFallbackWebViewContainer: UIView!
    var authFallbackWebView: MXKAuthenticationFallbackWebView?
    @IBOutlet weak var cancelAuthFallbackButton: UIButton!
    /// The current authentication type (MXKAuthenticationTypeLogin by default).

    private var _authType: MXKAuthenticationType?
    var authType: MXKAuthenticationType {
        get {
            _authType
        }
        set(authType) {
            if _authType != authType {
                _authType = authType

                // Cancel external registration parameters if any
                externalRegistrationParameters = nil

                // Remove the current inputs view
                authInputsView = nil

                isPasswordReseted = false

                authInputsContainerView.bringSubviewToFront(authenticationActivityIndicator)
                authenticationActivityIndicator.startAnimating()
            }

            // Restore user interaction
            userInteractionEnabled = true

            if authType == MXKAuthenticationTypeLogin {
                subTitleLabel.isHidden = true
                submitButton.setTitle(Bundle.mxk_localizedString(forKey: "login"), for: .normal)
                submitButton.setTitle(Bundle.mxk_localizedString(forKey: "login"), for: .highlighted)
                authSwitchButton.setTitle(Bundle.mxk_localizedString(forKey: "create_account"), for: .normal)
                authSwitchButton.setTitle(Bundle.mxk_localizedString(forKey: "create_account"), for: .highlighted)

                // Update supported authentication flow and associated information (defined in authentication session)
                refreshAuthenticationSession()
            } else if authType == MXKAuthenticationTypeRegister {
                subTitleLabel.isHidden = false
                subTitleLabel.text = Bundle.mxk_localizedString(forKey: "login_create_account")
                submitButton.setTitle(Bundle.mxk_localizedString(forKey: "sign_up"), for: .normal)
                submitButton.setTitle(Bundle.mxk_localizedString(forKey: "sign_up"), for: .highlighted)
                authSwitchButton.setTitle(Bundle.mxk_localizedString(forKey: "back"), for: .normal)
                authSwitchButton.setTitle(Bundle.mxk_localizedString(forKey: "back"), for: .highlighted)

                // Update supported authentication flow and associated information (defined in authentication session)
                refreshAuthenticationSession()
            } else if authType == MXKAuthenticationTypeForgotPassword {
                subTitleLabel.isHidden = true

                if isPasswordReseted {
                    submitButton.setTitle(Bundle.mxk_localizedString(forKey: "back"), for: .normal)
                    submitButton.setTitle(Bundle.mxk_localizedString(forKey: "back"), for: .highlighted)
                } else {
                    submitButton.setTitle(Bundle.mxk_localizedString(forKey: "submit"), for: .normal)
                    submitButton.setTitle(Bundle.mxk_localizedString(forKey: "submit"), for: .highlighted)

                    refreshForgotPasswordSession()
                }

                authSwitchButton.setTitle(Bundle.mxk_localizedString(forKey: "back"), for: .normal)
                authSwitchButton.setTitle(Bundle.mxk_localizedString(forKey: "back"), for: .highlighted)
            }

            checkIdentityServer()
        }
    }
    /// The view in which authentication inputs are displayed (`MXKAuthInputsView-inherited` instance).

    private var _authInputsView: MXKAuthInputsView?
    var authInputsView: MXKAuthInputsView? {
        get {
            _authInputsView
        }
        set(authInputsView) {
            // Here a new view will be loaded, hide first subviews which depend on auth flow
            submitButton.isHidden = true
            noFlowLabel.isHidden = true
            retryButton.isHidden = true

            if _authInputsView != nil {
                _authInputsView?.removeObserver(self, forKeyPath: "viewHeightConstraint.constant")

                if NSLayoutConstraint.responds(to: #selector(NSLayoutConstraint.deactivate(_:))) {
                    if let constraints = _authInputsView?.constraints {
                        NSLayoutConstraint.deactivate(constraints)
                    }
                } else {
                    if let constraints = _authInputsView?.constraints {
                        authInputsContainerView.removeConstraints(constraints)
                    }
                }

                _authInputsView?.removeFromSuperview()
                _authInputsView?.delegate = nil
                _authInputsView?.destroy()
                _authInputsView = nil
            }

            _authInputsView = authInputsView

            let previousInputsContainerViewHeight = authInputContainerViewHeightConstraint.constant

            if let _authInputsView = _authInputsView {
                _authInputsView?.translatesAutoresizingMaskIntoConstraints = false
                authInputsContainerView.addSubview(_authInputsView)

                _authInputsView?.delegate = self

                submitButton.isHidden = false
                _authInputsView?.hidden = false

                authInputContainerViewHeightConstraint.constant = _authInputsView.viewHeightConstraint.constant

                let topConstraint = NSLayoutConstraint(
                    item: authInputsContainerView,
                    attribute: .top,
                    relatedBy: .equal,
                    toItem: _authInputsView,
                    attribute: .top,
                    multiplier: 1.0,
                    constant: 0.0)


                let leadingConstraint = NSLayoutConstraint(
                    item: authInputsContainerView,
                    attribute: .leading,
                    relatedBy: .equal,
                    toItem: _authInputsView,
                    attribute: .leading,
                    multiplier: 1.0,
                    constant: 0.0)

                let trailingConstraint = NSLayoutConstraint(
                    item: authInputsContainerView,
                    attribute: .trailing,
                    relatedBy: .equal,
                    toItem: _authInputsView,
                    attribute: .trailing,
                    multiplier: 1.0,
                    constant: 0.0)


                if NSLayoutConstraint.responds(to: #selector(NSLayoutConstraint.activate(_:))) {
                    NSLayoutConstraint.activate([topConstraint, leadingConstraint, trailingConstraint])
                } else {
                    authInputsContainerView.addConstraint(topConstraint)
                    authInputsContainerView.addConstraint(leadingConstraint)
                    authInputsContainerView.addConstraint(trailingConstraint)
                }

                _authInputsView.addObserver(self, forKeyPath: "viewHeightConstraint.constant", options: 0, context: nil)
            } else {
                // No input fields are displayed
                authInputContainerViewHeightConstraint.constant = authInputContainerViewMinHeightConstraint.constant
            }

            view.layoutIfNeeded()

            // Refresh content view height by considering the updated height of inputs container
            contentViewHeightConstraint.constant += authInputContainerViewHeightConstraint.constant - previousInputsContainerViewHeight
        }
    }
    /// The default homeserver url (nil by default).

    private var _defaultHomeServerUrl: String?
    var defaultHomeServerUrl: String? {
        get {
            _defaultHomeServerUrl
        }
        set(defaultHomeServerUrl) {
            _defaultHomeServerUrl = defaultHomeServerUrl

            if (homeServerTextField.text?.count ?? 0) == 0 {
                setHomeServerTextFieldText(defaultHomeServerUrl)
            }
        }
    }
    /// The default identity server url (nil by default).

    private var _defaultIdentityServerUrl: String?
    var defaultIdentityServerUrl: String? {
        get {
            _defaultIdentityServerUrl
        }
        set(defaultIdentityServerUrl) {
            _defaultIdentityServerUrl = defaultIdentityServerUrl

            if (identityServerTextField.text?.count ?? 0) == 0 {
                setIdentityServerTextFieldText(defaultIdentityServerUrl)
            }
        }
    }
    /// Force a registration process based on a predefined set of parameters.
    /// Use this property to pursue a registration from the next_link sent in an email validation email.

    private var _externalRegistrationParameters: [AnyHashable : Any]?
    var externalRegistrationParameters: [AnyHashable : Any]? {
        get {
            _externalRegistrationParameters
        }
        set(parameters) {
            if (parameters?.count ?? 0) != 0 {
                MXLogDebug("[MXKAuthenticationVC] setExternalRegistrationParameters")

                // Cancel the current operation if any.
                cancel()

                // Load the view controller’s view if it has not yet been loaded.
                // This is required before updating view's textfields (homeserver url...)
                loadViewIfNeeded()

                // Force register mode
                authType = MXKAuthenticationTypeRegister

                // Apply provided homeserver if any
                let hs_url = parameters?["hs_url"]
                var homeserverURL: String? = nil
                if hs_url != nil && (hs_url is NSString) {
                    homeserverURL = hs_url as? String
                }
                setHomeServerTextFieldText(homeserverURL)

                // Apply provided identity server if any
                let is_url = parameters?["is_url"]
                var identityURL: String? = nil
                if is_url != nil && (is_url is NSString) {
                    identityURL = is_url as? String
                }
                setIdentityServerTextFieldText(identityURL)

                // Disable user interaction
                userInteractionEnabled = false

                // Cancel potential request in progress
                mxCurrentOperation?.cancel()
                mxCurrentOperation = nil

                // Remove the current auth inputs view
                authInputsView = nil

                // Set external parameters and trigger a refresh (the parameters will be taken into account during [handleAuthenticationSession:])
                _externalRegistrationParameters = parameters
                refreshAuthenticationSession()
            } else {
                MXLogDebug("[MXKAuthenticationVC] reset externalRegistrationParameters")
                _externalRegistrationParameters = nil

                // Restore default UI
                #warning("Swiftify: Skipping redundant initializing to itself")
                //authType = authType
            }
        }
    }
    /// Use a login process based on the soft logout credentials.

    private var _softLogoutCredentials: MXCredentials?
    var softLogoutCredentials: MXCredentials? {
        get {
            _softLogoutCredentials
        }
        set(softLogoutCredentials) {
            MXLogDebug("[MXKAuthenticationVC] setSoftLogoutCredentials")

            // Cancel the current operation if any.
            cancel()

            // Load the view controller’s view if it has not yet been loaded.
            // This is required before updating view's textfields (homeserver url...)
            loadViewIfNeeded()

            // Force register mode
            authType = MXKAuthenticationTypeLogin

            setHomeServerTextFieldText(softLogoutCredentials?.homeServer)
            setIdentityServerTextFieldText(softLogoutCredentials?.identityServer)

            // Cancel potential request in progress
            mxCurrentOperation?.cancel()
            mxCurrentOperation = nil

            // Remove the current auth inputs view
            authInputsView = nil

            // Set parameters and trigger a refresh (the parameters will be taken into account during [handleAuthenticationSession:])
            _softLogoutCredentials = softLogoutCredentials
            refreshAuthenticationSession()
        }
    }
    /// Enable/disable overall the user interaction option.
    /// It is used during authentication process to prevent multiple requests.

    private var _userInteractionEnabled = false
    var userInteractionEnabled: Bool {
        get {
            _userInteractionEnabled
        }
        set(userInteractionEnabled) {
            submitButton.isEnabled = userInteractionEnabled && authInputsView?.areAllRequiredFieldsSet
            authSwitchButton.isEnabled = userInteractionEnabled

            homeServerTextField.isEnabled = userInteractionEnabled
            identityServerTextField.isEnabled = userInteractionEnabled

            _userInteractionEnabled = userInteractionEnabled
        }
    }
    /// The device name used to display it in the user's devices list (nil by default).
    /// If nil, the device display name field is filled with a default string: "Mobile", "Tablet"...

    private var _deviceDisplayName: String?
    var deviceDisplayName: String? {
        if let _deviceDisplayName = _deviceDisplayName {
            return _deviceDisplayName
        }

        #if os(iOS)
        let deviceName = (UIDevice.current.model == "iPad") ? Bundle.mxk_localizedString(forKey: "login_tablet_device") : Bundle.mxk_localizedString(forKey: "login_mobile_device")
        #elseif os(macOS)
        let deviceName = Bundle.mxk_localizedString(forKey: "login_desktop_device")
        #endif

        return deviceName
    }
    /// The delegate for the view controller.
    weak var delegate: MXKAuthenticationViewControllerDelegate?
    /// current ongoing MXHTTPOperation. Nil if none.

    var currentHttpOperation: MXHTTPOperation? {
        return mxCurrentOperation
    }
    private var identityService: MXIdentityService?

    /// Returns the `UINib` object initialized for a `MXKAuthenticationViewController`.
    /// - Returns: The initialized `UINib` object or `nil` if there were errors during initialization
    /// or the nib file could not be located.
    /// - Remark: You may override this method to provide a customized nib. If you do,
    /// you should also override `authenticationViewController` to return your
    /// view controller loaded from your custom nib.

    // MARK: - Class methods

    class func nib() -> UINib? {
        return UINib(
            nibName: NSStringFromClass(MXKAuthenticationViewController.self.self),
            bundle: Bundle(for: MXKAuthenticationViewController.self))
    }

    /// Creates and returns a new `MXKAuthenticationViewController` object.
    /// - Remark: This is the designated initializer for programmatic instantiation.
    /// - Returns: An initialized `MXKAuthenticationViewController` object if successful, `nil` otherwise.
    convenience init() {
        self.init(
            nibName: NSStringFromClass(MXKAuthenticationViewController.self.self),
            bundle: Bundle(for: MXKAuthenticationViewController.self))
    }

    // MARK: -

    func finalizeInit() {
        super.finalizeInit()

        // Set initial auth type
        authType = MXKAuthenticationTypeLogin

        deviceDisplayName = nil

        // Initialize authInputs view classes
        loginAuthInputsViewClass = MXKAuthInputsPasswordBasedView.self
        registerAuthInputsViewClass = nil // No registration flow is supported yet
        forgotPasswordAuthInputsViewClass = nil
    }

    // MARK: -

    func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // Check whether the view controller has been pushed via storyboard
        if authenticationScrollView == nil {
            // Instantiate view controller objects
            nib()?.instantiate(withOwner: self, options: nil)
        }

        authFallbackWebView = MXKAuthenticationFallbackWebView(frame: authFallbackWebViewContainer.bounds)
        if let authFallbackWebView = authFallbackWebView {
            authFallbackWebViewContainer.addSubview(authFallbackWebView)
        }
        authFallbackWebView?.leadingAnchor.constraint(equalTo: authFallbackWebViewContainer.leadingAnchor, constant: 0).isActive = true
        authFallbackWebView?.trailingAnchor.constraint(equalTo: authFallbackWebViewContainer.trailingAnchor, constant: 0).isActive = true
        authFallbackWebView?.topAnchor.constraint(equalTo: authFallbackWebViewContainer.topAnchor, constant: 0).isActive = true
        authFallbackWebView?.bottomAnchor.constraint(equalTo: authFallbackWebViewContainer.bottomAnchor, constant: 0).isActive = true

        // Load welcome image from MatrixKit asset bundle
        welcomeImageView.image = Bundle.mxk_imageFromMXKAssetsBundle(withName: "logoHighRes")

        authenticationScrollView.autoresizingMask = .flexibleWidth

        subTitleLabel.numberOfLines = 0

        submitButton.isEnabled = false
        authSwitchButton.isEnabled = true

        homeServerTextField.text = defaultHomeServerUrl
        identityServerTextField.text = defaultIdentityServerUrl

        // Hide the identity server by default
        setIdentityServerHidden(true)

        // Create here REST client (if homeserver is defined)
        updateRESTClient()

        // Localize labels
        homeServerLabel.text = Bundle.mxk_localizedString(forKey: "login_home_server_title")
        homeServerTextField.placeholder = Bundle.mxk_localizedString(forKey: "login_server_url_placeholder")
        homeServerInfoLabel.text = Bundle.mxk_localizedString(forKey: "login_home_server_info")
        identityServerLabel.text = Bundle.mxk_localizedString(forKey: "login_identity_server_title")
        identityServerTextField.placeholder = Bundle.mxk_localizedString(forKey: "login_server_url_placeholder")
        identityServerInfoLabel.text = Bundle.mxk_localizedString(forKey: "login_identity_server_info")
        cancelAuthFallbackButton.setTitle(Bundle.mxk_localizedString(forKey: "cancel"), for: .normal)
        cancelAuthFallbackButton.setTitle(Bundle.mxk_localizedString(forKey: "cancel"), for: .highlighted)
    }

    func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(onTextFieldChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
    }

    func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        dismissKeyboard()

        // close any opened alert
        if alert != nil {
            alert?.dismiss(animated: false)
            alert = nil
        }
        NotificationCenter.default.removeObserver(self, name: AFNetworkingReachabilityDidChangeNotification, object: nil)

        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: nil)
    }

    // MARK: - Override MXKViewController

    func onKeyboardShowAnimationComplete() {
        // Report the keyboard view in order to track keyboard frame changes
        // TODO define inputAccessoryView for each text input
        // and report the inputAccessoryView.superview of the firstResponder in self.keyboardView.
    }

    func setKeyboardHeight(_ keyboardHeight: CGFloat) {
        // Deduce the bottom inset for the scroll view (Don't forget the potential tabBar)
        var scrollViewInsetBottom = keyboardHeight - bottomLayoutGuide.length
        // Check whether the keyboard is over the tabBar
        if scrollViewInsetBottom < 0 {
            scrollViewInsetBottom = 0
        }

        let insets = authenticationScrollView.contentInset
        insets.bottom = scrollViewInsetBottom
        authenticationScrollView.contentInset = insets
    }

    func destroy() {
        authInputsView = nil

        if registrationTimer != nil {
            registrationTimer?.invalidate()
            registrationTimer = nil
        }

        if mxCurrentOperation != nil {
            mxCurrentOperation?.cancel()
            mxCurrentOperation = nil
        }

        cancelIdentityServerCheck()

        mxRestClient?.close()
        mxRestClient = nil

        authenticationFallback = nil
        cancelFallbackBarButton = nil

        super.destroy()
    }

    /// Register the MXKAuthInputsView class that will be used to display inputs for an authentication type.
    /// By default the 'MXKAuthInputsPasswordBasedView' class is registered for 'MXKAuthenticationTypeLogin' authentication.
    /// No class is registered for 'MXKAuthenticationTypeRegister' type.
    /// No class is registered for 'MXKAuthenticationTypeForgotPassword' type.
    /// - Parameters:
    ///   - authInputsViewClass: a MXKAuthInputsView-inherited class.
    ///   - authType: the concerned authentication type

    // MARK: - Class methods

    func registerAuthInputsViewClass(_ authInputsViewClass: AnyClass, forAuthType authType: MXKAuthenticationType) {
        // Sanity check: accept only MXKAuthInputsView classes or sub-classes
        assert(authInputsViewClass.isSubclass(of: MXKAuthInputsView.self), "Invalid parameter not satisfying: authInputsViewClass.isSubclass(of: MXKAuthInputsView.self)")

        if authType == MXKAuthenticationTypeLogin {
            loginAuthInputsViewClass = authInputsViewClass
        } else if authType == MXKAuthenticationTypeRegister {
            registerAuthInputsViewClass = authInputsViewClass
        } else if authType == MXKAuthenticationTypeForgotPassword {
            forgotPasswordAuthInputsViewClass = authInputsViewClass
        }
    }

    /// Set the homeserver url and force a new authentication session.
    /// The default homeserver url is used when the provided url is nil.
    /// - Parameter homeServerUrl: the homeserver url to use
    func setHomeServerTextFieldText(_ homeServerUrl: String?) {
        var homeServerUrl = homeServerUrl
        if (homeServerUrl?.count ?? 0) == 0 {
            // Force refresh with default value
            homeServerUrl = defaultHomeServerUrl
        }

        homeServerTextField.text = homeServerUrl

        if mxRestClient == nil || (mxRestClient?.homeserver != homeServerUrl) {
            updateRESTClient()

            if authType == MXKAuthenticationTypeLogin || authType == MXKAuthenticationTypeRegister {
                // Restore default UI
                #warning("Swiftify: Skipping redundant initializing to itself")
                //authType = authType
            } else {
                // Refresh the IS anyway
                checkIdentityServer()
            }
        }
    }

    /// Set the identity server url.
    /// The default identity server url is used when the provided url is nil.
    /// - Parameter identityServerUrl: the identity server url to use
    func setIdentityServerTextFieldText(_ identityServerUrl: String?) {
        identityServerTextField.text = identityServerUrl

        updateIdentityServerURL(identityServerUrl)
    }

    func updateIdentityServerURL(_ url: String?) {
        if identityService?.identityServer != url {
            if (url?.count ?? 0) != 0 {
                identityService = MXIdentityService(identityServer: url, accessToken: nil, andHomeserverRestClient: mxRestClient)
            } else {
                identityService = nil
            }
        }

        mxRestClient?.identityServer = (url?.count ?? 0) != 0 ? url : nil
    }

    func setIdentityServerHidden(_ hidden: Bool) {
        identityServerContainer.isHidden = hidden
    }

    /// Fetch the identity server from the wellknown API of the selected homeserver.
    /// and check if the HS requires an identity server.
    func checkIdentityServer() {
        cancelIdentityServerCheck()

        // Hide the field while checking data
        setIdentityServerHidden(true)

        let homeserver = mxRestClient?.homeserver

        // First, fetch the IS advertised by the HS
        if let homeserver = homeserver {
            MXLogDebug("[MXKAuthenticationVC] checkIdentityServer for homeserver %@", homeserver)

            autoDiscovery = MXAutoDiscovery(url: homeserver)

            MXWeakify(self)
            checkIdentityServerOperation = autoDiscovery?.findClientConfig({ [self] discoveredClientConfig in
                MXStrongifyAndReturnIfNil(self)

                let identityServer = discoveredClientConfig.wellKnown.identityServer.baseUrl
                MXLogDebug("[MXKAuthenticationVC] checkIdentityServer: Identity server: %@", identityServer)

                if identityServer != "" {
                    // Apply the provided IS
                    setIdentityServerTextFieldText(identityServer)
                }

                // Then, check if the HS needs an IS for running
                MXWeakify(self)
                let operation = checkIdentityServerRequirement(withCompletion: { [self] identityServerRequired in

                    MXStrongifyAndReturnIfNil(self)

                    checkIdentityServerOperation = nil

                    // Show the field only if an IS is required so that the user can customise it
                    setIdentityServerHidden(!identityServerRequired)
                })

                if let operation = operation {
                    checkIdentityServerOperation?.mutate(to: operation)
                } else {
                    checkIdentityServerOperation = nil
                }

                autoDiscovery = nil

            }, failure: { [self] error in
                MXStrongifyAndReturnIfNil(self)

                // No need to report this error to the end user
                // There will be already an error about failing to get the auth flow from the HS
                MXLogDebug("[MXKAuthenticationVC] checkIdentityServer. Error: %@", error)

                autoDiscovery = nil
            })
        }
    }

    func cancelIdentityServerCheck() {
        if checkIdentityServerOperation != nil {
            checkIdentityServerOperation?.cancel()
            checkIdentityServerOperation = nil
        }
    }

    func checkIdentityServerRequirement(withCompletion completion: @escaping (_ identityServerRequired: Bool) -> Void) -> MXHTTPOperation? {
        var operation: MXHTTPOperation?

        if authType == MXKAuthenticationTypeLogin {
            // The identity server is only required for registration and password reset
            // It is then stored in the user account data
            completion(false)
        } else {
            operation = mxRestClient?.supportedMatrixVersions({ matrixVersions in

                MXLogDebug("[MXKAuthenticationVC] checkIdentityServerRequirement: %@", matrixVersions?.doesServerRequireIdentityServerParam ? "YES" : "NO")
                completion((matrixVersions?.doesServerRequireIdentityServerParam)!)

            }, failure: { error in
                // No need to report this error to the end user
                // There will be already an error about failing to get the auth flow from the HS
                MXLogDebug("[MXKAuthenticationVC] checkIdentityServerRequirement. Error: %@", error)
            })
        }

        return operation
    }

    /// Refresh login/register mechanism supported by the server and the application.
    func refreshAuthenticationSession() {
        // Remove reachability observer
        NotificationCenter.default.removeObserver(self, name: AFNetworkingReachabilityDidChangeNotification, object: nil)

        // Cancel potential request in progress
        mxCurrentOperation?.cancel()
        mxCurrentOperation = nil

        // Reset potential authentication fallback url
        authenticationFallback = nil

        if let mxRestClient = mxRestClient {
            if authType == MXKAuthenticationTypeLogin {
                mxCurrentOperation = mxRestClient.getLoginSession({ [self] authSession in

                    handle(authSession)

                }, failure: { [self] error in

                    onFailureDuringMXOperation(error)

                })
            } else if authType == MXKAuthenticationTypeRegister {
                mxCurrentOperation = mxRestClient.getRegisterSession({ [self] authSession in

                    handle(authSession)

                }, failure: { [self] error in

                    onFailureDuringMXOperation(error)

                })
            } else {
                // Not supported for other types
                MXLogDebug("[MXKAuthenticationVC] refreshAuthenticationSession is ignored")
            }
        }
    }

    /// Handle supported flows and associated information returned by the homeserver.
    func handle(_ authSession: MXAuthenticationSession?) {
        mxCurrentOperation = nil

        authenticationActivityIndicator.stopAnimating()

        // Check whether fallback is defined, and retrieve the right input view class.
        var authInputsViewClass: AnyClass?
        if authType == MXKAuthenticationTypeLogin {
            authenticationFallback = mxRestClient?.loginFallback()
            authInputsViewClass = loginAuthInputsViewClass
        } else if authType == MXKAuthenticationTypeRegister {
            authenticationFallback = mxRestClient?.registerFallback()
            authInputsViewClass = registerAuthInputsViewClass
        } else {
            // Not supported for other types
            MXLogDebug("[MXKAuthenticationVC] handleAuthenticationSession is ignored")
            return
        }

        var authInputsView: MXKAuthInputsView? = nil
        if let authInputsViewClass = authInputsViewClass {
            // Instantiate a new auth inputs view, except if the current one is already an instance of this class.
            if self.authInputsView != nil && type(of: self.authInputsView) == authInputsViewClass {
                // Use the current view
                authInputsView = self.authInputsView
            } else {
                authInputsView = authInputsViewClass.authInputsView()
            }
        }

        if authInputsView != nil {
            // Apply authentication session on inputs view
            if authInputsView?.setAuthSession(authSession, withAuthType: authType) == false {
                MXLogDebug("[MXKAuthenticationVC] Received authentication settings are not supported")
                authInputsView = nil
            } else if softLogoutCredentials == nil {
                // If all listed flows in this authentication session are not supported we suggest using the fallback page.
                if (authenticationFallback?.count ?? 0) != 0 && authInputsView?.authSession.flows.count == 0 {
                    MXLogDebug("[MXKAuthenticationVC] No supported flow, suggest using fallback page")
                    authInputsView = nil
                } else if authInputsView?.authSession.flows.count != authSession?.flows.count {
                    MXLogDebug("[MXKAuthenticationVC] The authentication session contains at least one unsupported flow")
                }
            }
        }

        if let authInputsView = authInputsView {
            // Check whether the current view must be replaced
            if self.authInputsView != authInputsView {
                // Refresh layout
                self.authInputsView = authInputsView
            }

            // Refresh user interaction
            #warning("Swiftify: Skipping redundant initializing to itself")
            //userInteractionEnabled = userInteractionEnabled

            // Check whether an external set of parameters have been defined to pursue a registration
            if let externalRegistrationParameters = externalRegistrationParameters {
                if authInputsView.externalRegistrationParameters = externalRegistrationParameters {
                    // Launch authentication now
                    onButtonPressed(submitButton)
                } else {
                    onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
                    ]))

                    externalRegistrationParameters = nil

                    // Restore login screen on failure
                    authType = MXKAuthenticationTypeLogin
                }
            }

            if softLogoutCredentials != nil {
                authInputsView.softLogoutCredentials = softLogoutCredentials
            }
        } else {
            // Remove the potential auth inputs view
            self.authInputsView = nil

            // Cancel external registration parameters if any
            externalRegistrationParameters = nil

            // Notify user that no flow is supported
            if authType == MXKAuthenticationTypeLogin {
                noFlowLabel.text = Bundle.mxk_localizedString(forKey: "login_error_do_not_support_login_flows")
            } else {
                noFlowLabel.text = Bundle.mxk_localizedString(forKey: "login_error_registration_is_not_supported")
            }
            MXLogDebug("[MXKAuthenticationVC] Warning: %@", noFlowLabel.text)

            if (authenticationFallback?.count ?? 0) != 0 {
                retryButton.setTitle(Bundle.mxk_localizedString(forKey: "login_use_fallback"), for: .normal)
                retryButton.setTitle(Bundle.mxk_localizedString(forKey: "login_use_fallback"), for: .normal)
            } else {
                retryButton.setTitle(Bundle.mxk_localizedString(forKey: "retry"), for: .normal)
                retryButton.setTitle(Bundle.mxk_localizedString(forKey: "retry"), for: .normal)
            }

            noFlowLabel.isHidden = false
            retryButton.isHidden = false
        }
    }

    /// Customize the MXHTTPClientOnUnrecognizedCertificate block that will be used to handle unrecognized certificate observed during authentication challenge from a server.
    /// By default we prompt the user by displaying a fingerprint (SHA256) of the certificate. The user is then able to trust or not the certificate.
    /// - Parameter onUnrecognizedCertificateBlock: the block that will be used to handle unrecognized certificate
    func setOnUnrecognizedCertificateBlock(_ onUnrecognizedCertificateBlock: MXHTTPClientOnUnrecognizedCertificate) {
        onUnrecognizedCertificateCustomBlock = onUnrecognizedCertificateBlock
    }

    /// Check whether the current username is already in use.
    /// - Parameter callback: A block object called when the operation is completed.
    func isUserName(inUse callback: @escaping (_ isUserNameInUse: Bool) -> Void) {
        mxCurrentOperation = mxRestClient?.isUserName(inUse: authInputsView?.userId, callback: { [self] isUserNameInUse in

            mxCurrentOperation = nil

            if callback != nil {
                callback(isUserNameInUse)
            }

        })
    }

    /// Make a ping to the registration endpoint to detect a possible registration problem earlier.
    /// - Parameter callback: A block object called when the operation is completed.
    /// It provides a MXError to check to verify if the user can be registered.
    func testUserRegistration(_ callback: @escaping (_ mxError: MXError?) -> Void) {
        mxCurrentOperation = mxRestClient?.testUserRegistration(authInputsView?.userId, callback: callback)
    }

    /// Action registered on the following events:
    /// - 'UIControlEventTouchUpInside' for each UIButton instance.
    /// - 'UIControlEventValueChanged' for each UISwitch instance.
    @IBAction func onButtonPressed(_ sender: Any) {
        dismissKeyboard()

        if (sender as? UIButton) == submitButton {
            // Disable user interaction to prevent multiple requests
            userInteractionEnabled = false

            // Check parameters validity
            let errorMsg = authInputsView?.validateParameters()
            if let errorMsg = errorMsg {
                onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                    NSLocalizedDescriptionKey: errorMsg
                ]))
            } else {
                authInputsContainerView.bringSubviewToFront(authenticationActivityIndicator)

                // Launch the authentication according to its type
                if authType == MXKAuthenticationTypeLogin {
                    // Prepare the parameters dict
                    authInputsView?.prepareParameters({ [self] parameters, error in

                        if parameters != nil && mxRestClient != nil {
                            authenticationActivityIndicator.startAnimating()
                            login(withParameters: parameters)
                        } else {
                            MXLogDebug("[MXKAuthenticationVC] Failed to prepare parameters")
                            onFailureDuringAuthRequest(error)
                        }

                    })
                } else if authType == MXKAuthenticationTypeRegister {
                    // Check here the availability of the userId
                    if authInputsView?.userId.length {
                        authenticationActivityIndicator.startAnimating()

                        if authInputsView?.password.length {
                            // Trigger here a register request in order to associate the filled userId and password to the current session id
                            // This will check the availability of the userId at the same time
                            var parameters: [StringLiteralConvertible : [AnyHashable : Any]]? = nil
                            if let userId = authInputsView?.userId, let password = authInputsView?.password {
                                parameters = [
                                    "auth": [:],
                                    "username": userId,
                                    "password": password,
                                    "bind_email": NSNumber(value: false),
                                    "initial_device_display_name": deviceDisplayName ?? ""
                                ]
                            }

                            mxCurrentOperation = mxRestClient?.register(withParameters: parameters, success: { [self] JSONResponse in

                                // Unexpected case where the registration succeeds without any other stages
                                let loginResponse: MXLoginResponse? = nil
                                MXJSONModelSetMXJSONModel(loginResponse, MXLoginResponse, JSONResponse)

                                let credentials = MXCredentials(
                                    loginResponse: loginResponse,
                                    andDefaultCredentials: mxRestClient?.credentials)

                                // Sanity check
                                if !credentials.userId || !credentials.accessToken {
                                    onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
                                    ]))
                                } else {
                                    MXLogDebug("[MXKAuthenticationVC] Registration succeeded")

                                    // Report the certificate trusted by user (if any)
                                    credentials.allowedCertificate = mxRestClient?.allowedCertificate

                                    onSuccessfulLogin(credentials)
                                }

                            }, failure: { [self] error in

                                mxCurrentOperation = nil

                                // An updated authentication session should be available in response data in case of unauthorized request.
                                var JSONResponse: [AnyHashable : Any]? = nil
                                if (error as NSError?)?.userInfo[MXHTTPClientErrorResponseDataKey] != nil {
                                    JSONResponse = (error as NSError?)?.userInfo[MXHTTPClientErrorResponseDataKey] as? [AnyHashable : Any]
                                }

                                if let JSONResponse = JSONResponse {
                                    let authSession = MXAuthenticationSession.model(fromJSON: JSONResponse)

                                    authenticationActivityIndicator.stopAnimating()

                                    // Update session identifier
                                    authInputsView?.authSession.session = authSession?.session

                                    // Launch registration by preparing parameters dict
                                    authInputsView?.prepareParameters({ [self] parameters, error in

                                        if parameters != nil && mxRestClient != nil {
                                            authenticationActivityIndicator.startAnimating()
                                            register(withParameters: parameters)
                                        } else {
                                            MXLogDebug("[MXKAuthenticationVC] Failed to prepare parameters")
                                            onFailureDuringAuthRequest(error)
                                        }

                                    })
                                } else {
                                    onFailureDuringAuthRequest(error)
                                }
                            })
                        } else {
                            isUserName(inUse: { [self] isUserNameInUse in

                                if isUserNameInUse {
                                    MXLogDebug("[MXKAuthenticationVC] User name is already use")
                                    onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "auth_username_in_use")
                                    ]))
                                } else {
                                    authenticationActivityIndicator.stopAnimating()

                                    // Launch registration by preparing parameters dict
                                    authInputsView?.prepareParameters({ [self] parameters, error in

                                        if parameters != nil && mxRestClient != nil {
                                            authenticationActivityIndicator.startAnimating()
                                            register(withParameters: parameters)
                                        } else {
                                            MXLogDebug("[MXKAuthenticationVC] Failed to prepare parameters")
                                            onFailureDuringAuthRequest(error)
                                        }

                                    })
                                }

                            })
                        }
                    } else if externalRegistrationParameters != nil {
                        // Launch registration by preparing parameters dict
                        authInputsView?.prepareParameters({ [self] parameters, error in

                            if parameters != nil && mxRestClient != nil {
                                authenticationActivityIndicator.startAnimating()
                                register(withParameters: parameters)
                            } else {
                                MXLogDebug("[MXKAuthenticationVC] Failed to prepare parameters")
                                onFailureDuringAuthRequest(error)
                            }

                        })
                    } else {
                        MXLogDebug("[MXKAuthenticationVC] User name is missing")
                        onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                            NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "auth_invalid_user_name")
                        ]))
                    }
                } else if authType == MXKAuthenticationTypeForgotPassword {
                    // Check whether the password has been reseted
                    if isPasswordReseted {
                        // Return to login screen
                        authType = MXKAuthenticationTypeLogin
                    } else {
                        // Prepare the parameters dict
                        authInputsView?.prepareParameters({ [self] parameters, error in

                            if parameters != nil && mxRestClient != nil {
                                authenticationActivityIndicator.startAnimating()
                                resetPassword(withParameters: parameters)
                            } else {
                                MXLogDebug("[MXKAuthenticationVC] Failed to prepare parameters")
                                onFailureDuringAuthRequest(error)
                            }

                        })
                    }
                }
            }
        } else if (sender as? UIButton) == authSwitchButton {
            if authType == MXKAuthenticationTypeLogin {
                authType = MXKAuthenticationTypeRegister
            } else {
                authType = MXKAuthenticationTypeLogin
            }
        } else if (sender as? UIButton) == retryButton {
            if let authenticationFallback = authenticationFallback {
                showAuthenticationFallBackView(authenticationFallback)
            } else {
                refreshAuthenticationSession()
            }
        } else if (sender as? UIButton) == cancelAuthFallbackButton {
            // Hide fallback webview
            hideRegistrationFallbackView()
        }
    }

    func cancel() {
        MXLogDebug("[MXKAuthenticationVC] cancel")

        // Cancel external registration parameters if any
        externalRegistrationParameters = nil

        if registrationTimer != nil {
            registrationTimer?.invalidate()
            registrationTimer = nil
        }

        // Cancel request in progress
        if mxCurrentOperation != nil {
            mxCurrentOperation?.cancel()
            mxCurrentOperation = nil
        }

        authenticationActivityIndicator.stopAnimating()
        userInteractionEnabled = true

        // Reset potential completed stages
        authInputsView?.authSession.completed = nil

        // Update authentication inputs view to return in initial step
        authInputsView?.setAuthSession(authInputsView?.authSession, withAuthType: authType)
    }

    /// Handle the error received during an authentication request.
    /// - Parameter error: the received error.
    func onFailureDuringAuthRequest(_ error: Error?) {
        mxCurrentOperation = nil
        authenticationActivityIndicator.stopAnimating()
        userInteractionEnabled = true

        // Ignore connection cancellation error
        if ((error as NSError?)?.domain == NSURLErrorDomain) && (error as NSError?)?.code == Int(NSURLErrorCancelled) {
            MXLogDebug("[MXKAuthenticationVC] Auth request cancelled")
            return
        }

        MXLogDebug("[MXKAuthenticationVC] Auth request failed: %@", error)

        // Cancel external registration parameters if any
        externalRegistrationParameters = nil

        // Translate the error code to a human message
        var title = (error as NSError?)?.localizedFailureReason
        if title == nil {
            if authType == MXKAuthenticationTypeLogin {
                title = Bundle.mxk_localizedString(forKey: "login_error_title")
            } else if authType == MXKAuthenticationTypeRegister {
                title = Bundle.mxk_localizedString(forKey: "register_error_title")
            } else {
                title = Bundle.mxk_localizedString(forKey: "error")
            }
        }
        var message = error?.localizedDescription
        let dict = (error as NSError?)?.userInfo

        // detect if it is a Matrix SDK issue
        if let dict = dict {
            let localizedError = dict["error"] as? String
            let errCode = dict["errcode"] as? String

            if (localizedError?.count ?? 0) > 0 {
                message = localizedError
            }

            if let errCode = errCode {
                if errCode == kMXErrCodeStringForbidden {
                    message = Bundle.mxk_localizedString(forKey: "login_error_forbidden")
                } else if errCode == kMXErrCodeStringUnknownToken {
                    message = Bundle.mxk_localizedString(forKey: "login_error_unknown_token")
                } else if errCode == kMXErrCodeStringBadJSON {
                    message = Bundle.mxk_localizedString(forKey: "login_error_bad_json")
                } else if errCode == kMXErrCodeStringNotJSON {
                    message = Bundle.mxk_localizedString(forKey: "login_error_not_json")
                } else if errCode == kMXErrCodeStringLimitExceeded {
                    message = Bundle.mxk_localizedString(forKey: "login_error_limit_exceeded")
                } else if errCode == kMXErrCodeStringUserInUse {
                    message = Bundle.mxk_localizedString(forKey: "login_error_user_in_use")
                } else if errCode == kMXErrCodeStringLoginEmailURLNotYet {
                    message = Bundle.mxk_localizedString(forKey: "login_error_login_email_not_yet")
                } else if errCode == kMXErrCodeStringResourceLimitExceeded {
                    showResourceLimitExceededError(dict, onAdminContactTapped: { _ in })
                    return
                } else if (message?.count ?? 0) == 0 {
                    message = errCode
                }
            }
        }

        // Alert user
        if let alert = alert {
            alert.dismiss(animated: false)
        }

        alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert?.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "ok"),
                style: .default,
                handler: { [self] action in

                    alert = nil

                }))


        if let alert = alert {
            present(alert, animated: true)
        }

        // Update authentication inputs view to return in initial step
        authInputsView?.setAuthSession(authInputsView?.authSession, withAuthType: authType)
        if let softLogoutCredentials = softLogoutCredentials {
            authInputsView?.softLogoutCredentials = softLogoutCredentials
        }
    }

    /// Display a kMXErrCodeStringResourceLimitExceeded error received during an authentication
    /// request.
    /// - Parameters:
    ///   - errorDict: the error data.
    ///   - onAdminContactTapped: a callback indicating if the user wants to contact their admin.
    func showResourceLimitExceededError(_ errorDict: [AnyHashable : Any]?, onAdminContactTapped: @escaping (_ adminContact: URL?) -> Void) {
        mxCurrentOperation = nil
        authenticationActivityIndicator.stopAnimating()
        userInteractionEnabled = true

        // Alert user
        if let alert = alert {
            alert.dismiss(animated: false)
        }

        // Parse error data
        let limitType: String? = nil
        let adminContactString: String? = nil
        var adminContact: URL?

        MXJSONModelSetString(limitType, errorDict?[kMXErrorResourceLimitExceededLimitTypeKey])
        MXJSONModelSetString(adminContactString, errorDict?[kMXErrorResourceLimitExceededAdminContactKey])

        if let adminContactString = adminContactString {
            adminContact = URL(string: adminContactString)
        }

        let title = Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_title")

        // Build the message content
        var message = ""
        if limitType == kMXErrorResourceLimitExceededLimitTypeMonthlyActiveUserValue {
            message += Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_message_monthly_active_user")
        } else {
            message += Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_message_default")
        }

        message += Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_message_contact")

        // Build the alert
        alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        MXWeakify(self)
        if adminContact != nil && onAdminContactTapped != nil {
            alert?.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "login_error_resource_limit_exceeded_contact_button"),
                    style: .default,
                    handler: { [self] action in
                        MXStrongifyAndReturnIfNil(self)
                        alert = nil

                        // Let the system handle the URI
                        // It could be something like "mailto: server.admin@example.com"
                        onAdminContactTapped(adminContact)
                    }))
        }

        alert?.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "cancel"),
                style: .default,
                handler: { [self] action in
                    MXStrongifyAndReturnIfNil(self)
                    alert = nil
                }))

        if let alert = alert {
            present(alert, animated: true)
        }

        // Update authentication inputs view to return in initial step
        authInputsView?.setAuthSession(authInputsView?.authSession, withAuthType: authType)
    }

    /// Handle the successful authentication request.
    /// - Parameter credentials: the user's credentials.
    func onSuccessfulLogin(_ credentials: MXCredentials?) {
        mxCurrentOperation = nil
        authenticationActivityIndicator.stopAnimating()
        userInteractionEnabled = true

        if let softLogoutCredentials = softLogoutCredentials {
            // Hydrate the account with the new access token
            let account = MXKAccountManager.shared().account(forUserId: softLogoutCredentials.userId)
            MXKAccountManager.shared().hydrateAccount(account, with: credentials)

            if delegate != nil {
                delegate?.authenticationViewController(self, didLogWithUserId: credentials?.userId)
            }
        } else if MXKAccountManager.shared().account(forUserId: credentials?.userId) {
            //Alert user
            weak var weakSelf = self

            if let alert = alert {
                alert.dismiss(animated: false)
            }

            alert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "login_error_already_logged_in"), message: nil, preferredStyle: .alert)

            alert?.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "ok"),
                    style: .default,
                    handler: { [self] action in

                        // We remove the authentication view controller.
                        let self = weakSelf
                        alert = nil
                        withdrawViewController(animated: true, completion: nil)

                    }))


            if let alert = alert {
                present(alert, animated: true)
            }
        } else {
            // Report the new account in account manager
            if !credentials?.identityServer {
                credentials?.identityServer = identityServerTextField.text
            }
            let account = MXKAccount(credentials: credentials)
            account.identityServerURL = credentials?.identityServer

            MXKAccountManager.shared().add(account, andOpenSession: true)

            if delegate != nil {
                delegate?.authenticationViewController(self, didLogWithUserId: credentials?.userId)
            }
        }
    }

    func refreshForgotPasswordSession() {
        authenticationActivityIndicator.stopAnimating()

        var authInputsView: MXKAuthInputsView? = nil
        if let forgotPasswordAuthInputsViewClass = forgotPasswordAuthInputsViewClass {
            // Instantiate a new auth inputs view, except if the current one is already an instance of this class.
            if self.authInputsView != nil && type(of: self.authInputsView) == forgotPasswordAuthInputsViewClass {
                // Use the current view
                authInputsView = self.authInputsView
            } else {
                authInputsView = forgotPasswordAuthInputsViewClass.authInputsView()
            }
        }

        if let authInputsView = authInputsView {
            // Update authentication inputs view to return in initial step
            authInputsView.setAuthSession(nil, withAuthType: MXKAuthenticationTypeForgotPassword)

            // Check whether the current view must be replaced
            if self.authInputsView != authInputsView {
                // Refresh layout
                self.authInputsView = authInputsView
            }

            // Refresh user interaction
            #warning("Swiftify: Skipping redundant initializing to itself")
            //userInteractionEnabled = userInteractionEnabled
        } else {
            // Remove the potential auth inputs view
            self.authInputsView = nil

            noFlowLabel.text = Bundle.mxk_localizedString(forKey: "login_error_forgot_password_is_not_supported")

            MXLogDebug("[MXKAuthenticationVC] Warning: %@", noFlowLabel.text)

            noFlowLabel.isHidden = false
        }
    }

    func updateRESTClient() {
        let homeserverURL = homeServerTextField.text

        if (homeserverURL?.count ?? 0) != 0 {
            // Check change
            if (homeserverURL == mxRestClient?.homeserver) == false {
                mxRestClient = MXRestClient(homeServer: homeserverURL) { [self] certificate in

                    // Check first if the app developer provided its own certificate handler.
                    if onUnrecognizedCertificateCustomBlock != nil {
                        return onUnrecognizedCertificateCustomBlock(certificate)
                    }

                    // Else prompt the user by displaying a fingerprint (SHA256) of the certificate.
                    var isTrusted: Bool
                    let semaphore = DispatchSemaphore(value: 0)

                    let title = Bundle.mxk_localizedString(forKey: "ssl_could_not_verify")
                    let homeserverURLStr = String(format: Bundle.mxk_localizedString(forKey: "ssl_homeserver_url"), homeserverURL ?? "")
                    let fingerprint = String(format: Bundle.mxk_localizedString(forKey: "ssl_fingerprint_hash"), "SHA256")
                    let certFingerprint = certificate?.mx_SHA256AsHexString()

                    let msg = "\(Bundle.mxk_localizedString(forKey: "ssl_cert_not_trust"))\n\n\(Bundle.mxk_localizedString(forKey: "ssl_cert_new_account_expl"))\n\n\(homeserverURLStr)\n\n\(fingerprint)\n\n\(certFingerprint ?? "")\n\n\(Bundle.mxk_localizedString(forKey: "ssl_only_accept"))"

                    if let alert = alert {
                        alert.dismiss(animated: false)
                    }

                    alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

                    alert?.addAction(
                        UIAlertAction(
                            title: Bundle.mxk_localizedString(forKey: "cancel"),
                            style: .default,
                            handler: { [self] action in

                                alert = nil
                                isTrusted = false
                                dispatch_semaphore_signal(semaphore)

                            }))

                    alert?.addAction(
                        UIAlertAction(
                            title: Bundle.mxk_localizedString(forKey: "ssl_trust"),
                            style: .default,
                            handler: { [self] action in

                                alert = nil
                                isTrusted = true
                                dispatch_semaphore_signal(semaphore)

                            }))

                    DispatchQueue.main.async(execute: { [self] in
                        if let alert = alert {
                            present(alert, animated: true)
                        }
                    })

                    (semaphore.wait(timeout: DispatchTime.distantFuture) == .success ? 0 : -1)

                    if !isTrusted {
                        // Cancel request in progress
                        mxCurrentOperation?.cancel()
                        mxCurrentOperation = nil
                        NotificationCenter.default.removeObserver(self, name: AFNetworkingReachabilityDidChangeNotification, object: nil)

                        authenticationActivityIndicator.stopAnimating()
                    }

                    return isTrusted
                }

                if (identityServerTextField.text?.count ?? 0) != 0 {
                    updateIdentityServerURL(identityServerTextField.text)
                }
            }
        } else {
            mxRestClient?.close()
            mxRestClient = nil
        }
    }

    /// Login with custom parameters
    /// @param parameters Login parameters
    func login(withParameters parameters: [AnyHashable : Any]?) {
        // Add the device name
        var theParameters = parameters
        theParameters["initial_device_display_name"] = deviceDisplayName ?? ""

        mxCurrentOperation = mxRestClient?.login(theParameters, success: { [self] JSONResponse in

            let loginResponse: MXLoginResponse? = nil
            MXJSONModelSetMXJSONModel(loginResponse, MXLoginResponse, JSONResponse)

            let credentials = MXCredentials(
                loginResponse: loginResponse,
                andDefaultCredentials: mxRestClient?.credentials)

            // Sanity check
            if !credentials.userId || !credentials.accessToken {
                onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                    NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
                ]))
            } else {
                MXLogDebug("[MXKAuthenticationVC] Login process succeeded")

                // Report the certificate trusted by user (if any)
                credentials.allowedCertificate = mxRestClient?.allowedCertificate

                onSuccessfulLogin(credentials)
            }

        }, failure: { [self] error in

            onFailureDuringAuthRequest(error)

        })
    }

    func register(withParameters parameters: [AnyHashable : Any]?) {
        if registrationTimer != nil {
            registrationTimer?.invalidate()
            registrationTimer = nil
        }

        // Add the device name
        var theParameters = parameters
        theParameters["initial_device_display_name"] = deviceDisplayName ?? ""

        mxCurrentOperation = mxRestClient?.register(withParameters: theParameters, success: { [self] JSONResponse in

            let loginResponse: MXLoginResponse? = nil
            MXJSONModelSetMXJSONModel(loginResponse, MXLoginResponse, JSONResponse)

            let credentials = MXCredentials(
                loginResponse: loginResponse,
                andDefaultCredentials: mxRestClient?.credentials)

            // Sanity check
            if !credentials.userId || !credentials.accessToken {
                onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                    NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
                ]))
            } else {
                MXLogDebug("[MXKAuthenticationVC] Registration succeeded")

                // Report the certificate trusted by user (if any)
                credentials.allowedCertificate = mxRestClient?.allowedCertificate

                onSuccessfulLogin(credentials)
            }

        }, failure: { [self] error in

            mxCurrentOperation = nil

            // Check whether the authentication is pending (for example waiting for email validation)
            let mxError = MXError(nsError: error)
            if mxError != nil && (mxError.errcode == kMXErrCodeStringUnauthorized) {
                MXLogDebug("[MXKAuthenticationVC] Wait for email validation")

                // Postpone a new attempt in 10 sec
                registrationTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(registrationTimerFireMethod(_:)), userInfo: parameters, repeats: false)
            } else {
                // The completed stages should be available in response data in case of unauthorized request.
                var JSONResponse: [AnyHashable : Any]? = nil
                if (error as NSError?)?.userInfo[MXHTTPClientErrorResponseDataKey] != nil {
                    JSONResponse = (error as NSError?)?.userInfo[MXHTTPClientErrorResponseDataKey] as? [AnyHashable : Any]
                }

                if let JSONResponse = JSONResponse {
                    let authSession = MXAuthenticationSession.model(fromJSON: JSONResponse)

                    if authSession?.completed {
                        authenticationActivityIndicator.stopAnimating()

                        // Update session identifier in case of change
                        authInputsView?.authSession.session = authSession?.session

                        authInputsView?.updateAuthSession(withCompletedStages: authSession?.completed, didUpdateParameters: { [self] parameters, error in

                            if let parameters = parameters {
                                MXLogDebug("[MXKAuthenticationVC] Pursue registration")

                                authenticationActivityIndicator.startAnimating()
                                register(withParameters: parameters)
                            } else {
                                MXLogDebug("[MXKAuthenticationVC] Failed to update parameters")

                                onFailureDuringAuthRequest(error)
                            }

                        })

                        return
                    }

                    onFailureDuringAuthRequest(NSError(domain: MXKAuthErrorDomain, code: 0, userInfo: [
                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "not_supported_yet")
                    ]))
                } else {
                    onFailureDuringAuthRequest(error)
                }
            }
        })
    }

    @objc func registrationTimerFireMethod(_ timer: Timer?) {
        if timer == registrationTimer && timer?.isValid ?? false {
            MXLogDebug("[MXKAuthenticationVC] Retry registration")
            register(withParameters: registrationTimer?.userInfo as? [AnyHashable : Any])
        }
    }

    func resetPassword(withParameters parameters: [AnyHashable : Any]?) {
        mxCurrentOperation = mxRestClient?.resetPassword(withParameters: parameters, success: { [self] in

            MXLogDebug("[MXKAuthenticationVC] Reset password succeeded")

            mxCurrentOperation = nil
            authenticationActivityIndicator.stopAnimating()

            isPasswordReseted = true

            // Force UI update to refresh submit button title.
            #warning("Swiftify: Skipping redundant initializing to itself")
            //authType = authType

            // Refresh the authentication inputs view on success.
            authInputsView?.nextStep()

        }, failure: { [self] error in

            let mxError = MXError(nsError: error)
            if mxError != nil && (mxError.errcode == kMXErrCodeStringUnauthorized) {
                MXLogDebug("[MXKAuthenticationVC] Forgot Password: wait for email validation")

                mxCurrentOperation = nil
                authenticationActivityIndicator.stopAnimating()

                if let alert = alert {
                    alert.dismiss(animated: false)
                }

                alert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "error"), message: Bundle.mxk_localizedString(forKey: "auth_reset_password_error_unauthorized"), preferredStyle: .alert)

                alert?.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "ok"),
                        style: .default,
                        handler: { [self] action in

                            alert = nil

                        }))


                if let alert = alert {
                    present(alert, animated: true)
                }
            } else if mxError != nil && (mxError.errcode == kMXErrCodeStringNotFound) {
                MXLogDebug("[MXKAuthenticationVC] Forgot Password: not found")

                var userInfo: [AnyHashable : Any]?
                if (error as NSError?)?.userInfo != nil {
                    userInfo = (error as NSError?)?.userInfo
                } else {
                    userInfo = [:]
                }
                userInfo?[NSLocalizedDescriptionKey] = Bundle.mxk_localizedString(forKey: "auth_reset_password_error_not_found")

                onFailureDuringAuthRequest(NSError(domain: kMXNSErrorDomain, code: 0, userInfo: userInfo as? [String : Any]))
            } else {
                onFailureDuringAuthRequest(error)
            }

        })
    }

    func onFailureDuringMXOperation(_ error: Error?) {
        mxCurrentOperation = nil

        authenticationActivityIndicator.stopAnimating()

        if ((error as NSError?)?.domain == NSURLErrorDomain) && (error as NSError?)?.code == Int(NSURLErrorCancelled) {
            // Ignore this error
            MXLogDebug("[MXKAuthenticationVC] flows request cancelled")
            return
        }

        MXLogDebug("[MXKAuthenticationVC] Failed to get %@ flows: %@", (authType == MXKAuthenticationTypeLogin ? "Login" : "Register"), error)

        // Cancel external registration parameters if any
        externalRegistrationParameters = nil

        // Alert user
        var title = (error as NSError?)?.userInfo[NSLocalizedFailureReasonErrorKey] as? String
        if title == nil {
            title = Bundle.mxk_localizedString(forKey: "error")
        }
        let msg = (error as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String

        if let alert = alert {
            alert.dismiss(animated: false)
        }

        alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

        alert?.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "dismiss"),
                style: .default,
                handler: { [self] action in

                    alert = nil

                }))


        if let alert = alert {
            present(alert, animated: true)
        }

        // Handle specific error code here
        if (error as NSError?)?.domain == NSURLErrorDomain {
            // Check network reachability
            if (error as NSError?)?.code == Int(NSURLErrorNotConnectedToInternet) {
                // Add reachability observer in order to launch a new request when network will be available
                NotificationCenter.default.addObserver(self, selector: #selector(onReachabilityStatusChange(_:)), name: AFNetworkingReachabilityDidChangeNotification, object: nil)
            } else if (error as NSError?)?.code == CFNetworkErrors.cfurlErrorTimedOut.rawValue {
                // Send a new request in 2 sec
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { [self] in
                    refreshAuthenticationSession()
                })
            } else {
                // Remove the potential auth inputs view
                authInputsView = nil
            }
        } else {
            // Remove the potential auth inputs view
            authInputsView = nil
        }

        if authInputsView == nil {
            // Display failure reason
            noFlowLabel.isHidden = false
            noFlowLabel.text = (error as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String
            if (noFlowLabel.text?.count ?? 0) == 0 {
                noFlowLabel.text = Bundle.mxk_localizedString(forKey: "login_error_no_login_flow")
            }
            retryButton.setTitle(Bundle.mxk_localizedString(forKey: "retry"), for: .normal)
            retryButton.setTitle(Bundle.mxk_localizedString(forKey: "retry"), for: .normal)
            retryButton.isHidden = false
        }
    }

    @objc func onReachabilityStatusChange(_ notif: Notification?) {
        let reachabilityManager = AFNetworkReachabilityManager.shared()
        let status = reachabilityManager?.networkReachabilityStatus

        if status == AFNetworkReachabilityStatusReachableViaWiFi || status == AFNetworkReachabilityStatusReachableViaWWAN {
            DispatchQueue.main.async(execute: { [self] in
                refreshAuthenticationSession()
            })
        } else if status == AFNetworkReachabilityStatusNotReachable {
            noFlowLabel.text = Bundle.mxk_localizedString(forKey: "network_error_not_reachable")
        }
    }

    /// Force dismiss keyboard

    // MARK: - Keyboard handling

    func dismissKeyboard() {
        // Hide the keyboard
        authInputsView?.dismissKeyboard()
        homeServerTextField.resignFirstResponder()
        identityServerTextField.resignFirstResponder()
    }

    // MARK: - UITextField delegate

    @objc func onTextFieldChange(_ notif: Notification?) {
        submitButton.isEnabled = authInputsView?.areAllRequiredFieldsSet ?? false

        if (notif?.object as? UITextField) == homeServerTextField {
            // If any, the current request is obsolete
            cancelIdentityServerCheck()

            setIdentityServerHidden(true)
        }
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == homeServerTextField {
            // Cancel supported AuthFlow refresh if a request is in progress
            NotificationCenter.default.removeObserver(self, name: AFNetworkingReachabilityDidChangeNotification, object: nil)

            if mxCurrentOperation != nil {
                // Cancel potential request in progress
                mxCurrentOperation?.cancel()
                mxCurrentOperation = nil
            }
        }

        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == homeServerTextField {
            setHomeServerTextFieldText(textField.text)
        } else if textField == identityServerTextField {
            setIdentityServerTextFieldText(textField.text)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.returnKeyType == .done {
            // "Done" key has been pressed
            textField.resignFirstResponder()
        }
        return true
    }

    // MARK: - AuthInputsViewDelegate delegate

    func authInputsView(_ authInputsView: MXKAuthInputsView?, present inputsAlert: UIAlertController?) {
        dismissKeyboard()
        if let inputsAlert = inputsAlert {
            present(inputsAlert, animated: true)
        }
    }

    func authInputsViewDidPressDoneKey(_ authInputsView: MXKAuthInputsView?) {
        if submitButton.isEnabled {
            // Launch authentication now
            onButtonPressed(submitButton)
        }
    }

    func authInputsViewThirdPartyIdValidationRestClient(_ authInputsView: MXKAuthInputsView?) -> MXRestClient? {
        return mxRestClient
    }

    func authInputsViewThirdPartyIdValidationIdentityService(_ authInputsView: MXIdentityService?) -> MXIdentityService? {
        return identityService
    }

    // MARK: - Authentication Fallback

    /// Display the fallback URL within a webview.

    // MARK: - Authentication Fallback

    func showAuthenticationFallBackView() {
        showAuthenticationFallBackView(authenticationFallback)
    }

    func showAuthenticationFallBackView(_ fallbackPage: String?) {
        var fallbackPage = fallbackPage
        authenticationScrollView.isHidden = true
        authFallbackContentView.isHidden = false

        // Add a cancel button in case of navigation controller use.
        if navigationController {
            if cancelFallbackBarButton == nil {
                cancelFallbackBarButton = UIBarButtonItem(title: Bundle.mxk_localizedString(forKey: "login_leave_fallback"), style: .plain, target: self, action: #selector(hideRegistrationFallbackView))
            }

            // Add cancel button in right bar items
            let rightBarButtonItems = navigationItem.rightBarButtonItems
            if let rightBarButtonItems = rightBarButtonItems, let cancelFallbackBarButton = cancelFallbackBarButton {
                navigationItem.rightBarButtonItems = rightBarButtonItems != nil ? rightBarButtonItems + [cancelFallbackBarButton] : [cancelFallbackBarButton].compactMap { $0 }
            }
        }

        if let softLogoutCredentials = softLogoutCredentials {
            // Add device_id as query param of the fallback
            let components = NSURLComponents(string: fallbackPage ?? "")

            var queryItems = components?.queryItems as [NSURLQueryItem]?
            if queryItems == nil {
                queryItems = []
            }

            queryItems?.append(
                NSURLQueryItem(
                    name: "device_id",
                    value: softLogoutCredentials.deviceId))

            components?.queryItems = queryItems as [URLQueryItem]?

            fallbackPage = components?.url?.absoluteString
        }

        authFallbackWebView?.openFallbackPage(fallbackPage, success: { [self] loginResponse in

            let credentials = MXCredentials(loginResponse: loginResponse, andDefaultCredentials: mxRestClient?.credentials)

            // TODO handle unrecognized certificate (if any) during registration through fallback webview.

            onSuccessfulLogin(credentials)
        })
    }

    @objc func hideRegistrationFallbackView() {
        if let cancelFallbackBarButton = cancelFallbackBarButton {
            var rightBarButtonItems: [UIBarButtonItem]? = nil
            if let rightBarButtonItems1 = navigationItem.rightBarButtonItems {
                rightBarButtonItems = rightBarButtonItems1
            }
            rightBarButtonItems?.removeAll { $0 as AnyObject === cancelFallbackBarButton as AnyObject }
            navigationItem.rightBarButtonItems = rightBarButtonItems
        }

        authFallbackWebView?.stopLoading()
        authenticationScrollView.isHidden = false
        authFallbackContentView.isHidden = true
    }

    // MARK: - KVO

    func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [String : Any]?, context: UnsafeMutableRawPointer?) {
        if "viewHeightConstraint.constant" == keyPath {
            // Refresh the height of the auth inputs view container.
            let previousInputsContainerViewHeight = authInputContainerViewHeightConstraint.constant
            authInputContainerViewHeightConstraint.constant = authInputsView?.viewHeightConstraint.constant ?? 0.0

            // Force to render the view
            view.layoutIfNeeded()

            // Refresh content view height by considering the updated height of inputs container
            contentViewHeightConstraint.constant += authInputContainerViewHeightConstraint.constant - previousInputsContainerViewHeight
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
