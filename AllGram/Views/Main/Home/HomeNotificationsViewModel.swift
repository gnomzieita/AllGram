//
//  HomeNotificationsViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 31.08.2022.
//

import Foundation
import Combine
import MatrixSDK

struct HomeNotificationItem {
    let eventId: String
    let isDeletable: Bool
    let avatarURL: URL?
    let displayName: String
    let notificationTitle: String
    let notificationSubtitle: String
    let notificationTime: Date
    let actionTitle: String
    let actionHandler: () -> Void
    let deleteHandler: () -> Void
}

class HomeNotificationsViewModel: ObservableObject {
    private var getCancellable: AnyCancellable?
    private var clearCancellable: AnyCancellable?
    private var removeCancellableSet = Set<AnyCancellable>()
    
    @Published private(set) var list = HomeNotificationList.empty {
        didSet { listToItems() }
    }
    
    @Published private(set) var items = [HomeNotificationItem]()
    
    /// Array of all events and calls that are being removed (swiped).
    /// Used to filter out those ones right away, not waiting for completion
    @Published private(set) var removingEventIds = [String]() {
        didSet { listToItems() }
    }
    
    /// Will be added to all items as handler of actions.
    /// When can redirect to specific event - will also provide `eventId`
    var actionHandler: ((_ room: AllgramRoom, _ eventId: String?) -> Void)?

    init() {
        // Listen for matrix sync, as we may got list events
        // before we actually synched that events to device
        NotificationCenter.default.addObserver(self, selector: #selector(updateOnSync), name: .mxSessionDidSync, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        getCancellable?.cancel()
        getCancellable = nil
        clearCancellable?.cancel()
        clearCancellable = nil
        removeCancellableSet.removeAll()
    }

    @objc
    private func updateOnSync() {
        guard list.count != items.count + removingEventIds.count else { return }
        listToItems()
    }
    
    private func listToItems() {
        var newItems = [HomeNotificationItem]()
        // Handle events
        for event in list.events {
            // Exclude locally deleting events
            guard !removingEventIds.contains(event.eventId) else { continue }
            
            // Continue only for locally available events
            guard let room = AuthViewModel.shared.sessionVM?.room(with: event.roomId),
                  let event = room.event(withEventId: event.eventId)
            else { continue }
            var text = "\(event.type ?? "nil")"
            var action = "Action"
            var deletable = true
            if event.type == kMXEventTypeStringRoomMember {
                let inviteType = room.isClub ? "club" : (room.isMeeting ? "meeting" : "chat")
                text = "You are invited to a \(inviteType)"
                action = "Accept"
                deletable = false
            } else if event.type == kMXEventTypeStringRoomMessage {
                switch event.messageType {
                case .image:
                    text = "Image"
                case .video:
                    text = "Video"
                case .audio:
                    text = "Audio"
                case .file:
                    text = "File"
                case .text:
                    text = ChatTextMessageView.Model.init(event: event).message
                default:
                    text = "New message"
                }
                action = room.isClub ? "Discover" : "Reply"
            } else {
                // Do not use unknown events
                //print("[H] event: \(event.content)")
                continue
            }
            let item = HomeNotificationItem(
                eventId: event.eventId,
                isDeletable: deletable,
                avatarURL: room.realAvatarURL,
                displayName: room.displayName,
                notificationTitle: room.displayName,
                notificationSubtitle: text,
                notificationTime: event.timestamp,
                actionTitle: action,
                actionHandler: { [weak self] in
                    self?.actionHandler?(room, event.eventId)
                },
                deleteHandler: { [weak self] in
                    self?.removeHomeNotification(eventId: event.eventId)
                }
            )
            newItems.append(item)
        }
        // Handle missed calls
        for call in list.missedCalls {
            let callEventId = "\(call.callId)"
            
            // Exclude locally deleting calls
            guard !removingEventIds.contains(callEventId) else { continue }
            
            // Continue only for locally available calls
            guard let room = AuthViewModel.shared.sessionVM?.room(with: call.roomId)
            else { continue }
            let item = HomeNotificationItem(
                eventId: callEventId,
                isDeletable: true,
                avatarURL: room.realAvatarURL,
                displayName: room.displayName,
                notificationTitle: room.displayName,
                notificationSubtitle: "Missed call",
                notificationTime: call.callDate,
                actionTitle: "Show",
                actionHandler: { [weak self] in
                    self?.actionHandler?(room, nil)
                },
                deleteHandler: { [weak self] in
                    self?.removeHomeNotification(eventId: callEventId)
                }
            )
            newItems.append(item)
        }
        // Sort for recent first
        items = newItems.sorted { $0.notificationTime > $1.notificationTime }
    }
    
    // MARK: - Public
    
    func getHomeNotifications(clear: Bool, completion: ((_ success: Bool) -> Void)? = nil) {
        getCancellable?.cancel()
        if clear { list = HomeNotificationList.empty }
        let accessToken = AuthViewModel.shared.sessionVM!.accessToken
        getCancellable = NewApiManager.shared.getHomeNotifications(accessToken: accessToken)
            .sink { result in
                switch result {
                case .finished:
                    break
                case .failure:
                    completion?(false)
                }
            } receiveValue: { [weak self] list in
                self?.list = list
                completion?(true)
            }
    }
    
    func removeHomeNotification(eventId: String) {
        guard !removingEventIds.contains(eventId) else { return }
        removingEventIds.append(eventId)
        let accessToken = AuthViewModel.shared.sessionVM!.accessToken
        NewApiManager.shared.deleteHomeNotification(eventId: eventId, accessToken: accessToken)
            .sink { [weak self] success in
                guard success else {
                    // Remove this id if FAILED so it will be back in the list
                    if let i = self?.removingEventIds.firstIndex(of: eventId) {
                        self?.removingEventIds.remove(at: i)
                    }
                    return
                }
                // Reload on success, and remove this id on any reload result
                self?.getHomeNotifications(clear: false) { _ in
                    if let i = self?.removingEventIds.firstIndex(of: eventId) {
                        self?.removingEventIds.remove(at: i)
                    }
                }
            }
            .store(in: &removeCancellableSet)
    }
    
    func clearHomeNotifications(completion: ((_ success: Bool) -> Void)? = nil) {
        clearCancellable?.cancel()
        let accessToken = AuthViewModel.shared.sessionVM!.accessToken
        clearCancellable = NewApiManager.shared.clearHomeNotifications(accessToken: accessToken)
            .sink { [weak self] success in
                guard success else {
                    completion?(false)
                    return
                }
                self?.getHomeNotifications(clear: true, completion: completion)
            }
    }
}
