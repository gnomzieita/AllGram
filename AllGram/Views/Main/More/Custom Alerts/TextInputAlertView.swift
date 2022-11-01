//
//  TextInputAlertView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 21.12.2021.
//

import SwiftUI

extension TextInputAlertView: DismissibleAlert {
    var alertShown: Binding<Bool> { shown }
}

struct TextInputAlertView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var backColor: Color {
        switch colorScheme {
        case .dark: return .black
        default: return .white
        }
    }
    
    let title: String
    let subtitle: String?
    let textInput: Binding<String>
    let inputPlaceholder: String
    let success: Binding<Bool>
    let shown: Binding<Bool>
    
    init(title: String, subtitle: String? = nil, textInput: Binding<String>, inputPlaceholder: String = "Enter text", success: Binding<Bool>, shown: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.textInput = textInput
        self.inputPlaceholder = inputPlaceholder
        self.success = success
        self.shown = shown
    }
    
    var body: some View {
        VStack {
            Text(title).font(.headline).bold()
            if subtitle != nil {
                Text(subtitle!).font(.subheadline)
                    .padding(.horizontal)
            }
            TextField(inputPlaceholder, text: textInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
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
                    success.wrappedValue = true
                    withAnimation { shown.wrappedValue = false }
                }, label: {
                    Text("  OK  ")
                })
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
    }
    
}

struct TextInputAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomAlertContainerView {
                TextInputAlertView(title: "Alert", subtitle: "some clarification text", textInput: .constant(""), inputPlaceholder: "Enter your words here", success: .constant(false), shown: .constant(true))
            }
            .colorScheme(.dark)
            CustomAlertContainerView {
                TextInputAlertView(title: "Default Alert", textInput: .constant(""), success: .constant(false), shown: .constant(true))
            }
            .colorScheme(.light)
        }
    }
}
