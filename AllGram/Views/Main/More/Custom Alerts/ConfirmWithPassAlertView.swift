//
//  ConfirmWithPassAlertView.swift
//  AllGram
//
//  Created by Eugene Ned on 25.07.2022.
//

import SwiftUI

extension ConfirmWithPassAlertView: DismissibleAlert {
    var alertShown: Binding<Bool> { shown }
}

struct ConfirmWithPassAlertView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var backColor: Color {
        switch colorScheme {
        case .dark: return .black
        default: return .white
        }
    }
    
    @State private var isSecure = true
    @State private var currentPassword = ""
    
    @State private var isFilled = false
    
    private func updateState() {
        withAnimation(.easeInOut) {
            isFilled = !currentPassword.isEmpty
        }
    }
    
    private var helpText: String? {
        if !isFilled { return "Please, enter your password" }
        return nil
    }
    
    let password: Binding<String>
    let success: Binding<Bool>
    let shown: Binding<Bool>
    
    var body: some View {
        VStack {
            ZStack {
                Text("Confirm action").font(.headline).bold()
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
                AdaptiveSecureTextField($isSecure, placeholder: "Your password", textInput: $currentPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: currentPassword, perform: { value in updateState() })
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
                    password.wrappedValue = currentPassword
                    success.wrappedValue = true
                    withAnimation { shown.wrappedValue = false }
                }, label: {
                    Text("Confirm")
                })
                .disabled(!isFilled)
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
