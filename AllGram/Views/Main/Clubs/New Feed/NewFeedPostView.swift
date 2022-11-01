//
//  NewFeedPostView.swift
//  AllGram
//
//  Created by Alex Pirog on 22.09.2022.
//

import SwiftUI

struct NewFeedPostView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    /// Handles downloading of media files, both encrypted and row
    @StateObject var attachment: ChatMediaAttachment
    
    /// Used to track post size and position on screen
    @ObservedObject private var positionManager: ClubPostPositionManager
    
    let post: NewClubPost
    let maxMediaHeight: CGFloat
    
    typealias TapHandler = () -> Void
    
    let checkClub: TapHandler?
    let checkContent: TapHandler?
    let likePost: TapHandler?
    let commentPost: TapHandler?
    let deletePost: TapHandler?
    
    private let clubName: String
    private let clubLogoURL: URL?
    private let isLiked: Bool
    private let canDelete: Bool
    
    private let mediaWidth: CGFloat
    private let mediaHeight: CGFloat
    
    init(
        post: NewClubPost,
        feedVM: NewClubFeedViewModel,
        maxMediaHeight: CGFloat = UIScreen.main.bounds.height,
        positionManager: ClubPostPositionManager,
        checkClub: TapHandler? = nil,
        checkContent: TapHandler? = nil,
        likePost: TapHandler? = nil,
        commentPost: TapHandler? = nil,
        deletePost: TapHandler? = nil
    ) {
        self.post = post
        self.maxMediaHeight = maxMediaHeight
        self.positionManager = positionManager
        self.checkClub = checkClub
        self.checkContent = checkContent
        self.likePost = likePost
        self.commentPost = commentPost
        self.deletePost = deletePost
        self._attachment = StateObject(wrappedValue: ChatMediaAttachment(event: post.mediaEvent!))
        
        // Internal
        self.clubName = feedVM.clubName
        self.clubLogoURL = feedVM.clubLogoURL
        if let myId = AuthViewModel.shared.sessionVM?.myUserId {
            self.isLiked = post.hasReaction("👍", by: myId)
            self.canDelete = myId == post.senderId
        } else {
            self.isLiked = false
            self.canDelete = false
        }
        
        // Handle size
        let aspectRatio = post.mediaEvent?.mediaSize?.aspectRatio ?? 1
        let maxWidth = UIScreen.main.bounds.width - Constants.clubPostOurPadding * 2
        self.mediaWidth = maxWidth
        self.mediaHeight = min(maxWidth / aspectRatio, maxMediaHeight)
    }
    
    var body: some View {
        VStack(spacing: Constants.clubPostOurPadding) {
            postHeader
            postContent
            postFooter
        }
        .padding(.all, Constants.clubPostOurPadding)
        .onAppear { positionManager.canPlay = true }
        .onDisappear { positionManager.canPlay = false }
        .background(Color("bgColor").ignoresSafeArea())
    }
    
    // MARK: - Header
    
    private var postHeader: some View {
        HStack {
            Group {
                AvatarImageView(clubLogoURL, name: clubName)
                    .frame(width: Constants.clubLogoSize, height: Constants.clubLogoSize)
                Text(verbatim: clubName)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .onTapGesture {
                checkClub?()
            }
            Spacer()
            if canDelete {
                Menu {
                    Button(action: { deletePost?() }) {
                        MoreOptionView(flat: "Delete Post", imageSystemName: "trash")
                    }
                } label: {
                    Image("ellipsis-v-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.settingsSize)
                        .frame(height: Constants.settingsSize)
                }
            }
        }
    }
    
    // MARK: - Content
    
    private var postContent: some View {
        VStack(spacing: 8) {
            mediaView
                .frame(width: mediaWidth, height: mediaHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onFrameChange({ frame in
                    let y = frame.origin.y
                    positionManager.contentOriginY = y
                }, enabled: true)
            textView
        }
        .onAppear {
            positionManager.contentHeight = mediaHeight
        }
        .onTapGesture {
            checkContent?()
        }
    }
    
    @ViewBuilder
    private var mediaView: some View {
        switch post.mediaEvent!.messageType! {
        case .image:
            if let data = attachment.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
            }
            
        case .video:
            if let url = attachment.shareURL {
                NewFeedVideoView(url, play: .constant(positionManager.shouldPlay))
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
            }
            
        default:
            Text("No Media!")
                .font(.largeTitle)
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var textView: some View {
        if let event = post.textEvent {
            let text = ChatTextMessageView.Model(event: event).message
            Text(text)
                .font(.subheadline)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Footer
    
    private var likeColor: Color {
        isLiked ? (colorScheme == .dark ? .yellow : .pink) : .primary
    }
    
    private var postFooter: some View {
        HStack(spacing: 0) {
            Button(action: { likePost?() }) {
                Image(isLiked ? "thumbs-up-full" : "thumbs-up-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: Constants.likeSize, height: Constants.likeSize)
                    .padding(.trailing, Constants.likePadding)
                    .foregroundColor(likeColor)
            }
            Button(action: { commentPost?() }) {
                Image("Comment")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: Constants.likeSize, height: Constants.likeSize)
                    .padding(.trailing, 8)
            }
            let count = post.comments.count
            if count > 0 {
                Button(action: { commentPost?() }) {
                    Text("\(count) comment(s)")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
            }
            Spacer()
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let clubPostOurPadding: CGFloat = 10
        static let clubLogoSize: CGFloat = 28
        static let settingsSize: CGFloat = 24
        static let contentHeight: CGFloat = 180
        static let likeSize: CGFloat = 18
        static let likePadding: CGFloat = 32
    }
}

extension NewFeedPostView: Equatable {
    static func == (lhs: NewFeedPostView, rhs: NewFeedPostView) -> Bool {
        lhs.post == rhs.post
    }
}
