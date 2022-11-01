//
//  CallHistoryItem.swift
//  AllGram
//
//  Created by Alex Pirog on 25.07.2022.
//

import Foundation

struct CallHistoryItem: Codable {
    let roomId: String
    let timestamp: Int
    let callerId: String
    let groupCall: Bool
    let videoCall: Bool
    let missed: Bool?
    
    // For 2 users (direct call)
    private let directDisplayName: String?
    private let directAvatarURI: String?
    
    // For 3+ users (group call)
    private let groupRoomName: String?
    private let groupRoomAvatarURI: String?
    
    var callDate: Date { Date(timeIntervalSince1970: TimeInterval(timestamp)) }
    var displayName: String? { directDisplayName ?? groupRoomName }
    var avatarURI: String? { directAvatarURI ?? groupRoomAvatarURI }
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case timestamp = "date"
        case callerId = "call_by"
        case groupCall = "group_call"
        case videoCall = "video"
        // Optional
        case directDisplayName = "displayname"
        case directAvatarURI = "avatar_url"
        case groupRoomName = "room_name"
        case groupRoomAvatarURI = "room_avatar"
        // May be absent for old history
        case missed = "missed"
    }
}

