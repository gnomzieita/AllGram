//
//  RoomViewModel.swift
//  AllGram
//
//  Created by Serg Basin on 17.09.2021.
//

import Foundation

//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import MatrixSDK
import UIKit

/// Define the threshold which triggers a bubbles count flush.
let MXKROOMDATASOURCE_CACHED_BUBBLES_COUNT_THRESHOLD = 30

/// Define the number of messages to preload around the initial event.
let MXKROOMDATASOURCE_PAGINATION_LIMIT_AROUND_INITIAL_EVENT = 30

/// List the supported pagination of the rendered room bubble cells
enum MXKRoomDataSourceBubblesPagination : Int {
    /// No pagination
    case none
    /// The rendered room bubble cells are paginated per day
    case perDay
}

// MARK: - Cells identifiers

/// String identifying the object used to store and prepare room bubble data.// MARK: - Notifications

/// Posted when a server sync starts or ends (depend on 'serverSyncEventCount').
/// The notification object is the `RoomViewModel` instance./// Posted when the data source has failed to paginate around an event.
/// The notification object is the `RoomViewModel` instance. The `userInfo` dictionary contains the following key:
/// - kMXKRoomDataTimelineErrorErrorKey: The NSError./// Notifications `userInfo` keys// MARK: - Constant definitions
let kMXKRoomBubbleCellDataIdentifier = "kMXKRoomBubbleCellDataIdentifier"
let kMXKRoomDataSourceSyncStatusChanged = "kMXKRoomDataSourceSyncStatusChanged"
let kMXKRoomDataSourceFailToLoadTimelinePosition = "kMXKRoomDataSourceFailToLoadTimelinePosition"
let kMXKRoomDataSourceTimelineError = "kMXKRoomDataSourceTimelineError"
let kMXKRoomDataSourceTimelineErrorErrorKey = "kMXKRoomDataSourceTimelineErrorErrorKey"
let MXKRoomDataSourceErrorDomain = "kMXKRoomDataSourceErrorDomain"

enum RoomDataSourceError : Int {
    case resendGeneric = 10001
    case resendInvalidMessageType = 10002
    case resendInvalidLocalFilePath = 10003
}

/// List data source states.
enum DataSourceState : Int {
    /// Default value (used when all resources have been disposed).
    /// The instance cannot be used anymore.
    case unknown
    /// Initialisation is in progress.
    case preparing
    /// Something wrong happens during initialisation.
    case failed
    /// Data source is ready to be used.
    case ready
}

extension MXSessionState {
    var storeDataReady: Bool {
        switch self.rawValue {
        case 2...:
            return true
        default:
            return false
        }
    }
}

// MARK: - RoomViewModel
/// The data source for `RoomView`.
class RoomViewModel: ObservableObject {
    /// The mapping between cell identifiers and CellData classes.
    private var cellDataMap: [AnyHashable : Any]? = [:]
    /// The matrix session.
    private(set) var mxSession: MXSession? {
        get {
            return self.mxSession
        }
        set {
            if newValue != nil {
                self.mxSession = newValue
                self.state = .preparing
            }
        }
    }
    /// The data source state
    private(set) var state: DataSourceState! = .unknown
    /// The data for the cells served by `RoomViewModel`.
    var bubbles: [RoomBubbleCellProtocol]?
    /// The queue of events that need to be processed in order to compute their display.
    var eventsToProcess: [QueuedEvent]?
    /// The dictionary of the related groups that the current user did not join.
    var externalRelatedGroups: [String : MXGroup]?

    /// If the data is not from a live timeline, `initialEventId` is the event in the past
    /// where the timeline starts.
    private var initialEventId: String?
    /// Current pagination request (if any)
    private var paginationRequest: MXHTTPOperation?
    /// The actual listener related to the current pagination in the timeline.
    private var paginationListener: Any?
    /// The listener to incoming events in the room.
    private var liveEventsListener: Any?
    /// The listener to redaction events in the room.
    private var redactionListener: Any?
    /// The listener to receipts events in the room.
    private var receiptsListener: Any?
    /// The listener to the related groups state events in the room.
    private var relatedGroupsListener: Any?
    /// The listener to reactions changed in the room.
    private var reactionsChangeListener: Any?
    /// The listener to edits in the room.
    private var eventEditsListener: Any?
    /// Current secondary pagination request (if any)
    private var secondaryPaginationRequest: MXHTTPOperation?
    /// The listener to incoming events in the secondary room.
    private var secondaryLiveEventsListener: Any?
    /// The listener to redaction events in the secondary room.
    private var secondaryRedactionListener: Any?
    /// The actual listener related to the current pagination in the secondary timeline.
    private var secondaryPaginationListener: Any?
    /// Mapping between events ids and bubbles.
    private var eventIdToBubbleMap: [AnyHashable : Any]?
    /// Typing notifications listener.
    private var typingNotifListener: Any?
    /// List of members who are typing in the room.
    private var currentTypingUsers: [AnyHashable]?
    /// Snapshot of the queued events.
    private var eventsToProcessSnapshot: [AnyHashable]?
    /// Snapshot of the bubbles used during events processing.
    private var bubblesSnapshot: [RoomBubbleCellProtocol]?
    /// The room being peeked, if any.
    private var peekingRoom: MXPeekingRoom?
    /// If any, the non terminated series of collapsable events at the start of self.bubbles.
    /// (Such series is determined by the cell data of its oldest event).
    private weak var collapsableSeriesAtStart: RoomBubbleCellProtocol?
    /// If any, the non terminated series of collapsable events at the end of self.bubbles.
    /// (Such series is determined by the cell data of its oldest event).
    private weak var collapsableSeriesAtEnd: RoomBubbleCellProtocol?
    /// Observe UIApplicationSignificantTimeChangeNotification to trigger cell change on time formatting change.
    private var UIApplicationSignificantTimeChangeNotificationObserver: Any?
    /// Observe NSCurrentLocaleDidChangeNotification to trigger cell change on time formatting change.
    private var NSCurrentLocaleDidChangeNotificationObserver: Any?
    /// Observe kMXRoomDidFlushDataNotification to trigger cell change when existing room history has been flushed during server sync.
    private var roomDidFlushDataNotificationObserver: Any?
    /// Observe kMXRoomDidUpdateUnreadNotification to refresh unread counters.
    private var roomDidUpdateUnreadNotificationObserver: Any?
    /// Emote slash command prefix @"/me "
    private var emoteMessageSlashCommandPrefix: String?

    /// The id of the room managed by the data source.
    private(set) var roomId: String?
    /// The id of the secondary room managed by the data source. Events with specified types from the secondary room will be provided from the data source.
    /// - seealso: `secondaryRoomEventTypes`.
    /// Can be nil
    private var _secondaryRoomId: String?
    var secondaryRoomId: String? {
        get {
            _secondaryRoomId
        }
        set(secondaryRoomId) {
            if _secondaryRoomId != secondaryRoomId {
                _secondaryRoomId = secondaryRoomId

                if state == .ready {
                    self.reload()
                }
            }
        }
    }
    /// Types of events to include from the secondary room. Default is all call events.

    private var _secondaryRoomEventTypes: [MXEventTypeString]?
    var secondaryRoomEventTypes: [MXEventTypeString]? {
        get {
            _secondaryRoomEventTypes
        }
        set(secondaryRoomEventTypes) {
            if _secondaryRoomEventTypes != secondaryRoomEventTypes {
                _secondaryRoomEventTypes = secondaryRoomEventTypes

                if state == .ready {
                    self.reload()
                }
            }
        }
    }
    /// The room the data comes from.
    /// The object is defined when the MXSession has data for the room
    private(set) var room: MXRoom?
    
    /// The preloaded room.state
    var roomState: MXRoomState? {
        // @TODO(async-state): Just here for dev
        return timeline?.state
    }
    /// The timeline being managed. It can be the live timeline of the room
    /// or a timeline from a past event, initialEventId.
    private(set) var timeline: MXEventTimeline?
    /// Flag indicating if the data source manages, or will manage, a live timeline.
    private(set) var isLive = false
    /// Flag indicating if the data source is used to peek into a room, ie it gets data from
    /// a room the user has not joined yet.
    private(set) var isPeeking = false
    /// The list of the attachments with thumbnail in the current available bubbles (MXKAttachment instances).
    /// Note: the stickers are excluded from the returned list.
    /// Note2: the attachments for which the antivirus scan status is not available are excluded too.

    var attachmentsWithThumbnail: [Attachment]? {
        var attachments: [Attachment] = []

        let lockQueue = DispatchQueue(label: "bubbles")
        lockQueue.sync {
            for bubbleData in bubbles ?? [] {
                if bubbleData.isAttachmentWithThumbnail && bubbleData.attachment?.type != .sticker && !bubbleData.showAntivirusScanStatus {
                    attachments.append(bubbleData.attachment!)//.append(bubbleData.attachment)
                }
            }
        }

        return attachments
    }
    /// The events are processed asynchronously. This property counts the number of queued events
    /// during server sync for which the process is pending.
    private(set) var serverSyncEventCount = 0
    /// The current text message partially typed in text input (use nil to reset it).

    private var _partialTextMessage: String?
    var partialTextMessage: String? {
        get {
            return room?.partialTextMessage
        }
        set(partialTextMessage) {
            room?.partialTextMessage = partialTextMessage
        }
    }
    // MARK: - Configuration
    /// The text formatter applied on the events.
    /// By default, the events are filtered according to the value stored in the shared application settings (see [MXKAppSettings standardAppSettings].eventsFilterForMessages).
    /// The events whose the type doesn't belong to the this list are not displayed.
    /// `RoomBubbleCellProtocol` instances can use it to format text.

    private var _eventFormatter: EventFormatter?
    var eventFormatter: EventFormatter? {
        get {
            _eventFormatter
        }
        set(eventFormatter) {
            if let _eventFormatter = _eventFormatter {
                // Remove observers on previous event formatter settings
                _eventFormatter.settings?.removeObserver(self as! NSObject, forKeyPath: "showRedactionsInRoomHistory")
                _eventFormatter.settings?.removeObserver(self as! NSObject, forKeyPath: "showUnsupportedEventsInRoomHistory")
            }

            _eventFormatter = eventFormatter

            if let _eventFormatter = _eventFormatter {
                // Add observer to flush stored data on settings changes
                _eventFormatter.settings?.addObserver(self as! NSObject, forKeyPath: "showRedactionsInRoomHistory", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
                _eventFormatter.settings?.addObserver(self as! NSObject, forKeyPath: "showUnsupportedEventsInRoomHistory", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
            }
        }
    }
    /// Show the date time label in rendered room bubble cells. NO by default.

    private var _showBubblesDateTime = false
    var showBubblesDateTime: Bool {
        get {
            _showBubblesDateTime
        }
        set(showBubblesDateTime) {
            _showBubblesDateTime = showBubblesDateTime

            //Table have to reload here
        }
    }
    /// A Boolean value that determines whether the date time labels are customized (By default date time display is handled by MatrixKit). NO by default.
    var useCustomDateTimeLabel = false
    /// Show the read marker (if any) in the rendered room bubble cells. YES by default.
    var showReadMarker = false
    /// Show the receipts in rendered bubble cell. YES by default.
    var showBubbleReceipts = false
    /// A Boolean value that determines whether the read receipts are customized (By default read receipts display is handled by MatrixKit). NO by default.
    var useCustomReceipts = false
    /// Show the reactions in rendered bubble cell. NO by default.
    var showReactions = false
    /// Show only reactions with single Emoji. NO by default.
    var showOnlySingleEmojiReactions = false
    /// A Boolean value that determines whether the unsent button is customized (By default an 'Unsent' button is displayed by MatrixKit in front of unsent events). NO by default.
    var useCustomUnsentButton = false
    /// Show the typing notifications of other room members in the chat history (NO by default).

    private var _showTypingNotifications = false
    var showTypingNotifications: Bool {
        get {
            _showTypingNotifications
        }
        set(shouldShowTypingNotifications) {
            _showTypingNotifications = shouldShowTypingNotifications

            if shouldShowTypingNotifications {
                // Register on typing notif
                listenTypingNotifications()
            } else {
                // Remove the live listener
                if typingNotifListener != nil {
                    timeline?.removeListener(typingNotifListener)
                    currentTypingUsers = nil
                    typingNotifListener = nil
                }
            }
        }
    }
    /// The pagination applied on the rendered room bubble cells (RoomViewModelBubblesPaginationNone by default).
    var bubblesPagination: MXKRoomDataSourceBubblesPagination!
    /// Max nbr of cached bubbles when there is no delegate.
    /// The default value is 30.
    var maxBackgroundCachedBubblesCount: UInt = 0
    /// The number of messages to preload around the initial event.
    /// The default value is 30.
    var paginationLimitAroundInitialEvent = 0
    /// Tell whether only the message events with an url key in their content must be handled. NO by default.
    /// Note: The stickers are not retained by this filter.

    private var _filterMessagesWithURL = false
    var filterMessagesWithURL: Bool {
        get {
            _filterMessagesWithURL
        }
        set(filterMessagesWithURL) {
            _filterMessagesWithURL = filterMessagesWithURL

            if isLive && room != nil {
                // Update the event listeners by considering the right types for the live events.
                refreshEventListeners(_filterMessagesWithURL ? [kMXEventTypeStringRoomMessage] : AppSettings.standard()?.allEventTypesForMessages)
            }
        }
    }
    /// Indicate to stop back-paginating when finding an un-decryptable event as previous event.
    /// It is used to hide pre join UTD events before joining the room.
    private var shouldPreventBackPaginationOnPreviousUTDEvent = false
    /// Indicate to stop back-paginating.
    private var shouldStopBackPagination = false
    private var secondaryRoom: MXRoom?
    private var secondaryTimeline: MXEventTimeline?

    // MARK: - Life cycle

    /// Asynchronously create a data source to serve data corresponding to the passed room.
    /// This method preloads room data, like the room state, to make it available once
    /// the room data source is created.
    /// - Parameters:
    ///   - roomId: the id of the room to get data from.
    ///   - mxSession: the Matrix session to get data from.
    ///   - onComplete: a block providing the newly created instance.
    static func load(withRoomId roomId: String?, andMatrixSession mxSession: MXSession?, onComplete: @escaping (_ roomDataSource: Any?) -> Void) {
        let roomDataSource = RoomViewModel(roomId: roomId, andMatrixSession: mxSession)
        self.ensureSessionState(for: roomDataSource, initialEventId: nil, andMatrixSession: mxSession, onComplete: onComplete)
    }

    /// Asynchronously create a data source to serve data corresponding to an event in the
    /// past of a room.
    /// This method preloads room data, like the room state, to make it available once
    /// the room data source is created.
    /// - Parameters:
    ///   - roomId: the id of the room to get data from.
    ///   - initialEventId: the id of the event where to start the timeline.
    ///   - mxSession: the Matrix session to get data from.
    ///   - onComplete: a block providing the newly created instance.
    static func load(withRoomId roomId: String?, initialEventId: String?, andMatrixSession mxSession: MXSession?, onComplete: @escaping (_ roomDataSource: Any?) -> Void) {
        let roomDataSource = RoomViewModel(roomId: roomId, initialEventId: initialEventId, andMatrixSession: mxSession)
        self.ensureSessionState(for: roomDataSource, initialEventId: initialEventId, andMatrixSession: mxSession, onComplete: onComplete)
    }

    /// Asynchronously create a data source to peek into a room.
    /// The data source will close the `peekingRoom` instance on [self destroy].
    /// This method preloads room data, like the room state, to make it available once
    /// the room data source is created.
    /// - Parameters:
    ///   - peekingRoom: the room to peek.
    ///   - initialEventId: the id of the event where to start the timeline. nil means the live
    /// timeline.
    ///   - onComplete: a block providing the newly created instance.
    class func load(with peekingRoom: MXPeekingRoom?, andInitialEventId initialEventId: String?, onComplete: @escaping (_ roomDataSource: Any?) -> Void) {
        let roomDataSource = RoomViewModel(peekingRoom: peekingRoom, andInitialEventId: initialEventId)
        self.finalizeRoomDataSource(roomDataSource, onComplete: onComplete)
    }

    /// Ensure session state to be store data ready for the roomDataSource.
    static func ensureSessionState(for roomDataSource: RoomViewModel?, initialEventId: String?, andMatrixSession mxSession: MXSession?, onComplete: @escaping (_ roomDataSource: Any?) -> Void) {
        //  if store is not ready, roomDataSource.room will be nil. So onComplete block will never be called.
        //  In order to successfully fetch the room, we should wait for store to be ready.
        if let state = mxSession?.state {
            if state.storeDataReady {
                self.ensureInitialEventExistence(for: roomDataSource, initialEventId: initialEventId, andMatrixSession: mxSession, onComplete: onComplete)
            } else {
                //  wait for session state to be store data ready
                let sessionStateObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.mxSessionStateDidChange, object: mxSession, queue: nil, using: { [self] note in
                    if state.storeDataReady {
                        NotificationCenter.default.removeObserver(sessionStateObserver)
                        self.ensureInitialEventExistence(for: roomDataSource, initialEventId: initialEventId, andMatrixSession: mxSession, onComplete: onComplete)
                    }
                })
            }
        }
    }

    /// Ensure initial event existence for the roomDataSource.
    static func ensureInitialEventExistence(for roomDataSource: RoomViewModel?, initialEventId: String?, andMatrixSession mxSession: MXSession?, onComplete: @escaping (_ roomDataSource: Any?) -> Void) {
        if roomDataSource?.room != nil {
            //  already finalized
            return
        }

        if initialEventId == nil {
            //  if an initialEventId not provided, finalize
            self.finalizeRoomDataSource(roomDataSource, onComplete: onComplete)
            return
        }

        //  ensure event with id 'initialEventId' exists in the session store
        if mxSession?.store.eventExists(withEventId: initialEventId ?? "", inRoom: (roomDataSource?.roomId)!) == true {
            self.finalizeRoomDataSource(roomDataSource, onComplete: onComplete)
        } else {
            //  give a chance for the specific event to be existent, for only one sync
            //  use kMXSessionDidSyncNotification here instead of MXSessionStateRunning, because session does not send this state update if it's already in this state
            let syncObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.mxSessionDidSync, object: mxSession, queue: nil, using: { [self] note in
                NotificationCenter.default.removeObserver(syncObserver)
                self.finalizeRoomDataSource(roomDataSource, onComplete: onComplete)
            })
        }
    }

    static func finalizeRoomDataSource(_ roomDataSource: RoomViewModel?, onComplete: @escaping (_ roomDataSource: Any?) -> Void) {
        if let roomDataSource = roomDataSource {
            roomDataSource.finalizeInitialization()

            // Asynchronously preload data here so that the data will be ready later
            // to synchronously respond to that request
            roomDataSource.room?.liveTimeline({ liveTimeline in

                onComplete(roomDataSource)
            })
        }
    }
    
    /// Finalize the initialization by adding an observer on matrix session state change.
    func finalizeInitialization() {
        // Add an observer on matrix session state change (prevent multiple registrations).
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxSessionStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didMXSessionStateChange(_:)), name: NSNotification.Name.mxSessionStateDidChange, object: nil)
        
        // Call the registered callback to finalize the initialisation step.
        didMXSessionStateChange()
    }
    
    // MARK: - MXSessionStateDidChangeNotification
    
    @objc func didMXSessionStateChange(_ notif: Notification?) {
        // Check this is our Matrix session that has changed
        if (notif?.object as? MXSession) == mxSession {
            didMXSessionStateChange()
        }
    }
    
    /// This method is called when the state of the attached Matrix session has changed.
    func didMXSessionStateChange() {
        // The inherited class is highly invited to override this method for its business logic
    }
    
    /// Dispose all resources.
    func destroy() {
        state = .unknown
        mxSession = nil
        cancelAllRequests()
        NotificationCenter.default.removeObserver(self)
        cellDataMap = nil
    }

    // MARK: - Constructors (Should not be called directly)

    /// Initialise the data source to serve data corresponding to the passed room.
    /// - Parameters:
    ///   - roomId: the id of the room to get data from.
    ///   - mxSession: the Matrix session to get data from.
    /// - Returns: the newly created instance.
    init(roomId: String?, andMatrixSession matrixSession: MXSession?) {
        self.mxSession = matrixSession
        //MXLogDebug(@"[RoomViewModel] initWithRoomId %p - room id: %@", self, roomId);

        self.roomId = roomId
        secondaryRoomEventTypes = [
            kMXEventTypeStringCallInvite,
            kMXEventTypeStringCallCandidates,
            kMXEventTypeStringCallAnswer,
            kMXEventTypeStringCallSelectAnswer,
            kMXEventTypeStringCallHangup,
            kMXEventTypeStringCallReject,
            kMXEventTypeStringCallNegotiate,
            kMXEventTypeStringCallReplaces,
            kMXEventTypeStringCallRejectReplacement
        ] as [NSString]
        let virtualRoomId = matrixSession?.virtualRoom(of: self.roomId)
        if let virtualRoomId = virtualRoomId {
            secondaryRoomId = virtualRoomId
        }
        isLive = true
        bubbles = []
        eventsToProcess = []
        eventIdToBubbleMap = [:]

        externalRelatedGroups = [:]

        filterMessagesWithURL = false

        emoteMessageSlashCommandPrefix = "\(kMXKSlashCmdEmote) "

        // Set default MXEvent -> NSString formatter
        eventFormatter = EventFormatter(matrixSession: mxSession)
        // Apply here the event types filter to display only the wanted event types.
        eventFormatter?.eventTypesFilterForMessages = AppSettings.standard()?.eventsFilterForMessages as [String]

        // display the read receips by default
        showBubbleReceipts = true

        // show the read marker by default
        showReadMarker = true

        // Disable typing notification in cells by default.
        showTypingNotifications = false

        useCustomDateTimeLabel = false
        useCustomReceipts = false
        useCustomUnsentButton = false

        maxBackgroundCachedBubblesCount = UInt(MXKROOMDATASOURCE_CACHED_BUBBLES_COUNT_THRESHOLD)
        paginationLimitAroundInitialEvent = MXKROOMDATASOURCE_PAGINATION_LIMIT_AROUND_INITIAL_EVENT

        // Observe UIApplicationSignificantTimeChangeNotification to refresh bubbles if date/time are shown.
        // UIApplicationSignificantTimeChangeNotification is posted if DST is updated, carrier time is updated
        UIApplicationSignificantTimeChangeNotificationObserver = NotificationCenter.default.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in
            onDateTimeFormatUpdate()
        })

        // Observe NSCurrentLocaleDidChangeNotification to refresh bubbles if date/time are shown.
        // NSCurrentLocaleDidChangeNotification is triggered when the time swicthes to AM/PM to 24h time format
        NSCurrentLocaleDidChangeNotificationObserver = NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

            onDateTimeFormatUpdate()

        })

        // Listen to the event sent state changes
        NotificationCenter.default.addObserver(self, selector: #selector(eventDidChangeSentState(_:)), name: NSNotification.Name.mxEventDidChangeSentState, object: nil)
        // Listen to events decrypted
        NotificationCenter.default.addObserver(self, selector: #selector(eventDidDecrypt(_:)), name: NSNotification.Name.mxEventDidDecrypt, object: nil)
        // Listen to virtual rooms change
        NotificationCenter.default.addObserver(self, selector: #selector(virtualRoomsDidChange(_:)), name: NSNotification.Name.mxSessionVirtualRoomsDidChange, object: matrixSession)
    }

    /// Initialise the data source to serve data corresponding to an event in the
    /// past of a room.
    /// - Parameters:
    ///   - roomId: the id of the room to get data from.
    ///   - initialEventId: the id of the event where to start the timeline.
    ///   - mxSession: the Matrix session to get data from.
    /// - Returns: the newly created instance.
    convenience init(roomId: String?, initialEventId initialEventId2: String?, andMatrixSession mxSession: MXSession?) {
        self.init(roomId: roomId, andMatrixSession: mxSession)
        if let initialEventId2 = initialEventId2 {
            initialEventId = initialEventId2
            isLive = false
        }
    }

    /// Initialise the data source to peek into a room.
    /// The data source will close the `peekingRoom` instance on [self destroy].
    /// - Parameters:
    ///   - peekingRoom: the room to peek.
    ///   - initialEventId: the id of the event where to start the timeline. nil means the live
    /// timeline.
    /// - Returns: the newly created instance.
    convenience init(peekingRoom peekingRoom2: MXPeekingRoom?, andInitialEventId theInitialEventId: String?) {
        self.init(roomId: peekingRoom2?.roomId, initialEventId: theInitialEventId, andMatrixSession: peekingRoom2?.mxSession)
        peekingRoom = peekingRoom2
        isPeeking = true
    }

    deinit {
        unregisterEventEditsListener()
        unregisterScanManagerNotifications()
        unregisterReactionsChangeListener()
    }

    func onDateTimeFormatUpdate() {
        // update the date and the time formatters
        eventFormatter?.initDateTimeFormatters()

        // refresh the UI if it is required
        if showBubblesDateTime && delegate {
            // Reload all the table
            delegate.dataSource(self, didCellChange: nil)
        }
    }

    /// Mark all messages as read in the room.
    func markAllAsRead() {
        room?.summary.markAllAsRead()
    }

    /// Reduce memory usage by releasing room data if the number of bubbles is over the provided limit 'maxBubbleNb'.
    /// This operation is ignored if some local echoes are pending or if unread messages counter is not nil.
    /// - Parameter maxBubbleNb: The room bubble data are released only if the number of bubbles is over this limit.
    func limitMemoryUsage(_ maxBubbleNb: Int) {
        var bubbleCount: Int
        let lockQueue = DispatchQueue(label: "bubbles")
        lockQueue.sync {
            bubbleCount = bubbles?.count ?? 0
        }

        if bubbleCount > maxBubbleNb {
            // Do nothing if some local echoes are in progress.
            let outgoingMessages = room?.outgoingMessages

            for index in 0..<(outgoingMessages?.count ?? 0) {
                let outgoingMessage = outgoingMessages?[index]

                if outgoingMessage?.sentState == MXEventSentStateSending || outgoingMessage?.sentState == MXEventSentStatePreparing || outgoingMessage?.sentState == MXEventSentStateEncrypting || outgoingMessage?.sentState == MXEventSentStateUploading {
                    MXLogDebug("[RoomViewModel] cancel limitMemoryUsage because some messages are being sent")
                    return
                }
            }

            // Reset the room data source (return in initial state: minimum memory usage).
            reload()
        }
    }

    func reset() {
        resetNotifying(true)
    }

    func resetNotifying(_ notify: Bool) {
        externalRelatedGroups?.removeAll()

        if roomDidFlushDataNotificationObserver != nil {
            if let roomDidFlushDataNotificationObserver = roomDidFlushDataNotificationObserver {
                NotificationCenter.default.removeObserver(roomDidFlushDataNotificationObserver)
            }
            roomDidFlushDataNotificationObserver = nil
        }

        if roomDidUpdateUnreadNotificationObserver != nil {
            if let roomDidUpdateUnreadNotificationObserver = roomDidUpdateUnreadNotificationObserver {
                NotificationCenter.default.removeObserver(roomDidUpdateUnreadNotificationObserver)
            }
            roomDidUpdateUnreadNotificationObserver = nil
        }

        if paginationRequest != nil {
            // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
            timeline?.removeListener(paginationListener)
            paginationListener = nil

            paginationRequest?.cancel()
            paginationRequest = nil
        }

        if secondaryPaginationRequest != nil {
            // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
            secondaryTimeline?.removeListener(secondaryPaginationListener)
            secondaryPaginationListener = nil

            secondaryPaginationRequest?.cancel()
            secondaryPaginationRequest = nil
        }

        if room != nil && liveEventsListener != nil {
            timeline?.removeListener(liveEventsListener)
            liveEventsListener = nil

            timeline?.removeListener(redactionListener)
            redactionListener = nil

            timeline?.removeListener(receiptsListener)
            receiptsListener = nil

            timeline?.removeListener(relatedGroupsListener)
            relatedGroupsListener = nil
        }

        if secondaryRoom != nil && secondaryLiveEventsListener != nil {
            secondaryTimeline?.removeListener(secondaryLiveEventsListener)
            secondaryLiveEventsListener = nil

            secondaryTimeline?.removeListener(secondaryRedactionListener)
            secondaryRedactionListener = nil
        }

        if room != nil && typingNotifListener != nil {
            timeline?.removeListener(typingNotifListener)
            typingNotifListener = nil
        }
        currentTypingUsers = nil

        NotificationCenter.default.removeObserver(self, name: kMXRoomInitialSyncNotification, object: nil)

        let lockQueue = DispatchQueue(label: "eventsToProcess")
        lockQueue.sync {
            eventsToProcess?.removeAll()
        }

        // Suspend the reset operation if some events is under processing
        let lockQueue = DispatchQueue(label: "eventsToProcessSnapshot")
        lockQueue.sync {
            eventsToProcessSnapshot = nil
            bubblesSnapshot = nil

            let lockQueue = DispatchQueue(label: "bubbles")
            lockQueue.sync {
                for bubble in bubbles ?? [] {
                    bubble.prevCollapsableCellData = nil
                    bubble.nextCollapsableCellData = nil
                }
                bubbles?.removeAll()
            }

            let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
            lockQueue.sync {
                eventIdToBubbleMap?.removeAll()
            }

            room = nil
            secondaryRoom = nil
        }

        serverSyncEventCount = 0

        // Notify the delegate to reload its tableview
        if notify && delegate {
            delegate.dataSource(self, didCellChange: nil)
        }
    }

    /// Force data reload.
    func reload() {
        reloadNotifying(true)
    }

    func reloadNotifying(_ notify: Bool) {
        //    MXLogDebug(@"[RoomViewModel] Reload %p - room id: %@", self, _roomId);

        setState(MXKDataSourceStatePreparing)

        resetNotifying(notify)

        // Reload
        didMXSessionStateChange()
    }

    func destroy() {
        MXLogDebug("[RoomViewModel] Destroy %p - room id: %@", self, roomId)

        unregisterScanManagerNotifications()
        unregisterReactionsChangeListener()
        unregisterEventEditsListener()

        NotificationCenter.default.removeObserver(self, name: kMXSessionDidUpdatePublicisedGroupsForUsersNotification, object: mxSession)

        NotificationCenter.default.removeObserver(self, name: kMXEventDidChangeSentStateNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: kMXEventDidDecryptNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: kMXEventDidChangeIdentifierNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: kMXSessionVirtualRoomsDidChangeNotification, object: nil)

        if NSCurrentLocaleDidChangeNotificationObserver != nil {
            if let NSCurrentLocaleDidChangeNotificationObserver = NSCurrentLocaleDidChangeNotificationObserver {
                NotificationCenter.default.removeObserver(NSCurrentLocaleDidChangeNotificationObserver)
            }
            NSCurrentLocaleDidChangeNotificationObserver = nil
        }

        if UIApplicationSignificantTimeChangeNotificationObserver != nil {
            if let UIApplicationSignificantTimeChangeNotificationObserver = UIApplicationSignificantTimeChangeNotificationObserver {
                NotificationCenter.default.removeObserver(UIApplicationSignificantTimeChangeNotificationObserver)
            }
            UIApplicationSignificantTimeChangeNotificationObserver = nil
        }

        // If the room data source was used to peek into a room, stop the events stream on this room
        if let peekingRoom = peekingRoom {
            room?.mxSession.stopPeeking(peekingRoom)
        }

        reset()

        eventFormatter = nil

        eventsToProcess = nil
        bubbles = nil
        eventIdToBubbleMap = nil

        timeline?.destroy()
        secondaryTimeline?.destroy()

        externalRelatedGroups = nil

        super.destroy()
    }

    func didMXSessionStateChange() {
        if MXSessionStateStoreDataReady <= mxSession.state {
            // Check whether the room is not already set
            if self.room == nil {
                // Are we peeking into a random room or displaying a room the user is part of?
                if let peekingRoom = peekingRoom {
                    self.room = peekingRoom
                } else {
                    self.room = mxSession.room(withRoomId: roomId)
                }

                if self.room != nil {
                    // This is the time to set up the timeline according to the called init method
                    if isLive {
                        // LIVE
                        MXWeakify(self)
                        self.room?.liveTimeline({ [self] liveTimeline in
                            MXStrongifyAndReturnIfNil(self)

                            timeline = liveTimeline

                            // Only one pagination process can be done at a time by an MXRoom object.
                            // This assumption is satisfied by MatrixKit. Only MXRoomDataSource does it.
                            timeline?.resetPagination()

                            // Observe room history flush (sync with limited timeline, or state event redaction)
                            roomDidFlushDataNotificationObserver = NotificationCenter.default.addObserver(forName: kMXRoomDidFlushDataNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

                                let room = notif?.object as? MXRoom
                                if mxSession == room?.mxSession && ((roomId == room?.roomId) || (secondaryRoomId == room?.roomId)) {
                                    // The existing room history has been flushed during server sync because a gap has been observed between local and server storage.
                                    reload()
                                }

                            })

                            // Add the event listeners, by considering all the event types (the event filtering is applying by the event formatter),
                            // except if only the events with a url key in their content must be handled.
                            refreshEventListeners(filterMessagesWithURL ? [kMXEventTypeStringRoomMessage] : AppSettings.standard().allEventTypesForMessages)

                            // display typing notifications is optional
                            // the inherited class can manage them by its own.
                            if showTypingNotifications {
                                // Register on typing notif
                                listenTypingNotifications()
                            }

                            // Manage unsent messages
                            handleUnsentMessages()

                            // Update here data source state if it is not already ready
                            if secondaryRoomId == nil {
                                setState(MXKDataSourceStateReady)
                            }

                            // Check user membership in this room
                            let membership = self.room?.summary.membership
                            if membership == MXMembershipUnknown || membership == MXMembershipInvite {
                                // Here the initial sync is not ended or the room is a pending invitation.
                                // Note: In case of invitation, a full sync will be triggered if the user joins this room.

                                // We have to observe here 'kMXRoomInitialSyncNotification' to reload room data when room sync is done.
                                NotificationCenter.default.addObserver(self, selector: #selector(didMXRoomInitialSynced(_:)), name: kMXRoomInitialSyncNotification, object: self.room)
                            }
                        })

                        if secondaryRoom == nil && secondaryRoomId != nil {
                            secondaryRoom = mxSession.room(withRoomId: secondaryRoomId)

                            if let secondaryRoom = secondaryRoom {
                                MXWeakify(self)
                                secondaryRoom.liveTimeline({ [self] liveTimeline in
                                    MXStrongifyAndReturnIfNil(self)

                                    secondaryTimeline = liveTimeline

                                    // Only one pagination process can be done at a time by an MXRoom object.
                                    // This assumption is satisfied by MatrixKit. Only MXRoomDataSource does it.
                                    secondaryTimeline?.resetPagination()

                                    // Add the secondary event listeners, by considering the event types in self.secondaryRoomEventTypes
                                    refreshSecondaryEventListeners(secondaryRoomEventTypes)

                                    // Update here data source state if it is not already ready
                                    setState(MXKDataSourceStateReady)

                                    // Check user membership in the secondary room
                                    let membership = secondaryRoom.summary.membership
                                    if membership == MXMembershipUnknown || membership == MXMembershipInvite {
                                        // Here the initial sync is not ended or the room is a pending invitation.
                                        // Note: In case of invitation, a full sync will be triggered if the user joins this room.

                                        // We have to observe here 'kMXRoomInitialSyncNotification' to reload room data when room sync is done.
                                        NotificationCenter.default.addObserver(self, selector: #selector(didMXRoomInitialSynced(_:)), name: kMXRoomInitialSyncNotification, object: secondaryRoom)
                                    }
                                })
                            }
                        }
                    } else {
                        // Past timeline
                        // Less things need to configured
                        timeline = self.room?.timeline(onEvent: initialEventId)

                        // Refresh the event listeners. Note: events for past timelines come only from pagination request
                        refreshEventListeners(nil)

                        MXWeakify(self)

                        // Preload the state and some messages around the initial event
                        timeline?.resetPaginationAroundInitialEvent(withLimit: paginationLimitAroundInitialEvent, success: { [self] in

                            MXStrongifyAndReturnIfNil(self)

                            // Do a "classic" reset. The room view controller will paginate
                            // from the events stored in the timeline store
                            timeline?.resetPagination()

                            // Update here data source state if it is not already ready
                            setState(MXKDataSourceStateReady)

                        }, failure: { error in

                            MXStrongifyAndReturnIfNil(self)

                            MXLogDebug("[RoomViewModel] Failed to resetPaginationAroundInitialEventWithLimit")

                            // Notify the error
                            if let error = error {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name(kMXKRoomDataSourceTimelineError),
                                    object: self,
                                    userInfo: [
                                        kMXKRoomDataSourceTimelineErrorErrorKey: error
                                    ])
                            }
                        })
                    }
                } else {
                    MXLogDebug("[RoomViewModel] Warning: The user does not know the room %@", roomId)

                    // Update here data source state if it is not already ready
                    setState(MXKDataSourceStateFailed)
                }
            }

            if self.room != nil && MXSessionStateRunning == mxSession.state {
                // Flair handling: observe the update in the publicised groups by users when the flair is enabled in the room.
                NotificationCenter.default.removeObserver(self, name: kMXSessionDidUpdatePublicisedGroupsForUsersNotification, object: mxSession)
                self.room?.state({ [self] roomState in
                    if roomState?.relatedGroups.count {
                        NotificationCenter.default.addObserver(self, selector: #selector(didMXSessionUpdatePublicisedGroups(forUsers:)), name: kMXSessionDidUpdatePublicisedGroupsForUsersNotification, object: mxSession)

                        // Get a fresh profile for all the related groups. Trigger a table refresh when all requests are done.
                        let count = roomState?.relatedGroups.count ?? 0
                        if let relatedGroups = roomState?.relatedGroups {
                            for groupId in relatedGroups {
                                guard let groupId = groupId as? String else {
                                    continue
                                }
                                var group = mxSession.group(withGroupId: groupId)
                                if group == nil {
                                    // Create a group instance for the groups that the current user did not join.
                                    group = MXGroup(groupId: groupId)
                                    externalRelatedGroups?[groupId] = group
                                }

                                // Refresh the group profile from server.
                                mxSession.updateGroupProfile(group, success: { [self] in

                                    count -= 1
                                    if delegate && count == 0 {
                                        // All the requests have been done.
                                        delegate.dataSource(self, didCellChange: nil)
                                    }

                                }, failure: { [self] error in

                                    MXLogDebug("[RoomViewModel] group profile update failed %@", groupId)

                                    count -= 1
                                    if delegate && count == 0 {
                                        // All the requests have been done.
                                        delegate.dataSource(self, didCellChange: nil)
                                    }

                                })
                            }
                        }
                    }
                })
            }
        }
    }

    func refreshEventListeners(_ liveEventTypesFilterForMessages: [AnyHashable]?) {
        // Remove the existing listeners
        if let liveEventsListener = liveEventsListener {
            timeline?.removeListener(liveEventsListener)
            timeline?.removeListener(redactionListener)
            timeline?.removeListener(receiptsListener)
            timeline?.removeListener(relatedGroupsListener)
        }

        // Listen to live events only for live timeline
        // Events for past timelines come only from pagination request
        if isLive {
            // Register a new one with the requested filter
            MXWeakify(self)
            liveEventsListener = timeline?.listen(toEventsOfTypes: liveEventTypesFilterForMessages, onEvent: { [self] event, direction, roomState in

                MXStrongifyAndReturnIfNil(self)

                if MXTimelineDirectionForwards == direction {
                    // Check for local echo suppression
                    var localEcho: MXEvent?
                    if room?.outgoingMessages.count && (event?.sender == mxSession.myUser.userId) {
                        localEcho = room?.pendingLocalEchoRelated(to: event)
                        if localEcho != nil {
                            // Check whether the local echo has a timestamp (in this case, it is replaced with the actual event).
                            if localEcho?.originServerTs != kMXUndefinedTimestamp {
                                // Replace the local echo by the true event sent by the homeserver
                                replace(localEcho, with: event)
                            } else {
                                // Remove the local echo, and process independently the true event.
                                replace(localEcho, with: nil)
                                localEcho = nil
                            }
                        }
                    }

                    if secondaryRoom != nil {
                        reloadNotifying(false)
                    } else if nil == localEcho {
                        // Process here incoming events, and outgoing events sent from another device.
                        queueEvent(forProcessing: event, with: roomState, direction: MXTimelineDirectionForwards)
                        processQueuedEvents({ _,_ in })
                    }
                }
            })

            receiptsListener = timeline?.listen(toEventsOfTypes: [kMXEventTypeStringReceipt], onEvent: { [self] event, direction, roomState in

                if MXTimelineDirectionForwards == direction {
                    // Handle this read receipt
                    didReceiveReceiptEvent(event, roomState: roomState)
                }
            })

            // Flair handling: register a listener for the related groups state event in this room.
            relatedGroupsListener = timeline?.listen(toEventsOfTypes: [kMXEventTypeStringRoomRelatedGroups], onEvent: { [self] event, direction, roomState in

                if MXTimelineDirectionForwards == direction {
                    // The flair settings have been updated: flush the current bubble data and rebuild them.
                    reload()
                }
            })
        }

        // Register a listener to handle redaction which can affect live and past timelines
        redactionListener = timeline?.listen(toEventsOfTypes: [kMXEventTypeStringRoomRedaction], onEvent: { [self] redactionEvent, direction, roomState in

            // Consider only live redaction events
            if direction == MXTimelineDirectionForwards {
                // Do the processing on the processing queue
                RoomViewModel.processingQueue().async(execute: { [self] in

                    // Check whether a message contains the redacted event
                    weak var bubbleData = cellDataOfEvent(withEventId: redactionEvent?.redacts)
                    if let bubbleData = bubbleData {
                        var shouldRemoveBubbleData = false
                        var hasChanged = false
                        var redactedEvent: MXEvent? = nil

                        let lockQueue = DispatchQueue(label: "bubbleData")
                        lockQueue.sync {
                            // Retrieve the original event to redact it
                            let events = bubbleData.events

                            for event in events {
                                guard let event = event as? MXEvent else {
                                    continue
                                }
                                if event.eventId == redactionEvent?.redacts {
                                    // Check whether the event was not already redacted (Redaction may be handled by event timeline too).
                                    if !event.isRedactedEvent {
                                        redactedEvent = event.prune()
                                        redactedEvent?.redactedBecause = redactionEvent?.jsonDictionary
                                    }

                                    break
                                }
                            }

                            if let redactedEvent = redactedEvent {
                                // Update bubble data
                                let remainingEvents = bubbleData.updateEvent(redactionEvent?.redacts, with: redactedEvent)

                                hasChanged = true

                                // Remove the bubble if there is no more events
                                shouldRemoveBubbleData = remainingEvents == 0
                            }
                        }

                        // Check whether the bubble should be removed
                        if shouldRemoveBubbleData {
                            removeCellData(bubbleData)
                        }

                        if hasChanged {
                            // Update the delegate on main thread
                            DispatchQueue.main.async(execute: { [self] in

                                if delegate {
                                    delegate.dataSource(self, didCellChange: nil)
                                }

                            })
                        }
                    }

                })
            }
        })
    }

    func refreshSecondaryEventListeners(_ liveEventTypesFilterForMessages: [AnyHashable]?) {
        // Remove the existing listeners
        if let secondaryLiveEventsListener = secondaryLiveEventsListener {
            secondaryTimeline?.removeListener(secondaryLiveEventsListener)
            secondaryTimeline?.removeListener(secondaryRedactionListener)
        }

        // Listen to live events only for live timeline
        // Events for past timelines come only from pagination request
        if isLive {
            // Register a new one with the requested filter
            MXWeakify(self)
            secondaryLiveEventsListener = secondaryTimeline?.listen(toEventsOfTypes: liveEventTypesFilterForMessages, onEvent: { [self] event, direction, roomState in

                MXStrongifyAndReturnIfNil(self)

                if MXTimelineDirectionForwards == direction {
                    // Check for local echo suppression
                    var localEcho: MXEvent?
                    if secondaryRoom?.outgoingMessages.count && (event?.sender == mxSession.myUserId) {
                        localEcho = secondaryRoom?.pendingLocalEchoRelated(to: event)
                        if localEcho != nil {
                            // Check whether the local echo has a timestamp (in this case, it is replaced with the actual event).
                            if localEcho?.originServerTs != kMXUndefinedTimestamp {
                                // Replace the local echo by the true event sent by the homeserver
                                replace(localEcho, with: event)
                            } else {
                                // Remove the local echo, and process independently the true event.
                                replace(localEcho, with: nil)
                                localEcho = nil
                            }
                        }
                    }

                    if nil == localEcho {
                        // Process here incoming events, and outgoing events sent from another device.
                        queueEvent(forProcessing: event, with: roomState, direction: MXTimelineDirectionForwards)
                        processQueuedEvents({ _,_ in })
                    }
                }
            })
        }

        // Register a listener to handle redaction which can affect live and past timelines
        secondaryRedactionListener = secondaryTimeline?.listen(toEventsOfTypes: [kMXEventTypeStringRoomRedaction], onEvent: { [self] redactionEvent, direction, roomState in

            // Consider only live redaction events
            if direction == MXTimelineDirectionForwards {
                // Do the processing on the processing queue
                RoomViewModel.processingQueue().async(execute: { [self] in

                    // Check whether a message contains the redacted event
                    weak var bubbleData = cellDataOfEvent(withEventId: redactionEvent?.redacts)
                    if let bubbleData = bubbleData {
                        var shouldRemoveBubbleData = false
                        var hasChanged = false
                        var redactedEvent: MXEvent? = nil

                        let lockQueue = DispatchQueue(label: "bubbleData")
                        lockQueue.sync {
                            // Retrieve the original event to redact it
                            let events = bubbleData.events

                            for event in events {
                                guard let event = event as? MXEvent else {
                                    continue
                                }
                                if event.eventId == redactionEvent?.redacts {
                                    // Check whether the event was not already redacted (Redaction may be handled by event timeline too).
                                    if !event.isRedactedEvent {
                                        redactedEvent = event.prune()
                                        redactedEvent?.redactedBecause = redactionEvent?.jsonDictionary
                                    }

                                    break
                                }
                            }

                            if let redactedEvent = redactedEvent {
                                // Update bubble data
                                let remainingEvents = bubbleData.updateEvent(redactionEvent?.redacts, with: redactedEvent)

                                hasChanged = true

                                // Remove the bubble if there is no more events
                                shouldRemoveBubbleData = remainingEvents == 0
                            }
                        }

                        // Check whether the bubble should be removed
                        if shouldRemoveBubbleData {
                            removeCellData(bubbleData)
                        }

                        if hasChanged {
                            // Update the delegate on main thread
                            DispatchQueue.main.async(execute: { [self] in

                                if delegate {
                                    delegate.dataSource(self, didCellChange: nil)
                                }

                            })
                        }
                    }

                })
            }
        })
    }

    func listenTypingNotifications() {
        // Remove the previous live listener
        if let typingNotifListener = typingNotifListener {
            timeline?.removeListener(typingNotifListener)
            currentTypingUsers = nil
        }

        // Add typing notification listener
        MXWeakify(self)

        typingNotifListener = timeline?.listen(toEventsOfTypes: [kMXEventTypeStringTypingNotification], onEvent: { [self] event, direction, roomState in
            MXStrongifyAndReturnIfNil(self)

            // Handle only live events
            if direction == MXTimelineDirectionForwards {
                // Retrieve typing users list
                var typingUsers: [AnyHashable]? = nil
                if let typingUsers1 = room?.typingUsers {
                    typingUsers = typingUsers1
                }

                // Remove typing info for the current user
                let index = typingUsers?.firstIndex(of: mxSession.myUser.userId) ?? NSNotFound
                if index != NSNotFound {
                    typingUsers?.remove(at: index)
                }
                // Ignore this notification if both arrays are empty
                if (currentTypingUsers?.count ?? 0) != 0 || (typingUsers?.count ?? 0) != 0 {
                    currentTypingUsers = typingUsers

                    if delegate {
                        // refresh all the table
                        delegate.dataSource(self, didCellChange: nil)
                    }
                }
            }
        })

        currentTypingUsers = room?.typingUsers
    }

    func cancelAllRequests() {
        if paginationRequest != nil {
            // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
            timeline?.removeListener(paginationListener)
            paginationListener = nil

            paginationRequest?.cancel()
            paginationRequest = nil
        }

        super.cancelAllRequests()
    }

    func setDelegate(_ delegate: MXKDataSourceDelegate?) {
        super.delegate = delegate

        // Register to MXScanManager notification only when a delegate is set
        if delegate != nil && mxSession.scanManager {
            registerScanManagerNotifications()
        }

        // Register to reaction notification only when a delegate is set
        if delegate != nil {
            registerReactionsChangeListener()
            registerEventEditsListener()
        }
    }

    func setRoom(_ room: MXRoom?) {
        if _room != room {
            _room = room

            roomDidSet()
        }
    }

    /// Called when room property changed. Designed to be used by subclasses.
    func roomDidSet() {

    }

    // MARK: - KVO

    func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [String : Any]?, context: UnsafeMutableRawPointer?) {
        if ("showRedactionsInRoomHistory" == keyPath) || ("showUnsupportedEventsInRoomHistory" == keyPath) {
            // Flush the current bubble data and rebuild them
            reload()
        }
    }

    // MARK: - Public methods
    /// Get the data for the cell at the given index.
    /// - Parameter index: the index of the cell in the array
    /// - Returns: the cell data

    // MARK: - Public methods

    func cellData(at index: Int) -> MXKRoomBubbleCellDataStoring? {
        weak var bubbleData: MXKRoomBubbleCellDataStoring?
        let lockQueue = DispatchQueue(label: "bubbles")
        lockQueue.sync {
            if index < (bubbles?.count ?? 0) {
                bubbleData = bubbles?[index]
            }
        }
        return bubbleData
    }

    /// Get the data for the cell which contains the event with the provided event id.
    /// - Parameter eventId: the event identifier
    /// - Returns: the cell data
    func cellDataOfEvent(withEventId eventId: String?) -> MXKRoomBubbleCellDataStoring? {
        weak var bubbleData: MXKRoomBubbleCellDataStoring?
        let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
        lockQueue.sync {
            bubbleData = eventIdToBubbleMap?[eventId ?? ""] as? MXKRoomBubbleCellDataStoring
        }
        return bubbleData
    }

    /// Get the index of the cell which contains the event with the provided event id.
    /// - Parameter eventId: the event identifier
    /// - Returns: the index of the concerned cell (NSNotFound if none).
    func indexOfCellData(withEventId eventId: String?) -> Int {
        var index = NSNotFound

        weak var bubbleData: MXKRoomBubbleCellDataStoring?
        let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
        lockQueue.sync {
            bubbleData = eventIdToBubbleMap?[eventId ?? ""] as? MXKRoomBubbleCellDataStoring
        }

        if let bubbleData = bubbleData {
            let lockQueue = DispatchQueue(label: "bubbles")
            lockQueue.sync {
                index = bubbles?.firstIndex(of: bubbleData) ?? NSNotFound
            }
        }

        return index
    }

    /// Get height of the cell at the given index.
    /// - Parameters:
    ///   - index: the index of the cell in the array.
    ///   - maxWidth: the maximum available width.
    /// - Returns: the cell height (0 if no data is available for this cell, or if the delegate is undefined).
    func cellHeight(at index: Int, withMaximumWidth maxWidth: CGFloat) -> CGFloat {
        weak var bubbleData = cellData(at: index)

        // Sanity check
        if bubbleData != nil && delegate {
            // Compute here height of bubble cell
            weak var cellViewClass = delegate.cellViewClass(forCellData: bubbleData)
            return cellViewClass?.height(forCellData: bubbleData, withMaximumWidth: maxWidth) ?? 0.0
        }

        return 0
    }

    /// Force bubbles cell data message recalculation.
    func invalidateBubblesCellDataCache() {
        let lockQueue = DispatchQueue(label: "bubbles")
        lockQueue.sync {
            for bubble in bubbles ?? [] {
                bubble.attributedTextMessage = nil
            }
        }
    }

    // MARK: - Pagination
    /// Load more messages.
    /// This method fails (with nil error) if the data source is not ready (see `MXKDataSourceStateReady`).
    /// - Parameters:
    ///   - numItems: the number of items to get.
    ///   - direction: backwards or forwards.
    ///   - onlyFromStore: if YES, return available events from the store, do not make a pagination request to the homeserver.
    ///   - success: a block called when the operation succeeds. This block returns the number of added cells.
    /// (Note this count may be 0 if paginated messages have been concatenated to the current first cell).
    ///   - failure: a block called when the operation fails.

    // MARK: - Pagination

    func paginate(_ numItems: Int, direction: MXTimelineDirection, onlyFromStore: Bool, success: @escaping (_ addedCellNumber: Int) -> Void, failure: @escaping (_ error: Error?) -> Void) {
        // Check the current data source state, and the actual user membership for this room.
        if state != MXKDataSourceStateReady || ((room?.summary.membership == MXMembershipUnknown || room?.summary.membership == MXMembershipInvite) && (roomState?.historyVisibility != kMXRoomHistoryVisibilityWorldReadable)) {
            // Back pagination is not available here.
            if failure != nil {
                failure(nil)
            }
            return
        }

        if paginationRequest != nil || secondaryPaginationRequest != nil {
            MXLogDebug("[RoomViewModel] paginate: a pagination is already in progress")
            if failure != nil {
                failure(nil)
            }
            return
        }

        if false == canPaginate(direction) {
            MXLogDebug("[RoomViewModel] paginate: No more events to paginate")
            if success != nil {
                success(0)
            }
        }

        var addedCellNb = 0
        var operationErrors = [AnyHashable](repeating: 0, count: 2) as? [Error]
        let dispatchGroup = DispatchGroup()

        // Define a new listener for this pagination
        paginationListener = timeline?.listen(toEventsOfTypes: (filterMessagesWithURL ? [kMXEventTypeStringRoomMessage] : AppSettings.standard().allEventTypesForMessages), onEvent: { [self] event, direction2, roomState in

            if direction2 == direction {
                queueEvent(forProcessing: event, with: roomState, direction: direction)
            }

        })

        // Keep a local reference to this listener.
        let localPaginationListenerRef = paginationListener

        dispatchGroup.enter()
        // Launch the pagination

        MXWeakify(self)
        paginationRequest = timeline?.paginate(numItems, direction: direction, onlyFromStore: onlyFromStore, complete: { [self] in

            MXStrongifyAndReturnIfNil(self)

            // Everything went well, remove the listener
            paginationRequest = nil
            timeline?.removeListener(paginationListener)
            paginationListener = nil

            // Once done, process retrieved events
            processQueuedEvents({ addedHistoryCellNb, addedLiveCellNb in

                addedCellNb += (direction == MXTimelineDirectionBackwards) ? addedHistoryCellNb : addedLiveCellNb
                dispatchGroup.leave()

            })

        }, failure: { [self] error in

            MXLogDebug("[RoomViewModel] paginateBackMessages fails")

            MXStrongifyAndReturnIfNil(self)

            // Something wrong happened or the request was cancelled.
            // Check whether the request is the actual one before removing listener and handling the retrieved events.
            if localPaginationListenerRef == paginationListener {
                paginationRequest = nil
                timeline?.removeListener(paginationListener)
                paginationListener = nil

                // Process at least events retrieved from store
                processQueuedEvents({ addedHistoryCellNb, addedLiveCellNb in

                    if let error = error {
                        operationErrors?.append(error)
                    }
                    if addedHistoryCellNb != 0 {
                        addedCellNb += addedHistoryCellNb
                    }
                    dispatchGroup.leave()

                })
            }

        })

        if let secondaryTimeline = secondaryTimeline {
            // Define a new listener for this pagination
            secondaryPaginationListener = secondaryTimeline.listen(toEventsOfTypes: secondaryRoomEventTypes, onEvent: { [self] event, direction2, roomState in

                if direction2 == direction {
                    queueEvent(forProcessing: event, with: roomState, direction: direction)
                }

            })

            // Keep a local reference to this listener.
            let localPaginationListenerRef = secondaryPaginationListener

            dispatchGroup.enter()
            // Launch the pagination
            MXWeakify(self)
            secondaryPaginationRequest = secondaryTimeline.paginate(numItems, direction: direction, onlyFromStore: onlyFromStore, complete: { [self] in

                MXStrongifyAndReturnIfNil(self)

                // Everything went well, remove the listener
                secondaryPaginationRequest = nil
                secondaryTimeline.removeListener(secondaryPaginationListener)
                secondaryPaginationListener = nil

                // Once done, process retrieved events
                processQueuedEvents({ addedHistoryCellNb, addedLiveCellNb in

                    addedCellNb += (direction == MXTimelineDirectionBackwards) ? addedHistoryCellNb : addedLiveCellNb
                    dispatchGroup.leave()

                })

            }, failure: { [self] error in

                MXLogDebug("[RoomViewModel] paginateBackMessages fails")

                MXStrongifyAndReturnIfNil(self)

                // Something wrong happened or the request was cancelled.
                // Check whether the request is the actual one before removing listener and handling the retrieved events.
                if localPaginationListenerRef == secondaryPaginationListener {
                    secondaryPaginationRequest = nil
                    secondaryTimeline.removeListener(secondaryPaginationListener)
                    secondaryPaginationListener = nil

                    // Process at least events retrieved from store
                    processQueuedEvents({ addedHistoryCellNb, addedLiveCellNb in

                        if let error = error {
                            operationErrors?.append(error)
                        }
                        if addedHistoryCellNb != 0 {
                            addedCellNb += addedHistoryCellNb
                        }
                        dispatchGroup.leave()

                    })
                }

            })
        }

        dispatch_group_notify(dispatchGroup, DispatchQueue.main, {
            if (operationErrors?.count ?? 0) != 0 {
                if failure != nil {
                    failure((operationErrors?.first)!)
                }
            } else {
                if success != nil {
                    success(addedCellNb)
                }
            }
        })
    }

    /// Load enough messages to fill the rect.
    /// This method fails (with nil error) if the data source is not ready (see `MXKDataSourceStateReady`),
    /// or if the delegate is undefined (this delegate is required to compute the actual size of the cells).
    /// - Parameters:
    ///   - rect: the rect to fill.
    ///   - direction: backwards or forwards.
    ///   - minRequestMessagesCount: if messages are not available in the store, a request to the homeserver
    /// is required. minRequestMessagesCount indicates the minimum messages count to retrieve from the hs.
    ///   - success: a block called when the operation succeeds.
    ///   - failure: a block called when the operation fails.
    func paginate(toFill rect: CGRect, direction: MXTimelineDirection, withMinRequestMessagesCount minRequestMessagesCount: Int, success: @escaping () -> Void, failure: @escaping (_ error: Error?) -> Void) {
        MXLogDebug("[RoomViewModel] paginateToFillRect: %@", NSCoder.string(for: rect))

        // During the first call of this method, the delegate is supposed defined.
        // This delegate may be removed whereas this method is called by itself after a pagination request.
        // The delegate is required here to be able to compute cell height (and prevent infinite loop in case of reentrancy).
        if !delegate {
            MXLogDebug("[RoomViewModel] paginateToFillRect ignored (delegate is undefined)")
            if failure != nil {
                failure(nil)
            }
            return
        }

        // Get the total height of cells already loaded in memory
        var minMessageHeight = CGFLOAT_MAX
        var bubblesTotalHeight: CGFloat = 0

        let lockQueue = DispatchQueue(label: "bubbles")
        lockQueue.sync {
            // Check whether data has been aldready loaded
            if (bubbles?.count ?? 0) != 0 {
                var eventsCount = 0
                var i = (bubbles?.count ?? 0) - 1
                while i >= 0 {
                    weak var bubbleData = bubbles?[i]
                    eventsCount += bubbleData?.events.count ?? 0

                    let bubbleHeight = cellHeight(at: i, withMaximumWidth: rect.size.width)
                    // Sanity check
                    if bubbleHeight != 0.0 {
                        bubblesTotalHeight += bubbleHeight

                        if bubblesTotalHeight > rect.size.height {
                            // No need to compute more cells heights, there are enough to fill the rect
                            MXLogDebug("[RoomViewModel] -> %tu already loaded bubbles (%tu events) are enough to fill the screen", (bubbles?.count ?? 0) - i, eventsCount)
                            break
                        }

                        // Compute the minimal height an event takes
                        minMessageHeight = CGFloat(min(minMessageHeight, bubbleHeight / (bubbleData?.events.count ?? 0.0)))
                    }
                    i -= 1
                }
            } else if minRequestMessagesCount != 0 && canPaginate(direction) {
                MXLogDebug("[RoomViewModel] paginateToFillRect: Prefill with data from the store")
                // Give a chance to load data from the store before doing homeserver requests
                // Reuse minRequestMessagesCount because we need to provide a number.
                paginate(minRequestMessagesCount, direction: direction, onlyFromStore: true, success: { [self] addedCellNumber in

                    // Then retry
                    paginate(toFill: rect, direction: direction, withMinRequestMessagesCount: minRequestMessagesCount, success: success, failure: failure)

                }, failure: failure)
                return
            }
        }

        // Is there enough cells to cover all the requested height?
        if bubblesTotalHeight < rect.size.height {
            // No. Paginate to get more messages
            if canPaginate(direction) {
                // Bound the minimal height to 44
                minMessageHeight = CGFloat(min(minMessageHeight, 44))

                // Load messages to cover the remaining height
                // Use an extra of 50% to manage unsupported/unexpected/redated events
                var messagesToLoad = ceil((rect.size.height - bubblesTotalHeight) / minMessageHeight * 1.5)

                // It does not worth to make a pagination request for only 1 message.
                // So, use minRequestMessagesCount
                messagesToLoad = Int(max(messagesToLoad, minRequestMessagesCount))

                MXLogDebug("[RoomViewModel] paginateToFillRect: need to paginate %tu events to cover %fpx", messagesToLoad, rect.size.height - bubblesTotalHeight)
                paginate(messagesToLoad, direction: direction, onlyFromStore: false, success: { [self] addedCellNumber in

                    paginate(toFill: rect, direction: direction, withMinRequestMessagesCount: minRequestMessagesCount, success: success, failure: failure)

                }, failure: failure)
            } else {

                MXLogDebug("[RoomViewModel] paginateToFillRect: No more events to paginate")
                if success != nil {
                    success()
                }
            }
        } else {
            // Yes. Nothing to do
            if success != nil {
                success()
            }
        }
    }

    // MARK: - Sending
    /// Send a text message to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - text: the text to send.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.

    // MARK: - Sending

    func sendTextMessage(_ text: String?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var localEchoEvent: MXEvent? = nil

        let isEmote = isMessageAnEmote(text)
        let sanitizedText = sanitizedMessageText(text)
        let html = htmlMessage(fromSanitizedText: sanitizedText)

        // Make the request to the homeserver
        if isEmote {
            room?.sendEmote(sanitizedText, formattedText: html, localEcho: &localEchoEvent, success: success, failure: failure)
        } else {
            room?.sendTextMessage(sanitizedText, formattedText: html, localEcho: &localEchoEvent, success: success, failure: failure)
        }

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    /// Send a reply to an event with text message to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - eventIdToReply: the id of event to reply.
    ///   - text: the text to send.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendReplyToEvent(
        withId eventIdToReply: String?,
        withTextMessage text: String?,
        success: @escaping (String?) -> Void,
        failure: @escaping (Error?) -> Void
    ) {
        let eventToReply = event(withEventId: eventIdToReply)

        var localEchoEvent: MXEvent? = nil

        let sanitizedText = sanitizedMessageText(text)
        let html = htmlMessage(fromSanitizedText: sanitizedText)

        weak var stringLocalizations = MXKSendReplyEventStringLocalizations() as? MXSendReplyEventStringsLocalizable

        room?.sendReply(to: eventToReply, withTextMessage: sanitizedText, formattedTextMessage: html, stringLocalizations: stringLocalizations, localEcho: &localEchoEvent, success: success, failure: failure)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    func isMessageAnEmote(_ text: String?) -> Bool {
        return text?.hasPrefix(emoteMessageSlashCommandPrefix ?? "") ?? false
    }

    func sanitizedMessageText(_ rawText: String?) -> String? {
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
        text = rawText?.replacingOccurrences(of: "\(0x00000000)", with: "")

        // Check whether the message is an emote
        if isMessageAnEmote(text) {
            // Remove "/me " string
            text = (text as NSString?)?.substring(from: emoteMessageSlashCommandPrefix?.count ?? 0)
        }

        return text
    }

    func htmlMessage(fromSanitizedText sanitizedText: String?) -> String? {
        var html: String?

        // Did user use Markdown text?
        let htmlStringFromMarkdown = eventFormatter?.htmlString(fromMarkdownString: sanitizedText)

        if htmlStringFromMarkdown == sanitizedText {
            // No formatted string
            html = nil
        } else {
            html = htmlStringFromMarkdown
        }

        return html
    }

    /// Send an image to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - image: the UIImage containing the image to send.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func send(_ image: UIImage?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var image = image
        // Make sure the uploaded image orientation is up
        image = Tools.forceImageOrientationUp(image)

        // Only jpeg image is supported here
        let mimetype = "image/jpeg"
        let imageData = image?.jpegData(compressionQuality: 0.9)

        // Shall we need to consider a thumbnail?
        var thumbnail: UIImage? = nil
        if room?.summary.isEncrypted ?? false {
            // Thumbnail is useful only in case of encrypted room
            thumbnail = Tools.reduce(image, toFitInSize: CGSize(width: 800, height: 600))
            if thumbnail == image {
                thumbnail = nil
            }
        }

        sendImageData(imageData, withImageSize: image?.size ?? CGSize.zero, mimeType: mimetype, andThumbnail: thumbnail, success: success, failure: failure)
    }

    /// Indicates if replying to the provided event is supported.
    /// Only event of type 'MXEventTypeRoomMessage' are supported for the moment, and for certain msgtype.
    /// - Parameter eventId: The id of the event.
    /// - Returns: YES if it is possible to reply to this event.
    func canReplyToEvent(withId eventIdToReply: String?) -> Bool {
        let eventToReply = event(withEventId: eventIdToReply)
        return room?.canReply(to: eventToReply) ?? false
    }

    /// Send an image to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - imageData: the full-sized image data of the image to send.
    ///   - mimetype: the mime type of the image
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendImage(_ imageData: Data?, mimeType mimetype: String?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var image: UIImage? = nil
        if let imageData = imageData {
            image = UIImage(data: imageData)
        }

        // Shall we need to consider a thumbnail?
        var thumbnail: UIImage? = nil
        if room?.summary.isEncrypted ?? false {
            // Thumbnail is useful only in case of encrypted room
            thumbnail = Tools.reduce(image, toFitInSize: CGSize(width: 800, height: 600))
            if thumbnail == image {
                thumbnail = nil
            }
        }

        sendImageData(imageData, withImageSize: image?.size ?? CGSize.zero, mimeType: mimetype, andThumbnail: thumbnail, success: success, failure: failure)
    }

    func sendImageData(_ imageData: Data?, withImageSize imageSize: CGSize, mimeType mimetype: String?, andThumbnail thumbnail: UIImage?, success: @escaping (_ eventId: String?) -> Void, failure: @escaping (_ error: Error?) -> Void) {
        var localEchoEvent: MXEvent? = nil

        room?.sendImage(imageData, withImageSize: imageSize, mimeType: mimetype, andThumbnail: thumbnail, localEcho: &localEchoEvent, success: success, failure: failure)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    /// Send a video to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - videoLocalURL: the local filesystem path of the video to send.
    ///   - videoThumbnail: the UIImage hosting a video thumbnail.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendVideo(_ videoLocalURL: URL?, withThumbnail videoThumbnail: UIImage?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var videoAsset: AVURLAsset? = nil
        if let videoLocalURL = videoLocalURL {
            videoAsset = AVURLAsset(url: videoLocalURL)
        }
        sendVideoAsset(videoAsset, withThumbnail: videoThumbnail, success: success, failure: failure)
    }

    /// Send a video to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - videoAsset: the AVAsset that represents the video to send.
    ///   - videoThumbnail: the UIImage hosting a video thumbnail.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendVideoAsset(_ videoAsset: AVAsset?, withThumbnail videoThumbnail: UIImage?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var localEchoEvent: MXEvent? = nil

        room?.sendVideoAsset(videoAsset, withThumbnail: videoThumbnail, localEcho: &localEchoEvent, success: success, failure: failure)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    /// Send an audio file to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - audioFileLocalURL: the local filesystem path of the audio file to send.
    ///   - mimeType: the mime type of the file.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendAudioFile(_ audioFileLocalURL: URL?, mimeType: mimeType, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var localEchoEvent: MXEvent? = nil

        room?.sendAudioFile(audioFileLocalURL, mimeType: mimeType, localEcho: &localEchoEvent, success: success, failure: failure, keepActualFilename: true)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
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
        _ audioFileLocalURL: URL?,
        mimeType: mimeType,
        duration: Int,
        samples: [NSNumber]?,
        success: @escaping (String?) -> Void,
        failure: @escaping (Error?) -> Void
    ) {
        var localEchoEvent: MXEvent? = nil

        room?.sendVoiceMessage(audioFileLocalURL, mimeType: mimeType, duration: duration, samples: samples, localEcho: &localEchoEvent, success: success, failure: failure, keepActualFilename: true)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    /// Send a file to the room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - fileLocalURL: the local filesystem path of the file to send.
    ///   - mimeType: the mime type of the file.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendFile(_ fileLocalURL: URL?, mimeType: String?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var localEchoEvent: MXEvent? = nil

        room?.sendFile(fileLocalURL, mimeType: mimeType, localEcho: &localEchoEvent, success: success, failure: failure)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    func sendMessage(withContent msgContent: [AnyHashable : Any]?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var localEchoEvent: MXEvent? = nil

        // Make the request to the homeserver
        room?.sendMessage(withContent: msgContent, localEcho: &localEchoEvent, success: success, failure: failure)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    /// Send a generic non state event to a room.
    /// While sending, a fake event will be echoed in the messages list.
    /// Once complete, this local echo will be replaced by the event saved by the homeserver.
    /// - Parameters:
    ///   - eventTypeString: the type of the event. - seealso: MXEventType.
    ///   - content: the content that will be sent to the server as a JSON object.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func sendEventOfType(_ eventTypeString: MXEventTypeString, content msgContent: [String : Any?]?, success: @escaping (_ eventId: String?) -> Void, failure: @escaping (_ error: Error?) -> Void) {
        var localEchoEvent: MXEvent? = nil

        // Make the request to the homeserver
        room?.sendEventOfType(eventTypeString, content: msgContent, localEcho: &localEchoEvent, success: success, failure: failure)

        if let localEchoEvent = localEchoEvent {
            // Make the data source digest this fake local echo message
            queueEvent(forProcessing: localEchoEvent, with: roomState, direction: MXTimelineDirectionForwards)
            processQueuedEvents({ _,_ in })
        }
    }

    /// Resend a room message event.
    /// The echo message corresponding to the event will be removed and a new echo message
    /// will be added at the end of the room history.
    /// - Parameters:
    ///   - eventId: of the event to resend.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver
    ///   - failure: A block object called when the operation fails.
    func resendEvent(withEventId eventId: String?, success: @escaping (String?) -> Void, failure: @escaping (Error?) -> Void) {
        var event = self.event(withEventId: eventId)

        // Sanity check
        if event == nil {
            return
        }

        MXLogInfo("[RoomViewModel] resendEventWithEventId. EventId: %@", event?.eventId)

        // Check first whether the event is encrypted
        if event?.wireType == kMXEventTypeStringRoomEncrypted {
            // We try here to resent an encrypted event
            // Note: we keep the existing local echo.
            room?.sendEventOfType(kMXEventTypeStringRoomEncrypted, content: event?.wireContent, localEcho: &event, success: success, failure: failure)
        } else if event?.type == kMXEventTypeStringRoomMessage {
            // And retry the send the message according to its type
            let msgType = event?.content["msgtype"] as? String
            if (msgType == kMXMessageTypeText) || (msgType == kMXMessageTypeEmote) {
                // Resend the Matrix event by reusing the existing echo
                room?.sendMessage(withContent: event?.content, localEcho: &event, success: success, failure: failure)
            } else if msgType == kMXMessageTypeImage {
                // Check whether the sending failed while uploading the data.
                // If the content url corresponds to a upload id, the upload was not complete.
                let contentURL = event?.content["url"] as? String
                if contentURL != nil && contentURL?.hasPrefix(kMXMediaUploadIdPrefix) ?? false {
                    var mimetype: String? = nil
                    if event?.content["info"] != nil {
                        mimetype = event?.content["info"]["mimetype"] as? String
                    }

                    let localImagePath = MXMediaManager.cachePath(forMatrixContentURI: contentURL, andType: mimetype, inFolder: roomId)
                    let image = MXMediaManager.loadPicture(fromFilePath: localImagePath)
                    if let image = image {
                        // Restart sending the image from the beginning.

                        // Remove the local echo.
                        removeEvent(withEventId: eventId)

                        if let mimetype = mimetype {
                            let imageData = NSData(contentsOfFile: localImagePath) as Data?
                            sendImage(imageData, mimeType: mimetype, success: success, failure: failure)
                        } else {
                            send(image, success: success, failure: failure)
                        }
                    } else {
                        failure(NSError(domain: MXKRoomDataSourceErrorDomain, code: RoomDataSourceError.resendGeneric.rawValue, userInfo: nil))
                        MXLogWarning("[RoomViewModel] resendEventWithEventId: Warning - Unable to resend room message of type: %@", msgType)
                    }
                } else {
                    // Resend the Matrix event by reusing the existing echo
                    room?.sendMessage(withContent: event?.content, localEcho: &event, success: success, failure: failure)
                }
            } else if msgType == kMXMessageTypeAudio {
                // Check whether the sending failed while uploading the data.
                // If the content url corresponds to a upload id, the upload was not complete.
                let contentURL = event?.content["url"] as? String
                if contentURL == nil || !(contentURL?.hasPrefix(kMXMediaUploadIdPrefix) ?? false) {
                    // Resend the Matrix event by reusing the existing echo
                    room?.sendMessage(withContent: event?.content, localEcho: &event, success: success, failure: failure)
                    return
                }

                var mimetype = event?.content["info"]["mimetype"] as? String
                let localFilePath = MXMediaManager.cachePath(forMatrixContentURI: contentURL, andType: mimetype, inFolder: roomId)
                let localFileURL = URL(string: localFilePath)

                if !FileManager.default.fileExists(atPath: localFilePath) {
                    failure(NSError(domain: MXKRoomDataSourceErrorDomain, code: RoomDataSourceError.resendInvalidLocalFilePath.rawValue, userInfo: nil))
                    MXLogWarning("[RoomViewModel] resendEventWithEventId: Warning - Unable to resend voice message, invalid file path.")
                    return
                }

                // Remove the local echo.
                removeEvent(withEventId: eventId)

                if event?.isVoiceMessage {
                    let duration = event?.content[kMXMessageContentKeyExtensibleAudio][kMXMessageContentKeyExtensibleAudioDuration] as? NSNumber
                    let samples = event?.content[kMXMessageContentKeyExtensibleAudio][kMXMessageContentKeyExtensibleAudioWaveform] as? [NSNumber]

                    sendVoiceMessage(localFileURL, mimeType: mimetype, duration: Int(duration?.doubleValue ?? 0.0), samples: samples, success: success, failure: failure)
                } else {
                    sendAudioFile(localFileURL, mimeType: mimetype, success: success, failure: failure)
                }
            } else if msgType == kMXMessageTypeVideo {
                // Check whether the sending failed while uploading the data.
                // If the content url corresponds to a upload id, the upload was not complete.
                let contentURL = event?.content["url"] as? String
                if contentURL != nil && contentURL?.hasPrefix(kMXMediaUploadIdPrefix) ?? false {
                    // TODO: Support resend on attached video when upload has been failed.
                    MXLogDebug("[RoomViewModel] resendEventWithEventId: Warning - Unable to resend attached video (upload was not complete)")
                    failure(NSError(domain: MXKRoomDataSourceErrorDomain, code: RoomDataSourceError.resendInvalidMessageType.rawValue, userInfo: nil))
                } else {
                    // Resend the Matrix event by reusing the existing echo
                    room?.sendMessage(withContent: event?.content, localEcho: &event, success: success, failure: failure)
                }
            } else if msgType == kMXMessageTypeFile {
                // Check whether the sending failed while uploading the data.
                // If the content url corresponds to a upload id, the upload was not complete.
                let contentURL = event?.content["url"] as? String
                if contentURL != nil && contentURL?.hasPrefix(kMXMediaUploadIdPrefix) ?? false {
                    var mimetype: String? = nil
                    if event?.content["info"] != nil {
                        mimetype = event?.content["info"]["mimetype"] as? String
                    }

                    if let mimetype = mimetype {
                        // Restart sending the image from the beginning.

                        // Remove the local echo
                        removeEvent(withEventId: eventId)

                        let localFilePath = MXMediaManager.cachePath(forMatrixContentURI: contentURL, andType: mimetype, inFolder: roomId)

                        sendFile(URL(fileURLWithPath: localFilePath, isDirectory: false), mimeType: mimetype, success: success, failure: failure)
                    } else {
                        failure(NSError(domain: MXKRoomDataSourceErrorDomain, code: RoomDataSourceError.resendGeneric.rawValue, userInfo: nil))
                        MXLogWarning("[RoomViewModel] resendEventWithEventId: Warning - Unable to resend room message of type: %@", msgType)
                    }
                } else {
                    // Resend the Matrix event by reusing the existing echo
                    room?.sendMessage(withContent: event?.content, localEcho: &event, success: success, failure: failure)
                }
            } else {
                failure(NSError(domain: MXKRoomDataSourceErrorDomain, code: RoomDataSourceError.resendInvalidMessageType.rawValue, userInfo: nil))
                MXLogWarning("[RoomViewModel] resendEventWithEventId: Warning - Unable to resend room message of type: %@", msgType)
            }
        } else {
            failure(NSError(domain: MXKRoomDataSourceErrorDomain, code: RoomDataSourceError.resendInvalidMessageType.rawValue, userInfo: nil))
            MXLogWarning("[RoomViewModel] RoomViewModel: Warning - Only resend of MXEventTypeRoomMessage is allowed. Event.type: %@", event?.type)
        }
    }

    // MARK: - Events management
    /// Get an event loaded in this room datasource.
    /// - Parameter eventId: of the event to retrieve.
    /// - Returns: the MXEvent object or nil if not found.

    // MARK: - Events management

    func event(withEventId eventId: String?) -> MXEvent? {
        var theEvent: MXEvent?

        // First, retrieve the cell data hosting the event
        weak var bubbleData = cellDataOfEvent(withEventId: eventId)
        if let bubbleData = bubbleData {
            // Then look into the events in this cell
            for event in bubbleData.events {
                if event.eventId == eventId {
                    theEvent = event
                    break
                }
            }
        }
        return theEvent
    }

    /// Remove an event from the events loaded by room datasource.
    /// - Parameter eventId: of the event to remove.
    func removeEvent(withEventId eventId: String?) {
        // First, retrieve the cell data hosting the event
        weak var bubbleData = cellDataOfEvent(withEventId: eventId)
        if let bubbleData = bubbleData {
            var remainingEvents: Int
            let lockQueue = DispatchQueue(label: "bubbleData")
            lockQueue.sync {
                remainingEvents = bubbleData.removeEvent(eventId)
            }

            // If there is no more events in the bubble, remove it
            if 0 == remainingEvents {
                removeCellData(bubbleData)
            }

            // Remove the event from the outgoing messages storage
            room?.removeOutgoingMessage(eventId)

            // Update the delegate
            if delegate {
                delegate.dataSource(self, didCellChange: nil)
            }
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
        // Do the processing on the same processing queue
        MXWeakify(self)
        RoomViewModel.processingQueue().async(execute: { [self] in
            MXStrongifyAndReturnIfNil(self)

            // Remove the previous displayed read receipt for each user who sent a
            // new read receipt.
            // To implement it, we need to find the sender id of each new read receipt
            // among the read receipts array of all events in all bubbles.
            let readReceiptSenders = receiptEvent?.readReceiptSenders

            let lockQueue = DispatchQueue(label: "bubbles")
            lockQueue.sync {
                for cellData in bubbles ?? [] {
                    guard let cellData = cellData as? MXKRoomBubbleCellData else {
                        continue
                    }
                    var updatedCellDataReadReceipts: [String /* eventId */ : [MXReceiptData]]? = [:]

                    for eventId in cellData.readReceipts {
                        for receiptData in cellData.readReceipts[eventId] {
                            guard let receiptData = receiptData as? MXReceiptData else {
                                continue
                            }
                            for senderId in readReceiptSenders ?? [] {
                                guard let senderId = senderId as? String else {
                                    continue
                                }
                                if receiptData.userId == senderId {
                                    if updatedCellDataReadReceipts?[eventId] == nil {
                                        updatedCellDataReadReceipts?[eventId] = cellData.readReceipts[eventId] as? [MXReceiptData]
                                    }

                                    let predicate = NSPredicate(format: "userId!=%@", receiptData.userId)
                                    updatedCellDataReadReceipts?[eventId] = (updatedCellDataReadReceipts?[eventId] as NSArray?)?.filtered(using: predicate) as? [MXReceiptData]
                                    break
                                }
                            }
                        }
                    }

                    // Flush found changed to the cell data
                    for eventId in updatedCellDataReadReceipts ?? [:] {
                        guard let eventId = eventId as? String else {
                            continue
                        }
                        if (updatedCellDataReadReceipts?[eventId].count ?? 0) != 0 {
                            update(cellData, withReadReceipts: updatedCellDataReadReceipts?[eventId], forEventId: eventId)
                        } else {
                            update(cellData, withReadReceipts: nil, forEventId: eventId)
                        }
                    }
                }
            }

            // Update cell data we have received a read receipt for
            let readEventIds = receiptEvent?.readReceiptEventIds
            for eventId in readEventIds ?? [] {
                guard let eventId = eventId as? String else {
                    continue
                }
                let cellData = cellDataOfEvent(withEventId: eventId) as? MXKRoomBubbleCellData
                if let cellData = cellData {
                    let lockQueue = DispatchQueue(label: "bubbles")
                    lockQueue.sync {
                        addReadReceipts(forEvent: eventId, inCellDatas: bubbles, startingAtCellData: cellData)
                    }
                }
            }

            DispatchQueue.main.async(execute: { [self] in
                if delegate {
                    delegate.dataSource(self, didCellChange: nil)
                }
            })
        })
    }

    /// Update read receipts for an event in a bubble cell data.
    /// - Parameters:
    ///   - cellData: The cell data to update.
    ///   - readReceipts: The new read receipts.
    ///   - eventId: The id of the event.
    func update(_ cellData: MXKRoomBubbleCellData?, withReadReceipts readReceipts: [MXReceiptData]?, forEventId eventId: String?) {
        cellData?.readReceipts[eventId ?? ""] = readReceipts
    }

    /// Overridable method to customise the way how unsent messages are managed.
    /// By default, they are added to the end of the timeline.
    func handleUnsentMessages() {
        // Add the unsent messages at the end of the conversation
        let outgoingMessages = room?.outgoingMessages

        mxSession.decryptEvents(outgoingMessages, inTimeline: nil, onComplete: { [self] failedEvents in
            var shouldProcessQueuedEvents = false

            for index in 0..<(outgoingMessages?.count ?? 0) {
                let outgoingMessage = outgoingMessages?[index]

                if outgoingMessage?.sentState != MXEventSentStateSent {
                    queueEvent(forProcessing: outgoingMessage, with: roomState, direction: MXTimelineDirectionForwards)
                    shouldProcessQueuedEvents = true
                }
            }

            if shouldProcessQueuedEvents {
                processQueuedEvents({ _,_ in })
            }
        })
    }

    // MARK: - Bubble collapsing

    /// Collapse or expand a series of collapsable bubbles.
    /// - Parameters:
    ///   - bubbleData: the first bubble of the series.
    ///   - collapsed: YES to collapse. NO to expand.

    // MARK: - Bubble collapsing

    func collapseRoomBubble(_ bubbleData: MXKRoomBubbleCellDataStoring?, collapsed: Bool) {
        if bubbleData?.collapsed != collapsed {
            weak var nextBubbleData = bubbleData
            repeat {
                nextBubbleData?.collapsed = collapsed
            } while (nextBubbleData = nextBubbleData?.nextCollapsableCellData)

            if delegate {
                // Reload all the table
                delegate.dataSource(self, didCellChange: nil)
            }
        }
    }

    // MARK: - Private methods

    func replace(_ eventToReplace: MXEvent?, with event: MXEvent?) {
        if eventToReplace?.isLocalEvent {
            // Stop listening to the identifier change for the replaced event.
            NotificationCenter.default.removeObserver(self, name: kMXEventDidChangeIdentifierNotification, object: eventToReplace)
        }

        // Retrieve the cell data hosting the replaced event
        weak var bubbleData = cellDataOfEvent(withEventId: eventToReplace?.eventId)
        if bubbleData == nil {
            return
        }

        var remainingEvents: Int
        let lockQueue = DispatchQueue(label: "bubbleData")
        lockQueue.sync {
            // Check whether the local echo is replaced or removed
            if let event = event {
                remainingEvents = bubbleData?.updateEvent(eventToReplace?.eventId, with: event) ?? 0
            } else {
                remainingEvents = bubbleData?.removeEvent(eventToReplace?.eventId) ?? 0
            }
        }

        // Update bubbles mapping
        let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
        lockQueue.sync {
            // Remove the broken link from the map
            eventIdToBubbleMap?.removeValue(forKey: eventToReplace?.eventId)

            if event != nil && remainingEvents != 0 {
                if let eventId = event?.eventId {
                    eventIdToBubbleMap?[eventId] = bubbleData
                }

                if event?.isLocalEvent {
                    // Listen to the identifier change for the local events.
                    NotificationCenter.default.addObserver(self, selector: #selector(localEventDidChangeIdentifier(_:)), name: kMXEventDidChangeIdentifierNotification, object: event)
                }
            }
        }

        // If there is no more events in the bubble, remove it
        if 0 == remainingEvents {
            removeCellData(bubbleData)
        }

        // Update the delegate
        if delegate {
            delegate.dataSource(self, didCellChange: nil)
        }
    }

    func removeCellData(_ cellData: MXKRoomBubbleCellDataStoring?) -> [IndexPath]? {
        var deletedRows: [AnyHashable] = []

        // Remove potential occurrences in bubble map
        let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
        lockQueue.sync {
            if let events = cellData?.events {
                for event in events {
                    guard let event = event as? MXEvent else {
                        continue
                    }
                    eventIdToBubbleMap?.removeValue(forKey: event.eventId)

                    if event.isLocalEvent {
                        // Stop listening to the identifier change for this event.
                        NotificationCenter.default.removeObserver(self, name: kMXEventDidChangeIdentifierNotification, object: event)
                    }
                }
            }
        }

        // Check whether the adjacent bubbles can merge together
        let lockQueue = DispatchQueue(label: "bubbles")
        lockQueue.sync {
            let index = bubbles?.firstIndex(of: cellData) ?? NSNotFound
            if index != NSNotFound {
                bubbles?.remove(at: index)
                deletedRows.append(IndexPath(row: index, section: 0))

                if (bubbles?.count ?? 0) != 0 {
                    // Update flag in remaining data
                    if index == 0 {
                        // We removed here the first bubble.
                        // We have to update the 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags of the new first bubble.
                        weak var firstCellData = bubbles?.first

                        firstCellData?.isPaginationFirstBubble = ((bubblesPagination == .perDay) && firstCellData?.date)

                        // Keep visible the sender information by default,
                        // except if the bubble has no display (composed only by ignored events).
                        firstCellData?.shouldHideSenderInformation = firstCellData?.hasNoDisplay
                    } else if index < (bubbles?.count ?? 0) {
                        // We removed here a bubble which is not the before last.
                        weak var cellData1 = bubbles?[index - 1]
                        weak var cellData2 = bubbles?[index]

                        // Check first whether the neighbor bubbles can merge
                        let `class` = cellDataClass(forCellIdentifier: kMXKRoomBubbleCellDataIdentifier)
                        if `class`.instancesRespond(to: Selector("mergeWithBubbleCellData:")) {
                            if cellData1?.merge(withBubbleCellData: cellData2) {
                                bubbles?.remove(at: index)
                                deletedRows.append(IndexPath(row: index + 1, section: 0))

                                cellData2 = nil
                            }
                        }

                        if let cellData2 = cellData2 {
                            // Update its 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags

                            // Pagination handling
                            if bubblesPagination == .perDay && !cellData2.isPaginationFirstBubble {
                                // Check whether a new pagination starts on the second cellData
                                let cellData1DateString = eventFormatter?.dateString(fromDate: cellData1?.date, withTime: false)
                                let cellData2DateString = eventFormatter?.dateString(fromDate: cellData2.date, withTime: false)

                                if cellData1DateString == nil {
                                    cellData2?.isPaginationFirstBubble = (cellData2DateString != nil && cellData?.isPaginationFirstBubble)
                                } else {
                                    cellData2?.isPaginationFirstBubble = (cellData2DateString != nil && (cellData2DateString != cellData1DateString))
                                }
                            }

                            // Check whether the sender information is relevant for this bubble.
                            // Check first if the bubble is not composed only by ignored events.
                            cellData2?.shouldHideSenderInformation = cellData2.hasNoDisplay
                            if !cellData2.shouldHideSenderInformation && cellData2.isPaginationFirstBubble == false {
                                // Check whether the neighbor bubbles have been sent by the same user.
                                cellData2?.shouldHideSenderInformation = cellData2.hasSameSender(asBubbleCellData: cellData1)
                            }
                        }
                    }
                }
            }
        }

        return deletedRows as? [IndexPath]
    }

    @objc func didMXRoomInitialSynced(_ notif: Notification?) {
        // Refresh the room data source when the room has been initialSync'ed
        let room = notif?.object as? MXRoom
        if mxSession == room?.mxSession && ((roomId == room?.roomId) || (secondaryRoomId == room?.roomId)) {
            MXLogDebug("[RoomViewModel] didMXRoomInitialSynced for room: %@", room?.roomId)

            NotificationCenter.default.removeObserver(self, name: kMXRoomInitialSyncNotification, object: room)

            reload()
        }
    }

    @objc func didMXSessionUpdatePublicisedGroups(forUsers notif: Notification?) {
        // Retrieved the list of the concerned users
        let userIds = notif?.userInfo?[kMXSessionNotificationUserIdsArrayKey] as? [String]
        if (userIds?.count ?? 0) != 0 {
            // Check whether at least one listed user is a room member.
            for userId in userIds ?? [] {
                let roomMember = roomState?.members.member(withUserId: userId)
                if roomMember != nil {
                    // Inform the delegate to refresh the bubble display
                    // We dispatch here this action in order to let each bubble data update their sender flair.
                    if delegate {
                        DispatchQueue.main.async(execute: { [self] in
                            delegate.dataSource(self, didCellChange: nil)
                        })
                    }
                    break
                }
            }
        }
    }

    @objc func eventDidChangeSentState(_ notif: Notification?) {
        let event = notif?.object as? MXEvent
        if event?.roomId == roomId {
            // Retrieve the cell data hosting the local echo
            weak var bubbleData = cellDataOfEvent(withEventId: event?.eventId)
            if bubbleData == nil {
                return
            }

            let lockQueue = DispatchQueue(label: "bubbleData")
            lockQueue.sync {
                bubbleData?.updateEvent(event?.eventId, with: event)
            }

            // Inform the delegate
            if delegate && (secondaryRoom != nil ? (bubbles?.count ?? 0) > 0 : true) != nil {
                delegate.dataSource(self, didCellChange: nil)
            }
        }
    }

    @objc func localEventDidChangeIdentifier(_ notif: Notification?) {
        let event = notif?.object as? MXEvent
        let previousId = notif?.userInfo?[kMXEventIdentifierKey] as? String

        if event != nil && previousId != nil {
            // Update bubbles mapping
            let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
            lockQueue.sync {
                weak var bubbleData = eventIdToBubbleMap?[previousId ?? ""] as? MXKRoomBubbleCellDataStoring
                if bubbleData != nil && event?.eventId {
                    if let eventId = event?.eventId {
                        eventIdToBubbleMap?[eventId] = bubbleData
                    }
                    eventIdToBubbleMap?.removeValue(forKey: previousId)

                    // The bubble data must use the final event id too
                    bubbleData?.updateEvent(previousId, with: event)
                }
            }

            if !event?.isLocalEvent {
                // Stop listening to the identifier change when the event becomes an actual event.
                NotificationCenter.default.removeObserver(self, name: kMXEventDidChangeIdentifierNotification, object: event)
            }
        }
    }

    @objc func eventDidDecrypt(_ notif: Notification?) {
        let event = notif?.object as? MXEvent
        if let type = event?.type {
            if (event?.roomId == roomId) || ((event?.roomId == secondaryRoomId) && secondaryRoomEventTypes?.contains(type) ?? false) {
                // Retrieve the cell data hosting the event
                weak var bubbleData = cellDataOfEvent(withEventId: event?.eventId)
                if bubbleData == nil {
                    return
                }

                // We need to update the data of the cell that displays the event.
                // The trickiest update is when the cell contains several events and the event
                // to update turns out to be an attachment.
                // In this case, we need to split the cell into several cells so that the attachment
                // has its own cell.
                if bubbleData?.events.count == 1 || !eventFormatter?.isSupportedAttachment(event) {
                    // If the event is still a text, a simple update is enough
                    // If the event is an attachment, it has already its own cell. Let the bubble
                    // data handle the type change.
                    let lockQueue = DispatchQueue(label: "bubbleData")
                    lockQueue.sync {
                        bubbleData?.updateEvent(event?.eventId, with: event)
                    }
                } else {
                    let lockQueue = DispatchQueue(label: "bubbleData")
                    lockQueue.sync {
                        var eventIsFirstInBubble = false
                        let bubbleDataIndex = bubbles?.firstIndex(of: bubbleData) ?? NSNotFound

                        // We need to create a dedicated cell for the event attachment.
                        // From the current bubble, remove the updated event and all events after.
                        var removedEvents: [MXEvent]?
                        let remainingEvents = bubbleData?.removeEvents(fromEvent: event?.eventId, removedEvents: &removedEvents) ?? 0

                        // If there is no more events in this bubble, remove it
                        if 0 == remainingEvents {
                            eventIsFirstInBubble = true
                            let lockQueue = DispatchQueue(label: "eventsToProcessSnapshot")
                            lockQueue.sync {
                                bubbles?.remove(at: bubbleDataIndex)
                                bubbleDataIndex -= 1
                            }
                        }

                        // Create a dedicated bubble for the attachment
                        if (removedEvents?.count ?? 0) != 0 {
                            let `class` = cellDataClass(forCellIdentifier: kMXKRoomBubbleCellDataIdentifier)

                            weak var newBubbleData = `class`.init(event: removedEvents?[0], andRoomState: roomState, andRoomDataSource: self) as? MXKRoomBubbleCellDataStoring

                            if eventIsFirstInBubble {
                                // Apply same config as before
                                newBubbleData?.isPaginationFirstBubble = bubbleData?.isPaginationFirstBubble
                                newBubbleData?.shouldHideSenderInformation = bubbleData?.shouldHideSenderInformation
                            } else {
                                // This new bubble is not the first. Show nothing
                                newBubbleData?.isPaginationFirstBubble = false
                                newBubbleData?.shouldHideSenderInformation = true
                            }

                            // Update bubbles mapping
                            let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
                            lockQueue.sync {
                                if let eventId = event?.eventId {
                                    eventIdToBubbleMap?[eventId] = newBubbleData
                                }
                            }

                            let lockQueue = DispatchQueue(label: "eventsToProcessSnapshot")
                            lockQueue.sync {
                                bubbles?.insert(newBubbleData, at: bubbleDataIndex + 1)
                            }
                        }

                        // And put other cutted events in another bubble
                        if (removedEvents?.count ?? 0) > 1 {
                            let `class` = cellDataClass(forCellIdentifier: kMXKRoomBubbleCellDataIdentifier)

                            weak var newBubbleData: MXKRoomBubbleCellDataStoring?
                            for i in 1..<(removedEvents?.count ?? 0) {
                                let removedEvent = removedEvents?[i]
                                if i == 1 {
                                    newBubbleData = `class`.init(event: removedEvent, andRoomState: roomState, andRoomDataSource: self) as? MXKRoomBubbleCellDataStoring
                                } else {
                                    newBubbleData?.add(removedEvent, andRoomState: roomState)
                                }

                                // Update bubbles mapping
                                let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
                                lockQueue.sync {
                                    if let eventId = removedEvent?.eventId {
                                        eventIdToBubbleMap?[eventId] = newBubbleData
                                    }
                                }
                            }

                            // Do not show the
                            newBubbleData?.isPaginationFirstBubble = false
                            newBubbleData?.shouldHideSenderInformation = true

                            let lockQueue = DispatchQueue(label: "eventsToProcessSnapshot")
                            lockQueue.sync {
                                bubbles?.insert(newBubbleData, at: bubbleDataIndex + 2)
                            }
                        }
                    }
                }

                // Update the delegate
                if delegate {
                    delegate.dataSource(self, didCellChange: nil)
                }
            }
        }
    }

    // Indicates whether an event has base requirements to allow actions (like reply, reactions, edit, etc.)
    func canPerformAction(on event: MXEvent?) -> Bool {
        let isSent = event?.sentState == MXEventSentStateSent
        let isRoomMessage = event?.eventType == MXEventTypeRoomMessage

        let messageType = event?.content["msgtype"] as? String

        return isSent && isRoomMessage && messageType != nil && (messageType != "m.bad.encrypted")
    }

    func setState(_ newState: MXKDataSourceState) {
        state = newState

        if delegate && delegate.responds(to: Selector("dataSource:didStateChange:")) {
            delegate.dataSource(self, didStateChange: state)
        }
    }

    // MARK: - Asynchronous events processing
    /// The dispatch queue to process room messages.
    /// This processing can consume time. Handling it on a separated thread avoids to block the main thread.
    /// All RoomViewModel instances share the same dispatch queue.

    // MARK: - Asynchronous events processing

    static var processingQueueVar: DispatchQueue?

    class func processingQueue() -> DispatchQueue {
        // `dispatch_once()` call was converted to a static variable initializer

        return processingQueueVar!
    }

    /// Queue an event in order to process its display later.
    /// - Parameters:
    ///   - event: the event to process.
    ///   - roomState: the state of the room when the event fired.
    ///   - direction: the order of the events in the arrays
    func queueEvent(forProcessing event: MXEvent?, with roomState: MXRoomState?, direction: MXTimelineDirection) {
        if filterMessagesWithURL {
            // Check whether the event has a value for the 'url' key in its content.
            if !event?.getMediaURLs.count {
                // Ignore the event
                return
            }
        }

        // Check for undecryptable messages that were sent while the user was not in the room and hide them
        if AppSettings.standard().hidePreJoinedUndecryptableEvents && direction == MXTimelineDirectionBackwards {
            checkForPreJoinUTD(with: event, roomState: roomState)

            // Hide pre joint UTD events
            if shouldStopBackPagination {
                return
            }
        }

        let queuedEvent = MXKQueuedEvent(event: event, andRoomState: roomState, direction: direction)

        // Count queued events when the server sync is in progress
        if mxSession.state == MXSessionStateSyncInProgress {
            queuedEvent.serverSyncEvent = true
            serverSyncEventCount += 1

            if serverSyncEventCount == 1 {
                // Notify that sync process starts
                NotificationCenter.default.post(name: NSNotification.Name(kMXKRoomDataSourceSyncStatusChanged), object: self, userInfo: nil)
            }
        }

        let lockQueue = DispatchQueue(label: "eventsToProcess")
        lockQueue.sync {
            eventsToProcess?.append(queuedEvent)

            if secondaryRoom != nil {
                //  use a stable sorting here, which means it won't change the order of events unless it has to.
                eventsToProcess = (eventsToProcess as NSArray?)?.sortedArray(options: .stable, usingComparator: { event1, event2 in
                    return event2.eventDate.compare(event1.eventDate)
                }) as? [AnyHashable] ?? eventsToProcess
            }
        }
    }

    func canPaginate(_ direction: MXTimelineDirection) -> Bool {
        if secondaryTimeline != nil {
            if !timeline?.canPaginate(direction) && !secondaryTimeline?.canPaginate(direction) {
                return false
            }
        } else {
            if !timeline?.canPaginate(direction) {
                return false
            }
        }

        if direction == MXTimelineDirectionBackwards && shouldStopBackPagination {
            return false
        }

        return true
    }

    // Check for undecryptable messages that were sent while the user was not in the room.
    func checkForPreJoinUTD(with event: MXEvent?, roomState: MXRoomState?) {
        // Only check for encrypted rooms
        if !(room?.summary.isEncrypted ?? false) {
            return
        }

        // Back pagination is stopped do not check for other pre join events
        if shouldStopBackPagination {
            return
        }

        // if we reach a UTD and flag is set, hide previous encrypted messages and stop back-paginating
        if event?.eventType == MXEventTypeRoomEncrypted && (event?.decryptionError.domain == MXDecryptingErrorDomain) && self.shouldPreventBackPaginationOnPreviousUTDEvent {
            shouldStopBackPagination = true
            return
        }

        shouldStopBackPagination = false

        if event?.eventType != MXEventTypeRoomMember {
            return
        }

        let userId = event?.stateKey

        // Only check "m.room.member" event for current user
        if userId != mxSession.myUserId {
            return
        }

        var shouldPreventBackPaginationOnPreviousUTDEvent = false

        let member = roomState?.members.member(withUserId: userId)

        if let member = member {
            switch member.membership {
            case MXMembershipJoin:
                // if we reach a join event for the user:
                //  - if prev-content is invite, continue back-paginating
                //  - if prev-content is join (was just an avatar or displayname change), continue back-paginating
                //  - otherwise, set a flag and continue back-paginating

                let previousMemberhsip = event?.prevContent["membership"] as? String

                let isPrevContentAnInvite = previousMemberhsip == "invite"
                let isPrevContentAJoin = previousMemberhsip == "join"

                if !(isPrevContentAnInvite || isPrevContentAJoin) {
                    shouldPreventBackPaginationOnPreviousUTDEvent = true
                }
            case MXMembershipInvite:
                // if we reach an invite event for the user, set flag and continue back-paginating
                shouldPreventBackPaginationOnPreviousUTDEvent = true
            default:
                break
            }
        }

        self.shouldPreventBackPaginationOnPreviousUTDEvent = shouldPreventBackPaginationOnPreviousUTDEvent
    }

    func checkBing(_ event: MXEvent?) -> Bool {
        var isHighlighted = false

        // read receipts have no rule
        if event?.type != kMXEventTypeStringReceipt {
            // Check if we should bing this event
            let rule = mxSession.notificationCenter.rule(matching: event, roomState: roomState)
            if let rule = rule {
                // Check whether is there an highlight tweak on it
                for ruleAction in rule.actions {
                    if ruleAction.actionType == MXPushRuleActionTypeSetTweak {
                        if ruleAction.parameters["set_tweak"] == "highlight" {
                            // Check the highlight tweak "value"
                            // If not present, highlight. Else check its value before highlighting
                            if nil == ruleAction.parameters["value"] || true == (ruleAction.parameters["value"] as? NSNumber).boolValue {
                                isHighlighted = true
                                break
                            }
                        }
                    }
                }
            }
        }

        event?.mxkIsHighlighted = isHighlighted
        return isHighlighted
    }

    /// Start processing pending events.
    /// - Parameter onComplete: a block called (on the main thread) when the processing has been done. Can be nil.
    /// Note this block returns the number of added cells in first and last positions.
    func processQueuedEvents(_ onComplete: @escaping (_ addedHistoryCellNb: Int, _ addedLiveCellNb: Int) -> Void) {
        MXWeakify(self)

        // Do the processing on the processing queue
        RoomViewModel.processingQueue().async(execute: { [self] in

            MXStrongifyAndReturnIfNil(self)

            // Note: As this block is always called from the same processing queue,
            // only one batch process is done at a time. Thus, an event cannot be
            // processed twice

            // Snapshot queued events to avoid too long lock.
            let lockQueue = DispatchQueue(label: "eventsToProcess")
            lockQueue.sync {
                if (eventsToProcess?.count ?? 0) != 0 {
                    eventsToProcessSnapshot = eventsToProcess
                    if secondaryRoom != nil {
                        let lockQueue = DispatchQueue(label: "bubbles")
                        lockQueue.sync {
                            bubbles?.removeAll()
                            bubblesSnapshot?.removeAll()
                        }
                    } else {
                        eventsToProcess = []
                    }
                }
            }

            let serverSyncEventCount = 0
            let addedHistoryCellCount = 0
            let addedLiveCellCount = 0

            // Lock on `eventsToProcessSnapshot` to suspend reload or destroy during the process.
            let lockQueue = DispatchQueue(label: "eventsToProcessSnapshot")
            lockQueue.sync {
                // Is there events to process?
                // The list can be empty because several calls of processQueuedEvents may be processed
                // in one pass in the processingQueue
                if (eventsToProcessSnapshot?.count ?? 0) != 0 {
                    // Make a quick copy of changing data to avoid to lock it too long time
                    let lockQueue = DispatchQueue(label: "bubbles")
                    lockQueue.sync {
                        bubblesSnapshot = bubbles
                    }

                    var collapsingCellDataSeriess: Set<MXKRoomBubbleCellDataStoring?>? = []

                    for queuedEvent in eventsToProcessSnapshot ?? [] {
                        guard let queuedEvent = queuedEvent as? MXKQueuedEvent else {
                            continue
                        }
                        autoreleasepool {
                            // Count events received while the server sync was in progress
                            if queuedEvent.serverSyncEvent {
                                serverSyncEventCount += 1
                            }

                            // Check whether the event must be highlighted
                            checkBing(queuedEvent.event)

                            // Retrieve the MXKCellData class to manage the data
                            let `class` = cellDataClass(forCellIdentifier: kMXKRoomBubbleCellDataIdentifier)
                            assert(`class` is MXKRoomBubbleCellDataStoring, "RoomViewModel only manages MXKCellData that conforms to MXKRoomBubbleCellDataStoring protocol")

                            var eventManaged = false
                            var updatedBubbleDataHadNoDisplay = false
                            weak var bubbleData: MXKRoomBubbleCellDataStoring?
                            if `class`.instancesRespond(to: Selector("addEvent:andRoomState:")) && 0 < (bubblesSnapshot?.count ?? 0) {
                                // Try to concatenate the event to the last or the oldest bubble?
                                if queuedEvent.direction == MXTimelineDirectionBackwards {
                                    bubbleData = bubblesSnapshot?.first
                                } else {
                                    bubbleData = bubblesSnapshot?.last
                                }

                                let lockQueue = DispatchQueue(label: "bubbleData")
                                lockQueue.sync {
                                    updatedBubbleDataHadNoDisplay = bubbleData?.hasNoDisplay ?? false
                                    eventManaged = bubbleData?.addEvent(queuedEvent.event, andRoomState: queuedEvent.state) ?? false
                                }
                            }

                            if false == eventManaged {
                                // The event has not been concatenated to an existing cell, create a new bubble for this event
                                bubbleData = `class`.init(event: queuedEvent.event, andRoomState: queuedEvent.state, andRoomDataSource: self) as? MXKRoomBubbleCellDataStoring
                                if bubbleData == nil {
                                    // The event is ignored
                                    continue
                                }

                                // Check cells collapsing
                                if bubbleData?.hasAttributedTextMessage {
                                    if bubbleData?.collapsable {
                                        if queuedEvent.direction == MXTimelineDirectionBackwards {
                                            // Try to collapse it with the series at the start of self.bubbles
                                            if collapsableSeriesAtStart != nil && collapsableSeriesAtStart?.collapse(with: bubbleData) {
                                                // bubbleData becomes the oldest cell data of the current series
                                                collapsableSeriesAtStart?.prevCollapsableCellData = bubbleData
                                                bubbleData.nextCollapsableCellData = collapsableSeriesAtStart

                                                // The new cell must have the collapsed state as the series
                                                bubbleData.collapsed = collapsableSeriesAtStart?.collapsed

                                                // Release data of the previous header
                                                collapsableSeriesAtStart?.collapseState = nil
                                                collapsableSeriesAtStart?.collapsedAttributedTextMessage = nil
                                                collapsingCellDataSeriess?.remove(collapsableSeriesAtStart)

                                                // And keep a ref of data for the new start of the series
                                                collapsableSeriesAtStart = bubbleData
                                                collapsableSeriesAtStart?.collapseState = queuedEvent.state
                                                collapsingCellDataSeriess?.insert(collapsableSeriesAtStart)
                                            } else {
                                                // This is a ending point for a new collapsable series of cells
                                                collapsableSeriesAtStart = bubbleData
                                                collapsableSeriesAtStart?.collapseState = queuedEvent.state
                                                collapsingCellDataSeriess?.insert(collapsableSeriesAtStart)
                                            }
                                        } else {
                                            // Try to collapse it with the series at the end of self.bubbles
                                            if collapsableSeriesAtEnd != nil && collapsableSeriesAtEnd?.collapse(with: bubbleData) {
                                                // Put bubbleData at the series tail
                                                // Find the tail
                                                weak var tailBubbleData = collapsableSeriesAtEnd
                                                while tailBubbleData?.nextCollapsableCellData {
                                                    tailBubbleData = tailBubbleData?.nextCollapsableCellData
                                                }

                                                tailBubbleData?.nextCollapsableCellData = bubbleData
                                                bubbleData.prevCollapsableCellData = tailBubbleData

                                                // The new cell must have the collapsed state as the series
                                                bubbleData.collapsed = tailBubbleData?.collapsed

                                                // If the start of the collapsible series stems from an event in a different processing
                                                // batch, we need to track it here so that we can update the summary string later
                                                if let collapsableSeriesAtEnd = collapsableSeriesAtEnd {
                                                    if !collapsingCellDataSeriess?.contains(collapsableSeriesAtEnd) {
                                                        collapsingCellDataSeriess?.insert(collapsableSeriesAtEnd)
                                                    }
                                                }
                                            } else {
                                                // This is a starting point for a new collapsable series of cells
                                                collapsableSeriesAtEnd = bubbleData
                                                collapsableSeriesAtEnd?.collapseState = queuedEvent.state
                                                collapsingCellDataSeriess?.insert(collapsableSeriesAtEnd)
                                            }
                                        }
                                    } else {
                                        // The new bubble is not collapsable.
                                        // We can close one border of the current series being built (if any)
                                        if queuedEvent.direction == MXTimelineDirectionBackwards && collapsableSeriesAtStart != nil {
                                            // This is the begin border of the series
                                            collapsableSeriesAtStart = nil
                                        } else if queuedEvent.direction == MXTimelineDirectionForwards && collapsableSeriesAtEnd != nil {
                                            // This is the end border of the series
                                            collapsableSeriesAtEnd = nil
                                        }
                                    }
                                }

                                if queuedEvent.direction == MXTimelineDirectionBackwards {
                                    // The new bubble data will be inserted at first position.
                                    // We have to update the 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags of the current first bubble.

                                    // Pagination handling
                                    if (bubblesPagination == .perDay) && bubbleData?.date {
                                        // A new pagination starts with this new bubble data
                                        bubbleData.isPaginationFirstBubble = true

                                        // Check whether the current first displayed pagination title is still relevant.
                                        if (bubblesSnapshot?.count ?? 0) != 0 {
                                            let index = 0
                                            weak var previousFirstBubbleDataWithDate: MXKRoomBubbleCellDataStoring?
                                            var firstBubbleDateString: String?
                                            while index < (bubblesSnapshot?.count ?? 0) {
                                                previousFirstBubbleDataWithDate = bubblesSnapshot?[index]
                                                index += 1
                                                firstBubbleDateString = eventFormatter?.dateString(fromDate: previousFirstBubbleDataWithDate?.date, withTime: false)

                                                if firstBubbleDateString != nil {
                                                    break
                                                }
                                            }

                                            if let firstBubbleDateString = firstBubbleDateString {
                                                let bubbleDateString = eventFormatter?.dateString(fromDate: bubbleData?.date, withTime: false)
                                                previousFirstBubbleDataWithDate?.isPaginationFirstBubble = (bubbleDateString != nil && (firstBubbleDateString != bubbleDateString))
                                            }
                                        }
                                    } else {
                                        bubbleData.isPaginationFirstBubble = false
                                    }

                                    // Sender information are required for this new first bubble data,
                                    // except if the bubble has no display (composed only by ignored events).
                                    bubbleData.shouldHideSenderInformation = bubbleData?.hasNoDisplay

                                    // Check whether this information is relevant for the current first bubble.
                                    if !bubbleData?.shouldHideSenderInformation && (bubblesSnapshot?.count ?? 0) != 0 {
                                        weak var previousFirstBubbleData = bubblesSnapshot?.first

                                        if previousFirstBubbleData?.isPaginationFirstBubble == false {
                                            // Check whether the current first bubble has been sent by the same user.
                                            previousFirstBubbleData?.shouldHideSenderInformation |= previousFirstBubbleData?.hasSameSender(asBubbleCellData: bubbleData)
                                        }
                                    }

                                    // Insert the new bubble data in first position
                                    bubblesSnapshot?.insert(bubbleData, at: 0)

                                    addedHistoryCellCount += 1
                                } else {
                                    // The new bubble data will be added at the last position
                                    // We have to update its 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags according to the previous last bubble.

                                    // Pagination handling
                                    if bubblesPagination == .perDay {
                                        // Check whether a new pagination starts at this bubble
                                        let bubbleDateString = eventFormatter?.dateString(fromDate: bubbleData?.date, withTime: false)

                                        // Look for the current last bubble with date
                                        let index = bubblesSnapshot?.count ?? 0
                                        var lastBubbleDateString: String?
                                        while index -= 1 {
                                            weak var previousLastBubbleData = bubblesSnapshot?[index]
                                            lastBubbleDateString = eventFormatter?.dateString(fromDate: previousLastBubbleData?.date, withTime: false)

                                            if lastBubbleDateString != nil {
                                                break
                                            }
                                        }

                                        if let lastBubbleDateString = lastBubbleDateString {
                                            bubbleData.isPaginationFirstBubble = (bubbleDateString != nil && (bubbleDateString != lastBubbleDateString))
                                        } else {
                                            bubbleData.isPaginationFirstBubble = (bubbleDateString != nil)
                                        }
                                    } else {
                                        bubbleData.isPaginationFirstBubble = false
                                    }

                                    // Check whether the sender information is relevant for this new bubble.
                                    bubbleData.shouldHideSenderInformation = bubbleData?.hasNoDisplay
                                    if !bubbleData?.shouldHideSenderInformation && (bubblesSnapshot?.count ?? 0) != 0 && (bubbleData?.isPaginationFirstBubble == false) {
                                        // Check whether the previous bubble has been sent by the same user.
                                        weak var previousLastBubbleData = bubblesSnapshot?.last
                                        bubbleData.shouldHideSenderInformation = bubbleData?.hasSameSender(asBubbleCellData: previousLastBubbleData)
                                    }

                                    // Insert the new bubble in last position
                                    if let bubbleData = bubbleData {
                                        bubblesSnapshot?.append(bubbleData)
                                    }

                                    addedLiveCellCount += 1
                                }
                            } else if updatedBubbleDataHadNoDisplay && !bubbleData?.hasNoDisplay {
                                // Here the event has been added in an existing bubble data which had no display,
                                // and the added event provides a display to this bubble data.
                                if queuedEvent.direction == MXTimelineDirectionBackwards {
                                    // The bubble is the first one.

                                    // Pagination handling
                                    if (bubblesPagination == .perDay) && bubbleData?.date {
                                        // A new pagination starts with this bubble data
                                        bubbleData.isPaginationFirstBubble = true

                                        // Look for the first next bubble with date to check whether its pagination title is still relevant.
                                        if (bubblesSnapshot?.count ?? 0) != 0 {
                                            let index = 1
                                            weak var nextBubbleDataWithDate: MXKRoomBubbleCellDataStoring?
                                            var firstNextBubbleDateString: String?
                                            while index < (bubblesSnapshot?.count ?? 0) {
                                                nextBubbleDataWithDate = bubblesSnapshot?[index]
                                                index += 1
                                                firstNextBubbleDateString = eventFormatter?.dateString(fromDate: nextBubbleDataWithDate?.date, withTime: false)

                                                if firstNextBubbleDateString != nil {
                                                    break
                                                }
                                            }

                                            if let firstNextBubbleDateString = firstNextBubbleDateString {
                                                let bubbleDateString = eventFormatter?.dateString(fromDate: bubbleData?.date, withTime: false)
                                                nextBubbleDataWithDate?.isPaginationFirstBubble = (bubbleDateString != nil && (firstNextBubbleDateString != bubbleDateString))
                                            }
                                        }
                                    } else {
                                        bubbleData.isPaginationFirstBubble = false
                                    }

                                    // Sender information are required for this new first bubble data
                                    bubbleData.shouldHideSenderInformation = false

                                    // Check whether this information is still relevant for the next bubble.
                                    if (bubblesSnapshot?.count ?? 0) > 1 {
                                        weak var nextBubbleData = bubblesSnapshot?[1]

                                        if nextBubbleData?.isPaginationFirstBubble == false {
                                            // Check whether the current first bubble has been sent by the same user.
                                            nextBubbleData?.shouldHideSenderInformation |= nextBubbleData?.hasSameSender(asBubbleCellData: bubbleData)
                                        }
                                    }
                                } else {
                                    // The bubble data is the last one

                                    // Pagination handling
                                    if bubblesPagination == .perDay {
                                        // Check whether a new pagination starts at this bubble
                                        let bubbleDateString = eventFormatter?.dateString(fromDate: bubbleData?.date, withTime: false)

                                        // Look for the first previous bubble with date
                                        let index = (bubblesSnapshot?.count ?? 0) - 1
                                        var firstPreviousBubbleDateString: String?
                                        while index -= 1 {
                                            weak var previousBubbleData = bubblesSnapshot?[index]
                                            firstPreviousBubbleDateString = eventFormatter?.dateString(fromDate: previousBubbleData?.date, withTime: false)

                                            if firstPreviousBubbleDateString != nil {
                                                break
                                            }
                                        }

                                        if let firstPreviousBubbleDateString = firstPreviousBubbleDateString {
                                            bubbleData.isPaginationFirstBubble = (bubbleDateString != nil && (bubbleDateString != firstPreviousBubbleDateString))
                                        } else {
                                            bubbleData.isPaginationFirstBubble = (bubbleDateString != nil)
                                        }
                                    } else {
                                        bubbleData.isPaginationFirstBubble = false
                                    }

                                    // Check whether the sender information is relevant for this new bubble.
                                    bubbleData.shouldHideSenderInformation = false
                                    if (bubblesSnapshot?.count ?? 0) != 0 && (bubbleData?.isPaginationFirstBubble == false) {
                                        // Check whether the previous bubble has been sent by the same user.
                                        let index = (bubblesSnapshot?.count ?? 0) - 1
                                        if index -= 1 != 0 {
                                            weak var previousBubbleData = bubblesSnapshot?[index]
                                            bubbleData.shouldHideSenderInformation = bubbleData?.hasSameSender(asBubbleCellData: previousBubbleData)
                                        }
                                    }
                                }
                            }

                            updateCellDataReactions(bubbleData, forEventId: queuedEvent.event.eventId)

                            // Store event-bubble link to the map
                            let lockQueue = DispatchQueue(label: "eventIdToBubbleMap")
                            lockQueue.sync {
                                eventIdToBubbleMap?[queuedEvent.event.eventId] = bubbleData
                            }

                            if queuedEvent.event.isLocalEvent {
                                // Listen to the identifier change for the local events.
                                NotificationCenter.default.addObserver(self, selector: #selector(localEventDidChangeIdentifier(_:)), name: kMXEventDidChangeIdentifierNotification, object: queuedEvent.event)
                            }
                        }
                    }

                    for queuedEvent in eventsToProcessSnapshot ?? [] {
                        guard let queuedEvent = queuedEvent as? MXKQueuedEvent else {
                            continue
                        }
                        autoreleasepool {
                            addReadReceipts(forEvent: queuedEvent.event.eventId, inCellDatas: bubblesSnapshot, startingAtCellData: eventIdToBubbleMap?[queuedEvent.event.eventId] as? MXKRoomBubbleCellDataStoring)
                        }
                    }

                    // Check if all cells of self.bubbles belongs to a single collapse series.
                    // In this case, collapsableSeriesAtStart and collapsableSeriesAtEnd must be equal
                    // in order to handle next forward or backward pagination.
                    if collapsableSeriesAtStart != nil && collapsableSeriesAtStart == bubbles?.first {
                        // Find the tail
                        weak var tailBubbleData = collapsableSeriesAtStart
                        while tailBubbleData?.nextCollapsableCellData {
                            tailBubbleData = tailBubbleData?.nextCollapsableCellData
                        }

                        if tailBubbleData == bubbles?.last {
                            collapsableSeriesAtEnd = collapsableSeriesAtStart
                        }
                    } else if let collapsableSeriesAtEnd = collapsableSeriesAtEnd {
                        // Find the start
                        weak var startBubbleData = collapsableSeriesAtEnd
                        while startBubbleData?.prevCollapsableCellData {
                            startBubbleData = startBubbleData?.prevCollapsableCellData
                        }

                        if startBubbleData == bubbles?.first {
                            collapsableSeriesAtStart = collapsableSeriesAtEnd
                        }
                    }

                    // Compose (= compute collapsedAttributedTextMessage) of collapsable seriess
                    for bubbleData in collapsingCellDataSeriess ?? [] {
                        // Get all events of the series
                        var events: [MXEvent]? = []
                        weak var nextBubbleData = bubbleData
                        repeat {
                            if let events1 = nextBubbleData?.events {
                                events?.append(contentsOf: events1)
                            }
                        } while (nextBubbleData = nextBubbleData?.nextCollapsableCellData)

                        // Build the summary string for the series
                        do {
                            bubbleData.collapsedAttributedTextMessage = try eventFormatter?.attributedString(fromEvents: events, withRoomState: bubbleData.collapseState)
                        } catch {
                        }

                        // Release collapseState objects, even the one of collapsableSeriesAtStart.
                        // We do not need to keep its state because if an collapsable event comes before collapsableSeriesAtStart,
                        // we will take the room state of this event.
                        if bubbleData != collapsableSeriesAtEnd {
                            bubbleData.collapseState = nil
                        }
                    }
                }
                eventsToProcessSnapshot = nil
            }

            // Check whether some events have been processed
            if let bubblesSnapshot = bubblesSnapshot {
                // Updated data can be displayed now
                // Block RoomViewModel.processingQueue while the processing is finalised on the main thread
                DispatchQueue.main.sync(execute: { [self] in

                    // Check whether self has not been reloaded or destroyed
                    if state == MXKDataSourceStateReady && bubblesSnapshot != nil {
                        if self.serverSyncEventCount != 0 {
                            self.serverSyncEventCount -= serverSyncEventCount
                            if self.serverSyncEventCount == 0 {
                                // Notify that sync process ends
                                NotificationCenter.default.post(name: NSNotification.Name(kMXKRoomDataSourceSyncStatusChanged), object: self, userInfo: nil)
                            }
                        }

                        bubbles = bubblesSnapshot
                        bubblesSnapshot = nil

                        if delegate {
                            delegate.dataSource(self, didCellChange: nil)
                        } else {
                            // Check the memory usage of the data source. Reload it if the cache is too huge.
                            limitMemoryUsage(Int(maxBackgroundCachedBubblesCount))
                        }
                    }

                    // Inform about the end if requested
                    if onComplete != nil {
                        onComplete(addedHistoryCellCount, addedLiveCellCount)
                    }
                })
            } else {
                // No new event has been added, we just inform about the end if requested.
                if onComplete != nil {
                    DispatchQueue.main.async(execute: {
                        onComplete(0, 0)
                    })
                }
            }
        })
    }

    /// Add the read receipts of an event into the timeline (which is in array of cell datas)
    /// If the event is not displayed, read receipts will be added to a previous displayed message.
    /// - Parameters:
    ///   - eventId: the id of the event.
    ///   - cellDatas: the working array of cell datas.
    ///   - cellData: the original cell data the event belongs to.
    func addReadReceipts(forEvent eventId: String?, inCellDatas cellDatas: [MXKRoomBubbleCellDataStoring?]?, startingAtCellData cellData: MXKRoomBubbleCellDataStoring?) {
        if showBubbleReceipts {
            let readReceipts = room?.getEventReceipts(eventId, sorted: true)
            if (readReceipts?.count ?? 0) != 0 {
                let cellDataIndex = cellDatas?.firstIndex(of: cellData) ?? NSNotFound
                if cellDataIndex != NSNotFound {
                    addReadReceipts(readReceipts, forEvent: eventId, inCellDatas: cellDatas, atCellDataIndex: cellDataIndex)
                }
            }
        }
    }

    func addReadReceipts(_ readReceipts: [MXReceiptData]?, forEvent eventId: String?, inCellDatas cellDatas: [MXKRoomBubbleCellDataStoring?]?, atCellDataIndex cellDataIndex: Int) {
        weak var cellData = cellDatas?[cellDataIndex]

        if cellData is MXKRoomBubbleCellData {
            let roomBubbleCellData = cellData as? MXKRoomBubbleCellData

            var areReadReceiptsAssigned = false
            if let reverseObjectEnumerator = roomBubbleCellData?.bubbleComponents.reverseObjectEnumerator() {
                for component in reverseObjectEnumerator {
                    guard let component = component as? MXKRoomBubbleComponent else {
                        continue
                    }
                    if component.attributedTextMessage {
                        if roomBubbleCellData?.readReceipts[component.event.eventId] != nil {
                            let currentReadReceipts = roomBubbleCellData?.readReceipts[component.event.eventId] as? [MXReceiptData]
                            var newReadReceipts: [MXReceiptData]? = nil
                            if let currentReadReceipts = currentReadReceipts {
                                newReadReceipts = currentReadReceipts
                            }
                            for readReceipt in readReceipts ?? [] {
                                var alreadyHere = false
                                for currentReadReceipt in currentReadReceipts ?? [] {
                                    if readReceipt.userId == currentReadReceipt.userId {
                                        alreadyHere = true
                                        break
                                    }
                                }

                                if !alreadyHere {
                                    newReadReceipts?.append(readReceipt)
                                }
                            }
                            update(roomBubbleCellData, withReadReceipts: newReadReceipts, forEventId: component.event.eventId)
                        } else {
                            update(roomBubbleCellData, withReadReceipts: readReceipts, forEventId: component.event.eventId)
                        }
                        areReadReceiptsAssigned = true
                        break
                    }

                    MXLogDebug("[RoomViewModel] addReadReceipts: Read receipts for an event(%@) that is not displayed", eventId)
                }
            }

            if !areReadReceiptsAssigned {
                MXLogDebug("[RoomViewModel] addReadReceipts: Try to attach read receipts to an older message: %@", eventId)

                // Try to assign RRs to a previous cell data
                if cellDataIndex >= 1 {
                    addReadReceipts(readReceipts, forEvent: eventId, inCellDatas: cellDatas, atCellDataIndex: cellDataIndex - 1)
                } else {
                    MXLogDebug("[RoomViewModel] addReadReceipts: Fail to attach read receipts for an event(%@)", eventId)
                }
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // PATCH: Presently no bubble must be displayed until the user joins the room.
        // FIXME: Handle room data source in case of room preview
        if room?.summary.membership == MXMembershipInvite {
            return 0
        }

        var count: Int
        let lockQueue = DispatchQueue(label: "bubbles")
        lockQueue.sync {
            count = bubbles?.count ?? 0
        }
        return count
    }

    func scanBubbleDataIfNeeded(_ bubbleData: MXKRoomBubbleCellDataStoring?) {
        let scanManager = mxSession.scanManager

        if scanManager == nil && !(bubbleData is MXKRoomBubbleCellData) {
            return
        }

        let roomBubbleCellData = bubbleData as? MXKRoomBubbleCellData

        let contentURL = roomBubbleCellData?.attachment.contentURL as? String

        // If the content url corresponds to an upload id, the upload is in progress or not complete.
        // Create a fake event scan with in progress status when uploading media.
        // Since there is no event scan in database it will be overriden by MXScanManager on media upload complete.
        if contentURL != nil && contentURL?.hasPrefix(kMXMediaUploadIdPrefix) ?? false {
            let firstBubbleComponent = roomBubbleCellData?.bubbleComponents.first as? MXKRoomBubbleComponent
            let firstBubbleComponentEvent = firstBubbleComponent?.event

            if firstBubbleComponent != nil && firstBubbleComponent?.eventScan.antivirusScanStatus != MXAntivirusScanStatusInProgress && firstBubbleComponentEvent != nil {
                let uploadEventScan = MXEventScan()
                uploadEventScan.eventId = firstBubbleComponentEvent?.eventId
                uploadEventScan.antivirusScanStatus = MXAntivirusScanStatusInProgress
                uploadEventScan.antivirusScanDate = nil
                uploadEventScan.mediaScans = []

                firstBubbleComponent?.eventScan = uploadEventScan
            }
        } else {
            if let bubbleComponents = roomBubbleCellData?.bubbleComponents {
                for bubbleComponent in bubbleComponents {
                    guard let bubbleComponent = bubbleComponent as? MXKRoomBubbleComponent else {
                        continue
                    }
                    let event = bubbleComponent.event

                    if event?.isContentScannable() {
                        scanManager?.scanEventIfNeeded(event)
                        // NOTE: - [MXScanManager scanEventIfNeeded:] perform modification in background, so - [MXScanManager eventScanWithId:] do not retrieve the last state of event scan.
                        // It is noticeable when eventScan should be created for the first time. It would be better to return an eventScan with an in progress scan status instead of nil.
                        let eventScan = scanManager?.eventScan(withId: event?.eventId)
                        bubbleComponent.eventScan = eventScan
                    }
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        weak var cell: (UITableViewCell & MXKCellRendering)?

        weak var bubbleData = cellData(at: indexPath.row)

        // Launch an antivirus scan on events contained in bubble data if needed
        scanBubbleDataIfNeeded(bubbleData)

        if bubbleData != nil && delegate {
            // Retrieve the cell identifier according to cell data.
            let identifier = delegate.cellReuseIdentifier(forCellData: bubbleData)
            if identifier != "" {
                cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)

                // Make sure we listen to user actions on the cell
                cell?.delegate = self

                // Update typing flag before rendering
                if let senderId = bubbleData?.senderId {
                    bubbleData?.isTyping = showTypingNotifications && currentTypingUsers != nil && ((currentTypingUsers?.firstIndex(of: senderId) ?? NSNotFound) != NSNotFound)
                }
                // Report the current timestamp display option
                bubbleData?.showBubbleDateTime = showBubblesDateTime
                // display the read receipts
                bubbleData?.showBubbleReceipts = showBubbleReceipts
                // let the caller application manages the time label?
                bubbleData?.useCustomDateTimeLabel = useCustomDateTimeLabel
                // let the caller application manages the receipt?
                bubbleData?.useCustomReceipts = useCustomReceipts
                // let the caller application manages the unsent button?
                bubbleData?.useCustomUnsentButton = useCustomUnsentButton

                // Make the bubble display the data
                cell?.render(bubbleData)
            }
        }

        // Sanity check: this method may be called during a layout refresh while room data have been modified.
        if cell == nil {
            // Return an empty cell
            return UITableViewCell(style: .default, reuseIdentifier: "fakeCell")
        }

        return cell!
    }

    // MARK: - Groups

    /// Get a MXGroup instance for a group.
    /// This method is used by the bubble to retrieve a related groups of the room.
    /// - Parameter groupId: The identifier to the group.
    /// - Returns: the MXGroup instance.

    // MARK: - Groups

    func group(withGroupId groupId: String?) -> MXGroup? {
        var group = mxSession.group(withGroupId: groupId)
        if group == nil {
            // Check whether an instance has been already created.
            group = externalRelatedGroups?[groupId ?? ""]
        }

        if group == nil {
            // Create a new group instance.
            group = MXGroup(groupId: groupId)
            externalRelatedGroups?[groupId] = group

            // Retrieve at least the group profile
            mxSession.updateGroupProfile(group, success: nil, failure: { error in

                MXLogDebug("[RoomViewModel] groupWithGroupId: group profile update failed %@", groupId)

            })
        }

        return group
    }

    // MARK: - MXScanManager notifications

    func registerScanManagerNotifications() {
        NotificationCenter.default.removeObserver(self, name: MXScanManagerEventScanDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(eventScansDidChange(_:)), name: MXScanManagerEventScanDidChangeNotification, object: nil)
    }

    func unregisterScanManagerNotifications() {
        NotificationCenter.default.removeObserver(self, name: MXScanManagerEventScanDidChangeNotification, object: nil)
    }

    @objc func eventScansDidChange(_ notification: Notification?) {
        // TODO: Avoid to call the delegate to often. Set a minimum time interval to avoid table view flickering.
        delegate.dataSource(self, didCellChange: nil)
    }

    // MARK: - Reactions

    func registerReactionsChangeListener() {
        if !showReactions || reactionsChangeListener != nil {
            return
        }

        MXWeakify(self)
        reactionsChangeListener = mxSession.aggregations.listenToReactionCountUpdate(inRoom: roomId) { [self] changes in
            MXStrongifyAndReturnIfNil(self)

            var updated = false
            for eventId in changes {
                guard let eventId = eventId as? String else {
                    continue
                }
                weak var bubbleData = cellDataOfEvent(withEventId: eventId)
                if let bubbleData = bubbleData {
                    // TODO: Be smarted and use changes[eventId]
                    updateCellDataReactions(bubbleData, forEventId: eventId)
                    updated = true
                }
            }

            if updated {
                delegate.dataSource(self, didCellChange: nil)
            }
        }
    }

    func unregisterReactionsChangeListener() {
        if reactionsChangeListener != nil {
            mxSession.aggregations.removeListener(reactionsChangeListener)
            reactionsChangeListener = nil
        }
    }

    /// Update reactions for an event in a bubble cell data.
    /// - Parameters:
    ///   - cellData: The cell data to update.
    ///   - eventId: The id of the event.
    func updateCellDataReactions(_ cellData: MXKRoomBubbleCellDataStoring?, forEventId eventId: String?) {
        if !showReactions || !(cellData is MXKRoomBubbleCellData) {
            return
        }

        let roomBubbleCellData = cellData as? MXKRoomBubbleCellData

        var aggregatedReactions = mxSession.aggregations.aggregatedReactions(onEvent: eventId, inRoom: roomId).aggregatedReactionsWithNonZeroCount

        if showOnlySingleEmojiReactions {
            aggregatedReactions = aggregatedReactions?.aggregatedReactionsWithSingleEmoji
        }

        if let aggregatedReactions = aggregatedReactions {
            if !roomBubbleCellData?.reactions {
                roomBubbleCellData?.reactions = [AnyHashable : Any]()
            }

            roomBubbleCellData?.reactions[eventId ?? ""] = aggregatedReactions
        } else {
            // unreaction
            roomBubbleCellData?.reactions[eventId ?? ""] = nil
        }

        // Recompute the text message layout
        roomBubbleCellData?.attributedTextMessage = nil
    }

    // MARK: - Reactions

    /// Indicates if it's possible to react on the event.
    /// - Parameter eventId: The id of the event.
    /// - Returns: True to indicates reaction possibility for this event.
    func canReactToEvent(withId eventId: String?) -> Bool {
        var canReact = false

        let event = self.event(withEventId: eventId)

        if canPerformAction(on: event) {
            let messageType = event?.content["msgtype"] as? String

            if messageType == kMXMessageTypeKeyVerificationRequest {
                canReact = false
            } else {
                canReact = true
            }
        }

        return canReact
    }

    /// Send a reaction to an event.
    /// - Parameters:
    ///   - reaction: Reaction to add.
    ///   - eventId: The id of the event.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func addReaction(_ reaction: String?, forEventId eventId: String?, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        mxSession.aggregations.addReaction(reaction, forEvent: eventId, inRoom: roomId, success: success, failure: { error in
            MXLogDebug("[RoomViewModel] Fail to send reaction on eventId: %@", eventId)
            if failure != nil {
                failure(error)
            }
        })
    }

    /// Unreact a reaction to an event.
    /// - Parameters:
    ///   - reaction: Reaction to unreact.
    ///   - eventId: The id of the event.
    ///   - success: A block object called when the operation succeeds.
    ///   - failure: A block object called when the operation fails.
    func removeReaction(_ reaction: String?, forEventId eventId: String?, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        mxSession.aggregations.removeReaction(reaction, forEvent: eventId, inRoom: roomId, success: success, failure: { error in
            MXLogDebug("[RoomViewModel] Fail to unreact on eventId: %@", eventId)
            if failure != nil {
                failure(error)
            }
        })
    }

    // MARK: - Editions

    /// Indicates if it's possible to edit the event content.
    /// - Parameter eventId: The id of the event.
    /// - Returns: True to indicates edition possibility for this event.

    // MARK: - Editions

    func canEditEvent(withId eventId: String?) -> Bool {
        let event = self.event(withEventId: eventId)
        let isRoomMessage = event?.eventType == MXEventTypeRoomMessage
        let messageType = event?.content["msgtype"] as? String

        return isRoomMessage && ((messageType == kMXMessageTypeText) || (messageType == kMXMessageTypeEmote)) && (event?.sender == mxSession.myUserId) && (event?.roomId == roomId)
    }

    /// Retrieve editable text message from an event.
    /// - Parameter event: An event.
    /// - Returns: Event text editable by user.
    func editableTextMessage(for event: MXEvent?) -> String? {
        var editableTextMessage: String?

        if event?.isReplyEvent {
            let replyEventParser = MXReplyEventParser()
            let replyEventParts = replyEventParser.parse(event)

            editableTextMessage = replyEventParts?.bodyParts.replyText
        } else {
            editableTextMessage = event?.content["body"] as? String
        }

        return editableTextMessage
    }

    func registerEventEditsListener() {
        if eventEditsListener != nil {
            return
        }

        MXWeakify(self)
        eventEditsListener = mxSession.aggregations.listenToEditsUpdate(inRoom: roomId) { [self] replaceEvent in
            MXStrongifyAndReturnIfNil(self)

            updateEvent(withReplace: replaceEvent)
        }
    }

    func updateEvent(withReplace replaceEvent: MXEvent?) {
        let editedEventId = replaceEvent?.relatesTo.eventId

        RoomViewModel.processingQueue().async(execute: { [self] in

            // Check whether a message contains the edited event
            weak var bubbleData = cellDataOfEvent(withEventId: editedEventId)
            if let bubbleData = bubbleData {
                let hasChanged = updateCellData(bubbleData, forEditionWithReplace: replaceEvent, andEventId: editedEventId)

                if hasChanged {
                    // Update the delegate on main thread
                    DispatchQueue.main.async(execute: { [self] in

                        if delegate {
                            delegate.dataSource(self, didCellChange: nil)
                        }

                    })
                }
            }
        })
    }

    func unregisterEventEditsListener() {
        if eventEditsListener != nil {
            mxSession.aggregations.removeListener(eventEditsListener)
            eventEditsListener = nil
        }
    }

    func updateCellData(_ bubbleCellData: MXKRoomBubbleCellDataStoring?, forEditionWithReplace replaceEvent: MXEvent?, andEventId eventId: String?) -> Bool {
        var hasChanged = false

        let lockQueue = DispatchQueue(label: "bubbleCellData")
        lockQueue.sync {
            // Retrieve the original event to edit it
            let events = bubbleCellData?.events
            var editedEvent: MXEvent? = nil

            // If not already done, update edited event content in-place
            // This is required for:
            //   - local echo
            //   - non live timeline in memory store (permalink)
            for event in events ?? [] {
                guard let event = event as? MXEvent else {
                    continue
                }
                if event.eventId == eventId {
                    // Check whether the event was not already edited
                    if event.unsignedData.relations.replace.eventId != replaceEvent?.eventId {
                        editedEvent = event.editedEvent(fromReplacementEvent: replaceEvent)
                    }
                    break
                }
            }

            if let editedEvent = editedEvent {
                if editedEvent.sentState != replaceEvent?.sentState {
                    // Relay the replace event state to the edited event so that the display
                    // of the edited will rerun the classic sending color flow.
                    // Note: this must be done on the main thread (this operation triggers
                    // the call of [self eventDidChangeSentState])
                    DispatchQueue.main.async(execute: {
                        editedEvent?.sentState = replaceEvent?.sentState
                    })
                }

                bubbleCellData?.updateEvent(eventId, with: editedEvent)
                bubbleCellData?.attributedTextMessage = nil
                hasChanged = true
            }
        }

        return hasChanged
    }

    /// Replace a text in an event.
    /// - Parameters:
    ///   - eventId: The eventId of event to replace.
    ///   - text: The new message text.
    ///   - success: A block object called when the operation succeeds. It returns
    /// the event id of the event generated on the homeserver.
    ///   - failure: A block object called when the operation fails.
    func replaceTextMessageForEvent(
        withId eventId: String?,
        withTextMessage text: String?,
        success: @escaping (String?) -> Void,
        failure: @escaping (Error?) -> Void
    ) {
        let event = self.event(withEventId: eventId)

        let sanitizedText = sanitizedMessageText(text)
        let formattedText = htmlMessage(fromSanitizedText: sanitizedText)

        let eventBody = event?.content["body"] as? String
        let eventFormattedBody = event?.content["formatted_body"] as? String

        if (sanitizedText != eventBody) && (eventFormattedBody == nil || (formattedText != eventFormattedBody)) {
            mxSession.aggregations.replaceTextMessageEvent(event, withTextMessage: sanitizedText, formattedText: formattedText, localEchoBlock: { [self] replaceEventLocalEcho in

                // Apply the local echo to the timeline
                updateEvent(withReplace: replaceEventLocalEcho)

                // Integrate the replace local event into the timeline like when sending a message
                // This also allows to manage read receipt on this replace event
                queueEvent(forProcessing: replaceEventLocalEcho, with: roomState, direction: MXTimelineDirectionForwards)
                processQueuedEvents({ _,_ in })

            }, success: success, failure: failure)
        } else {
            failure(nil)
        }
    }

    // MARK: - Virtual Rooms

    @objc func virtualRoomsDidChange(_ notification: Notification?) {
        //  update secondary room id
        secondaryRoomId = mxSession.virtualRoomOf(roomId)
    }
}
