//
//  ClubPostView.swift
//  AllGram
//
//  Created by Alex Pirog on 16.02.2022.
//

import SwiftUI
import Kingfisher

//struct ClubPostView: View {
//    @Environment(\.colorScheme) var colorScheme: ColorScheme
//
//    let clubName: String
//    let clubLogoURL: URL?
//    let postMedia: PostMediaType
//    let mediaAspectRatio: CGFloat
//    let isLicked: Bool
//    let postComments: Int
//    let canDelete: Bool
//
//    /// Used to track post size and position on screen
//    @ObservedObject private var positionManager: ClubPostPositionManager
//
//    let maxMediaHeight: CGFloat
//
//    typealias TapHandler = () -> Void
//
//    let checkClub: TapHandler?
//    let checkContent: TapHandler?
//    let likePost: TapHandler?
//    let commentPost: TapHandler?
//    let viewComments: TapHandler?
//    let deletePost: TapHandler?
//
//    var postWidth: CGFloat {
//        let width = UIScreen.main.bounds.width
//        return width - Constants.clubPostOurPadding * 2
//    }
//
//    var postHeight: CGFloat {
//        let width = postWidth / mediaAspectRatio
//        return min(width, maxMediaHeight)
//    }
//
//    var postText: String? {
//        switch postMedia {
//        case .image(_, let text): return text
//        case .video(_, let text): return text
//        }
//    }
//
//    init(
//        clubName: String,
//        clubLogoURL: URL? = nil,
//        postMedia: PostMediaType,
//        mediaAspectRatio: CGFloat = 0.5,
//        isLicked: Bool = false,
//        postComments: Int = 0,
//        canDelete: Bool = false,
//        maxMediaHeight: CGFloat = UIScreen.main.bounds.height,
//        positionManager: ClubPostPositionManager,
//        checkClub: ClubPostView.TapHandler? = nil,
//        checkContent: ClubPostView.TapHandler? = nil,
//        likePost: ClubPostView.TapHandler? = nil,
//        commentPost: ClubPostView.TapHandler? = nil,
//        viewComments: ClubPostView.TapHandler? = nil,
//        deletePost: ClubPostView.TapHandler? = nil
//    ) {
//        self.clubName = clubName
//        self.clubLogoURL = clubLogoURL
//        self.postMedia = postMedia
//        self.mediaAspectRatio = mediaAspectRatio
//        self.isLicked = isLicked
//        self.postComments = postComments
//        self.canDelete = canDelete
//
//        self.maxMediaHeight = maxMediaHeight
//        self.positionManager = positionManager
//
//        self.checkClub = checkClub
//        self.checkContent = checkContent
//        self.likePost = likePost
//        self.commentPost = commentPost
//        self.viewComments = viewComments
//        self.deletePost = deletePost
//    }
//
//    init(
//        post: ClubPost,
//        maxMediaHeight: CGFloat = UIScreen.main.bounds.height,
//        positionManager: ClubPostPositionManager,
//        checkClub: ClubPostView.TapHandler? = nil,
//        checkContent: ClubPostView.TapHandler? = nil,
//        likePost: ClubPostView.TapHandler? = nil,
//        commentPost: ClubPostView.TapHandler? = nil,
//        viewComments: ClubPostView.TapHandler? = nil,
//        deletePost: ClubPostView.TapHandler? = nil
//    ) {
//        self.clubName = post.clubName
//        self.clubLogoURL = post.clubLogoURL
//        self.postMedia = post.postMedia
//        self.mediaAspectRatio = post.mediaAspectRatio
//        self.isLicked = post.isLicked
//        self.postComments = post.comments.count
//        self.canDelete = post.canDelete
//
//        self.maxMediaHeight = maxMediaHeight
//        self.positionManager = positionManager
//
//        self.checkClub = checkClub
//        self.checkContent = checkContent
//        self.likePost = likePost
//        self.commentPost = commentPost
//        self.viewComments = viewComments
//        self.deletePost = deletePost
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            postHeader
//                .padding(.top, Constants.clubPostOurPadding)
//                .padding(.horizontal, Constants.clubPostOurPadding)
//            postContent
//                .padding(.horizontal, Constants.clubPostOurPadding)
//            postFooter
//        }
//        .onAppear { positionManager.canPlay = true }
//        .onDisappear { positionManager.canPlay = false }
//        .background(Color("bgColor").ignoresSafeArea())
//    }
//
//    private var postHeader: some View {
//        HStack {
//            Group {
//                AvatarImageView(clubLogoURL, name: clubName)
//                    .frame(width: Constants.clubLogoSize, height: Constants.clubLogoSize)
//                Text(clubName)
//                    .font(.subheadline)
//                    .lineLimit(1)
//            }
//            .onTapGesture {
//                checkClub?()
//            }
//            Spacer()
//            if canDelete {
//                Menu {
//                    Button(action: { deletePost?() }) {
//                        MoreOptionView(flat: "Delete Post", imageSystemName: "trash")
//                    }
//                } label: {
//                    Image("ellipsis-v-solid")
//                        .renderingMode(.template)
//                        .resizable().scaledToFit()
//                        .frame(width: Constants.settingsSize)
//                        .frame(height: Constants.settingsSize)
//                }
//            }
//        }
//    }
//
//    private var postContent: some View {
//        VStack(spacing: 0) {
//            VStack(spacing: 0) {
//                switch postMedia {
//                case .image(let info, _):
////                    let text: String = "  " + postMedia.preview + "  "
////                    + "\nContent H: \(postHeight)"
////                    + "\nShould play: \(positionManager.shouldPlay)"
////                    + "\nCan play: \(positionManager.canPlay)"
//                    if info.isEncrypted {
//                        EncryptedClubPlaceholder(text: "Image")
//                            .frame(width: postWidth, height: postHeight)
//                            .clipShape(RoundedRectangle(cornerRadius: 4))
//                            .padding(.top, Constants.clubPostOurPadding)
//                    } else {
//                        KFImage(info.url)
//                            .resizable().scaledToFit()
//                            .placeholder(when: true, alignment: .center) {
//                                ProgressView()
//                                    .scaleEffect(2.0)
//                            }
//                            .frame(width: postWidth, height: postHeight)
//                            .clipShape(RoundedRectangle(cornerRadius: 4))
//                            .padding(.top, Constants.clubPostOurPadding)
//                    }
////                        .overlay(
////                            Text(text)
////                                .multilineTextAlignment(.center)
////                                .foregroundColor(.red)
////                                .background(Color.gray)
////                        )
//                case .video(let info, _):
////                    let text: String = "  " + postMedia.preview + "  "
////                    + "Content H: \(postHeight)"
////                    + "\nShould play: \(positionManager.shouldPlay)"
////                    + "\nCan play: \(positionManager.canPlay)"
//                    if info.isEncrypted {
//                        EncryptedClubPlaceholder(text: "Video")
//                            .frame(width: postWidth, height: postHeight)
//                            .clipShape(RoundedRectangle(cornerRadius: 4))
//                            .padding(.top, Constants.clubPostOurPadding)
//                    } else {
//                        FeedVideoContainer(videoInfo: info, play: .constant(positionManager.shouldPlay))
//                            .equatable()
//                            .frame(width: postWidth, height: postHeight)
//                            .clipShape(RoundedRectangle(cornerRadius: 4))
//                            .padding(.top, Constants.clubPostOurPadding)
//                    }
////                        .overlay(
////                            Text(text)
////                                .multilineTextAlignment(.center)
////                                .foregroundColor(.red)
////                                .background(Color.gray)
////                        )
//                }
//            }
//            .onFrameChange({ frame in
//                let y = frame.origin.y
//                positionManager.contentOriginY = y
//            }, enabled: true)
//            if let text = postText {
//                Text(text)
//                    .font(.subheadline)
//                    .lineLimit(5)
//                    .multilineTextAlignment(.leading)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .fixedSize(horizontal: false, vertical: true)
//                    .padding(.top, 8)
//            }
//        }
//        .onAppear {
//            positionManager.contentHeight = postHeight
//        }
//        .onTapGesture {
//            checkContent?()
//        }
//    }
//
//    private var likeColor: Color {
//        isLicked ? (colorScheme == .dark ? .yellow : .pink) : .primary
//    }
//
//    private var postFooter: some View {
//        VStack {
//            HStack(spacing: 0) {
//                Button(action: { likePost?() }) {
//                    Image(isLicked ? "thumbs-up-full" : "thumbs-up-solid")
//                        .renderingMode(.template)
//                        .resizable().scaledToFit()
//                        .frame(width: Constants.likeSize, height: Constants.likeSize)
//                        .padding(.trailing, Constants.likePadding)
//                        .foregroundColor(likeColor)
//                }
//                Button(action: { commentPost?() }) {
//                    Image("Comment")
//                        .renderingMode(.template)
//                        .resizable().scaledToFit()
//                        .frame(width: Constants.likeSize, height: Constants.likeSize)
//                        .padding(.trailing, 8)
//                }
//                if postComments > 0 {
//                    Button(action: { viewComments?() }) {
//                        Text("\(postComments) comment(s)")
//                            .foregroundColor(.gray)
//                            .font(.subheadline)
//                    }
//                }
//                Spacer()
//            }
//            .padding(.top)
//            .padding(.bottom, 16)
//            .padding(.horizontal, 16)
//        }
//    }
//
//    struct Constants {
//        static let clubPostOurPadding: CGFloat = 10
//        static let clubLogoSize: CGFloat = 28
//        static let settingsSize: CGFloat = 24
//        static let contentHeight: CGFloat = 180
//        static let likeSize: CGFloat = 18
//        static let likePadding: CGFloat = 32
//    }
//
//}

//struct ClubPostView_Previews: PreviewProvider {
//    static let blankURL = URL(string: "https://www.google.com")!
//    static var previews: some View {
//        VStack {
//            // Dark
//            VStack {
//                ClubPostView(clubName: "Top Club", postMedia: .image(url: blankURL, text: "Short post text"), isLicked: true, postComments: 8, canDelete: true)
//                ClubPostView(clubName: "Another Club", postMedia: .video(url: blankURL, text: nil), mediaAspectRatio: 0.5, isLicked: false, postComments: 0, canDelete: false)
//            }
//            .padding()
//            .background(Color.black)
//            .colorScheme(.dark)
//            // Light
//            VStack {
//                ClubPostView(clubName: "Top Club", postMedia: .image(url: blankURL, text: "Some text that happen to be very long indeed. Maybe even multiple lines. Probably cropping anyway"), isLicked: true, postComments: 8, canDelete: true)
//                ClubPostView(clubName: "Another Club", postMedia: .video(url: blankURL, text: nil), mediaAspectRatio: 1.5, isLicked: false, postComments: 0, canDelete: false)
//            }
//            .padding()
//            .background(Color.white)
//            .colorScheme(.light)
//        }
//        .padding()
//        .background(Color.gray)
//        .previewLayout(.sizeThatFits)
//        .accentColor(.accentColor)
//    }
//}

struct EncryptedClubPlaceholder: View {
    let text: String
    
    var body: some View {
        Color.allgramMain
            .overlay(
                Text(text).font(.largeTitle)
                    .foregroundColor(.white)
            )
    }
}
