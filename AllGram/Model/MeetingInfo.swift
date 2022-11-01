//
//  MeetingsInfo.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 20.01.2022.
//

import Foundation

struct MeetingInfo: Codable, Identifiable, Equatable {
    let id: String
    let summary: String
    let description: String?
    let frequency: String
    let roomID: String
    
    /// Ids of all participants of the meeting, excluding the creator to `creator` when getting all meetings
    let attendees: [String]
    
    /// Id of the creator, excluded from `attendees`.  Available only when getting all meetings
    let creator: String?
    
    private let dateStart: String
    private let dateEnd: String
    
    var startDate: Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        // Convert from UTC time on server to local
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.date(from: dateStart)!
    }
    
    var endDate: Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        // Convert from UTC time on server to local
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.date(from: dateEnd)!
    }

    enum CodingKeys: String, CodingKey {
        case id = "uid"
        case summary = "summary"
        case description = "description"
        case dateStart = "dtstart"
        case dateEnd = "dtend"
        case frequency = "frequency"
        case roomID = "room_id"
        case attendees = "attendees"
        case creator = "creator"
    }
}
