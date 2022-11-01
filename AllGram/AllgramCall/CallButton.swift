//
//  CallButton.swift
//  AllGram
//
//  Created by Alex Pirog on 08.02.2022.
//

import SwiftUI

struct CallButton: View {
    
    typealias ButtonAction = () -> Void
    
    enum ButtonScale: Int {
        
        case tiny = 1
        case small
        case medium
        case big
        case huge
        
        var iconSize: CGFloat {
            return buttonSize * 4 / 9
        }
        
        var buttonSize: CGFloat {
            // 24-36-48-60-72
            return 12 + CGFloat(self.rawValue) * 12
        }
        
    }
    
    enum ButtonType {
        
        case mic(on: Bool)
        case speaker(on: Bool)
        case video(on: Bool)
        
        case chat
        case menu
        
        case acceptCall
        case endCall
        
        var image: Image {
            switch self {
            case .mic(let on):
                return Image(systemName: on ? "mic.fill" : "mic.slash.fill")
            case .speaker(let on):
                return Image(systemName: on ? "speaker.wave.2.fill" : "speaker.slash.fill")
            case .video(let on):
                return Image(systemName: on ? "video.fill" : "video.slash.fill")
            case .chat:
                return Image(systemName: "message.fill")
            case .menu:
//                return Image("ellipsis-v-solid")
                return Image(systemName: "ellipsis")
            case .acceptCall, .endCall:
                return Image(systemName: "phone.fill")
            }
        }
        
        var rotateDegrees: CGFloat {
            switch self {
            case .menu, .endCall: return 90
            default: return 0
            }
        }
        
        func foregroundColor(in colorScheme: ColorScheme) -> Color {
            switch self {
            case .acceptCall, .endCall:
                return .white
            default:
                return .black
            }
        }
        
        func backgroundColor(in colorScheme: ColorScheme) -> Color {
            switch self {
            case .acceptCall:
                return .green
            case .endCall:
                return .red
            default:
                // Use tab background for light mode
                return colorScheme == .dark ? .white : Color.tabBackground
            }
        }
        
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    let type: ButtonType
    let scale: ButtonScale
    let action: ButtonAction
    
    init(type: CallButton.ButtonType,
         scale: CallButton.ButtonScale,
         action: @escaping CallButton.ButtonAction
    ) {
        self.type = type
        self.scale = scale
        self.action = action
    }
    
    var body: some View {
        Button(action: { action() }) {
            type.image
                .resizable().scaledToFit()
                .frame(width: scale.iconSize, height: scale.iconSize)
                .foregroundColor(type.foregroundColor(in: colorScheme))
                .rotationEffect(.degrees(type.rotateDegrees))
        }
        .frame(width: scale.buttonSize, height: scale.buttonSize)
        .background(type.backgroundColor(in: colorScheme))
        .clipShape(Circle())
    }
    
}

struct CallButton_Previews: PreviewProvider {
    
    static var previews: some View {
        VStack {
            // Dark
            VStack {
                HStack {
                    CallButton(type: .mic(on: true), scale: .tiny) { }
                    CallButton(type: .mic(on: false), scale: .small) { }
                    CallButton(type: .speaker(on: true), scale: .medium) { }
                    CallButton(type: .speaker(on: false), scale: .big) { }
                }
                HStack {
                    CallButton(type: .acceptCall, scale: .huge) { }
                    CallButton(type: .endCall, scale: .huge) { }
                }
            }
            .padding()
            .colorScheme(.dark)
            .background(Color.black)
            
            // Light
            VStack {
                HStack {
                    CallButton(type: .chat, scale: .small) { }
                    CallButton(type: .mic(on: true), scale: .medium) { }
                    CallButton(type: .video(on: false), scale: .medium) { }
                    CallButton(type: .menu, scale: .small) { }
                }
                HStack {
                    CallButton(type: .acceptCall, scale: .huge) { }
                    CallButton(type: .endCall, scale: .huge) { }
                }
            }
            .padding()
            .colorScheme(.light)
            .background(Color.white)
        }
        .padding()
        .background(Color.gray)
        .previewLayout(.sizeThatFits)
    }
}
