//
//  ChatsItemContainerView.swift
//  AllGram
//
//  Created by Alex Pirog on 03.05.2022.
//

import SwiftUI
import MatrixSDK

/// Wrapper for chat row view, handles invites and room updates
struct ChatsItemContainerView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    @ObservedObject var room: AllgramRoom
    
    let highlighted: Bool
    
    init(room: AllgramRoom, highlighted: Bool) {
        self.room = room
        self.highlighted = highlighted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ChatsItemView(room: room, updates: tUpdater.updates + nUpdater.updates)
                    .padding(.vertical, 6)
                if room.invitedByUserId != nil {
                    inviteOptions
                        .padding(.top, 4)
                        .padding(.bottom, 10)
                }
            }
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(
                        highlighted ? Color.gray.opacity(0.5) : Color.clear
                    )
            )
            Divider()
        }
        .onAppear { startUpdating() }
        .onDisappear { stopUpdating() }
        // Fix buttons inside List (allow interaction inside table row)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var inviteOptions: some View {
        HStack {
            Spacer()
            Button(action: { authViewModel.sessionVM?.leave(from: room.room) }) {
                Text("Reject")
                    .font(.subheadline)
                    .padding(.all, 6)
                    .frame(width: UIScreen.main.bounds.width * 0.3)
            }
            Button(action: { authViewModel.sessionVM?.join(to: room.room) }) {
                Text("ACCEPT")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.all, 6)
                    .frame(width: UIScreen.main.bounds.width * 0.3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.allgramMain)
                    )
            }
        }
    }
    
    // MARK: - Updates
    
    @StateObject private var tUpdater = TimedUpdater()
    @StateObject private var nUpdater = NotificationUpdater()
    
    private var updateTime: TimeInterval {
        let time = abs(room.summary.lastMessageDate.timeIntervalSinceNow)
        if time < .minute {
            return .second
        } else if time < .hour {
            return .minute
        } else {
            return .hour
        }
    }
    
    private func startUpdating() {
        // Update on timer
        tUpdater.updateHandler = {
            tUpdater.issueUpdate(in: updateTime)
        }
        tUpdater.issueUpdate(in: .second)
        // Notifications just to reset timer
        nUpdater.updateChecker = { notification in
            if let summary = notification.object as? MXRoomSummary {
                if summary.roomId == room.roomId {
                    tUpdater.issueUpdate(in: .second)
                }
            }
            return false
        }
        nUpdater.updateOnNotification(name: .mxRoomSummaryDidChange)
    }
    
    private func stopUpdating() {
        tUpdater.updateHandler = nil
        tUpdater.invalidate()
        nUpdater.updateChecker = nil
        nUpdater.stopNotificationUpdates()
    }
    
}
