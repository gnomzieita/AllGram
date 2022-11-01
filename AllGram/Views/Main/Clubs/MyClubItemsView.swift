//
//  MyClubItemsView.swift
//  AllGram
//
//  Created by Igor Antonchenko on 21.02.2022.
//

import SwiftUI
import Kingfisher

struct MyClubItemsView: View {
    
    let clubName: String
    let avatarURL: URL?
    let createdDate: Date?
    
    init(clubName: String, avatarURL: URL? = nil, createdDate: Date? = nil ){
        self.clubName = clubName
        self.avatarURL = avatarURL
        self.createdDate = createdDate
    }
    
    init(myClubInfo: MyClubInfo, createdDate: Date?) {
        self.clubName = myClubInfo.name
        self.avatarURL = myClubInfo.avatarURL
        self.createdDate = createdDate
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AvatarImageView(avatarURL, name: clubName)
                    .frame(width: Constants.photoSize, height: Constants.photoSize)
                Text(verbatim: clubName)
                    .font(.headline)
                    .lineLimit(1)
                    .allowsTightening(true)
                Spacer()
                if let date = createdDate {
                    Text(Formatter.string(for: date, format: .yearMonthDay))
                        .font(.footnote)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.reverseColor)
            .padding(.vertical, 6)
            Divider()
        }
    }
    
    struct Constants {
        static let photoSize: CGFloat = 42
        static let joinHeight: CGFloat = 32
    }
    
}

struct MyClubItemsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            //Dark
            VStack {
                MyClubItemsView(clubName: "MyClub1",createdDate: Date(timeIntervalSince1970: 1645561050))
                MyClubItemsView(clubName: "MyClub2",createdDate: Date(timeIntervalSince1970: 1645561050))
                MyClubItemsView(clubName: "MyClub3",createdDate: Date(timeIntervalSince1970: 1645561050))
            }
            .padding()
            .background(Color.black)
            .colorScheme(.dark)
            //Light
            VStack {
                MyClubItemsView(clubName: "MyClub1",createdDate: Date(timeIntervalSince1970: 1645561050))
                MyClubItemsView(clubName: "MyClub2",createdDate: Date(timeIntervalSince1970: 1645561050))
                MyClubItemsView(clubName: "MyClub3",createdDate: Date(timeIntervalSince1970: 1645561050))
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


