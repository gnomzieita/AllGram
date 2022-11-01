//
//  NewClubPostView.swift
//  AllGram
//
//  Created by Alex Pirog on 22.09.2022.
//

import SwiftUI
import Combine
import Kingfisher
import MatrixSDK
import AVKit

struct NewClubPostView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.userId) var userId
    
    @State private var showReactionPicker = false
    
    @State private var deletingPost = false
    
    @State private var scrollToComment: NewClubComment?
    private let initialScrollId: String?
        
    @ObservedObject var feedVM: NewClubFeedViewModel
    @ObservedObject private(set) var membersVM: RoomMembersViewModel
    
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    /// Handles input view and provides data for new comments
    @ObservedObject private var inputVM: MessageInputViewModel
    
    /// Handles downloading of media files, both encrypted and row
    @StateObject var attachment: ChatMediaAttachment
    
    /// Handles sending comments with data from inputVM
    let inputHandler: CommentInputHandler
    
    let post: NewClubPost
    
    private let maxMediaHeight: CGFloat = UIScreen.main.bounds.height / 2
    private let mediaWidth: CGFloat
    private let mediaHeight: CGFloat
    private let maxCommentWidth: CGFloat
    
    init(post: NewClubPost, feedVM: NewClubFeedViewModel, scrollToCommentId: String? = nil) {
        self.post = post
        self.feedVM = feedVM
        self.membersVM = RoomMembersViewModel(room: feedVM.room)
        self.inputVM = MessageInputViewModel(config: .comment)
        self.inputHandler = CommentInputHandler(postId: post.idForNewComment, room: feedVM.room)
        self._attachment = StateObject(wrappedValue: ChatMediaAttachment(event: post.mediaEvent!))
        
        // Initial scrolling to comment
        self.initialScrollId = scrollToCommentId
        
        // Handle size
        let aspectRatio = post.mediaEvent?.mediaSize?.aspectRatio ?? 1
        let maxWidth = UIScreen.main.bounds.width - 32
        self.mediaWidth = maxWidth
        self.mediaHeight = min(maxWidth / aspectRatio, maxMediaHeight)
        self.maxCommentWidth = maxWidth - Constants.senderAvatarSize * 2 - Constants.commentPaddingH * 2
    }
    
    @State var showPermissionAlert = false
    @State var permissionAlertText = ""
    
    var body: some View {
        ZStack {
            // Navigation
            VStack {
                NavigationLink(
                    destination: showMediaDestination,
                    isActive: $showMediaDetails
                ) {
                    EmptyView()
                }
            }
            // Post, reactions, comments, input
            content
                .onAppear {
                    //print("[P] initial scroll to comment \(initialScrollId ?? "nil")")
                    scrollToComment = post.comments.first(where: { $0.id == initialScrollId })
                    IgnoringUsersViewModel.shared.getIgnoredUsersList()
                }
            // Custom Alerts
            if showingIgnoreAlert { ignoreAlert }
            if showingReportAlert { reportAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
            if showingLoader { loaderAlert }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            leading:
                HStack {
                    AvatarImageView(feedVM.clubLogoURL, name: feedVM.clubName)
                        .frame(width: Constants.clubLogoSize, height: Constants.clubLogoSize)
                    VStack(alignment: .leading) {
                        Text(feedVM.clubName).bold()
                    }
                }
            ,
            trailing:
                HStack(alignment: .center, spacing: 2) {
                    Menu {
//                        if post.canDelete {
//                            Button {
//                                withAnimation { deletingPost = true }
//                            } label: {
//                                MoreOptionView(flat: "Delete", imageName: "trash-alt-solid")
//                            }
//                        }
//                        if post.canEdit {
//                            Button {
//                                guard let text = post.postMedia.text else { return }
//                                inputVM.message = text
//                                inputVM.inputType = .edit(eventId: postId, highlight: .text(text))
//                            } label: {
//                                MoreOptionView(flat: "Edit", imageName: "edit-solid")
//                            }
//                        }
                        Button {
                            reportEvent = post.postEvents.first
                            withAnimation { showingReportAlert = true }
                        } label: {
                            MoreOptionView(flat: "Report Content", imageName: "flag-solid")
                        }
                    } label: {
                        Image("ellipsis-v-solid")
                            .renderingMode(.template)
                            .resizable()
                    }
                }
        )
    }
    
    private var permissionAlertView: some View {
        ActionAlert(showAlert: $showPermissionAlert, title: "Access to \(permissionAlertText)", text: "Tap Settings and enable \(permissionAlertText)", actionTitle: "Settings") {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    
    private var content: some View {
        ZStack {
            VStack(spacing: 0) {
                // Voice player
                if voicePlayer.currentURL != nil {
                    Divider()
                    ChatVoicePlayerView(
                        voicePlayer: voicePlayer,
                        voiceEvents: post.comments
                            .map { $0.commentEvent }
                            .filter { $0.isVoiceMessage() }
                    )
                        .background(Color("bgColor"))
                }
                // Post content
                LazyVScrollList(
                    post.comments.reversed(),
                    scrollToItem: $scrollToComment,
                    showsIndicators: false,
                    animateScrolling: true,
                    spacing: Constants.commentSpacing,
                    viewForItem: { comment in
                        rowForComment(comment).id(comment.id)
                    },
                    topViewBuilder: {
                        VStack(spacing: 0) {
                            postContent
                            postReactions
                        }
                    },
                    botViewBuilder: {
                        EmptyView()
                    }
                )
                // Input
                Divider()
                MessageInputView(viewModel: inputVM, showPermissionAlert: $showPermissionAlert, permissionAlertText: $permissionAlertText)
                    .equatable()
                    .onAppear {
                        inputHandler.clearHandler = {
                            inputVM.inputType = .new
                        }
                        inputVM.inputDelegate = inputHandler
                    }
            }
                .environmentObject(membersVM)
                .background(Color("bgColor").ignoresSafeArea())
                .onTapGesture { hideKeyboard() }
                .alert(isPresented: $deletingPost) {
                    Alert(title: Text("Remove"),
                          message: Text("Are you sure want to delete this post?"),
                          primaryButton: .destructive(
                            Text("Remove"),
                            action: {
                                withAnimation {
                                    loaderInfo = "Deleting post."
                                    showingLoader = true
                                }
                                feedVM.deletePost(post) {
                                    showingLoader = false
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                          ),
                          secondaryButton: .cancel()
                    )
                }
                .fullScreenCover(isPresented: $showReactionPicker) {
                    ReactionPicker { reaction in
                        if let commentId = eventToReactId {
                            // Reacting on comment
                            if let comment = post.comments.first(where: { $0.id == commentId }) {
                                feedVM.handleReaction(reaction, comment: comment)
                            } else {
                                // Comment from another post?!
                            }
                        } else {
                            // Reacting on post itself
                            feedVM.handleReaction(reaction, post: post)
                        }
                        eventToReactId = nil
                        showReactionPicker = false
                    }
                }
                .alert(item: $eventToRedactId) { eventId in
                    Alert(title: Text("Remove"),
                          message: Text("Are you sure want to delete comment?"),
                          primaryButton: .destructive(
                            Text("Remove"),
                            action: {
                                if let comment = post.comments.first(where: { $0.id == eventId }) {
                                    withAnimation {
                                        loaderInfo = "Deleting coment."
                                        showingLoader = true
                                    }
                                    feedVM.deleteComment(comment) {
                                        showingLoader = false
                                    }
                                }
                            }
                          ),
                          secondaryButton: .cancel()
                    )
                }
            if showPermissionAlert { permissionAlertView }
        }
    }
    
    // MARK: - Post Content
    
    private var postContent: some View {
        VStack(spacing: 8) {
            mediaView
                .frame(width: mediaWidth, height: mediaHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onTapGesture {
                    detailsAttachment = attachment
                    showMediaDetails = true
                }
            textView
        }
        .padding()
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
            if let data = attachment.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .overlay(PlayImageOverlay())
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
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Reactions
    
    @ViewBuilder
    private func reactionBackground(forHost: Bool) -> some View {
        if forHost {
            RoundedRectangle(cornerRadius: 18)
                .foregroundColor(.borderedMessageBackground)
        } else {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder()
                .foregroundColor(.reverseColor)
        }
    }
    
    private var postReactions: some View {
        HStack(alignment: .top, spacing: 0) {
            let addWidth: CGFloat = 120
            Button(action: { showReactionPicker = true }) {
                Text("Add Reaction")
                    .frame(width: addWidth, height: ReactionGridView.Constants.reactionHeight)
                    .background(Capsule().strokeBorder(Color.accentColor))
                    .padding(.horizontal)
            }
            if !post.reactions.isEmpty {
                ReactionGridView(
                    reactions: post.reactions,
                    widthLimit: UIScreen.main.bounds.width - (addWidth + 24),
                    alignment: .leading,
                    textColor: .reverseColor,
                    backColor: .accentColor,
                    userColor: .accentColor
                ) { group in
                    feedVM.handleReaction(group.reaction, post: post)
                }
            }
            Spacer()
        }
    }
    
    // MARK: - Comments
    
    @ViewBuilder
    private func rowForComment(_ comment: NewClubComment) -> some View {
        HStack(alignment: .top) {
            viewForComment(comment)
            Spacer()
        }
        .padding(.horizontal, Constants.commentPaddingH)
        .contextMenu(ContextMenu(menuItems: {
            CommentContextMenu(
                event: comment.commentEvent,
                userId: AuthViewModel.shared.sessionVM?.myUserId ?? "nil",
                onReact: {
                    eventToReactId = comment.id
                    showReactionPicker = true
                },
                onReply: {
                    let h = MessageInputHighlight.text("comment")
                    inputVM.inputType = .reply(eventId: comment.id, highlight: h)
                },
                onEdit: {
                    let h = MessageInputHighlight.text("comment")
                    inputVM.inputType = .edit(eventId: comment.id, highlight: h)
                    //inputVM.message = message
                },
                onRedact: {
                    eventToRedactId = comment.id
                },
                onReport: {
                    reportEvent = comment.commentEvent
                    withAnimation { showingReportAlert = true }
                },
                onIgnore: {
                    ignoreUserId = comment.commentEvent.sender
                    withAnimation { showingIgnoreAlert = true }
                }
            )
        }))
    }
    
    @ViewBuilder
    private func viewForComment(_ comment: NewClubComment) -> some View {
        let reply = comment.isReplyToComment ? post.comments.first(where: { $0.id == comment.commentEvent.replyToEventId! }) : nil
        NewClubCommentView(comment: comment, replyToComment: reply, maxWidth: maxCommentWidth) { group in
            feedVM.handleReaction(group.reaction, comment: comment)
        }
            .equatable()
            .onTapGesture {
                let commentAttachment = ChatMediaAttachment(event: comment.commentEvent)
                if commentAttachment.isValid {
                    detailsAttachment = commentAttachment
                    showMediaDetails = true
                }
            }
    }
    
    // MARK: - Show Media
    
    @State private var showMediaDetails = false
    @State private var detailsAttachment: ChatMediaAttachment?
    
    private var showMediaDestination: some View {
        ZStack {
            if let details = detailsAttachment {
                ChatFullscreenMediaView(attachment: details)
            } else {
                Text("No media...")
                    .onAppear {
                        showMediaDetails = false
                    }
            }
        }
    }
    
    // MARK: - Loading
    
    @State private var showingLoader = false
    @State private var loaderInfo: String?
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showingLoader)
        }
    }
    
    // MARK: - Reporting
    
    @State private var showingReportAlert = false
    @State private var reportEvent: MXEvent?
    @State private var reportReason = ""
    @State private var reportConfirmed = false
    @State private var cancellables = Set<AnyCancellable>()
    
    private var reportAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingReportAlert) {
            TextInputAlertView(title: "Report Content", subtitle: nil, textInput: $reportReason, inputPlaceholder: "Reason for reporting this content", success: $reportConfirmed, shown: $showingReportAlert)
                .onDisappear() {
                    // Continue only when confirmed
                    guard reportConfirmed else {
                        reportEvent = nil
                        reportReason = ""
                        reportConfirmed = false
                        return
                    }
                    // Ensure we have all needed data
                    guard let event = reportEvent,
                          let access = AuthViewModel.shared.session?.credentials.accessToken
                    else {
                        reportEvent = nil
                        reportReason = ""
                        reportConfirmed = false
                        return
                    }
                    let reason = reportReason.hasContent ? reportReason : nil
                    let admins = membersVM.filteredMembers
                        .filter { $0.powerLevel == .admin }
                        .map { $0.id }
                    // Trigger the report
                    loaderInfo = "Reporting content..."
                    withAnimation { showingLoader = true }
                    reportEvent = nil
                    reportReason = ""
                    reportConfirmed = false
                    ApiManager.shared.reportEvent(event, score: -100, reason: reason, admins: admins, accessToken: access)
                        .sink(receiveValue: { success in
                            showingLoader = false
                        })
                        .store(in: &cancellables)
                }
        }
    }
    
    // MARK: - Ignoring
    
    @State private var showingIgnoreAlert = false
    @State private var ignoreUserId: String?
    
    private var ignoreAlert: some View {
        ActionAlert(showAlert: $showingIgnoreAlert, title: "Ignore User", text: "Ignoring this user will remove their messages from all chats and clubs you share. You can reverse this action at any time in the general settings.", actionTitle: "Ignore") {
            guard let id = ignoreUserId else { return }
            loaderInfo = "Ignoring user"
            withAnimation { showingLoader = true }
            ignoreUserId = nil
            IgnoringUsersViewModel.shared.ignoreUser(userId: id) { response in
                withAnimation { showingLoader = false }
                switch response {
                case .success:
                    successHint = "Successfully ignored \(membersVM.member(with: id)?.displayname ?? "user")."
                    withAnimation { showingSuccess = true }
                case .failure(let error):
                    failureHint = "Failed to ignore user.\n\(error.localizedDescription)"
                    withAnimation { showingFailure = true }
                }
                IgnoringUsersViewModel.shared.getIgnoredUsersList()
            }
        }
    }
    
    // MARK: - Success Alert
    
    @State private var showingSuccess = false
    @State private var successHint: String?
    
    private var successAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingSuccess) {
            InfoAlertView(title: "Success", subtitle: successHint, shown: $showingSuccess)
        }
    }
    
    // MARK: - Failure Alert
    
    @State private var showingFailure = false
    @State private var failureHint: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: failureHint, shown: $showingFailure)
        }
    }
    
    // MARK: - Input
    
    @State private var eventToRedactId: String?
    @State private var eventToReactId: String?
    
    // MARK: -
    
    struct Constants {
        static let clubLogoSize: CGFloat = 32
        static let mediaPaddingV: CGFloat = 4
        static let senderAvatarSize: CGFloat = 48
        static let commentPaddingH: CGFloat = 16
        static let commentSpacing: CGFloat = 4
        static let commentBottomGap: CGFloat = 8
    }
}

extension NewClubPostView: Equatable {
    static func == (lhs: NewClubPostView, rhs: NewClubPostView) -> Bool {
        lhs.post == rhs.post
    }
}
