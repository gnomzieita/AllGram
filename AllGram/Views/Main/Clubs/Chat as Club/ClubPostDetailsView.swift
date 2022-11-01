//
//  ClubPostDetailsView.swift
//  AllGram
//
//  Created by Alex Pirog on 28.02.2022.
//

import SwiftUI
import Combine
import Kingfisher
import MatrixSDK
import AVKit

struct ClubPostDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.userId) var userId
    
    @State private var showMediaDetails = false
    @State private var commentMedia: CommentMediaType?
    
    @State private var showReactionPicker = false
    
    @State private var deletingPost = false
    
    @State private var scrollToComment: ClubComment?
    private let initialScrollId: String?
    
    let postId: String
    
    @ObservedObject private(set) var feedVM: ClubFeedViewModel
    @ObservedObject private(set) var room: AllgramRoom
    @ObservedObject private(set) var membersVM: RoomMembersViewModel
    
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    /// Handles input view and provides data for new comments
    @ObservedObject private var inputVM: MessageInputViewModel
    
    /// Handles sending comments with data from inputVM
    let inputHandler: CommentInputHandler
    
    var post: ClubPost! {
        feedVM.posts.first(where: { $0.id == postId })
    }
    
    init(postId: String, feedVM: ClubFeedViewModel, scrollToCommentId: String? = nil) {
        self.postId = postId
        self.feedVM = feedVM
        self.room = feedVM.room
        self.membersVM = RoomMembersViewModel(room: feedVM.room)
        self.inputVM = MessageInputViewModel(config: .comment)
        self.inputHandler = CommentInputHandler(postId: postId, room: feedVM.room)
        // Initial scrolling to comment
        self.initialScrollId = scrollToCommentId
    }
    
    private var postWidth: CGFloat {
        let width = UIScreen.main.bounds.width
        return width - 32
    }
    
    private var postHeight: CGFloat {
        let width = postWidth
        return width / post.mediaAspectRatio
    }
    
    private var postText: String? {
        switch post.postMedia {
        case .image(_, let text): return text
        case .video(_, let text): return text
        }
    }
    
    private var commentWidth: CGFloat {
        postWidth - Constants.senderAvatarSize * 2 - Constants.commentPaddingH * 2
    }
    
    @State var showPermissionAlert = false
    @State var permissionAlertText = ""
    
    var body: some View {
        ZStack {
            // Navigation
            VStack {
                NavigationLink(
                    destination:
                        Group {
                            if let media = commentMedia {
                                FullscreenMediaView(media: media)
                            } else {
                                FullscreenMediaView(media: post.postMedia)
                            }
                        },
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
                    AvatarImageView(post.clubLogoURL, name: post.clubName)
                        .frame(width: Constants.clubLogoSize, height: Constants.clubLogoSize)
                    VStack(alignment: .leading) {
                        Text(post.clubName).bold()
                    }
                }
            ,
            trailing:
                HStack(alignment: .center, spacing: 2) {
                    Menu {
                        if post.canDelete {
                            Button {
                                withAnimation { deletingPost = true }
                            } label: {
                                MoreOptionView(flat: "Delete", imageName: "trash-alt-solid")
                            }
                        }
                        if post.canEdit {
                            Button {
                                guard let text = post.postMedia.text else { return }
                                inputVM.message = text
                                inputVM.inputType = .edit(eventId: postId, highlight: .text(text))
                            } label: {
                                MoreOptionView(flat: "Edit", imageName: "edit-solid")
                            }
                        }
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
                // TODO: iOS 15
                // .refreshable { feedVM.updatePosts() }
                .simultaneousGesture(
                    // TODO: This will update ALL posts on drag, very efficiently (NOT)
                    DragGesture().onChanged {
                        if 0 < $0.translation.height {
                            feedVM.updatePosts()
                        }
                    }
                )
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
                                feedVM.delete(post: post) {
                                    showingLoader = false
                                    presentationMode.wrappedValue.dismiss()
                                    DispatchQueue.main.async {
                                        feedVM.updatePosts()
                                    }
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
                                feedVM.handleCommentReaction(comment, with: reaction) {
                                    // Delay update
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        feedVM.updatePosts()
                                    }
                                }
                            } else {
                                // Comment from another post?!
                            }
                        } else {
                            // Reacting on post itself
                            feedVM.handlePostReaction(post, with: reaction) {
                                // Delay update
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    feedVM.updatePosts()
                                }
                            }
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
                                withAnimation {
                                    loaderInfo = "Deleting coment."
                                    showingLoader = true
                                }
                                room.redact(eventId: eventId, reason: "Deleting club comment") { _ in
                                    showingLoader = false
                                    DispatchQueue.main.async {
                                        feedVM.updatePosts()
                                    }
                                }
                            }
                          ),
                          secondaryButton: .cancel()
                    )
                }
    //        VStack(spacing: 0) {
    //            // Post content, reactions, comments
    //                ScrollView {
    //                    LazyVStack(spacing: 0) {
    //                        // Post
    //                        postContent
    //                            .alert(isPresented: $deletingPost) {
    //                                Alert(title: Text("Remove"),
    //                                      message: Text("Are you sure want to delete this post?"),
    //                                      primaryButton: .destructive(
    //                                        Text("Remove"),
    //                                        action: {
    //                                            withAnimation {
    //                                                loaderInfo = "Deleting post."
    //                                                showingLoader = true
    //                                            }
    //                                            feedVM.delete(post: post) {
    //                                                showingLoader = false
    //                                                presentationMode.wrappedValue.dismiss()
    //                                                DispatchQueue.main.async {
    //                                                    feedVM.updatePosts()
    //                                                }
    //                                            }
    //                                        }
    //                                      ),
    //                                      secondaryButton: .cancel()
    //                                )
    //                            }
    //                        // Reactions
    //                        postReactions
    //                            .fullScreenCover(isPresented: $showReactionPicker) {
    //                                ReactionPicker { reaction in
    //                                    if let commentId = eventToReactId {
    //                                        // Reacting on comment
    //                                        if let comment = post.comments.first(where: { $0.id == commentId }) {
    //                                            feedVM.handleCommentReaction(comment, with: reaction) {
    //                                                // Delay update
    //                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    //                                                    feedVM.updatePosts()
    //                                                }
    //                                            }
    //                                        } else {
    //                                            // Comment from another post?!
    //                                        }
    //                                    } else {
    //                                        // Reacting on post itself
    //                                        feedVM.handlePostReaction(post, with: reaction) {
    //                                            // Delay update
    //                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    //                                                feedVM.updatePosts()
    //                                            }
    //                                        }
    //                                    }
    //                                    eventToReactId = nil
    //                                    showReactionPicker = false
    //                                }
    //                            }
    //                        // Comments
    //                        postComments
    //                            .alert(item: $eventToRedactId) { eventId in
    //                                Alert(title: Text("Remove"),
    //                                      message: Text("Are you sure want to delete comment?"),
    //                                      primaryButton: .destructive(
    //                                        Text("Remove"),
    //                                        action: {
    //                                            withAnimation {
    //                                                loaderInfo = "Deleting coment."
    //                                                showingLoader = true
    //                                            }
    //                                            room.redact(eventId: eventId, reason: "Deleting club comment") { _ in
    //                                                showingLoader = false
    //                                                DispatchQueue.main.async {
    //                                                    feedVM.updatePosts()
    //                                                }
    //                                            }
    //                                        }
    //                                      ),
    //                                      secondaryButton: .cancel()
    //                                )
    //                            }
    //                    }
    //                }
    //                .padding(.top, 1)
    //                .onTapGesture { hideKeyboard() }
    //                // TODO: iOS 15
    //                // .refreshable { feedVM.updatePosts() }
    //                .simultaneousGesture(
    //                    // TODO: This will update ALL posts on drag, very efficiently (NOT)
    //                    DragGesture().onChanged {
    //                        if 0 < $0.translation.height {
    //                            feedVM.updatePosts()
    //                        }
    //                    }
    //                )
    //            // Input
    //            Divider()
    //            MessageInputView(viewModel: inputVM)
    //                .equatable()
    //                .onAppear {
    //                    inputHandler.clearHandler = {
    //                        inputVM.inputType = .new
    //                    }
    //                    inputVM.inputDelegate = inputHandler
    //                }
    //        }
    //        .background(Color("bgColor").ignoresSafeArea())
            if showPermissionAlert { permissionAlertView }
        }
    }
    
    private var postContent: some View {
        VStack {
            switch post.postMedia {
            case .image(let info, _):
                if info.isEncrypted {
                    EncryptedClubPlaceholder(text: "Image")
                        .frame(width: postWidth, height: postHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.vertical, Constants.mediaPaddingV)
                } else {
                    KFImage(info.url)
                        .resizable().scaledToFit()
                        .frame(width: postWidth, height: postHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.vertical, Constants.mediaPaddingV)
                        .onTapGesture {
                            commentMedia = nil
                            showMediaDetails = true
                        }
                }
            case .video(let info, _):
                if info.isEncrypted {
                    EncryptedClubPlaceholder(text: "Video")
                        .frame(width: postWidth, height: postHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.vertical, Constants.mediaPaddingV)
                } else {
                    KFImage(info.thumbnail.url)
                        .resizable().scaledToFit()
                        .frame(width: postWidth, height: postHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.vertical, Constants.mediaPaddingV)
                        .overlay(PlayImageOverlay())
                        .onTapGesture {
                            commentMedia = nil
                            showMediaDetails = true
                        }
                }
            }
            if let text = postText {
                Text(text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
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
                    if let reaction = group.reaction(from: userId) {
                        room.redact(eventId: reaction.id, reason: nil)
                    } else {
                        room.react(toEventId: post.id, emoji: group.reaction)
                    }
                }
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func rowForComment(_ comment: ClubComment) -> some View {
        HStack(alignment: .top) {
            viewForComment(comment)
            Spacer()
        }
        .padding(.horizontal, Constants.commentPaddingH)
        .contextMenu(ContextMenu(menuItems: {
            CommentContextMenu(
                event: comment.commentEvent,
                userId: room.session.myUserId,
                onReact: {
                    eventToReactId = comment.id
                    showReactionPicker = true
                },
                onReply: {
                    inputVM.inputType = .reply(eventId: comment.id, highlight: .text(comment.mediaShortText))
                },
                onEdit: {
                    inputVM.inputType = .edit(eventId: comment.id, highlight: .text(comment.mediaShortText))
                    if case .text(let message) = comment.commentMedia {
                        inputVM.message = message
                    }
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
    private func viewForComment(_ comment: ClubComment) -> some View {
        let isMyComment = comment.commentEvent.sender.id == room.session.myUserId
        ClubPostCommentView(
            comment: comment,
            sendByMe: isMyComment,
            maxWidth: commentWidth,
            reactionTapHandler: { group in
                if let reaction = group.reaction(from: userId) {
                    room.redact(eventId: reaction.id, reason: nil)
                } else {
                    room.react(toEventId: comment.id, emoji: group.reaction)
                }
            }
        )
            .equatable()
            .onTapGesture {
                // No details for text/voice comments
                if case .text = comment.commentMedia { return }
                if case .voice = comment.commentMedia { return }
                commentMedia = comment.commentMedia
                showMediaDetails = true
            }
    }
    
//    @ViewBuilder
//    private var postComments: some View {
//        LazyVStack(spacing: Constants.commentSpacing) {
//            if post.comments.isEmpty {
//                Text("No comments yet")
//                    .padding(.vertical)
//            } else {
//                ForEach(post.comments, id: \.id) { comment in
//                    let isMyComment = comment.commentEvent.sender.id == room.session.myUserId
//                    let commentView = ClubPostCommentView(
//                        comment: comment,
//                        sendByMe: isMyComment,
//                        maxWidth: commentWidth,
//                        reactionTapHandler: { group in
//                            if let reaction = group.reaction(from: userId) {
//                                room.redact(eventId: reaction.id, reason: nil)
//                            } else {
//                                room.react(toEventId: comment.id, emoji: group.reaction)
//                            }
//                        }
//                    )
//                        .equatable()
//                        .onTapGesture {
//                            // No details for text/voice comments
//                            if case .text = comment.commentMedia { return }
//                            if case .voice = comment.commentMedia { return }
//                            commentMedia = comment.commentMedia
//                            showMediaDetails = true
//                        }
//                    HStack(alignment: .top) {
//                        commentView
//                        Spacer()
//                    }
//                    .id(comment.id)
//                    .padding(.horizontal, Constants.commentPaddingH)
//                    .contextMenu(ContextMenu(menuItems: {
//                        EventContextMenu(
//                            event: comment.commentEvent,
//                            userId: room.session.myUserId,
//                            onReact: {
//                                eventToReactId = comment.id
//                                showReactionPicker = true
//                            },
//                            onReply: {
//                                inputVM.inputType = .reply(eventId: comment.id, highlight: .text(comment.mediaShortText))
//                            },
//                            onEdit: {
//                                inputVM.inputType = .edit(eventId: comment.id, highlight: .text(comment.mediaShortText))
//                                if case .text(let message) = comment.commentMedia {
//                                    inputVM.message = message
//                                }
//                            },
//                            onRedact: {
//                                eventToRedactId = comment.id
//                            }
//                        )
//                    }))
//                }
//            }
//        }
//        .padding(.bottom, Constants.commentBottomGap)
//    }
    
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

extension ClubPostDetailsView: Equatable {
    static func == (lhs: ClubPostDetailsView, rhs: ClubPostDetailsView) -> Bool {
        return lhs.postId == rhs.postId
    }
}

import SwiftUI
import MatrixSDK

struct CommentContextMenuViewModel {
    let canReact: Bool
    let canReply: Bool
    let canEdit: Bool
    let canRedact: Bool
    let canReport: Bool
    let canIgnore: Bool

    init(event: MXEvent, userId: String) {
        var canReact = false
        var canReply = false
        var canEdit = false
        var canRedact = false
        var canReport = false
        var canIgnore = false

        // The correct way to check if replying is possible is `-[MXRoom canReplyToEvent:]`.
        if event.type == kMXEventTypeStringRoomMessage {
            canReact = true
            canReply = true
        }

        // TODO: Redacting messages is a powerlevel thing, you can't only redact your own.
        if event.sender == userId && event.type == kMXEventTypeStringRoomMessage && !event.isRedactedEvent() {
            canEdit = !event.isMediaAttachment()
            canRedact = true
        }
        
        // User can only report NOT encrypted events and events sent by others
        if event.sender != userId && !event.isEncrypted {
            canReport = true
        }
        
        // User can ignore all other users
        if event.sender != userId {
            canIgnore = true
        }

        self.canReact = canReact
        self.canReply = canReply
        self.canEdit = canEdit
        self.canRedact = canRedact
        self.canReport = canReport
        self.canIgnore = canIgnore
    }
}

struct CommentContextMenu: View {
    typealias Action = () -> Void

    private let onReact: Action
    private let onReply: Action
    private let onEdit: Action
    private let onRedact: Action
    private let onReport: Action
    private let onIgnore: Action
    
    private var model: CommentContextMenuViewModel

    init(event: MXEvent,
         userId: String,
         onReact: @escaping Action,
         onReply: @escaping Action,
         onEdit: @escaping Action,
         onRedact: @escaping Action,
         onReport: @escaping Action,
         onIgnore: @escaping Action
    ) {
        self.model = CommentContextMenuViewModel(event: event, userId: userId)
        self.onReact = onReact
        self.onReply = onReply
        self.onEdit = onEdit
        self.onRedact = onRedact
        self.onReport = onReport
        self.onIgnore = onIgnore
    }

    var body: some View {
        Group {
            if model.canReact {
                Button(action: onReact, label: {
                    Text("Add Reaction")
                    Image("smile-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                })
            }
            if model.canReply {
                Button(action: onReply, label: {
                    Text("Reply")
                    Image("reply-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                })
            }
            if model.canEdit {
                Button(action: onEdit, label: {
                    Text("Edit")
                    Image("pen-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                })
            }
            if model.canRedact {
                Button(action: onRedact, label: {
                    Text("Remove")
                    Image("times-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                })
            }
            if model.canReport {
                Button(action: onReport, label: {
                    Text("Report Content")
                    Image("flag-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                })
            }
            if model.canIgnore {
                Button(action: onIgnore, label: {
                    Text("Ignore User")
                    Image("exclamation-triangle-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                })
            }
        }
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
    }
}

