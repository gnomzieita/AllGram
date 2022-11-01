//
//  HomeNotification.swift
//  AllGram
//
//  Created by Alex Pirog on 31.08.2022.
//

import Foundation

struct HomeNotificationList: Codable {
    let events: [HomeEventNotification]
    let missedCalls: [HomeMissedCallNotification]
    
    var count: Int { events.count + missedCalls.count }
    
    enum CodingKeys: String, CodingKey {
        case events = "event_list"
        case missedCalls = "missed_calls"
    }
    
    static let empty = HomeNotificationList(events: [], missedCalls: [])
}

struct HomeEventNotification: Codable {
    let eventId: String
    let roomId: String
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case roomId = "room_id"
    }
}

struct HomeMissedCallNotification: Codable {
    let callId: Int
    let roomId: String
    let timestamp: Int
    
    var callDate: Date { Date(timeIntervalSince1970: TimeInterval(timestamp)) }
    
    enum CodingKeys: String, CodingKey {
        case callId = "id"
        case roomId = "room_id"
        case timestamp = "date"
    }
}
