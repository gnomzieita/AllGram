//
//  APIManager.swift
//  AllGram
//
//  Created by Serg Basin on 23.10.2021.
//

import Foundation
import Combine
import MatrixSDK

//For future handling errors
enum NetworkError: Error, LocalizedError, Identifiable {
    var id: String { localizedDescription }
    case urlError(URLError)
    case responseError(Int, String)
    case decodingError(DecodingError)
    case genericError
    
    var localizedDescription: String {
        switch self {
        case .urlError(let error):
            return error.localizedDescription
        case .responseError(let status, let message):
            let range = (message.range(of: "message\":")?.upperBound
                         ?? message.startIndex)..<message.endIndex
            return "Bad response code: \(status) message : \(message[range])"
        case .decodingError(let error):
            var errorToReport = error.localizedDescription
            
            switch error {
            case .dataCorrupted(let context):
                let details = context.underlyingError?.localizedDescription
                ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorToReport = "\(context.debugDescription) - (\(details))"
            case .keyNotFound(let key, let context):
                let details = context.underlyingError?.localizedDescription
                ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorToReport = "\(context.debugDescription) (key: \(key), \(details))"
            case .typeMismatch(let type, let context), .valueNotFound(let type, let context):
                let details = context.underlyingError?.localizedDescription
                ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorToReport = "\(context.debugDescription) (type: \(type), \(details))"
            @unknown default:
                break
            }
            return  errorToReport
        case .genericError:
            return "An unknown error has been occured"
        }
    }
}

enum MeetingFrequency: String, CaseIterable {
    case never, daily, weekly, monthly
}

enum APNTokenType: String {
    case voip
    case `default`
}

enum ClubRoomType {
    /// Public and unencrypted
    case `public`
    /// Private and unencrypted (not in search)
    case `private`
    /// Private and encrypted (not in search, no history for new users)
    case encrypted
}

enum NotificationsType: String {
    case chat, club, meeting
}

enum ApiType {
    case clubsSearch(userId: String, searchTerm: String)
    
    case getRoomDescription(roomId: String, accessToken: String)
    case setRoomDescription(roomId: String, description: String, accessToken: String)
    
    case createMeetingRoom(roomName: String, userIDList: [String], accessToken: String)
    case createClubRoom(roomName: String, topic: String, type: ClubRoomType, roomAliasName: String, roomDescription: String, accessToken: String)
    case createChatRoom(name: String? = nil, inviteIDs: [String], accessToken: String)
        
    case userAvatar(userId: String, accessToken: String)
    
    case getCustomAvatar(userId: String, accessToken: String)
    case setCustomAvatar(uri: String, userId: String, accessToken: String)
    
    case reportEvent(_ event: MXEvent, score: Int, reason: String?, admins: [String], accessToken: String)
    
    var baseUrl: String { API.server.baseURL }
    
    var port: Int? { API.server.port }
    
    var path: String {
        switch self {
        case .getCustomAvatar(let userId, _), .setCustomAvatar(_, let userId, _):
            return "/_matrix/client/r0/custom-profile/\(userId)/avatar_url"
            
        case .clubsSearch:
            return "/_matrix/client/r0/custom-search"
            
        case .createMeetingRoom, .createClubRoom, .createChatRoom:
            return "/_matrix/client/r0/createRoom"
            
        case .userAvatar(let userId, _):
            return "/_matrix/client/r0/profile/\(userId)/avatar_url"
            
        case .getRoomDescription(let roomId, _):
            return "/_matrix/client/r0/rooms/\(roomId)/state/m.room.description"
            
        case .setRoomDescription(let roomId, _, _):
            return "/_matrix/client/r0/rooms/\(roomId)/state/m.room.description"
            
        case .reportEvent(let event, _, _, _, _):
            return "/_matrix/client/r0/rooms/\(event.roomId!)/report/\(MXTools.encodeURIComponent(event.eventId!)!)"
        }
    }
    
    var method: String {
        switch self {
        case .clubsSearch, .createMeetingRoom, .createClubRoom, .createChatRoom, .reportEvent:
            return "POST"
            
        case .userAvatar,  .getRoomDescription, .getCustomAvatar:
            return "GET"
            
        case .setRoomDescription, .setCustomAvatar:
            return "PUT"
        }
    }
    
    /// Parameter used in `initial_state` to start room with ENABLED encryption
    static let encryptionEvent: [String: Any] = [
        "content": [
            "algorithm": "m.megolm.v1.aes-sha2"
        ],
        "state_key": "",
        "type": "m.room.encryption"
    ]
    
    var httpBody: [String: Any]? {
        switch self {
        case .setCustomAvatar(let uri, _, _):
            return [
                "avatar_url": uri
            ]
            
        case .clubsSearch(_, let searchTerm):
            return [
                "filter": [
                    "generic_search_term": searchTerm
                ]
            ]
            
        case .setRoomDescription(_, let description, _):
            return [
                "description": description
            ]
            
        case .createMeetingRoom(let roomName, let userIDList, _):
            return [
                "creation_content": [
                    "m.federate": false
                ],
                "initial_state": [], // No encryption for now
                "is_meeting": true,
                "invite": userIDList,
                "is_direct": true,
                "visibility": MXRoomDirectoryVisibility.private.identifier,
                "preset": MXRoomPreset.trustedPrivateChat.identifier,
                "name": roomName
            ]
            
        case .createClubRoom(let roomName, let topic, let clubType, let roomAliasName, let roomDescription, _):
            var visibility: String {
                switch clubType {
                case .public:
                    return MXRoomDirectoryVisibility.public.identifier
                case .private:
                    return MXRoomDirectoryVisibility.private.identifier
                case .encrypted:
                    return MXRoomDirectoryVisibility.private.identifier
                }
            }
            var preset: String {
                switch clubType {
                case .public:
                    return MXRoomPreset.publicChat.identifier
                case .private:
                    return MXRoomPreset.privateChat.identifier
                case .encrypted:
                    return MXRoomPreset.trustedPrivateChat.identifier
                }
            }
            var club: [String: Any] = [
                "creation_content": [
                    "m.federate": false
                ],
                "initial_state": clubType == .encrypted ? [ApiType.encryptionEvent] : [],
                "name": roomName,
                "topic": topic,
                "visibility": visibility,
                "preset": preset,
                "is_direct": false
            ]
            if roomAliasName != "" {
                club["room_alias_name"] = roomAliasName
            }
            if roomDescription != "" {
                club["description"] = roomDescription
            }
            return club
            
        case .createChatRoom(let name, let inviteIDs, _):
            var chat: [String: Any] = [
                "creation_content": [
                    "m.federate": false
                ],
                "initial_state": [ApiType.encryptionEvent],
                "invite": inviteIDs,
                "is_direct": true,
                "visibility": MXRoomDirectoryVisibility.private.identifier,
                "preset": MXRoomPreset.trustedPrivateChat.identifier
            ]
            if let chatName = name, chatName != "" {
                chat["name"] = chatName
            }
            return chat
            
        case .reportEvent(let event, let score, let reason, let admins, _):
            var params: [String: Any] = [
                "score": score,
                "content": event.content!
            ]
            if let safeReason = reason, safeReason.hasContent {
                params["reason"] = safeReason
            }
            if !admins.isEmpty {
                params["adminIds"] = admins
            }
            return params
            
        default:
            return nil
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
            
        case .clubsSearch(let userId, let searchTerm):
            return [
                URLQueryItem(name: "userId", value: userId.description),
                URLQueryItem(name: "search_term", value: searchTerm.description)
            ]
            

        default:
            return nil
        }
    }
    
    var headers: [String: String] {
        switch self {
        case .clubsSearch:
            return [:]
            
        case .createMeetingRoom(_, _, let accessToken), .createClubRoom(_, _, _, _, _, let accessToken), .createChatRoom(_, _, let accessToken), .userAvatar(_, let accessToken), .reportEvent(_, _, _, _, let accessToken), .getCustomAvatar(_, let accessToken), .setCustomAvatar(_, _, let accessToken), .getRoomDescription(_, let accessToken), .setRoomDescription(_, _, let accessToken):
            return [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json"
            ]
        }
    }
    
    var request: URLRequest {
        var urlComponents = URLComponents(string: baseUrl)!
        urlComponents.path = path
        urlComponents.port = port
        urlComponents.queryItems = queryItems
        var request = URLRequest(url: (urlComponents.url)!)
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        request.httpMethod = method
        if let httpBody = httpBody {
            let jsonData = try! JSONSerialization.data(withJSONObject: httpBody, options: [])
            request.httpBody = jsonData
        }
        return request
    }
    
}

class ApiManager {
    private var cancels = Set<AnyCancellable>()
    static let shared = ApiManager()
    
    private func fetch<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, Error> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .handleEvents(receiveOutput: { data in
                //print("URLSession.handleEvents request: \(request.url?.path ?? "nil") | data: " + (String(data: data, encoding: .utf8) ?? "none"))
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    /// Returns matrix URI (mxc://...) of the avatar of a given user
    func getUserAvatar(userId: String, accessToken: String) -> AnyPublisher<String?, Never> {
        let request = ApiType.userAvatar(userId: userId, accessToken: accessToken).request
        return fetch(request)
            .map { (response: [String: String]) -> String? in
                return response["avatar_url"]
            }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
    
    // MARK: -

    
    /// Expects `userId` to be in following format: `@example:allgram.me`
    func clubsSearch(userId: String, searchTerm: String) -> AnyPublisher<[Club], Never> {
      let request = ApiType.clubsSearch(userId: userId, searchTerm: searchTerm).request
        return fetch(request)
            .map { (response: ClubsSearch) -> [Club] in
                return response.chunk
            }
            .replaceError(with: [Club]())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Room (Club) Description
    
    func getRoomDescription(roomId: String, accessToken: String) -> AnyPublisher<String?, Error> {
        let request = ApiType.getRoomDescription(roomId: roomId, accessToken: accessToken).request
        return fetch(request)
            .map { (response: [String: String]) -> String? in
                return response["description"]
            }
            .eraseToAnyPublisher()
    }
    
    func setRoomDescription(roomId: String, description: String, accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = ApiType.setRoomDescription(roomId: roomId, description: description, accessToken: accessToken).request
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Creating Rooms
    
    func createChatRoom(name: String? = nil, inviteIDs: [String], accessToken: String) -> AnyPublisher<CreateRoomResponse, Error> {
        let request = ApiType.createChatRoom(name: name, inviteIDs: inviteIDs, accessToken: accessToken).request
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func createClubRoom(roomName: String, topic: String, type: ClubRoomType, roomAliasName: String, roomDescription: String, accessToken: String) -> AnyPublisher<CreateRoomResponse, Error> {
        let request = ApiType.createClubRoom(roomName: roomName, topic: topic, type: type, roomAliasName: roomAliasName, roomDescription: roomDescription, accessToken: accessToken).request
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func createMeetingRoom(meetingName: String, userIDList: [String], accessToken: String) -> AnyPublisher<CreateRoomResponse, Error> {
        let request = ApiType.createMeetingRoom(roomName: meetingName, userIDList: userIDList, accessToken: accessToken).request
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func reportEvent(_ event: MXEvent, score: Int = -100, reason: String? = nil, admins: [String], accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = ApiType.reportEvent(event, score: score, reason: reason, admins: admins, accessToken: accessToken).request
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Custom Avatar
    
    func getCustomAvatar(userId: String, accessToken: String) -> AnyPublisher<String?, Error> {
        let request = ApiType.getCustomAvatar(userId: userId, accessToken: accessToken).request
        return fetch(request)
            .map { (response: [String: String]) -> String? in
                return response["avatar_url"]
            }
            .eraseToAnyPublisher()
    }
    
    func setCustomAvatar(uri: String, userId: String, accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = ApiType.setCustomAvatar(uri: uri, userId: userId, accessToken: accessToken).request
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

}

/// Please, do not use)))
struct TokenResult: Decodable {
    let token: String?
    let refresh_token: String?
}
