//
//  TextField+Extension.swift
//  AllGram
//
//  Created by Rustam on 29.10.2021.
//

import SwiftUI

extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
    func security<Content: View>(alignment: Alignment = .trailing, @ViewBuilder security: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            security()
            self
        }
    }
}
