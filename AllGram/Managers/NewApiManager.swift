//
//  NewApiManager.swift
//  AllGram
//
//  Created by Alex Agarkov on 26.07.2022.
//

import Foundation
import Combine

enum NewApiManagerRequestError: LocalizedError, Equatable {
    case invalidRequest
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case error4xx(_ code: Int)
    case serverError
    case error5xx(_ code: Int)
    case decodingError
    case urlSessionFailed(_ error: URLError)
    case unknownError
}


class NewApiManager {
    static let shared = NewApiManager()
    
    private func fetch<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, Error> {
        let DataTask = URLSession.shared.dataTaskPublisher(for: request)
        
        return DataTask
            .map { $0.data }
            .handleEvents(receiveOutput: { data in
                //print("URLSession.handleEvents request: \(request.url?.path ?? "nil") | data: " + (String(data: data, encoding: .utf8) ?? "none"))
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
            
    }
    
    private func request(url: URL, queryItems: [String: String]?, headers: [String: String]?, httpMethod: HTTPMethod, httpBody: [String: Any]?) -> URLRequest {
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return URLRequest(url: (url))
        }
        
        var qItems: [URLQueryItem] = []
        if let tQueryItems = queryItems  {
            for item in tQueryItems {
                qItems.append(URLQueryItem(name: item.key, value: item.value))
            }
        }
        urlComponents.queryItems = qItems
        
        var request = URLRequest(url: (urlComponents.url)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tHeaders = headers {
            for header in tHeaders {
                request.addValue(header.value, forHTTPHeaderField: header.key)
            }
        }

        request.httpMethod = httpMethod.rawValue
        if let httpBody = httpBody {
            let jsonData = try! JSONSerialization.data(withJSONObject: httpBody, options: [])
            request.httpBody = jsonData
        }
        return request
    }
    
    // MARK: -
    
    /// Returns `true` when version is OK and `false` when needs update.
    /// Expects a valid format of version with build and dev/prod separation
    func checkForUpdates(version: String) -> AnyPublisher<Bool?, Never> {
        let request = self.checkForUpdatesRequest(version: version)
        return fetch(request)
            .map { (response: [String: Bool]) -> Bool in
                return response["status"]!
            }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
    
    func roomIsMeeting(roomId: String) -> AnyPublisher<Bool?, Never> {
        let request = self.getRoomIsMeetingRequest(roomId: roomId)
        return fetch(request)
            .map { (response: [String: Bool]) -> Bool in
                return response["is_meeting"] ?? false
            }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
    
    func getRoomsInfo(roomsIds: [String]) -> AnyPublisher<[RoomIsDirect], Never> {
        let request = self.getRoomsInfoRequest(ids: roomsIds)
        return fetch(request)
            .map { (response: RoomsInfo) -> [RoomIsDirect] in
                return response.roomsIsDirect
            }
            .replaceError(with: [RoomIsDirect]())
            .eraseToAnyPublisher()
    }
    
    func redisSearch(searchRequest: String, fromUserId: String, limit: Int, offset: Int) -> AnyPublisher<[User], Never> {
        let request = self.getRedisSearchRequest(searchRequest: searchRequest, fromUserId: fromUserId, limit: limit, offset: offset)
        return fetch(request)
            .map { (response: RedisSearch) -> [User] in
                return response.users
            }
            .replaceError(with: [User]())
            .eraseToAnyPublisher()
    }
    
    /// Do not mistaken with MXRoom.isDirect as this one is our custom
    /// (named the same) to distinguish between chats (`true`) and clubs (`false`)
    func roomIsDirect(roomId: String) -> AnyPublisher<Bool?, Never> {
        let request = self.getRoomIsDirectRequest(roomId: roomId)
        return fetch(request)
            .map { (response: [String: Bool]) -> Bool in
                return response["is_direct"]!
            }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
    
    func getMeetings(startDate: Date, endDate: Date, accessToken: String) -> AnyPublisher<[MeetingInfo], Error> {
        let request = self.getMeetingsRequest(startDate: startDate, endDate: endDate, accessToken: accessToken)
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func createMeetingEvent(eventName: String, startDate: Date, endDate: Date, frequency: MeetingFrequency, userIDList: [String], roomID: String, accessToken: String) -> AnyPublisher<MeetingInfo, Error> {
        let request = self.getAddMeetingEventRequest(startDate: startDate, endDate: endDate, summary: eventName, description: nil, frequency: frequency, userIDList: userIDList, roomID: roomID, accessToken: accessToken)
        return fetch(request)
            .eraseToAnyPublisher()
    }

    func registerAPNToken(_ token: String, type: APNTokenType, accessToken: String) -> AnyPublisher<TokenResult, Error> {
        let request = self.getRegisterApnTokenRequest(token: token, type: type, accessToken: accessToken)
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func unregisterAPNToken(_ token: String, type: APNTokenType, accessToken: String) -> AnyPublisher<TokenResult, Error> {
        let request = self.getUnregisterApnTokenRequest(token: token, type: type, accessToken: accessToken)
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func getNotificationSettings(accessToken: String) -> AnyPublisher<[String: Bool?], Error> {
        let request = self.getNotificationSettingsRequest(accessToken: accessToken)
        return fetch(request)
            .map { (response: [String: Bool?]) -> [String: Bool?] in
                return response
            }
            .eraseToAnyPublisher()
    }
    
    func updateNotificationSettings(_ value: Bool,_ type: NotificationsType, accessToken: String) -> AnyPublisher<String, Error> {
        let request = self.getUpdateNotificationSettingsRequest(value, type, accessToken: accessToken)
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Call History
    
    func getMissedCalls(accessToken: String) -> AnyPublisher<Int, Never> {
        let request = self.getMissedCallsRequest(accessToken: accessToken)
        return fetch(request)
            .map { (response: [String: Int]) -> Int in
                return response["missed_calls"] ?? 0
            }
            .replaceError(with: 0)
            .eraseToAnyPublisher()
    }
    
    func getCallHistory(accessToken: String) -> AnyPublisher<[CallHistoryItem], Error> {
        let request = self.getCallHistoryRequest(accessToken: accessToken)
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func clearCallHistory(accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = self.getClearCallHistoryRequest(accessToken: accessToken)
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    func recordCalling(roomId: String, isVideo: Bool, accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = self.getRecordCallingRequest(roomId: roomId, isVideo: isVideo, accessToken: accessToken)
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 201 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    func recordAnswering(roomId: String, accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = self.getRecordAnsweringRequest(roomId: roomId, accessToken: accessToken)
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 201 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Home Notifications
    
    func getHomeNotifications(accessToken: String) -> AnyPublisher<HomeNotificationList, Error> {
        let request = self.getHomeNotificationsRequest(accessToken: accessToken)
        return fetch(request)
            .eraseToAnyPublisher()
    }
    
    func deleteHomeNotification(eventId: String, accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = self.getDeleteHomeNotificationRequest(eventId: eventId, accessToken: accessToken)
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    func clearHomeNotifications(accessToken: String) -> AnyPublisher<Bool, Never> {
        let request = self.getClearHomeNotificationsRequest(accessToken: accessToken)
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { ($0.response as? HTTPURLResponse)?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

extension NewApiManager {
    
    /// Checks if there is new version available.
    /// Expects `version` to be in 1.0.1-dev or 1.0.1-prod style
    private func checkForUpdatesRequest(version: String) -> URLRequest {
        let queryItems = ["version": version, "os": "ios"]
        return request(url: ServerRoadMap().getCheckVersionUrl(), queryItems: queryItems, headers: nil, httpMethod: .POST, httpBody: nil)
    }
    
    //roomIsMeetingRequest(roomId: String)
    private func getRoomIsMeetingRequest(roomId: String) -> URLRequest {
        let queryItems = ["room_id": roomId]
        return request(url: ServerRoadMap().getRoomIsMeetingUrl(), queryItems: queryItems, headers: nil, httpMethod: .GET, httpBody: nil)
    }
    
    private func getRoomsInfoRequest(ids: [String]) -> URLRequest {
        let httpBody: [String: Any] = ["room_ids": ids]
        return request(url: ServerRoadMap().getRoomInfoUrl(), queryItems: nil, headers: nil, httpMethod: .POST, httpBody: httpBody)
    }
    
    private func getRedisSearchRequest(searchRequest: String, fromUserId: String, limit: Int, offset: Int) -> URLRequest {
        let queryItems =  [
            "limit": limit.description,
            "offset": offset.description,
            "user_id": fromUserId.description,
            "search_term": searchRequest.description
        ]
        return request(url: ServerRoadMap().getRedisSearchUrl(), queryItems: queryItems, headers: nil, httpMethod: .GET, httpBody: nil)
    }
    
    private func getRoomIsDirectRequest(roomId: String) -> URLRequest {
        let queryItems =  ["room_id": roomId]
        return request(url: ServerRoadMap().getRoomIsDirectUrl(), queryItems: queryItems, headers: nil, httpMethod: .GET, httpBody: nil)
    }
    
    private func getMeetingsRequest(startDate: Date, endDate: Date, accessToken: String) -> URLRequest {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        // Convert local time to UTC on server
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        let queryItems =  [
            "start": dateFormatter.string(from: startDate),
            "end": dateFormatter.string(from: endDate)
        ]
        
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        
        return request(url: ServerRoadMap().getCalendarEventsUrl(), queryItems: queryItems, headers: headers, httpMethod: .GET, httpBody: nil)
    }
    
    private func getAddMeetingEventRequest(startDate: Date, endDate: Date, summary: String, description: String?, frequency: MeetingFrequency, userIDList: [String], roomID: String, accessToken: String) -> URLRequest {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        // Convert local time to UTC on server
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        var event: [String: Any] = [
            "date_start": dateFormatter.string(from: startDate),
            "date_end": dateFormatter.string(from: endDate),
            "summary": summary,
            "frequency": frequency.rawValue,
            "attendees": userIDList,
            "room_id": roomID
        ]
        if let text = description, text != "" {
            event["description"] = text
        }
        
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        
        return request(url: ServerRoadMap().getCalendarEventsUrl(), queryItems: nil, headers: headers, httpMethod: .POST, httpBody: event)
    }

    func getRegisterApnTokenRequest(token: String, type: APNTokenType, accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        let httpBody: [String: Any] = [
            "registration_token": token,
            "token_type": type.rawValue
        ]
        print(httpBody)
        return request(url: ServerRoadMap().getNotificationSubscribeUrl(), queryItems: nil, headers: headers, httpMethod: .POST, httpBody: httpBody)
    }

    func getUnregisterApnTokenRequest(token: String, type: APNTokenType, accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        let httpBody: [String: Any] = [
            "registration_token": token,
            "token_type": type.rawValue
        ]
        
        return request(url: ServerRoadMap().getNotificationUnsubscribeUrl(), queryItems: nil, headers: headers, httpMethod: .POST, httpBody: httpBody)
    }
    
    private func getNotificationSettingsRequest(accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        return request(url: ServerRoadMap().getNotificationSettingsUrl(), queryItems: nil, headers: headers, httpMethod: .GET, httpBody: nil)
    }
    
    private func getUpdateNotificationSettingsRequest(_ value: Bool ,_ type: NotificationsType, accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        return request(url: ServerRoadMap().getNotificationSettingsUrl(), queryItems: nil, headers: headers, httpMethod: .POST, httpBody: [type.rawValue: value])
    }
    
    // MARK: - Call History
    
    private func  getMissedCallsRequest(accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        let queryItems: [String: String] = ["only_missed": "1"]
        return request(url: ServerRoadMap().getCallHistoryUrl(), queryItems: queryItems, headers: headers, httpMethod: .GET, httpBody: nil)
    }
    
    private func getCallHistoryRequest(accessToken: String) -> URLRequest {
        // Will also reset missed calls counter
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        return request(url: ServerRoadMap().getCallHistoryUrl(), queryItems: nil, headers: headers, httpMethod: .GET, httpBody: nil)
    }
    
    private func getClearCallHistoryRequest(accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        return request(url: ServerRoadMap().getCallHistoryUrl(), queryItems: nil, headers: headers, httpMethod: .DELETE, httpBody: nil)
    }
    
    private func getRecordCallingRequest(roomId: String, isVideo: Bool, accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        let body: [String: Any] = ["room_id": roomId, "video": isVideo]
        return request(url: ServerRoadMap().getCallHistoryUrl(), queryItems: nil, headers: headers, httpMethod: .POST, httpBody: body)
    }
    
    private func getRecordAnsweringRequest(roomId: String, accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        let body: [String: Any] = ["room_id": roomId]
        return request(url: ServerRoadMap().getCallHistoryUrl(), queryItems: nil, headers: headers, httpMethod: .PATCH, httpBody: body)
    }
    
    // MARK: - Home Notifications
    
    private func getHomeNotificationsRequest(accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        return request(url: ServerRoadMap().getHomeNotificationsUrl(), queryItems: nil, headers: headers, httpMethod: .GET, httpBody: nil)
    }
    
    private func getDeleteHomeNotificationRequest(eventId: String, accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        let body: [String: Any] = ["event_id": eventId]
        return request(url: ServerRoadMap().getHomeNotificationsUrl(), queryItems: nil, headers: headers, httpMethod: .PUT, httpBody: body)
    }
    
    private func getClearHomeNotificationsRequest(accessToken: String) -> URLRequest {
        let headers: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        return request(url: ServerRoadMap().getHomeNotificationsUrl(), queryItems: nil, headers: headers, httpMethod: .DELETE, httpBody: nil)
    }
}
