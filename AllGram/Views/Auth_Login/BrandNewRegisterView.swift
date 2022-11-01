//
//  BrandNewRegisterView.swift
//  AllGram
//
//  Created by Eugene Ned on 26.08.2022.
//

import SwiftUI
import Combine

struct BrandNewRegisterView: View {
    @Environment(\.presentationMode) var presentationMode
    
    private var formFilledCorrectly: Bool {
        // If we have a valid invite key -> username if good if it has any content
        // otherwise (no invite key) -> we expect username validation
        let isUsernameValid = (inviteKeyManager.input.hasContent ? inviteKeyManager.isValid : false) ? usernameManager.input.hasContent : (usernameManager.input.hasContent ? usernameManager.isValid : false)
        // Username, password and email are required
        let required = isUsernameValid && (passwordManager.input.hasContent ? passwordManager.isValid : false) && (emailManager.input.hasContent ? emailManager.isValid : false)
        // Phone number and invite key are optional
        let optional = (phoneManager.input.hasContent ? phoneManager.isValid : true) && (inviteKeyManager.input.hasContent ? inviteKeyManager.isValid : true)
        // Also need to agree to info
        return required && optional && agreed
    }
    
    private let urlPrivacy = "https://allgram.com/info-pp"
    private let urlTerms = "https://allgram.com/info-terms"
    private let urlEULA = "https://allgram.com/info-eula"
    
    @FocusState private var focusedField: OurTextFieldFocus?
    
    var body: some View {
        ScrollView {
            VStack {
                VStack {
                    usernameTextField
                    if invitationKeyShown {
                        inviteKeyTextField
                    }
                    passwordTextField
                    passwordRequirements
                    emailTextField
                    phoneTextField
                    agreeField
                    createAccountButton
                }
                .padding(Constants.horisontalPadding)
                .navigationTitle("Create account")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 10)
                .onSubmit {
                    switch focusedField {
                    case .username:
                        focusedField = invitationKeyShown ? .inviteKey : .password
                    case .inviteKey:
                        focusedField = .password
                    case .password:
                        focusedField = .email
                    case .email:
                        focusedField = .phone
                    case .phone:
                        if formFilledCorrectly {
                            AuthViewModel.shared.registerUser(
                                username: usernameManager.input,
                                password: passwordManager.input,
                                email: emailManager.input,
                                phone: emailManager.input.optionalContent,
                                inviteCode: inviteKeyManager.input.optionalContent
                            )
                        }
                    default:
                        break
                    }
                }
                .animation(.easeIn(duration: 0.1))
            }
            //            .adaptsToKeyboard()
            .padding([.horizontal, .top],Constants.horisontalPadding)
            //            .padding(.bottom, 350)
        }
        .keyboardAware
        //        .modifier(AdaptsToSoftwareKeyboard())
        .overlay(
            logInButton
            , alignment: .bottom
        )
        .edgesIgnoringSafeArea(.bottom)
        .background(Color("authBackground"))
        .onTapGesture {
            self.hideKeyboard()
        }
    }
    
    // MARK: - Username
    
    @StateObject private var usernameManager = InputManager(validations: Validation.username)
    
    let usernameConfig = OurTextFieldConfiguration.registerUsername
    
    private var usernameTextField: some View {
        // If we have some content in username and some invite key - its valid
        // or when the username field filled correctly
        OurTextField(rowInput: $usernameManager.input, isValid: (usernameManager.input.hasContent && inviteKeyManager.input.hasContent) || usernameManager.isValid, focus: $focusedField, config: usernameConfig) {
            if !usernameManager.isValid {
                if usernameManager.input.hasContent {
                    if inviteKeyManager.input.hasContent {
                        EmptyView()
                    } else {
                        HStack(spacing: 0) {
                            formattedUsernameHelpText
                                .font(.footnote)
                                .onTapGesture {
                                    withAnimation { invitationKeyShown.toggle() }
                                }
                            Spacer()
                        }
                        .animation(.easeInOut, value: usernameManager.isValid)
                    }
                } else {
                    HStack(spacing: 0) {
                        Text("Username field can't be empty")
                            .foregroundColor(.red)
                            .font(.footnote)
                        Spacer()
                    }
                    .animation(.easeInOut, value: passwordManager.isValid)
                }
            } else {
                EmptyView()
            }
        }
        .padding(.bottom, Constants.horisontalPadding)
    }
    
    private var formattedUsernameHelpText: Text {
        return Text("The username is required to be at least 3 characters or ").foregroundColor(.red)
        + Text("use your invitation key").foregroundColor(Color.allgramMain).underline()
        + Text(" to avoid restriction").foregroundColor(.red)
    }
    
    // MARK: - Invitation Key
    
    @StateObject private var inviteKeyManager = InputManager(validations: Validation.invitationKey, requiredContent: false)
    
    @State private var invitationKeyShown = false
    
    let inviteKeyConfig = OurTextFieldConfiguration.registerInviteKey
    
    private var inviteKeyTextField: some View {
        OurTextField(rowInput: $inviteKeyManager.input, isValid: inviteKeyManager.isValid, focus: $focusedField, config: inviteKeyConfig) {
            EmptyView()
        }
        .padding(.bottom, Constants.horisontalPadding)
    }
    
    // MARK: - Password
    
    @StateObject private var passwordManager = InputManager(validations: Validation.password)
    
    @State private var isSecure = true
    
    let passwordConfig = OurTextFieldConfiguration.registerPassword
    
    private var passwordTextField: some View {
        OurTextField(secureInput: $passwordManager.input, isSecure: $isSecure, isValid: passwordManager.isValid, focus: $focusedField, config: passwordConfig) {
            if !passwordManager.isValid {
                HStack(spacing: 0) {
                    Text(passwordManager.input.hasContent ? "Password doesn't meet the password requirements" : "Password field can't be empty")
                        .foregroundColor(.red)
                        .font(.footnote)
                    Spacer()
                }
                .animation(.easeInOut, value: passwordManager.isValid)
            } else {
                EmptyView()
            }
        }
    }
    
    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Password requirements:")
                .font(.headline)
                .fontWeight(.bold)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
            ForEach(passwordManager.validations, id: \.requirementDescription) { validation in
                HStack {
                    let passed = validation.validate(passwordManager.input)
                    Image("check-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                        .foregroundColor(passed ? Color.green : Color.clear)
                    Text(validation.requirementDescription ?? "Other requirement")
                        .font(.subheadline)
                        .foregroundColor(passed ? .green : .black)
                }
            }
            
        }
        .foregroundColor(.black)
    }
    
    // MARK: - Email
    
    @StateObject private var emailManager = InputManager(validations: Validation.email)
        
    let emailConfig = OurTextFieldConfiguration.registerEmail
    
    private var emailTextField: some View {
        OurTextField(rowInput: $emailManager.input, isValid: emailManager.isValid, focus: $focusedField, config: emailConfig) {
            if !emailManager.isValid {
                HStack(spacing: 0) {
                    Text(emailManager.input.hasContent ? "Invalid email address" : "Email field can't be empty")
                        .foregroundColor(.red)
                        .font(.footnote)
                    Spacer()
                }
                .animation(.easeInOut, value: emailManager.isValid)
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Phone
    
    @StateObject private var phoneManager = InputManager(validations: Validation.phone, requiredContent: false)
        
    let phoneConfig = OurTextFieldConfiguration.registerPhone
    
    private var phoneTextField: some View {
        OurTextField(rowInput: $phoneManager.input, isValid: phoneManager.isValid, focus: $focusedField, config: phoneConfig) {
            HStack(spacing: 0) {
                Text("Please, enter your phone number with the country code")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
    }
    
    // MARK: - Agree Switch
    
    @State private var agreed = false
    
    private var agreeField: some View {
        Toggle(isOn: $agreed, label: {
            VStack(alignment: .leading) {
                // I agree to the Privacy Policy, Terms and Conditions and EULA
                HStack(spacing: 0) {
                    Text("I agree to the ").foregroundColor(.black).lineLimit(1)
                    Link(destination: URL(string: urlPrivacy)!, label: {
                        Text("Privacy Policy").foregroundColor(Color.allgramMain).underline()
                    })
                    Text(",").foregroundColor(.white).lineLimit(1)
                }
                HStack(spacing: 0) {
                    Link(destination: URL(string: urlTerms)!, label: {
                        Text("Terms and Conditions").foregroundColor(Color.allgramMain).underline()
                    })
                    Text(" and ").foregroundColor(.black).lineLimit(1)
                    Link(destination: URL(string: urlEULA)!, label: {
                        Text("EULA").foregroundColor(Color.allgramMain).underline()
                    })
                }
            }
            .font(.subheadline)
        })
        .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
        .padding(.bottom, Constants.togglePadding)
    }
    
    // MARK: - Buttons
    
    private var createAccountButton: some View {
        Button(action: {
            AuthViewModel.shared.registerUser(
                username: usernameManager.input,
                password: passwordManager.input,
                email: emailManager.input,
                phone: phoneManager.input.optionalContent,
                inviteCode: inviteKeyManager.input.optionalContent
            )
        }) {
            HStack {
                Spacer()
                Text("Create account")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sameHeight)
        .background(Color.allgramMain.opacity(formFilledCorrectly ? 1 : 0.15))
        .cornerRadius(Constants.cornerRadius)
        .padding(.bottom, 4)
        .disabled(!formFilledCorrectly)
    }
    
    private var logInButton: some View {
        VStack {
            HStack {
                Text("Already have an account?")
                    .foregroundColor(.gray)
                    .foregroundColor(.black.opacity(0.7))
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Log In")
                        .fontWeight(.bold)
                        .foregroundColor(Color.allgramMain)
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 60)
        .background(Color.white)
        .overlay(
            Divider()
            , alignment: .top
        )
    }
    
    // MARK: -
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let iconPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 8
        static let sameHeight: CGFloat = 56
        static let fieldsPadding: CGFloat = 30
        static let horisontalPadding: CGFloat = 16
        static let togglePadding: CGFloat = 16
    }
}

struct BrandNewRegisterView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BrandNewRegisterView()
                .previewDevice("iPhone 13")
                .colorScheme(.dark)
                .background(Color.white)
            BrandNewRegisterView()
                .colorScheme(.light)
                .background(Color.white)
        }
    }
}


// MARK: - Modifications that are needed to push a text field up as much as needed in order to not to overlap it with the keyboard

extension Publishers {
    // 1.
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        // 2.
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }
        
        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        
        // 3.
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

extension Notification {
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var bottomPadding: CGFloat = 0
    
    func body(content: Content) -> some View {
        // 1.
        GeometryReader { geometry in
            content
                .offset(y: bottomPadding)
                .onReceive(Publishers.keyboardHeight) { keyboardHeight in
                    let keyboardTop = geometry.frame(in: .global).height - keyboardHeight
                    let focusedTextInputBottom = UIResponder.currentFirstResponder?.globalFrame?.maxY ?? 0
                    print("FOCUSED EBAT\(focusedTextInputBottom)")
                    self.bottomPadding = max(0, focusedTextInputBottom - keyboardTop - geometry.safeAreaInsets.bottom)
                    print("some text \(focusedTextInputBottom - keyboardTop - geometry.safeAreaInsets.bottom)")
                }
                .animation(.easeOut(duration: 0.16))
        }
    }
}

//struct KeyboardAdaptive: ViewModifier {
//    @State private var keyboardHeight: CGFloat = 0
//
//    func body(content: Content) -> some View {
//        content
//            .padding(.bottom, keyboardHeight)
//            .onReceive(Publishers.keyboardHeight) { self.keyboardHeight = $0 }
//    }
//}

extension View {
    func keyboardAdaptive() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAdaptive())
    }
    
    func modify<T: View>(@ViewBuilder _ modifier: (Self) -> T) -> some View {
        return modifier(self)
    }
}

extension UIResponder {
    static var currentFirstResponder: UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }
    
    private static weak var _currentFirstResponder: UIResponder?
    
    @objc private func findFirstResponder(_ sender: Any) {
        UIResponder._currentFirstResponder = self
    }
    
    var globalFrame: CGRect? {
        guard let view = self as? UIView else { return nil }
        return view.superview?.convert(view.frame, to: nil)
    }
}
