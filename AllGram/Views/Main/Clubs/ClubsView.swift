//
//  ClubsView.swift
//  AllGram
//
//  Created by Igor Antonchenko on 01.02.2022.
//

import SwiftUI
import Combine
import Kingfisher
import MatrixSDK

struct ClubsView: View {
    @ObservedObject var navManager = NavigationManager.shared
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @StateObject var combinedFeedVM: NewCombinedFeedViewModel
    
    private var feedManager = FeedPositionManager()
    
    @State private var deletingPost: NewClubPost?
    @State private var showCreateClub = false
    @State private var showSearch = false
        
    /// Used to open specific club feed when transitions from widget on home screen
    @Binding var widgetRoomId: String?
    
    @Binding var widgetPostId: String?
    
    // Toggle to scroll to top
    @State private var scrollToTop = false
    private let topObjectId = "TOP"
    
    init(widgetRoomId: Binding<String?>, widgetPostId: Binding<String?>) {
        self._widgetRoomId = widgetRoomId
        self._widgetPostId = widgetPostId
        self._combinedFeedVM = StateObject(wrappedValue: NewCombinedFeedViewModel(clubRooms: AuthViewModel.shared.sessionVM?.clubRooms ?? []))
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    // Navigation
                    VStack {
                        NavigationLink(
                            destination: selectedPostDestination,
                            isActive: $showSelectedPost
                        ) {
                            EmptyView()
                        }
                        NavigationLink(
                            destination: selectedClubDestination,
                            isActive: $showSelectedClub
                        ) {
                            EmptyView()
                        }
                        NavigationLink(
                            destination: createdClubDestination,
                            isActive: $goToCreatedClubFeed
                        ) {
                            EmptyView()
                        }
                        NavigationLink(
                            destination: SearchClubsView(viewModel: authViewModel.clubSearcher),
                            isActive: $showSearch
                        ) {
                            EmptyView()
                        }
                    }
                    // Content (with tab bar)
                    TabContentView() {
                        ZStack {
                            combinedClubsFeed
                                .simultaneousGesture(animationGesture)
                            // Button over content
                            FloatingButton(type: .newClub, controller: animationController) {
                                showCreateClub = true
                            }
                            .sheet(isPresented: $showCreateClub) {
                                AddClubView(
                                    session: authViewModel.session,
                                    successHandler: { id in
                                        createdClubRoomId = id
                                        goToCreatedClubFeed = true
                                    },
                                    failureHandler: { error in
                                        failureText = error.localizedDescription
                                        showingFailure = true
                                    }
                                )
                            }
                        }
                    }
                    // Custom Alerts
                    if showingLoader { loaderAlert }
                    if showingFailure { failureAlert }
                }
                .onReceive(navManager.$selectedTab) { tab in
                    // Scroll to top when selected clubs tab again
                    guard tab == .clubs else { return }
                    withAnimation { scrollToTop.toggle() }
                }
                .onChange(of: showSelectedClub) { newValue in
                    if !newValue && selectedClubId != nil {
                        selectedClubId = nil
                    }
                }
                .onChange(of: selectedClubId) { value in
                    withAnimation { showSelectedClub = value != nil }
                }
                .onChange(of: showSelectedPost) { newValue in
                    if !newValue && selectedPostId != nil {
                        selectedPostId = nil
                    }
                }
                .onChange(of: selectedPostId) { value in
                    withAnimation { showSelectedPost = value != nil }
                }
                .onAppear {
                    // Go to club feed if needed from widget
                    if let id = widgetRoomId {
                        createdClubRoomId = id
                        goToCreatedClubFeed = true
                        widgetRoomId = nil
                    }
                    // Do async to get it work properly
                    DispatchQueue.main.async {
                        feedManager.allowPlaying = true
                    }
                }
                .onDisappear {
                    feedManager.allowPlaying = false
                }
                .alert(item: $deletingPost) { post in
                    Alert(title: Text("Remove"),
                          message: Text("Are you sure want to delete this post?"),
                          primaryButton: .destructive(
                            Text("Remove"),
                            action: {
                                loaderInfo = "Deleting post and removing it from feed."
                                withAnimation { showingLoader = true }
                                combinedFeedVM.delete(post: post) {
                                    withAnimation { showingLoader = false }
                                }
                            }
                          ),
                          secondaryButton: .cancel()
                    )
                }
                .navigationBarTitleDisplayMode(.inline)
                .ourToolbar(
                    leading:
                        HStack {
                            Button {
                                withAnimation { navManager.showProfile = true }
                            } label: {
                                ToolbarImage(.menuBurger)
                            }
                            Text("Clubs").bold()
                        }
                    ,
                    trailing:
                        HStack {
                            Button {
                                withAnimation { showSearch = true }
                            } label: {
                                ToolbarImage(.search)
                            }
                        }
                )
            }
            .navigationViewStyle(.stack)
        }
    }
    
    private var clubsTopStack: some View {
        HStack(spacing: 4) {
            // Static button for my clubs
            NavigationLink(destination: MyClubsView( viewModel: authViewModel.myClubsVM)) {
                TopClubView(
                    username: authViewModel.session?.myUser.displayname ?? "MY",
                    avatarURL: authViewModel.sessionVM?.userAvatarURL
                )
            }
            // Dynamic clubs list
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    // Invited first
                    ForEach(combinedFeedVM.invitedToClubs) { room in
                        NavigationLink(
                            destination:
                                NewClubFeedView(room: room)
                                .equatable()
                        ) {
                            TopClubView(
                                name: room.displayName ?? "???",
                                avatarURL: room.realAvatarURL,
                                isInvite: true,
                                hasUnreadContent: room.hasUnreadContent
                            )
                        }
                    }
                    // Joined later
                    ForEach(combinedFeedVM.joinedClubs) { room in
                        NavigationLink(
                            destination:
                                NewClubFeedView(room: room)
                                .equatable()
                        ) {
                            TopClubView(
                                name: room.summary.displayname ?? "nil",
                                avatarURL: room.realAvatarURL,
                                isInvite: false,
                                hasUnreadContent: room.hasUnreadContent
                            )
                        }
                    }
                }
            }
        }
        .frame(height: TopClubView.Constants.estimatedHeight)
        .padding(.leading, 6)
        .padding(.vertical, 6)
        .background(Color(Constants.backgroundColor))
    }
    
    private var combinedClubsFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                // Clubs stack at the top
                Divider().id(topObjectId)
                clubsTopStack
                Divider()
                // Clubs feed below if there is any posts
                if !combinedFeedVM.combinedPosts.isEmpty {
                    LazyVStack(spacing: Constants.feedSpacing) {
                        ForEach(combinedFeedVM.combinedPosts.reversed(), id: \.id) { post in
                            let positionManager = feedManager.createManager(for: post.id)
                            let feed = combinedFeedVM.findFeed(by: post.clubRoomId)!
                            NewFeedPostView(
                                post: post,
                                feedVM: feed,
                                maxMediaHeight: UIScreen.main.bounds.height / 2,
                                positionManager: positionManager,
                                checkClub: {
                                    selectedClubId = post.clubRoomId
                                },
                                checkContent: {
                                    selectedPostId = post.id
                                },
                                likePost: {
                                    combinedFeedVM.handleReaction(post: post)
                                },
                                commentPost: {
                                    selectedPostId = post.id
                                },
                                deletePost: {
                                    deletingPost = post
                                }
                            )
                                .accentColor(.reverseColor)
                                .background(Color(Constants.backgroundColor))
                            Divider()
                        }
                        Spacer()
                        if combinedFeedVM.expectsMorePosts {
                            HStack(spacing: Constants.pagingPadding) {
                                ProgressView()
                                Text("Loading more posts...")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.gray)
                            .padding()
                            .onAppear {
                                combinedFeedVM.paginate()
                            }
                        }
                    }
                } else {
                    Text("No posts yet")
                        .foregroundColor(.gray)
                        .padding()
                        .onAppear {
                            combinedFeedVM.paginate()
                        }
                    Spacer()
                }
            }
            .onFrameChange({ frame in
                feedManager.feedFrame = frame
            }, enabled: true)
            .background(Color("bgColor").ignoresSafeArea())
            .onChange(of: scrollToTop) { _ in
                proxy.scrollTo(topObjectId)
            }
        }
    }
    
    // MARK: - Animation Button
    
    /// Controls animation of FloatingButton
    private let animationController = FloatingButtonController()
    
    /// DragGesture for animation FloatingButton on ScrollView dragging
    private var animationGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                animationController.delayOnDrag()
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
    
    // MARK: - Failure
    
    @State private var showingFailure = false
    @State private var failureText: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: "Failed to create new club." + (failureText == nil ? "" : "\n\(failureText!)"), shown: $showingFailure)
        }
    }
    
    // MARK: - Handle Selected Post
    
    @State private var selectedPostId: String?
    @State private var showSelectedPost = false
    
    private var selectedPostDestination: some View {
        ZStack {
            if let post = combinedFeedVM.findPost(by: selectedPostId ?? "nil"),
               let feed = combinedFeedVM.findFeed(by: post.clubRoomId)
            {
                NewClubPostView(post: post, feedVM: feed, scrollToCommentId: post.id)
//                    .equatable()
            } else {
                Text("No such post...")
                    .onAppear {
                        selectedPostId = nil
                    }
            }
        }
    }
    
    // MARK: - Handle Selected Club
    
    @State private var selectedClubId: String?
    @State private var showSelectedClub = false
    
    private var selectedClubDestination: some View {
        ZStack {
            if let room = combinedFeedVM.clubRooms.first(where: { $0.roomId == selectedClubId }) {
                NewClubFeedView(room: room)
                .equatable()
            } else {
                Text("No such club...")
                    .onAppear {
                        selectedClubId = nil
                    }
            }
        }
    }
    
    // MARK: - Handle Create Club
    
    @State private var createdClubRoomId: String?
    @State private var goToCreatedClubFeed = false
    
    private var createdClubDestination: some View {
        ZStack {
            if let newId = createdClubRoomId, let room = authViewModel.sessionVM?.clubRooms.first(where: { $0.room.roomId == newId }) {
                NewClubFeedView(room: room)
            } else {
                Text("No such club...")
                    .onAppear {
                        createdClubRoomId = nil
                    }
            }
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let clubLogoSize: CGFloat = 32
        static let loaderScale: CGFloat = 2
        static let pagingPadding: CGFloat = 18
        static let feedSpacing: CGFloat = 1
        static let backgroundColor: String = "clubsBackground"
    }
}
