//
//  LoaderAlertView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 11.01.2022.
//

import SwiftUI

extension LoaderAlertView: DismissibleAlert {
    var alertShown: Binding<Bool> { shown }
}

struct LoaderAlertView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var backColor: Color {
        switch colorScheme {
        case .dark: return .black
        default: return .white
        }
    }
    
    let title: String
    let subtitle: String?
    let cancellable: Bool
    let shown: Binding<Bool>
    
    init(title: String, subtitle: String? = nil, cancellable: Bool = false, shown: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.cancellable = cancellable
        self.shown = shown
    }
    
    var body: some View {
        VStack {
            Text(title).font(.headline).bold()
                .padding(.horizontal)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                .scaleEffect(Constants.alertSpinnerScale)
                .padding(.all, Constants.alertSpinnerPadding)
            if subtitle != nil {
                Text(subtitle!).font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            Divider()
            HStack {
                Spacer()
                if cancellable {
                    Button(action: { withAnimation { shown.wrappedValue = false } }) {
                        Text("Cancel").frame(width: Constants.alertButtonsWidth)
                    }
                } else {
                    Text("Please, wait")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                }
                Spacer()
            }
            .frame(height: Constants.alertButtonsHeight)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: Constants.alertCornerRadius)
                        .foregroundColor(backColor))
    }
    
    struct Constants {
        static let alertSpinnerScale: CGFloat = 2
        static let alertSpinnerPadding: CGFloat = 20
        static let alertCornerRadius: CGFloat = 16
        static let alertButtonsHeight: CGFloat = 32
        static let alertButtonsWidth: CGFloat = 80
    }
    
}

struct LoaderAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomAlertContainerView {
                LoaderAlertView(title: "Alert", subtitle: "some clarification text that can take multiple lines and be pretty long in some cases", cancellable: true, shown: .constant(true))
            }
            .colorScheme(.dark)
            CustomAlertContainerView {
                LoaderAlertView(title: "Loading...", shown: .constant(true))
            }
            .colorScheme(.light)
        }
    }
}
