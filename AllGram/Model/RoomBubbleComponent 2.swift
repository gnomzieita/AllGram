//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd

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

/// `RoomBubbleComponent` class compose data related to one `MXEvent` instance.
class RoomBubbleComponent: NSObject {
    /// The body of the message, or kind of content description in case of attachment (e.g. "image attachment").

    private var _textMessage: String?
    var textMessage: String? {
        get {
            if _textMessage == nil {
                _textMessage = attributedTextMessage?.string
            }
            return _textMessage
        }
        set {
            self._textMessage = newValue
        }
    }
    /// The `textMessage` with sets of attributes.
    var attributedTextMessage: NSAttributedString?
    /// The event date
    var date: Date?
    /// Event formatter
    var eventFormatter: EventFormatter?
    /// The event on which the composent is based (used in case of redaction)
    private(set) var event: MXEvent?
    // The following properties are defined to store information on component.
    // They must be handled by the object which creates the RoomBubbleComponent instance.
    //@property (nonatomic) CGFloat height;
    var position = CGPoint.zero
    /// Event antivirus scan. Present only if antivirus is enabled and event contains media.
    var eventScan: MXEventScan?
    /// Indicate if an encryption badge should be shown.
    private(set) var showEncryptionBadge = false
    ///Error in component
    var error: EventFormatterError?

    /// Create a new `RoomBubbleComponent` object based on a `MXEvent` instance.
    /// - Parameters:
    ///   - event: the event used to compose the bubble component.
    ///   - roomState: the room state when the event occured.
    ///   - eventFormatter: object used to format event into displayable string.
    ///   - session: the related matrix session.
    /// - Returns: the newly created instance.
    init(event: MXEvent?, roomState: MXRoomState?, eventFormatter: EventFormatter?, session: MXSession?) {
        super.init()
            // Build text component related to this event
            self.eventFormatter = eventFormatter
            var error: EventFormatterError?

            let eventString = self.eventFormatter?.attributedString(from: event, with: roomState, error: &error)

            // Store the potential error
//            event?.mxkEventFormatterError = error

            textMessage = nil
            attributedTextMessage = eventString

            // Set date time
            if event?.originServerTs != kMXUndefinedTimestamp {
                date = Date(timeIntervalSince1970: TimeInterval(Double(event?.originServerTs ?? 0) / 1000))
            } else {
                date = nil
            }

            // Keep ref on event (used to handle the read marker, or a potential event redaction).
            self.event = event

//            displayFix = .none
//            if event?.content["format"] == kMXRoomMessageFormatHTML {
//                if (event?.content["formatted_body"] as? String)?.contains("<blockquote") ?? false {
//                    displayFix.insert(.htmlBlockquote)
//                }
//            }

            showEncryptionBadge = shouldShowWarningBadge(for: event, roomState: roomState, session: session)
    }

    /// Update the event because its sent state changed or it is has been redacted.
    /// - Parameters:
    ///   - event: the new event data.
    ///   - roomState: the up-to-date state of the room.
    ///   - session: the related matrix session.
    func update(with event: MXEvent?, roomState: MXRoomState?, session: MXSession?) {
        var roomState = roomState
        // Report the new event
        self.event = event

        if self.event != nil, self.event!.isRedactedEvent() == true {
            // Do not use the live room state for redacted events as they occured in the past
            // Note: as we don't have valid room state in this case, userId will be used as display name
            roomState = nil
        }
        // Other calls to updateWithEvent are made to update the state of an event (ex: MXKEventStateSending to MXKEventStateDefault).
        // They occur in live so we can use the room up-to-date state without making huge errors

        textMessage = nil

        attributedTextMessage = eventFormatter?.attributedString(from: event, with: roomState, error: &error)

        showEncryptionBadge = shouldShowWarningBadge(for: event, roomState: roomState, session: session)
    }

    func shouldShowWarningBadge(for event: MXEvent?, roomState: MXRoomState?, session: MXSession?) -> Bool {
        // Warning badges are unnecessary in unencrypted rooms
        if roomState?.isEncrypted == false {
            return false
        }

        // Not all events are encrypted (e.g. state/reactions/redactions) and we only have encrypted cell subclasses for messages and attachments.
        if event?.eventType != .roomMessage && event?.isMediaAttachment() == false {
            return false
        }

        // Always show a warning badge if there was a decryption error.
        if event?.decryptionError != nil {
            return true
        }

        // Unencrypted message events should show a warning unless they're pending local echoes
        if event?.isEncrypted == false {
            if event?.isLocalEvent() == true || event?.contentHasBeenEdited() == true {
                return false
            }

            return true
        }

        // The encryption is in a good state.
        // Only show a warning badge if there are trust issues.
        if event?.sender != nil {
            let userTrustLevel = session?.crypto.trustLevel(forUser: event?.sender)
            let deviceInfo = session?.crypto.eventDeviceInfo(event)

            if userTrustLevel?.isVerified == true && deviceInfo!.trustLevel.isVerified == false {
                return true
            }
        }

        // Everything was fine
        return false
    }
}
