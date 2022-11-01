//
//  MainTabView.swift
//  AllGram
//
//  Created by Admin on 18.08.2021.
//

import SwiftUI
import Combine
import Kingfisher

class NavigationManager: ObservableObject {
    /// Change to show/hide user profile view sliding from the left
    @Published var showProfile = false
    
    /// Change to select any of the available tabs
    @Published var selectedTab = Tab.home
    
    /// Change to room id for opening chat (meeting)
    @Published var chatId: String?
    
    /// Change to room id for opening club
    @Published var clubId: String?
    
    /// Change to event id for opening post (in a club)
    @Published var postId: String?
    
    static let shared = NavigationManager()
    private init() { }
}

struct MainTabView: View {
    // We use this as shared objects as sometimes, just sometimes,
    // on released apps, it loses @EnvironmentObject and crashes.
    // It `IS` better than passing those as .environmentObject()
    // again and again to all children, just to ensure availability
    @ObservedObject var navManager = NavigationManager.shared
    @ObservedObject var callHandler = CallHandler.shared
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    @StateObject var backupVM: NewKeyBackupViewModel
    @StateObject var keyBackupInfoListener: KeyBackupInfoListener
    
    @ObservedObject var sessionVM: SessionViewModel
    
    init(_ sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
        
        let bVM = NewKeyBackupViewModel(backupService: KeyBackupService(crypto: AuthViewModel.shared.session!.crypto))
        self._backupVM = StateObject(wrappedValue: bVM)
        
        let bListener = KeyBackupInfoListener(backupVM: bVM)
        self._keyBackupInfoListener = StateObject(wrappedValue: bListener)
    }
    
    var body: some View {
        ZStack {
            ZStack {
                tabContent
                callOverlay
            }
            
            // User profile sliding from the left side of the screen
            profileOverlay
            
            // Recover session stuff
            if showRestoreAlert { restoreAlert }
            // Show backupless info alert
            if keyBackupInfoListener.showAlert { keyBackupInfoAlert }
        }
        .environment(\.userId, sessionVM.myUserId)
        .environmentObject(backupVM)
        .environmentObject(sessionVM)
        .onChange(of: backupVM.state) { state in
            // Show alert when we have unverified backup AND to skipped it yet
            if case .unverifiedBackup = state, !skippedRestore {
                withAnimation { showRestoreAlert = true }
            }
        }
        .onChange(of: keyBackupInfoListener.showAlert) { showAlert in
            if showAlert {
                // Hide keyboard when showing large alert
                self.hideKeyboard()
            }
        }
        .onAppear {
            backupVM.updateState { _ in }
            sessionVM.updateMissed()
        }
        .sheet(isPresented: $showRecovery) {
            NavigationView {
                ManageBackupView(backupVM)
                    .ourToolbar(
                        leading:
                            Button {
                                skippedRestore = true
                                showRestoreAlert = false
                                withAnimation { showRecovery = false }
                            } label: {
                                Text("Close")
                            }
                    )
            }
        }
        .fullScreenCover(isPresented: $callHandler.isShownOutgoingAcceptance) {
            OutgoingAcceptanceView()
        }
        .fullScreenCover(isPresented: $callHandler.isShownIncomingAcceptance) {
            IncomingAcceptanceView()
        }
        .fullScreenCover(isPresented: $callHandler.isShownIncomingSecondAcceptance) {
            IncomingSecondCallView()
        }
        .fullScreenCover(isPresented: $callHandler.isShownCallView) {
            CallView() { id in
                withAnimation {
                    pipLocation = MainTabView.pipOriginalLocation
                    callHandler.isShownCallView = false
                    navManager.chatId = id
                    navManager.selectedTab = .chats
                }
            }
        }
        .fullScreenCover(isPresented: $callHandler.isShownJitsiCallView) {
            JitsiCallView()
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch navManager.selectedTab {
        case .home:
            HomeView(
                onNeedOpenChat: { roomId in
                    // Open chats only when there is such a room
                    if let room = sessionVM.chatRooms.first(where: { $0.roomId == roomId }) {
                        if room.summary.membership == .invite {
                            // No need to accept invite, just show tab
                            navManager.chatId = roomId
                            navManager.selectedTab = .chats
                        } else {
                            navManager.chatId = roomId
                            navManager.selectedTab = .chats
                        }
                    } else {
                        navManager.chatId = nil
                    }
                },
                onNeedOpenChats: {
                    navManager.selectedTab = .chats
                },
                onNeedOpenClub: { roomId in
                    // Open clubs only when there is such a room
                    if let room = sessionVM.clubRooms.first(where: { $0.roomId == roomId }) {
                        if room.summary.membership == .invite {
                            // No need to accept invite, just show tab
                            navManager.clubId = roomId
                            navManager.selectedTab = .clubs
                        } else {
                            navManager.clubId = roomId
                            navManager.selectedTab = .clubs
                        }
                    } else {
                        navManager.clubId = nil
                    }
                },
                onNeedOpenClubs: {
                    navManager.selectedTab = .clubs
                },
                onNeedOpenPost: { roomId, postId in
                    // Open clubs only when there is such a room
                    if let room = sessionVM.clubRooms.first(where: { $0.roomId == roomId }) {
                        navManager.postId = postId
                        if room.summary.membership == .invite {
                            // No need to accept invite, just show tab
                            navManager.clubId = roomId
                            navManager.selectedTab = .clubs
                        } else {
                            navManager.clubId = roomId
                            navManager.selectedTab = .clubs
                        }
                    } else {
                        navManager.clubId = nil
                        navManager.postId = nil
                    }
                }
            )
            
        case .calendar:
            CalendarTabView(
                onNeedOpenChat: { roomId in
                    // Open chats only when there is such a room
                    if let room = sessionVM.chatRooms.first(where: { $0.room.roomId == roomId }) {
                        if room.summary.membership == .invite {
                            // No need to accept invite, just show tab
                            navManager.chatId = roomId
                            navManager.selectedTab = .chats
                        } else {
                            navManager.chatId = roomId
                            navManager.selectedTab = .chats
                        }
                    } else {
                        navManager.chatId = nil
                    }
                },
                onNeedOpenChats: {
                    navManager.selectedTab = .chats
                }
            )
            
        case .chats:
            NewChatsTabView()
//                        ChatsView(rooms: sessionVM.chatRooms, widgetRoomId: $navManager.chatId)
            
        case .clubs:
            ClubsView(
                widgetRoomId: $navManager.clubId,
                widgetPostId: $navManager.postId
            )
            
        case .calls:
            CallsTabView()
        }
    }
    
    @ViewBuilder
    private var callOverlay: some View {
        // Moveable jitsi call view
        if callHandler.isShownMinimizedJitsiCallView {
            moveableView
        }
        
        // Moveable PIP direct video call view
        if callHandler.isVideoCall(viewKind: .call) && !callHandler.isShownCallView {
            // Background just in case
            ZStack {
                Rectangle()
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("PIP")
                    .font(.largeTitle)
            }
            .frame(width: 120, height: 120)
            .position(pipLocation)
            
            // Actual video view
            VideoView(isRemote: true)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .position(pipLocation)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            withAnimation {
                                pipLocation = gesture.location
                            }
                        }
                )
                .onTapGesture {
                    callHandler.isShownCallView = true
                }
        }
    }
    
    // MARK: - User Profile
    
    @GestureState private var profileDragOffset: CGSize = CGSize.zero
    
    private var profileOverlay: some View {
        HStack {
            ProfileView()
                .background(
                    Color(ProfileView.Constants.backgroundBottom)
                        .edgesIgnoringSafeArea(.bottom)
                        .offset(x: 0, y: 300)
                )
                .gesture(
                    DragGesture()
                        .updating($profileDragOffset, body: { value, state, transaction in
                            if value.translation.width < 0 {
                                state = value.translation
                            }
                        })
                        .onEnded({ value in
                            if value.translation.width < 0 && value.translation.width <=  -UIScreen.main.bounds.width/3 {
                                navManager.showProfile.toggle()
                            }
                        })
                )
                .animation(.easeInOut)
                .offset(x: navManager.showProfile ? profileDragOffset.width : -UIScreen.main.bounds.width, y: 0)
            Spacer()
        }
        .background(
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .opacity(navManager.showProfile ? 1 : 0)
                .animation(.easeInOut)
                .onTapGesture {
                    navManager.showProfile.toggle()
                }
        )
    }
    
    // MARK: - Restore Session Stuff
    
    @State private var skippedRestore = false
    @State private var showRestoreAlert = false
    @State private var showRecovery = false
    
    private var restoreAlert: some View {
        VStack {
            VStack(spacing: 0) {
                Text("The previous session has ended or you have created a new account. Please use your recovery key to decrypt the content or create a new key.")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.top)
                HStack {
                    Button {
                        skippedRestore = true
                        withAnimation {
                            showRestoreAlert = false
                        }
                    } label: {
                        ExpandingHStack() {
                            Text("CLOSE").bold()
                                .foregroundColor(Color("lightPurple"))
                                .padding(.vertical)
                        }
                    }
                    Button {
                        withAnimation {
                            showRestoreAlert = false
                            showRecovery = true
                        }
                    } label: {
                        ExpandingHStack() {
                            Text("USE KEY BACKUP").bold()
                                .foregroundColor(Color("lightPurple"))
                                .padding(.vertical)
                        }
                    }
                }
            }
            .background(
                Rectangle()
                    .foregroundColor(.black)
                    .opacity(0.8)
                    .ignoresSafeArea()
            )
            Spacer()
        }
        .transition(.move(edge: .top))
    }
    
    // MARK: - Key Backup Info
    
    private var keyBackupInfoAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $keyBackupInfoListener.showAlert) {
            VStack {
                Text("Key Backup Information")
                    .font(.title)
                    .padding(.vertical, 6)
                Text("allgram cares about your security and uses the principle of encrypted messaging. This means that your messages will only be viewable during the active session. If the active session ends, you log out of your account or delete the application and do not create a decryption key, it will be impossible to recover the message!")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Toggle("Don't show this alert again", isOn: $keyBackupInfoListener.stopShowing)
                    .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                    .padding(.vertical, 4)
                Divider()
                HStack(spacing: 0) {
                    Button {
                        withAnimation { keyBackupInfoListener.showAlert = false }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text("Cancel").bold()
                                .foregroundColor(.accentColor)
                        }
                    }
                    Divider()
                    Button {
                        withAnimation {
                            keyBackupInfoListener.showAlert = false
                            showRecovery = true
                        }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text("Generate Key").bold()
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .frame(height: 32)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(.backColor)
            )
        }
    }
    
    // MARK: - PIP for Direct Video Call
    
    static private let pipOriginalLocation = CGPoint(x: UIScreen.main.bounds.width - 80, y: 120)
    @State private var pipLocation = pipOriginalLocation
    
    // MARK: - Moveable
    
    @State private var savedMoveableArea = CGRect.zero
    @State private var startingOffset = CGPoint.zero
    @State private var offset = CGPoint.zero
    @State private var boundsForOffset = CGRect.zero
    
    @State private var isDragging = false
    @State private var needCheckTap = false
    
    private var moveableView : some View {
        GeometryReader { geometry in
            let area = geometry.frame(in: .global)
            let smallRect = calculateRectSize(area: area)
            
            AdaptedJitsiView(model: JitsiCallModel.shared)
                .frame(width: smallRect.width, height: smallRect.height, alignment: .center)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged({ value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let pt = CGPoint(x: startingOffset.x + dx, y: startingOffset.y + dy)
                    if boundsForOffset.contains(pt) {
                        offset = pt
                    }
                    isDragging = true
                }).onEnded({ value in
                    startingOffset = offset
                    isDragging = false
                    if needCheckTap {
                        needCheckTap = false
                        let dx = value.translation.width
                        let dy = value.translation.height
                        let q = dx * dx + dy * dy
                        if q == 0 {
                            exitPip()
                        }
                    }
                }))
                .simultaneousGesture(TapGesture().onEnded({ _ in
                    if isDragging {
                        needCheckTap = true
                    } else {
                        exitPip()
                    }
                }))
                .foregroundColor(.blue)
                .border(Color.gray, width: 1)
                .animation(.none)
                .position(x: offset.x, y: offset.y)
        }
    }
    
    private func exitPip() {
        callHandler.isShownMinimizedJitsiCallView = false
        callHandler.isShownJitsiCallView = true
    }
    
    private func calculateRectSize(area: CGRect) -> CGSize {
        let w = round(area.width * 0.30)
        let h = round(area.height * 0.25)
        let size = CGSize(width: w, height: h)
        if area == savedMoveableArea { return size }
        DispatchQueue.main.async {
            self.savedMoveableArea = area
            self.boundsForOffset = area //.insetBy(dx: round(0.3 * w), dy: round(0.3 * h))
            let x0 = area.midX
            let y0 = area.midY
            self.startingOffset = CGPoint(x: x0, y: y0)
            self.offset = self.startingOffset
        }
        return size
    }
    
}

//struct MainTabView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainTabView(userId: UUID().uuidString)
//            .colorScheme(.dark)
//            .previewDevice("iPhone 11")
//        MainTabView(userId: UUID().uuidString)
//            .colorScheme(.light)
//            .previewDevice("iPhone 8 Plus")
//    }
//}
 
