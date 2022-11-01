//
//  CallHandler.swift
//  AllGram
//
//  Created by Wladislaw Derevianko on 08.11.2021.
//

import Foundation
import Combine
import MatrixSDK
import CallKit
import JitsiMeetSDK
import UIKit

enum CallViewType : Int {
    case call, incoming, outgoing, incomingSecond
}

var kEnableRingingForGroupCalls = true

// supplied container for remote(true) and local(false) video view
typealias ViewContainerProvider = (Bool) -> UIView?

// global - the callStorage
fileprivate(set) var callStore = [UUID : MXCall]()

class CallHandler : NSObject, ObservableObject {
    var call : MXCall?
	var incomingCall : MXCall?
    var outgoingCall : MXCall?
    var incomingSecondCall : MXCall?
    
    @Published var isShownIncomingAcceptance = false
    @Published var isShownOutgoingAcceptance = false
    @Published var isShownIncomingSecondAcceptance = false
    @Published var isShownCallView = false
    @Published var isShownJitsiCallView = false
    @Published var isShownMinimizedJitsiCallView = false
    @Published var isInsufficientPriviledgeToMakeCallInChat = false
    
	@Published var isEndOfCall = false
	var isNewAudioSessionActivated = false
    
    private let audioConfigurator = MXJingleCallAudioSessionConfigurator()
    private var mediatorVideoViews = [UUID : [UIView?]]()
    
    private var authSession: MXSession?
    
	static let shared = CallHandler()
	
	func setVideoLinker(roomId: String, callback: @escaping ViewContainerProvider) {
		videoLinks[roomId] = callback
	}
    
    func prepareCallManagerIfNeeded(session: MXSession?) {
        authSession = session
        guard let mxSession = session else {
            return
        }
        if mxSession.callManager == nil {
            mxSession.enableVoIP(with: MXJingleCallStack())
            let isCallKitEnabled = AppSettings.shared.enableCallKit
            mxSession.callManager?.callKitAdapter = self.callKitAdapter(forEnabled: isCallKitEnabled)
        }
    }
    
    func isCallKitAvailable() -> Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            return (Locale.current.identifier.uppercased() != "CN")
        #endif
    }
    
    func callerName(viewKind: CallViewType) -> String {
//        let str = call(for: viewKind)?.callerName
        let str = call(for: viewKind)?.callSignalingRoom.summary.displayname
        return (str ?? "(unknown)")
    }
    
    func callerAvatar(viewKind: CallViewType) -> String {
        let str = call(for: viewKind)?.callSignalingRoom.summary.avatar
        let url = getAvatarURL(from: str)
        return (url ?? "(unknown)")
    }
    
    private func getAvatarURL(from uri: String?) -> String? {
        guard let avatarPath = uri else { return nil }
        return authSession?.mediaManager.url(ofContent: avatarPath)
    }
    
    func roomId(viewKind: CallViewType) -> String? {
        return call(for: viewKind)?.room.roomId
    }
    
    func roomName(viewKind: CallViewType) -> String {
        let str = call(for: viewKind)?.callSignalingRoom.summary.displayname
        return (str ?? "(unknown room)")
    }
    
    func isVideoCall(viewKind: CallViewType) -> Bool {
        return call(for: viewKind)?.isVideoCall ?? false
    }
    
    func callDurationMS(viewKind: CallViewType) -> UInt {
        return call(for: viewKind)?.duration ?? 0
    }
    
    func acceptCall() {
        if let call = incomingCall {
            call.answer()
            audioConfigurator.configureAudioSession(forVideoCall: call.isVideoCall)
            self.call = call
        }
    }
    
    func rejectCall() {
        if let call = incomingCall {
            call.hangup()
        }
        incomingCall = nil
        isShownIncomingAcceptance = false
    }
    
    func hangup(viewKind: CallViewType)  {
        if let c = call(for: viewKind) {
            c.hangup()
        }
        switch viewKind {
        case .call:
            isShownCallView = false
            self.call = nil
        case .incoming:
            isShownIncomingAcceptance = false
            incomingCall = nil
        case .outgoing:
            isShownOutgoingAcceptance = false
            outgoingCall = nil
        case .incomingSecond:
            isShownIncomingSecondAcceptance = false
            incomingSecondCall = nil
        }
        // Clear this as well
        directCallSubview = nil
        directRemoteCallSubview = nil
    }
    
    func hideMyVideo(_ shouldHide: Bool) {
        self.call?.videoMuted = shouldHide
    }
    
    func muteMicrophone(_ shouldMute: Bool) {
        self.call?.audioMuted = shouldMute
    }
    
    func isCallConnected() -> Bool {
        return (self.call?.state == .connected)
    }
    
    func setCallsVideoView(_ view: UIView, isRemote: Bool) {
        guard let c = call else {
            return
        }
        guard let views = mediatorVideoViews[c.callUUID] else {
            setStoredCallsVideoView(view, isRemote: isRemote)
            return
        }
        guard views.count == 2 else {
            return
        }
        // Grab correct view
        let index = isRemote ? 1 : 0
        guard let subview = views[index] else {
            return
        }
        // Setup view
        subview.frame = view.bounds
        subview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)
        // Store view for when CallView appears again
        if isRemote { directRemoteCallSubview = subview }
        else { directCallSubview = subview }
        // Update mediator views
        let anotherIndex = 1 - index
        if let otherView = views[anotherIndex] {
            var updatedViews : [UIView?] = [nil, nil]
            updatedViews[anotherIndex] = otherView
            mediatorVideoViews[c.callUUID] = updatedViews
        } else {
            mediatorVideoViews.removeValue(forKey: c.callUUID)
        }
    }
    
    private var directCallSubview: UIView?
    private var directRemoteCallSubview: UIView?
    
    private func setStoredCallsVideoView(_ view: UIView, isRemote: Bool) {
        // Grab correct view (if any)
        guard let subview = isRemote ? directRemoteCallSubview : directCallSubview else {
            return
        }
        // Setup view
        subview.frame = view.bounds
        subview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)
        view.setNeedsLayout()
        subview.setNeedsLayout()
    }
    
    enum CallCapability {
        case cannotCall, canDirectCall, canJitsiCall, jitsiCallInsufficientPower
    }
    @Published var roomCapabilities = [String : CallCapability]()
    
    func determineCallCapability(for room: AllgramRoom) {
		var capability = CallCapability.cannotCall
		if let memberCounts = room.summary.membersCount, memberCounts.joined >= 2 {
			if memberCounts.members == 2 {
				capability = .canDirectCall
			} else {
				// jitsi call
				if room.isAllowedToStartGroupChat() {
					capability = .canJitsiCall
				} else {
					capability = .jitsiCallInsufficientPower
				}
			}
		}
		roomCapabilities[room.room.roomId] = capability
    }
    func capability(for room: AllgramRoom) -> CallCapability {
        return roomCapabilities[room.room.roomId] ?? .cannotCall
    }
    
    func makeOutgoingCall(room: AllgramRoom, hasVideo: Bool) {
        let mxRoom = room.room
		if roomCapabilities[mxRoom.roomId] == .canDirectCall {
			if mxRoom.isDirect {
				self.makeDirectCall(room: room, hasVideo: hasVideo)
			} else {
				mxRoom.setIsDirect(true, withUserId: nil) {
					self.makeDirectCall(room: room, hasVideo: hasVideo)
				} failure: { error in
					self.makeJitsiCall(room: room, hasVideo: hasVideo)
				}
			}
		} else {
			if room.isDirect {
				mxRoom.setIsDirect(false, withUserId: nil) {
					//
				} failure: { error in
                    print("error: \(error ?? "")")
				}

			}
			makeJitsiCall(room: room, hasVideo: hasVideo)
		}
    }
	private func makeDirectCall(room: AllgramRoom, hasVideo: Bool) {
		guard let callManager = room.session.callManager else {
			return
		}
		if hasVideo {
			// check camera permission
		}
        
<<<<<<< HEAD
        // Track making call
        if let accessToken = room.session.credentials.accessToken {
            NewApiManager.shared.recordCallHistory(roomId: room.roomId, isVideo: hasVideo, accessToken: accessToken)
                .sink(receiveValue: { success in

                })
                .store(in: &cancellables)
        }
        
		callManager.placeCall(inRoom: room.room.roomId, withVideo: hasVideo, success: { mxCall in
			// self.call = mxCall
			callManager.callKitAdapter?.start(mxCall)
		}, failure: { error in
			print("ERROR placing call: \(String(describing: error))")
		})
=======
        callManager.placeCall(
            inRoom: room.room.roomId,
            withVideo: hasVideo,
            success: { [unowned self] mxCall in
                // Track making call
                if let accessToken = room.session.credentials.accessToken {
                    ApiManager.shared.recordCalling(roomId: room.roomId, isVideo: hasVideo, accessToken: accessToken)
                        .sink(receiveValue: { _ in
                            //
                        })
                        .store(in: &self.cancellables)
                }
                
                // self.call = mxCall
                callManager.callKitAdapter?.start(mxCall)
            },
            failure: { error in
                print("ERROR placing call: \(String(describing: error))")
            }
        )
>>>>>>> 31c18d7065477c7bcc3186fdd8cdd3e76e69b78e
	}
    
    private func handlePushCall(fallbackSession: MXSession?, roomId: String, event: MXEvent?, completion: @escaping () -> Void) {
        guard let manager = (authSession ?? fallbackSession)?.callManager else {
            completion()
            return
        }
        if let event = event {
            if event.eventType == .callInvite {
                manager.handleCall(event)
            } else {
            }
        } else {
            if let callAdapter = manager.callKitAdapter {
                let dummyCall = MXCall(roomId: roomId, andCallManager: manager)
                dummyCall.callerName = "DUMMY"
                callAdapter.reportIncomingCall(dummyCall)
            }
        }
        completion()
    }
    
    /// New
    func makePushNotificationIncomingCall(fallbackSession: MXSession?, roomId: String, eventId: String, completion: @escaping () -> Void) {
        guard let session = authSession ?? fallbackSession else {
            completion()
            return
        }
        session.event(
            withEventId: eventId,
            inRoom: roomId,
            success: { [weak self] event in

                self?.handlePushCall(fallbackSession: fallbackSession, roomId: roomId, event: event, completion: completion)
            },
            failure: { [weak self] error in

                self?.handlePushCall(fallbackSession: fallbackSession, roomId: roomId, event: nil, completion: completion)
            }
        )
    }
	
    /// Old
	func makePushNotificationIncomingCall(_ dict: [String : Any], completion: @escaping () -> Void) {
		guard let roomId = dict["room_id"] as? String,
		   let room = authSession?.room(withRoomId: roomId) else {
			completion()
			return
		}
		guard let eventId = dict["event_id"] as? String else {
			completion()
			return
		}
		// get event? 
		if let event = authSession?.store.event(withEventId: eventId, inRoom: roomId) {
			if event.eventType == .callInvite {
				authSession?.callManager.handleCall(event)
			}
			
		} else {
			if let callAdapter = authSession?.callManager.callKitAdapter {
				let dummyCall = MXCall(roomId: roomId, andCallManager: authSession!.callManager)
				dummyCall.callerName = room.summary.displayname ?? "<unknown>"
				callAdapter.reportIncomingCall(dummyCall)
			}
		}

		completion()
	}
    
	private var observers = [NSObjectProtocol]()
	//private var cancelObj : AnyCancellable?
	private var videoLinks = [String : ViewContainerProvider]()
    
    private var cancellables = Set<AnyCancellable>()
	
    private override init() {
        super.init()
        startObserving()
	}
	
	deinit {
        stopObserving()
        cancellables.removeAll()
	}
    
    private var jitsiUUIDtoWidget = [UUID : Widget]()
    private var jitsiWidgetIdToUUID = [String : UUID]()
    
    func process(widget: Widget, in event: MXEvent) {
        guard JMCallKitProxy.isProviderConfigured() else {
            return
        }
        if widget.isActive {
            if jitsiWidgetIdToUUID[widget.widgetId] != nil {
                return
            }
            guard let widgetType = widget.type, [kWidgetTypeJitsiV1, kWidgetTypeJitsiV2].contains(widgetType) else {
                return
            }
            let kMillisecondsInSecond = 1000
            let groupInviteTime = 30
            if event.age > groupInviteTime * kMillisecondsInSecond {
                return
            }
            
            let newUUID = UUID()
            jitsiUUIDtoWidget[newUUID] = widget
            jitsiWidgetIdToUUID[widget.widgetId] = newUUID
            
            if event.sender == widget.mxSession.myUserId {
                //
                JMCallKitProxy.reportOutgoingCall(with: newUUID, connectedAt: nil)
            } else {
                // incoming call
                guard kEnableRingingForGroupCalls else {
                    //  do not ring for Jitsi calls
                    return
                }
                let user = widget.mxSession.user(withUserId: event.sender)!
                let displayName = "conference call from user: \(user.displayname ?? user.userId ?? "unknown")"
                
                JMCallKitProxy.reportNewIncomingCall(UUID: newUUID, handle: widget.roomId,
                                                     displayName: displayName, hasVideo: true) { [weak self] error in
                    if  error != nil, let self = self {
                        self.jitsiUUIDtoWidget.removeValue(forKey: newUUID)
                        self.jitsiWidgetIdToUUID.removeValue(forKey: widget.widgetId)
                    }
                }
            }
            
        } else {
            if let uuid = jitsiWidgetIdToUUID[widget.widgetId] {
                JMCallKitProxy.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
                jitsiUUIDtoWidget.removeValue(forKey: uuid)
                jitsiWidgetIdToUUID.removeValue(forKey: widget.widgetId)
            } else {
            }
        }
    }
    
    func endJitsiCall(forWidgetId widgetId: String) {
        guard let uuid = jitsiWidgetIdToUUID[widgetId]
        else {
            return
        }

        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
                
        JMCallKitProxy.request(transaction) { (error) in
            if error == nil {
                self.jitsiWidgetIdToUUID.removeValue(forKey: widgetId)
                self.jitsiUUIDtoWidget.removeValue(forKey: uuid)
            }
        }
    }
}

private extension CallHandler {
    func startObserving() {
        let nc = NotificationCenter.default
        let observer1 = nc.addObserver(forName: NSNotification.Name(kMXCallManagerNewCall), object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let call = notification.object as? MXCall
            else {
                return
            }
            saveCall(call)
            
            if call.isIncoming {
                self.handleIncomingCall(call)
            } else {
                // outgoing call
                self.handleOutgoingCall(call)
            }
        }
        observers.append(observer1)
        
        let observer2 = nc.addObserver(forName: NSNotification.Name(kMXCallStateDidChange), object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let call = notification.object as? MXCall
            else {
                return
            }
            saveCall(call)
			switch call.state {
			case .connecting:
                break
				
			case .waitLocalMedia:
                self.linkVideoViews(call: call)
            case .connected:
                self.call = call
                
                if call.isIncoming {
                    self.incomingCall = nil
                    self.isShownIncomingAcceptance = false
                    
                    // Track accepting incoming call
                    if let accessToken = AuthViewModel.shared.session?.credentials.accessToken {
                        ApiManager.shared.recordAnswering(roomId: call.room.roomId, accessToken: accessToken)
                            .sink(receiveValue: { success in
                                //
                            })
                            .store(in: &self.cancellables)
                    }
                } else {
                    self.outgoingCall = nil
                    self.isShownOutgoingAcceptance = false
                }
                self.isShownCallView = true
			case .ended:
                self.onCallEnded(call: call)
			default: break
			}
		}
		observers.append(observer2)
		
        let kAudioSessionActiveName = NSNotification.Name(kMXCallKitAdapterAudioSessionDidActive)
        let observer3 = nc.addObserver(forName: kAudioSessionActiveName, object: nil, queue: .main) { [weak self] notif in
            guard let self = self else { return }
            self.isNewAudioSessionActivated = true
            // HOW: answer call?
        }
        observers.append(observer3)
        
        JMCallKitProxy.addListener(self)
    }
    
    func stopObserving() {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        observers.removeAll()
    }
    
    func callKitAdapter(forEnabled enabled: Bool) -> MXCallKitAdapter? {
        if !(enabled && isCallKitAvailable())   { return nil }
        
        let config = MXCallKitConfiguration()
        config.iconName = "callkit_icon"
        config.ringtoneName = "ring.mp3"
        let iconData = UIImage(named: config.iconName!)?.pngData()
        JMCallKitProxy.configureProvider(localizedName: config.name, ringtoneSound: config.ringtoneName,
                                         iconTemplateImageData: iconData)
        
        let callKitAdapter = MXCallKitAdapter(configuration: config)
        callKitAdapter.audioSessionConfigurator = audioConfigurator
        return callKitAdapter
    }
    
    func handleIncomingCall(_ call: MXCall) {
        isNewAudioSessionActivated = false
        if isCallKitAvailable() {
            // let CallKit to interact with user
            return
        }
        if isShownIncomingSecondAcceptance {
            // too many calls... Get rid of the last one
            call.hangup()
            return
        }
        if isShownIncomingAcceptance || isShownOutgoingAcceptance || isShownCallView {
            incomingSecondCall = call
            isShownIncomingSecondAcceptance = true
        } else {
            incomingCall = call
            isShownIncomingAcceptance = true
        }
    }
    
    func handleOutgoingCall(_ call: MXCall) {
        outgoingCall = call
        isNewAudioSessionActivated = false
        isShownOutgoingAcceptance = true
    }
    
    func onConnected(call: MXCall) {
        self.call = call
        isShownCallView = true
    }
    
    func onCallEnded(call: MXCall) {
        isEndOfCall = true
        
        let uuid = call.callUUID
        if uuid == self.call?.callUUID {
            isShownCallView = false
            self.call = nil
        }
        if uuid == incomingCall?.callUUID {
            isShownIncomingAcceptance = false
            incomingCall = nil
        }
        if uuid == outgoingCall?.callUUID {
            isShownOutgoingAcceptance = false
            outgoingCall = nil
        }
        if uuid == incomingSecondCall?.callUUID {
            isShownIncomingSecondAcceptance = false
            incomingSecondCall = nil
        }
    }
    
    func call(for viewType: CallViewType) -> MXCall? {
        switch viewType {
        case .call:
            return call
        case .incoming:
            return incomingCall
        case .outgoing:
            return outgoingCall
        case .incomingSecond:
            return incomingSecondCall
        }
    }
    
    func linkVideoViews(call: MXCall) {
        guard call.isVideoCall else { return }
        let uuid = call.callUUID
        let pairOfViews : [UIView?]
        if let oldPair = mediatorVideoViews[uuid], oldPair.count == 2 {
            pairOfViews = oldPair
        } else {
            let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
            pairOfViews = [UIView(frame: rect), UIView(frame: rect)]
            mediatorVideoViews[uuid] = pairOfViews
        }
        if let newSelfVideoView = pairOfViews[0] {
            call.selfVideoView = newSelfVideoView
        }
        if let newRemoteVideoView = pairOfViews[1] {
            call.remoteVideoView = newRemoteVideoView
        }
    }
    
    func makeJitsiCall(room: AllgramRoom, hasVideo: Bool) {
        guard room.isAllowedToStartGroupChat() else {
            //  Insufficient privileges to add a Jitsi widget
            isInsufficientPriviledgeToMakeCallInChat = true
            return
        }
        
        // Track making call
        if let accessToken = room.session.credentials.accessToken {
<<<<<<< HEAD
            NewApiManager.shared.recordCallHistory(roomId: room.roomId, isVideo: hasVideo, accessToken: accessToken)
=======
            ApiManager.shared.recordCalling(roomId: room.roomId, isVideo: hasVideo, accessToken: accessToken)
>>>>>>> 31c18d7065477c7bcc3186fdd8cdd3e76e69b78e
                .sink(receiveValue: { success in
                    //
                })
                .store(in: &cancellables)
        }
        
        WidgetManager.shared.createJitsiWidget(in: room.room, isVideo: hasVideo) { [weak self] response in
            switch response {
            case .success(let widget):
                JitsiCallModel.shared.prepareJitsi(with: widget) { [weak self] isSuccess in
                    guard let self = self else { return }
                    if isSuccess {
                        self.startJitsiCall(withWidget: widget)
                    }
                    self.isShownJitsiCallView = true
                }
            case .failure(let error):
                JitsiCallModel.shared.setLastError(error)
                self?.isShownJitsiCallView = true
            }
        }
    }
    
    private func startJitsiCall(withWidget widget: Widget) {
        if jitsiWidgetIdToUUID[widget.widgetId] != nil {
            return
        }
        
        guard let roomId = widget.roomId else {
            return
        }
        
        let session = widget.mxSession
        
        guard let room = session.room(withRoomId: roomId) else {
            return
        }
        
        let newUUID = UUID()
        let handle = CXHandle(type: .generic, value: roomId)
        let startCallAction = CXStartCallAction(call: newUUID, handle: handle)
        let transaction = CXTransaction(action: startCallAction)
        
        
        JMCallKitProxy.request(transaction) { [weak self] error in
            if error != nil {
                return
            }
            
            
            JMCallKitProxy.reportCallUpdate(with: newUUID,
                                            handle: roomId,
                                            displayName: room.summary.displayname,
                                            hasVideo: true)
            JMCallKitProxy.reportOutgoingCall(with: newUUID, connectedAt: nil)
            self?.jitsiUUIDtoWidget[newUUID] = widget
            self?.jitsiWidgetIdToUUID[widget.widgetId] = newUUID
        }
    }
    
}

// callbacks from Jitsi Meet
extension CallHandler : JMCallKitListener {
    func providerDidReset() {
    }
    func performAnswerCall(UUID: UUID) {
        if let widget = jitsiUUIDtoWidget[UUID] {
            JitsiCallModel.shared.prepareJitsi(with: widget) { [weak self] isSuccess in
                guard let self = self else { return }
                if isSuccess {
                    self.startJitsiCall(withWidget: widget)
                }
                self.isShownJitsiCallView = true
            }
        }
    }

}

fileprivate func saveCall(_ call: MXCall) {
    if nil == callStore[call.callUUID] {
        callStore[call.callUUID] = call
    }
}
