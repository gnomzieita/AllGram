//
//  NewChatsTabView.swift
//  AllGram
//
//  Created by Alex Pirog on 05.10.2022.
//

import SwiftUI

//struct OurNavigationView<Content: View>: View {
//    private let content: Content
//
//    init(@ViewBuilder contentBuilder: () -> Content) {
//        tabContent = contentBuilder()
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            tabContent
//            TabBarView()
//        }
//        // Keep tab bar at the bottom even if keyboard is up
//        .ignoresSafeArea(.keyboard)
//    }
//}

struct NewChatsTabView: View {
    @ObservedObject var navManager = NavigationManager.shared
    @ObservedObject var sessionVM = AuthViewModel.shared.sessionVM!
    
    @StateObject var viewModel: ChatsTabViewModel
    
    @State var selectedSection: ChatsTabSection
    
    init() {
        let vm = ChatsTabViewModel(sessionVM: AuthViewModel.shared.sessionVM!)
        self._viewModel = StateObject(wrappedValue: vm)
        self._selectedSection = State(initialValue: vm.availableSections.first!)
    }
    
    var body: some View {
        ZStack {
            // Navigation & Content
            NavigationView {
                ZStack {
                    // Navigation layer
                    navigationHelper
                    
                    // Content (with tab bar)
                    TabContentView() {
                        content.simultaneousGesture(animationGesture)
                            .background(backImage)
                            .partialSheet(isPresented: $showSheet) {
                                sheetContent
                            }
                    }
                    .alert(isPresented: $showLeaveAlert) {
                        leaveAlert
                    }
                    .onReceive(navManager.$selectedTab) { tab in
                        // Scroll to top when selected this tab again
                        //guard tab == .chats else { return }
                        //withAnimation { scrollToTop.toggle() }
                    }
                    .onAppear {
                        // Jump to room when needed by navigation
                        guard let id = navManager.chatId,
                              let room = sessionVM.chatRooms.first(where: { $0.roomId == id })
                        else { return }
                        selectedRoom = room
                        showSelected = true
                        navManager.chatId = nil
                    }
                    .onChange(of: navManager.chatId) { id in
                        guard let id = id else { return }
                        selectedRoom = sessionVM.chatRooms.first(where: { $0.roomId == id })
                        showSelected = selectedRoom != nil
                        navManager.chatId = nil
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
                                Text("Chats").bold()
                            }
                        ,
                        trailing:
                            Menu {
                                Button {
                                    withAnimation { showSearch = true }
                                } label: {
                                    MoreOptionView(flat: "Search", imageName: "search-solid")
                                }
                                Button {
                                    sessionVM.chatRooms.forEach() { $0.room.markAllAsRead() }
                                } label: {
                                    MoreOptionView(flat: "Mark all as read", imageName: "check-square-solid")
                                }
                            } label: {
                                ToolbarImage(.menuDots)
                            }
                    )
                    // Button over content
                    NewFloatingButton(
                        controller: animationController,
                        scanQRChatHandler: {
                            showScanQR = true
                        },
                        searchChatHandler: {
                            showCreateChat = true
                        }
                    )
                        .opacity(selectedSection == .meetings ? 0: 1)
                        .disabled(selectedSection == .meetings)
                }
            }
            .navigationViewStyle(.stack)
            .fullScreenCover(isPresented: $showCreateChat) {
                CreateChatView(createdRoomId: $navManager.chatId)
            }
            .fullScreenCover(isPresented: $showScanQR) {
                QRScannerView()
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            // Sections picker
            Picker("", selection: $selectedSection) {
                ForEach(viewModel.availableSections, id: \.self) { section in
                    Text(section.title)
                        .fontWeight(section == selectedSection ? .bold : .regular)
                        .foregroundColor(section == selectedSection ? .textHigh : .textMedium)
                        .lineLimit(1)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .background(Color.allgramMain)
            .accentColor(.white)
            .tint(.red)
            .colorScheme(.dark)
            
            // Chats/meetings
            ScrollView(.vertical, showsIndicators: true) {
                switch selectedSection {
                case .favorites, .lowPriority:
                    let rooms = viewModel.getRooms(for: selectedSection)
                    let chats = rooms.filter { !$0.isMeeting }
                    let meetings = rooms.filter { $0.isMeeting }
                    doubleSectionView(chats, meetings)
                    
                case .chats, .meetings:
                    singleSectionView(viewModel.getRooms(for: selectedSection))
                }
            }
        }
    }
    
    private func singleSectionView(_ rooms: [AllgramRoom]) -> some View {
        ChatRoomsView(
            rooms, focused: $focusedRoom,
            tapHandler: { room in
                // Do not select invites
                if !room.isInvite {
                    selectedRoom = room
                    withAnimation { showSelected = true }
                }
            },
            pressHandler: { room in
                // Do not focus invites
                if !room.isInvite {
                    focusedRoom = room
                    withAnimation { showSheet = true }
                }
            },
            actionHandler: { room in
                // Handle action for invites
                if room.isInvite {
                    selectedRoom = room
                    withAnimation { showSelected = true }
                }
            }
        )
            .padding(.horizontal, Constants.sectionHPadding)
    }
    
    private func doubleSectionView(_ chats: [AllgramRoom], _ meetings: [AllgramRoom]) -> some View {
        VStack(spacing: 0) {
            if !chats.isEmpty {
                HStack {
                    Text("GENERAL CHAT").bold()
                        .font(.caption)
                        .foregroundColor(.textMedium)
                    Spacer()
                }
                .padding(.top, Constants.sectionTitlePadding)
                .padding(.horizontal, Constants.sectionHPadding)
                singleSectionView(chats)
            }
            if !meetings.isEmpty {
                HStack {
                    Text("MEETINGS").bold()
                        .font(.caption)
                        .foregroundColor(.textMedium)
                    Spacer()
                }
                .padding(.top, chats.isEmpty ? Constants.sectionTitlePadding : Constants.sectionTitlePadding - ChatRoomsView.Constants.contentVPadding)
                .padding(.horizontal, Constants.sectionHPadding)
                singleSectionView(meetings)
            }
        }
    }
    
    // MARK: - Sheet options
    
    @State private var focusedRoom: AllgramRoom?
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
            if let room = focusedRoom {
                SheetOptionView(title: "Settings", imageName: "cog-solid") {
                    withAnimation {
                        settingsRoom = room
                        showSettings = true
                        showSheet = false
                    }
                }
                if room.isFavorite {
                    SheetOptionView(title: "Remove from favorites", imageName: "star-solid") {
                        withAnimation {
                            viewModel.markFavorite(true, room: room)
                            showSheet = false
                        }
                    }
                } else {
                    SheetOptionView(title: "Add to favorites", imageName: "star") {
                        withAnimation {
                            viewModel.markFavorite(true, room: room)
                            showSheet = false
                        }
                    }
                }
                if room.isLowPriority {
                    SheetOptionView(title: "Remove from low priority", imageName: "star-solid") {
                        withAnimation {
                            viewModel.markLowPriority(false, room: room)
                            showSheet = false
                        }
                    }
                } else {
                    SheetOptionView(title: "Add to low priority", imageName: "caret-square-down") {
                        withAnimation {
                            viewModel.markLowPriority(true, room: room)
                            showSheet = false
                        }
                    }
                }
                Divider()
                SheetOptionView(title: "Leave the Chat", imageName: "sign-out-alt-solid") {
                    withAnimation {
                        leaveRoom = room
                        showLeaveAlert = true
                        showSheet = false
                    }
                }
                .padding(.bottom)
                .foregroundColor(.red)
            } else {
                // Should never happen, but who knows?
                SheetOptionView(title: "Ops! No such room", imageName: "download-solid") {
                    withAnimation {
                        showSheet = false
                    }
                }
                .padding(.bottom)
                .foregroundColor(.red)
            }
        }
        .onDisappear {
            focusedRoom = nil
        }
    }
    
    // MARK: - Chat Destination
    
    @State private var showSelected = false
    @State private var selectedRoom: AllgramRoom?
    
    @ViewBuilder
    private var roomDestination: some View {
        if let room = selectedRoom {
            ChatContainerView(room: room)
        } else {
            Text("No such room")
                .onAppear { selectedRoom = nil }
        }
    }
    
    // MARK: - Settings Destination
    
    @State private var showSettings = false
    @State private var settingsRoom: AllgramRoom?
    
    @ViewBuilder
    private var settingsDestination: some View {
        if let room = settingsRoom {
            RoomSettingsView(room: room)
        } else {
            Text("No such room")
                .onAppear { showSettings = false }
        }
    }
    
    // MARK: - Navigation
    
    @State private var showSearch = false
    @State private var showCreateChat = false
    @State private var showScanQR = false
    
    private var navigationHelper: some View {
        VStack {
            // Select chat
            NavigationLink(
                destination: roomDestination,
                isActive: $showSelected
            ) {
                EmptyView()
            }
            .onChange(of: showSelected) { show in
                if !show { selectedRoom = nil }
            }
            
            // Select settings
            NavigationLink(
                destination: settingsDestination,
                isActive: $showSettings
            ) {
                EmptyView()
            }
            .onChange(of: showSettings) { show in
                if !show { settingsRoom = nil }
            }
            
            // Search
            NavigationLink(
                destination: SearchChatView(),
                isActive: $showSearch
            ) {
                EmptyView()
            }
        }
    }
    
    // MARK: - Alerts
    
    @State private var showLeaveAlert = false
    @State private var leaveRoom: AllgramRoom?
    
    private var leaveAlert: Alert {
        Alert(
            title: Text("Leave Chat"),
            message: Text("Are you sure you want to leave the chat?\nThis chat is not public. You will not be able to rejoin without an invite."),
            primaryButton:
                    .destructive(Text("Leave"), action: {
                        leaveRoom?.room.leave { _ in }
                        leaveRoom = nil
                    }),
            secondaryButton:
                    .default(Text("Cancel"), action: {
                        leaveRoom = nil
                    })
        )
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
    
    // MARK: -
    
    @ViewBuilder
    private var backImage: some View {
        if SettingsManager.homeBackgroundImageName == nil,
           let customImage = SettingsManager.getSavedHomeBackgroundImage() {
            Image(uiImage: customImage)
                .resizable().scaledToFill()
        } else {
            Image(SettingsManager.homeBackgroundImageName!)
                .resizable().scaledToFill()
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let sectionTitlePadding: CGFloat = 20
        static let sectionHPadding: CGFloat = 16
    }
}
