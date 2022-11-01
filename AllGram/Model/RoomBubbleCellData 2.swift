//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
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

import MatrixSDK

/// `RoomBubbleCellData` instances compose data for `MXKRoomBubbleTableViewCell` cells.
/// This is the basic implementation which considers only one component (event) by bubble.
/// `MXKRoomBubbleCellDataWithAppendingMode` extends this class to merge consecutive messages from the same sender into one bubble.

class RoomBubbleCellData: RoomBubbleCellProtocol {
    
    var senderId: String?
    
    var targetId: String?
    
    var roomId: String?
    
    var senderDisplayName: String?
    
    var senderAvatarUrl: String?
    
    var senderAvatarPlaceholder: UIImage?
    
    var targetDisplayName: String?
    
    var targetAvatarUrl: String?
    
    var targetAvatarPlaceholder: UIImage?
    
    var senderFlair: [MXGroup]?
    
    var isEncryptedRoom: Bool = false
    
    var isPaginationFirstBubble: Bool = false
    
    var shouldHideSenderInformation: Bool = false
    
    var hasNoDisplay: Bool = false
    
    var events: [MXEvent]?
    
    var attachment: Attachment?
    
    var date: Date?
    
    var isIncoming: Bool = false
    
    var isAttachmentWithThumbnail: Bool = false
    
    var isAttachmentWithIcon: Bool = false
    
    var hasAttributedTextMessage: Bool = false
    
    var textMessage: String?
    
    var shouldHideSenderName: Bool = false
    
    var isTyping: Bool = false
    
    var showBubbleDateTime: Bool = false
    
    var useCustomDateTimeLabel: Bool = false
    
    var showBubbleReceipts: Bool = false
    
    var useCustomReceipts: Bool = false
    
    var useCustomUnsentButton: Bool = false
    
    var tag: Int = 0
    
    var showAntivirusScanStatus: Bool = false
    
    var collapsable: Bool = false
    
    var collapsed: Bool = false
    
    var collapsedAttributedTextMessage: NSAttributedString?
    
    var prevCollapsableCellData: RoomBubbleCellProtocol?
    
    var nextCollapsableCellData: RoomBubbleCellProtocol?
    
    var collapseState: MXRoomState?
    
    /// The data source owner of this instance.
    var roomViewModel: RoomViewModel?
    /// Array of bubble components. Each bubble is supposed to have at least one component.
    /// The body of the message with sets of attributes, or kind of content description in case of attachment (e.g. "image attachment")
    var attributedTextMessage: NSAttributedString?
    /// The optional text pattern to be highlighted in the body of the message.
    var highlightedPattern: String?
    var highlightedPatternColor: UIColor?
    var highlightedPatternFont: UIFont?

    /// The matrix session.
    private var _mxSession: MXSession?
    var mxSession: MXSession? {
        return roomViewModel?.mxSession
    }
    /// Returns bubble components list (`RoomBubbleComponent` instances).
    private var _bubbleComponents: [RoomBubbleComponent]?
    var bubbleComponents: [RoomBubbleComponent]? {
        get {
            var copy: [AnyHashable]?
            
            let lockQueue = DispatchQueue(label: "_bubbleComponents")
            lockQueue.sync {
                copy = _bubbleComponents
            }
            
            return copy as? [RoomBubbleComponent]
        }
        set {
            _bubbleComponents = newValue
        }
    }
    /// Read receipts per event.
    var readReceipts: [String : [MXReceiptData]]?
    /// Aggregated reactions per event.
    var reactions: [String : MXAggregatedReactions]?
    /// Event formatter
    private var _eventFormatter: EventFormatter?
    var eventFormatter: EventFormatter? {
        // Retrieve event formatter from the first component
        return bubbleComponents?.first?.eventFormatter
    }

    /// Attachment upload
    var uploadId: String?
    var uploadProgress: CGFloat = 0.0
    /// Indicate a bubble component needs to show encryption badge.
    var containsBubbleComponentWithEncryptionBadge: Bool {
        var containsBubbleComponentWithEncryptionBadge = false

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            for component in bubbleComponents ?? [] {
                if component.showEncryptionBadge {
                    containsBubbleComponentWithEncryptionBadge = true
                    break
                }
            }
        }

        return containsBubbleComponentWithEncryptionBadge
    }

    // MARK: - RoomBubbleCellProtocol
    convenience init(event: MXEvent?, andRoomState roomState: MXRoomState?, andRoomDataSource roomDataSource: RoomViewModel?) {
        self.init()
        
        // Initialize read receipts
        readReceipts = [:]
        
        // Create the bubble component based on matrix event
        let firstComponent = RoomBubbleComponent(event: event, roomState: roomState, eventFormatter: roomDataSource?.eventFormatter, session: roomDataSource?.mxSession)
        self.bubbleComponents = []
        bubbleComponents?.append(firstComponent)
        
        senderId = event?.sender
        targetId = (event?.type == kMXEventTypeStringRoomMember) ? event?.stateKey : nil
        roomId = roomDataSource?.roomId
        senderDisplayName = roomDataSource?.eventFormatter!.senderDisplayName(for: event, with: roomState)
        senderAvatarUrl = roomDataSource?.eventFormatter!.senderAvatarUrl(for: event, with: roomState)
        senderAvatarPlaceholder = nil
        targetDisplayName = roomDataSource?.eventFormatter!.targetDisplayName(for: event, with: roomState)
        targetAvatarUrl = roomDataSource?.eventFormatter!.targetAvatarUrl(for: event, with: roomState)
        targetAvatarPlaceholder = nil
        isEncryptedRoom = roomState?.isEncrypted ?? false
        isIncoming = ((event?.sender == roomDataSource?.mxSession?.myUser.userId) == false)
        
        // Check attachment if any
        if roomDataSource?.eventFormatter!.isSupportedAttachment(event) == true {
            // Note: event.eventType is equal here to MXEventTypeRoomMessage or MXEventTypeSticker
            attachment = Attachment(event: event!, andMediaManager: (roomDataSource?.mxSession?.mediaManager)!)
            if attachment != nil && attachment!.type == .image {
                // Check the current thumbnail orientation. Rotate the current content size (if need)
                if attachment!.thumbnailOrientation == .left || attachment!.thumbnailOrientation == .right {
                    contentSize = CGSize(width: contentSize.height, height: contentSize.width)
                }
            }
        }
        
        // Report the attributed string (This will initialize _contentSize attribute)
        attributedTextMessage = firstComponent.attributedTextMessage
        
    }

    deinit {
        // Reset any observer on publicised groups by user.
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxSessionDidUpdatePublicisedGroupsForUsers, object: mxSession)

        roomViewModel = nil
        bubbleComponents = nil
    }

    func updateEvent(_ eventId: String?, with event: MXEvent?) -> Int {
        var count = 0

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            // Retrieve the component storing the event and update it
            for index in 0..<(bubbleComponents?.count ?? 0) {
                let roomBubbleComponent = bubbleComponents?[index]
                if roomBubbleComponent?.event!.eventId == eventId {
                    roomBubbleComponent?.update(with: event, roomState: roomViewModel?.roomState, session: mxSession)
                    if !roomBubbleComponent?.textMessage?.count > 0 {
                        bubbleComponents?.remove(at: index)
                    }
                    // flush the current attributed string to force refresh
                    attributedTextMessage = nil

                    // Handle here attachment update.
                    // For example: the case of update of attachment event happens when an echo is replaced by its true event
                    // received back by the events stream.
                    if attachment {
                        // Check the current content url, to update it with the actual one
                        // Retrieve content url/info
                        var eventContentURL = event?.content["url"] as? String
                        if event?.content["file"]["url"] != nil {
                            eventContentURL = event?.content["file"]["url"] as? String
                        }

                        if (eventContentURL?.count ?? 0) == 0 {
                            // The attachment has been redacted.
                            attachment = nil
                            contentSize = CGSize.zero
                        } else if (attachment.eventId != event?.eventId) || (attachment.contentURL != eventContentURL) {
                            let updatedAttachment = MXKAttachment(event: event, andMediaManager: roomDataSource?.mxSession.mediaManager)

                            // Sanity check on attachment type
                            if updatedAttachment != nil && attachment.type == updatedAttachment.type {
                                // Re-use the current image as preview to prevent the cell from flashing
                                updatedAttachment.previewImage = attachment.getCachedThumbnail()
                                if !updatedAttachment.previewImage && attachment.type == MXKAttachmentTypeImage {
                                    updatedAttachment.previewImage = MXMediaManager.loadPicture(fromFilePath: attachment.cacheFilePath)
                                }

                                // Clean the cache by removing the useless data
                                if updatedAttachment.cacheFilePath != attachment.cacheFilePath {
                                    do {
                                        try FileManager.default.removeItem(atPath: attachment.cacheFilePath)
                                    } catch {
                                    }
                                }
                                if updatedAttachment.thumbnailCachePath != attachment.thumbnailCachePath {
                                    do {
                                        try FileManager.default.removeItem(atPath: attachment.thumbnailCachePath)
                                    } catch {
                                    }
                                }

                                // Update the current attachmnet description
                                attachment = updatedAttachment

                                if attachment.type == MXKAttachmentTypeImage {
                                    // Reset content size
                                    contentSize = CGSize.zero

                                    // Check the current thumbnail orientation. Rotate the current content size (if need)
                                    if attachment.thumbnailOrientation == .left || attachment.thumbnailOrientation == .right {
                                        contentSize = CGSize(width: contentSize.height, height: contentSize.width)
                                    }
                                }
                            } else {
                                MXLogDebug("[MXKRoomBubbleCellData] updateEvent: Warning: Does not support change of attachment type")
                            }
                        }
                    } else if roomDataSource?.eventFormatter.isSupportedAttachment(event) {
                        // The event is updated to an event with attachement
                        attachment = MXKAttachment(event: event, andMediaManager: roomDataSource?.mxSession.mediaManager)
                        if attachment && attachment.type == MXKAttachmentTypeImage {
                            // Check the current thumbnail orientation. Rotate the current content size (if need)
                            if attachment.thumbnailOrientation == .left || attachment.thumbnailOrientation == .right {
                                contentSize = CGSize(width: contentSize.height, height: contentSize.width)
                            }
                        }
                    }

                    break
                }
            }

            count = bubbleComponents?.count ?? 0
        }

        return count
    }

    func removeEvent(_ eventId: String?) -> Int {
        var count = 0

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            for roomBubbleComponent in bubbleComponents ?? [] {
                guard let roomBubbleComponent = roomBubbleComponent as? RoomBubbleComponent else {
                    continue
                }
                if roomBubbleComponent.event.eventId == eventId {
                    bubbleComponents?.removeAll { $0 as AnyObject === roomBubbleComponent as AnyObject }

                    // flush the current attributed string to force refresh
                    attributedTextMessage() = nil

                    break
                }
            }

            count = bubbleComponents?.count ?? 0
        }

        return count
    }

    func removeEvents(fromEvent eventId: String?, removedEvents: [MXEvent]?) -> Int {
        var removedEvents = removedEvents
        var cuttedEvents: [AnyHashable] = []

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            let componentIndex = bubbleComponentIndex(forEventId: eventId)

            if NSNotFound != componentIndex {
                let newBubbleComponents = (bubbleComponents as NSArray?)?.subarray(with: NSRange(location: 0, length: componentIndex))

                for i in componentIndex..<(bubbleComponents?.count ?? 0) {
                    let roomBubbleComponent = bubbleComponents?[i] as? RoomBubbleComponent
                    if let event = roomBubbleComponent?.event {
                        cuttedEvents.append(event)
                    }
                }

                if let newBubbleComponents = newBubbleComponents {
                    bubbleComponents = newBubbleComponents as? [AnyHashable]
                }

                // Flush the current attributed string to force refresh
                attributedTextMessage() = nil
            }
        }

        removedEvents = cuttedEvents as? [MXEvent]
        return bubbleComponents?.count ?? 0
    }

    func hasSameSender(asBubbleCellData bubbleCellData: MXKRoomBubbleCellDataStoring?) -> Bool {
        // Sanity check: accept only object of MXKRoomBubbleCellData classes or sub-classes
        assert((bubbleCellData is MXKRoomBubbleCellData), "Invalid parameter not satisfying: (bubbleCellData is MXKRoomBubbleCellData)")

        // NOTE: Same sender means here same id, same display name and same avatar

        // Check first user id
        if (senderId == bubbleCellData?.senderId) == false {
            return false
        }
        // Check sender name
        if (senderDisplayName.length || bubbleCellData?.senderDisplayName.length) && ((senderDisplayName == bubbleCellData?.senderDisplayName) == false) {
            return false
        }
        // Check avatar url
        if (senderAvatarUrl.length || bubbleCellData?.senderAvatarUrl.length) && ((senderAvatarUrl == bubbleCellData?.senderAvatarUrl) == false) {
            return false
        }

        return true
    }

    func getFirstBubbleComponent() -> MXKRoomBubbleComponent? {
        var first: MXKRoomBubbleComponent? = nil

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            if (bubbleComponents?.count ?? 0) != 0 {
                first = bubbleComponents?.first as? MXKRoomBubbleComponent
            }
        }

        return first
    }

    /// Get the first visible component.
    /// - Returns: First visible component or nil.
    func getFirstBubbleComponentWithDisplay() -> MXKRoomBubbleComponent? {
        // Look for the first component which is actually displayed (some event are ignored in room history display).
        var first: MXKRoomBubbleComponent? = nil

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            for index in 0..<(bubbleComponents?.count ?? 0) {
                let component = bubbleComponents?[index] as? MXKRoomBubbleComponent
                if component?.attributedTextMessage {
                    first = component
                    break
                }
            }
        }

        return first
    }

    func attributedTextMessage(withHighlightedEvent eventId: String?, tintColor: UIColor?) -> NSAttributedString? {
        var customAttributedTextMsg: NSAttributedString?

        // By default only one component is supported, consider here the first component
        let firstComponent = getFirstBubbleComponent()

        if let firstComponent = firstComponent {
            customAttributedTextMsg = firstComponent.attributedTextMessage

            // Sanity check
            if customAttributedTextMsg != nil && (firstComponent.event.eventId == eventId) {
                var customComponentString: NSMutableAttributedString? = nil
                if let customAttributedTextMsg = customAttributedTextMsg {
                    customComponentString = NSMutableAttributedString(attributedString: customAttributedTextMsg)
                }
                let color = tintColor ?? UIColor.lightGray
                customComponentString?.addAttribute(.backgroundColor, value: color, range: NSRange(location: 0, length: customComponentString?.length ?? 0))
                customAttributedTextMsg = customComponentString
            }
        }

        return customAttributedTextMsg
    }

    func highlightPattern(inTextMessage pattern: String?, withForegroundColor patternColor: UIColor?, andFont patternFont: UIFont?) {
        highlightedPattern = pattern
        highlightedPatternColor = patternColor
        highlightedPatternFont = patternFont

        // flush the current attributed string to force refresh
        attributedTextMessage() = nil
    }

    func setShouldHideSenderInformation(_ inShouldHideSenderInformation: Bool) {
        shouldHideSenderInformation = inShouldHideSenderInformation

        if !shouldHideSenderInformation {
            // Refresh the flair
            refreshSenderFlair()
        }
    }

    func refreshSenderFlair() {
        // Reset by default any observer on publicised groups by user.
        NotificationCenter.default.removeObserver(self, name: kMXSessionDidUpdatePublicisedGroupsForUsersNotification, object: mxSession)

        // Check first whether the room enabled the flair for some groups
        let roomRelatedGroups = roomDataSource?.roomState.relatedGroups
        if (roomRelatedGroups?.count ?? 0) != 0 && senderId {
            var senderPublicisedGroups: [String]?

            senderPublicisedGroups = mxSession?.publicisedGroups(forUser: senderId)

            if (senderPublicisedGroups?.count ?? 0) != 0 {
                // Cross the 2 arrays to keep only the common group ids
                var flair = [AnyHashable](repeating: 0, count: roomRelatedGroups?.count ?? 0)

                for groupId in roomRelatedGroups ?? [] {
                    if (senderPublicisedGroups?.firstIndex(of: groupId) ?? NSNotFound) != NSNotFound {
                        let group = roomDataSource?.group(withGroupId: groupId)
                        if let group = group {
                            flair.append(group)
                        }
                    }
                }

                if flair.count != 0 {
                    senderFlair = flair
                } else {
                    senderFlair = nil
                }
            } else {
                senderFlair = nil
            }

            // Observe any change on publicised groups for the message sender
            NotificationCenter.default.addObserver(self, selector: #selector(didMXSessionUpdatePublicisedGroups(forUsers:)), name: kMXSessionDidUpdatePublicisedGroupsForUsersNotification, object: mxSession)
        }
    }

    /// Check and refresh the position of each component.

    // MARK: -

    func prepareBubbleComponentsPosition() {
        // Consider here only the first component if any
        let firstComponent = getFirstBubbleComponent()

        if let firstComponent = firstComponent {
            let positionY = CGFloat((attachment == nil || attachment.type == MXKAttachmentTypeFile || attachment.type == MXKAttachmentTypeAudio || attachment.type == MXKAttachmentTypeVoiceMessage) ? MXKROOMBUBBLECELLDATA_TEXTVIEW_DEFAULT_VERTICAL_INSET : 0)
            firstComponent?.position = CGPoint(x: 0, y: positionY)
        }
    }

    /// Get bubble component index from event id.
    /// - Parameter eventId: Event id of bubble component.
    /// - Returns: Index of bubble component associated to event id or NSNotFound
    func bubbleComponentIndex(forEventId eventId: String?) -> Int {
        return (bubbleComponents as NSArray?)?.indexOfObject(passingTest: { bubbleComponent, idx, stop in
            if bubbleComponent.event.eventId == eventId {
                stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
                return true
            }
            return false
        }) ?? 0
    }

    /// Return the raw height of the provided text by removing any vertical margin/inset.
    /// - Parameter attributedText: the attributed text to measure
    /// - Returns: the computed height

    // MARK: - Text measuring

    // Return the raw height of the provided text by removing any margin
    func rawTextHeight(_ attributedText: NSAttributedString?) -> CGFloat {
        var textSize: CGSize
        if Thread.current != Thread.main {
            DispatchQueue.main.sync(execute: { [self] in
                textSize = textContentSize(attributedText, removeVerticalInset: true)
            })
        } else {
            textSize = textContentSize(attributedText, removeVerticalInset: true)
        }

        return textSize.height
    }

    /// Return the content size of a text view initialized with the provided attributed text.
    /// CAUTION: This method runs only on main thread.
    /// - Parameters:
    ///   - attributedText: the attributed text to measure
    ///   - removeVerticalInset: tell whether the computation should remove vertical inset in text container.
    /// - Returns: the computed size content
    static var textContentSizeMeasurementTextView: UITextView? = nil
    static var textContentSizeMeasurementTextViewWithoutInset: UITextView? = nil

    func textContentSize(_ attributedText: NSAttributedString?, removeVerticalInset: Bool) -> CGSize {

        if (attributedText?.length ?? 0) != 0 {
            if !MXKRoomBubbleCellData.textContentSizeMeasurementTextView {
                MXKRoomBubbleCellData.textContentSizeMeasurementTextView = UITextView()

                MXKRoomBubbleCellData.textContentSizeMeasurementTextViewWithoutInset = UITextView()
                // Remove the container inset: this operation impacts only the vertical margin.
                // Note: consider textContainer.lineFragmentPadding to remove horizontal margin
                MXKRoomBubbleCellData.textContentSizeMeasurementTextViewWithoutInset.textContainerInset = .zero
            }

            // Select the right text view for measurement
            let selectedTextView = removeVerticalInset ? MXKRoomBubbleCellData.textContentSizeMeasurementTextViewWithoutInset : MXKRoomBubbleCellData.textContentSizeMeasurementTextView

            selectedTextView?.frame = CGRect(x: 0, y: 0, width: maxTextViewWidth, height: MAXFLOAT)
            selectedTextView?.attributedText = attributedText

            let size = selectedTextView?.sizeThatFits(selectedTextView?.frame.size ?? CGSize.zero)

            // Manage the case where a string attribute has a single paragraph with a left indent
            // In this case, [UITextViex sizeThatFits] ignores the indent and return the width
            // of the text only.
            // So, add this indent afterwards
            let textRange = NSRange(location: 0, length: attributedText?.length ?? 0)
            var longestEffectiveRange: NSRange
            let paragraphStyle = attributedText?.attribute(.paragraphStyle, at: 0, longestEffectiveRange: &longestEffectiveRange, in: textRange) as? NSParagraphStyle

            if NSEqualRanges(textRange, longestEffectiveRange) {
                size?.width = (size?.width ?? 0.0) + (paragraphStyle?.headIndent ?? 0.0)
            }

            return size ?? CGSize.zero
        }

        return CGSize.zero
    }

    func textMessage() -> String? {
        return attributedTextMessage()?.string
    }

    func setAttributedTextMessage(_ inAttributedTextMessage: NSAttributedString?) {
        attributedTextMessage = inAttributedTextMessage

        if (attributedTextMessage?.length ?? 0) != 0 && highlightedPattern != nil {
            highlightPattern()
        }

        // Reset content size
        contentSize = CGSize.zero
    }

    func attributedTextMessage() -> NSAttributedString? {
        if hasAttributedTextMessage() && (attributedTextMessage?.length ?? 0) == 0 {
            // By default only one component is supported, consider here the first component
            let firstComponent = getFirstBubbleComponent()

            if let firstComponent = firstComponent {
                attributedTextMessage = firstComponent.attributedTextMessage

                if (attributedTextMessage?.length ?? 0) != 0 && highlightedPattern != nil {
                    highlightPattern()
                }
            }
        }

        return attributedTextMessage
    }

    func hasAttributedTextMessage() -> Bool {
        // Determine if the event formatter will return at least one string for the events in this cell.
        // No string means that the event formatter has been configured so that it did not accept all events
        // of the cell.
        var hasAttributedTextMessage = false

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            for roomBubbleComponent in bubbleComponents ?? [] {
                guard let roomBubbleComponent = roomBubbleComponent as? MXKRoomBubbleComponent else {
                    continue
                }
                if roomBubbleComponent.attributedTextMessage {
                    hasAttributedTextMessage = true
                    break
                }
            }
        }
        return hasAttributedTextMessage
    }

    func shouldHideSenderName() -> Bool {
        var res = false

        let firstDisplayedComponent = getFirstBubbleComponentWithDisplay()
        let senderDisplayName = self.senderDisplayName

        if let firstDisplayedComponent = firstDisplayedComponent {
            res = firstDisplayedComponent.event.isEmote || (firstDisplayedComponent.event.isState && senderDisplayName != "" && firstDisplayedComponent.textMessage.hasPrefix(senderDisplayName))
        }

        return res
    }

    func events() -> [AnyHashable]? {
        var eventsArray: [AnyHashable]?

        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            eventsArray = [AnyHashable](repeating: 0, count: bubbleComponents?.count ?? 0)
            for roomBubbleComponent in bubbleComponents ?? [] {
                guard let roomBubbleComponent = roomBubbleComponent as? MXKRoomBubbleComponent else {
                    continue
                }
                if roomBubbleComponent.event {
                    eventsArray?.append(roomBubbleComponent.event)
                }
            }
        }
        return eventsArray
    }

    func date() -> Date? {
        let firstDisplayedComponent = getFirstBubbleComponentWithDisplay()

        if let firstDisplayedComponent = firstDisplayedComponent {
            return firstDisplayedComponent.date
        }

        return nil
    }

    func hasNoDisplay() -> Bool {
        var noDisplay = true

        // Check whether at least one component has a string description.
        let lockQueue = DispatchQueue(label: "bubbleComponents")
        lockQueue.sync {
            if collapsed {
                // Collapsed cells have no display except their cell header
                noDisplay = !collapsedAttributedTextMessage
            } else {
                for roomBubbleComponent in bubbleComponents ?? [] {
                    guard let roomBubbleComponent = roomBubbleComponent as? MXKRoomBubbleComponent else {
                        continue
                    }
                    if roomBubbleComponent.attributedTextMessage {
                        noDisplay = false
                        break
                    }
                }
            }
        }

        return noDisplay && !attachment
    }

    func isAttachmentWithThumbnail() -> Bool {
        return attachment && (attachment.type == MXKAttachmentTypeImage || attachment.type == MXKAttachmentTypeVideo || attachment.type == MXKAttachmentTypeSticker)
    }

    func isAttachmentWithIcon() -> Bool {
        // Not supported yet (TODO for audio, file).
        return false
    }

    func showAntivirusScanStatus() -> Bool {
        let firstBubbleComponent = bubbleComponents?.first as? MXKRoomBubbleComponent

        if attachment == nil || firstBubbleComponent == nil {
            return false
        }

        let eventScan = firstBubbleComponent?.eventScan

        return eventScan != nil && eventScan?.antivirusScanStatus != MXAntivirusScanStatusTrusted
    }

    // MARK: - Bubble collapsing

    func collapse(with cellData: MXKRoomBubbleCellDataStoring?) -> Bool {
        // NO by default
        return false
    }

    // MARK: - Internals

    func highlightPattern() {
        var customAttributedTextMsg: NSMutableAttributedString? = nil

        let currentTextMessage = textMessage()
        var range = (currentTextMessage as NSString?)?.range(of: highlightedPattern ?? "", options: .caseInsensitive)

        if range?.location != NSNotFound {
            if let attributedTextMessage1 = attributedTextMessage() {
                customAttributedTextMsg = NSMutableAttributedString(attributedString: attributedTextMessage1)
            }

            while range?.location != NSNotFound {
                if let highlightedPatternColor = highlightedPatternColor {
                    // Update text color
                    if let range = range {
                        customAttributedTextMsg?.addAttribute(.foregroundColor, value: highlightedPatternColor, range: range)
                    }
                }

                if let highlightedPatternFont = highlightedPatternFont {
                    // Update text font
                    if let range = range {
                        customAttributedTextMsg?.addAttribute(.font, value: highlightedPatternFont, range: range)
                    }
                }

                // Look for the next pattern occurrence
                range?.location += range?.length ?? 0
                if (range?.location ?? 0) < (currentTextMessage?.count ?? 0) {
                    (range?.length ?? 0) = (currentTextMessage?.count ?? 0) - (range?.location ?? 0)
                    if let range = range {
                        range = (currentTextMessage as NSString?)?.range(of: highlightedPattern ?? "", options: .caseInsensitive, range: range)
                    }
                } else {
                    range?.location = NSNotFound
                }
            }
        }

        if let customAttributedTextMsg = customAttributedTextMsg {
            // Update resulting message body
            attributedTextMessage = customAttributedTextMsg
        }
    }

    @objc func didMXSessionUpdatePublicisedGroups(forUsers notif: Notification?) {
        // Retrieved the list of the concerned users
        let userIds = notif?.userInfo?[kMXSessionNotificationUserIdsArrayKey] as? [String]
        if (userIds?.count ?? 0) != 0 && senderId {
            // Check whether the current sender is concerned.
            if (userIds?.firstIndex(of: senderId) ?? NSNotFound) != NSNotFound {
                refreshSenderFlair()
            }
        }
    }
}

let MXKROOMBUBBLECELLDATA_MAX_ATTACHMENTVIEW_WIDTH = 192

let MXKROOMBUBBLECELLDATA_DEFAULT_MAX_TEXTVIEW_WIDTH = 200
