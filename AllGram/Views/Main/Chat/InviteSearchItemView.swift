//
//  InviteSearchItemView.swift
//  AllGram
//
//  Created by Alex Pirog on 11.02.2022.
//

import SwiftUI
import Kingfisher

struct InviteSearchItemView: View {
    
    let displayName: String
    let nickname: String
    let avatarURL: URL?
    let selection: (() -> Void)?
    
    init(displayName: String, nickname: String, avatarURL: URL? = nil, selection: (() -> Void)? = nil) {
        self.displayName = displayName
        self.nickname = nickname.starts(with: "@")
                        ? nickname
                        : "@\(nickname)"
        self.avatarURL = avatarURL
        self.selection = selection
    }
    
    init(info: UserInfo, selection: (() -> Void)? = nil) {
        self.displayName = info.displayName
        self.nickname = info.shortUserId.starts(with: "@")
                        ? info.shortUserId
                        : "@\(info.shortUserId)"
        self.avatarURL = info.avatarURL
        self.selection = selection
    }
    
    var body: some View {
        Button(action: { selection?() }) {
            HStack {
                AvatarImageView(avatarURL, name: displayName)
                    .frame(width: Constants.photoSize, height: Constants.photoSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                    Text(nickname)
                        .font(.subheadline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
    }
    
    struct Constants {
        static let photoSize: CGFloat = 42
    }
    
}

struct InviteSearchItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Dark
            VStack {
                InviteSearchItemView(displayName: "Bob", nickname: "bob")
                InviteSearchItemView(displayName: "Mark", nickname: "ironmanmk1")
                InviteSearchItemView(displayName: "Tom", nickname: "tom007")
            }
            .padding()
            .background(Color.black)
            .colorScheme(.dark)
            // Light
            VStack {
                InviteSearchItemView(displayName: "Bob", nickname: "@bob")
                InviteSearchItemView(displayName: "Mark", nickname: "@ironmanmk1")
                InviteSearchItemView(displayName: "Tom", nickname: "@tom007")
            }
            .padding()
            .background(Color.white)
            .colorScheme(.light)
        }
        .padding()
        .background(Color.gray)
        .previewLayout(.sizeThatFits)
    }
}
