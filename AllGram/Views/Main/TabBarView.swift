//
//  TabBarView.swift
//  AllGram
//
//  Created by Alex Pirog on 05.04.2022.
//

import SwiftUI

/// All possible tabs for `TabBarView`
enum Tab: CaseIterable {
    case home, calendar, chats, clubs, calls
    
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .home: return nL10n.Tabs.home
        case .calendar: return nL10n.Tabs.calendar
        case .chats: return nL10n.Tabs.chats
        case .clubs: return nL10n.Tabs.clubs
        case .calls: return nL10n.Tabs.calls
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "home-solid"
        case .calendar: return "calendar-alt-solid"
        case .chats: return "comments"
        case .clubs: return "users-solid"
        case .calls: return "phone-solid"
        }
    }
}

/// Used to wrap other views that need tab bar functionality
struct TabContentView<Content>: View where Content: View {
    private let tabContent: Content
    
    init(@ViewBuilder contentBuilder: () -> Content) {
        tabContent = contentBuilder()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabContent
            TabBarView()
        }
        // Keep tab bar at the bottom even if keyboard is up
        .ignoresSafeArea(.keyboard)
    }
}

/// Custom view to mimic a desired UI for the TabBar.
/// Tied to `NavigationManager` for changing tabs
struct TabBarView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    @ObservedObject var navManager = NavigationManager.shared
    
    private var tabs = [Tab.home, .calendar, .chats, .clubs, .calls]
    
    func isSelected(_ tab: Tab) -> Bool {
        navManager.selectedTab == tab
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(tabs, id: \.iconName) { tab in
                    HStack(spacing: 0) {
                        Spacer()
                        Button {
                            navManager.selectedTab = tab
                        } label: {
                            VStack(spacing: 4) {
                                Image(tab.iconName)
                                    .renderingMode(.template)
                                    .resizable().scaledToFit()
                                    .frame(width: 24, height: 24)
                                Text(tab.localizedTitle)
                                    .fontWeight(isSelected(tab) ? .bold : .thin)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .overlay(getOverlayCounter(for: tab), alignment: .topTrailing)
                        }
                        .foregroundColor(isSelected(tab) ? .accentColor : .textMedium)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .foregroundColor(isSelected(tab) ? .tabBarActive : .clear)
                    )
                }
            }
            .frame(height: Constants.tabBarHeight)
            .background(Color.tabBarBack.ignoresSafeArea())
        }
    }
    
    @ViewBuilder
    private func getOverlayCounter(for tab: Tab) -> some View {
        switch tab {
        case .home:
            EmptyView()
            
        case .calendar:
            EmptyView()
            
        case .chats:
            let count = authViewModel.sessionVM?.unreadChatsCount ?? 0
            if count > 0 { validCounterText(count) }
            
        case .clubs:
            let count = authViewModel.sessionVM?.unreadClubsCount ?? 0
            if count > 0 { validCounterText(count) }
            
        case .calls:
            let count = authViewModel.sessionVM?.missedCallsCount ?? 0
            if count > 0 { validCounterText(count) }
        }
        
        // Preview counters
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"  {
            switch tab {
            case .calls: validCounterText(1)
            case .chats: validCounterText(69)
            case .clubs: validCounterText(999)
            default: EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private func validCounterText(_ counter: Int) -> some View {
        // Use unread count or "..." if more than 99
        Text(counter > 99 ? "..." : "\(counter)")
            .bold()
            .font(.system(size: 9))
            .foregroundColor(.white)
            .frame(width: 16, height: 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.pink)
            )
            .offset(x: 4, y: -4)
    }
    
    // MARK: -
    
    struct Constants {
        static let tabBarHeight: CGFloat = 58
    }
}
