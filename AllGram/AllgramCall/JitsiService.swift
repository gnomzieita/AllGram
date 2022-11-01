//
//  JitsiService.swift
//  AllGram
//
//  Created by Vladyslav on 15.12.2021.
//

import Foundation
import JitsiMeetSDK
import MatrixSDK

enum JitsiAuthenticationType : String {
    case openIDTokenJWT = "openidtoken-jwt"
}

enum JitsiServiceError: Error {
    case widgetContentCreationFailed
    case emptyResponse
    case noWellKnown
    case missingConferenceId
    case terminatedCall
    case unknown
}

class JitsiService {
    static let shared = JitsiService()
    
    private let jitsiMeet = JitsiMeet.sharedInstance()
    private lazy var jwtTokenBuilder: JitsiJWTTokenBuilder = {
        return JitsiJWTTokenBuilder()
    }()
    
    static func createJitsiWidgetContent(serverDomain: String,
                                         roomID: String,
                                         isAudioOnly: Bool) -> [String: Any]? {
        let widgetSessionId = randomString(lengthLimit: 7)
        
        let conferenceID : String
        let components = roomID.split(separator: ":")
        if components.count == 2 {
            let localRoomID = components[0].filter { $0 != "!" }
            conferenceID = localRoomID + widgetSessionId
        } else {
            conferenceID = widgetSessionId
        }
        
        // Build widget url
        // Riot-iOS does not directly use it but extracts params from it (see `[JitsiViewController openWidget:withVideo:]`)
        // This url can be used as is inside a web container (like iframe for Riot-web)
        
        // Build it from the riot-web app
        // let appUrlString = BuildSettings.applicationWebAppUrlString
        let appUrlString = API.server.getURL()!.absoluteString
        
        // We mix v1 and v2 param for backward compability
        let v1queryStringParts = [
            "confId=\(conferenceID)",
            "isAudioConf=\(isAudioOnly ? "true" : "false")",
            "displayName=$matrix_display_name",
            "avatarUrl=$matrix_avatar_url",
            "email=$matrix_user_id"
        ]
        
        let v1Params = v1queryStringParts.joined(separator: "&")
                        
        let v2queryStringParts = [
            "conferenceDomain=$domain",
            "conferenceId=$conferenceId",
            "isAudioOnly=$isAudioOnly",
            "displayName=$matrix_display_name",
            "avatarUrl=$matrix_avatar_url",
            "userId=$matrix_user_id"
        ]
        
        let v2Params = v2queryStringParts.joined(separator: "&")
        
        let widgetStringURL = "\(appUrlString)/widgets/jitsi.html?\(v1Params)#\(v2Params)"
        
        // Build widget data
        // We mix v1 and v2 widget data for backward compability
//        let jitsiWidgetData = JitsiWidgetData()
//        jitsiWidgetData.domain = serverDomain
//        jitsiWidgetData.conferenceId = conferenceID
//        jitsiWidgetData.isAudioOnly = isAudioOnly
//        jitsiWidgetData.authenticationType = authenticationType?.identifier
//
//        let v2WidgetData: [AnyHashable: Any] = jitsiWidgetData.jsonDictionary()
//
//        var v1AndV2WidgetData = v2WidgetData
//        v1AndV2WidgetData["widgetSessionId"] = widgetSessionId
        
        let v1AndV2WidgetData = ["widgetSessionId" : widgetSessionId,
                                 "domain": serverDomain,
                                 "conferenceId": conferenceID,
                                 "isAudioOnly" : isAudioOnly
        ] as [String : Any]
        
        let widgetContent: [String: Any] = [
            "url": widgetStringURL,
            "type": kWidgetTypeJitsiV1,
            "data": v1AndV2WidgetData
        ]
        
        return widgetContent
    }
    
    /// Get Jitsi JWT token using user OpenID token
    @discardableResult
    func getOpenIdJWTToken(jitsiServerDomain: String,
                           roomId: String,
                           matrixSession: MXSession,
                           completion: @escaping (MXResponse<String>) -> Void) -> MXHTTPOperation? {
        
        let myUser: MXUser = matrixSession.myUser
        let userDisplayName: String = myUser.displayname ?? myUser.userId
        let avatarStringURL: String = myUser.avatarUrl ?? ""
        
        return matrixSession.matrixRestClient.openIdToken({ (openIdToken) in
            guard let openIdToken = openIdToken, openIdToken.accessToken != nil else {
                completion(.failure(JitsiServiceError.unknown))
                return
            }
            
            do {
                let jwtToken = try JitsiJWTTokenBuilder.build(jitsiServerDomain: jitsiServerDomain,
                openIdToken: openIdToken,
                roomId: roomId,
                userAvatarUrl: avatarStringURL,
                userDisplayName: userDisplayName)
                
                completion(.success(jwtToken))
            } catch {
                completion(.failure(error))
            }
        }, failure: { error in
            completion(.failure(error ?? JitsiServiceError.unknown))
        })
    }
    
}

// processing of AppDelegate functions for Jitsi Meet
extension JitsiService {
    @discardableResult
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        jitsiMeet.defaultConferenceOptions = .fromBuilder { builder in
            var urlComponents = URLComponents()
            urlComponents.host = API.jitsiServer
            urlComponents.scheme = "https"
            builder.serverURL = urlComponents.url
        }
        
        return jitsiMeet.application(application, didFinishLaunchingWithOptions: launchOptions ?? [:])
    }
}

func randomString(lengthLimit: Int) -> String {
    assert(0 < lengthLimit && lengthLimit < 12)
    var x = Int.random(in: 0..<(1 << (5 * lengthLimit)))
    
    let table = ["a", "b", "c", "d", "e", "f", "g", "h",
                 "i", "j", "k", "l", "m", "n", "o", "p",
                 "q", "r", "s", "t", "u", "v", "w", "x",
                 "2", "3", "4", "5", "6", "7", "8", "9"]
    var result = ""
    for _ in 0..<lengthLimit {
        result.append(table[x & 31])
        x >>= 5
    }
    return result
}

