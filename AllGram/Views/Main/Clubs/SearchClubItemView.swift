//
//  SearchClubItemView.swift
//  AllGram
//
//  Created by Alex Pirog on 15.02.2022.
//

import SwiftUI
import Kingfisher

struct SearchClubItemView: View {
    let state: JoinState
    let clubName: String
    let avatarURL: URL?
    let joinAction: ((JoinState) -> Void)?
    
    enum JoinState {
        case notJoined, joining, joined
    }
    
    init(_ state: JoinState, clubName: String, avatarURL: URL?, joinAction: ((JoinState) -> Void)? = nil) {
        self.state = state
        self.clubName = clubName
        self.avatarURL = avatarURL
        self.joinAction = joinAction
    }
    
    var body: some View {
        HStack {
            AvatarImageView(avatarURL, name: clubName)
                .frame(width: Constants.photoSize, height: Constants.photoSize)
            Text(clubName)
            Spacer()
            Button {
                joinAction?(state)
            } label: {
                switch state {
                case .notJoined:
                    Text("Join")
                        .frame(height: Constants.joinHeight)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(Color.allgramMain)
                        .clipShape(Capsule())
                    
                case .joining:
                    Spinner()
                    
                case .joined:
                    Text("Joined")
                        .frame(height: Constants.joinHeight)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    struct Constants {
        static let photoSize: CGFloat = 48
        static let joinHeight: CGFloat = 28
    }
    
}

struct SearchClubItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Dark
            VStack {
                SearchClubItemView(.joined, clubName: "First Club", avatarURL: nil)
                SearchClubItemView(.joining, clubName: "Middle Club", avatarURL: nil)
                SearchClubItemView(.notJoined, clubName: "Seconddd", avatarURL: nil)
            }
            .padding()
            .background(Color.black)
            .colorScheme(.dark)
            // Light
            VStack {
                SearchClubItemView(.joined, clubName: "First Club", avatarURL: nil)
                SearchClubItemView(.joining, clubName: "Middle Club", avatarURL: nil)
                SearchClubItemView(.notJoined, clubName: "Seconddd", avatarURL: nil)
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
