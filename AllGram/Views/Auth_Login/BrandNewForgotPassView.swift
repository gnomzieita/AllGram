//
//  BrandNewForgotPassView.swift
//  AllGram
//
//  Created by Eugene Ned on 26.08.2022.
//

import SwiftUI

struct BrandNewForgotPassView: View {
    
    enum LocalState {
        case forgot, reset
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var state: LocalState = .forgot
    @State private var errorAlert: ErrorAlert?
    @State private var forgotPassData: AuthViewModel.ForgotPasswordData?
    
    private var formFilledCorrectly: Bool {
        passwordManager.isValid && emailManager.isValid
    }
    
    @FocusState private var focusedField: OurTextFieldFocus?
    
    var body: some View {
        ScrollView {
            VStack {
                VStack(alignment: .leading) {
                    switch state {
                    case .forgot:
                        VStack {
                            infoTextView
                            emailTextField
                        }
                        .alert(item: $errorAlert) { alert in
                            Alert(title: Text(alert.title),
                                  message: Text(alert.message),
                                  dismissButton: .cancel(Text("Okay")))
                        }
                        VStack {
                            passwordTextField
                            passwordRequirements
                            resetPasswordButton
                        }
                        .alert(isPresented: $showWarningAlert) {
                            warningAlert
                        }
                    case .reset:
                        BrandNewResetPassword(data: forgotPassData!)
                    }
                }
                .padding(Constants.horisontalPadding)
                .navigationTitle("Forgot password")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 10)
                .onSubmit {
                    switch focusedField {
                    case .email:
                        focusedField = .password
                    default:
                        if formFilledCorrectly {
                            showWarningAlert = true
                        }
                    }
                }
                .animation(.easeIn(duration: 0.1))
            }
            .padding(Constants.horisontalPadding)
            .padding(.bottom, 80)
        }
        .overlay(
            VStack {
                if state == .forgot {
                    backToLoginButton
                } else {
                    EmptyView()
                }
            }
            , alignment: .bottom)
        .background(Color("authBackground"))
        .edgesIgnoringSafeArea(.bottom)
        .onTapGesture {
            self.hideKeyboard()
        }
    }
    
    @State private var showWarningAlert = false
    
    private var warningAlert: Alert {
        Alert(
            title: Text("Warning!"),
            message: Text("Changing your password will reset any end-to-end encryption keys on all of your sessions, making encrypted chat history unreadable. Set up Key Backup or export your room keys from another session before resetting your password."),
            primaryButton: .default(
                Text("Continue"),
                action: {
                    AuthViewModel.shared.forgotUserPassword(
                        email: emailManager.input,
                        newPassword: passwordManager.input
                    ) { result in
                        switch result {
                        case .success(let data):
                            forgotPassData = data
                            state = .reset
                        case .failure(let error):
                            errorAlert = error
                        }
                    }
                }),
            secondaryButton: .cancel()
        )
    }
    
    private var infoTextView: some View {
        Text("A verification email will be sent to your inbox to confirm setting your new password.")
            .font(.headline)
            .foregroundColor(.black)
            .padding(.bottom, Constants.infoBottomPadding)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
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
//        VStack(spacing: 4) {
//            HStack {
//                Image("envelope-solid")
//                    .resizable()
//                    .renderingMode(.template)
//                    .foregroundColor(.black)
//                    .frame(width: Constants.iconSize, height: Constants.iconSize)
//                    .padding([.vertical, .leading], Constants.iconPadding)
//
//                TextField("", text: $email)
//                    .autocapitalization(.none)
//                    .disableAutocorrection(true)
//                    .foregroundColor(.black)
//                    .accentColor(.black)
//                    .textFieldStyle(PlainTextFieldStyle())
//                    .frame(height: Constants.sameHeight)
//                    .keyboardType(.emailAddress)
//                    .submitLabel(.next)
//                    .focused($focusedField, equals: .email)
//                    .onTapGesture {
//                        focusedField = .email
//                    }
//            }
//            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius)
//                .foregroundColor(.white))
//            .overlay(
//                RoundedRectangle(cornerRadius: Constants.cornerRadius)
//                    .strokeBorder(inputManager.isEmailValid ? Color.allgramMain.opacity(!email.hasContent ? 0.1 : 1) : Color.red, lineWidth: 1)
//            )
//            .overlay(
//                HStack {
//                    Text("Email address*")
//                        .padding([.leading, .trailing], 4)
//                        .background(emailPlaceholderBackground)
//                        .scaleEffect(emailPlaceholderScale)
//                        .foregroundColor(emailPlaceholderForeground)
//                        .offset(y: emailPlaceholderOffset)
//                        .padding(.leading, emailPlaceholderPadding)
//                        .transition(.slide.combined(with: .scale))
//                    Spacer()
//                }
//                    .onTapGesture {
//                        focusedField = .email
//                    }
//                    .animation(.easeIn(duration: 0.1), value: email)
//            )
//
//            HStack {
//                withAnimation {
//                    Text(inputManager.emailHelpText)
//                        .foregroundColor(.red)
//                        .font(.footnote)
//                }
//                Spacer()
//            }
//            .animation(.easeInOut, value: inputManager.emailHelpText)
//        }
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
//        VStack(spacing: 4) {
//            HStack {
//                Image("key-solid")
//                    .resizable()
//                    .renderingMode(.template)
//                    .foregroundColor(.black)
//                    .frame(width: Constants.iconSize, height: Constants.iconSize)
//                    .padding([.vertical, .leading], Constants.iconPadding)
//
//                AdaptiveSecureTextField($securePass, placeholder: "", textInput: $inputManager.password)
//                    .autocapitalization(.none)
//                    .disableAutocorrection(true)
//                    .foregroundColor(.black)
//                    .accentColor(.black)
//                    .textFieldStyle(PlainTextFieldStyle())
//                    .frame(height: Constants.sameHeight)
//                    .keyboardType(.asciiCapable)
//                    .submitLabel(.continue)
//                    .focused($focusedField, equals: .password)
//                    .onTapGesture {
//                        focusedField = .password
//                    }
//
//
//                Button(action: { withAnimation { securePass.toggle() } }, label: {
//                    Image(systemName: securePass ? "eye.fill" : "eye.slash.fill")
//                        .resizable()
//                        .foregroundColor(.black)
//                        .scaledToFit()
//                        .frame(width: Constants.iconSize, height: Constants.iconSize)
//                        .padding([.vertical, .trailing], Constants.iconPadding)
//                })
//            }
//            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius)
//                .foregroundColor(.white))
//            .overlay(
//                RoundedRectangle(cornerRadius: Constants.cornerRadius)
//                    .strokeBorder(!inputManager.isPasswordValid && inputManager.password.hasContent ? Color.red : Color.allgramMain.opacity(!inputManager.password.hasContent ? 0.1 : 1), lineWidth: 1)
//            )
//            .overlay(
//                HStack {
//                    Text("Password*")
//                        .padding([.leading, .trailing], 4)
//                        .background(passwordPlaceholderBackground)
//                        .scaleEffect(passwordPlaceholderScale)
//                        .foregroundColor(passwordPlaceholderForeground)
//                        .offset(y: passwordPlaceholderOffset)
//                        .padding(.leading, passwordPlaceholderPadding)
//                        .transition(.slide.combined(with: .scale))
//                    Spacer()
//                }
//                    .onTapGesture {
//                        focusedField = .password
//                    }
//                    .animation(.easeIn(duration: 0.1), value: inputManager.password)
//            )
//
//            //            .padding(.bottom, Constants.fieldsPadding)
//            HStack {
//                Text(inputManager.passwordHelpText)
//                    .foregroundColor(.red)
//                    .font(.footnote)
//                Spacer()
//            }
//            .animation(.easeInOut, value: inputManager.passwordHelpText)
//        }
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
    
    // MARK: - Buttons
    
    private var resetPasswordButton: some View {
        Button(action: {
            self.hideKeyboard()
            showWarningAlert = true
        }) {
            HStack {
                Spacer()
                Text("Reset Password")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sameHeight)
        .background(Color.allgramMain.opacity(formFilledCorrectly ? 1 : 0.15))
        .cornerRadius(Constants.cornerRadius)
        .disabled(!formFilledCorrectly)
    }
    
    private var backToLoginButton: some View {
        VStack {
            HStack {
                Text("Made a mistake?")
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
        .background(Color("authButtonPanel"))
        .overlay(
            Divider()
            , alignment: .top
        )
    }
    
    // MARK: -
    
    struct Constants {
        static let infoBottomPadding: CGFloat = 24
        static let infoHorizontalPadding: CGFloat = 4
        static let iconSize: CGFloat = 24
        static let iconPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 8
        static let sameHeight: CGFloat = 56
        static let fieldsPadding: CGFloat = 30
        static let horisontalPadding: CGFloat = 16
    }
}

struct BrandNewаForgotPassView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BrandNewForgotPassView()
                .colorScheme(.dark)
                .background(Color.white)
            BrandNewForgotPassView()
                .colorScheme(.light)
                .background(Color.white)
        }
    }
}

