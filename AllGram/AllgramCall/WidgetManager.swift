//
//  WidgetManager.swift
//  AllGram
//
//  Created by Vladyslav on 15.12.2021.
//

import Foundation
import MatrixSDK

let WidgetManagerErrorDomain = "WidgetManagerErrorDomain"
let kWidgetUpdatedNotificationName = Notification.Name("kWidgetUpdatedNotificationName")

enum WidgetManagerErrorCode : Int {
    case notEnoughPower, creationFailed,
         noIntegrationServer, disabledIntegrationServer,
         failToConnectToIntegrationServer, termsNotSigned
}

class WidgetManager {
    static let shared = WidgetManager()
    
    @discardableResult
    func createJitsiWidget(in room: MXRoom, isVideo: Bool, completion: @escaping (MXResponse<Widget>) -> Void) -> MXHTTPOperation? {
        guard let myUserId = room.mxSession.myUserId else {
            completion(.failure(nsError(code: .creationFailed)))
            return nil
        }
        
        let timeInMS = UInt64(Date().timeIntervalSince1970 * 1000)
        let widgetId = "\(kWidgetTypeJitsiV1)_\(myUserId)_\(timeInMS)"
        
        // TODO: use configuration for MXSession
        // let preferedJitsiUrl = URL(string: "https://" + API.jitsiServer)!
        
        guard let widgetContent = JitsiService.createJitsiWidgetContent(serverDomain: API.jitsiServer, roomID: room.roomId, isAudioOnly: !isVideo) else {
            completion(.failure(nsError(code: .creationFailed)))
            return nil
        }
        
        let operation = self.createWidget(id: widgetId, content: widgetContent, room: room, completion: completion)
        return operation
    }
    
    
    func createWidget(id: String, content: [String: Any], room: MXRoom,
                      completion: @escaping (MXResponse<Widget>) -> Void) -> MXHTTPOperation {
        let operation = MXHTTPOperation()
        checkWidgetPermission(room: room) {
            let objId = ObjectIdentifier(room.mxSession)
            if var sessionDict = self.completionForWidgetCreation[objId] {
                sessionDict[id] = completion
                self.completionForWidgetCreation[objId] = sessionDict
            } else {
                self.completionForWidgetCreation[objId] = [id: completion]
            }

            let type = MXEventType(identifier: kWidgetModularEventTypeString)
            let operation2 = room.sendStateEvent(type, content: content, stateKey: id) { response in
                if response.isFailure {
                    completion(.failure(response.error!))
                }
            }
            operation.mutate(to: operation2)
        } failure: { error in
            completion(.failure(error))
        }

        return operation
    }
    
    func add(matrixSession session: MXSession) {
        matrixSessions[session.myUserId] = session
        let objId = ObjectIdentifier(session)
        
        let type1 = MXEventType(identifier: kWidgetMatrixEventTypeString)
        let type2 = MXEventType(identifier: kWidgetModularEventTypeString)
        let listener = session.listenToEvents([type1, type2]) { [weak self] event, direction, customObject in
            guard let self = self, let widgetId = event.stateKey, direction == .forwards else {
                return
            }
            let responseFuncs = self.completionForWidgetCreation[objId]?[widgetId]
            if let widget = Widget(withWidgetEvent: event, inMatrixSession: session) {
                responseFuncs?(.success(widget))
                CallHandler.shared.process(widget: widget, in: event)
                
                // Broadcast the generic notification
                NotificationCenter.default.post(name: kWidgetUpdatedNotificationName, object: widget)
            } else {
                let error = self.nsError(code: .creationFailed,
                                         userInfo: [NSLocalizedDescriptionKey : "creation failed"])
                responseFuncs?(.failure(error))
            }
            self.completionForWidgetCreation[objId]?.removeValue(forKey: widgetId)
        }
        widgetEventListeners[objId] = listener
        completionForWidgetCreation[objId] = [:]
    }
    
    func remove(matrixSession session: MXSession) {
        for key in matrixSessions.keys {
            if session === matrixSessions[key] {
                matrixSessions.removeValue(forKey: key)
            }
        }
        let objId = ObjectIdentifier(session)
        if let listener = widgetEventListeners[objId] {
            session.removeListener(listener)
            widgetEventListeners.removeValue(forKey: objId)
        }
        completionForWidgetCreation.removeValue(forKey: objId)
    }
    
    func isScalarUrl(_ urlStr: String, forUserId userId: String) -> Bool {
        // Widgets in those paths require a scalar token
        let scalarStrings = [String]() // TODO: get information from the config for userId
        
        return scalarStrings.contains { urlStr.hasPrefix($0) }
    }
    
    @discardableResult
    func getScalarToken(session: MXSession, validate: Bool, completion: @escaping (MXResponse<String>) -> Void) -> MXHTTPOperation? {
        var operation : MXHTTPOperation?
        if let scalarToken = self.scalarToken(for: session) {
            if validate {
                operation = validateScalarToken(scalarToken, mxSession: session) { [weak self] response in
                    guard let self = self else { return }
                    switch response {
                    case .success(let isValid):
                        if isValid {
                            completion(.success(scalarToken))
                        } else {
                            let operation2 = self.registerForScalarToken(session: session, completion: completion)
                            operation?.mutate(to: operation2)
                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            } else {
                completion(.success(scalarToken))
            }
        } else {
            // register
        }
        
        return operation
    }
    
    func registerForScalarToken(session: MXSession, completion: @escaping (MXResponse<String>) -> Void) -> MXHTTPOperation? {
        let userId = session.myUserId ?? ""
        var config = configForUser(userId)
        guard config.hasUrls else {
            let error = nsError(code: .noIntegrationServer,
                                userInfo: [NSLocalizedDescriptionKey : "No integration server configured"])
            completion(.failure(error))
            return nil
        }
        
        var operation : MXHTTPOperation?
        let restClient = session.matrixRestClient
        let op2 = restClient?.openIdToken({ tokenObject in
            var httpClient : MXHTTPClient?
            httpClient = MXHTTPClient(baseURL: config.apiUrl, andOnUnrecognizedCertificateBlock: nil)
            let operation2 = httpClient?.request(withMethod: "POST", path: "register?v=1.1",
                                                 parameters: tokenObject?.jsonDictionary(), success: { JSONResponse in
                httpClient = nil
                let scalarToken = JSONResponse?["scalar_token"] as? String
                config.scalarToken = scalarToken
                self.configs[userId] = config
                self.saveConfigs()
                
            }, failure: { error in
                httpClient = nil
                let nsErr = self.nsError(code: .failToConnectToIntegrationServer,
                                    userInfo: [NSLocalizedDescriptionKey : "fail to connect to integration server"])
                completion(.failure(nsErr))
            })
            operation?.mutate(to: operation2)
        }, failure: { error in
            completion(.failure(error!))
        })
        operation = op2
        return operation
    }
    
    func validateScalarToken(_ token: String, mxSession: MXSession, completion: @escaping (MXResponse<Bool>) -> Void) -> MXHTTPOperation? {
        guard let userId = mxSession.myUserId else {
            completion(.failure(nsError(code: .disabledIntegrationServer, userInfo: nil)))
            return nil
        }
        let config = configForUser(userId)
        guard config.hasUrls else {
            let error = nsError(code: .noIntegrationServer,
                                userInfo: [NSLocalizedDescriptionKey : "no integration server"])
            completion(.failure(error))
            return nil
        }
        var httpClient = MXHTTPClient(baseURL: config.apiUrl, andOnUnrecognizedCertificateBlock: nil)

        return httpClient?.request(withMethod: "GET", path: "account?v=1.1&scalar_token=\(token)",
                                   parameters: [:], success: { jsonResponse in
            httpClient = nil
            let incomingUserId = jsonResponse?["user_id"] as? String
            if incomingUserId == userId {
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }, failure: { error in
            httpClient = nil
            let httpStatusCode = MXHTTPOperation.urlResponse(fromError: error)?.statusCode
            
            let mxError = MXError(nsError: error)
            if mxError?.errcode == kMXErrCodeStringTermsNotSigned {
                let nsError = self.nsError(code: .termsNotSigned,
                                      userInfo: [NSLocalizedDescriptionKey : "Terms not signed!"])
                completion(.failure(nsError))
            } else if let x = httpStatusCode, 200 <= x && x <= 299 {
                completion(.success(false))
            } else if let error = error {
                completion(.failure(error))
            }
        })
    }
    
    func scalarToken(for session: MXSession) -> String? {
        return configs[session.myUserId]?.scalarToken
    }
    
    
    // MARK: private -
    private init() {
        loadConfigs()
    }
    
    private var matrixSessions = [String : MXSession]()
    private var widgetEventListeners = [ObjectIdentifier : Any]()
    private var successBlockForWidgetCreation = [ObjectIdentifier : [String : (Widget) -> Void]]()
    private var failureBlockForWidgetCreation = [ObjectIdentifier : [String : (NSError) -> Void]]()
    private var completionForWidgetCreation = [ObjectIdentifier : [String : (MXResponse<Widget>) -> Void]]()
    private var configs = [String : WidgetManagerConfig]()
}

private extension WidgetManager {
    func loadConfigs() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "integrationManagerConfigs") {
            do {
                configs = try JSONDecoder().decode([String : WidgetManagerConfig].self, from: data)
            } catch _ {
                configs.removeAll()
            }
        } else {
            configs.removeAll()
        }
    }
    
    func saveConfigs() {
        let defaults = UserDefaults.standard
        let jsonEncoder = JSONEncoder()
        do {
            let data = try jsonEncoder.encode(configs)
            defaults.set(data, forKey: "integrationManagerConfigs")
        } catch let error {
            print("Encoding error: \(error)")
        }
    }
    
    func configForUser(_ userId: String) -> WidgetManagerConfig {
        return configs[userId] ?? createWidgetManagerConfigForUser(userId)
    }
    
    func createWidgetManagerConfigForUser(_ userId: String) -> WidgetManagerConfig {
        if let session = matrixSessions[userId] {
            if let integrationManager = session.homeserverWellknown.integrations?.managers.first {
                return WidgetManagerConfig(apiUrl: integrationManager.apiUrl,
                                           uiUrl: integrationManager.uiUrl)
            }
        }
        // Fallback on app settings
        return createWidgetManagerConfigWithAppSettings()
    }
    
    func createWidgetManagerConfigWithAppSettings() -> WidgetManagerConfig {
        return WidgetManagerConfig(apiUrl: "https://a.com",
                                   uiUrl: "https://b.com")
    }
    
    func checkWidgetPermission(room: MXRoom, success: @escaping () -> Void,
                                       failure: @escaping (NSError) -> Void) {
        room.state { roomState in
            var isAllowed = false
            if let powerLevels = roomState?.powerLevels {
                let myPowerLevel = powerLevels.powerLevelOfUser(withUserID: room.mxSession.myUserId)
                isAllowed = (myPowerLevel >= powerLevels.stateDefault)
            }
            
            if isAllowed {
                success()
            } else {
                let error = NSError(domain: WidgetManagerErrorDomain, code: WidgetManagerErrorCode.notEnoughPower.rawValue, userInfo: [NSLocalizedDescriptionKey : "No power to manage"])
                failure(error)
            }
        }
    }
    func nsError(code: WidgetManagerErrorCode, userInfo: [String : Any]? = nil) -> NSError {
        return NSError(domain: WidgetManagerErrorDomain, code: code.rawValue, userInfo: userInfo)
    }
}
