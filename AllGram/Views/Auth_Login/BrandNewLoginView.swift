//
//  BrandNewLoginView.swift
//  AllGram
//
//  Created by Eugene Ned on 26.08.2022.
//

import SwiftUI
import SocketIO

struct BrandNewLoginView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @FocusState private var focusedField: OurTextFieldFocus?
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack {
                        Spacer()
                        headerWithHelpText
                        usernameTextField
                        passwordTextField
                        loginButton
                        forgotPasswordButton
                        ORDivider()
                        digitalIDButton
                        googleSignInButton.opacity(0).disabled(true)
                        appleSignInButton.opacity(0).disabled(true)
                    }
                    .zIndex(0)
                    .padding(.horizontal, Constants.fieldsPadding)
                    .onSubmit {
                        switch focusedField {
                        case .username:
                            focusedField = .password
                        default:
                            if formFilledCorrectly {
                                AuthViewModel.shared.loginUser(username: username, password: password)
                            }
                        }
                    }
                    .animation(.easeIn(duration: 0.1))
                }
                .overlay(createAccountButton, alignment: .bottom)
                .ignoresSafeArea()
                .onTapGesture {
                    self.hideKeyboard()
                }
                if showQR { qrView.zIndex(1) }
            }
            .background(Color.white)
            .edgesIgnoringSafeArea(.vertical)
            .navigationBarHidden(true)
            .onAppear {
                // User username and password for previous login attempt
                username = authViewModel.lastAuthUsername ?? ""
                password = authViewModel.lastAuthPassword ?? ""
                // Clear temporal storage
                authViewModel.lastAuthUsername = nil
                authViewModel.lastAuthPassword = nil
            }
        }
        .alert(item: $authViewModel.errorAlert) { errorForAlert in
            Alert(
                title: Text(errorForAlert.title),
                message: Text(errorForAlert.message),
                dismissButton: .cancel(Text("OK")) {
                    authViewModel.errorAlert = nil
                }
            )
        }
    }
    
    private var formFilledCorrectly: Bool {
        username.hasContent && password.hasContent
    }
    
    private var logoSize: CGFloat {
        UIScreen.main.bounds.width / 3.5
    }
    
    private var logoView: some View {
        ZStack {
            Circle()
                .frame(width: logoSize * 2.5, height: logoSize * 2.5)
                .foregroundColor(Color("circlesColor"))
                .opacity(0.1)
            Circle()
                .frame(width: logoSize * 1.5, height: logoSize * 1.5)
                .foregroundColor(Color("circlesColor"))
                .opacity(0.15)
            Image("logo")
                .resizable().scaledToFit()
                .frame(width: 100, height: 100)
                .padding()
        }
    }
    
    private var headerWithHelpText: some View {
        ZStack {
            withAnimation {
                HStack {
                    Spacer()
                    VStack{
                        logoView
                        Spacer()
                    }
                    Spacer()
                }
            }
            .overlay(
                Text("Welcome to allgram")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .padding(.bottom, 48)
                , alignment: .bottom)
        }
    }
    
    // MARK: - Username
    
    @State private var username = ""
    
    let usernameConfig = OurTextFieldConfiguration.loginUsername
    
    private var usernameTextField: some View {
        OurTextField(rowInput: $username, isValid: true, focus: $focusedField, config: usernameConfig) {
            EmptyView()
        }
        .padding(.bottom, Constants.fieldsPadding)
    }
    
    // MARK: - Password
    
    @State private var password = ""
    @State private var isSecure = true
    
    let passwordConfig = OurTextFieldConfiguration.loginPassword
    
    private var passwordTextField: some View {
        OurTextField(secureInput: $password, isSecure: $isSecure, isValid: true, focus: $focusedField, config: passwordConfig) {
            EmptyView()
        }
        .padding(.bottom, Constants.fieldsPadding)
    }
    
    // MARK: - Buttons
    
    private var loginButton: some View {
        Button {
            AuthViewModel.shared.loginUser(username: username, password: password)
        } label: {
            HStack {
                Spacer()
                Text("Log In")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sameHeight)
        .background(Color.allgramMain.opacity(formFilledCorrectly ? 1 : 0.15))
        .cornerRadius(Constants.cornerRadius)
        .padding(.bottom,Constants.signInButtonsPadding)
        .disabled(!formFilledCorrectly)
    }
    
    private var forgotPasswordButton: some View {
        Button {
            //
        } label: {
            NavigationLink(destination: BrandNewForgotPassView()) {
                Text("Forgot password?")
                    .foregroundColor(Color.allgramMain)
                    .fontWeight(.bold)
            }
            .isDetailLink(false)
        }
    }
    
    private var digitalIDButton: some View {
        Button {
            withAnimation {
                hideKeyboard()
                showQR = true
            }
        } label: {
            HStack {
                Spacer()
                Image("qrcode-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.black)
                Text("Use your Digital ID")
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sameHeight)
        .background(Color.white)
        .cornerRadius(Constants.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .strokeBorder(Color.allgramMain.opacity(0.15), lineWidth: 2)
        )
        .padding(.bottom,Constants.signInButtonsPadding)
    }
    
    private var googleSignInButton: some View {
        Button {
            withAnimation {
                hideKeyboard()
                UIApplication.shared.open(AuthViewModel.shared.googleRedirect, options: [:])
            }
        } label: {
            HStack() {
                Spacer()
                Image("googleLogo")
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)
                Text("Sign in Google")
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sameHeight)
        .background(Color.white)
        .cornerRadius(Constants.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .strokeBorder(Color.allgramMain.opacity(0.15), lineWidth: 2)
        )
        .padding(.bottom,Constants.signInButtonsPadding)
    }
    
    private var appleSignInButton: some View {
        Button {
            // TODO: Handle apple auth
        } label: {
            HStack {
                Spacer()
                Image(systemName: "applelogo")
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                Text("Sign in Apple")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sameHeight)
        .background(Color.black)
        .cornerRadius(Constants.cornerRadius)
        .padding(.bottom,Constants.signInButtonsPadding)
    }
    
    private var createAccountButton: some View {
        VStack {
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.gray)
                    .foregroundColor(.black.opacity(0.7))
                Button {
                    //
                } label: {
                    NavigationLink(destination: BrandNewRegisterView()) {
                        Text("Create account")
                            .fontWeight(.bold)
                            .foregroundColor(Color.allgramMain)
                    }
                    .isDetailLink(false)
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 60)
        .background(Color("authButtonPanel"))
        .overlay(Divider(), alignment: .top)
    }
    
    // MARK: - Digital ID
    
    @State private var showQR = false
    
    @StateObject var idHandler = BrandNewDigitalIDHandler()
    
    let qrPadding: CGFloat = UIScreen.main.bounds.width / 13
    let qrContainerPadding: CGFloat = UIScreen.main.bounds.width / 7
    
    private var qrView: some View {
        
        ZStack {
            Rectangle()
                .foregroundColor(.black.opacity(0.8)) // To be able to catch taps, must not be fully transparent
                .onTapGesture {
                    withAnimation { showQR = false }
                }

                VStack(spacing: 0) {

                    Group {
                        Text("User your Digital ID")
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.top, 32)
                        Text("Scan this QR code with a device where you are already authorized")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, qrPadding)
                    if let token = idHandler.token {
                        Image(uiImage: generateQRImage(with: token))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image("logo")
                                    .resizable().scaledToFit()
                                    .frame(width: qrPadding, height: qrPadding)
                            )
                            .padding([.horizontal, .bottom], qrPadding)
                            .padding(.top, qrPadding/2)

                    } else {
                        Rectangle()
                            .strokeBorder(Color.black)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                ProgressView().scaleEffect(2)
                                    .foregroundColor(.allgramMain)
                            )
                            .padding([.horizontal, .bottom], qrPadding)
                            .padding(.top, qrPadding/2)
                    }
                    Button {
                        withAnimation { showQR = false }
                    } label: {
                        Text("Close")
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.bottom)
                    }
                }
                .background(Color(hex: "CCCCCC"))
                .cornerRadius(14)
                .onAppear {
                    handleQR()
                }
                .padding(.horizontal, qrContainerPadding)
                .opacity(showQR ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .all)
    }
    
    private func handleQR() {
        idHandler.onAuthData = { userId, secret in
            AuthViewModel.shared.loginUser(userId: userId, secret: secret)
            withAnimation { showQR = false }
        }
        if idHandler.token != nil {
            idHandler.sendRenew()
        } else {
            idHandler.sendConnect()
        }
    }
    
    // MARK: - Generating QR Image
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    private func generateQRImage(with content: String) -> UIImage {
        let data = Data(content.utf8)
        filter.setValue(data, forKey: "inputMessage")
        if let qrCodeImage = filter.outputImage {
            if let qrCodeCGImage = context.createCGImage(qrCodeImage, from: qrCodeImage.extent){
                return UIImage(cgImage: qrCodeCGImage)
            }
        }
        return UIImage(solidColor: .black, size: CGSize(width: 200, height: 200))
    }
    
    // MARK: -
    
    struct Constants {
        static let cornerRadius: CGFloat = 8
        static var sameHeight: CGFloat { OurTextFieldConstants.inputHeight }
        static let fieldsPadding: CGFloat = 30
        static let signInButtonsPadding: CGFloat = 4
    }
}

struct BrandNewLoginView_Previews: PreviewProvider {
    static var previews: some View {
        BrandNewLoginView()
    }
}

class BrandNewDigitalIDHandler: ObservableObject {
    private static let devSocket = "http://s0.allgram.me:9050"
    private static let prodSocket = "http://s.allgram.me:9050"
    private static var socketURL: URL {
        URL(string: API.inDebug ? devSocket : prodSocket)!
    }
    
    // Do not expose manager/socket
    private let manager: SocketManager
    private let socket: SocketIOClient
    
    /// Provide access token for logged in user, otherwise provide `nil`
    init(accessToken: String? = nil) {
        // We need authorization header for logged in user
        // and confirming token from devices to login
        let headers: [String: String] = accessToken != nil ? ["Authorization": accessToken!] : [:]
        self.manager = SocketManager.init(
            socketURL: BrandNewDigitalIDHandler.socketURL,
            config: [.log(true), .compress, .extraHeaders(headers)]
        )
        self.socket = manager.defaultSocket
        addHandlers()
        socket.connect()
    }
    
    private func addHandlers() {
        // Log all events...
        socket.onAny { anyEvent in
        }
        // Do not mistaken with 'connect', this one has token (not sid)
        // We need to call 'sendConnect()' in order to get this
        socket.on("connected") { [weak self] data, ack in
            self?.token = (data as? [[String: Any]])?.first?["token"] as? String
        }
        // Provides renewed token when 'sendRenew()' is called
        socket.on("renewed") { [weak self] data, ack in
            self?.token = (data as? [[String: Any]])?.first?["token"] as? String
        }
        // Invalid token when confirming one
        socket.on("invalid_token") { [weak self] data, ack in
            self?.onInvalidToken?()
        }
        // Token confirmed successfully
        socket.on("scanned_successfully") { [weak self] data, ack in
            self?.onTokenConfirmed?()
        }
        // Token confirmed, get login data
        socket.on("auth") { [weak self] data, ack in
            if let dictionary = (data as? [[String: Any]])?.first,
               let userId = dictionary["user_id"] as? String,
               let secret = dictionary["secret"] as? String
            {
                self?.onAuthData?(userId, secret)
            }
        }
    }
    
    // MARK: - Get token for Digital ID (device to login)
    
    @Published private(set) var token: String?
    
    /// Called when `token` is confirmed by logged device.
    /// Provides `userId` and `secret` for login
    var onAuthData: ((String, String) -> Void)?
    
    /// Asks for token that will be used in QR for digital ID login
    func sendConnect(completion: (() -> Void)? = nil) {
        socket.emit("connect", [:]) {
            completion?()
        }
    }
    
    /// Asks to renew the token that is used in QR for digital ID login
    func sendRenew(completion: (() -> Void)? = nil) {
        socket.emit("renew", [:]) {
            completion?()
        }
    }
    
    // MARK: - Validate token of Digital ID (logged device)
    
    /// Called when confirming token failed (incorrect or timeout)
    var onInvalidToken: (() -> Void)?
    
    /// Called when confirming token successful
    var onTokenConfirmed: (() -> Void)?
    
    /// Asks to confirm token
    func sendConfirm(token: String, completion: (() -> Void)? = nil) {
        socket.emit("confirm_token", ["token":token]) {
            completion?()
        }
    }
}




