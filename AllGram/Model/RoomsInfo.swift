//
//  RoomsInfo.swift
//  AllGram
//
//  Created by Serg Basin on 23.10.2021.
//

import Foundation

// MARK: - RoomsInfo
struct RoomsInfo: Codable {
    let roomsIsDirect: [RoomIsDirect]

    enum CodingKeys: String, CodingKey {
        case roomsIsDirect = "room_is_direct"
    }
}

// MARK: - RoomIsDirect
struct RoomIsDirect: Codable {
    let roomID: String
    let isDirect: Bool // true for chat, false for club
    let dateCreated: Int? // Theoretically should always be, but sometimes don't
    let description: String?

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case isDirect = "is_direct"
        case dateCreated = "date_created"
        case description = "description"
    }
}

// MARK: - DescriptionOfRoom
struct DescriptionOfRoom: Codable {
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case description = "description"
    }
}
