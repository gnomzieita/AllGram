//
//  TopClubView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 22.02.2022.
//

import SwiftUI
import Kingfisher

struct TopClubView: View {
    
    let name: String
    let avatarURL: URL?
    let isInvite: Bool
    let hasUnreadContent: Bool
    let myClubs: Bool
    
    /// For regular clubs & invites
    init(name: String, avatarURL: URL? = nil, isInvite: Bool, hasUnreadContent: Bool) {
        self.name = name
        self.avatarURL = avatarURL
        self.isInvite = isInvite
        self.hasUnreadContent = hasUnreadContent
        self.myClubs = false
    }
    
    /// For `my clubs` option
    init(username: String, avatarURL: URL? = nil) {
        self.name = username
        self.avatarURL = avatarURL
        self.isInvite = false
        self.hasUnreadContent = false
        self.myClubs = true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isInvite {
                    Circle()
                        .foregroundColor(.pink)
                        .frame(width: Constants.avatarSize + Constants.inviteWidth,
                               height: Constants.avatarSize + Constants.inviteWidth)
                }
                AvatarImageView(avatarURL, name: name)
                    .frame(width: Constants.avatarSize, height: Constants.avatarSize)
                    .padding(.all, Constants.avatarPadding)
                if hasUnreadContent { unreadView }
                if myClubs { plusView }
            }
            Text(myClubs ? "My Clubs" : name)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(width: Constants.avatarSize + Constants.avatarPadding,
                       height: Constants.textHeight)
                .foregroundColor(.reverseColor)
                .padding(.vertical, Constants.textSpacing)
        }
    }
    
    private var unreadView: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Circle()
                    .foregroundColor(.pink)
                    .frame(width: Constants.plusSize, height: Constants.plusSize)
            }
        }
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
    }
    
    private var plusView: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "plus.circle")
                    .resizable().scaledToFit()
                    .frame(width: Constants.plusSize, height: Constants.plusSize)
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .foregroundColor(.allgramMain)
                    )
            }
        }
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
    }
    
    struct Constants {
        static let avatarSize: CGFloat = 44
        static let avatarPadding: CGFloat = 6
        static let inviteWidth: CGFloat = 6 // for doth sides
        static let textSpacing: CGFloat = 4
        static let textHeight: CGFloat = 16 // what to expect here?
        static let plusSize: CGFloat = 16
        
        static var estimatedHeight: CGFloat {
            avatarSize + avatarPadding * 2 + textSpacing * 2 + textHeight
        }
    }
    
}

struct TopClubView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Dark
            HStack {
                TopClubView(name: "Short", isInvite: true, hasUnreadContent: true)
                TopClubView(name: "Loooongggggg", isInvite: true, hasUnreadContent: false)
                TopClubView(name: "111", isInvite: false, hasUnreadContent: true)
                TopClubView(name: "Another", isInvite: false, hasUnreadContent: false)
                Spacer()
            }
            .padding()
            .background(Color.black)
            .colorScheme(.dark)
            // Light
            HStack {
                TopClubView(name: "Short", isInvite: true, hasUnreadContent: true)
                TopClubView(name: "Loooongggggg", isInvite: true, hasUnreadContent: false)
                TopClubView(name: "111", isInvite: false, hasUnreadContent: true)
                TopClubView(name: "Another", isInvite: false, hasUnreadContent: false)
                Spacer()
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
