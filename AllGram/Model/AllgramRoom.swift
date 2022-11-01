import Foundation
import SwiftUI
import Combine

import MatrixSDK

struct RoomItem: Codable, Hashable {
    static func == (lhs: RoomItem, rhs: RoomItem) -> Bool {
        return lhs.displayName == rhs.displayName &&
        lhs.roomId == rhs.roomId
    }
    
    let roomId: String
    let displayName: String
    let messageDate: UInt64
    
    init(room: MXRoom) {
        self.roomId = room.summary.roomId
        self.displayName = room.summary.displayname ?? ""
        self.messageDate = room.summary.lastMessage?.originServerTs ?? UInt64(Date.timeIntervalSinceReferenceDate)
    }
}

extension NSNotification.Name {
    static var roomIsMeetingStateChanged = NSNotification.Name("roomIsMeetingStateChanged")
    static var allgramRoomIsDirectStateChanged = NSNotification.Name("allgramRoomIsDirectStateChanged")
}

class AllgramRoom: ObservableObject {
    @Environment(\.userId) private var userId
    private var cancellable = Set<AnyCancellable>()
    
    let room: MXRoom
    let session: MXSession
    
    /// The Matrix id of the room
    var roomId: String! { room.roomId }
    
    /// Room display name from summary if any
    var displayName: String! { room.summary.displayname }
    
    /// Room topic from summary if any
    var topic: String? { return room.summary.topic }
    
    /// Correct URL from matrix URI string if any
    var realAvatarURL: URL? {
        // Until user accepts an invite, summary does not provide room avatar,
        // so we use the avatar of inviting user user instead.
        // In some cases, summary still provides nil instead of the avatar,
        // so just fallback to invite handled approach...
        if let urlString = session.mediaManager.url(ofContent: room.summary?.avatar) {
            return URL(string: urlString)
        } else if let inviteEvent = eventCache.last(where: { $0.type == kMXEventTypeStringRoomMember && $0.stateKey != room.mxSession.myUserId }),
                  let senderURI: String? = inviteEvent.content(valueFor: "avatar_url"),
                  let urlString = session.mediaManager.url(ofContent: senderURI)
        {
            return URL(string: urlString)
        } else {
            return nil
        }
    }
    
    /// Custom description field for the club rooms only
    @Published private(set) var clubDescription: String?
    
    func getClubDescription() {
        guard let accessToken = AuthViewModel.shared.sessionVM?.accessToken else { return }
        ApiManager.shared.getRoomDescription(roomId: roomId, accessToken: accessToken)
            .sink { co in
                switch co {
                case .finished:
                    break
                case .failure(let error):
                    break
                }
            } receiveValue: { [weak self] someDescription in
                self?.clubDescription = someDescription
            }.store(in: &cancellable)
    }
    
    func setClubDescription(_ description: String, completion: @escaping (Bool) -> Void) {
        guard let accessToken = AuthViewModel.shared.sessionVM?.accessToken else { return }
        ApiManager.shared.setRoomDescription(roomId: roomId, description: description, accessToken: accessToken)
            .sink { [weak self] success in
                if success {
                    self?.clubDescription = description
                }
                completion(success)
            }.store(in: &cancellable)
    }
    
    @Published
    var summary: AllgramRoomSummary
    
    @Published
    var eventCache: [MXEvent] = []
    
    /// Read receipts per event
    @Published
    var readReceipts: [String: [MXReceiptData]] = [:]
    
    /// Direct by Matrix standards, meaning direct chat
    var isDirect: Bool { room.isDirect }
    
    @Published var expectMoreHistory = true
    @Published var counterForTypingNotifications = 0
    
    // Whats the difference? Hm...
    var isInvite: Bool { summary.membership == .invite }
//    var isInvite: Bool { summary.dataTypes.contains(.invited) }
    
    var isGeneral: Bool { !isFavorite && !isLowPriority }
    var isFavorite: Bool { summary.dataTypes.contains(.favorited) }
    var isLowPriority: Bool { summary.dataTypes.contains(.lowPriority) }
    
    /// Returns userId of the user who invited current one.
    /// Returns `nil` if room is not in invite state
    var invitedByUserId: String? {
        if summary.membership == .invite {
            let inviteEvent = eventCache.last {
                $0.type == kMXEventTypeStringRoomMember && $0.stateKey != room.mxSession.myUserId
            }
            return inviteEvent?.sender
        }
        return nil
    }
    
    var lastMessage: String {
        // Check invite case
        if summary.membership == .invite {
            guard let sender = invitedByUserId else { return "" }
            return "Invitation from: \(sender.dropAllgramSuffix)"
        }
        // Filter only room message event
        guard let lastMessageEvent = eventCache.filter({ $0.messageType != nil }).last else {
            return ""
        }
        switch lastMessageEvent.messageType {
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .file:
            return "File"
        default:
            return ChatTextMessageView.Model.init(event: lastMessageEvent).message
        }
    }
    
    /// Checks notification count and returns `true` if  more than zero
    var hasUnreadContent: Bool {
        room.summary.notificationCount > 0
    }
    
    /// Our custom parameter, meetings are basically chats (starts with `false` before update)
    var isMeeting: Bool = false {
        didSet {
            if isMeeting != oldValue {
                NotificationCenter.default.post(name: .roomIsMeetingStateChanged, object: nil)
            }
        }
    }
    
    /// Our custom parameter, determines if room is NOT club (starts with `true` before update)
    var isChat: Bool = true {
        didSet {
            if isChat != oldValue {
                NotificationCenter.default.post(name: .allgramRoomIsDirectStateChanged, object: nil)
            }
        }
    }
    
    /// Based on our custom parameters, NOT chat & NOT meeting
    var isClub: Bool { !isChat && !isMeeting }
    
    /// Is set once at init time, should never change (hopefully)
    private(set) var isEncrypted: Bool = false
    
    init(_ room: MXRoom, in session: MXSession) {
        self.room = room
        self.session = session
        self.summary = AllgramRoomSummary(room.summary)
        
        registerEventEditsListener()
        
        updateReadReceipts()
        listenEvents()
        deleteFailedOutgoingMessages()
        checkMeetingState()
        checkIsDirectState()
        getClubDescription()
        
        // Wait a bit to properly get it for newly created rooms on device
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            room.state { [weak self] roomState in
                self?.isEncrypted = roomState?.isEncrypted ?? false
            }
        }
    }
    
    deinit {
        if let listener = eventListener {
            room.liveTimeline { timeline in
                timeline?.removeListener(listener)
            }
        }
        if let listener = eventEditsListener {
            session.aggregations.removeListener(listener)
        }
        if let listener = eventTypingListener {
            room.removeListener(listener)
        }
    }
    
    /// The listener to edits in the room.
    private var eventEditsListener: Any?
    private var eventListener: Any?
    private var eventTypingListener : Any?
    
    var listenIfOthersAreTyping: Bool = false {
        didSet {
            if listenIfOthersAreTyping {
                eventTypingListener = room.listen(toEventsOfTypes: [MXEventType.typing.identifier])
                { [weak self] event, direction, roomState in
                    self?.counterForTypingNotifications += 1
                }
            } else {
                if let listener = eventTypingListener {
                    room.removeListener(listener)
                    eventTypingListener = nil
                }
            }
        }
    }
    
    func checkIsDirectState(completion: (() -> Void)? = nil) {
        // Check storage first
        let roomId = room.roomId!
        if let storedRoomType = UserDefaults.group.getStoredType(for: roomId) {
            // Already have this in storage
            if storedRoomType.chatUpdates > 10 {
                // Updated enough times
                isChat = storedRoomType.isChat
                completion?()
                return
            } else {
                // Need more updates, use stored value and do the update
                isChat = storedRoomType.isChat
            }
        } else {
            // Not in storage yet
        }
        // Do the update if needed
        NewApiManager.shared.roomIsDirect(roomId: self.room.roomId)
            .sink { [weak self] isDirect in
                UserDefaults.group.setStoredType(for: roomId, isChat: isDirect)
                self?.isChat = isDirect ?? false
                completion?()
            }.store(in: &cancellable)
    }
    
    func checkMeetingState(completion: (() -> Void)? = nil) {
        // Check storage first
        let roomId = room.roomId!
        if let storedRoomType = UserDefaults.group.getStoredType(for: roomId) {
            // Already have this in storage
            if storedRoomType.meetingUpdates > 10 {
                // Updated enough times
                isMeeting = storedRoomType.isMeeting
                completion?()
                return
            } else {
                // Need more updates, use stored value and do the update
                isMeeting = storedRoomType.isMeeting
            }
        } else {
            // Not in storage yet
        }
        // Do the update if needed
        NewApiManager.shared.roomIsMeeting(roomId: self.room.roomId)
            .sink { isMeeting in
                UserDefaults.group.setStoredType(for: roomId, isMeeting: isMeeting)
                self.isMeeting = isMeeting ?? false
                completion?()
            }.store(in: &cancellable)
    }
    
    private func updateReadReceipts() {
        let _ = eventCache.map { event in
            room.getEventReceipts(event.eventId, sorted: true) { [weak self] receiptDataArray in
                self?.readReceipts[event.eventId] = receiptDataArray
            }
        }
    }
    
    private func add(event: MXEvent, direction: MXTimelineDirection, roomState: MXRoomState?) {
        
        if event.type == "m.room.member" {


        }
        
        
        if event.eventType == .receipt {
            didReceiveReceiptEvent(event, roomState: roomState)
        }
        
        if let nonZeroEventId = event.eventId {
            if eventCache.contains(where: { $0.eventId == nonZeroEventId } ) {
                return
            }
        } // else, allow the duplicate receipts with zero eventId
        
        switch direction {
        case .backwards:
            self.eventCache.insert(event, at: 0)
        case .forwards:
            self.eventCache.append(event)
        }
    }
    
    func events() -> EventCollection {
        return EventCollection(eventCache + room.outgoingMessages())
    }
    
    func getClubEvents() -> ClubEventCollection {
        ClubEventCollection(eventCache + room.outgoingMessages())
    }
    
    private var accessedTimelines = Set<ObjectIdentifier>()
    
    func isAllowedToStartGroupChat() -> Bool {
        var roomState : MXRoomState?
        room.state { aRoomState in
            roomState = aRoomState
        }
        guard let powerLevels = roomState?.powerLevels else {
            // TODO: explain that room state was not loaded yet
            return false
        }
        
        // TODO: what is the required level?
        let requiredPower = powerLevels.invite
        
        let myPower = powerLevels.powerLevelOfUser(withUserID: room.mxSession.myUserId)
        return myPower >= requiredPower
    }
    
    // MARK: - Pagination
    
    func paginateBackward(items: UInt = 40, completion: ((_ success: Bool) -> Void)? = nil) {
        room.liveTimeline { [weak self] timeline in
            guard let timeline = timeline, let self = self else { return }
            timeline.paginate(items, direction: .backwards, onlyFromStore: false) { [weak self] response in
                DispatchQueue.main.async {
                    self?.expectMoreHistory = timeline.canPaginate(.backwards)
                    switch response {
                    case .success(): completion?(true)
                    case .failure(_): completion?(false)
                    }
                }
            }
        }
    }
    
    func paginate(till event: MXEvent, completion: @escaping (Bool) -> Void) {
        guard event.roomId == self.roomId else {
            completion(false)
            return
        }
        cancelablePaginate() { [weak self] result in
            switch result {
            case .success(()):
                // Check if we have requested event or continue paginate
                if self?.event(withEventId: event.eventId) != nil {
                    completion(true)
                } else {
                    self?.paginate(till: event, completion: completion)
                }
            case .failure(_):
                completion(false)
            }
        }
    }
    
    private var paginateOperations = [MXHTTPOperation]()
    
    /// Cancels all paginate operations from calling `cancelablePaginate()`
    func stopCancellablePaginate() {
        for operation in paginateOperations {
            operation.cancel()
        }
        paginateOperations.removeAll()
    }
    
    /// Can be cancelled by calling `stopCancellablePaginate()`
    func cancelablePaginate(completion: @escaping (Result<Void, Error>) -> Void) {
        room.liveTimeline { [weak self] timeline in
            guard let timeline = timeline, let self = self else { return }
            let paginateOperation = timeline.paginate(25, direction: .backwards, onlyFromStore: false) { [weak self] response in
                self?.expectMoreHistory = timeline.canPaginate(.backwards)
                switch response {
                case .success(): completion(.success(()))
                case .failure(let error): completion(.failure(error))
                }
            }
            if let operation = paginateOperation {
                self.paginateOperations.append(operation)
            }
        }
    }
    
    // MARK: - Events management
    
    /// Indicates if it's possible to edit the event content.
    /// - Parameter eventId: The id of the event.
    /// - Returns: True to indicates edition possibility for this event.
    private func canEditEvent(withId eventId: String?) -> Bool {
        let event = self.event(withEventId: eventId)
        let isRoomMessage = event?.eventType == .roomMessage
        let messageType = event?.content["msgtype"] as? String
        
        return isRoomMessage && ((messageType == kMXMessageTypeText) || (messageType == kMXMessageTypeEmote)) && (event?.sender == userId) && (event?.roomId == room.roomId)
    }
    
    /// Indicates if replying to the provided event is supported.
    /// Only event of type 'MXEventTypeRoomMessage' are supported for the moment, and for certain msgtype.
    /// - Parameter eventId: The id of the event.
    /// - Returns: YES if it is possible to reply to this event.
    func canReplyToEvent(withId eventIdToReply: String?) -> Bool {
        let eventToReply = event(withEventId: eventIdToReply)
        return room.canReply(to: eventToReply)
    }
    
    /// Retrieve editable text message from an event.
    /// - Parameter event: An event.
    /// - Returns: Event text editable by user.
    private func editableTextMessage(for event: MXEvent?) -> String? {
        var editableTextMessage: String?
        
        if event?.isReply() == true {
            let replyEventParser = MXReplyEventParser()
            let replyEventParts = replyEventParser.parse(event!)
            
            editableTextMessage = replyEventParts.bodyParts.replyText
        } else {
            editableTextMessage = event?.content["body"] as? String
        }
        
        return editableTextMessage
    }
    
    func updateEvent(withReplace replaceEvent: MXEvent) {
        let editedEventId = replaceEvent.relatesTo.eventId
        var editedEvent: MXEvent? = nil
        
        // If not already done, update edited event content in-place
        // This is required for:
        //   - local echo
        //   - non live timeline in memory store (permalink)
        for event in eventCache {
            if event.eventId == editedEventId {
                // Check whether the event was not already edited
                if event.unsignedData.relations?.replace?.eventId != replaceEvent.eventId {
                    editedEvent = event.editedEvent(fromReplacementEvent: replaceEvent)
                }
                break
            }
        }
        
        if let editedEvent = editedEvent {
            if editedEvent.sentState != replaceEvent.sentState {
                // Relay the replace event state to the edited event so that the display
                // of the edited will rerun the classic sending color flow.
                // Note: this must be done on the main thread (this operation triggers
                // the call of [self eventDidChangeSentState])
                DispatchQueue.main.async {
                    editedEvent.sentState = replaceEvent.sentState
                }
            }
            let index = eventCache.firstIndex(where: { $0.eventId == editedEventId })
            eventCache[index!] = editedEvent
        }
    }
    
    private func removeEvent(_ eventId: String) {
        self.eventCache.removeAll { $0.eventId == eventId }
    }
    
    
    /// Replace one event by another
    /// - Parameters:
    ///   - eventToReplace: the event that will be replaced
    ///   - event: the destination event
    private func replace(_ eventToReplace: MXEvent, with event: MXEvent) {
        // Check whether the local echo is replaced or removed
        if let eventIdIndex = eventCache.firstIndex(where: { $0.eventId == event.eventId }) {
            eventCache[eventIdIndex] = self.event(withEventId: eventToReplace.eventId)!
        }
    }
    
    /// Get an event loaded in this room datasource.
    /// - Parameter eventId: of the event to retrieve.
    /// - Returns: the MXEvent object or nil if not found
    func event(withEventId eventId: String?) -> MXEvent? {
        var theEvent: MXEvent?
        theEvent = eventCache.first(where: { $0.eventId == eventId})
        return theEvent
    }
    
    func send(text: String, completion: ((String?) -> Void)? = nil) {
        guard text.hasContent else {
            completion?(nil)
            return
        }
        
        objectWillChange.send()             // room.outgoingMessages() will change
        var localEcho: MXEvent? = nil
        room.sendTextMessage(text, localEcho: &localEcho) { result in
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
            switch result {
            case .success(let id):
                completion?(id)
            case .failure(_):
                completion?(nil)
            }
        }
    }
    
    /// Send a reply to an event with text message to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - eventIdToReply: the id of event to reply.
    ///   - text: the text to send.
    ///   - success: A block object called when the operation succeeds.
    ///   It returns the event id of the event generated on the homeserver.
    ///   - failure: A block object called when the operation fails.
    func sendReplyToEvent(withId eventIdToReply: String, withTextMessage text: String, completion: ((String?) -> Void)? = nil) {
        guard let eventToReply = event(withEventId: eventIdToReply) else {
            completion?(nil)
            return
        }
        
        var localEchoEvent: MXEvent? = nil
        
        let sanitizedText = sanitizedMessageText(text)
        let html = htmlString(fromMarkdownString: sanitizedText)
        
        let stringLocalizer = MXSendReplyEventDefaultStringLocalizer()
        
        room.sendReply(to: eventToReply, textMessage: text, formattedTextMessage: html, stringLocalizer: stringLocalizer, localEcho: &localEchoEvent) { result in
            switch result {
            case .success(let id):
                completion?(id)
            case .failure(_):
                completion?(nil)
            }
        }
    }
    
    /// Gets real URL from matrix storage URI if possible
    func realUrl(from uri: String?) -> URL? {
        var realUrl: URL?
        if let urlString = session.mediaManager.url(ofContent: uri) {
            realUrl = URL(string: urlString)
        }
        return realUrl
    }
    
    // MARK: - Uploading Row Data
    
    /// Resulting data from image upload needed for MXEvent
    typealias UploadImageData = (name: String, uri: String, mimeType: String, size: CGSize, dataSize: Int)
    
    /// Compresses and uploads an image (optionally named) to the matrix storage.
    /// Passes resulting `UploadImageData` to the completion block or `nil` if failed
    func uploadImage(_ image: UIImage, named: String? = nil, completion: @escaping (UploadImageData?) -> Void) {
        guard let imageData = image.jpeg(.lowest) else {
            completion(nil)
            return
        }
        // All images are uploaded in jpeg format
        let name = named ?? "image_\(Int(image.size.width))_\(Int(image.size.height)).jpeg"
        let mimeType = "image/jpeg"
        // Will check data size when tries to upload and stop if > 50 MB
        uploadData(imageData, filename: name, mimeType: mimeType) { storageURI in
            guard let uri = storageURI else {
                completion(nil)
                return
            }
            let result = (name, uri, mimeType, image.size, imageData.count)
            completion(result)
        }
    }
    
    /// Resulting data from video upload needed for MXEvent
    typealias UploadedVideoData = (name: String, uri: String, mimeType: String, size: CGSize, duration: Double, dataSize: Int)
    
    /// Converts video file into `mp4` format and uploads it (optionally named) to the matrix storage.
    /// Passes resulting `UploadedVideoData` to the completion block or `nil` if failed
    func uploadVideo(localURL: URL, named: String? = nil, completion: @escaping (UploadedVideoData?) -> Void) {
        // MXTools will ensure max upload size (50 MB) for video
        MXTools.convertVideo(
            toMP4: localURL,
            withTargetFileSize: session.maxUploadSize,
            success: { [weak self] url, mime, size, duration in
                guard let self = self,
                      let videoURL = url,
                      let mimeType = mime,
                      let videoData = try? Data(contentsOf: videoURL)
                else {
                    completion(nil)
                    return
                }
                // All videos converted to mp4 format
                let name = named ?? videoURL.lastPathComponent
                self.uploadData(videoData, filename: name, mimeType: mimeType) { storageURI in
                    guard let uri = storageURI else {
                        completion(nil)
                        return
                    }
                    let result = (name, uri, mimeType, size, duration, videoData.count)
                    completion(result)
                }
            },
            failure: { _ in
                completion(nil)
            }
        )
    }
    
    /// Resulting data from video upload needed for MXEvent
    typealias UploadedVoiceData = (name: String, uri: String, mimeType: String, samples: [Int], duration: Int, dataSize: Int)
    
    /// Uploads voice recording with given samples and duration (optionally named) to the matrix storage.
    /// Passes resulting `UploadedVoiceData` to the completion block or `nil` if failed
    func uploadVoice(_ localURL: URL, samples: [Float], duration: Int, named: String? = nil, completion: @escaping (UploadedVoiceData?) -> Void) {
        let validSamples = samples.filter { $0 >= 0 && $0 <= 1 }.map { Int($0 * 1024) }
        guard let voiceData = try? Data(contentsOf: localURL),
              !validSamples.isEmpty,
              duration > 0
        else {
            completion(nil)
            return
        }
        // All voice recordings should be 'audio/aac', not 'audio/x-m4a'
        let name = named ?? localURL.lastPathComponent
        let mimeType = "audio/aac"
        uploadData(voiceData, filename: name, mimeType: mimeType) { storageURI in
            guard let uri = storageURI else {
                completion(nil)
                return
            }
            let result = (name, uri, mimeType, validSamples, duration, voiceData.count)
            completion(result)
        }
    }
    
    /// Uploads data (optionally named) of a given type to the matrix storage.
    /// Passes resulting URI to the completion block or `nil` if failed.
    /// Also ensures that passed data size is valid for the upload (less than 50 MB)
    private func uploadData(_ data: Data, filename: String? = nil, mimeType: String, completion: @escaping (String?) -> Void) {
        guard data.isValidUploadSize else {
            completion(nil)
            return
        }
        let uploader = MXMediaManager.prepareUploader(withMatrixSession: session, initialRange: 0, andRange: 1)
        uploader!.uploadData(
            data, filename: filename, mimeType: mimeType,
            success: { storageURI in
                completion(storageURI)
            },
            failure: { error in
                completion(nil)
            }
        )
    }
    
    // MARK: - Upload Encrypted Data
    
    
    /// Resulting data from image upload needed for MXEvent
    typealias UploadEncryptedImageData = (name: String, file: MXEncryptedContentFile, mimeType: String, size: CGSize, dataSize: Int)
    
    /// Compresses and uploads an image (optionally named) to the matrix storage.
    /// Passes resulting `UploadImageData` to the completion block or `nil` if failed
    func uploadEncryptedImage(_ image: UIImage, named: String? = nil, completion: @escaping (UploadEncryptedImageData?) -> Void) {
        guard let imageData = image.jpeg(.lowest) else {
            completion(nil)
            return
        }
        // All images are uploaded in jpeg format
        let name = named ?? "image_\(Int(image.size.width))_\(Int(image.size.height)).jpeg"
        let mimeType = "image/jpeg"
        // Will check data size when tries to upload and stop if > 50 MB
        uploadEncryptedData(imageData) { encryptedFile in
            guard let file = encryptedFile else {
                completion(nil)
                return
            }
            let result = (name, file, mimeType, image.size, imageData.count)
            completion(result)
        }
    }
    
    /// Resulting data from video upload needed for MXEvent
    typealias UploadedEncryptedVideoData = (name: String, file: MXEncryptedContentFile, mimeType: String, size: CGSize, duration: Double, dataSize: Int)
    
    /// Converts video file into `mp4` format and uploads it (optionally named) to the matrix storage.
    /// Passes resulting `UploadedVideoData` to the completion block or `nil` if failed
    func uploadEncryptedVideo(localURL: URL, named: String? = nil, completion: @escaping (UploadedEncryptedVideoData?) -> Void) {
        // MXTools will ensure max upload size (50 MB) for video
        MXTools.convertVideo(
            toMP4: localURL,
            withTargetFileSize: session.maxUploadSize,
            success: { [weak self] url, mime, size, duration in
                guard let self = self,
                      let videoURL = url,
                      let mimeType = mime,
                      let videoData = try? Data(contentsOf: videoURL)
                else {
                    completion(nil)
                    return
                }
                // All videos converted to mp4 format
                let name = named ?? videoURL.lastPathComponent
                self.uploadEncryptedData(videoData) { encryptedFile in
                    guard let file = encryptedFile else {
                        completion(nil)
                        return
                    }
                    let result = (name, file, mimeType, size, duration, videoData.count)
                    completion(result)
                }
            },
            failure: { _ in
                completion(nil)
            }
        )
    }
    
    // MARK: - Encryption
    
    /// `true` when we have module for E2E encryption and room is set to be encrypted
    var shouldEncrypt: Bool {
        (session.crypto != nil) && summary.isEncrypted
    }
    
    /// `Encrypts` and uploads data to the matrix storage.
    /// Passes resulting EncryptedFile to the completion block or `nil` if failed.
    /// Also ensures that passed data size is valid for the upload (less than 50 MB)
    private func uploadEncryptedData(_ data: Data, completion: @escaping (MXEncryptedContentFile?) -> Void) {
        guard data.isValidUploadSize else {
            completion(nil)
            return
        }
        let uploader = MXMediaManager.prepareUploader(withMatrixSession: session, initialRange: 0, andRange: 1)
        MXEncryptedAttachments.encryptAttachment(uploader, data: data) { file in
            completion(file)
        } failure: { error in
            completion(nil)
        }
    }
    
    // MARK: - Combined Post Header
    
    /// Sends a specific message that will be treated as header event for the combined post.
    /// Passes resulting event id in the completion block or `nil` if failed
    func sendPostHeader(completion: @escaping (String?) -> Void) {
        let content = getContent(for: "gRoUp\r\n2")
        var localEchoEvent: MXEvent? = nil
        room.sendEvent(.roomMessage, content: content, localEcho: &localEchoEvent) { response in
            switch response {
            case .success(let text):
                // print("Success with response: \(text ?? "nil")")
                completion(text)
            case .failure(_):
                // print("Failure with error \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - New Reply System
    
    /// Sends a text message as a reply to a given event id.
    /// Passes resulting event id in the completion block or `nil` if failed
    func reply(to eventId: String, with text: String, completion: ((String?) -> Void)? = nil) {
        var content = getContent(for: text)
        content = addReplyPart(for: content, with: eventId)
        sendMessage(content: content) { [weak self] id in
            self?.objectWillChange.send()
            completion?(id)
        }
    }
    
    /// Sends an image (optionally named) message as a reply to a given event id.
    /// Passes resulting event id in the completion block or `nil` if failed
    func reply(to eventId: String, with image: UIImage, named: String? = nil, completion: ((String?) -> Void)? = nil) {
        if shouldEncrypt {
            uploadEncryptedImage(image, named: named) { [weak self] uploadResult in
                guard let self = self,
                      let uploadedImage = uploadResult else {
                    completion?(nil)
                    return
                }
                var content = self.getContent(for: uploadedImage, named: uploadedImage.name)
                content = self.addReplyPart(for: content, with: eventId)
                self.sendMessage(content: content) { [weak self] id in
                    self?.objectWillChange.send()
                    completion?(id)
                }
            }
        } else {
            uploadImage(image, named: named) { [weak self] uploadResult in
                guard let self = self,
                      let uploadedImage = uploadResult else {
                    completion?(nil)
                    return
                }
                var content = self.getContent(for: uploadedImage, named: uploadedImage.name)
                content = self.addReplyPart(for: content, with: eventId)
                self.sendMessage(content: content) { [weak self] id in
                    self?.objectWillChange.send()
                    completion?(id)
                }
            }
        }
    }
    
    /// Sends a video (optionally named) message as a reply to a given event id.
    /// Passes resulting event id in the completion block or `nil` if failed
    func reply(to eventId: String, with videoURL: URL, thumbnail: UIImage, named: String? = nil, completion: ((String?) -> Void)? = nil) {
        if shouldEncrypt {
            uploadEncryptedVideo(localURL: videoURL, named: named) { [weak self] videoUpload in
                guard let self = self,
                      let uploadedVideo = videoUpload else {
                    completion?(nil)
                    return
                }
                self.uploadEncryptedImage(thumbnail) { [weak self] imageUpload in
                    guard let self = self,
                          let uploadedImage = imageUpload else {
                        completion?(nil)
                        return
                    }
                    var content = self.getContent(for: uploadedVideo, thumbnail: uploadedImage, named: uploadedVideo.name)
                    content = self.addReplyPart(for: content, with: eventId)
                    self.sendMessage(content: content) { [weak self] id in
                        self?.objectWillChange.send()
                        completion?(id)
                    }
                }
            }
        } else {
            uploadVideo(localURL: videoURL, named: named) { [weak self] videoUpload in
                guard let self = self,
                      let uploadedVideo = videoUpload else {
                    completion?(nil)
                    return
                }
                self.uploadImage(thumbnail) { [weak self] imageUpload in
                    guard let self = self,
                          let uploadedImage = imageUpload else {
                        completion?(nil)
                        return
                    }
                    var content = self.getContent(for: uploadedVideo, thumbnail: uploadedImage, named: uploadedVideo.name)
                    content = self.addReplyPart(for: content, with: eventId)
                    self.sendMessage(content: content) { [weak self] id in
                        self?.objectWillChange.send()
                        completion?(id)
                    }
                }
            }
        }
    }
    
    /// Sends a voice recording with samples and duration (optionally named) as a reply to a given event id.
    /// Passes resulting event id in the completion block or `nil` if failed
    func reply(to eventId: String, with voiceURL: URL, samples: [Float], duration: Int, named: String? = nil, completion: ((String?) -> Void)? = nil) {
        guard !shouldEncrypt else {
            completion?(nil)
            return
        }
        uploadVoice(voiceURL, samples: samples, duration: duration, named: named) { [weak self] uploadResult in
            guard let self = self,
                  let uploadedVoice = uploadResult else {
                completion?(nil)
                return
            }
            var content = self.getContent(for: uploadedVoice, named: uploadedVoice.name)
            content = self.addReplyPart(for: content, with: eventId)
            self.sendMessage(content: content) { [weak self] id in
                self?.objectWillChange.send()
                completion?(id)
            }
        }
    }
    
    /// Sends a message with a given content.
    /// Passes resulting event id in the completion block or `nil` if failed
    private func sendMessage(content: [String: Any], completion: ((String?) -> Void)? = nil) {
        var localEchoEvent: MXEvent? = nil
        room.sendEvent(.roomMessage, content: content, localEcho: &localEchoEvent) { response in
            switch response {
            case .success(let text):
                // print("Success with response: \(text ?? "nil")")
                completion?(text)
            case .failure(_):
                // print("Failure with error \(error)")
                completion?(nil)
            }
        }
    }
    
    // MARK: - Handmade Message Content
    
    /// Returns content dictionary for a text message
    private func getContent(for text: String) -> [String: Any] {
        return [
            "body": text,
            "msgtype": "m.text"
        ]
    }
    
    // MARK: Voice
    
    /// Returns content dictionary for a voice message
    private func getContent(for uploadedVoice: UploadedVoiceData, named: String) -> [String: Any] {
        return [
            "body": named,
            "url": uploadedVoice.uri,
            "msgtype": "m.audio",
            "info": [
                // Not sure, but we get 0 duration here,
                // Actual voice duration below is below
                "duration": 0,
                "mimetype": uploadedVoice.mimeType,
                "size": uploadedVoice.dataSize,
            ],
            "org.matrix.msc1767.audio": [
                "duration": uploadedVoice.duration,
                "waveform": uploadedVoice.samples
            ],
            // This should be empty "org.matrix.msc3245.voice": { }
            "org.matrix.msc3245.voice": [String: Any]()
        ]
    }
    
    // MARK: Image
    
    /// Returns content dictionary for an image message
    private func getContent(for uploadedImage: UploadImageData, named: String) -> [String: Any] {
        return [
            "body": named,
            "url": uploadedImage.uri,
            "info": [
                "w": Int(uploadedImage.size.width),
                "h": Int(uploadedImage.size.height),
                "mimetype": uploadedImage.mimeType,
                "size": uploadedImage.dataSize
            ],
            "msgtype": "m.image"
        ]
    }
    
    /// Returns content dictionary for an image message
    private func getContent(for uploadedImage: UploadEncryptedImageData, named: String) -> [String: Any] {
        var imageDict = uploadedImage.file.jsonDictionary()!
        imageDict["mimetype"] = uploadedImage.mimeType
        return [
            "msgtype": "m.image",
            "body": named,
            "info": [
                "w": Int(uploadedImage.size.width),
                "h": Int(uploadedImage.size.height),
                "mimetype": uploadedImage.mimeType,
                "size": uploadedImage.dataSize
            ],
            "file": imageDict
        ]
        /* ENCRYPTED IMAGE
         [
             "msgtype": m.image,
             "body": 123140104-12312415.png,
             "info": {
                 w = 1079;
                 h = 1619;
                 mimetype = "image/jpeg";
                 size = 1463355;
             },
             "file": {
                 hashes =     {
                     sha256 = "9GIO7iQ8s1y2IwfastEf4vifwQxqEb50aTRLFOTjW+Q";
                 };
                 iv = Y5DjXPXCv6UAAAAAAAAAAA;
                 key =     {
                     alg = A256CTR;
                     ext = 1;
                     k = 4uHcIinE7c8izY9cL9gMdI4PeSAGoZAR0iNxPBYNkOc;
                     "key_ops" =         (
                         encrypt,
                         decrypt
                     );
                     kty = oct;
                 };
                 mimetype = "image/jpeg";
                 url = "mxc://allgram.me/SPUmqWpqIxCXptEqcFjLCyAn";
                 v = v2;
             }
         ]
         */
    }
    
    // MARK: Video
    
    private func getContent(for uploadedVideo: UploadedVideoData, thumbnail: UploadImageData, named: String) -> [String: Any] {
        return [
            "body": named,
            "url": uploadedVideo.uri,
            "info": [
                "duration": Int(uploadedVideo.duration),
                "w": Int(uploadedVideo.size.width),
                "h": Int(uploadedVideo.size.height),
                "mimetype": uploadedVideo.mimeType,
                "size": uploadedVideo.dataSize,
                "thumbnail_info": [
                    "w": Int(thumbnail.size.width),
                    "h": Int(thumbnail.size.height),
                    "mimetype": thumbnail.mimeType,
                    "size": thumbnail.dataSize
                ],
                "thumbnail_url": thumbnail.uri
            ],
            "msgtype": "m.video"
        ]
    }
    
    private func getContent(for uploadedVideo: UploadedEncryptedVideoData, thumbnail: UploadEncryptedImageData, named: String) -> [String: Any] {
        var videoDict = uploadedVideo.file.jsonDictionary()!
        videoDict["mimetype"] = uploadedVideo.mimeType
        var thumbnailDict = thumbnail.file.jsonDictionary()!
        thumbnailDict["mimetype"] = thumbnail.mimeType
        return [
            "msgtype": "m.video",
            "body": named,
            "info": [
                "duration": Int(uploadedVideo.duration),
                "w": Int(uploadedVideo.size.width),
                "h": Int(uploadedVideo.size.height),
                "mimetype": uploadedVideo.mimeType,
                "size": uploadedVideo.dataSize,
                "thumbnail_file": thumbnailDict,
                "thumbnail_info": [
                    "w": Int(thumbnail.size.width),
                    "h": Int(thumbnail.size.height),
                    "mimetype": thumbnail.mimeType,
                    "size": thumbnail.dataSize
                ]
            ],
            "file": videoDict
        ]
        /* ENCRYPTED VIDEO
         [
             "msgtype": m.video,
             "body": 20220926-153538.mp4,
             "info": {
                 duration = 0;
                 w = 1280;
                 h = 720;
                 mimetype = "video/mp4";
                 size = 672234;
                 "thumbnail_file" =     {
                     hashes =         {
                         sha256 = "9a3Kfo7kC/agBdSbEmh8HUT8tstwvPw243irNJFHhGc";
                     };
                     iv = wuNrx1hROBUAAAAAAAAAAA;
                     key =         {
                         alg = A256CTR;
                         ext = 1;
                         k = H8A9P3pJKW1711roKQJBAVBgWSDC5hLYMiaFyREZwcM;
                         "key_ops" =             (
                             encrypt,
                             decrypt
                         );
                         kty = oct;
                     };
                     mimetype = "image/jpeg";
                     url = "mxc://allgram.me/WjmHtIxgzsAedhYHnAMEBeAw";
                     v = v2;
                 };
                 "thumbnail_info" =     {
                     w = 1280;
                     h = 720;
                     mimetype = "image/jpeg";
                     size = 509750;
                 };
             },
             "file": {
                 hashes =     {
                     sha256 = "Jb5qWi3G8oRt6fbE40uVNZDj16vtvAT/46nJT1isP04";
                 };
                 iv = XyeglcQ0tLsAAAAAAAAAAA;
                 key =     {
                     alg = A256CTR;
                     ext = 1;
                     k = "6V0gEVtVaZ7UnD7OiOjM0WuioKJPq9yu_CsPTboIMms";
                     "key_ops" =         (
                         encrypt,
                         decrypt
                     );
                     kty = oct;
                 };
                 mimetype = "video/mp4";
                 url = "mxc://allgram.me/LgWFEqImZmMAvPvvMKIGyHqu";
                 v = v2;
             }
         ]
         */
    }
    
    // MARK: Reply
    
    /// Adds replying part to a given content dictionary
    private func addReplyPart(for content: [String: Any], with eventId: String) -> [String: Any] {
        var result = content
        result["m.relates_to"] = [
            "m.in_reply_to": [
                "event_id": eventId
            ]
        ]
        return result
    }
    
    // MARK: -
    
    /// Convert a Markdown string to HTML.
    /// - Parameter markdownString: the string to convert.
    /// - Returns: an HTML formatted string.
    var markdownToHTMLRenderer: MarkdownToHTMLRendererProtocol?
    func htmlString(fromMarkdownString markdownString: String?) -> String? {
        var htmlString = markdownToHTMLRenderer?.renderToHTML(markdown: markdownString ?? "")
        
        // Strip off the trailing newline, if it exists.
        if htmlString?.hasSuffix("\n") ?? false {
            htmlString = (htmlString as NSString?)?.substring(to: (htmlString?.count ?? 0) - 1)
        }
        
        // Strip start and end <p> tags else you get 'orrible spacing.
        // But only do this if it's a single paragraph we're dealing with,
        // otherwise we'll produce some garbage (`something</p><p>another`).
        if htmlString?.hasPrefix("<p>") ?? false && htmlString?.hasSuffix("</p>") ?? false {
            let components = htmlString?.components(separatedBy: "<p>")
            let paragrapsCount = (components?.count ?? 0) - 1
            
            if paragrapsCount == 1 {
                htmlString = (htmlString as NSString?)?.substring(from: 3)
                htmlString = (htmlString as NSString?)?.substring(to: (htmlString?.count ?? 0) - 4)
            }
        }
        
        return htmlString
    }
    
    /// Emote slash command prefix @"/me "
    private var emoteMessageSlashCommandPrefix: String = "/me"
    
    private func isMessageAnEmote(_ text: String?) -> Bool {
        return text?.hasPrefix(emoteMessageSlashCommandPrefix) ?? false
    }
    
    private func sanitizedMessageText(_ rawText: String) -> String? {
        var text: String?
        
        //Remove NULL bytes from the string, as they are likely to trip up many things later,
        //including our own C-based Markdown-to-HTML convertor.
        //
        //Normally, we don't expect people to be entering NULL bytes in messages,
        //but because of a bug in iOS 11, it's easy to have it happen.
        //
        //iOS 11's Smart Punctuation feature "conveniently" converts double hyphens (`--`) to longer en-dashes (`—`).
        //However, when adding any kind of dash/hyphen after such an en-dash,
        //iOS would also insert a NULL byte inbetween the dashes (`<en-dash>NULL<some other dash>`).
        //
        //Even if a future iOS update fixes this,
        //we'd better be defensive and always remove occurrences of NULL bytes from text messages.
        text = rawText.replacingOccurrences(of: "\(0x00000000)", with: "")
        
        // Check whether the message is an emote
        if isMessageAnEmote(text) {
            // Remove "/me " string
            text = (text as NSString?)?.substring(from: emoteMessageSlashCommandPrefix.count)
        }
        
        return text
    }
    
    /// Adds a reaction to a given event (expects a single emoji).
    /// Passes `true` to the completion handler on success and `false` on failure
    func react(toEventId eventId: String, emoji: String, completion: ((Bool) -> Void)? = nil) {
        let content = try! ReactionEvent(eventId: eventId, key: emoji).encodeContent()
        objectWillChange.send()             // room.outgoingMessages() will change
        var localEcho: MXEvent? = nil
        room.sendEvent(.reaction, content: content, localEcho: &localEcho) { result in
            switch result {
            case .success: completion?(true)
            case .failure: completion?(false)
            }
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
        }
    }
    
    func edit(text: String, eventId: String) {
        
        var localEcho: MXEvent? = nil
        // swiftlint:disable:next force_try
        let content = try! EditEvent(eventId: eventId, text: text).encodeContent()
        // TODO: Use localEcho to show sent message until it actually comes back
        objectWillChange.send()
        room.sendMessage(withContent: content, localEcho: &localEcho) { response in
            switch response {
            case .success(_):
                self.updateEvent(withReplace: localEcho!)
                self.objectWillChange.send()
                case .failure(_):break
                
            }
        }
    }
    
    /// Sends a redact event (basically deletes another event) with optional reason.
    /// Passes `true` to the completion handler on success and `false` on failure 
    func redact(eventId: String, reason: String?, completion: ((Bool) -> Void)? = nil) {
        guard let _ = event(withEventId: eventId) else {
            completion?(false)
            return
        }
        objectWillChange.send()
        room.redactEvent(eventId, reason: reason) { response in
            switch response {
            case .success():
                self.removeEvent(eventId)
                // Remove the event from the outgoing messages storage
                self.room.removeOutgoingMessage(eventId)
                self.objectWillChange.send()
                completion?(true)
            case .failure(_):
                self.objectWillChange.send()
                completion?(false)
            }
        }
    }
    
    // MARK: - Sending Media
    
    /// Sends a file message with data provided by local URL.
    /// Provides `true` to completion handler if successful
    func sendFile(localURL: URL, completion: ((Bool) -> Void)? = nil) {
        var localEcho: MXEvent? = nil
        objectWillChange.send()             // room.outgoingMessages() will change
        room.sendFile(
            localURL: localURL,
            mimeType: localURL.mimeType,
            localEcho: &localEcho
        ) { response in
            completion?(response.isSuccess)
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
        }
    }
    
    /// Sends a message, compressing given image.
    /// Provides `true` to completion handler if successful
    func sendImage(image: UXImage, completion: ((Bool) -> Void)? = nil) {
        guard let imageData = image.jpeg(.lowest) else { return }
        var localEcho: MXEvent? = nil
        objectWillChange.send()             // room.outgoingMessages() will change
        room.sendImage(
            data: imageData,
            size: image.size,
            mimeType: "image/jpeg",
            thumbnail: image,
            blurhash: nil,
            localEcho: &localEcho
        ) { response in
            completion?(response.isSuccess)
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
        }
    }
    
    /// Sends a message, uploading video from given local url and optional thumbnail.
    /// Provides `true` to completion handler if successful
    func sendVideo(url: URL, thumbnail: MXImage?, completion: ((Bool) -> Void)? = nil) {
        var localEcho: MXEvent? = nil
        objectWillChange.send()             // room.outgoingMessages() will change
        room.sendVideo(
            localURL: url,
            thumbnail: thumbnail,
            localEcho: &localEcho
        ) { response in
            completion?(response.isSuccess)
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
        }
    }
    
    /// Sends a audio message with data provided by local URL.
    /// Provides `true` to completion handler if successful
    func sendAudio(url: URL, completion: ((Bool) -> Void)? = nil) {
        var localEcho: MXEvent? = nil
        objectWillChange.send()             // room.outgoingMessages() will change
        room.sendAudioFile(
            localURL: url,
            mimeType: url.mimeType,
            localEcho: &localEcho
        ) { response in
            completion?(response.isSuccess)
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
        }
    }
    
    /// Send a voice message to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - audioFileLocalURL: the local filesystem path of the audio file to send.
    ///   - mimeType: (optional) the mime type of the file. Defaults to `audio/ogg`
    ///   - duration: the length of the voice message in milliseconds
    ///   - samples: an array of floating point values normalized to [0, 1], boxed within NSNumbers
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendVoiceMessage(
        didRequestSendForFileAtURL audioFileLocalURL: URL?,
        duration: Int,
        samples: [Float]?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = audioFileLocalURL else { return }
        var localEcho: MXEvent? = nil
        objectWillChange.send()             // room.outgoingMessages() will change
        room.sendVoiceMessage(
            localURL: url,
            mimeType: url.mimeType,
            duration: UInt(duration),
            samples: samples,
            localEcho: &localEcho
        ) { response in

            switch response {
            case .success(let id):
                completion(.success(id ?? "nil"))
            case .failure(let error):
                completion(.failure(error))
            }
            self.objectWillChange.send()    // localEcho.sentState has(!) changed
        }
    }
    
    // MARK: -
    
    func markAllAsRead() {
        room.markAllAsRead()
    }
    
    func removeOutgoingMessage(_ event: MXEvent) {
        objectWillChange.send()             // room.outgoingMessages() will change
        room.removeOutgoingMessage(event.eventId)
    }
    
    private func registerEventEditsListener() {
        if eventEditsListener != nil {
            return
        }
        
        eventEditsListener = session.aggregations.listenToEditsUpdate(inRoom: room.roomId) { [self] replaceEvent in
            
            updateEvent(withReplace: replaceEvent)
        }
    }
    
    private func listenEvents() {
        room.liveTimeline { [weak self] timeline in
            guard let timeline = timeline, let self = self else { return }
            timeline.resetPagination()
            self.eventCache.removeAll()
            self.eventListener = timeline.listenToEvents(nil, { [weak self] event, direction, roomState in
                guard let self = self else { return }
                self.add(event: event, direction: direction, roomState: roomState)
            })
            timeline.paginate(40, direction: .backwards, onlyFromStore: false) { response in
            }
        }
    }
    
    private func deleteFailedOutgoingMessages() {
        guard let messages = self.room.outgoingMessages() else {
            return
        }
        for msg in messages {
            if msg.isLocalEvent() && msg.sentState == MXEventSentStateFailed {
                room.removeOutgoingMessage(msg.eventId)
            }
        }
    }
    
    private var typingDateToCheck : Date?
    private var lastTypingDate : Date?
    private var typingTimer : Timer?
    
    func sendTypingNotification(typing: Bool) {
        if !typing {
            self.typingTimer?.invalidate()
            sendTypingNotificationUnconditionally(typing: false, timeout: 0)
            typingDateToCheck = nil
            lastTypingDate = nil
            return
        }
        let kTimeout : TimeInterval = 1.0
        if let lastDate = lastTypingDate {
            let checkDate = typingDateToCheck ?? (lastDate + kTimeout)
            if Date() < checkDate {
                lastTypingDate = Date()
                return
            }
        }
        lastTypingDate = Date()
        scheduleTypingTimer(remainingTimeout: kTimeout, timeout: kTimeout)
        sendTypingNotificationUnconditionally(typing: true, timeout: 2 * kTimeout)
    }
    
    private func scheduleTypingTimer(remainingTimeout: TimeInterval, timeout: TimeInterval) {
        self.typingDateToCheck = Date(timeIntervalSinceNow: remainingTimeout)
        self.typingTimer?.invalidate()
        self.typingTimer = .scheduledTimer(withTimeInterval: remainingTimeout, repeats: false) { timer in
            guard let lastDate = self.lastTypingDate else {
                return
            }
            let t = lastDate.timeIntervalSinceNow + timeout
            if t > 0 {
                self.scheduleTypingTimer(remainingTimeout: t, timeout: timeout)
                self.sendTypingNotificationUnconditionally(typing: true, timeout: 2 * t)
            } else {
                self.sendTypingNotificationUnconditionally(typing: false, timeout: 0)
                self.typingDateToCheck = nil
                self.lastTypingDate = nil
            }
        }
    }
    
    private func sendTypingNotificationUnconditionally(typing: Bool, timeout: TimeInterval) {
        room.sendTypingNotification(typing: typing, timeout: timeout) { response in
        }
    }
    
    func moveReadMarker(to event: MXEvent) {
        //Move readmarker just on alien messages
        if event.sender != userId {
            room.moveReadMarker(toEventId: event.eventId)
        }
    }
    
    /// This method is called for each read receipt event received in forward mode.
    /// By default, it tells the delegate that some cell data/views have been changed.
    /// You may override this method to handle the receipt event according to the application needs.
    /// You should not call this method directly.
    /// You may override it in inherited 'RoomViewModel' class.
    /// - Parameters:
    ///   - receiptEvent: an event with 'm.receipt' type.
    ///   - roomState: the room state right before the event
    func didReceiveReceiptEvent(_ receiptEvent: MXEvent?, roomState: MXRoomState?) {
        // Remove the previous displayed read receipt for each user who sent a
        // new read receipt.
        // To implement it, we need to find the sender id of each new read receipt
        // among the read receipts array of all events in all bubbles.
        guard let readReceiptSenders = receiptEvent?.readReceiptSenders() as? [String] else { return }
        
        var updatedReadReceipts: [String /* eventId */ : [MXReceiptData]] = [:]
        
        for (eventId, dataArray) in readReceipts {
            for receiptData in dataArray {
                if readReceiptSenders.contains(receiptData.userId) {
                    if updatedReadReceipts[eventId] == nil {
                        updatedReadReceipts[eventId] = dataArray
                    }
                    updatedReadReceipts[eventId]?.removeAll(where: { $0.userId == receiptData.userId })
                }
            }
        }
        
        // Flush found changed to the readReceipts
        for (eventId, dataArray) in updatedReadReceipts {
            let arrayOrNil = dataArray.isEmpty ? nil : dataArray
            updateReadReceipts(withReadReceipts: arrayOrNil, forEventId: eventId)
        }
        
        // Update data we have received a read receipt for
        let readEventIds = receiptEvent?.readReceiptEventIds() as? [String] ?? []
        for eventId in readEventIds {
            addReadReceipts(forEvent: eventId)
        }
    }
    
    /// Update read receipts for an event in a bubble cell data.
    /// - Parameters:
    ///   - readReceipts: The new read receipts.
    ///   - eventId: The id of the event.
    private func updateReadReceipts(withReadReceipts readReceipts: [MXReceiptData]?, forEventId eventId: String) {
        self.readReceipts[eventId] = readReceipts
    }
    
    /// Add the read receipts of an event into the timeline (which is in array of events)
    /// If the event is not displayed, read receipts will be added to a previous displayed message.
    /// - Parameters:
    ///   - eventId: the id of the event.
    func addReadReceipts(forEvent eventId: String) {
        guard let eventIndex = eventCache.firstIndex(where: { $0.eventId == eventId }) else { return }
        let eventContainsBody = (eventCache[eventIndex].content["body"] as? String) != nil
        
        room.getEventReceipts(eventId, sorted: true) { [weak self] eventReceipts in
            guard let self = self, eventContainsBody else { return }
            if let oldReceipts = self.readReceipts[eventId] {
                let oldUserIds = Set(oldReceipts.map { $0.userId } )
                let unconflictingNew = eventReceipts.filter { !oldUserIds.contains($0.userId) }
                self.updateReadReceipts(withReadReceipts: eventReceipts + unconflictingNew, forEventId: eventId)
            } else {
                self.updateReadReceipts(withReadReceipts: eventReceipts, forEventId: eventId)
            }
        }
    }
    
    func isReadedState(for eventId: String) -> Bool {
        guard let _ = readReceipts[eventId] else { return false }
        return true
    }
}

extension AllgramRoom: Identifiable {
    var id: ObjectIdentifier {
        room.id
    }
}

extension UXImage {
    public enum JPEGQuality: CGFloat {
        case lowest  = 0
        case low     = 0.25
        case medium  = 0.5
        case high    = 0.75
        case highest = 1
    }
    
    public func jpeg(_ jpegQuality: JPEGQuality) -> Data? {
        return jpegData(compressionQuality: jpegQuality.rawValue)
    }
}
