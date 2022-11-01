//
//  PushNotifications.swift
//  AllGram
//
//  Created by Wladislaw Derevianko on 11.04.2022.
//

import UIKit
import PushKit
import CallKit
import MatrixSDK

enum AppStateForPush: String {
    /// Initial state
    case initial
    /// When finished launching with options
    case launched
    /// When moved to background
    case inBackground
    /// When moved to foreground (after being in background)
    case inForeground
}

class PushNotifications : NSObject {
	static let shared = PushNotifications()
	
	private let pushRegistry = PKPushRegistry(queue: nil)
	private var userID : String?
	private var email : String?
	private weak var authModel: AuthViewModel?
	private var task : URLSessionDataTask?
    
    var appState: AppStateForPush = .initial
    
	override init() {
		super.init()
		pushRegistry.delegate = self
        
        // Track if app is in use to avoid push notifications
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
	}
    
    @objc private func appMovedToBackground() { appState = .inBackground }
    @objc private func appMovedToForeground() { appState = .inForeground }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

	func subscribe(model: AuthViewModel) {
		self.authModel = model
		pushRegistry.desiredPushTypes = [.voIP]
	}
    
	func unsubscribe(model : AuthViewModel, completion: (() -> Void)? = nil) {
		self.authModel = model
		pushRegistry.desiredPushTypes = []
		
		guard let credentials = model.session?.credentials else {
			completion?()
			return
		}
		if let accessToken = credentials.accessToken,
		   let pushToken = pushRegistry.pushToken(for: .voIP) {
			let pushTokenString = hexDigits(pushToken)
            let type = NewApiManager.shared.getUnregisterApnTokenRequest(token: pushTokenString, type: .voip, accessToken: accessToken)
			sendRequest(type, completion: completion)
		} else {
			completion?()
		}
	}
	
	private func hexDigits(_ data: Data) -> String {
		let pushTokenArray : [String] = data.map {
			let s = String($0, radix: 16, uppercase: true)
			return (s.count < 2 ? "0" + s : s)
		}
		return pushTokenArray.joined(separator: "")
	}
    
	private func sendRequest(_ request: URLRequest, completion: (() -> Void)? = nil) {
		self.task?.cancel()
		let task = URLSession(configuration: .ephemeral).dataTask(with: request) { data, response, error in
			DispatchQueue.main.async {
				completion?()
			}
		}
		self.task = task
		task.resume()
	}
}

extension PushNotifications : PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        // TODO: clear token on the server?
    }
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP, let credentials = self.authModel?.session?.credentials else { return }
        guard let accessToken = credentials.accessToken else {
            return
        }
        let pushTokenString = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        let type = NewApiManager.shared.getRegisterApnTokenRequest(token: pushTokenString, type: APNTokenType.voip, accessToken: accessToken)
        sendRequest(type)
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("=================type: \(type)")
        guard type == .voIP, let dict = payload.dictionaryPayload as? [String : Any] else {
            completion()
            return
        }
                print(" ================================= \n \n \(payload.dictionaryPayload) \n \n ============================")
        //        let config = CXProviderConfiguration()
        //        //config.iconTemplateImageData = UIImage(named: "pizza")!.pngData()
        //        config.ringtoneSound = "ringtone.caf"
        //        config.includesCallsInRecents = false;
        //        config.supportsVideo = true;
        

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: (dict["displayName"] as? String ?? ""))
        
        let roomId = dict["roomID"] as? String ?? "nil"
        let eventId = dict["eventID"] as? String ?? "nil"
        let eventType = dict["type"] as? String ?? "nil"
        let video = dict["video"] as? Bool ?? false
        
        let CallKitConfiguration = MXCallKitConfiguration.init(name: (payload.dictionaryPayload["displayName"] as? String ?? ""), ringtoneName: "ringtone.caf", iconName: nil, supportsVideo: video)
        let adapter:MXCallKitAdapter = MXCallKitAdapter.init(configuration: CallKitConfiguration)
        let callManager = AuthViewModel.shared.session
        //callManager!.enableVoIP(with: AuthViewModel.shared.session?.callManager.callStack)
        let call:MXCall = MXCall(roomId: roomId, andCallManager: (callManager?.callManager)!)
        adapter.reportIncomingCall(call)
        
        //completion()
        
        //        switch appState {
        //        case .initial:
        //            // App have not finished launching yet - handle push?
        //            break
        //        case .launched:
        //            // App just launched - no need to handle push?
        //            break
        //        case .inBackground:
        //            // App in background - handle push?
        //            break
        //        case .inForeground:
        //            // Returned to usage by user - no need to handle push?
        //            break
        //        }
        //        if eventType.starts(with: "m.call") {
        //            // Not encrypted chat call event
        //            CallHandler.shared.makePushNotificationIncomingCall(
        //                fallbackSession: authModel?.session,
        //                roomId: roomId, eventId: eventId,
        //                completion: completion
        //            )
        //        } else if eventType.contains("encrypted") {
        //            // Encrypted chat event, maybe not a call event at all
        //            CallHandler.shared.makePushNotificationIncomingCall(
        //                fallbackSession: authModel?.session,
        //                roomId: roomId, eventId: eventId,
        //                completion: completion
        //            )
        //        } else {
        //            // Not a call event
        //            completion()
        //        }
        //	}
    }
}

extension PushNotifications : CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {

    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        action.fulfill()
    }
}
