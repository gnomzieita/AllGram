//
//  ChatsItemView.swift
//  AllGram
//
//  Created by Alex Pirog on 03.05.2022.
//

import SwiftUI

/// Chat row view, should be used inside a proper container
struct ChatsItemView: View, Equatable {
    let title: String
    let avatarURL: URL?
    let lastMessageText: String
    let lastMessageTime: Date
    let badge: Int
    
    /// Workaround for updating last message time
    let updates: Int
    
    init(title: String, avatarURL: URL?, lastMessageText: String, lastMessageTime: Date, badge: Int, updates: Int = 0) {
        self.title = title.hasContent ? title : "Unknown"
        self.avatarURL = avatarURL
        self.lastMessageText = lastMessageText.hasContent ? lastMessageText : " "
        self.lastMessageTime = lastMessageTime
        self.badge = badge
        self.updates = updates
    }
    
    /// Parses AllgramRoom for needed info without storing reference to it
    init(room: AllgramRoom, updates: Int) {
        self.init(
            title: room.summary.summary.displayname,
            avatarURL: room.realAvatarURL,
            lastMessageText: room.lastMessage,
            lastMessageTime: room.summary.lastMessageDate,
            badge: Int(room.summary.summary.notificationCount),
            updates: updates
        )
    }
    
    var body: some View {
        HStack {
            AvatarImageView(avatarURL, name: title)
                .frame(width: 42, height: 42)
            VStack(spacing: 2) {
                // Chat title and time of the last message
                HStack {
                    Text(verbatim: title)
                        .font(.headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                    Spacer()
                    Text(Formatter.string(forRelativeDate: lastMessageTime) ?? "?")
                        .font(.footnote)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.gray)
                }
                // The last message and unread badge (if any)
                if lastMessageText.hasContent {
                    HStack(alignment: .top) {
                        Text(verbatim: lastMessageText)
                            .font(.subheadline)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .foregroundColor(.gray)
                        Spacer()
                        if badge > 0 {
                            Text(verbatim: " \(badge) ")
                                .font(.caption)
                                .lineLimit(1)
                                .allowsTightening(true)
                                .foregroundColor(.white)
                                .padding(.all, 4)
                                .background(Color.gray)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
}
