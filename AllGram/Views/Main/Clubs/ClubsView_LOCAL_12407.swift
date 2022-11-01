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
    @ObservedObject var authViewModel = AuthViewModel.shared
    @ObservedObject var viewModel: CombinedClubsFeedViewModel
    
    private var feedManager = FeedPositionManager()
    
    @State private var deletingPost: ClubPost?
    @State private var showCreateClub = false
    @State private var showingUserProfile = false
    @State private var showSearch = false
    
    @GestureState private var profileDragOffset: CGSize = CGSize.zero
    
    /// Used to open specific club feed when transitions from widget on home screen
    @Binding var widgetRoomId: String?
    
    init(viewModel: CombinedClubsFeedViewModel, widgetRoomId: Binding<String?>) {
        self.viewModel = viewModel
        _widgetRoomId = widgetRoomId
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
                            VStack(spacing: 0) {
                                // Clubs stack at the top
                                clubsTopStack
                                Divider()
                                // Clubs feed below
                                combinedClubsFeed
                                    .simultaneousGesture(animationGesture)
                            }
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
                .onChange(of: selectedClubId) { value in
                    withAnimation { showSelectedClub = value != nil }
                }
                .onChange(of: selectedPostId) { value in
                    withAnimation { showSelectedPost = value != nil }
                }
                .onAppear {
                    viewModel.updatePosts()
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
                                viewModel.delete(post: post) {
                                    viewModel.updatePosts()
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
                                withAnimation { showingUserProfile = true }
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
            HStack {
                ProfileView(
                    displayName: authViewModel.session?.myUser.displayname ?? "noname",
                    nickname: authViewModel.session?.myUser.userId.components(separatedBy: ":").first ?? "@none",
                    profilePhotoURL: authViewModel.userAvatarURL
                )
                    .background(
                        Color(ProfileView.Constants.backgroundBottom)
                            .edgesIgnoringSafeArea(.bottom)
                            .offset(x: 0, y: 300)
                    )
                    .gesture(
                        DragGesture()
                            .updating($profileDragOffset, body: {value, state, transaction in
                                if value.translation.width < 0 {
                                    state = value.translation
                                }
                            })
                            .onEnded({ value in
                                if value.translation.width < 0 && value.translation.width <=  -UIScreen.main.bounds.width/3 {
                                    showingUserProfile = !showingUserProfile
                                }
                            })
                    )
                    .animation(.easeInOut)
                    .offset(x: showingUserProfile ? Constants.offsetProfile + profileDragOffset.width: -UIScreen.main.bounds.width, y: 0)
                Spacer()
                
            }
            .background(Color.black.opacity(0.6)
                            .ignoresSafeArea()
                            .opacity(showingUserProfile ? 1 : 0)
                            .animation(.easeInOut)
                            .onTapGesture {
                showingUserProfile = !showingUserProfile
            })
        }
    }
    
    private var clubsTopStack: some View {
        HStack(spacing: 4) {
            // Static button for my clubs
            NavigationLink(destination: MyClubsView( viewModel: authViewModel.myClubsVM)) {
                TopClubView(
                    username: authViewModel.session?.myUser.displayname ?? "MY",
                    avatarURL: authViewModel.userAvatarURL
                )
            }
            // Dynamic clubs list
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    // Invited first
                    ForEach(viewModel.invitedToClubs) { room in
                        NavigationLink(
                            destination:
                                ClubFeedView(room: room) {
                                    viewModel.updatePosts()
                                }
                                .equatable()
                        ) {
                            TopClubView(
                                name: room.summary.displayname ?? "nil",
                                avatarURL: room.realAvatarURL,
                                isInvite: true,
                                hasUnreadContent: room.hasUnreadContent
                            )
                        }
                    }
                    // Joined later
                    ForEach(viewModel.joinedClubs) { room in
                        NavigationLink(
                            destination:
                                ClubFeedView(room: room) {
                                    viewModel.updatePosts()
                                }
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
        ScrollView(.vertical) {
            // Feed if there is any posts
            if !viewModel.combinedPosts.isEmpty {
                LazyVStack(spacing: Constants.feedSpacing) {
                    ForEach(viewModel.combinedPosts.reversed(), id: \.id) { post in
                        let positionManager = feedManager.createManager(for: post)
                        ClubPostView(
                            post: post,
                            maxMediaHeight: UIScreen.main.bounds.height / 2,
                            positionManager: positionManager,
                            checkClub: {
                                selectedClubId = post.clubRoomId
                            },
                            checkContent: {
                                selectedPostId = post.id
                            },
                            likePost: {
                                if post.isLicked {
                                    viewModel.unlike(post: post) {
                                        // Delay the update
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            viewModel.updatePosts()
                                        }
                                    }
                                } else {
                                    viewModel.like(post: post) {
                                        // Delay the update
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            viewModel.updatePosts()
                                        }
                                    }
                                }
                            },
                            commentPost: {
                                selectedPostId = post.id
                            },
                            viewComments: {
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
                    if viewModel.expectsMorePosts {
                        HStack(spacing: Constants.pagingPadding) {
                            ProgressView()
                            Text("Loading more posts...")
                                .font(.subheadline)
                        }
                        .foregroundColor(.gray)
                        .padding()
                        .onAppear {
                            viewModel.paginate()
                        }
                    }
                }
            } else {
                Text("No posts yet")
                    .foregroundColor(.gray)
                    .padding()
                    .onAppear {
                        viewModel.paginate()
                    }
                Spacer()
            }
        }
        .onFrameChange({ frame in
            feedManager.feedFrame = frame
        }, enabled: true)
        .background(Color("bgColor").ignoresSafeArea())
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
            if let clubPost = viewModel.combinedPosts
                .first(where: { $0.id == selectedPostId }),
               let postFeed = viewModel.individualFeedVMs
                .first(where: { $0.room.room.roomId == clubPost.clubRoomId }),
               let postRoom = viewModel.clubRooms
                .first(where: { $0.room.roomId == clubPost.clubRoomId })
            {
                ClubPostDetailsView(postId: selectedPostId!, feedVM: postFeed)
                    .equatable()
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
            if let room = viewModel.clubRooms.first(where: { $0.roomId == selectedClubId }) {
                ClubFeedView(room: room) {
                    viewModel.updatePosts()
                }
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
            if let newId = createdClubRoomId, let room = authViewModel.clubRooms.first(where: { $0.room.roomId == newId }) {
                ClubFeedView(room: room) {
                    createdClubRoomId = nil
                }
                .equatable()
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
        static var offsetProfile: CGFloat = 0
    }
}

extension ClubsView: Equatable {
    static func == (lhs: ClubsView, rhs: ClubsView) -> Bool {
        lhs.viewModel == rhs.viewModel
    }
}
