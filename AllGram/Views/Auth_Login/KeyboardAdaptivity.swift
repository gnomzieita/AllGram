//
//  KeyboardAdaptivity.swift
//  AllGram
//
//  Created by Eugene Ned on 10.09.2022.
//

import SwiftUI
import Combine

// MARK: - Pushing the keyboard up if it covers a textfield

struct AdaptsToSoftwareKeyboard: ViewModifier {
    @State var currentHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, currentHeight)
            .animation(.keyboard)
        //            .edgesIgnoringSafeArea(.bottom)
        //            .ignoresSafeArea(.keyboard, edges: .bottom)
            .edgesIgnoringSafeArea(currentHeight == 0 ? [] : .bottom)
            .onAppear(perform: subscribeToKeyboardEvents)
    }
    
    private func subscribeToKeyboardEvents() {
        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillShowNotification
        ).compactMap { notification in
            notification.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect
        }.map { rect in
            rect.height
        }.subscribe(Subscribers.Assign(object: self, keyPath: \.currentHeight))
        
        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillHideNotification
        ).compactMap { notification in
            CGFloat.zero
        }.subscribe(Subscribers.Assign(object: self, keyPath: \.currentHeight))
    }
}

extension Animation {
    static var keyboard: Animation {
        .interpolatingSpring(mass: 3, stiffness: 1000, damping: 500, initialVelocity: 0.0)
    }
}

extension View {
    var keyboardAware: some View {
        self.modifier(AdaptsToSoftwareKeyboard())
    }
}
