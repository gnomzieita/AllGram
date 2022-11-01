//
//  PlaceHolder.swift
//  AllGram
//
//  Created by Admin on 13.08.2021.
//

import Foundation
import SwiftUI

struct PlaceHolder<T: View>: ViewModifier {
    var placeHolder: T
    var color: Color
    var show: Bool
    func body(content: Content) -> some View {
        ZStack(alignment: .leading, content: {
            if show {
                placeHolder
                    .foregroundColor(color)
            }
            content
        })
    }
}

extension View {
    func placeHolder<T: View>(_ holder: T, color: Color, show: Bool) -> some View {
        self.modifier(PlaceHolder(placeHolder: holder, color: color, show: show))
    }
}
