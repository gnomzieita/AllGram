//
//  Extension+Color.swift
//  AllGram
//
//  Created by Admin on 18.08.2021.
//

import Foundation
import SwiftUI

extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension Color {
    static func random() -> Color {
        return Color(UIColor(
            red:   .random(),
            green: .random(),
            blue:  .random(),
            alpha: 1.0
        ).cgColor)
    }
    
    static let postMyCommentBackground = Color("postMyCommentColor")
    static let postOtherCommentBackground = Color("postOtherCommentColor")
    
    static let tabBackground = Color("tabBackground")
    static let tabForeground = Color("tabForeground")
    static let tabSelected = Color("tabSelected")
    
    static let allgramMain = Color("allgram_main_color")
    
    /// `Black` on dark and `white` on light color scheme
    static let backColor = Color("backColor")
    
    /// `White` on dark and `black` on light color scheme
    static let reverseColor = Color("reverseColor")
    
    /// `Black` on dark and `light gray` on light color scheme
    static let moreBackColor = Color("moreBackColor")
    
    /// `Dark gray` on dark and `white` on light color scheme
    /// Mimics `.systemGray6` on dark and `.white` on light color scheme
    /// from default for Form, List row background (not needed to use in Form/List)
    static let moreItemColor = Color("moreItemColor")
    
    static let floatingPanelBackgroundColor = Color("floatingPanelBackgroundColor")
    
    static var borderedMessageBackground: Color = .init("borderedMessageBackground")
    static var myBorderedMessageBackground: Color = .init("myborderedMessageBackgroundColor")
    
    static var textFieldBackground: Color = .init("textFieldBackground")
    
    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return .black
        } else {
            return .white
        }
    }
    
    var uiColor: UIColor { UIColor(self) }
}

extension UXColor {
    /// Color of text that is shown on top of the accent color, e.g. badges.
    static func textOnAccentColor(for colorScheme: ColorScheme) -> UXColor {
        messageTextColor(for: colorScheme, isOutgoing: true)
    }
    
    static func messageTextColor(for colorScheme: ColorScheme,
                                 isOutgoing: Bool) -> UXColor {
        if isOutgoing {
            return .white
        }
        switch colorScheme {
        case .dark:
            return .white
        default:
            return .black
        }
    }
}

extension Color {
    // https://stackoverflow.com/a/56874327/10353982
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Color {
    // Tab bar colors
    static let tabBarBack = Color("tabBarBack")
    static let tabBarActive = Color("tabBarActive")
    
    // Card colors
    static let cardBackground = Color("cardBackground")
    static let cardDisabled = Color("cardDisabled")
    
    /// Has 12% opacity, representing gray border on any color scheme
    static let cardBorder = Color("cardBorder")
    
    /// Yellowish or dark gray color for info cards
    static let infoBoxBackground = Color("infoBoxBackground")
    
    // Colorful colors
    static let ourPurple = Color("ourPurple")
    static let ourGreen = Color("ourGreen")
    static let ourOrange = Color("ourOrange")
    static let ourRed = Color("ourRed")
    
    // MARK: Text related colors
    
    /// Color values picked with transparency,  but actual color is fully opaque!
    /// `Light` - full black, but with 87% opacity. `Dark` - full white, but 100% opacity.
    static let textHigh = Color("textHigh")
    
    /// Color values picked with transparency,  but actual color is fully opaque!
    /// `Light` - full black, but with 54% opacity. `Dark` - full white, but 70% opacity.
    static let textMedium = Color("textMedium")
    
    /// Color values picked with transparency,  but actual color is fully opaque!
    /// `Light` - full black, but with 38% opacity. `Dark` - full white, but 50% opacity.
    static let textDisabled = Color("textDisabled")
    
    /// Color values picked with transparency,  but actual color is fully opaque!
    /// `Light` - full black, but with 12% opacity. `Dark` - full white, but 12% opacity.
    static let textContainer = Color("textContainer")
}
