//
//  ClubFeedView.swift
//  AllGram
//
//  Created by Alex Pirog on 16.02.2022.
//

import SwiftUI
import Kingfisher
import MatrixSDK

//struct ClubFeedView: View {
//    @Environment(\.presentationMode) var presentationMode
//    
//    @ObservedObject var navManager = NavigationManager.shared
//    
//    @State private var showRoomSettings = false
//    @State private var showInviteParticipant = false
//    @State private var showContentSearch = false
//    
//    private let inviteUserViewModel: InviteUserViewModel
//    private let inviteVM: ClubInviteViewModel
//    
//    @ObservedObject private var room: AllgramRoom
//    @ObservedObject private var viewModel: ClubFeedViewModel
//    @ObservedObject private var membersVM: RoomMembersViewModel
//    
//    private var feedManager = FeedPositionManager()
//    
//    @State var selectedEvent: MXEvent?
//    
//    private let onBack: () -> Void
//    
//    init(room: AllgramRoom, onBack: @escaping () -> Void) {
//        self.onBack = onBack
//        self.room = room
//        self.viewModel = ClubFeedViewModel(room: room)
//        self.membersVM = RoomMembersViewModel(room: room)
//        self.inviteUserViewModel = InviteUserViewModel(room: room)
//        self.inviteVM = ClubInviteViewModel(room: room)
//        viewModel.updatePosts()
//    }
//    
//    @State private var showCreatingPost = false
//    @State private var deletingPost: ClubPost?
//    
//    @State var showInvite = false
//    
//    var body: some View {
//        ZStack {
//            // Navigation
//            VStack {
//                NavigationLink(
//                    destination: selectedPostDestination,
//                    isActive: $showSelectedPost
//                ) {
//                    EmptyView()
//                }
//                NavigationLink(
//                    destination: NewPostView(feedVM: viewModel).equatable(),
//                    isActive: $showCreatingPost
//                ) {
//                    EmptyView()
//                }
//                NavigationLink(
//                    destination: RoomSettingsView(room: room),
//                    isActive: $showRoomSettings
//                ) {
//                    EmptyView()
//                }
//                NavigationLink(
//                    destination:
//                        ContentSearchView(room: room, selectedEvent: $selectedEvent)
//                        .environmentObject(membersVM)
//                    , isActive: $showContentSearch
//                ) {
//                    EmptyView()
//                }
//                NavigationLink(
//                    destination: NewInviteView(viewModel: inviteUserViewModel, headerOfView: "Invite someone to the Club"),
//                    isActive: $showInviteParticipant
//                ) {
//                    EmptyView()
//                }
//            }
//            // Content
//            ZStack {
//                content
//                    .simultaneousGesture(animationGesture)
//                    .onAppear {
//                        showInvite = !room.session.isJoined(onRoom: room.room.roomId)
//                        viewModel.updatePosts()
//                        room.markAllAsRead()
//                        // Do async to get it work properly
//                        DispatchQueue.main.async {
//                            feedManager.allowPlaying = true
//                            if let id = navManager.postId {
//                                navManager.postId = nil
//                                guard let event = room.event(withEventId: id)
//                                else { return }
//                                loaderInfo = "Searching for the post."
//                                withAnimation { showingLoader = true }
//                                room.paginate(till: event) { success in
//                                    // Same as after search below...
//                                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
//                                        withAnimation { showingLoader = false }
//                                        if success {
//                                            showSelectedPost = false
//                                            if let post = viewModel.getPost(for: event) {
//                                                //print("[P] found post right away")
//                                                selectedPostId = post.id
//                                                scrollEventId = event.eventId
//                                                showSelectedPost = true
//                                            } else {
//                                                viewModel.updatePosts()
//                                                if let post = viewModel.getPost(for: event) {
//                                                    //print("[P] found post after update")
//                                                    selectedPostId = post.id
//                                                    scrollEventId = event.eventId
//                                                    showSelectedPost = true
//                                                } else {
//                                                    //print("[P] failed to find post")
//                                                    infoAlertTitle = "Failed"
//                                                    infoAlertSubtitle = "Failed to find selected post."
//                                                    withAnimation { showingInfo = true }
//                                                }
//                                            }
//                                        } else {
//                                            infoAlertTitle = "Failed"
//                                            infoAlertSubtitle = "Failed to paginate to selected post."
//                                            withAnimation { showingInfo = true }
//                                        }
//                                        selectedEvent = nil
//                                    }
//                                }
//                            }
//                        }
//                    }
//                    .onDisappear {
//                        feedManager.allowPlaying = false
//                    }
//                // New Post Button
//                FloatingButton(type: .newPost, controller: animationController) {
//                    showCreatingPost = true
//                }
//                .disabled(showingLoader)
//            }
//            .background(Color("bgColor").ignoresSafeArea())
//            // Custom Alerts
//            if showingInfo { infoAlert }
//            if showingLoader { loaderAlert }
//            // Cover with Invite screen if needed
//            if showInvite {
//                ClubInviteView(vm: inviteVM) { state in
//                    switch state {
//                    case .rejected:
//                        // Rejected invite - exit
//                        presentationMode.wrappedValue.dismiss()
//                    case .accepted:
//                        // Accepted invite - show feed
//                        showInvite = false
//                    default:
//                        // Processing handled inside
//                        break
//                    }
//                }
//                    .equatable()
//                    .background(Color.backColor)
//            }
//        }
//        .background(Color("bgColor").ignoresSafeArea())
//        .alert(item: $deletingPost) { post in
//            Alert(title: Text("Remove"),
//                  message: Text("Are you sure want to delete this post?"),
//                  primaryButton: .destructive(
//                    Text("Remove"),
//                    action: {
//                        loaderInfo = "Deleting post and removing it from feed."
//                        withAnimation {
//                            showingLoader = true
//                            viewModel.delete(post: post) {
//                                viewModel.updatePosts()
//                                showingLoader = false
//                            }
//                        }
//                    }
//                  ),
//                  secondaryButton: .cancel()
//            )
//        }
//        .onChange(of: selectedEvent) { event in
//            guard let event = event else { return }
//            loaderInfo = "Paginating back to selected post."
//            withAnimation { showingLoader = true }
//            room.paginate(till: event) { success in
//                // This may happen while we are still transitioning back
//                // from content search view to club feed view.
//                // In this case, we can't navigate to post right away,
//                // so do it after a considerable delay to counter cases
//                // without or with short paginate time.
//                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
//                    withAnimation { showingLoader = false }
//                    if success {
//                        showSelectedPost = false
//                        if let post = viewModel.getPost(for: event) {
//                            //print("[P] found post right away")
//                            selectedPostId = post.id
//                            scrollEventId = event.eventId
//                            showSelectedPost = true
//                        } else {
//                            viewModel.updatePosts()
//                            if let post = viewModel.getPost(for: event) {
//                                //print("[P] found post after update")
//                                selectedPostId = post.id
//                                scrollEventId = event.eventId
//                                showSelectedPost = true
//                            } else {
//                                //print("[P] failed to find post")
//                                infoAlertTitle = "Failed"
//                                infoAlertSubtitle = "Failed to find selected post."
//                                withAnimation { showingInfo = true }
//                            }
//                        }
//                    } else {
//                        infoAlertTitle = "Failed"
//                        infoAlertSubtitle = "Failed to paginate to selected post."
//                        withAnimation { showingInfo = true }
//                    }
//                    selectedEvent = nil
//                }
//            }
//        }
//        .navigationBarTitleDisplayMode(.inline)
//        .ourToolbar(
//            leading:
//                HStack {
//                    AvatarImageView(viewModel.clubLogoURL, name: viewModel.clubName)
//                        .frame(width: Constants.clubLogoSize, height: Constants.clubLogoSize)
//                    Text(viewModel.clubName).bold()
//                }
//                .onTapGesture {
//                    showRoomSettings = true
//                }
//                .disabled(showInvite || showingLoader)
//            ,
//            trailing:
//                HStack(alignment: .center, spacing: 2) {
//                    Menu {
//                        Button(action: { showRoomSettings = true }, label: {
//                            MoreOptionView(flat: "Settings", imageName: "users-cog-solid")
//                        })
//                        if !room.isEncrypted {
//                            // Content search for not encrypted room (public club)
//                            Button(action: { showContentSearch = true }, label: {
//                                MoreOptionView(flat: "Search", imageName: "search-solid")
//                            })
//                        }
//                        Button(action: { showInviteParticipant = true }, label: {
//                            MoreOptionView(flat: "Invite", imageName: "user-plus-solid")
//                                .opacity(inviteUserViewModel.canInvite ? 1 : 0.5)
//                        })
//                        Button {
//                            withAnimation {
//                                loaderInfo = "Leaving this club."
//                                showingLoader = true
//                                room.room.leave { response in
//                                    showingLoader = false
//                                    switch response {
//                                    case .success:
//                                        presentationMode.wrappedValue.dismiss()
//                                    case .failure(_):
//                                        break
//                                    }
//                                }
//                            }
//                        } label: {
//                            MoreOptionView(flat: "Leave", imageName: "sign-out-alt-solid")
//                        }
//                    } label: {
//                        ToolbarImage(.menuDots)
//                    }
//                }
//                .disabled(showInvite || showingLoader)
//        )
//    }
//    
//    private var content: some View {
//        VStack {
//            styleSwitch
//            switch selectedStyle {
//            case .feed:
//                feedStyleContent
//            case .grid:
//                gridStyleContent
//            }
//        }
//    }
//    
//    private enum ClubContentStyle: String, CaseIterable {
//        case feed
//        case grid
//    }
//    
//    @State private var selectedStyle: ClubContentStyle = .feed
//    
//    private var styleSwitch: some View {
//        // Native selecting tabs
//        Picker("Select Club Content Style", selection: $selectedStyle) {
//            ForEach(ClubContentStyle.allCases, id: \.self) { style in
//                switch style {
//                case .feed:
//                    Image("rows-solid")
//                        .renderingMode(.template)
//                        .resizable().scaledToFit()
//                        .frame(width: 24, height: 24)
//                case .grid:
//                    Image("table-solid")
//                        .renderingMode(.template)
//                        .resizable().scaledToFit()
//                        .frame(width: 24, height: 24)
//                }
//            }
//        }
//        .pickerStyle(.segmented)
//        .padding()
//    }
//    
//    private var feedStyleContent: some View {
//        VStack {
//            if viewModel.isBusy {
//                Spacer()
//                ProgressView()
//                    .scaleEffect(Constants.loaderScale)
//                Spacer()
//            } else if !viewModel.posts.isEmpty {
//                ScrollView(.vertical) {
//                    LazyVStack(spacing: Constants.feedSpacing) {
//                        ForEach(viewModel.posts.reversed(), id: \.id) { post in
//                            let positionManager = feedManager.createManager(for: post.id)
//                            ClubPostView(
//                                post: post,
//                                maxMediaHeight: UIScreen.main.bounds.height / 2,
//                                positionManager: positionManager,
//                                checkClub: {
//                                    selectedPostId = post.id
//                                    showSelectedPost = true
//                                },
//                                checkContent: {
//                                    selectedPostId = post.id
//                                    showSelectedPost = true
//                                },
//                                likePost: {
//                                    if post.isLicked {
//                                        viewModel.removeReaction(from: post) {
//                                            // Delay the update
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                                                viewModel.updatePosts()
//                                            }
//                                        }
//                                    } else {
//                                        viewModel.react(to: post) {
//                                            // Delay the update
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                                                viewModel.updatePosts()
//                                            }
//                                        }
//                                    }
//                                },
//                                commentPost: {
//                                    selectedPostId = post.id
//                                    showSelectedPost = true
//                                },
//                                viewComments: {
//                                    selectedPostId = post.id
//                                    showSelectedPost = true
//                                },
//                                deletePost: {
//                                    deletingPost = post
//                                }
//                            )
//                                .accentColor(.reverseColor)
//                                .background(Color.backColor)
//                        }
//                        if viewModel.room.expectMoreHistory {
//                            HStack(spacing: Constants.pagingPadding) {
//                                ProgressView()
//                                Text("Loading more posts...")
//                                    .font(.subheadline)
//                            }
//                            .foregroundColor(.gray)
//                            .padding()
//                            .onAppear {
//                                viewModel.paginate()
//                            }
//                        }
//                    }
//                }
//                .padding(.top, 1)
//                .background(Color.gray.opacity(0.3))
//                .onFrameChange({ frame in
//                    feedManager.feedFrame = frame
//                }, enabled: true)
//            } else {
//                Text("No posts yet")
//                    .foregroundColor(.gray)
//                    .padding()
//                    .onAppear {
//                        viewModel.paginate()
//                    }
//                Spacer()
//            }
//        }
//    }
//    
//    private let columns = [
//        GridItem(.flexible()),
//        GridItem(.flexible()),
//        GridItem(.flexible())
//    ]
//    
//    private var gridStyleContent: some View {
//        VStack(spacing: 0) {
//            // Club info (always on screen)
//            HStack(spacing: 0) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(verbatim: viewModel.clubName)
//                        .font(.headline)
//                    if let topic = viewModel.clubTopic, topic.hasContent {
//                        Text(verbatim: topic)
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                    }
//                    if let description = viewModel.clubDescription, description.hasContent {
//                        Text(verbatim: description)
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                    }
//                }
//                Spacer()
//            }
//            .padding(.horizontal)
//            .padding(.bottom)
//            Divider()
//            // Club Posts
//            if viewModel.isBusy {
//                Spacer()
//                ProgressView()
//                    .scaleEffect(Constants.loaderScale)
//                Spacer()
//            } else if !viewModel.posts.isEmpty {
//                ScrollView(.vertical) {
//                    LazyVGrid(columns: columns, spacing: 0) {
//                        ForEach(viewModel.posts.reversed(), id: \.id) { post in
//                            NavigationLink {
//                                ClubPostDetailsView(postId: post.id, feedVM: viewModel)
//                            } label: {
//                                switch post.postMedia {
//                                case .image(let info, _):
//                                    KFImage(info.url)
//                                        .resizable().scaledToFill()
//                                        .frame(width: UIScreen.main.bounds.width / 3,
//                                               height: UIScreen.main.bounds.width / 3)
//                                        .clipped()
//                                case .video(let info,_):
//                                    KFImage(info.thumbnail.url)
//                                        .resizable().scaledToFill()
//                                        .frame(width: UIScreen.main.bounds.width / 3,
//                                               height: UIScreen.main.bounds.width / 3)
//                                        .clipped()
//                                        .overlay(PlayImageOverlay(size: 32))
//                                }
//                            }
//                        }
//                    }
//                    if viewModel.room.expectMoreHistory && !viewModel.isPaginating {
//                        HStack(spacing: Constants.pagingPadding) {
//                            ProgressView()
//                            Text("Loading more posts...")
//                                .font(.subheadline)
//                        }
//                        .foregroundColor(.gray)
//                        .padding()
//                        .onAppear {
//                            viewModel.paginate()
//                        }
//                    }
//                }
//            } else {
//                Text("No posts yet")
//                    .foregroundColor(.gray)
//                    .padding()
//                    .onAppear {
//                        viewModel.paginate()
//                    }
//                Spacer()
//            }
//        }
//    }
//    
//    // MARK: - Animation Button
//    
//    /// Controls animation of FloatingButton
//    private let animationController = FloatingButtonController()
//    
//    /// DragGesture for animation FloatingButton on ScrollView dragging
//    private var animationGesture: some Gesture {
//        DragGesture()
//            .onChanged { _ in
//                animationController.delayOnDrag()
//            }
//    }
//    
//    // MARK: - Info
//    
//    @State private var showingInfo = false
//    @State private var infoAlertTitle = ""
//    @State private var infoAlertSubtitle = ""
//    
//    private var infoAlert: some View {
//        CustomAlertContainerView(allowTapDismiss: true, shown: $showingInfo) {
//            InfoAlertView(title: infoAlertTitle, subtitle: infoAlertSubtitle, shown: $showingInfo)
//        }
//    }
//    
//    // MARK: - Loading
//    
//    @State private var showingLoader = false
//    @State private var loaderInfo: String?
//    
//    private var loaderAlert: some View {
//        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
//            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showingLoader)
//        }
//    }
//    
//    // MARK: - Handle Selected Post
//    
//    @State private var selectedPostId: String?
//    @State private var showSelectedPost = false
//    @State private var scrollEventId: String?
//    
//    private var selectedPostDestination: some View {
//        ZStack {
//            if viewModel.posts.first(where: { $0.id == selectedPostId }) != nil {
//                ClubPostDetailsView(postId: selectedPostId!, feedVM: viewModel, scrollToCommentId: scrollEventId)
//                    .equatable()
//                    .onAppear {
//                        // Reset
//                        scrollEventId = nil
//                    }
//            } else {
//                Text("No such post...")
//            }
//        }
//    }
//    
//    // MARK: -
//    
//    struct Constants {
//        static let clubLogoSize: CGFloat = 32
//        static let loaderScale: CGFloat = 2
//        static let feedSpacing: CGFloat = 1
//        static let pagingPadding: CGFloat = 18
//    }
//    
//}
//
//extension ClubFeedView: Equatable {
//    static func == (lhs: ClubFeedView, rhs: ClubFeedView) -> Bool {
//        return lhs.room.id == rhs.room.id
//    }
//}
