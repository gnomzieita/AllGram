//
//  CalendarTabView.swift
//  AllGram
//
//  Created by Alex Pirog on 16.08.2022.
//

import SwiftUI

struct CalendarTabView: View {
    var onNeedOpenChat: (_ roomId: String) -> Void
    var onNeedOpenChats: () -> Void
    
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
    
    @State private var showCreateMeeting = false
    
    @StateObject var viewModel = MeetingsViewModel()
    
    @State private var showNewScheduledMeeting = false
    @State private var showNewInstantMeeting = false
    
    var body: some View {
        ZStack {
            NavigationView {
                TabContentView() {
                    ZStack {
                        // Force light scheme and accent color
                        content
                            .colorScheme(.light)
                            .accentColor(.allgramMain)
                            .background(backImage)
                            .simultaneousGesture(animationGesture)
                    }
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
                            Text("Calendar").bold()
                        }
                    )
            }
            .navigationViewStyle(.stack)
            // Button over content
            NewFloatingButton(
                controller: animationController,
                regularMeetingHandler: {
                    showNewScheduledMeeting = true
                },
                instantMeetingHandler: {
                    showNewInstantMeeting = true
                }
            )
        }
        .fullScreenCover(isPresented: $showNewScheduledMeeting) {
            CreateMeetingView(forInstant: false)
        }
        .fullScreenCover(isPresented: $showNewInstantMeeting) {
            CreateMeetingView(forInstant: true)
        }
    }
    
    @State var updater = 0
    
    private var content: some View {
        VStack(spacing: 0) {
            CalendarContainerView(
                selectedDate: $viewModel.selectedDate,
                eventDates: viewModel.eventDates,
                allowPastDates: true,
                calendar: viewModel.calendar,
                updater: $updater
            )
                .equatable()
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(
                    IndividuallyRoundedRectangle(
                        bottomLeft: 16,
                        bottomRight: 16
                    )
                        .foregroundColor(.backColor)
                        .shadow(radius: 2)
                )
                .onChange(of: viewModel.eventDates) { _ in
                    // We need to increment this to redraw calendar
                    // when calendar is the same, but we got events
                    updater += 1
                }
            ScrollView(.vertical, showsIndicators: false) {
                PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                    viewModel.update()
                }
                LazyVStack {
                    ForEach(viewModel.selectedMeetings) { meeting in
                        if let room = authViewModel.sessionVM?.chatRooms.first(where: { $0.roomId == meeting.roomID }) {
                            MeetingView(meeting: meeting) {
                                onNeedOpenChat(room.roomId)
                            }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading),
                                    removal: .move(edge: .trailing)
                                ))
                        } else {
                            MeetingView(meeting: meeting, joinHandler: nil)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading),
                                    removal: .move(edge: .trailing)
                                ))
                        }
                    }
                    Spacer()
                    if viewModel.selectedMeetings.isEmpty {
                        noEventsView
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading),
                                removal: .move(edge: .trailing)
                            ))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 80)
            }
            .coordinateSpace(name: "pullToRefresh")
        }
    }
    
    private var noEventsView: some View {
        HStack(spacing: 0) {
            Image("calendar-alt-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .foregroundColor(Color(hex: "#219589"))
                .frame(width: 24, height: 24)
                .padding(4)
                .padding(.trailing, 8)
            Text("No events")
                .font(.footnote)
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "#000000").opacity(0.12))
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#F4FAF9"))
        )
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
            // Calendar Widget
            CalendarView(onMeetingTap: onNeedOpenChat)
                .frame(maxHeight: 210)
                .padding(.horizontal, 16)
                .padding(.vertical)
            Spacer()
        }
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
    
    struct Constants {
        static var offsetProfile: CGFloat = 0
        static var durationOfAnimation: Double = 0.6
    }
    
}
