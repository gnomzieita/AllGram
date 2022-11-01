//
//  OurTextField.swift
//  AllGram
//
//  Created by Eugene Ned on 29.09.2022.
//

import SwiftUI

/// Provides expanding divider: `----- OR -----`
struct ORDivider: View {
    var body: some View {
        HStack {
            VStack { Divider() }
            Text("OR").foregroundColor(.gray)
            VStack { Divider() }
        }
    }
}

// MARK: - Custom TextField

enum OurTextFieldFocus {
    case username, password, email, phone, inviteKey, newMeetingName, newMeetingDescription
}

struct OurTextFieldConfiguration {
    let placeholder: String
    let fieldFocus: OurTextFieldFocus
    let leadingIconName: String?
    let addClearButton: Bool
    let autocapitalizationType: UITextAutocapitalizationType
    let disableAutocorrection: Bool
    let keyboardType: UIKeyboardType
    let filterInput: (String) -> String
    
    init(placeholder: String, fieldFocus: OurTextFieldFocus, leadingIconName: String?, addClearButton: Bool, autocapitalizationType: UITextAutocapitalizationType, disableAutocorrection: Bool, keyboardType: UIKeyboardType, filterInput: @escaping (String) -> String) {
        self.placeholder = placeholder
        self.fieldFocus = fieldFocus
        self.leadingIconName = leadingIconName
        self.addClearButton = addClearButton
        self.autocapitalizationType = autocapitalizationType
        self.disableAutocorrection = disableAutocorrection
        self.keyboardType = keyboardType
        self.filterInput = filterInput
    }
    
    // MARK: - Our Configurations
    
    static let loginUsername = OurTextFieldConfiguration(
        placeholder: "Username",
        fieldFocus: .username,
        leadingIconName: "user-circle-solid",
        addClearButton: true,
        autocapitalizationType: .none,
        disableAutocorrection: true,
        keyboardType: .asciiCapable,
        filterInput: { input in
            return input.replacingOccurrences(of: " ", with: "").lowercased()
        }
    )
    static let loginPassword = OurTextFieldConfiguration(
        placeholder: "Password",
        fieldFocus: .password,
        leadingIconName: "key-solid",
        addClearButton: false,
        autocapitalizationType: .none,
        disableAutocorrection: true,
        keyboardType: .asciiCapable,
        filterInput: { input in
            return input.replacingOccurrences(of: " ", with: "")
        }
    )
    static let registerUsername = OurTextFieldConfiguration(
        placeholder: "Username*",
        fieldFocus: .username,
        leadingIconName: "user-circle-solid",
        addClearButton: true,
        autocapitalizationType: .none,
        disableAutocorrection: true,
        keyboardType: .asciiCapable,
        filterInput: { input in
            return input.replacingOccurrences(of: " ", with: "").lowercased()
        }
    )
    static let registerInviteKey = OurTextFieldConfiguration(
        placeholder: "Invitation key (optional)",
        fieldFocus: .inviteKey,
        leadingIconName: nil,
        addClearButton: false,
        autocapitalizationType: .none,
        disableAutocorrection: true,
        keyboardType: .asciiCapable,
        filterInput: { input in
            return input.replacingOccurrences(of: " ", with: "")
        }
    )
    static let registerPassword = OurTextFieldConfiguration(
        placeholder: "Password*",
        fieldFocus: .password,
        leadingIconName: "key-solid",
        addClearButton: false,
        autocapitalizationType: .none,
        disableAutocorrection: true,
        keyboardType: .asciiCapable,
        filterInput: { input in
            return input.replacingOccurrences(of: " ", with: "")
        }
    )
    static let registerEmail = OurTextFieldConfiguration(
        placeholder: "Email*",
        fieldFocus: .email,
        leadingIconName: "envelope-solid",
        addClearButton: false,
        autocapitalizationType: .none,
        disableAutocorrection: true,
        keyboardType: .emailAddress,
        filterInput: { input in
            return input.replacingOccurrences(of: " ", with: "")
        }
    )
    static let registerPhone = OurTextFieldConfiguration(
        placeholder: "Phone number (optional)",
        fieldFocus: .phone,
        leadingIconName: "mobile-solid",
        addClearButton: false,
        autocapitalizationType: .none,
        disableAutocorrection: true,
        keyboardType: .numberPad,
        filterInput: { input in
            return input.replacingOccurrences(of: " ", with: "")
        }
    )
    static let createMeetingName = OurTextFieldConfiguration(
        placeholder: "Meeting name *",
        fieldFocus: .newMeetingName,
        leadingIconName: nil,
        addClearButton: true,
        autocapitalizationType: .sentences,
        disableAutocorrection: false,
        keyboardType: .default,
        filterInput: { input in
            return String(input.prefix(30))
        }
    )
    static let createMeetingDescription = OurTextFieldConfiguration(
        placeholder: "Description (optional)",
        fieldFocus: .newMeetingDescription,
        leadingIconName: nil,
        addClearButton: false,
        autocapitalizationType: .sentences,
        disableAutocorrection: false,
        keyboardType: .default,
        filterInput: { input in
            return input
        }
    )
}

struct OurTextFieldConstants {
    static let iconSize: CGFloat = 24
    static let iconPadding: CGFloat = 16
    static let inputPadding: CGFloat = 8
    static let inputHeight: CGFloat = 56
    static let cornerRadius: CGFloat = 8
    static let placeholderTextPadding: CGFloat = 4
    static let placeholderMovedUpPadding: CGFloat = 12
    
    static func placeholderLeadingPadding(movedUp: Bool, withIcon: Bool) -> CGFloat {
        if movedUp {
            return placeholderMovedUpPadding
        } else if withIcon {
            return iconSize + iconPadding + inputPadding - placeholderTextPadding
        } else {
            return inputPadding - placeholderTextPadding
        }
    }
}

struct OurTextField<V: View>: View {
    @Binding var input: String
    @Binding var isSecure: Bool
    
    let isValid: Bool
    
    var focus: FocusState<OurTextFieldFocus?>.Binding
    
    let config: OurTextFieldConfiguration
    
    let footerView: V
    
    // Internal
    private let isSecurable: Bool
    
    /// Init for secure input, like password
    init(secureInput: Binding<String>, isSecure: Binding<Bool>, isValid: Bool = true, focus: FocusState<OurTextFieldFocus?>.Binding, config: OurTextFieldConfiguration, @ViewBuilder footerBuilder: () -> V) {
        self._input = secureInput
        self._isSecure = isSecure
        self.isSecurable = true
        self.isValid = isValid
        self.focus = focus
        self.config = config
        self.footerView = footerBuilder()
    }
    
    /// Init for non-secure input, like login
    init(rowInput: Binding<String>, isValid: Bool = true, focus: FocusState<OurTextFieldFocus?>.Binding, config: OurTextFieldConfiguration, @ViewBuilder footerBuilder: () -> V) {
        self._input = rowInput
        self._isSecure = .constant(false)
        self.isSecurable = false
        self.isValid = isValid
        self.focus = focus
        self.config = config
        self.footerView = footerBuilder()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Input field with optional icons
            HStack(spacing: 0) {
                // Leading icon if needed
                if let icon = config.leadingIconName {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .foregroundColor(.black)
                        .frame(width: OurTextFieldConstants.iconSize)
                        .frame(height: OurTextFieldConstants.iconSize)
                        .padding([.vertical, .leading], OurTextFieldConstants.iconPadding)
                }
                // Actual text field (secure if needed)
                AdaptiveSecureTextField($isSecure, placeholder: "", textInput: $input)
                    .autocapitalization(config.autocapitalizationType)
                    .disableAutocorrection(config.disableAutocorrection)
                    .foregroundColor(.reverseColor)
                    .accentColor(.reverseColor)
//                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(height: OurTextFieldConstants.inputHeight)
                    .padding(.horizontal, OurTextFieldConstants.inputPadding)
                    .keyboardType(config.keyboardType)
                    .submitLabel(.next)
                    .focused(focus, equals: config.fieldFocus)
                    .onTapGesture {
                        focus.wrappedValue = config.fieldFocus
                    }
                // Trailing button
                if isSecurable {
                    // Secure eye on/off
                    Button {
                        withAnimation { isSecure.toggle() }
                    } label: {
                        Image(systemName: isSecure ? "eye.fill" : "eye.slash.fill")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .foregroundColor(.reverseColor)
                            .frame(width: OurTextFieldConstants.iconSize)
                            .frame(height: OurTextFieldConstants.iconSize)
                            .padding([.vertical, .trailing], OurTextFieldConstants.iconPadding)
                    }
                } else if input.hasContent && config.addClearButton {
                    // Clear when there is something to clear
                    Button {
                        withAnimation { input = "" }
                    } label: {
                        Image("times-circle-solid")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .foregroundColor(.reverseColor)
                            .frame(width: OurTextFieldConstants.iconSize)
                            .frame(height: OurTextFieldConstants.iconSize)
                            .padding([.vertical, .trailing], OurTextFieldConstants.iconPadding)
                    }
                }
            }
            // Background with border
            .background(
                RoundedRectangle(cornerRadius: OurTextFieldConstants.cornerRadius)
                    .foregroundColor(Color("newMeetingBackground"))
                    .overlay(
                        RoundedRectangle(cornerRadius: OurTextFieldConstants.cornerRadius)
                            .strokeBorder(!isValid ? Color.red : Color.allgramMain.opacity(!input.hasContent ? 0.1 : 1), lineWidth: 1)
                    )
            )
            // Placeholder overlay
            .overlay(
                HStack(spacing: 0) {
                    Text(config.placeholder)
                        .foregroundColor(!input.hasContent ? .gray : isValid ? .allgramMain : .red)
                        .padding(.horizontal, OurTextFieldConstants.placeholderTextPadding)
                        .animation(.easeIn(duration: 0.1), value: input)
                        .background(Color("newMeetingBackground").opacity(!input.hasContent ? 0 : 1))
                        .cornerRadius(4)
                        .animation(.none, value: input)
                        .scaleEffect(!input.hasContent ? 1 : 0.8)
                        .offset(y: !input.hasContent ? 0 : -OurTextFieldConstants.inputHeight / 2)
                        .padding(.leading, OurTextFieldConstants.placeholderLeadingPadding(movedUp: input.hasContent, withIcon: config.leadingIconName != nil))
                        .transition(.slide.combined(with: .scale))
                        .animation(.easeIn(duration: 0.1), value: input)
                    Spacer()
                }
                    .onTapGesture {
                        focus.wrappedValue = config.fieldFocus
                    }
            )
            // Provided footer view
            footerView
                .padding(.top, 4)
        }
        // Triggers only when input has changed, so no cycle
        .onChange(of: input) { newValue in
            input = config.filterInput(newValue)
        }
    }
}
