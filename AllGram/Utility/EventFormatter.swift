//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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

import DTCoreText
import Foundation
import MatrixSDK

/// Formatting result codes.
enum EventFormatterError : Int {
    /// The formatting was successful.
    case none = 0
    /// The formatter knows the event type but it encountered data that it does not support.
    case unsupported
    /// The formatter encountered unexpected data in the event.
    case unexpected
    /// The formatter does not support the type of the passed event.
    case unknownEventType
}

private let kHTMLATagRegexPattern = "<a href=\"(.*?)\">([^<]*)</a>"

/// `EventFormatter` is an utility class for formating Matrix events into strings which
/// will be displayed to the end user.
class EventFormatter: NSObject, MXRoomSummaryUpdating {
    /// The matrix session. Used to get contextual data.
    var mxSession: MXSession?
    /// The date formatter used to build date string without time information.
    var dateFormatter: DateFormatter?
    /// The time formatter used to build time string without date information.
    var timeFormatter: DateFormatter?
    /// The default room summary updater from the MXSession.
    var defaultRoomSummaryUpdater: MXRoomSummaryUpdater?

    /// The default CSS converted in DTCoreText object.
    private var dtCSS: DTCSSStylesheet?
    /// Links detector in strings.
    private var linkDetector: NSDataDetector?

    /// The settings used to handle room events.
    /// By default the shared application settings are considered.
    var settings: AppSettings?
    /// Flag indicating if the formatter must build strings that will be displayed as subtitle.
    /// Default is NO.
    var isForSubtitle = false
    /// Flags indicating if the formatter must create clickable links for Matrix user ids,
    /// room ids, room aliases or event ids.
    /// Default is NO.
    var treatMatrixUserIdAsLink = false
    var treatMatrixRoomIdAsLink = false
    var treatMatrixRoomAliasAsLink = false
    var treatMatrixEventIdAsLink = false
    var treatMatrixGroupIdAsLink = false
    /// The types of events allowed to be displayed in the room history.
    /// No string will be returned by the formatter for the events whose the type doesn't belong to this array.
    /// Default is nil. All messages types are displayed.

    private var _eventTypesFilterForMessages: [String]?
    var eventTypesFilterForMessages: [String]? {
        get {
            _eventTypesFilterForMessages
        }
        set(eventTypesFilterForMessages) {
            _eventTypesFilterForMessages = eventTypesFilterForMessages

            // probably this property is deprecated, and missing in new MatrixSDK
            // defaultRoomSummaryUpdater?.eventsFilterForMessages = eventTypesFilterForMessages
        }
    }
    
    // MARK: - Customisation
    /// The list of allowed HTML tags in rendered attributed strings.
    var allowedHTMLTags: [String]?
    /// The style sheet used by the 'renderHTMLString' method.
    private var _defaultCSS: String?
    var defaultCSS: String? {
        get {
            _defaultCSS
        }
        set(defaultCSS) {
            // Make sure we mark HTML blockquote blocks for later computation
            _defaultCSS = "\(Tools.cssToMarkBlockquotes())\(defaultCSS ?? "")"

            dtCSS = DTCSSStylesheet(styleBlock: _defaultCSS)
        }
    }
    /// Default color used to display text content of event.
    /// Default is [UIColor blackColor].
    var defaultTextColor: UIColor?
    /// Default color used to display text content of event when it is displayed as subtitle (related to 'isForSubtitle' property).
    /// Default is [UIColor blackColor].
    var subTitleTextColor: UIColor?
    /// Color applied on the event description prefix used to display for example the message sender name.
    /// Default is [UIColor blackColor].
    var prefixTextColor: UIColor?
    /// Color used when the event must be bing to the end user. This happens when the event
    /// matches the user's push rules.
    /// Default is [UIColor blueColor].
    var bingTextColor: UIColor?
    /// Color used to display text content of an event being encrypted.
    /// Default is [UIColor lightGrayColor].
    var encryptingTextColor: UIColor?
    /// Color used to display text content of an event being sent.
    /// Default is [UIColor lightGrayColor].
    var sendingTextColor: UIColor?
    /// Color used to display error text.
    /// Default is red.
    var errorTextColor: UIColor?
    /// Color used to display the side border of HTML blockquotes.
    /// Default is a grey.
    var htmlBlockquoteBorderColor: UIColor?
    /// Default text font used to display text content of event.
    /// Default is SFUIText-Regular 14.
    var defaultTextFont: UIFont?
    /// Font applied on the event description prefix used to display for example the message sender name.
    /// Default is SFUIText-Regular 14.
    var prefixTextFont: UIFont?
    /// Text font used when the event must be bing to the end user. This happens when the event
    /// matches the user's push rules.
    /// Default is SFUIText-Regular 14.
    var bingTextFont: UIFont?
    /// Text font used when the event is a state event.
    /// Default is italic SFUIText-Regular 14.
    var stateEventTextFont: UIFont?
    /// Text font used to display call notices (invite, answer, hangup).
    /// Default is SFUIText-Regular 14.
    var callNoticesTextFont: UIFont?
    /// Text font used to display encrypted messages.
    /// Default is SFUIText-Regular 14.
    var encryptedMessagesTextFont: UIFont?
    /// Text font used to display message containing a single emoji.
    /// Default is nil (same font as self.emojiOnlyTextFont).
    var singleEmojiTextFont: UIFont?
    /// Text font used to display message containing only emojis.
    /// Default is nil (same font as self.defaultTextFont).
    var emojiOnlyTextFont: UIFont?

    /// Initialise the event formatter.
    /// - Parameter mxSession: the Matrix to retrieve contextual data.
    /// - Returns: the newly created instance.
    init(matrixSession: MXSession?) {
        super.init()
        mxSession = matrixSession

        initDateTimeFormatters()

        // Use the same list as matrix-react-sdk ( https://github.com/matrix-org/matrix-react-sdk/blob/24223ae2b69debb33fa22fcda5aeba6fa93c93eb/src/HtmlUtils.js#L25 )
        allowedHTMLTags = [
            "font" /* custom to matrix for IRC-style font coloring */,
            "del" /* for markdown */,
                        // deliberately no h1/h2 to stop people shouting.
            "h3",
            "h4",
            "h5",
            "h6",
            "blockquote",
            "p",
            "a",
            "ul",
            "ol",
            "nl",
            "li",
            "b",
            "i",
            "u",
            "strong",
            "em",
            "strike",
            "code",
            "hr",
            "br",
            "div",
            "table",
            "thead",
            "caption",
            "tbody",
            "tr",
            "th",
            "td",
            "pre"
        ]

        defaultCSS = "             pre,code {                 background-color: #eeeeee;                 display: inline;                 font-family: monospace;                 white-space: pre;                 -coretext-fontname: Menlo-Regular;                 font-size: small;             }"

        // Set default colors
        defaultTextColor = UIColor.black
        subTitleTextColor = UIColor.black
        prefixTextColor = UIColor.black
        bingTextColor = UIColor.blue
        encryptingTextColor = UIColor.lightGray
        sendingTextColor = UIColor.lightGray
        errorTextColor = UIColor.red
//        htmlBlockquoteBorderColor = MXKTools.color(withRGBValue: 0xdddddd)

        defaultTextFont = UIFont.systemFont(ofSize: 14)
        prefixTextFont = UIFont.systemFont(ofSize: 14)
        bingTextFont = UIFont.systemFont(ofSize: 14)
        stateEventTextFont = UIFont.italicSystemFont(ofSize: 14)
        callNoticesTextFont = UIFont.italicSystemFont(ofSize: 14)
        encryptedMessagesTextFont = UIFont.italicSystemFont(ofSize: 14)

        eventTypesFilterForMessages = nil

        // Consider the shared app settings by default
        settings = AppSettings.shared

        defaultRoomSummaryUpdater = MXRoomSummaryUpdater(for: matrixSession)!
        // defaultRoomSummaryUpdater.ignoreMemberProfileChanges = true // deprecated in MatrixSDK ??
        defaultRoomSummaryUpdater?.ignoreRedactedEvent = !(settings?.showRedactionsInRoomHistory)!
        defaultRoomSummaryUpdater?.roomNameStringLocalizer = MXRoomNameDefaultStringLocalizer()

        linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

        markdownToHTMLRenderer = MarkdownToHTMLRendererHardBreaks()
    }

    /// Initialise the date and time formatters.
    /// This formatter could require to be updated after updating the device settings.
    /// e.g the time format switches from 24H format to AM/PM.
    func initDateTimeFormatters() {
        // Prepare internal date formatter
        dateFormatter = DateFormatter()
        dateFormatter?.locale = NSLocale(localeIdentifier: Bundle.main.preferredLocalizations[0]) as Locale
        dateFormatter?.formatterBehavior = .behavior10_4
        // Set default date format
        dateFormatter?.dateFormat = "MMM dd"

        // Create a time formatter to get time string by considered the current system time formatting.
        timeFormatter = DateFormatter()
        timeFormatter?.dateStyle = .none
        timeFormatter?.timeStyle = .short
    }

    /// Checks whether the event is related to an attachment and if it is supported.
    /// - Parameter event: an event.
    /// - Returns: YES if the provided event is related to a supported attachment type.

    // MARK: - Event formatter settings

    // Checks whether the event is related to an attachment and if it is supported
    func isSupportedAttachment(_ event: MXEvent?) -> Bool {
        var isSupportedAttachment = false

        if event?.eventType == .roomMessage {
            let msgtype = event?.content["msgtype"] as? String

            let urlField = event?.content["url"] as? String
            let fileField = event?.content["file"] as? [String: Any]

            let hasUrl = (urlField != nil)
            var hasFile = false

            if let fileField = fileField {
                let fileUrlField = fileField["url"] as? String
                let fileIvField = fileField["iv"] as? String
                let fileHashesField = fileField["hashes"] as? [String: Any]
                let fileKeyField = fileField["key"] as? [String: Any]

                hasFile = (fileUrlField != nil) && fileIvField != nil && fileHashesField != nil && fileKeyField != nil
            }

            if msgtype == kMXMessageTypeImage {
                isSupportedAttachment = hasUrl || hasFile
            } else if msgtype == kMXMessageTypeAudio {
                isSupportedAttachment = hasUrl || hasFile
            } else if msgtype == kMXMessageTypeVideo {
                isSupportedAttachment = hasUrl || hasFile
            } else if msgtype == kMXMessageTypeLocation {
                // Not supported yet
            } else if msgtype == kMXMessageTypeFile {
                isSupportedAttachment = hasUrl || hasFile
            }
        } else if event?.eventType == .sticker {
            let urlField = event?.content["url"] as? String
            let fileField = event?.content["file"] as? [String: Any]

            let hasUrl = urlField != nil
            var hasFile = false

            // @TODO: Check whether the encrypted sticker uses the same `file dict than other media
            if let fileField = fileField {
                let fileUrlField = fileField["url"] as? String
                let fileIvField = fileField["iv"] as? String
                let fileHashesField = fileField["hashes"] as? [String: Any]
                let fileKeyField = fileField["key"] as? [String: Any]

                hasFile = fileUrlField != nil && fileIvField != nil && fileHashesField != nil && fileKeyField != nil
            }

            isSupportedAttachment = hasUrl || hasFile
        }
        return isSupportedAttachment
    }

    // MARK: - Events to strings conversion methods
    /// Compose the event sender display name according to the current room state.
    /// - Parameters:
    ///   - event: the event to format.
    ///   - roomState: the room state right before the event.
    /// - Returns: the sender display name

    // MARK: event sender/target info

    func senderDisplayName(for event: MXEvent?, with roomState: MXRoomState?) -> String? {
        // Check whether the sender name is updated by the current event. This happens in case of a
        // newly joined member. Otherwise, fall back to the current display name defined in the provided
        // room state (note: this room state is supposed to not take the new event into account).
        return userDisplayNameFromContent(in: event, withMembershipFilter: "join") ?? roomState?.members.memberName(event?.sender)
    }

    /// Compose the event target display name according to the current room state.
    /// - Remark: "target" refers to the room member who is the target of this event (if any), e.g.
    /// the invitee, the person being banned, etc.
    /// - Parameters:
    ///   - event: the event to format.
    ///   - roomState: the room state right before the event.
    /// - Returns: the target display name (if any)
    func targetDisplayName(for event: MXEvent?, with roomState: MXRoomState?) -> String? {
        if event?.type != kMXEventTypeStringRoomMember {
            return nil // Non-membership events don't have a target
        }
        return userDisplayNameFromContent(in: event, withMembershipFilter: nil) ?? roomState?.members.memberName(event?.stateKey)
    }

    func userDisplayNameFromContent(in event: MXEvent?, withMembershipFilter filter: String?) -> String? {
        let membership = event?.content["membership"] as? String
        let displayname = event?.content["displayname"] as? String

        if membership != nil && (filter == nil || (membership == filter)) && displayname != nil {
            return displayname
        }

        return nil
    }

    /// Retrieve the avatar url of the event sender from the current room state.
    /// - Parameters:
    ///   - event: the event to format.
    ///   - roomState: the room state right before the event.
    /// - Returns: the sender avatar url
    func senderAvatarUrl(for event: MXEvent?, with roomState: MXRoomState?) -> String? {
        // Check whether the avatar URL is updated by the current event. This happens in case of a
        // newly joined member. Otherwise, fall back to the avatar URL defined in the provided room
        // state (note: this room state is supposed to not take the new event into account).
        let avatarUrl = userAvatarUrlFromContent(in: event, withMembershipFilter: "join") ?? roomState?.members.member(withUserId: event?.sender).avatarUrl

        // Handle here the case where no avatar is defined
        return avatarUrl ?? fallbackAvatarUrl(forUserId: event?.sender)
    }

    /// Retrieve the avatar url of the event target from the current room state.
    /// - Remark: "target" refers to the room member who is the target of this event (if any), e.g.
    /// the invitee, the person being banned, etc.
    /// - Parameters:
    ///   - event: the event to format.
    ///   - roomState: the room state right before the event.
    /// - Returns: the target avatar url (if any)
    func targetAvatarUrl(for event: MXEvent?, with roomState: MXRoomState?) -> String? {
        if event?.type != kMXEventTypeStringRoomMember {
            return nil // Non-membership events don't have a target
        }
        let avatarUrl = userAvatarUrlFromContent(in: event, withMembershipFilter: nil) ?? roomState?.members.member(withUserId: event?.stateKey).avatarUrl
        return avatarUrl ?? fallbackAvatarUrl(forUserId: event?.stateKey)
    }

    func userAvatarUrlFromContent(in event: MXEvent?, withMembershipFilter filter: String?) -> String? {
        let membership = event?.content["membership"] as? String
        let avatarUrl = event?.content["avatar_url"] as? String

        if membership != nil && (filter == nil || (membership == filter)) && avatarUrl != nil {
            // We ignore non mxc avatar url
            if avatarUrl?.hasPrefix(kMXContentUriScheme) ?? false {
                return avatarUrl
            }
        }

        return nil
    }

    func fallbackAvatarUrl(forUserId userId: String?) -> String? {
        if MXSDKOptions.sharedInstance().disableIdenticonUseForUserAvatar {
            return nil
        }
        return mxSession?.mediaManager.url(ofIdenticon: userId)
    }

    /// Generate a displayable string representating the event.
    /// - Parameters:
    ///   - event: the event to format.
    ///   - roomState: the room state right before the event.
    ///   - error: the error code. In case of formatting error, the formatter may return non nil string as a proposal.
    /// - Returns: the display text for the event.

    // MARK: - Events to strings conversion methods

    func string(from event: MXEvent?, with roomState: MXRoomState?,
				error: inout EventFormatterError) -> String? {
        var stringFromEvent: String?
        let attributedStringFromEvent = attributedString(from: event, with: roomState, error: &error)
        if error == EventFormatterError.none {
            stringFromEvent = attributedStringFromEvent?.string
        }

        return stringFromEvent
    }

    /// Generate a displayable attributed string representating the event.
    /// - Parameters:
    ///   - event: the event to format.
    ///   - roomState: the room state right before the event.
    ///   - error: the error code. In case of formatting error, the formatter may return non nil string as a proposal.
    /// - Returns: the attributed string for the event.
    func attributedString(from event: MXEvent?, with roomState: MXRoomState?, error: inout EventFormatterError) -> NSAttributedString? {
        // var error = error
        // Check we can output the error
        //assert(error != nil, "Invalid parameter not satisfying: error != nil")

        error = EventFormatterError.none

        // Filter the events according to their type.
        if eventTypesFilterForMessages != nil && ((eventTypesFilterForMessages?.firstIndex(of: event?.type ?? "") ?? NSNotFound) == NSNotFound) {
            // Ignore this event
            return nil
        }

        let isEventSenderMyUser = event?.sender == mxSession?.myUserId

        // Check first whether the event has been redacted
        var redactedInfo: String? = nil
		let redactedBecauseDict = event?.redactedBecause as? [String : Any]
        let isRedacted = (redactedBecauseDict != nil)
        if isRedacted {
            // Check whether redacted information is required
            if (settings?.showRedactionsInRoomHistory ?? false) {

                let redactorId = redactedBecauseDict?["sender"] as? String
                var redactedBy = ""
                // Consider live room state to resolve redactor name if no roomState is provided
                let aRoomState = roomState //?? mxSession?.room(withRoomId: event?.roomId)
                redactedBy = aRoomState?.members.memberName(redactorId) ?? ""

				let content = redactedBecauseDict?["content"] as? [String: Any]
				let redactedReason = content?["reason"] as? String
                if (redactedReason?.count ?? 0) != 0 {
                    if redactorId == mxSession?.myUserId {
                        let formatString = "\(localizedString(forKey: "notice_event_redacted_by_you"))\(localizedString(forKey: "notice_event_redacted_reason"))"
                        redactedBy = String(format: formatString, redactedReason ?? "")
                    } else if redactedBy.count != 0 {
                        let formatString = "\(localizedString(forKey: "notice_event_redacted_by"))\(localizedString(forKey: "notice_event_redacted_reason"))"
                        redactedBy = String(format: formatString, redactedBy, redactedReason ?? "")
                    } else {
                        redactedBy = String(format: localizedString(forKey: "notice_event_redacted_reason"), redactedReason ?? "")
                    }
                } else if redactorId == mxSession?.myUserId {
                    redactedBy = localizedString(forKey: "notice_event_redacted_by_you")
                } else if redactedBy.count != 0 {
                    redactedBy = String(format: localizedString(forKey: "notice_event_redacted_by"), redactedBy)
                }

                redactedInfo = String(format: localizedString(forKey: "notice_event_redacted"), redactedBy)
            }
        }

        // Prepare returned description
        var displayText = ""
        var attributedDisplayText: NSAttributedString? = nil
        let isRoomDirect = mxSession?.room(withRoomId: event?.roomId).isDirect ?? false

        // Prepare the display name of the sender
        var senderDisplayName: String?
        senderDisplayName = roomState != nil ? self.senderDisplayName(for: event, with: roomState) : event?.sender

        switch event?.eventType {
		case .roomName:
			var roomName = event?.content["name"] as? String

            if isRedacted {
                if redactedInfo == nil {
                    // Here the event is ignored (no display)
                    return nil
                }
                roomName = redactedInfo
            }

            if (roomName?.count ?? 0) != 0 {
                if isEventSenderMyUser {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_name_changed_by_you_for_dm"), roomName ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_name_changed_by_you"), roomName ?? "")
                    }
                } else {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_name_changed_for_dm"), senderDisplayName ?? "", roomName ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_name_changed"), senderDisplayName ?? "", roomName ?? "")
                    }
                }
            } else {
                if isEventSenderMyUser {
                    if isRoomDirect {
                        displayText = localizedString(forKey: "notice_room_name_removed_by_you_for_dm")
                    } else {
                        displayText = localizedString(forKey: "notice_room_name_removed_by_you")
                    }
                } else {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_name_removed_for_dm"), senderDisplayName ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_name_removed"), senderDisplayName ?? "")
                    }
                }
            }
		case .roomTopic:
			var roomTopic = event?.content["topic"] as?  String

            if isRedacted {
                if redactedInfo == nil {
                    // Here the event is ignored (no display)
                    return nil
                }
                roomTopic = redactedInfo
            }

            if (roomTopic?.count ?? 0) != 0 {
                if isEventSenderMyUser {
                    displayText = String(format: localizedString(forKey: "notice_topic_changed_by_you"), roomTopic ?? "")
                } else {
                    displayText = String(format: localizedString(forKey: "notice_topic_changed"), senderDisplayName ?? "", roomTopic ?? "")
                }
            } else {
                if isEventSenderMyUser {
                    displayText = localizedString(forKey: "notice_room_topic_removed_by_you")
                } else {
                    displayText = String(format: localizedString(forKey: "notice_room_topic_removed"), senderDisplayName ?? "")
                }
            }
		case .roomMember:
            // Presently only change on membership, display name and avatar are supported

            // Check whether the sender has updated his profile
            if event?.isUserProfileChange() == true {
                // Is redacted event?
                if isRedacted {
                    if redactedInfo == nil {
                        // Here the event is ignored (no display)
                        return nil
                    }
                    if isEventSenderMyUser {
                        displayText = String(format: localizedString(forKey: "notice_profile_change_redacted_by_you"), redactedInfo ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_profile_change_redacted"), senderDisplayName ?? "", redactedInfo ?? "")
                    }
                } else {
                    // Check whether the display name has been changed
					var displayname = event?.content["displayname"] as? String
					var prevDisplayname = event?.prevContent["displayname"] as? String

                    if (displayname?.count ?? 0) == 0 {
                        displayname = nil
                    }
                    if (prevDisplayname?.count ?? 0) == 0 {
                        prevDisplayname = nil
                    }
                    if (displayname != nil || prevDisplayname != nil) && ((displayname == prevDisplayname) == false) {
                        if prevDisplayname == nil {
                            if isEventSenderMyUser {
                                displayText = String(format: localizedString(forKey: "notice_display_name_set_by_you"), displayname ?? "")
                            } else {
                                if let sender = event?.sender {
                                    displayText = String(format: localizedString(forKey: "notice_display_name_set"), sender, displayname ?? "")
                                }
                            }
                        } else if displayname == nil {
                            if isEventSenderMyUser {
                                displayText = localizedString(forKey: "notice_display_name_removed_by_you")
                            } else {
                                if let sender = event?.sender {
                                    displayText = String(format: localizedString(forKey: "notice_display_name_removed"), sender)
                                }
                            }
                        } else {
                            if isEventSenderMyUser {
                                displayText = String(format: localizedString(forKey: "notice_display_name_changed_from_by_you"), prevDisplayname ?? "", displayname ?? "")
                            } else {
                                if let sender = event?.sender {
                                    displayText = String(format: localizedString(forKey: "notice_display_name_changed_from"), sender, prevDisplayname ?? "", displayname ?? "")
                                }
                            }
                        }
                    }

                    // Check whether the avatar has been changed
					var avatar = event?.content["avatar_url"] as? String
					var prevAvatar = event?.prevContent["avatar_url"] as? String

                    if (avatar?.count ?? 0) == 0 {
                        avatar = nil
                    }
                    if (prevAvatar?.count ?? 0) == 0 {
                        prevAvatar = nil
                    }
                    if (prevAvatar != nil || avatar != nil) && ((avatar == prevAvatar) == false) {
						if !displayText.isEmpty {
                            displayText = "\(displayText) \(localizedString(forKey: "notice_avatar_changed_too"))"
                        } else {
                            if isEventSenderMyUser {
                                displayText = localizedString(forKey: "notice_avatar_url_changed_by_you")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_avatar_url_changed"), senderDisplayName ?? "")
                            }
                        }
                    }
                }
            } else {
                // Retrieve membership
				let membership = event?.content["membership"] as? String

                // Prepare targeted member display name
                var targetDisplayName = event?.stateKey

                // Retrieve content displayname
				let contentDisplayname = event?.content["displayname"] as? String
				let prevContentDisplayname = event?.prevContent["displayname"] as? String

                // Consider here a membership change
                if membership == "invite" {
					if let thirdParty = event?.content["third_party_invite"] as? [String: Any] {
                        if event?.stateKey == mxSession?.myUserId {
							if let contentDN = thirdParty["display_name"] as? CVarArg {
                                displayText = String(format: localizedString(forKey: "notice_room_third_party_registered_invite_by_you"), contentDN)
                            }
                        } else {
                            if let content = thirdParty["display_name"] as? CVarArg {
                                displayText = String(format: localizedString(forKey: "notice_room_third_party_registered_invite"), targetDisplayName ?? "", content)
                            }
                        }
                    } else {
                        if MXCallManager.isConferenceUser(event?.stateKey ?? "") {
                            if isEventSenderMyUser {
                                displayText = localizedString(forKey: "notice_conference_call_request_by_you")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_conference_call_request"), senderDisplayName ?? "")
                            }
                        } else {
                            // The targeted member display name (if any) is available in content
                            if isEventSenderMyUser {
                                displayText = String(format: localizedString(forKey: "notice_room_invite_by_you"), targetDisplayName ?? "")
                            } else if targetDisplayName == mxSession?.myUserId {
                                displayText = String(format: localizedString(forKey: "notice_room_invite_you"), senderDisplayName ?? "")
                            } else {
                                if contentDisplayname != nil {
                                    targetDisplayName = contentDisplayname
                                }

                                displayText = String(format: localizedString(forKey: "notice_room_invite"), senderDisplayName ?? "", targetDisplayName ?? "")
                            }
                        }
                    }
                } else if membership == "join" {
                    if MXCallManager.isConferenceUser(event?.stateKey ?? "") {
                        displayText = localizedString(forKey: "notice_conference_call_started")
                    } else {
                        // The targeted member display name (if any) is available in content
                        if isEventSenderMyUser {
                            displayText = localizedString(forKey: "notice_room_join_by_you")
                        } else {
                            if contentDisplayname != nil {
                                targetDisplayName = contentDisplayname
                            }

                            displayText = String(format: localizedString(forKey: "notice_room_join"), targetDisplayName ?? "")
                        }
                    }
                } else if membership == "leave" {
					let  prevMembership = event?.prevContent?["membership"] as? String

                    // The targeted member display name (if any) is available in prevContent
                    if prevContentDisplayname != nil {
                        targetDisplayName = prevContentDisplayname
                    }

                    if event?.sender == event?.stateKey {
                        if MXCallManager.isConferenceUser(event?.stateKey ?? "") {
                            displayText = localizedString(forKey: "notice_conference_call_finished")
                        } else {
                            if prevMembership != nil && (prevMembership == "invite") {
                                if isEventSenderMyUser {
                                    displayText = localizedString(forKey: "notice_room_reject_by_you")
                                } else {
                                    displayText = String(format: localizedString(forKey: "notice_room_reject"), targetDisplayName ?? "")
                                }
                            } else {
                                if isEventSenderMyUser {
                                    displayText = localizedString(forKey: "notice_room_leave_by_you")
                                } else {
                                    displayText = String(format: localizedString(forKey: "notice_room_leave"), targetDisplayName ?? "")
                                }
                            }
                        }
                    } else if let prevMembership = prevMembership {
                        if prevMembership == "invite" {
                            if isEventSenderMyUser {
                                displayText = String(format: localizedString(forKey: "notice_room_withdraw_by_you"), targetDisplayName ?? "")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_room_withdraw"), senderDisplayName ?? "", targetDisplayName ?? "")
                            }
                            if event?.content["reason"] != nil {
                                if let contentReason = event?.content["reason"] as? CVarArg {
                                    displayText = displayText + String(format: localizedString(forKey: "notice_room_reason"), contentReason)
                                }
                            }
                        } else if prevMembership == "join" {
                            if isEventSenderMyUser {
                                displayText = String(format: localizedString(forKey: "notice_room_kick_by_you"), targetDisplayName ?? "")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_room_kick"), senderDisplayName ?? "", targetDisplayName ?? "")
                            }

                            //  add reason if exists
                            if event?.content["reason"] != nil {
                                if let contentReason = event?.content["reason"] as? CVarArg {
                                    displayText = displayText + String(format: localizedString(forKey: "notice_room_reason"), contentReason)
                                }
                            }
                        } else if prevMembership == "ban" {
                            if isEventSenderMyUser {
                                displayText = String(format: localizedString(forKey: "notice_room_unban_by_you"), targetDisplayName ?? "")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_room_unban"), senderDisplayName ?? "", targetDisplayName ?? "")
                            }
                        }
                    }
                } else if membership == "ban" {
                    // The targeted member display name (if any) is available in prevContent
                    if prevContentDisplayname != nil {
                        targetDisplayName = prevContentDisplayname
                    }

                    if isEventSenderMyUser {
                        displayText = String(format: localizedString(forKey: "notice_room_ban_by_you"), targetDisplayName ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_ban"), senderDisplayName ?? "", targetDisplayName ?? "")
                    }
                    if event?.content["reason"] != nil {
                        if let contentReason = event?.content["reason"] as? CVarArg {
                            displayText = displayText + String(format: localizedString(forKey: "notice_room_reason"), contentReason)
                        }
                    }
                }

                // Append redacted info if any
                if let redactedInfo = redactedInfo {
                    displayText = "\(displayText) \(redactedInfo)"
                }
            }

			if displayText.isEmpty {
                error = .unexpected
            }
		case .roomCreate:
			let creatorId = event?.content["creator"] as? String

            if let creatorId = creatorId {
                if creatorId == mxSession?.myUserId {
                    if isRoomDirect {
                        displayText = localizedString(forKey: "notice_room_created_by_you_for_dm")
                    } else {
                        displayText = localizedString(forKey: "notice_room_created_by_you")
                    }
                } else {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_created_for_dm"), (roomState != nil ? roomState?.members.memberName(creatorId) : creatorId) ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_created"), (roomState != nil ? roomState?.members.memberName(creatorId) : creatorId) ?? "")
                    }
                }
                // Append redacted info if any
                if let redactedInfo = redactedInfo {
                    displayText = "\(displayText) \(redactedInfo)"
                }
            }
		case .roomJoinRules:
			let joinRule = event?.content["join_rule"] as? String

            if let joinRule = joinRule {
                if event?.sender == mxSession?.myUserId {
                    if joinRule == kMXRoomJoinRulePublic {
                        if isRoomDirect {
                            displayText = localizedString(forKey: "notice_room_join_rule_public_by_you_for_dm")
                        } else {
                            displayText = localizedString(forKey: "notice_room_join_rule_public_by_you")
                        }
                    } else if joinRule == kMXRoomJoinRuleInvite {
                        if isRoomDirect {
                            displayText = localizedString(forKey: "notice_room_join_rule_invite_by_you_for_dm")
                        } else {
                            displayText = localizedString(forKey: "notice_room_join_rule_invite_by_you")
                        }
                    }
                } else {
                    let displayName = roomState != nil ? roomState?.members.memberName(event?.sender) : event?.sender
                    if joinRule == kMXRoomJoinRulePublic {
                        if isRoomDirect {
                            displayText = String(format: localizedString(forKey: "notice_room_join_rule_public_for_dm"), displayName ?? "")
                        } else {
                            displayText = String(format: localizedString(forKey: "notice_room_join_rule_public"), displayName ?? "")
                        }
                    } else if joinRule == kMXRoomJoinRuleInvite {
                        if isRoomDirect {
                            displayText = String(format: localizedString(forKey: "notice_room_join_rule_invite_for_dm"), displayName ?? "")
                        } else {
                            displayText = String(format: localizedString(forKey: "notice_room_join_rule_invite"), displayName ?? "")
                        }
                    }
                }

				if displayText.isEmpty {
                    //  use old string for non-handled cases: "knock" and "private"
                    displayText = String(format: localizedString(forKey: "notice_room_join_rule"), joinRule)
                }

                // Append redacted info if any
                if let redactedInfo = redactedInfo {
                    displayText = "\(displayText) \(redactedInfo)"
                }
            }
		case .roomPowerLevels:
            if isRoomDirect {
                displayText = localizedString(forKey: "notice_room_power_level_intro_for_dm")
            } else {
                displayText = localizedString(forKey: "notice_room_power_level_intro")
            }
			if let users = event?.content["users"] as? [String: Any] {
				for (key, value) in users {
					if let object = value as? CVarArg {
						displayText = String(format: "%@\n\u{2022} %@: %@", displayText, key, object)
					}
				}
			}

            if let contentUD = event?.content["users_default"] as? CVarArg {
				displayText = String(format: "%@\n\u{2022} %@: %@", displayText, localizedString(forKey: "default"), contentUD)
            }

            displayText = "\(displayText)\n\(localizedString(forKey: "notice_room_power_level_acting_requirement"))"
            if let contentBan = event?.content["ban"] as? CVarArg {
				displayText = String(format: "%@\n\u{2022} ban: %@", displayText, contentBan)
            }
            if let contentKick = event?.content["kick"] as? CVarArg {
				displayText = String(format: "%@\n\u{2022} kick: %@", displayText, contentKick)
            }
            if let contentRedact = event?.content["redact"] as? CVarArg {
				displayText = String(format: "%@\n\u{2022} redact: %@", displayText, contentRedact)
            }
            if let contentInvite = event?.content["invite"] as? CVarArg {
				displayText = String(format: "%@\n\u{2022} invite: %@", displayText, contentInvite)
            }

            displayText = "\(displayText)\n\(localizedString(forKey: "notice_room_power_level_event_requirement"))"

			if let events = event?.content["events"] as? [String: Any] {
				for (key, value) in events {
					if let object = value as? CVarArg {
						displayText = String(format: "%@\n\u{2022} %@: %@", displayText, key, object)
					}
				}
			}

            if let contentED = event?.content["events_default"] as? CVarArg {
				displayText = String(format: "%@\n\u{2022} %@: %@", displayText, "events_default", contentED)
            }
			if let contentSD = event?.content["state_default"] as? CVarArg {
				displayText = String(format: "%@\n\u{2022} %@: %@", displayText, "state_default", contentSD)
            }

            // Append redacted info if any
            if let redactedInfo = redactedInfo {
                displayText = "\(displayText)\n \(redactedInfo)"
            }
		case .roomAliases:
            if let aliases = event?.content["aliases"] as? CVarArg {
                if isRoomDirect {
                    displayText = String(format: localizedString(forKey: "notice_room_aliases_for_dm"), aliases)
                } else {
                    displayText = String(format: localizedString(forKey: "notice_room_aliases"), aliases)
                }
                // Append redacted info if any
                if let redactedInfo = redactedInfo {
                    displayText = "\(displayText)\n \(redactedInfo)"
                }
            }
		case .roomRelatedGroups:
            if let groups = event?.content["groups"] as? [String] {
                displayText = String(format: localizedString(forKey: "notice_room_related_groups"), groups)
                // Append redacted info if any
                if let redactedInfo = redactedInfo {
                    displayText = "\(displayText)\n \(redactedInfo)"
                }
            }
		case .roomEncrypted:
            // Is redacted?
            if isRedacted {
                if redactedInfo == nil {
                    // Here the event is ignored (no display)
                    return nil
                }
                displayText = redactedInfo!
            } else {
                // If the message still appears as encrypted, there was propably an error for decryption
                // Show this error
                if let decryptionErr = event?.decryptionError as NSError? {
                    var errorDescription: String?

                    if (decryptionErr.domain == MXDecryptingErrorDomain) && AppSettings.shared.hideUndecryptableEvents {
                        //  Hide this event, it cannot be decrypted
                        displayText = ""
					} else if (decryptionErr.domain == MXDecryptingErrorDomain) && decryptionErr.code == MXDecryptingErrorUnknownInboundSessionIdCode.rawValue {
                        // Make the unknown inbound session id error description more user friendly
                        errorDescription = localizedString(forKey: "notice_crypto_error_unknown_inbound_session_id")
					} else if (decryptionErr.domain == MXDecryptingErrorDomain) && decryptionErr.code == MXDecryptingErrorDuplicateMessageIndexCode.rawValue {
                        // Hide duplicate message warnings
                        displayText = ""
                    } else {
                        errorDescription = decryptionErr.localizedDescription
                    }

                    if let errorDescription = errorDescription {
                        displayText = String(format: localizedString(forKey: "notice_crypto_unable_to_decrypt"), errorDescription)
                    }
                } else {
                    displayText = localizedString(forKey: "notice_encrypted_message")
                }
            }
		case .roomEncryption:
			var algorithm = event?.content["algorithm"] as? String

            if isRedacted {
                if redactedInfo == nil {
                    // Here the event is ignored (no display)
                    return nil
                }
                algorithm = redactedInfo
            }

            if algorithm == kMXCryptoMegolmAlgorithm {
                if isEventSenderMyUser {
                    displayText = localizedString(forKey: "notice_encryption_enabled_ok_by_you")
                } else {
                    displayText = String(format: localizedString(forKey: "notice_encryption_enabled_ok"), senderDisplayName ?? "")
                }
            } else {
                if isEventSenderMyUser {
                    displayText = String(format: localizedString(forKey: "notice_encryption_enabled_unknown_algorithm_by_you"), algorithm ?? "")
                } else {
                    displayText = String(format: localizedString(forKey: "notice_encryption_enabled_unknown_algorithm"), senderDisplayName ?? "", algorithm ?? "")
                }
            }
		case .roomHistoryVisibility:
            if isRedacted {
                displayText = redactedInfo ?? ""
            } else {
				let historyVisibilityStr = event?.content["history_visibility"] as? String

				if let historyVisibility = MXRoomHistoryVisibility(identifier: historyVisibilityStr ?? "") {
					if historyVisibility == .worldReadable {
                        if !isRoomDirect {
                            if isEventSenderMyUser {
                                displayText = localizedString(forKey: "notice_room_history_visible_to_anyone_by_you")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_room_history_visible_to_anyone"), senderDisplayName ?? "")
                            }
                        }
					} else if historyVisibility  == .shared {
                        if isEventSenderMyUser {
                            if isRoomDirect {
                                displayText = localizedString(forKey: "notice_room_history_visible_to_members_by_you_for_dm")
                            } else {
                                displayText = localizedString(forKey: "notice_room_history_visible_to_members_by_you")
                            }
                        } else {
                            if isRoomDirect {
                                displayText = String(format: localizedString(forKey: "notice_room_history_visible_to_members_for_dm"), senderDisplayName ?? "")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_room_history_visible_to_members"), senderDisplayName ?? "")
                            }
                        }
					} else if historyVisibility == .invited {
                        if isEventSenderMyUser {
                            if isRoomDirect {
                                displayText = localizedString(forKey: "notice_room_history_visible_to_members_from_invited_point_by_you_for_dm")
                            } else {
                                displayText = localizedString(forKey: "notice_room_history_visible_to_members_from_invited_point_by_you")
                            }
                        } else {
                            if isRoomDirect {
                                displayText = String(format: localizedString(forKey: "notice_room_history_visible_to_members_from_invited_point_for_dm"), senderDisplayName ?? "")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_room_history_visible_to_members_from_invited_point"), senderDisplayName ?? "")
                            }
                        }
					} else if historyVisibility == .joined {
                        if isEventSenderMyUser {
                            if isRoomDirect {
                                displayText = localizedString(forKey: "notice_room_history_visible_to_members_from_joined_point_by_you_for_dm")
                            } else {
                                displayText = localizedString(forKey: "notice_room_history_visible_to_members_from_joined_point_by_you")
                            }
                        } else {
                            if isRoomDirect {
                                displayText = String(format: localizedString(forKey: "notice_room_history_visible_to_members_from_joined_point_for_dm"), senderDisplayName ?? "")
                            } else {
                                displayText = String(format: localizedString(forKey: "notice_room_history_visible_to_members_from_joined_point"), senderDisplayName ?? "")
                            }
                        }
                    }
                }
            }
		case .roomMessage:
            // Is redacted?
            if isRedacted {
                if redactedInfo == nil {
                    // Here the event is ignored (no display)
                    return nil
                }
                displayText = redactedInfo!
            } else if event?.isEdit() == true {
                return nil
            } else {
				let msgtype = event?.content["msgtype"] as? String

                var body: String?
                var isHTML = false

                // Use the HTML formatted string if provided
                if event?.content["format"] as? String == kMXRoomMessageFormatHTML {
                    isHTML = true
					body = event?.content["formatted_body"] as? String
                } else {
					body = event?.content["body"] as? String
                }

                if body != nil {
					let showUnsupportedEventsInRoomHistory = settings?.showUnsupportedEventsInRoomHistory ?? false
                    if msgtype == kMXMessageTypeImage {
                        body = body ?? localizedString(forKey: "notice_image_attachment")
                        // Check attachment validity
                        if !isSupportedAttachment(event) {
                            body = localizedString(forKey: "notice_invalid_attachment")
                            error = .unsupported
                        }
                    } else if msgtype == kMXMessageTypeAudio {
                        body = body ?? localizedString(forKey: "notice_audio_attachment")
                        if !isSupportedAttachment(event) {
                            if isForSubtitle || !showUnsupportedEventsInRoomHistory {
                                body = localizedString(forKey: "notice_invalid_attachment")
                            } else {
                                if let description = event?.description {
                                    body = String(format: localizedString(forKey: "notice_unsupported_attachment"), description)
                                }
                            }
                            error = .unsupported
                        }
                    } else if msgtype == kMXMessageTypeVideo {
                        body = body ?? localizedString(forKey: "notice_video_attachment")
                        if !isSupportedAttachment(event) {
                            if isForSubtitle || !showUnsupportedEventsInRoomHistory {
                                body = localizedString(forKey: "notice_invalid_attachment")
                            } else {
                                if let description = event?.description {
                                    body = String(format: localizedString(forKey: "notice_unsupported_attachment"), description)
                                }
                            }
                            error = .unsupported
                        }
                    } else if msgtype == kMXMessageTypeLocation {
                        body = body ?? localizedString(forKey: "notice_location_attachment")
                        if !isSupportedAttachment(event) {
                            if isForSubtitle || !showUnsupportedEventsInRoomHistory {
                                body = localizedString(forKey: "notice_invalid_attachment")
                            } else {
                                if let description = event?.description {
                                    body = String(format: localizedString(forKey: "notice_unsupported_attachment"), description)
                                }
                            }
                            error = .unsupported
                        }
                    } else if msgtype == kMXMessageTypeFile {
                        body = body ?? localizedString(forKey: "notice_file_attachment")
                        // Check attachment validity
                        if !isSupportedAttachment(event) {
                            body = localizedString(forKey: "notice_invalid_attachment")
                            error = .unsupported
                        }
                    }

                    if isHTML {
                        // Build the attributed string from the HTML string
                        attributedDisplayText = renderHTMLString(body, for: event, with: roomState)
                    } else {
                        // Build the attributed string with the right font and color for the event
                        attributedDisplayText = renderString(body, for: event)
                    }

                    // Build the full emote string after the body message formatting
                    if msgtype == kMXMessageTypeEmote {
                        var insertAt = 0

                        // For replies, look for the end of the parent message
                        // This helps us insert the emote prefix in the right place
						let relatesTo = event?.content["m.relates_to"] as? [String: Any]
                        if relatesTo?["m.in_reply_to"] is [AnyHashable : Any] {
                            attributedDisplayText?.enumerateAttribute(
								NSAttributedString.Key(kMXKToolsBlockquoteMarkAttribute),
                                in: NSRange(location: 0, length: attributedDisplayText?.length ?? 0),
								options: .reverse, using:
                                { value, range, stop in
                                    insertAt = range.location
									stop.pointee = true
                                })
                        }

                        // Always use default font and color for the emote prefix
                        let emotePrefix = "* \(senderDisplayName ?? "") "
                        var attributedEmotePrefix: NSAttributedString? = nil
                        if let defaultTextColor = defaultTextColor, let defaultTextFont = defaultTextFont {
                            attributedEmotePrefix = NSAttributedString(
                                string: emotePrefix,
                                attributes: [
                                    NSAttributedString.Key.foregroundColor: defaultTextColor,
                                    NSAttributedString.Key.font: defaultTextFont
                                ])
                        }

                        // Then, insert the emote prefix at the start of the message
                        // (location varies depending on whether it was a reply)
                        var newAttributedDisplayText: NSMutableAttributedString? = nil
                        if let attributedDisplayText = attributedDisplayText {
                            newAttributedDisplayText = NSMutableAttributedString(attributedString: attributedDisplayText)
                        }
                        if let attributedEmotePrefix = attributedEmotePrefix {
                            newAttributedDisplayText?.insert(
                                attributedEmotePrefix,
                                at: insertAt)
                        }
                        attributedDisplayText = newAttributedDisplayText
                    }
                }
            }
		case .roomMessageFeedback:
			let type = event?.content["type"] as? String
			let eventId = event?.content["target_event_id"] as? String

            if type != nil && eventId != nil {
                displayText = String(format: localizedString(forKey: "notice_feedback"), eventId ?? "", type ?? "")
                // Append redacted info if any
                if let redactedInfo = redactedInfo {
                    displayText = "\(displayText) \(redactedInfo)"
                }
            }
		case .roomRedaction:
            let eventId = event?.redacts
            if isEventSenderMyUser {
                displayText = String(format: localizedString(forKey: "notice_redaction_by_you"), eventId ?? "")
            } else {
                displayText = String(format: localizedString(forKey: "notice_redaction"), senderDisplayName ?? "", eventId ?? "")
            }
		case .roomThirdPartyInvite:
			var displayname = event?.content["display_name"] as? String
            if let displayname = displayname {
                if isEventSenderMyUser {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_invite_by_you_for_dm"), displayname)
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_invite_by_you"), displayname)
                    }
                } else {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_invite_for_dm"), senderDisplayName ?? "", displayname)
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_invite"), senderDisplayName ?? "", displayname)
                    }
                }
            } else {
                // Consider the invite has been revoked
				displayname = event?.prevContent["display_name"] as? String
                if isEventSenderMyUser {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_revoked_invite_by_you_for_dm"), displayname ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_revoked_invite_by_you"), displayname ?? "")
                    }
                } else {
                    if isRoomDirect {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_revoked_invite_for_dm"), senderDisplayName ?? "", displayname ?? "")
                    } else {
                        displayText = String(format: localizedString(forKey: "notice_room_third_party_revoked_invite"), senderDisplayName ?? "", displayname ?? "")
                    }
                }
            }
		case .callInvite:
			let callInviteEventContent = MXCallInviteEventContent(fromJSON: event?.content)

            if callInviteEventContent?.isVideoCall() ?? false {
                if isEventSenderMyUser {
                    displayText = localizedString(forKey: "notice_placed_video_call_by_you")
                } else {
                    displayText = String(format: localizedString(forKey: "notice_placed_video_call"), senderDisplayName ?? "")
                }
            } else {
                if isEventSenderMyUser {
                    displayText = localizedString(forKey: "notice_placed_voice_call_by_you")
                } else {
                    displayText = String(format: localizedString(forKey: "notice_placed_voice_call"), senderDisplayName ?? "")
                }
            }
		case .callAnswer:
            if isEventSenderMyUser {
                displayText = localizedString(forKey: "notice_answered_video_call_by_you")
            } else {
                displayText = String(format: localizedString(forKey: "notice_answered_video_call"), senderDisplayName ?? "")
            }
		case .callHangup:
            if isEventSenderMyUser {
                displayText = localizedString(forKey: "notice_ended_video_call_by_you")
            } else {
                displayText = String(format: localizedString(forKey: "notice_ended_video_call"), senderDisplayName ?? "")
            }
		case .callReject:
            if isEventSenderMyUser {
                displayText = localizedString(forKey: "notice_declined_video_call_by_you")
            } else {
                displayText = String(format: localizedString(forKey: "notice_declined_video_call"), senderDisplayName ?? "")
            }
		case .sticker:
            // Is redacted?
            if isRedacted {
                if redactedInfo == nil {
                    // Here the event is ignored (no display)
                    return nil
                }
                displayText = redactedInfo ?? ""
            } else {
				var body = event?.content["body"] as? String

                // Check sticker validity
                if !isSupportedAttachment(event) {
                    body = localizedString(forKey: "notice_invalid_attachment")
                    error = .unsupported
                }

                displayText = body ?? localizedString(forKey: "notice_sticker")
            }
        default:
            error = .unknownEventType
        }

		if attributedDisplayText == nil && !displayText.isEmpty {
            // Build the attributed string with the right font and color for the event
            attributedDisplayText = renderString(displayText, for: event)
        }

        if attributedDisplayText == nil {
            if settings?.showUnsupportedEventsInRoomHistory ?? false {
                if .none == error {
                    error = .unsupported
                }

                var shortDescription: String? = nil

                switch error {
                case .unsupported:
                    shortDescription = localizedString(forKey: "notice_error_unsupported_event")
                case .unexpected:
                    shortDescription = localizedString(forKey: "notice_error_unexpected_event")
                case .unknownEventType:
                    shortDescription = localizedString(forKey: "notice_error_unknown_event_type")
                default:
                    break
                }

                if !isForSubtitle {
                    // Return event content as unsupported event
                    if let description = event?.description {
                        displayText = "\(shortDescription ?? ""): \(description)"
                    }
                } else {
                    // Return a short error description
                    displayText = shortDescription ?? ""
                }

                // Build the attributed string with the right font for the event
                attributedDisplayText = renderString(displayText, for: event)
            }
        }

        return attributedDisplayText
    }

    /// Generate a displayable attributed string representating a summary for the provided events.
    /// - Parameters:
    ///   - events: the series of events to format.
    ///   - roomState: the room state right before the first event in the series.
    ///   - error: the error code. In case of formatting error, the formatter may return non nil string as a proposal.
    /// - Returns: the attributed string.
    func attributedString(fromEvents events: [MXEvent]?, with roomState: MXRoomState?, error: inout EventFormatterError) -> NSAttributedString? {
        // TODO: Do a full summary
        return nil
    }

    /// Render a random string into an attributed string with the font and the text color
    /// that correspond to the passed event.
    /// - Parameters:
    ///   - string: the string to render.
    ///   - event: the event associated to the string.
    /// - Returns: an attributed string.
    func renderString(_ string: String?, for event: MXEvent?) -> NSAttributedString? {
        // Sanity check
        if string == nil {
            return nil
        }

        let str = NSMutableAttributedString(string: string ?? "")

        let wholeString = NSRange(location: 0, length: str.length)

        // Apply color and font corresponding to the event state
		str.addAttribute(.foregroundColor, value: textColor(for: event) ?? .red, range: wholeString)
		str.addAttribute(.font, value: font(for: event) ?? .systemFont(ofSize: UIFont.systemFontSize), range: wholeString)

        // If enabled, make links clickable
        if ((settings?.httpLinkScheme == "http") || (settings?.httpsLinkScheme == "https")) {
            let matches = linkDetector?.matches(in: str.string, options: [], range: wholeString)
            for match in matches ?? [] {
                let matchRange = match.range
                let matchUrl = match.url
                var urlComps: URLComponents? = nil
                if let matchUrl = matchUrl {
					urlComps = URLComponents(url: matchUrl, resolvingAgainstBaseURL: false)
                }

                if var comps = urlComps {
                    if comps.scheme == "http" {
						comps.scheme = settings?.httpLinkScheme ?? "http"
                    } else if comps.scheme == "https" {
						comps.scheme = settings?.httpsLinkScheme ?? "https"
                    }

                    if let url = comps.url {
                        str.addAttribute(.link, value: url, range: matchRange)
                    }
                }
            }
        }

        // Apply additional treatments
        return postRenderAttributedString(str)
    }

    /// Render a random html string into an attributed string with the font and the text color
    /// that correspond to the passed event.
    /// - Parameters:
    ///   - htmlString: the HTLM string to render.
    ///   - event: the event associated to the string.
    ///   - roomState: the room state right before the event.
    /// - Returns: an attributed string.
    func renderHTMLString(_ htmlString: String?, for event: MXEvent?, with roomState: MXRoomState?) -> NSAttributedString? {
        var html = htmlString

        // Special treatment for "In reply to" message
		let relatesTo = event?.content["m.relates_to"] as? [String: Any]
        if relatesTo?["m.in_reply_to"] is [AnyHashable : Any] {
            html = renderReply(to: html, with: roomState)
        }

        // Do some sanitisation before rendering the string
        html = Tools.sanitiseHTML(html, withAllowedHTMLTags: allowedHTMLTags, imageHandler: nil)

        // Apply the css style that corresponds to the event state
        let font = self.font(for: event)
        var options: [String : Any]?
        if let text = textColor(for: event), let dtCSS = dtCSS {
            let fontSize = font?.pointSize ?? 14 // declare this value here, to avoid the compiler error "Segmantation fault 11"
            
            options = [
                DTUseiOS6Attributes: NSNumber(value: true) /* Enable it to be able to display the attributed string in a UITextView */,
                DTDefaultFontFamily: font?.familyName ?? "",
                DTDefaultFontName: font?.fontName ?? "",
                DTDefaultFontSize: NSNumber(value: Int(fontSize)),
                DTDefaultTextColor: text,
                DTDefaultLinkDecoration: NSNumber(value: false),
                DTDefaultStyleSheet: dtCSS
            ]
        }

        // Do not use the default HTML renderer of NSAttributedString because this method
        // runs on the UI thread which we want to avoid because renderHTMLString is called
        // most of the time from a background thread.
        // Use DTCoreText HTML renderer instead.
        // Using DTCoreText, which renders static string, helps to avoid code injection attacks
        // that could happen with the default HTML renderer of NSAttributedString which is a
        // webview.
        var str = NSAttributedString(htmlData: html?.data(using: .utf8), options: options, documentAttributes: nil)

        // Apply additional treatments
        if let post = postRenderAttributedString(str) {
            str = post
        }

        // Finalize the attributed string by removing DTCoreText artifacts (Trim trailing newlines).
        str = Tools.removeDTCoreTextArtifacts(str)

        // Finalize HTML blockquote blocks marking
        str = Tools.removeMarkedBlockquotesArtifacts(str)

        return str
    }

    /// Special treatment for "In reply to" message.
    /// According to https://docs.google.com/document/d/1BPd4lBrooZrWe_3s_lHw_e-Dydvc7bXbm02_sV2k6Sc/edit.
    /// - Parameters:
    ///   - htmlString: an html string containing a reply-to message.
    ///   - roomState: the room state right before the event.
    /// - Returns: a displayable internationalised html string.
    static var renderReplyToHtmlATagRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: kHTMLATagRegexPattern, options: .caseInsensitive)
    }()

    func renderReply(to htmlString: String?, with roomState: MXRoomState?) -> String? {
        guard var html = htmlString else {
            return nil
        }
        // `dispatch_once()` call was converted to a static variable initializer

        var hrefCount = 0

        var inReplyToLinkRange = NSRange(location: NSNotFound, length: 0)
        var inReplyToTextRange = NSRange(location: NSNotFound, length: 0)
        var userIdRange = NSRange(location: NSNotFound, length: 0)

        EventFormatter.renderReplyToHtmlATagRegex?.enumerateMatches(
            in: html,
            options: [],
            range: NSRange(location: 0, length: html.count),
            using: { match, flags, stop in

                if hrefCount > 1 {
                    stop.pointee = true
                } else if hrefCount == 0 && (match?.numberOfRanges ?? 0) >= 2 {
                    if let range = match?.range(at: 1) {
                        inReplyToLinkRange = range
                    }
                    if let range = match?.range(at: 2) {
                        inReplyToTextRange = range
                    }
                } else if hrefCount == 1 && (match?.numberOfRanges ?? 0) >= 2 {
                    if let range = match?.range(at: 2) {
                        userIdRange = range
                    }
                }

                hrefCount += 1
            })

        // Note: Take care to replace text starting with the end

        // Replace <a href=\"https://matrix.to/#/mxid\">mxid</a>
        // By <a href=\"https://matrix.to/#/mxid\">Display name</a>
        // To replace the user Matrix ID by his display name when available.
        // This link is the second <a> HTML node of the html string

        if userIdRange.location != NSNotFound {
            let userId = (html as NSString?)?.substring(with: userIdRange)

            let senderDisplayName = roomState?.members.memberName(userId)

            if let senderDisplayName = senderDisplayName {
                html = (html as NSString).replacingCharacters(in: userIdRange, with: senderDisplayName)
            }
        }

        // Replace <mx-reply><blockquote><a href=\"__permalink__\">In reply to</a>
        // By <mx-reply><blockquote><a href=\"#\">['In reply to' from resources]</a>
        // To disable the link and to localize the "In reply to" string
        // This link is the first <a> HTML node of the html string

        if inReplyToTextRange.location != NSNotFound {
            html = (html as NSString).replacingCharacters(in: inReplyToTextRange, with: localizedString(forKey: "notice_in_reply_to"))
        }

        if inReplyToLinkRange.location != NSNotFound {
            html = (html as NSString).replacingCharacters(in: inReplyToLinkRange, with: "#")
        }

        return html
    }

    func postRenderAttributedString(_ attributedString: NSAttributedString?) -> NSAttributedString? {
        if attributedString == nil {
            return nil
        }

        var enabledMatrixIdsBitMask = 0

        // If enabled, make user id clickable
        if treatMatrixUserIdAsLink {
            enabledMatrixIdsBitMask |= MXKTOOLS_USER_IDENTIFIER_BITWISE
        }

        // If enabled, make room id clickable
        if treatMatrixRoomIdAsLink {
            enabledMatrixIdsBitMask |= MXKTOOLS_ROOM_IDENTIFIER_BITWISE
        }

        // If enabled, make room alias clickable
        if treatMatrixRoomAliasAsLink {
            enabledMatrixIdsBitMask |= MXKTOOLS_ROOM_ALIAS_BITWISE
        }

        // If enabled, make event id clickable
        if treatMatrixEventIdAsLink {
            enabledMatrixIdsBitMask |= MXKTOOLS_EVENT_IDENTIFIER_BITWISE
        }

        // If enabled, make group id clickable
        if treatMatrixGroupIdAsLink {
            enabledMatrixIdsBitMask |= MXKTOOLS_GROUP_IDENTIFIER_BITWISE
        }

        return Tools.createLinks(in: attributedString, forEnabledMatrixIds: enabledMatrixIdsBitMask)
    }

    func renderString(_ string: String?, withPrefix prefix: String?, for event: MXEvent?) -> NSAttributedString? {
        var str: NSMutableAttributedString?

        if let prefix = prefix {
            str = NSMutableAttributedString(string: prefix)

            // Apply the prefix font and color on the prefix
            let prefixRange = NSRange(location: 0, length: prefix.count)
			str?.addAttribute(.foregroundColor, value: prefixTextColor ?? .gray, range: prefixRange)
			str?.addAttribute(.font, value: prefixTextFont ?? .systemFont(ofSize: UIFont.systemFontSize), range: prefixRange)

            // And append the string rendered according to event state
            if let render = renderString(string, for: event) {
                str?.append(render)
            }

            return str
        } else {
            // Use the legacy method
            return renderString(string, for: event)
        }
    }

    // MARK: - MXRoomSummaryUpdating

    func session(_ session: MXSession?, update summary: MXRoomSummary?, withStateEvents stateEvents: [MXEvent]?, roomState: MXRoomState?) -> Bool {
        // We build strings containing the sender displayname (ex: "Bob: Hello!")
        // If a sender changes his displayname, we need to update the lastMessage.
        var lastMessage: MXRoomLastMessage?
        for event in stateEvents ?? [] {
            if event.isUserProfileChange() {
                if lastMessage == nil {
                    // Load lastMessageEvent on demand to save I/O
                    lastMessage = summary?.lastMessage
                }

                if event.sender == lastMessage?.sender {
                    // The last message must be recomputed
                    summary?.resetLastMessage(nil, failure: nil, commit: true)
                    break
                }
            } else if event.eventType == .roomJoinRules {
                summary?.others["mxkEventFormatterisJoinRulePublic"] = NSNumber(value: roomState!.isJoinRulePublic)
            }
        }

        return defaultRoomSummaryUpdater?.session(session, update: summary, withStateEvents: stateEvents, roomState: roomState) ?? false
    }

    func session(_ session: MXSession?, update summary: MXRoomSummary?, withLast event: MXEvent?, eventState: MXRoomState?, roomState: MXRoomState?) -> Bool {
        // Use the default updater as first pass
        let currentlastMessage = summary?.lastMessage
        var updated = defaultRoomSummaryUpdater?.session(session, update: summary, withLast: event, eventState: eventState, roomState: roomState) ?? false
        if updated {
            // Then customise

            // Compute the text message
            // Note that we use the current room state (roomState) because when we display
            // users displaynames, we want current displaynames
            var error: EventFormatterError = .none
            let lastMessageString = string(from: event, with: roomState, error: &error)
            if 0 == (lastMessageString?.count ?? 0) {
                // @TODO: there is a conflict with what [defaultRoomSummaryUpdater updateRoomSummary] did :/
                updated = false
                // Restore the previous lastMessageEvent
                summary?.updateLastMessage(currentlastMessage)
            } else {
                summary?.lastMessage.text = lastMessageString

                if summary?.lastMessage.others == nil {
                    summary?.lastMessage.others = [:]
                }

                // Store the potential error
                summary?.lastMessage.others!["mxkEventFormatterError"] = NSNumber(value: error.rawValue)

                summary?.lastMessage.others!["lastEventDate"] = dateString(from: event, withTime: true)

                // Check whether the sender name has to be added
                var prefix: String? = nil

                if event?.eventType == .roomMessage {
                    let msgtype = event?.content["msgtype"] as? String
                    if msgtype != kMXMessageTypeEmote {
                        let senderDisplayName = self.senderDisplayName(for: event, with: roomState)
                        prefix = "\(senderDisplayName ?? ""): "
                    }
                } else if event?.eventType == .sticker {
                    let senderDisplayName = self.senderDisplayName(for: event, with: roomState)
                    prefix = "\(senderDisplayName ?? ""): "
                }

                // Compute the attribute text message
                summary?.lastMessage.attributedText = renderString(summary?.lastMessage.text, withPrefix: prefix, for: event)
            }
        }

        return updated
    }

    func session(_ session: MXSession?, update summary: MXRoomSummary?, withServerRoomSummary serverRoomSummary: MXRoomSyncSummary?, roomState: MXRoomState?) -> Bool {
        return defaultRoomSummaryUpdater?.session(session, update: summary, withServerRoomSummary: serverRoomSummary, roomState: roomState) ?? false
    }

    // MARK: - Conversion private methods

    /// Get the text color to use according to the event state.
    /// - Parameter event: the event.
    /// - Returns: the text color.
    func textColor(for event: MXEvent?) -> UIColor? {
        // Select the text color
        var textColor: UIColor?

        // Check whether an error occurred during event formatting.
//        if event?.mxkEventFormatterError != .none {
//            textColor = errorTextColor
//        } else if event?.mxkIsHighlighted {
//            textColor = bingTextColor
//        } else {
            // Consider here the sending state of the event, and the property `isForSubtitle`.
            switch event?.sentState {
            case MXEventSentStateSent:
                if isForSubtitle {
                    textColor = subTitleTextColor
                } else {
                    textColor = defaultTextColor
                }
            case MXEventSentStateEncrypting:
                textColor = encryptingTextColor
            case MXEventSentStatePreparing, MXEventSentStateUploading, MXEventSentStateSending:
                textColor = sendingTextColor
            case MXEventSentStateFailed:
                textColor = errorTextColor
            default:
                if isForSubtitle {
                    textColor = subTitleTextColor
                } else {
                    textColor = defaultTextColor
                }
            }
//        }

        return textColor
    }

    /// Get the text font to use according to the event state.
    /// - Parameter event: the event.
    /// - Returns: the text font.
    func font(for event: MXEvent?) -> UIFont? {
        // Select text font
        var font = defaultTextFont
        if event?.isState() == true {
            font = stateEventTextFont
        } else if event?.eventType == .callInvite || event?.eventType == .callAnswer || event?.eventType == .callHangup {
            font = callNoticesTextFont
        } else if event?.eventType == .roomEncrypted {
            font = encryptedMessagesTextFont
        } else if !isForSubtitle && event?.eventType == .roomMessage && (emojiOnlyTextFont != nil || singleEmojiTextFont != nil) {
            let message = event?.content["body"] as? String

            if emojiOnlyTextFont != nil && Tools.isEmojiOnlyString(message) {
                font = emojiOnlyTextFont
            } else if singleEmojiTextFont != nil && Tools.isSingleEmojiString(message) {
                font = singleEmojiTextFont
            }
        }
        return font
    }

    // MARK: - Conversion tools

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

    // MARK: - Timestamp formatting

    /// Generate the date in string format corresponding to the date.
    /// - Parameters:
    ///   - date: The date.
    ///   - time: The flag used to know if the returned string must include time information or not.
    /// - Returns: the string representation of the date.
    func dateString(from date: Date?, withTime time: Bool) -> String? {
        // Get first date string without time (if a date format is defined, else only time string is returned)
        var dateString: String? = nil
        if dateFormatter?.dateFormat != nil {
            if let date = date {
                dateString = dateFormatter?.string(from: date)
            }
        }

        if time {
            let timeString = self.timeString(from: date)
            if (dateString?.count ?? 0) != 0 {
                // Add time string
                dateString = "\(dateString ?? "") \(timeString ?? "")"
            } else {
                dateString = timeString
            }
        }

        return dateString
    }

    /// Generate the date in string format corresponding to the timestamp.
    /// The returned string is localised according to the current device settings.
    /// - Parameters:
    ///   - timestamp: The timestamp in milliseconds since Epoch.
    ///   - time: The flag used to know if the returned string must include time information or not.
    /// - Returns: the string representation of the date.
    func dateString(fromTimestamp timestamp: UInt64, withTime time: Bool) -> String? {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))

        return dateString(from: date, withTime: time)
    }

    /// Generate the date in string format corresponding to the event.
    /// The returned string is localised according to the current device settings.
    /// - Parameters:
    ///   - event: The event to format.
    ///   - time: The flag used to know if the returned string must include time information or not.
    /// - Returns: the string representation of the event date.
    func dateString(from event: MXEvent?, withTime time: Bool) -> String? {
        if event?.originServerTs != kMXUndefinedTimestamp {
            return dateString(fromTimestamp: event?.originServerTs ?? 0, withTime: time)
        }

        return nil
    }

    /// Generate the time string of the provided date by considered the current system time formatting.
    /// - Parameter date: The date.
    /// - Returns: the string representation of the time component of the date.
    func timeString(from date: Date?) -> String? {
        var timeString: String? = nil
        if let date = date {
            timeString = timeFormatter?.string(from: date)
        }

        return timeString?.lowercased()
    }
}

// 

// MARK: from C macros

fileprivate func localizedString(forKey key: String) -> String {
	return NSLocalizedString(key, comment: "")
}
