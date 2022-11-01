//
//  JitsiCallModel.swift
//  AllGram
//
//  Created by Vladyslav on 20.12.2021.
//

import Foundation
import JitsiMeetSDK

class JitsiCallModel : NSObject, ObservableObject {
    static var shared = JitsiCallModel()
    
    private var jitsiView = JitsiMeetView()
    var serverUrl : URL?
    var videoMuted = false
    var conferenceId : String?
    
    var lastError : Error?
    @Published var problemDescription : String?
    
    private var jwtToken : String?
    private var conferenceIdToWidgetIdMap = [String : String]()
    
    func getView() -> UIView {
        return jitsiView
    }
    
    func setLastError(_ error: Error?) {
        lastError = error
        problemDescription = error?.localizedDescription
    }
    
    func prepareJitsi(with widget: Widget, completion: @escaping (Bool) -> Void) {
        widget.decipherWidgetUrl { [weak self] response in
            guard let self = self else {
                completion(false)
                return
            }
            
            switch response {
            case .success(let url):
                let widgetData = widget.data
                let domain = widgetData?["domain"] as? String
                let authType = widgetData?["auth"] as? String
                
                self.conferenceId = widgetData?["conferenceId"] as? String
                if let domain = domain {
                    var components = URLComponents()
                    components.host = domain
                    components.scheme = "https"
                    self.serverUrl = components.url
                } else {
                    self.serverUrl = nil
                }
                self.videoMuted = (widgetData?["isAudioOnly"] as? NSNumber)?.boolValue ?? false
                
                
                if authType == JitsiAuthenticationType.openIDTokenJWT.rawValue {
                    JitsiService.shared.getOpenIdJWTToken(jitsiServerDomain: domain ?? "", roomId: widget.roomId ?? "",
                                                          matrixSession: widget.mxSession) { response in
                        var isOkey = false
                        switch response {
                        case .success(let jwtToken):
                            self.jwtToken = jwtToken
                            isOkey = self.fillAndGo(url: url, widget: widget)
                        case .failure(let error):
                            self.setLastError(error)
                        }
                        completion(isOkey)
                    }
                } else {
                    let isOkey = self.fillAndGo(url: url, widget: widget)
                    completion(isOkey)
                }
                
                
                break
            case .failure(let error):
                self.setLastError(error)
                completion(false)
                break
            }
        }
    }
    
    private var jitsiOptions : JitsiMeetConferenceOptions?
    
    private override init() {
        super.init()
    }
    
    private func fillAndGo(url: URL, widget: Widget) -> Bool {
        if nil == conferenceId  {
            fillFrom(url: url)
        }
        if let conferenceId = conferenceId {
            // success
            conferenceIdToWidgetIdMap[conferenceId] = widget.widgetId
            jitsiView.delegate = self
            jitsiOptions = makeJitsiOptionsFrom(widget: widget, conferenceId: conferenceId)
            setLastError(nil)
        } else {
            // failure
            jitsiOptions = nil
            lastError = JitsiServiceError.missingConferenceId
            problemDescription = "Error: missing conference ID"
        }
        jitsiView.join(jitsiOptions)
        return (nil != jitsiOptions)
    }
    
    private func fillFrom(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let item = components.queryItems?.first {
            $0.name == "confId"
        }
        conferenceId = item?.value
    }
    
    private func makeJitsiOptionsFrom(widget: Widget, conferenceId: String) -> JitsiMeetConferenceOptions {
        let session = widget.mxSession
        let roomSummary = session.roomSummary(withRoomId: widget.roomId)

        var userDisplayName : String?
        var avatarUrl : URL?
        if let roomMember = roomSummary?.room.dangerousSyncState?.members.member(withUserId: session.myUserId) {
            userDisplayName = roomMember.displayname
            
            if let memberAvatar = roomMember.avatarUrl {
                if let avatarString = session.mediaManager.url(ofContent: memberAvatar) {
                    avatarUrl = URL(string: avatarString)
                }
            }
        }

        return JitsiMeetConferenceOptions.fromBuilder { builder in
            builder.serverURL = self.serverUrl
            builder.room = conferenceId
            builder.setVideoMuted(self.videoMuted)
            
            if let subject = roomSummary?.displayname {
                builder.setSubject(subject)
            }
            
            builder.userInfo = .init(displayName: userDisplayName, andEmail: nil, andAvatar: avatarUrl)
            builder.token = self.jwtToken
            builder.setFeatureFlag("chat.enabled", withValue: false)
        }
    }
    
}

extension JitsiCallModel : JitsiMeetViewDelegate {
    func conferenceJoined(_ data: [AnyHashable : Any]!) {
    }
    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        lastError = JitsiServiceError.terminatedCall
        if let err = data?["error"] as? String {
            let dict = ["connection.droppedError": "Dropped connection",
                        "connection.otherError": "Unspecified error",
                        "connection.passwordRequired": "Password is required for connection",
                        "connection.serverError": "Error: too many 5xx HTTP errors on BOSH requests"
            ]
            problemDescription = dict[err] ?? "Unexpected error"
        } else {
            problemDescription = "Conference call is terminated"
        }
        if let urlString = data?["url"] as? String, let url = URL(string: urlString) {
            let confId = url.lastPathComponent
            if let widgetId = conferenceIdToWidgetIdMap[confId] {
                conferenceIdToWidgetIdMap.removeValue(forKey: confId)
                CallHandler.shared.endJitsiCall(forWidgetId: widgetId)
                
            }
                
        }
    }
    
//    func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
//    }
    func enterPicture(inPicture data: [AnyHashable : Any]!) {
        CallHandler.shared.isShownJitsiCallView = false
        CallHandler.shared.isShownMinimizedJitsiCallView = true
    }
}

