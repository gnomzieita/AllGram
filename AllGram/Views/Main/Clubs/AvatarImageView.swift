//
//  AvatarImageView.swift
//  AllGram
//
//  Created by Alex Pirog on 01.04.2022.
//

import SwiftUI
import Kingfisher

/// Uses row image or image from URL as an avatar, otherwise takes prefix from name
struct AvatarImageView: View {
    @State private var loaded = false
    @State private var failed = false
    
    let image: UIImage?
    let url: URL?
    let name: String
    
    init(_ image: UIImage?, name: String?) {
        self.image = image
        self.url = nil
        self.name = name ?? ""
    }
    
    init(_ url: URL?, name: String?) {
        self.image = nil
        self.url = url
        self.name = name ?? ""
    }
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                // We have image to use
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(Circle())
            } else if let avatarURL = url, !failed {
                // We have url to use
                KFImage(avatarURL)
                    .onSuccess { _ in
                        withAnimation { loaded = true }
                    }
                    .onFailure { _ in
                        withAnimation { failed = true }
                    }
                    .placeholder {
                        // If failed we won't be here
                        loadingPlaceholder
                    }
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(Circle())
            } else if let prefix = name.avatarLetters, prefix.hasContent {
                // We have letters to use
                let fontFromSize = min(geometry.size.width, geometry.size.height) / 3
                let fontSize = max(12, fontFromSize)
                Text(prefix)
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .foregroundColor(.white)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(backgroundCircle)
            } else {
                // Fallback to simple background
                backgroundCircle
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
    
    private var loadingPlaceholder: some View {
        backgroundCircle
            .overlay(Spinner(.white))
            .opacity(loaded ? 0 : 1)
    }
    
    private var backgroundCircle: some View {
        Circle()
            .fill(Color.allgramMain)
            .padding(.all, 2)
            .background(Color.white)
            .overlay(
                Circle()
                    .stroke(Color.gray, lineWidth: 0.5)
            )
            .clipShape(Circle())
    }
}
