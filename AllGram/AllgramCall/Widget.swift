//
//  Widget.swift
//  AllGram
//
//  Created by Vladyslav on 15.12.2021.
//

import Foundation
import MatrixSDK

class Widget {
    private(set) var widgetId : String
    private(set) var type: String?
    private(set) var url: String?
    private(set) var name: String?
    private(set) var data: [String : Any]?
    private(set) var widgetEvent: MXEvent
    private(set) var mxSession: MXSession
    var isActive : Bool { type != nil && url != nil }
    var roomId : String? { widgetEvent.roomId }
    
    init?(withWidgetEvent event: MXEvent, inMatrixSession session: MXSession) {
        let eventType = event.type
        guard eventType == kWidgetMatrixEventTypeString ||
            eventType == kWidgetModularEventTypeString else {
            return nil
        }
        widgetId = event.stateKey
        widgetEvent = event
        mxSession = session
        
        if let content = event.content {
            type = content["type"] as? String
            url = content["url"] as? String
            name = content["name"] as? String
            data = content["data"] as? [String : Any]
        } else {
            return nil
        }
    }
    
    @discardableResult
    func decipherWidgetUrl(completion: @escaping (MXResponse<URL>) -> Void) -> MXHTTPOperation? {
        var urlString = self.url ?? ""
        
        var myUserId = mxSession.myUserId ?? ""
        var displayName = mxSession.myUser.displayname ?? myUserId
        var avatarUrl = mxSession.myUser.avatarUrl ?? ""
        // let widgetId = self.widgetId
        
        myUserId = MXTools.encodeURIComponent(myUserId)
        displayName = MXTools.encodeURIComponent(displayName)
        avatarUrl = MXTools.encodeURIComponent(avatarUrl)
        
        urlString = urlString.replacingOccurrences(of: "$matrix_user_id", with: myUserId)
        urlString = urlString.replacingOccurrences(of: "$matrix_display_name", with: displayName)
        urlString = urlString.replacingOccurrences(of: "$matrix_avatar_url", with: avatarUrl)
        
        if let roomID = self.roomId {
            urlString = urlString.replacingOccurrences(of: "$matrix_room_id",
                                           with: MXTools.encodeURIComponent(roomID))
        }
        
        // Integrate widget data into widget url
        if let dict = self.data {
            for (key, value) in dict {
                let stringValue : String
                if let str = value as? String {
                    stringValue = str
                } else if let num = value as? NSNumber {
                    stringValue = num.stringValue
                } else {
                    continue
                }
                urlString = urlString.replacingOccurrences(of: "@" + key,
                                with: MXTools.encodeURIComponent(stringValue))
            }
        }
        let separator = (urlString.contains("?") ? "&" : "?")
        urlString += separator + "widgetId=" + MXTools.encodeURIComponent(self.widgetId)
        
        if WidgetManager.shared.isScalarUrl(urlString, forUserId: myUserId) {
            
        } else {
            completion(.success(URL(string: urlString)!))
        }
        
        return nil
    }
}
