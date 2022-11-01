//
//  CallItemView.swift
//  AllGram
//
//  Created by Alex Pirog on 25.07.2022.
//

import SwiftUI

struct CallItemView: View {
    let chatName: String
    let chatAvatar: URL?
    let callDate: Date
    let isVideoCall: Bool
    let isIncoming: Bool
    let isMissed: Bool
    
    var dateText: String {
        Formatter.string(for: callDate, dateStyle: .long, timeStyle: .medium)
    }
    
    init(chatName: String, chatAvatar: URL?, callDate: Date, isVideoCall: Bool, isIncoming: Bool, isMissed: Bool) {
        self.chatName = chatName
        self.chatAvatar = chatAvatar
        self.callDate = callDate
        self.isVideoCall = isVideoCall
        self.isIncoming = isIncoming
        self.isMissed = isMissed
    }
    
    var body: some View {
        HStack(spacing: 0) {
            AvatarImageView(chatAvatar, name: chatName)
                .frame(width: 42, height: 42)
                .padding(.horizontal)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(chatName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(isIncoming ? "arrow-circle-down-solid" : "arrow-circle-up-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(isMissed ? .red : .primary)
                    Image(isVideoCall ? "video-solid": "phone-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 16, height: 16)
                    Text(dateText)
                        .font(.footnote)
                        .lineLimit(1)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Image("angle-right-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.horizontal)
        }
    }
}
