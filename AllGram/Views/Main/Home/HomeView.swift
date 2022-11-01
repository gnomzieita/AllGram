//
//  HomeView.swift
//  AllGram
//
//  Created by Admin on 18.08.2021.
//

import SwiftUI
import Kingfisher
import MatrixSDK

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    //    // iPhone 8+ = top 20 bot 49
    //    // iPhone X  = top 44 bot 83
    //    // -49 for old iPhones | 83 (tab bar) - 17 (safe area) for new iPhones | Cap height 30
    //    static private var panelOffsetFromDevice: CGFloat {
    //        if UIDevice().type.isSquareScreenPhone { return 20 + 49 }
    //        if UIDevice().type.isRoundedScreenPhone { return 44 + 83 }
    //        return 0
    //    }
    //    private let panelClosedOffset: CGFloat = UIScreen.main.bounds.height - FloatingPanel.estimatedCapHeight - HomeView.panelOffsetFromDevice
    //    private let panelOpenOffset: CGFloat = UIScreen.main.bounds.height - FloatingPanel.estimatedHeight - HomeView.panelOffsetFromDevice
    
    // MARK: Closures
    
    var onNeedOpenChat: (_ roomId: String) -> Void
    var onNeedOpenChats: () -> Void
    var onNeedOpenClub: (_ roomId: String) -> Void
    var onNeedOpenClubs: () -> Void
    var onNeedOpenPost: (_ roomId: String, _ postId: String) -> Void
    
    // Navigation bar height is 32
    private func closedPanelOffset(with insets: EdgeInsets) -> CGFloat {
        UIScreen.main.bounds.height - (insets.top + insets.bottom) - FloatingPanel.estimatedCapHeight - TabBarView.Constants.tabBarHeight - 32
    }
    private func openPanelOffset(with insets: EdgeInsets) -> CGFloat {
        UIScreen.main.bounds.height - (insets.top + insets.bottom) - FloatingPanel.estimatedHeight - TabBarView.Constants.tabBarHeight - 32
    }
    // 58 is fixed, 90 may (and slightly will) vary
//    static private let tabBarHeight: CGFloat = UIDevice().type.isSquareScreenPhone ? 58 : 90
    // Start with closed
    @State private var panelArrowUp = true
    @State private var panelCurrentOffset: CGFloat = UIScreen.main.bounds.height
    @State private var showPanel = false
    @GestureState private var panelDragOffset: CGSize = CGSize.zero
    
    @ObservedObject var navManager = NavigationManager.shared
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @State private var showingUserQR = false
    
    @StateObject var notificationsVM = HomeNotificationsViewModel()
    @State var gettingNotifications = true
    @State var clearingNotifications = false
    
    var body: some View {
        ZStack {
            NavigationView {
                TabContentView() {
                    ZStack {
                        content
                            .background(backImage)
                            .sheet(isPresented: $showingUserQR) {
                                NavigationView {
                                    MyQRCodeView()
                                }
                            }
                    }
                    .onAppear() {
                        notificationsVM.actionHandler = { room, eventId in
                            if room.isClub {
                                if let id = eventId {
                                    onNeedOpenPost(room.roomId, id)
                                } else {
                                    onNeedOpenClub(room.roomId)
                                }
                            } else {
                                onNeedOpenChat(room.roomId)
                            }
                        }
                        withAnimation { gettingNotifications = true }
                        notificationsVM.getHomeNotifications(clear: true) { success in
                            withAnimation { gettingNotifications = false }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .ourToolbar(
                    leading:
                        HStack {
                            Button {
                                withAnimation { navManager.showProfile = true }
                            } label: {
                                HStack {
                                    ToolbarImage(.menuBurger)
                                    AvatarImageView(authViewModel.sessionVM?.userAvatarURL, name: authViewModel.sessionVM?.myUser?.displayname ?? "MY")
                                        .frame(width: 32, height: 32)
                                    Text(authViewModel.session?.myUser.displayname ?? "").bold()
                                }
                            }
                        }
                )
            }
            .navigationViewStyle(.stack)
        }
    }
    
    private var content: some View {
        VStack {
            HStack(spacing: 0) {
                Text("ALL NOTIFICATIONS")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    withAnimation { clearingNotifications = true }
                    notificationsVM.clearHomeNotifications { success in
                        withAnimation { clearingNotifications = false }
                    }
                } label: {
                    Text("Clear")
                        .font(.caption)
                        .bold()
                }
                .disabled(clearingNotifications)
            }
            .opacity(notificationsVM.items.isEmpty ? 0 : 1)
            .disabled(notificationsVM.items.isEmpty)
            if !notificationsVM.items.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                        withAnimation { gettingNotifications = true }
                        notificationsVM.getHomeNotifications(clear: false) { success in
                            withAnimation { gettingNotifications = false }
                        }
                    }
                    LazyVStack(spacing: 0) {
                        let count = notificationsVM.items.count
                        let items = (1...count)
                        ForEach(items, id: \.self) { i in
                            let item = notificationsVM.items[i - 1]
                            HomeNotificationView(item)
                                .padding(.vertical, 6)
                            if i < items.upperBound {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .light ? Color.white : Color(hex: "#2C2C2E"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.gray.opacity(0.3))
                    )
                    .padding(.bottom)
                }
                .coordinateSpace(name: "pullToRefresh")
            } else if gettingNotifications || clearingNotifications {
                HStack {
                    Spacer()
                    Spinner()
                        .padding()
                    Spacer()
                }
                    .padding(.top)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                        withAnimation { gettingNotifications = true }
                        notificationsVM.getHomeNotifications(clear: false) { success in
                            withAnimation { gettingNotifications = false }
                        }
                    }
                    noNotificationsView
                    Spacer()
                }
                .coordinateSpace(name: "pullToRefresh")
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
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
    
    @ViewBuilder
    private var widgets: some View {
        VStack {
            // Next up Widget
            NextUpView(
                chats: authViewModel.sessionVM?.chatRooms
                    .filter({ $0.summary.notificationCount > 0 })
                    .map({ room in
                        (room.summary.displayname, Color.random(), { onNeedOpenChat(room.room.roomId) })
                    }) ?? [],
                clubs: authViewModel.sessionVM?.clubRooms
                    .filter({ $0.summary.notificationCount > 0 })
                    .map({ room in
                        (room.summary.displayname, Color.random(), { onNeedOpenClub(room.room.roomId) })
                    }) ?? [],
                tapOnChats: {
                    onNeedOpenChats()
                },
                tapOnClubs: {
                    onNeedOpenClubs()
                }
            )
                .frame(maxHeight: 180)
                .padding(.horizontal, 16)
                .padding(.vertical)
            Spacer()
        }
    }
    
    private var noNotificationsView: some View {
        HStack(spacing: 0) {
            Image("bell")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .foregroundColor(Color(hex: "#219589"))
                .frame(width: 24, height: 24)
                .padding(4)
                .padding(.trailing, 8)
            Text("You don't have any notifications yet")
                .font(.footnote)
                .foregroundColor(.black.opacity(0.87))
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#F4FAF9"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "#000000").opacity(0.12))
        )
    }
    
    
    @ViewBuilder
    private var floatingPanel: some View {
        GeometryReader { geometryProxy in
            FloatingPanel(
                arrowUp: panelArrowUp,
                bottomSpace: 100,
                onNeedOpenRoom: { roomID in
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        if let rooms = authViewModel.sessionVM?.rooms {
                            for room in rooms {
                                if room.room.roomId == roomID {
                                    self.onNeedOpenChat(roomID)
                                }
                            }
                        }
                    }
                }
            )
                .opacity(showPanel ? 1 : 0)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                        panelCurrentOffset = closedPanelOffset(with: geometryProxy.safeAreaInsets)
                        showPanel = true
                    }
                }
                .animation(.easeOut)
                .offset(y: limitPanelOffset(panelCurrentOffset + panelDragOffset.height, geometryProxy: geometryProxy))
                .gesture(
                    DragGesture()
                        .updating($panelDragOffset, body: {
                            value, state, transaction in
                            if (panelCurrentOffset == closedPanelOffset(with: geometryProxy.safeAreaInsets) && value.translation.height <= 0)
                                || (panelCurrentOffset == openPanelOffset(with: geometryProxy.safeAreaInsets) && value.translation.height >= 0) {
                                state = value.translation
                            }
                        })
                        .onEnded({ value in
                            if value.translation.height < -FloatingPanel.estimatedHeight * 0.4 {
                                panelCurrentOffset = openPanelOffset(with: geometryProxy.safeAreaInsets)
                                panelArrowUp = false
                            } else {
                                panelCurrentOffset = closedPanelOffset(with: geometryProxy.safeAreaInsets)
                                panelArrowUp = true
                            }
                        })
                )
        }
    }
    
    private func limitPanelOffset(_ offset: CGFloat, geometryProxy: GeometryProxy) -> CGFloat {
        CGFloat.maximum(CGFloat.minimum(offset, closedPanelOffset(with: geometryProxy.safeAreaInsets)), openPanelOffset(with: geometryProxy.safeAreaInsets))
    }
    
    struct Constants {
        static var offsetProfile: CGFloat = 0
        static var durationOfAnimation: Double = 0.6
    }
    
}
