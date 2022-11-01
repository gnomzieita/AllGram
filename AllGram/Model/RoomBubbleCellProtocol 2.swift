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

import Foundation
import MatrixSDK

/// `RoomBubbleCellProtocol` defines a protocol a class must conform in order to store MXKRoomBubble cell data
/// managed by `MXKRoomDataSource`.
protocol RoomBubbleCellProtocol: AnyObject {
    // MARK: - Data displayed by a room bubble cell

    /// The sender Id
    var senderId: String? { get set }
    /// The target Id (may be nil)
    /// - Remark: "target" refers to the room member who is the target of this event (if any), e.g.
    /// the invitee, the person being banned, etc.
    var targetId: String? { get set }
    /// The room id
    var roomId: String? { get set }
    /// The sender display name composed when event occured
    var senderDisplayName: String? { get set }
    /// The sender avatar url retrieved when event occured
    var senderAvatarUrl: String? { get set }
    /// The sender avatar placeholder (may be nil) - Used when url is nil, or during avatar download.
    var senderAvatarPlaceholder: UIImage? { get set }
    /// The target display name composed when event occured (may be nil)
    /// - Remark: "target" refers to the room member who is the target of this event (if any), e.g.
    /// the invitee, the person being banned, etc.
    var targetDisplayName: String? { get set }
    /// The target avatar url retrieved when event occured (may be nil)
    /// - Remark: "target" refers to the room member who is the target of this event (if any), e.g.
    /// the invitee, the person being banned, etc.
    var targetAvatarUrl: String? { get set }
    /// The target avatar placeholder (may be nil) - Used when url is nil, or during avatar download.
    /// - Remark: "target" refers to the room member who is the target of this event (if any), e.g.
    /// the invitee, the person being banned, etc.
    var targetAvatarPlaceholder: UIImage? { get set }
    /// The current sender flair (list of the publicised groups in the sender profile which matches the room flair settings)
    var senderFlair: [MXGroup]? { get set }
    /// Tell whether the room is encrypted.
    var isEncryptedRoom: Bool { get set }
    /// Tell whether a new pagination starts with this bubble.
    var isPaginationFirstBubble: Bool { get set }
    /// Tell whether the sender information is relevant for this bubble
    /// (For example this information should be hidden in case of 2 consecutive bubbles from the same sender).
    var shouldHideSenderInformation: Bool { get set }
    /// Tell whether this bubble has nothing to display (neither a message nor an attachment).
    var hasNoDisplay: Bool { get }
    /// The list of events (`MXEvent` instances) handled by this bubble.
    var events: [MXEvent]? { get }
    /// The bubble attachment (if any).
    var attachment: Attachment? { get set }
    /// The bubble date
    var date: Date? { get set }
    /// YES when the bubble is composed by incoming event(s).
    var isIncoming: Bool { get set }
    /// YES when the bubble correspond to an attachment displayed with a thumbnail (see image, video).
    var isAttachmentWithThumbnail: Bool { get set }
    /// YES when the bubble correspond to an attachment displayed with an icon (audio, file...).
    var isAttachmentWithIcon: Bool { get set }
    /// Flag that indicates that self.attributedTextMessage will be not nil.
    /// This avoids the computation of self.attributedTextMessage that can take time.
    var hasAttributedTextMessage: Bool { get }
    /// The body of the message with sets of attributes, or kind of content description in case of attachment (e.g. "image attachment")
    var attributedTextMessage: NSAttributedString? { get set }
    /// The raw text message (without attributes)
    var textMessage: String? { get set }
    /// Tell whether the sender's name is relevant or not for this bubble.
    /// Return YES if the first component of the bubble message corresponds to an emote, or a state event in which
    /// the sender's name appears at the beginning of the message text (for example membership events).
    var shouldHideSenderName: Bool { get set }
    /// YES if the sender is currently typing in the current room
    var isTyping: Bool { get set }
    /// Show the date time label in rendered bubble cell. NO by default.
    var showBubbleDateTime: Bool { get set }
    /// A Boolean value that determines whether the date time labels are customized (By default date time display is handled by MatrixKit). NO by default.
    var useCustomDateTimeLabel: Bool { get set }
    /// Show the receipts in rendered bubble cell. YES by default.
    var showBubbleReceipts: Bool { get set }
    /// A Boolean value that determines whether the read receipts are customized (By default read receipts display is handled by MatrixKit). NO by default.
    var useCustomReceipts: Bool { get set }
    /// A Boolean value that determines whether the unsent button is customized (By default an 'Unsent' button is displayed by MatrixKit in front of unsent events). NO by default.
    var useCustomUnsentButton: Bool { get set }
    /// An integer that you can use to identify cell data in your application.
    /// The default value is 0. You can set the value of this tag and use that value to identify the cell data later.
    var tag: Int { get set }
    /// Indicate if antivirus scan status should be shown.
    var showAntivirusScanStatus: Bool { get }
    // MARK: - Public methods
    /// Create a new `RoomBubbleCellProtocol` object for a new bubble cell.
    /// - Parameters:
    ///   - event: the event to be displayed in the cell.
    ///   - roomState: the room state when the event occured.
    ///   - roomDataSource: the `MXKRoomDataSource` object that will use this instance.
    /// - Returns: the newly created instance.
    init(event: MXEvent?, andRoomState roomState: MXRoomState?, andRoomDataSource roomDataSource: RoomViewModel)
    /// Update the event because its sent state changed or it is has been redacted.
    /// - Parameters:
    ///   - eventId: the id of the event to change.
    ///   - event: the new event data
    /// - Returns: the number of events hosting by the object after the update.
    func updateEvent(_ eventId: String?, with event: MXEvent?) -> Int
    /// Remove the event from the `RoomBubbleCellProtocol` object.
    /// - Parameter eventId: the id of the event to remove.
    /// - Returns: the number of events still hosting by the object after the removal
    func removeEvent(_ eventId: String?) -> Int
    /// Remove the passed event and all events after it.
    /// - Parameters:
    ///   - eventId: the id of the event where to start removing.
    ///   - removedEvents: removedEvents will contain the list of removed events.
    /// - Returns: the number of events still hosting by the object after the removal.
    func removeEvents(fromEvent eventId: String?, removedEvents: [MXEvent]?) -> Int
    /// Check if the receiver has the same sender as another bubble.
    /// - Parameter bubbleCellData: an object conforms to `RoomBubbleCellProtocol` protocol.
    /// - Returns: YES if the receiver has the same sender as the provided bubble
    func hasSameSender(asBubbleCellData bubbleCellData: RoomBubbleCellProtocol?) -> Bool
    /// Highlight text message of an event in the resulting message body.
    /// - Parameters:
    ///   - eventId: the id of the event to highlight.
    ///   - tintColor: optional tint color
    /// - Returns: The body of the message by highlighting the content related to the provided event id
    func attributedTextMessage(withHighlightedEvent eventId: String?, tintColor: UIColor?) -> NSAttributedString?
    /// Highlight all the occurrences of a pattern in the resulting message body 'attributedTextMessage'.
    /// - Parameters:
    ///   - pattern: the text pattern to highlight.
    ///   - patternColor: optional text color (the pattern text color is unchanged if nil).
    ///   - patternFont: optional text font (the pattern font is unchanged if nil).
    func highlightPattern(inTextMessage pattern: String?, withForegroundColor patternColor: UIColor?, andFont patternFont: UIFont?)
    /// Refresh the sender flair information
    func refreshSenderFlair()
    // MARK: - Bubble collapsing

    /// A Boolean value that indicates if the cell is collapsable.
    var collapsable: Bool { get set }
    /// A Boolean value that indicates if the cell and its series is collapsed.
    var collapsed: Bool { get set }
    /// The attributed string to display when the collapsable cells series is collapsed.
    /// It is not nil only for the start cell of the cells series.
    var collapsedAttributedTextMessage: NSAttributedString? { get set }
    /// Bidirectional linked list of cells that can be collapsed together.
    /// If prevCollapsableCellData is nil, this cell data instance is the data of the start
    /// cell of the collapsable cells series.
    var prevCollapsableCellData: RoomBubbleCellProtocol? { get set }
    var nextCollapsableCellData: RoomBubbleCellProtocol? { get set }
    /// The room state to use for computing or updating the data to display for the series when it is
    /// collapsed.
    /// It is not nil only for the start cell of the cells series.
    var collapseState: MXRoomState? { get set }
    /// Check whether the two cells can be collapsable together.
    /// - Returns: YES if YES.
    func collapse(with cellData: RoomBubbleCellProtocol?) -> Bool
}

extension RoomBubbleCellProtocol {
    /// Attempt to add a new event to the bubble.
    /// - Parameters:
    ///   - event: the event to be displayed in the cell.
    ///   - roomState: the room state when the event occured.
    /// - Returns: YES if the model accepts that the event can concatenated to events already in the bubble.
    func add(_ event: MXEvent?, andRoomState roomState: MXRoomState?) -> Bool { return false}
    /// The receiver appends to its content the provided bubble cell data, if both have the same sender.
    /// - Parameter bubbleCellData: an object conforms to `RoomBubbleCellProtocol` protocol.
    /// - Returns: YES if the provided cell data has been merged into receiver.
    func merge(withBubbleCellData bubbleCellData: RoomBubbleCellProtocol?) -> Bool { return false}
}
