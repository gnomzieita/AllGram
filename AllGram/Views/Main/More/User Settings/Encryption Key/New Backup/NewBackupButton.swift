//
//  NewBackupButton.swift
//  AllGram
//
//  Created by Alex Pirog on 04.08.2022.
//

import SwiftUI

struct NewBackupButton: View {
    let title: String
    let titleColor: Color
    let style: ButtonStyle
    let buttonColor: Color
    let action: () -> Void
    
    enum ButtonStyle {
        case filled
        case stroked
    }
    
    init(_ title: String, titleColor: Color, style: ButtonStyle, buttonColor: Color, action: @escaping () -> Void) {
        self.title = title
        self.titleColor = titleColor
        self.style = style
        self.buttonColor = buttonColor
        self.action = action
    }
    
    init(filledTitle: String, action: @escaping () -> Void) {
        self.init(
            filledTitle,
            titleColor: .backColor,
            style: .filled,
            buttonColor: .accentColor,
            action: action
        )
    }
    
    init(strokedTitle: String, action: @escaping () -> Void) {
        self.init(
            strokedTitle,
            titleColor: .accentColor,
            style: .stroked,
            buttonColor: .accentColor,
            action: action
        )
    }
    
    init(destructiveTitle: String, action: @escaping () -> Void) {
        self.init(
            destructiveTitle,
            titleColor: .red,
            style: .stroked,
            buttonColor: .red,
            action: action
        )
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            ExpandingHStack {
                Text(title).bold()
                    .foregroundColor(titleColor)
            }
            .frame(height: 62)
            .background(buttonBackground)
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .filled:
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(buttonColor)
        case .stroked:
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder()
                .foregroundColor(buttonColor)
        }
    }
}

