//
//  UserDefaults.swift
//  NioKit
//
//  Created by Stefan Hofman on 05/09/2020.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import Foundation

public extension UserDefaults {
    private static let appGroup: String = {
        guard let group = Bundle.main.infoDictionary?["AppGroup"] as? String else {
            fatalError("Missing 'AppGroup' key in Info.plist!")
        }
        return group
    }()
  #if os(macOS)
    private static let teamIdentifierPrefix = Bundle.main
      .object(forInfoDictionaryKey: "TeamIdentifierPrefix") as? String ?? ""

    private static let suiteName = teamIdentifierPrefix + appGroup
  #else // iOS
    private static let suiteName = "group." + appGroup
  #endif

    static let group = UserDefaults(suiteName: suiteName)!
}

struct RoomTypeStorage: Codable {
    let roomId: String
    var isChat: Bool
    var isMeeting: Bool
    var chatUpdates: Int
    var meetingUpdates: Int
    
    init(roomId: String, isChat: Bool = true, isMeeting: Bool = false, chatUpdates: Int = 0, meetingUpdates: Int = 0) {
        self.roomId = roomId
        self.isChat = isChat
        self.isMeeting = isMeeting
        self.chatUpdates = chatUpdates
        self.meetingUpdates = meetingUpdates
    }
}

extension UserDefaults {
    private var kRoomTypeStorageKey: String { return "RoomTypeStorageKey" }
    var roomTypeStorage: [RoomTypeStorage] {
        get {
            if let saved = self.object(forKey: kRoomTypeStorageKey) as? Data {
                let decoder = JSONDecoder()
                if let loaded = try? decoder.decode([RoomTypeStorage].self, from: saved) {
                    return loaded
                }
            }
            return []
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                self.set(encoded, forKey: kRoomTypeStorageKey)
            }
        }
    }
    
    func getStoredType(for roomId: String) -> RoomTypeStorage? {
        roomTypeStorage.first(where: { $0.roomId == roomId })
    }
    
    /// Use `forSure` right after creating chat, meeting, club, to avoid inconsistency
    func setStoredType(for roomId: String, isChat: Bool? = nil, isMeeting: Bool? = nil, forSure: Bool = false) {
        var updated = roomTypeStorage
        if let index = updated.firstIndex(where: { $0.roomId == roomId }) {
            // Update old
            if let isChat = isChat {
                updated[index].isChat = isChat
                updated[index].chatUpdates += forSure ? 99 : 1
            }
            if let isMeeting = isMeeting {
                updated[index].isMeeting = isMeeting
                updated[index].meetingUpdates += forSure ? 99 : 1
            }
        } else {
            // Create new
            let new = RoomTypeStorage(
                roomId: roomId,
                isChat: isChat ?? true,
                isMeeting: isMeeting ?? false,
                chatUpdates: forSure ? 99 : 0,
                meetingUpdates: forSure ? 99 : 0
            )
            updated.append(new)
        }
        roomTypeStorage = updated
    }
}

extension UserDefaults {
    private var kStopShowingKeyBackupInfo: String { return "StopShowingKeyBackupInfoKey" }
    var stopShowingKeyBackupInfo: Bool {
        get {
            self.bool(forKey: kStopShowingKeyBackupInfo)
        }
        set {
            self.set(newValue, forKey: kStopShowingKeyBackupInfo)
        }
    }
}
