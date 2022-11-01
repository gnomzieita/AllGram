//
//  ChatsView.swift
//  AllGram
//
//  Created by Alex Pirog on 02.05.2022.
//

import SwiftUI

/// General chats tab
struct ChatsView: View {
    @EnvironmentObject var sessionVM: SessionViewModel
    
    @ObservedObject var navManager = NavigationManager.shared
    
    // Toggle to scroll to top
    @State private var scrollToTop = false
    private let favoritesId = "FAVORITES_SECTION"
    private let generalId = "GENERAL_SECTION"
    private let meetingsId = "MEETINGS_SECTION"
    private let lowPriorityId = "LOW_PRIORITY_SECTION"
    
    struct Constants {
        static var offsetProfile: CGFloat = 0
    }
    
    @State private var showChatRoom = false
    @State private var showNewChatCreation = false
    @State private var showChatSearch = false
    
    @State private var showingUserProfile = false
    @GestureState private var profileDragOffset: CGSize = CGSize.zero
    
    /// Used to open specific chat when transitions from widget on home screen
    @Binding var widgetRoomId: String?
    
    /// Internal id of selected chat to show room
    @State var selectedRoomId: String?
    
    var selectedRoom: AllgramRoom? {
        guard let id = selectedRoomId else { return nil }
        return rooms.first(where: { $0.roomId == id })
    }
    
    /// Handles moving between categories
    @ObservedObject private var chatListModel = ChatListModel()
    
    @State var highlightedRoomId: String?
    
    var highlightedRoom: AllgramRoom? {
        guard let id = highlightedRoomId else { return nil }
        return rooms.first(where: { $0.roomId == id })
    }
    
    let rooms: [AllgramRoom]
    
    init(rooms: [AllgramRoom], widgetRoomId: Binding<String?>) {
        self.rooms = rooms
        _widgetRoomId = widgetRoomId
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    // Navigation
                    VStack {
                        NavigationLink(
                            destination: roomDestination,
                            isActive: $showChatRoom
                        ) {
                            EmptyView()
                        }
                        NavigationLink(
                            destination: settingsDestination,
                            isActive: $showChatSettings
                        ) {
                            EmptyView()
                        }
                        NavigationLink(
                            destination: SearchChatView(),
                            isActive: $showChatSearch
                        ) {
                            EmptyView()
                        }
                        NavigationLink(
                            destination: NewStartView(createdRoomId: $selectedRoomId),
                            isActive: $showNewChatCreation
                        ) {
                            EmptyView()
                        }
                    }
                    // Content (with tab bar)
                    TabContentView() {
                        ZStack {
                            content
                                .simultaneousGesture(animationGesture)
                            // Button over content
                            FloatingButton(type: .newChat, controller: animationController) {
                                showNewChatCreation = true
                            }
                        }
                    }
                    .onReceive(navManager.$selectedTab) { tab in
                        // Scroll to top when selected clubs tab again
                        guard tab == .chats else { return }
                        withAnimation { scrollToTop.toggle() }
                    }
                    // Custom alerts
                    if showLeaveAlert { leaveAlert.ignoresSafeArea() }
                }
            }
            .navigationViewStyle(.stack)
            HStack {
                ProfileView()
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
        .onAppear {
            // Check on appear if needed to jump right in chat
            if let id = widgetRoomId {
                selectedRoomId = id
                widgetRoomId = nil
            }
            withAnimation { showChatRoom = selectedRoomId != nil }
        }
        .onChange(of: showChatRoom) { newValue in
            // Clear selected room id when got back from chat room
            if !newValue && selectedRoomId != nil {
                selectedRoomId = nil
            }
        }
        .onChange(of: selectedRoomId) { newValue in
            withAnimation { showChatRoom = newValue != nil }
        }
        .onChange(of: highlightedRoomId) { newValue in
            withAnimation { showSheet = highlightedRoom != nil }
        }
        .partialSheet(isPresented: $showSheet) {
            sheetContent
        }
    }
    
    private var content: some View {
        ScrollViewReader { proxy in
            List {
                if !allOtherRooms.isEmpty {
                    // Should not happen (hopefully)
                    ChatsSectionView(category: .other, rooms: allOtherRooms, selectedRoomId: $selectedRoomId, highlightedRoomId: $highlightedRoomId)
                }
                if !favoriteRooms.isEmpty {
                    ChatsSectionView(category: .favourites, rooms: favoriteRooms, selectedRoomId: $selectedRoomId, highlightedRoomId: $highlightedRoomId)
                        .id(favoritesId)
                }
                if !generalWithInvitedRooms.isEmpty {
                    ChatsSectionView(
                        rooms: generalWithInvitedRooms,
                        selectedRoomId: $selectedRoomId,
                        highlightedRoomId: $highlightedRoomId,
                        categoryTitle: ChatsSectionView.SectionCategory.general.rawValue,
                        allowTap: { id in
                            if invitedRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.invited.allowTap
                            } else if generalRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.general.allowTap
                            } else {
                                return false
                            }
                        },
                        allowLongPress: { id in
                            if invitedRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.invited.allowLongPress
                            } else if generalRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.general.allowLongPress
                            } else {
                                return false
                            }
                        }
                    )
                        .id(generalId)
                }
                if !meetingWithInvitedRooms.isEmpty {
                    ChatsSectionView(
                        rooms: meetingWithInvitedRooms,
                        selectedRoomId: $selectedRoomId,
                        highlightedRoomId: $highlightedRoomId,
                        categoryTitle: ChatsSectionView.SectionCategory.meetings.rawValue,
                        allowTap: { id in
                            if invitedRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.invited.allowTap
                            } else if meetingRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.meetings.allowTap
                            } else {
                                return false
                            }
                        },
                        allowLongPress: { id in
                            if invitedRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.invited.allowLongPress
                            } else if meetingRooms.contains(where: { $0.roomId == id }) {
                                return ChatsSectionView.SectionCategory.meetings.allowLongPress
                            } else {
                                return false
                            }
                        }
                    )
                        .id(meetingsId)
                }
                if !lowPriorityRooms.isEmpty {
                    ChatsSectionView(category: .lowPriority, rooms: lowPriorityRooms, selectedRoomId: $selectedRoomId, highlightedRoomId: $highlightedRoomId)
                        .id(lowPriorityId)
                }
            }
            .padding(.top, 1)
            .background(Color("bgColor").ignoresSafeArea())
            .listStyle(.sidebar)
            .navigationBarTitleDisplayMode(.inline)
            .ourToolbar(
                leading:
                    HStack {
                        Button {
                            withAnimation { showingUserProfile = true }
                        } label: {
                            ToolbarImage(.menuBurger)
                        }
                        Text("Chats").bold()
                    }
                ,
                trailing:
                    HStack {
                        Button {
                            withAnimation { showChatSearch = true }
                        } label: {
                            ToolbarImage(.search)
                        }
                        Menu {
                            Button(action: {
                                sessionVM.chatRooms.forEach() { $0.room.markAllAsRead() }
                            }) {
                                MoreOptionView(flat: "Mark all as read", imageName: "check-square-solid")
                            }
                        } label: {
                            ToolbarImage(.menuDots)
                        }
                    }
            )
            .onChange(of: scrollToTop) { _ in
                if !favoriteRooms.isEmpty {
                    proxy.scrollTo(favoritesId)
                } else if !generalWithInvitedRooms.isEmpty {
                    proxy.scrollTo(generalId)
                } else if !meetingWithInvitedRooms.isEmpty {
                    proxy.scrollTo(meetingsId)
                } else if !lowPriorityRooms.isEmpty {
                    proxy.scrollTo(lowPriorityId)
                } else {
                    // Nothing to scroll to...
                }
            }
        }
    }
    
    @ViewBuilder
    private var roomDestination: some View {
        if let room = selectedRoom {
            ChatContainerView(room: room) {
                selectedRoomId = nil
            }
        } else {
            Text("No such room")
                .onAppear {
                    selectedRoomId = nil
                }
        }
    }
    
    @State private var roomForSettings: AllgramRoom?
    @State private var showChatSettings = false
    
    @ViewBuilder
    private var settingsDestination: some View {
        if let room = roomForSettings {
            RoomSettingsView(room: room)
        } else {
            Text("No such room")
                .onAppear {
                    showChatSettings = false
                }
        }
    }
    
    // MARK: - Sheet
    
    @State private var showSheet = false
    
    struct SheetOptionView: View {
        let title: String
        let imageName: String
        let action: () -> Void
        var body: some View {
            Button(action: { action() }) {
                HStack {
                    Image(imageName)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 12)
                    Text(title)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
        }
    }
    
    private var sheetContent: some View {
        VStack(alignment: .leading) {
            if let room = highlightedRoom {
                SheetOptionView(title: "Settings", imageName: "cog-solid") {
                    withAnimation {
                        roomForSettings = room
                        showChatSettings = true
                        showSheet = false
                    }
                }
                if !chatListModel.isInFavorites(room: room) {
                    SheetOptionView(title: "Add to favorites", imageName: "star") {
                        withAnimation { showSheet = false }
                        chatListModel.moveToFavorites(room: room)
                    }
                }
                if chatListModel.isInFavorites(room: room) || chatListModel.isInLowPriority(room: room) {
                    SheetOptionView(title: "Add to general chats", imageName: "star-solid") {
                        withAnimation { showSheet = false }
                        chatListModel.moveToGeneral(room: room)
                    }
                }
                if !chatListModel.isInLowPriority(room: room) {
                    SheetOptionView(title: "Add to low priority", imageName: "caret-square-down") {
                        withAnimation { showSheet = false }
                        chatListModel.moveToLowPriority(room: room)
                    }
                }
                Divider()
                SheetOptionView(title: "Leave the Chat", imageName: "sign-out-alt-solid") {
                    withAnimation {
                        roomToLeave = highlightedRoom
                        showLeaveAlert = true
                        showSheet = false
                    }
                }
                .padding(.bottom)
                .foregroundColor(.red)
            } else {
                // Should never happen, but who knows?
                SheetOptionView(title: "Ops! No such room", imageName: "download-solid") {
                    withAnimation { showSheet = false }
                }
                .padding(.bottom)
                .foregroundColor(.red)
            }
        }
        .onDisappear {
            // Without animation
            highlightedRoomId = nil
        }
    }
    
    // MARK: - Leave
    
    @State private var roomToLeave: AllgramRoom?
    @State private var showLeaveAlert = false
    
    private var leaveAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showLeaveAlert) {
            ConfirmAlertView(
                title: "Leave Chat",
                subtitle: "Are you sure you want to leave the chat?\n\nThis chat is not public. You will not be able to rejoin without an invite.",
                shown: $showLeaveAlert
            ) { confirmed in
                if confirmed { roomToLeave?.room.leave { _ in } }
                roomToLeave = nil
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
    
}

// MARK: - Rooms by Categories

extension ChatsView {
    
    // MARK: Helper Categories
    
    /// All rooms to which current user is `invited` (chats and meetings)
    private var invitedRooms: [AllgramRoom] {
        rooms.filter { $0.room.summary?.membership == .invite }
    }
    
    /// All rooms to which current user is `join` (chats and meetings)
    private var joinedRooms: [AllgramRoom] {
        rooms.filter { $0.room.summary?.membership == .join }
    }
    
    /// All room that are joined and do not fall under `favorited` or `lowPriority` (not meetings)
    private var generalRooms: [AllgramRoom] {
        joinedRooms.filter { !$0.isMeeting && $0.summary.dataTypes.isDisjoint(with: [.favorited, .lowPriority]) }
    }
    
    /// All rooms that are `meetings` and already joined
    private var meetingRooms: [AllgramRoom] {
        joinedRooms.filter { $0.isMeeting }
    }
    
    // MARK: Used Categories
    
    /// List of invites to chats and then general rooms
    private var generalWithInvitedRooms: [AllgramRoom] {
        invitedRooms.filter { !$0.isMeeting } + generalRooms
    }
    
    /// List of invites to meetings and then meeting rooms
    private var meetingWithInvitedRooms: [AllgramRoom] {
        invitedRooms.filter { $0.isMeeting } + meetingRooms
    }
    
    /// All rooms that are joined and marked as `favorited` (not meetings)
    private var favoriteRooms: [AllgramRoom] {
        joinedRooms.filter { !$0.isMeeting && $0.summary.dataTypes.contains(.favorited) }
    }
    
    /// All rooms that are joined and marked as `lowPriority` (not meetings)
    private var lowPriorityRooms: [AllgramRoom] {
        joinedRooms.filter { !$0.isMeeting && $0.summary.dataTypes.contains(.lowPriority) }
    }
    
    /// All other rooms that were not filtered to other categories (should be empty)
    private var allOtherRooms: [AllgramRoom] {
        let other = rooms.filter { room in
            return !favoriteRooms.contains(where: { $0.room.roomId == room.room.roomId })
            && !generalWithInvitedRooms.contains(where: { $0.room.roomId == room.room.roomId })
            && !meetingWithInvitedRooms.contains(where: { $0.room.roomId == room.room.roomId })
            && !lowPriorityRooms.contains(where: { $0.room.roomId == room.room.roomId })
        }
        return other
    }
    
}
