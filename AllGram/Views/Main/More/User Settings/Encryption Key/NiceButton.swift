//
//  NiceButton.swift
//  AllGram
//
//  Created by Alex Pirog on 29.01.2022.
//

import SwiftUI

struct NiceButton: View {
    
    enum NiceAppearance {
        
        /// Accent color for filled background, black/white color for title
        case filled
        
        /// Accent color for stroked background and for title
        case stroked
        
        /// Accent color for for title, no background
        case borderless
        
    }
    
    enum NiceSize {
        
        /// Uses width and height of that defined in `Constants`
        case `default`
        
        /// Custom width/height. Uses defaults if not provided
        case custom(width: CGFloat = Constants.buttonWidth,
                    height: CGFloat = Constants.buttonHeight)
        
        var width: CGFloat {
            switch self {
            case .custom(let w, _): return w
            case .default: return Constants.buttonWidth
            }
        }
        
        var height: CGFloat {
            switch self {
            case .custom(_, let h): return h
            case .default: return Constants.buttonHeight
            }
        }
        
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var backColor: Color {
        switch colorScheme {
        case .dark: return .black
        default: return .white
        }
    }
    
    @ViewBuilder private var backgroundView: some View {
        switch appearance {
        case .filled:
            RoundedRectangle(cornerRadius: Constants.buttonCorner)
                .foregroundColor(.accentColor)
        case .stroked:
            RoundedRectangle(cornerRadius: Constants.buttonCorner)
                .strokeBorder()
                .foregroundColor(.accentColor)
        case .borderless:
            EmptyView()
        }
    }
    
    let title: String
    let appearance: NiceAppearance
    let size: NiceSize
    let action: () -> Void
    
    init(title: String, appearance: NiceAppearance, size: NiceSize = .default, action: @escaping () -> Void) {
        self.title = title
        self.appearance = appearance
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: { action() }) {
            Text(title)
                .foregroundColor(appearance == .filled ? backColor : .accentColor)
                .frame(width: size.width, height: size.height)
                .background(backgroundView)
        }
    }
    
    struct Constants {
        static let buttonCorner: CGFloat = 8
        static let buttonWidth: CGFloat = 240
        static let buttonHeight: CGFloat = 48
    }
    
}

struct NiceButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Group {
                NiceButton(title: "Fist", appearance: .filled, size: .default, action: { })
                NiceButton(title: "Second", appearance: .borderless, size: .default, action: { })
                NiceButton(title: "Third", appearance: .stroked, size: .default, action: { })
            }
            Spacer()
        }
        .colorScheme(.dark)
        VStack {
            Group {
                NiceButton(title: "Fist", appearance: .stroked, size: .custom(width: 300), action: { })
                NiceButton(title: "Second", appearance: .stroked, size: .custom(height: 200), action: { })
                NiceButton(title: "Third", appearance: .stroked, size: .custom(width: 300, height: 300), action: { })
            }
            Spacer()
        }
        .colorScheme(.light)
    }
}
