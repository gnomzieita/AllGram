//
//  ChangePasswordAlertView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 21.12.2021.
//

import SwiftUI

extension ChangePasswordAlertView: DismissibleAlert {
    var alertShown: Binding<Bool> { shown }
}

struct AdaptiveSecureTextField: View {
    
    let secure: Binding<Bool>
    let placeholder: String
    let textInput: Binding<String>
    
    init(_ secure: Binding<Bool>, placeholder: String, textInput: Binding<String>) {
        self.secure = secure
        self.placeholder = placeholder
        self.textInput = textInput
    }
    
    var body: some View {
        if secure.wrappedValue {
            SecureField(placeholder, text: textInput)
        } else {
            TextField(placeholder, text: textInput)
        }
    }
    
}

struct ChangePasswordAlertView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var backColor: Color {
        switch colorScheme {
        case .dark: return .black
        default: return .white
        }
    }
    
    @State private var isSecure = true
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var isFilled = false
    @State private var isMatching = true
    @State private var isSame = true
    
    private func updateState() {
        withAnimation(.easeInOut) {
            isFilled = !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty
            isMatching = newPassword == confirmPassword
            isSame = isMatching && currentPassword == newPassword
        }
    }
    
    private var helpText: String? {
        if !isFilled { return "Please, fill all the fields" }
        if !isMatching { return "New passwords should be matching" }
        if isSame { return "New password should not match the old one" }
        return nil
    }
    
    let passwordInput: Binding<String>
    let passwordOutput: Binding<String>
    let success: Binding<Bool>
    let shown: Binding<Bool>
    
    var body: some View {
        VStack {
            ZStack {
                Text("Change Password").font(.headline).bold()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation { isSecure.toggle() }
                    }, label: {
                        Image(systemName: isSecure ? "eye.fill" : "eye.slash.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .foregroundColor(.accentColor)
                    })
                }
            }
            .padding(.horizontal)
            if let text = helpText {
                Text(text).font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            VStack(spacing: 16) {
                AdaptiveSecureTextField($isSecure, placeholder: "Current password", textInput: $currentPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: currentPassword, perform: { value in updateState() })
                AdaptiveSecureTextField($isSecure, placeholder: "New password", textInput: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: newPassword, perform: { value in updateState() })
                AdaptiveSecureTextField($isSecure, placeholder: "Confirm new password", textInput: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: confirmPassword, perform: { value in updateState() })
            }
            .padding()
            Divider()
            HStack {
                Spacer()
                Button(action: {
                    success.wrappedValue = false
                    withAnimation { shown.wrappedValue = false }
                }, label: {
                    Text("Cancel")
                })
                Spacer()
                Divider()
                Spacer()
                Button(action: {
                    passwordInput.wrappedValue = currentPassword
                    passwordOutput.wrappedValue = newPassword
                    success.wrappedValue = true
                    withAnimation { shown.wrappedValue = false }
                }, label: {
                    Text("Change")
                })
                .disabled(!(isFilled && isMatching && !isSame))
                Spacer()
            }
            .frame(height: Constants.alertButtonsHeight)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: Constants.alertCornerRadius)
                        .foregroundColor(backColor))
    }
    
    struct Constants {
        static let alertCornerRadius: CGFloat = 16
        static let alertButtonsHeight: CGFloat = 32
        static let iconSize: CGFloat = 24
    }
    
}

struct ChangePasswordAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomAlertContainerView {
                ChangePasswordAlertView(passwordInput: .constant(""), passwordOutput: .constant(""), success: .constant(false), shown: .constant(true))
            }
            .colorScheme(.dark)
            CustomAlertContainerView {
                ChangePasswordAlertView(passwordInput: .constant(""), passwordOutput: .constant(""), success: .constant(false), shown: .constant(true))
            }
            .colorScheme(.light)
        }
    }
}
