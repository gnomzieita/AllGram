//
//  InfoAlertView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 11.01.2022.
//

import SwiftUI

extension InfoAlertView: DismissibleAlert {
    var alertShown: Binding<Bool> { shown }
}

struct InfoAlertView: View {
    
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
    
    init(title: String, subtitle: String? = nil, shown: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
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
                    withAnimation { shown.wrappedValue = false }
                }, label: {
                    Text("OK").frame(width: Constants.alertButtonsWidth)
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

struct InfoAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomAlertContainerView {
                InfoAlertView(title: "Alert", subtitle: "some clarification text that can take multiple lines and be pretty long in some cases", shown: .constant(true))
            }
            .colorScheme(.dark)
            CustomAlertContainerView {
                InfoAlertView(title: "Default Alert", shown: .constant(true))
            }
            .colorScheme(.light)
        }
    }
}
