//
//  RedisSearch.swift
//  AllGram
//
//  Created by Serg Basin on 23.10.2021.
//

import Foundation

// MARK: - RedisSearch
struct RedisSearch: Codable {
    let count, limit, offset: Int
    let users: [User]
}

// MARK: - User
struct User: Codable {
    let userID: String
    let displayname: String
    let avatarURL: String?
    let lastSeen: String?
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayname = "displayname"
        case avatarURL = "avatar_url"
        case lastSeen = "last_seen"
        case isOnline = "is_online"
    }
}

// MARK: - Clubs

struct ClubsSearch: Codable {
    let total_room_count_estimate: Int
    let chunk: [Club]
}

/*
 
 "room_id": "!cZhIyVeNSKEzNkxfLe:allgram.me",
 "name": "public club to test media",
 "topic": "media tester",
 "canonical_alias": "#mediatester:allgram.me",
 "num_joined_members": 8,
 "avatar_url": "mxc://allgram.me/BrOLnSrisXwwGxiPquyBieQm",
 "world_readable": false,
 "guest_can_join": false,
 "join_rule": "public"
 
 */

enum JoinRule: String, Codable {
    case `public`
    case `private`
}

struct Club: Codable {
    let roomId: String
    let name: String?
    let topic: String?
    let alias: String?
    let description: String?
    let membersJoined: Int
    let avatarURI: String?
    let joinRule: JoinRule

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case name = "name"
        case topic = "topic"
        case alias = "canonical_alias"
        case description = "description"
        case membersJoined = "num_joined_members"
        case avatarURI = "avatar_url"
        case joinRule = "join_rule"
    }
}

struct GetClubsSearch: BaseRequest {
    var url: URL = API.server.getURLwithPath(path: "/_matrix/client/r0/custom-search")
    var httpMethod: HTTPMethod = .POST
    var queryItems: [String : String]?
    var headers: [String : String]?
    
    typealias ReturnType = [ClubsSearch]
    
    var httpBody: [String: Any]?

    init(userId: String, searchTerm: String) {
        self.httpBody = ["filter": ["generic_search_term": searchTerm]]
        self.queryItems = ["userId":userId,
                            "search_term":searchTerm]
    }
}

