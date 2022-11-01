//
//  ChatSystemEventView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI

/// Shows avatar image or uses displayname to generate one, and then provided text (max 2 lines)
struct ChatSystemEventView: View {
    let avatarURL: URL?
    let displayname: String?
    let text: String
    
    init(avatarURL: URL?, displayname: String?, text: String) {
        self.avatarURL = avatarURL
        self.displayname = displayname
        self.text = text
    }
    
    var body: some View {
        ExpandingHStack() {
            AvatarImageView(avatarURL, name: displayname?.dropPrefix("@"))
                .frame(width: 24, height: 24)
            Text(verbatim: text)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
