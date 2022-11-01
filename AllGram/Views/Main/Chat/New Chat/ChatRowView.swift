//
//  ChatRowView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.10.2022.
//

import SwiftUI

struct ChatRowView: View {
    let room: AllgramRoom
    let actionHandler: () -> Void
    
    var body: some View {
        if room.isInvite {
            inviteView
        } else {
            joinedView
        }
    }
    
    private var dateText: String {
        let date = room.summary.lastMessageDate
        let formatter = DateFormatter()
        formatter.dateStyle = date.isToday ? .none : .short
        formatter.timeStyle = date.isToday ? .short : .none
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if room.isMeeting {
            Circle()
            // Orange for instant and purple for scheduled
                .foregroundColor(.ourPurple)
                .overlay(
                    Image("calendar-alt-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(.white)
                )
        } else {
            AvatarImageView(room.realAvatarURL, name: room.displayName)
        }
    }
    
    private var joinedView: some View {
        HStack(spacing: 0) {
            avatarView
                .frame(width: Constants.avatarSize, height: Constants.avatarSize)
                .padding(.trailing, 8)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(room.displayName).bold()
                        .font(.footnote)
                        .foregroundColor(.textHigh)
                    Circle()
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 2)
                        .foregroundColor(.textMedium)
                    Text(dateText)
                        .font(.caption)
                        .foregroundColor(.textMedium)
                }
                if room.lastMessage.hasContent {
                    Text(room.lastMessage)
                        .font(.caption)
                        .foregroundColor(.textMedium)
                }
            }
            .lineLimit(1)
            Spacer()
            let count = room.summary.notificationCount
            if count > 0 {
                Circle()
                    .foregroundColor(.pink)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text(count < 100 ? "\(count)" : "...")
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
                    .padding(.all, 4)
            }
            Image("angle-right-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundColor(.textMedium)
        }
    }
    
    private var inviteView: some View {
        HStack(spacing: 0) {
            avatarView
                .frame(width: 32, height: 32)
                .padding(.trailing, 8)
            VStack(alignment: .leading) {
                Text(room.displayName).bold()
                    .font(.subheadline)
                    .foregroundColor(.textHigh)
                if room.lastMessage.hasContent {
                    Text(room.lastMessage)
                        .font(.caption)
                        .foregroundColor(.textMedium)
                }
            }
            .lineLimit(1)
            Spacer()
            Button {
                actionHandler()
            } label: {
                Text("Action").bold()
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.allgramMain)
                    )
            }
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let avatarSize: CGFloat = 32
    }
}
