//
//  ServerRoadMap.swift
//  AllGram
//
//  Created by Alex Agarkov on 26.07.2022.
//

import Foundation

class ServerRoadMap {
    
    //let MatrixBaseURL: URL = API.server.getURL() ?? URL(string: "")!
    private let AllGramBaseURL: URL = API.identityServer.getURL() ?? URL(string: "")!
    
    private func getApiUrl() -> URL {
        return AllGramBaseURL.appendingPathComponent("/api")
    }
    
    func getCheckVersionUrl() -> URL {
        return getApiUrl().appendingPathComponent("/check-version")
    }
    
    func getRoomInfoUrl() -> URL {
        return getApiUrl().appendingPathComponent("/room-info")
    }
    
    func getRoomIsDirectUrl() -> URL {
        return getApiUrl().appendingPathComponent("/room-is-direct")
    }
    
    func getRoomIsMeetingUrl() -> URL {
        return getApiUrl().appendingPathComponent("/room-is-meeting")
    }
    
    func getRedisSearchUrl() -> URL {
        return getApiUrl().appendingPathComponent("/redis-search")
    }
    
    private func getNotificationUrl() -> URL {
        return getApiUrl().appendingPathComponent("/notification")
    }
    
    func getCallHistoryUrl() -> URL {
        return getApiUrl().appendingPathComponent("/call-history")
    }
    
    func getHomeNotificationsUrl() -> URL {
        return getApiUrl().appendingPathComponent("/show-last-events")
    }
    
    func getNotificationSubscribeUrl() -> URL {
        return getNotificationUrl().appendingPathComponent("/ios/subscribe")
    }
    
    func getNotificationUnsubscribeUrl() -> URL {
        return getNotificationUrl().appendingPathComponent("/ios/unsubscribe")
    }
    
    func getNotificationSettingsUrl() -> URL {
        return getNotificationUrl().appendingPathComponent("/settings")
    }
    
    func getCalendarEventsUrl() -> URL {
        return AllGramBaseURL.appendingPathComponent("/calendar/default_calendar/events")
    }
}
