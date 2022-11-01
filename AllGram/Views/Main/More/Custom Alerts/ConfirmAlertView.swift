//
//  ConfirmAlertView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 10.01.2022.
//

import SwiftUI

extension ConfirmAlertView: DismissibleAlert {
    var alertShown: Binding<Bool> { shown }
}

struct ConfirmAlertView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var backColor: Color {
        switch colorScheme {
        case .dark: return .black
        default: return .white
        }
    }
    
    let title: String
    let subtitle: String?
    let shown: Binding<Bool>
    let callback: ConfirmCallback?
    
    typealias ConfirmCallback = (_ confirmed: Bool) -> Void
    
    init(title: String, subtitle: String? = nil, shown: Binding<Bool>, callback: ConfirmCallback? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.callback = callback
        self.shown = shown
    }
    
    var body: some View {
        VStack {
            Text(title).font(.headline).bold()
                .padding(.bottom, Constants.alertTitlePadding)
            if subtitle != nil {
                Text(subtitle!).font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            Divider()
            HStack {
                Spacer()
                Button(action: {
                    callback?(false)
                    withAnimation { shown.wrappedValue = false }
                }, label: {
                    Text("Cancel").frame(width: Constants.alertButtonsWidth)
                })
                Spacer()
                Divider()
                Spacer()
                Button(action: {
                    callback?(true)
                    withAnimation { shown.wrappedValue = false }
                }, label: {
                    Text("Confirm").frame(width: Constants.alertButtonsWidth)
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
        static let alertTitlePadding: CGFloat = 8
        static let alertCornerRadius: CGFloat = 16
        static let alertButtonsHeight: CGFloat = 32
        static let alertButtonsWidth: CGFloat = 80
    }
    
}

struct ConfirmAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomAlertContainerView {
                ConfirmAlertView(title: "Alert", subtitle: "some clarification text that can take multiple lines and be pretty long in some cases", shown: .constant(true))
            }
            .colorScheme(.dark)
            CustomAlertContainerView {
                ConfirmAlertView(title: "Default Alert", shown: .constant(true))
            }
            .colorScheme(.light)
        }
    }
}
