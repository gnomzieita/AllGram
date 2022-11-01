//
//  CustomAlertView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 20.12.2021.
//

import SwiftUI

protocol DismissibleAlert {
    var alertShown: Binding<Bool> { get }
}

struct CustomAlertContainerView<Content: View>: View {
    
    let allowTapDismiss: Bool
    let shown: Binding<Bool>
    
    /// Expected to be one of the custom alert views
    @ViewBuilder let content: Content
    
    init(allowTapDismiss: Bool = false, shown: Binding<Bool> = .constant(true), content: () -> Content) {
        self.allowTapDismiss = allowTapDismiss
        self.shown = shown
        self.content = content()
    }
    
    var body: some View {
        GeometryReader() { geometry in
            ZStack {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3)) // To be able to catch taps, must not be fully transparent
                    .onTapGesture {
                        guard allowTapDismiss else { return }
                        withAnimation { shown.wrappedValue = false }
                    }
                VStack {
                    Spacer()
                    content
                        .frame(minWidth: 100, idealWidth: 150, maxWidth: geometry.size.width * 0.8, minHeight: 100, idealHeight: 150, maxHeight: geometry.size.height * 0.8)
//                        .frame(maxWidth: geometry.size.width * 0.8, minHeight: 100, idealHeight: 150, maxHeight: geometry.size.height * 0.8)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .all)
        }
    }
    
}

struct CustomAlertContainerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomAlertContainerView {
                Text("Any custom alert")
            }
            .colorScheme(.dark)
            CustomAlertContainerView {
                TextInputAlertView(title: "Default Alert", textInput: .constant(""), success: .constant(false), shown: .constant(true))
            }
            .colorScheme(.light)
        }
    }
}
