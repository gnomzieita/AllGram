//
//  AuthViewModel.swift
//  AllGram
//
//  Created by Admin on 13.08.2021.
//

//import Foundation
//import Combine
//import MatrixSDK
//import KeychainAccess
//import UIKit
//
//struct ErrorAlert: Error, Identifiable {
//    let id = UUID()
//    let title = "Error"
//    var message = "Something gone wrong!"
//}
//
//enum AuthType {
//    case register
//    case login
//    case forgotPassword
//}
//
//enum LoginState {
//    case loggedOut
//    case authenticating(inRegistration: Bool)
//    case failure(Error)
//    case loggedIn(userId: String)
//}
//
//class AuthViewModel: ObservableObject {
//    private var cancellable = Set<AnyCancellable>()
//    private var sessionCancels: AnyCancellable?
//
//    //MARK: - Published proporties
//    @Published var errorAlert: ErrorAlert?
//    @Published var usernameForAuth: String = ""
//    @Published var passwordForAuth: String = ""
//    @Published var emailForAuth: String = ""
//    @Published var phoneForAuth: String = ""
//    @Published var inviteCodeForAuth: String = ""
//
//    @Published var isValidLoginForm = false
//    @Published var loginMessage = ""
//
//    @Published var isValidForgotPassForm = false
//    @Published var forgotPassMessage = ""
//
//    @Published var isValidEmailForm = false
//    @Published var emailMessage = ""
//
//    @Published var isValidRegistrationForm = false
//    @Published var singUpMessage = ""
//    @Published var loginState: LoginState = .loggedOut {
//        didSet {
//        }
//    }
//
//    var client: MXRestClient?
//    @Published var session: MXSession?
//
//    let keychain = Keychain(service: "chat.allgram.credentials",
//                            accessGroup: ((Bundle.main.infoDictionary?["DevelopmentTeam"] as? String) ?? "") + ".allgram.keychain")
//
//    //MARK: - Private proporties
//
//    private var authType: AuthType? {
//        didSet {
//            // Cancel external registration parameters if any
//            externalRegistrationParameters = nil
//        }
//    }
//
//    ///Property for storing data in app
//    private var fileStore: MXFileStore?
//
//    /// The set of parameters ready to use for a registration.
//    private var externalRegistrationParameters: [String : Any]?
//
//    /// Current request in progress.
//    private var mxCurrentOperation: MXHTTPOperation?
//
//    /// Successfully login credentials
//    private var credentials: MXCredentials?
//
//    /// The default country code used to initialize the mobile phone number input.
//    private var defaultCountryCode: String?
//
//    /// Contains registration and completed flows
//    private var authSession: MXAuthenticationSession?
//
//    /// The current authentication fallback URL (if any).
//    private var authenticationFallback: URL?
//
//    // Current SSO flow containing Identity Providers. Used for `socialLoginListView`
//    private var currentLoginSSOFlow: MXLoginSSOFlow?
//
//    /// For mutiple devices
//    private var crossSigningService: CrossSigningService?
//
//    /// The current email validation
//    private var submittedEmail: MXK3PID?
//
//    /// The current msisdn validation
//    private var submittedMSISDN: MXK3PID?
//
//    /// The block called when the parameters are ready and the user confirms he has checked his email.
//    private var didPrepareParametersCallback: ((_ parameters: [String : Any]?, _ error: Error?) -> Void)?
//
//    private var isAuthSessionContainsPasswordFlow: Bool = false
//
//    // Returns device model, os version and os name
//    private var deviceDisplayName: String {
//        return UIDevice.current.model + " "
//        + UIDevice.current.systemName + " "
//        + UIDevice.current.systemVersion
//        // UIDevice.current.identifierForVendor?.uuidString
//    }
//
//    /// Return `TRUE` or `FALSE` if authSession contains PasswordFlow
//    private var containsPasswordFlow: AnyPublisher<Bool, Never> {
//        let areContains = authSession?.flows.map { $0.contains(where: { $0.type == kMXLoginFlowTypePassword}) } ?? false
//
//        return Just(areContains)
//            .eraseToAnyPublisher()
//    }
//
//    ///Registration timer publisher
//    private var registrationTimer: Publishers.Autoconnect<Timer.TimerPublisher>? = nil
//    private var timerSubscription: AnyCancellable? = nil
//    private var isTimerRunning: Bool {
//        registrationTimer != nil
//    }
//
//    /// Tell whether some third-party identifiers may be added during the account registration.
//    private var areThirdPartyIdentifiersSupported: Bool {
//        return isFlowSupported(kMXLoginFlowTypeEmailIdentity) || isFlowSupported(kMXLoginFlowTypeMSISDN)
//    }
//
//    /// Tell whether a second third-party identifier is waiting for being added to the new account.
//    private var isThirdPartyIdentifierPending: Bool {
//        return ((emailForAuth.trimmingCharacters(in: .whitespacesAndNewlines) != "" && isFlowCompleted(kMXLoginFlowTypeEmailIdentity)) ||
//        (phoneForAuth.trimmingCharacters(in: .whitespacesAndNewlines) != "" && isFlowCompleted(kMXLoginFlowTypeMSISDN)))
//    }
//
//    /// Tell whether at least one third-party identifier is required to create a new account.
//    var isThirdPartyIdentifierRequired: Bool {
//        // Check first whether some 3pids are supported
//        if !areThirdPartyIdentifiersSupported {
//            return false
//        }
//
//        // Check whether an account may be created without third-party identifiers.
//        for loginFlow in authSession!.flows {
//            if (loginFlow.stages.firstIndex(of: kMXLoginFlowTypeEmailIdentity) ?? NSNotFound) == NSNotFound && (loginFlow.stages.firstIndex(of: kMXLoginFlowTypeMSISDN) ?? NSNotFound) == NSNotFound {
//                // There is a flow with no 3pids
//                return false
//            }
//        }
//
//        return true
//    }
//
//    /// Tell whether all the supported third-party identifiers are required to create a new account.
//    var areAllThirdPartyIdentifiersRequired: Bool {
//        // Check first whether some 3pids are required
//        if !isThirdPartyIdentifierRequired {
//            return false
//        }
//
//        let isEmailIdentityFlowSupported = isFlowSupported(kMXLoginFlowTypeEmailIdentity)
//        let isMSISDNFlowSupported = isFlowSupported(kMXLoginFlowTypeMSISDN)
//
//        for loginFlow in authSession!.flows {
//            if isEmailIdentityFlowSupported {
//                if !loginFlow.stages.contains(kMXLoginFlowTypeEmailIdentity) {
//                    return false
//                } else if isMSISDNFlowSupported {
//                    if !loginFlow.stages.contains(kMXLoginFlowTypeMSISDN) {
//                        return false
//                    }
//                }
//            } else if isMSISDNFlowSupported {
//                if !loginFlow.stages.contains(kMXLoginFlowTypeMSISDN) {
//                    return false
//                }
//            }
//        }
//
//        return true
//    }
//
//    private var listenReference: Any?
//    private var listenReferenceRoom: Any?
//    private var roomCache = [ObjectIdentifier: AllgramRoom]()
//
//    // Input values validation
//    private var isUsernameValidPublisher: AnyPublisher<Bool, Never> {
//        $usernameForAuth
//            .debounce(for: 0.7, scheduler: RunLoop.main)
//            .map { $0.count >= 3 }
//            .eraseToAnyPublisher()
//    }
//
//    private var isEmailNotEmptyPublisher: AnyPublisher<Bool, Never> {
//        $emailForAuth
//            .debounce(for: 0.7, scheduler: RunLoop.main)
//            .removeDuplicates()
//            .map { $0 != "" }
//            .eraseToAnyPublisher()
//    }
//
//    private var isPasswordNotEmptyPublisher: AnyPublisher<Bool, Never> {
//        $passwordForAuth
//            .debounce(for: 0.7, scheduler: RunLoop.main)
//            .removeDuplicates()
//            .map { $0 != "" }
//            .eraseToAnyPublisher()
//    }
//
//    private var isEmailForAuthValidPublisher: AnyPublisher<Bool, Never> {
//        let emailPattern = #"^\S+@\S+\.\S+$"#
//
//        return $emailForAuth
//            .map { $0.range(of: emailPattern, options: .regularExpression) != nil }
//            .eraseToAnyPublisher()
//    }
//
//    private var isLoginForValidatePublisher: AnyPublisher <Bool, Never> {
//        Publishers.CombineLatest(isUsernameValidPublisher, isPasswordNotEmptyPublisher)
//            .map { $0 && $1 }
//            .eraseToAnyPublisher()
//    }
//
//    private var isForgotPassFormValidatePublisher: AnyPublisher <Bool, Never> {
//        Publishers.CombineLatest(isEmailNotEmptyPublisher, isPasswordNotEmptyPublisher)
//            .map { $0 && $1 }
//            .eraseToAnyPublisher()
//    }
//
//    private var isRegisterFormValidatePublisher: AnyPublisher <Bool, Never> {
//        Publishers.CombineLatest3(isUsernameValidPublisher, isPasswordNotEmptyPublisher, isEmailNotEmptyPublisher)
//            .map { $0 && $1 && $2 }
//            .eraseToAnyPublisher()
//    }
//
//    private(set) var loggedInFromStoredCredentials = false
//
//    static let shared = AuthViewModel()
//
//    @objc
//    private func handleClientError(_ notification: NSNotification) {
//        if let object = notification.userInfo as? [String:Any] {
//            let error = object["kMXHTTPClientMatrixErrorNotificationErrorKey"] as! MXError
//            if error.errcode == "M_UNKNOWN_TOKEN" {
//                // Do not do logout, we already lost access
//                // and will get only errors on all requests
//
//                // Our session was terminated on other device
//                // and no other case will cause this? Hm...
//                // No, it happens time to time on its own!
//
//                //self.loginState = .loggedOut
//            }
//        }
//    }
//
//    // MARK: - Init
//
//    private init() {
//        // Listen to MXClient errors (for terminating session)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleClientError), name: Notification.Name("kMXHTTPClientMatrixErrorNotification"), object: nil)
//
//        // Clear credentials on first launch (fix reinstall with login)
//        if SettingsManager.applicationLaunchCounter < 2 {
//            // First launch, clear old login details
//            MXCredentials
//                .from(keychain)?
//                .clear(from: keychain)
//        }
//
//        // Clears credentials when specific command added
//        if CommandLine.arguments.contains("-clear-stored-credentials") {
//            MXCredentials
//                .from(keychain)?
//                .clear(from: keychain)
//        }
//
//        defaultCountryCode = "UA"
//        crossSigningService = CrossSigningService()
//        Configuration.setupMatrixSDKSettings()
//        authSession = MXAuthenticationSession(fromJSON: [
//            "flows": [[
//                "stages": [kMXLoginFlowTypePassword]
//            ]]
//        ])
//        setAuthSession(authSession, withAuthType: .login)
//
//        if let credentials = MXCredentials.from(keychain) {
//
//            // Check if credentials from prod/dev are matching current server
//            if credentials.homeServer == API.server.baseURL {
//
//                self.loginState = .authenticating(inRegistration: false)
//                self.authType = .login
//                self.credentials = credentials
//                self.sync { result in
//                    switch result {
//                    case .failure(let error):
//                        self.loginState = .failure(error)
//                    case .success(let state):
//                        self.loggedInFromStoredCredentials = true
//                        self.loginState = state
//                        self.session?.crypto.warnOnUnknowDevices = false
//                        PushNotifications.shared.subscribe(model: self)
//                        UserNotifications.shared.subscribe(with: self)
//                    }
//                }
//            }
//        }
//
//        // MARK: - Business-logic publishers
//
//        listenToRoomListChange()
//
//        sessionCancels = $session
//            .map { $0?.state }
//            .sink { [weak self] state in
//                if state == .storeDataReady {
//                    // Do not make key share requests while the "Complete security" is not complete.
//                    // If the device is self-verified, the SDK will restore the existing key backup.
//                    // Then, it  will re-enable outgoing key share requests
//                    if self?.session?.crypto.crossSigning != nil {
//                        self?.session?.crypto.setOutgoingKeyRequestsEnabled(false, onComplete: nil)
//                    }
//                } else if state == .running {
//                    //TODO: - We need to cancel subscription after getting running state
//                    self?.sessionCancels?.cancel()
//
//                    if self?.session?.crypto.crossSigning != nil {
//                        self?.session?.crypto.crossSigning.refreshState(success: { stateUpdated in
//                            switch self?.session?.crypto.crossSigning.state {
//                            case .notBootstrapped:
//                                // TODO: This is still not sure we want to disable the automatic cross-signing bootstrap
//                                // if the admin disabled e2e by default.
//                                // Do like riot-web for the moment
//                                self?.session?.crypto.crossSigning.setup(withPassword: self?.passwordForAuth ?? "", success: {
//                                }, failure: { error in
//                                    self?.session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
//                                })
//                            case .crossSigningExists:
//                                break
//                                // TODO: What i have to do with it?
//                            default:
//                                self?.session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
//                            }
//                        }, failure: { error in
//                            self?.session?.crypto.setOutgoingKeyRequestsEnabled(true, onComplete: nil)
//                        })
//                    }
//                }
//            }
//
//        containsPasswordFlow
//            .assign(to: \.isAuthSessionContainsPasswordFlow, on: self)
//            .store(in: &cancellable)
//
//        // MARK: - UI Publishers
//
//        isLoginForValidatePublisher
//            .receive(on: RunLoop.main)
//            .assign(to: \.isValidLoginForm, on: self)
//            .store(in: &cancellable)
//
//        isForgotPassFormValidatePublisher
//            .receive(on: RunLoop.main)
//            .assign(to: \.isValidForgotPassForm, on: self)
//            .store(in: &cancellable)
//
//        isRegisterFormValidatePublisher
//            .receive(on: RunLoop.main)
//            .assign(to: \.isValidRegistrationForm, on: self)
//            .store(in: &cancellable)
//
//        isEmailForAuthValidPublisher
//            .receive(on: RunLoop.main)
//            .assign(to: \.isValidEmailForm, on: self)
//            .store(in: &cancellable)
//
//        Publishers.CombineLatest(isEmailNotEmptyPublisher, isPasswordNotEmptyPublisher)
//            .receive(on: RunLoop.main)
//            .debounce(for: 0.2, scheduler: RunLoop.main)
//            .map { emailCheck, passCheck in
//                if !emailCheck {
//                    return "Email can't be empty"
//                }
//                if !passCheck {
//                    return "Password can't be empty"
//                }
//                return ""
//            }
//            .assign(to: \.forgotPassMessage, on: self)
//            .store(in: &cancellable)
//
//        Publishers.CombineLatest(isUsernameValidPublisher, isPasswordNotEmptyPublisher)
//            .receive(on: RunLoop.main)
//            .debounce(for: 0.2, scheduler: RunLoop.main)
//            .map { usernameCheck, passCheck in
//                if !usernameCheck {
//                    return "Username minimum length is 3 characters"
//                }
//                if !passCheck {
//                    return "Password can't be empty"
//                }
//                return ""
//            }
//            .assign(to: \.loginMessage, on: self)
//            .store(in: &cancellable)
//
//        Publishers.CombineLatest3(isUsernameValidPublisher, isPasswordNotEmptyPublisher, isEmailNotEmptyPublisher)
//            .receive(on: RunLoop.main)
//            .debounce(for: 0.2, scheduler: RunLoop.main)
//            .map { usernameCheck, passCheck, emailCheck in
//                if !usernameCheck {
//                    return "Username minimum length is 3 characters"
//                } else if !passCheck {
//                    return "Password can't be empty"
//                } else if !emailCheck {
//                    return "Email can't be empty"
//                } else {
//                    return ""
//                }
//            }
//            .assign(to: \.singUpMessage, on: self)
//            .store(in: &cancellable)
//
//        isEmailForAuthValidPublisher
//            .receive(on: RunLoop.main)
//            .debounce(for: 0.2, scheduler: RunLoop.main)
//            .map { valid in
//                if !valid {
//                    return "Invalid email"
//                } else {
//                    return ""
//                }
//            }
//            .assign(to: \.emailMessage, on: self)
//            .store(in: &cancellable)
//
//    }
//
//    //MARK: - Private methods
//
//
//    private func setAuthSession(_ authSession: MXAuthenticationSession?, withAuthType authType: AuthType) {
//        switch authType {
//        case .login, .register:
//            // Cancel email validation if any
//            if submittedEmail != nil {
//                submittedEmail?.cancelCurrentRequest()
//                submittedEmail = nil
//            }
//
//            // Cancel msisdn validation if any
//            if submittedMSISDN != nil {
//                submittedMSISDN?.cancelCurrentRequest()
//                submittedMSISDN = nil
//            }
//
//            // Reset external registration parameters
//            externalRegistrationParameters = nil
//        case .forgotPassword:
//            // authSession is not used here, filled it by default (it should be nil).
//            self.authSession = authSession
//
//            mxCurrentOperation = nil
//            didPrepareParametersCallback = nil
//        }
//    }
//
//
//
//    /// Check if a flow (kMXLoginFlowType*) is part of the required flows steps.
//    /// - Parameter flow: the flow type to check.
//    /// - Returns: YES if the the flow must be implemented.
//    private func isFlowSupported(_ flow: String?) -> Bool {
//
//        guard let authSession = authSession else {
//            fatalError("No Auth Session were found")
//        }
//
//        for loginFlow in authSession.flows {
//            if (loginFlow.type == flow) || loginFlow.stages.contains(flow ?? "") {
//                return true
//            }
//        }
//
//        return false
//    }
//
//    /// Check if a flow (kMXLoginFlowType*) has already been completed.
//    /// - Parameter flow: the flow type to check.
//    /// - Returns: YES if the the flow has been completedd.
//    private func isFlowCompleted(_ flow: String?) -> Bool {
//        if let completedArray = authSession?.completed {
//            return completedArray.contains(flow ?? "")
//        }
//
//        return false
//    }
//
//    private func handleCredentials(_ credentials: MXCredentials) {
//        self.credentials = credentials
//        self.credentials?.allowedCertificate = credentials.allowedCertificate
//
//        if self.credentials?.identityServer == nil {
//            self.credentials?.identityServer = API.identityServer.getURL()?.absoluteString
//        }
//
//        credentials.save(to: self.keychain)
//
//        self.sync { result in
//            switch result {
//            case .failure(let error):
//                self.loginState = .failure(error)
//                self.errorAlert = ErrorAlert(message: error.localizedDescription)
//            case .success(let state):
//                self.loggedInFromStoredCredentials = false
//                self.loginState = state
//                // We always need crypto
//                if self.session?.crypto == nil {
//                    self.session?.enableCrypto(true) { [weak self] response in
//                        switch response {
//                        case .success:
//                            self?.session?.crypto.warnOnUnknowDevices = false
//                        case .failure(let error):
//                            self?.loginState = .failure(error)
//                            self?.errorAlert = ErrorAlert(message: error.localizedDescription)
//                        }
//                    }
//                } else {
//                    self.session?.crypto.warnOnUnknowDevices = false
//                }
//				PushNotifications.shared.subscribe(model: self)
//                UserNotifications.shared.subscribe(with: self)
//
//                //Clear entered data
//                self.usernameForAuth = ""
//                self.passwordForAuth = ""
//                self.emailForAuth = ""
//                self.phoneForAuth = ""
//            }
//        }
//    }
//
//    /// A final part of registration and logining process
//    private func sync(completion: @escaping (Result<LoginState, Error>) -> Void) {
//        guard let credentials = self.credentials else {
//            completion(.failure(ErrorAlert(message: "No credentials")))
//            return
//        }
//
//        self.client = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
//        self.session = MXSession(matrixRestClient: self.client!)
//        self.fileStore = MXFileStore()
//
//        CallHandler.shared.prepareCallManagerIfNeeded(session: session)
//
//        self.session!.setStore(fileStore!) { response in
//            switch response {
//            case .failure(let error):
//                completion(.failure(error))
//            case .success:
//                self.session!.start { response in
//                    switch response {
//                    case .failure(let error):
//                        completion(.failure(error))
//                    case .success:
//                        let userId = credentials.userId!
//                        completion(.success(.loggedIn(userId: userId)))
//                    }
//                }
//            }
//        }
//
//    }
//
//    /// A part of public logout()
//    private func logoutWithAfterProcessing(completion: @escaping (Result<LoginState, Error>) -> Void) {
//		PushNotifications.shared.unsubscribe(model: self) {
//			self.doLogout(completion: completion)
//		}
//	}
//
//	private func doLogout(completion: @escaping (Result<LoginState, Error>) -> Void) {
//        self.credentials?.clear(from: keychain)
//
//        guard let session = self.session else {
//            loginState = .loggedOut
//			PushNotifications.shared.unsubscribe(model: self)
//            UserNotifications.shared.unsubscribe()
//            authSession = nil
//            return
//        }
//
//        session.logout { [unowned self] response in
//            switch response {
//            case .failure(let error):
//                errorAlert = ErrorAlert(message: "Logout error: \(error.localizedDescription)")
//                completion(.failure(error))
//            case .success:
//                completion(.success(.loggedOut))
//            }
//        }
//    }
//
//    private func updateUserDefaults(with rooms: [AllgramRoom]) {
//        let roomItems = rooms.map { RoomItem(room: $0.room) }
//        do {
//            let data = try JSONEncoder().encode(roomItems)
//            UserDefaults.group.set(data, forKey: "roomList")
//        } catch {
//        }
//    }
//
//    private func makeRoom(from mxRoom: MXRoom) -> AllgramRoom {
//        let room = AllgramRoom(mxRoom, in: session!)
//        roomCache[mxRoom.id] = room
//        return room
//    }
//
//    private var roomsListChangePublisher : Publishers.MergeMany<NotificationCenter.Publisher>?
//    private func listenToRoomListChange() {
//        let nc = NotificationCenter.default
//        let listOfNotificationNames : [Notification.Name] =
//        [
//            // Matrix Notifications
//            .mxSessionNewRoom, .mxRoomSummaryDidChange,
//            .mxSessionDidLeaveRoom, .mxSessionInvitedRoomsDidChange,
//            .mxSessionIgnoredUsersDidChange
//
//            // Also update to fix new created chat not being chat at first
////            .allgramRoomIsDirectStateChanged
//        ]
//
//        let mergedPublisher = Publishers.MergeMany(
//            listOfNotificationNames.map { nc.publisher(for: $0, object: nil) }
//        )
//        roomsListChangePublisher = mergedPublisher
//
//        mergedPublisher.sink { _ in
//            self.counterOfRoomChanges += 1
//        }.store(in: &cancellable)
//    }
//
//    /// Handle the error received during an authentication request.
//    /// - Parameter error: the received error.
//    func onFailureDuringAuthRequest(_ error: Error?) {
//        mxCurrentOperation = nil
//        //        authenticationActivityIndicator.stopAnimating()
//
//        // Cancel external registration parameters if any
//        externalRegistrationParameters = nil
//
//        // Alert user
//        errorAlert = ErrorAlert(message: "Failure during auth request.\n \(error?.localizedDescription ?? "(no external error description)")")
//
//        loginState = .loggedOut
//		PushNotifications.shared.unsubscribe(model: self)
//        UserNotifications.shared.unsubscribe()
//    }
//
//    // MARK: - Register
//
//    /// Registers new user. Phone number and invitation code are optional
//    func registerUser(username: String, password: String, email: String, phone: String? = nil, inviteCode: String? = nil) {
//        client = MXRestClient(homeServer: API.server.getURL()!, unrecognizedCertificateHandler: nil)
//        loginState = .authenticating(inRegistration: true)
//        authType = .register
//        client!.testUserRegistration(username) { [unowned self] error in
//            guard error == nil else {
//                errorAlert = ErrorAlert(message: error!.error)
//                loginState = .loggedOut
//                PushNotifications.shared.unsubscribe(model: self)
//                UserNotifications.shared.unsubscribe()
//                return
//            }
//            var parameters = [String: Any]()
//            parameters = [
//                "username": username,
//                "password": password,
//                "initial_device_display_name": deviceDisplayName,
//                "unvalidated_email": email
//            ]
//            if let phoneNumber = phone {
//                parameters["unvalidated_msisdn"] = phoneNumber.replacingOccurrences(of: "+", with: "")
//            }
//            if let code = inviteCode {
//                parameters["user_reserved_secret"] = code
//            }
//            guard let tClient = client else {
//                errorAlert = ErrorAlert(message: "Internal")
//                loginState = .loggedOut
//                PushNotifications.shared.unsubscribe(model: self)
//                UserNotifications.shared.unsubscribe()
//                return
//            }
//            mxCurrentOperation = tClient.register(parameters: parameters) { response in
//                // This call EXPECTS error 401, but returns needed data anyway
//                switch response {
//                case .success(_):
//                    // Theoretically will never happen as we need .failure case to proceed
//                    break
//                case .failure(let error):
//                    let nsError = error as NSError
//
//                    guard let errorData = nsError.userInfo["com.matrixsdk.httpclient.error.response.data"] as? [String: Any],
//                          let sessionID = errorData["session"] as? String
//                    else {
//                        self.mxCurrentOperation = nil
//                        self.loginState = .loggedOut
//                        PushNotifications.shared.unsubscribe(model: self)
//                        UserNotifications.shared.unsubscribe()
//                        return
//                    }
//                    var authParams = [String: Any]()
//                    authParams = [
//                        "auth": [
//                            "type": kMXLoginFlowTypeDummy,
//                            "session": sessionID
//                        ]
//                    ]
//                    guard let tClient = self.client else {
//                        self.errorAlert = ErrorAlert(message: "Internal")
//                        self.loginState = .loggedOut
//                        PushNotifications.shared.unsubscribe(model: self)
//                        UserNotifications.shared.unsubscribe()
//                        return
//                    }
//                    self.mxCurrentOperation = tClient.register(parameters: authParams) { response in
//                        switch response {
//                        case .success(let resultParams):
//                            let loginResponse = MXLoginResponse(fromJSON: resultParams)
//                            let loginCredentials = MXCredentials(loginResponse: loginResponse!, andDefaultCredentials: self.client?.credentials)
//                            if loginCredentials.userId == nil || loginCredentials.accessToken == nil {
//                                // Was in old register, leave it here
//                                self.onFailureDuringAuthRequest(NSError(domain: URLError.errorDomain, code: 0, userInfo: [
//                                    NSLocalizedDescriptionKey: "Not supported yet."
//                                ]))
//                            } else {
//                                self.handleCredentials(loginCredentials)
//                            }
//                        case .failure(let error):
//                            self.mxCurrentOperation = nil
//                            self.loginState = .loggedOut
//                            PushNotifications.shared.unsubscribe(model: self)
//                            UserNotifications.shared.unsubscribe()
//                            if let mxError = MXError(nsError: error) {
//                                self.errorAlert = ErrorAlert(message: mxError.error)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    // MARK: - Login
//
//    private enum LoginType: String {
//        case password = "password"
//        case qr = "qr"
//        case google = "google"
//    }
//
//    /// Uses username and password to login
//    func loginUser(username: String, password: String) {
//        /*
//         {
//             "type": "m.login.password",
//             "identifier": {
//                 "type": "m.id.user",
//                 "user": "{{user-login}}"
//             },
//             "password": "{{user-pass}}",
//             "initial_device_display_name": "test postman UA"
//         }
//         */
//        var params = [String: Any]()
//        params["type"] = "m.login.password"
//        params["identifier"] = [
//            "type": "m.id.user",
//            "user": username
//        ]
//        params["password"] = password
//        params["initial_device_display_name"] = self.deviceDisplayName
//        loginUser(with: params, loginType: .password)
//    }
//
//    /// Uses userId and secret to login (from QR code)
//    func loginUser(userId: String, secret: String) {
//        /*
//         {
//             "type": "m.login.qr",
//             "identifier": {
//                 "type": "m.id.user",
//                 "user": "{{user-id}}"
//             },
//             "secret": "{{secret}}"
//             "initial_device_display_name": "test postman UA"
//         }
//         */
//        var params = [String: Any]()
//        params["type"] = "m.login.qr"
//        params["identifier"] = [
//            "type": "m.id.user",
//            "user": userId
//        ]
//        params["secret"] = secret
//        params["initial_device_display_name"] = self.deviceDisplayName
//        loginUser(with: params, loginType: .qr)
//    }
//
//    /// Uses token from redirected google sign in
//    func loginUser(redirectToken: String) {
//        var params = [String: Any]()
//        params["type"] = "m.login.token"
//        params["token"] = redirectToken
//        params["initial_device_display_name"] = self.deviceDisplayName
//        loginUser(with: params, loginType: .google)
//    }
//
//    /// Pings server and then uses provided parameters to login the user.
//    /// `LoginType` needed only for Firebase Analytics
//    private func loginUser(with parameters: [String: Any], loginType: LoginType) {
////        afterPingServer { [unowned self] in
//            self.loginState = .authenticating(inRegistration: false)
//            self.authType = .login
//            self.client = MXRestClient(homeServer: API.server.getURL()!, unrecognizedCertificateHandler: nil)
//            self.client!.login(parameters: parameters) { [unowned self] response in
//                switch response {
//                case .success(let loginData):
//                    let loginResponse = MXLoginResponse(fromJSON: loginData)
//                    let loginCredentials = MXCredentials(loginResponse: loginResponse!, andDefaultCredentials: self.client?.credentials)
//                    AnalyticsManager.logLogin(loginType.rawValue)
//                    self.handleCredentials(loginCredentials)
//                case .failure(_):
//                    self.credentials?.clear(from: keychain)
//                    self.loginState = .loggedOut
//                    PushNotifications.shared.unsubscribe(model: self)
//                    UserNotifications.shared.unsubscribe()
//                    errorAlert = ErrorAlert(message: response.error!.localizedDescription)
//                }
//            }
////        }
//    }
//
//    // MARK: - Redirect Google Sign In
//
//    /// URL to open for redirecting to google login.
//    /// When user confirms their account, it will redirect back to our app
//    var googleRedirect: URL {
//        var urlComponents = URLComponents(string: API.server.baseURL)!
//        urlComponents.port = API.server.port
//        urlComponents.path = "/_matrix/client/r0/login/sso/redirect"
//        let qItem = URLQueryItem(name: "redirectUrl", value: "allgram://connect")
//        urlComponents.queryItems = [qItem]
//        return urlComponents.url!
//    }
//
//    func getRedirectLoginToken(from url: URL) -> String? {
//        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
//           let queryItems = components.queryItems,
//           let tokenItem = queryItems.first,
//           tokenItem.name == "loginToken"
//        {
//            return tokenItem.value
//        } else {
//            return nil
//        }
//    }
//
//    // MARK: - Forgot Password
//
//    typealias ForgotPasswordData = (sid: String, secret: String, email: String, newPassword: String)
//
//    /// Uses given email to confirm setting new password for the user of that email.
//    /// Provides data required to reset password or error if failed
//    func forgotUserPassword(email: String, newPassword: String, completion: @escaping (Result<ForgotPasswordData, ErrorAlert>) -> Void) {
//        let secret = MXTools.generateSecret()!
////        afterPingServer { [unowned self] in
//            self.client = MXRestClient(homeServer: API.server.getURL()!, unrecognizedCertificateHandler: nil)
//            self.client!.forgetPassword(
//                forEmail: email,
//                clientSecret: secret,
//                sendAttempt: 1,
//                success: { sid in
//                    guard let sid = sid else {
//                        let error = ErrorAlert(message: "Failed to get SID.")
//                        completion(.failure(error))
//                        return
//                    }
//                    let data = (sid, secret, email, newPassword)
//                    completion(.success(data))
//                },
//                failure: { error in
//                    let error = ErrorAlert(message: error?.localizedDescription ?? "Failed with no error.")
//                    completion(.failure(error))
//                }
//            )
////        }
//    }
//
//    /// Resets user password if it was confirmed on the email (link)
//    func resetPassword(_ data: ForgotPasswordData, completion: @escaping (Result<Void, ErrorAlert>) -> Void) {
//        var params = [String: Any]()
//        params["auth"] = [
//            "type": "m.login.email.identity",
//            "threepid_creds": [
//                "client_secret": data.secret,
//                "sid": data.sid
//            ],
//        ]
//        params["new_password"] = data.newPassword
//        self.client = MXRestClient(homeServer: API.server.getURL()!, unrecognizedCertificateHandler: nil)
//        self.client!.resetPassword(parameters: params) { response in
//            switch response {
//            case .success:
//                completion(.success(()))
//            case .failure(let error):
//                let error = ErrorAlert(message: error.localizedDescription)
//                completion(.failure(error))
//            }
//        }
//    }
//
//    // MARK: -
//
//    private func getEmail(_ callback: @escaping (String) -> ()) {
//        let storedEmails = UserDefaults.group.pendingEmailsPhones.map({ $0.asEmailPhone }).filter({ $0.type == .email })
//        if let email = storedEmails.first?.text, email.count > 0 {
//            callback(email)
//        } else {
//            client?.thirdPartyIdentifiers() { response in
//                switch response {
//                case .success(let data):
//                    let loaded: [EmailPhone] = (data ?? [])
//                        .filter({ $0.medium == kMX3PIDMediumEmail })
//                        .map({ EmailPhone(type: .email, text: $0.address, isValid: true) })
//                    let stored = UserDefaults.group.pendingEmailsPhones.map({ $0.asEmailPhone })
//                    let emails = loaded + stored.filter({ $0.type == .email })
//                    if let email = emails.first?.text, email.count > 0 {
//                        callback(email)
//                    }
//                case .failure(_): break
//                }
//            }
//        }
//    }
//
//    /// Handle the error received during an deactivation request.
//    /// - Parameter error: the received error.
//    func onFailureDuringDeativateRequest(_ error: Error?) {
//        errorAlert = ErrorAlert(message: "Failure during deactivate account request.\n \(error?.localizedDescription ?? "(no external error description)")")
//    }
//
//    func deactivateAccount(password: String, completion: ((MXResponse<Void>) -> ())?){
//        guard let session = session else {return}
//        let parameters: [String: Any] = [
//            "type": kMXLoginFlowTypePassword,
//            "user": session.myUserId ?? "",
//            "password": password,
//            "session": authSession?.session ?? ""
//        ]
//        session.deactivateAccount(
//            withAuthParameters: parameters,
//            eraseAccount: false) { response in
//                completion?(response)
//                if response.isFailure{
//                    self.onFailureDuringDeativateRequest(response.error)
//                }
//                if response.isSuccess {
//                    self.loginState = .loggedOut
//					PushNotifications.shared.unsubscribe(model: self)
//                    UserNotifications.shared.unsubscribe()
//                    self.authSession = nil
//                }
//            }
//    }
//
//    func logout(_ completion: (() -> Void)? = nil) {
//        logoutWithAfterProcessing { result in
//            switch result {
//            case .failure:
//                // Close the session even if the logout request failed
//                self.loginState = .loggedOut
//            case .success(let state):
//                self.loginState = state
//            }
//			PushNotifications.shared.unsubscribe(model: self)
//            UserNotifications.shared.unsubscribe()
//            completion?()
//        }
//    }
//
//    func resetPassword(withParameters parameters: [String : Any]?,
//                       successCompletion: @escaping (() -> Void) ) {
//
//        guard let parameters = parameters else {
//            return
//        }
//
//        mxCurrentOperation = client?.resetPassword(parameters: parameters) { response in
//            switch response {
//            case .success:
//                self.mxCurrentOperation = nil
//
//                // Here the password has been reseted with success
//                self.loginState = .loggedOut
//				PushNotifications.shared.unsubscribe(model: self)
//                UserNotifications.shared.unsubscribe()
//                successCompletion()
//            case .failure(let error):
//                guard let mxError = MXError(nsError: error) else { return }
//                switch mxError.errcode {
//                case kMXErrCodeStringUnauthorized:
//
//                    self.mxCurrentOperation = nil
//                    //authenticationActivityIndicator.stopAnimating()
//                    self.onFailureDuringAuthRequest(error)
//                case kMXErrCodeStringNotFound:
//
//                    self.onFailureDuringAuthRequest(error)
//
//                default:
//                    self.onFailureDuringAuthRequest(error)
//                }
//            }
//        }
//    }
//
//    func changePassword(from current: String, to new: String, success: @escaping () -> Void, failure: @escaping () -> Void) {
//        client?.changePassword(from: current, to: new) { response in
//            switch response {
//            case .failure(_):
//                failure()
//            case .success():
//                success()
//            }
//        }
//    }
//
//    // MARK: - Custom Avatar Update
//
//    @Published private(set) var userAvatarURL: URL?
//    private var updatingAvatarURL = false
//
//    func updateAvatarURL() {
//        guard let id = session?.myUserId,
//              let token = session?.credentials.accessToken,
//              !updatingAvatarURL
//        else { return }
//        updatingAvatarURL = true
//        ApiManager.shared.getUserAvatar(userId: id, accessToken: token)
//            .sink { [weak self] uri in
//                var realUrl: URL?
//                if let urlString = self?.session?.mediaManager.url(ofContent: uri) {
//                    realUrl = URL(string: urlString)
//                }
//                self?.userAvatarURL = realUrl
//                self?.updatingAvatarURL = false
//            }.store(in: &cancellable)
//    }
//
//    //MARK: - Rooms methods
//
//    func join(to room: MXRoom, completion: ((Bool) -> Void)? = nil) {
//        room.join { [weak self] response in
//            self?.session?.roomsSummaries()
//            self?.counterOfRoomChanges += 1
//            switch response {
//            case .failure(_):
//                completion?(false)
//            case .success():
//                completion?(true)
//            }
//        }
//    }
//
//    func leave(from room: MXRoom, completion: ((Bool) -> Void)? = nil) {
//        room.leave { [weak self] response in
//            self?.session?.roomsSummaries()
//            self?.counterOfRoomChanges += 1
//            switch response {
//            case .failure(_):
//                completion?(false)
//            case .success():
//                completion?(true)
//            }
//        }
//    }
//
//    @Published var counterOfRoomChanges = 0
//
//    /// Rooms that are chats (direct chats, group chats, meetings)
//    var chatRooms: [AllgramRoom] { rooms.filter({ $0.isChat }) }
//
//    /// Rooms that are clubs
//    var clubRooms: [AllgramRoom] { rooms.filter({ $0.isClub }) }
//
//    /// All rooms that did NOT go into `chatRooms` and `clubRooms` (should be empty)
//    var otherRooms: [AllgramRoom] {
//        rooms.filter { room in
//            return !chatRooms.contains(where: { $0.room.roomId == room.room.roomId })
//            && !clubRooms.contains(where: { $0.room.roomId == room.room.roomId })
//        }
//    }
//
//    /// Rooms created by current user that are clubs
//    var clubsCreatedByUser: [AllgramRoom] { clubRooms.filter({ $0.summary.creatorUserId == session?.myUserId }) }
//
//    /// All rooms
//    var rooms: [AllgramRoom] {
//        guard let session = self.session else { return [] }
//        let rooms = session.rooms
//            .map { roomCache[$0.id] ?? makeRoom(from: $0) }
//            .sorted { $0.summary.lastMessageDate > $1.summary.lastMessageDate }
//        updateUserDefaults(with: rooms)
//        return rooms
//    }
//
//    var unreadChatsCount: Int {
//        var result = 0
//        for room in chatRooms {
//            if room.summary.notificationCount > 0 {
//                // Count rooms with unread messages
//                result += 1
//            } else if room.summary.membership == .invite {
//                // Also count invites to rooms
//                result += 1
//            }
//        }
//        return result
//    }
//
//    var unreadClubsCount: Int {
//        var result = 0
//        for room in clubRooms {
//            if room.summary.notificationCount > 0 {
//                // Count rooms with unread messages
//                result += 1
//            } else if room.summary.membership == .invite {
//                // Also count invites to rooms
//                result += 1
//            }
//        }
//        return result
//    }
//
//    /// ViewModel for searching clubs
//    private(set) lazy var clubSearcher = SearcherForClubs(auth: self)
//
//    /// ViewModel for my clubs
//    private(set) lazy var myClubsVM = MyClubsViewModel(auth: self)
//
//    // MARK: -
//
//    @Published private(set) var missedCallsCount = 0
//    private var isUpdatingMissed = false
//
//    /// Initiates update of missed calls count
//    func updateMissed() {
//        guard let accessToken = session?.credentials.accessToken else { return }
//        guard !isUpdatingMissed else { return }
//        isUpdatingMissed = true
//        NewApiManager.shared.getMissedCalls(accessToken: accessToken)
//            .sink(receiveValue: { [weak self] count in
//                self?.isUpdatingMissed = false
//                self?.missedCallsCount = count
//            })
//            .store(in: &cancellable)
//    }
//
//}
//
//
//extension AuthViewModel {
//
//    func getDevicesList(completion: @escaping (_ response:  MXResponse<[MXDevice]>) -> Void) {
//        self.client?.devices(completion: { response in
//            completion(response)
//        })
//    }
//
//    //setDeviceName
//    func setDeviceName(_ deviceName: String, forDevice deviceId: String, completion: @escaping (MXResponse<Void>) -> Void) {
//        self.client?.setDeviceName(deviceName, forDevice: deviceId, completion: { response in
//            completion(response)
//        })
//    }
//
//    func getSession(toDeleteDevice deviceId: String, completion: @escaping (_ response: MXAuthenticationSession) -> Void) {
//        self.client?.getSession(toDeleteDevice: deviceId, completion: { response in
//            switch response {
//            case .success(let authSession):
//                completion(authSession)
//            case .failure(let error):
//                print(error)
//            }
//        })
//    }
//
//    func deleteDevice(deviceID: String, pass: String, completion: @escaping (MXResponse<Void>) -> Void) {
//        getSession(toDeleteDevice: deviceID) { response in
//            let parameters: [String: Any] = [
//                "type": kMXLoginFlowTypePassword,
//                "user": self.session?.myUserId ?? "",
//                "password": pass,
//                "session": response.session ?? ""
//            ]
//            self.client?.deleteDevice(deviceID, authParameters: parameters, completion: { response in
//                completion(response)
//            })
//        }
//    }
//}
