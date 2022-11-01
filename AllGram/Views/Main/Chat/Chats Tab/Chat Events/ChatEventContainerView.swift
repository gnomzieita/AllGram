//
//  ChatEventContainerView.swift
//  AllGram
//
//  Created by Alex Pirog on 08.06.2022.
//

import SwiftUI
import MatrixSDK

extension ChatEventContainerView: Equatable {
    static func == (lhs: ChatEventContainerView, rhs: ChatEventContainerView) -> Bool {
        lhs.event.eventId == rhs.event.eventId
    }
}

/// Container view that provides needed UI depending on the event type.
/// Also handles reactions
struct ChatEventContainerView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.userId) private var userId
    
    @EnvironmentObject var room: AllgramRoom
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    /// Handles downloading of media files, both encrypted and row
    @ObservedObject var attachment: ChatMediaAttachment
    
    let event: MXEvent
    let reactions: [Reaction]
    let connectedEdges: ConnectedEdges
    let showSender: Bool
    let edits: [MXEvent]
    let isRead: Bool
    
    var member: MXRoomMember? {
        membersVM.member(with: event.sender)?.member
    }
    
    init(event: MXEvent,
         reactions: [Reaction],
         connectedEdges: ConnectedEdges,
         showSender: Bool,
         edits: [MXEvent],
         isRead: Bool
    ) {
        self.event = event
        self.reactions = reactions
        self.connectedEdges = connectedEdges
        self.showSender = showSender
        self.edits = edits
        self.isRead = isRead
        self.attachment = ChatMediaAttachment(event: event)
    }
    
    var senderAvatar: URL? {
        room.realUrl(from: member?.avatarUrl)
    }
    
    var senderName: String? {
        member?.displayname
    }
    
    var body: some View {
        switch event.eventType {
        case .roomEncrypted:
            // Encrypted variant of .roomMessage when waiting for keys
            ExpandingHStack(contentPosition: isMyEvent ? .right(minLength: 60) : .left(minLength: 60)) {
                VStack(alignment: isMyEvent ? .trailing : .leading, spacing: 0) {
                    messageHeader
                    ChatEncryptedMessageView()
                        .padding(.horizontal, 8)
                        .padding(.top, connectedTop ? 8 : 0)
                        .padding(.bottom, reactions.isEmpty ? 8 : 0)
                }
                .overlay(badgeOverlay, alignment: .bottomTrailing)
                .background(bubbleColor)
                .clipShape(bubbleShape)
                .padding(.top, connectedTop ? 2 : 8)
                .padding(.bottom, connectedBottom ? 2 : 8)
            }
            .onAppear {
                room.room.moveReadMarker(toEventId: event.eventId)
            }
        case .roomMessage:
            if event.isRedactedEvent() {
                // Redacted (deleted) event -> show system one
                ChatRedactionEventView(
                    model: .init(avatar: senderAvatar, sender: senderName, event: event)
                )
            } else if event.isEdit() {
                // Edit event -> no need to show
                EmptyView()
            } else {
                // Room message - handle bordered view
                ExpandingHStack(contentPosition: isMyEvent ? .right(minLength: 60) : .left(minLength: 60)) {
                    VStack(alignment: isMyEvent ? .trailing : .leading, spacing: 0) {
                        messageHeader
                        messageView
                            .foregroundColor(textColor)
                        reactionsView
                    }
                    .overlay(badgeOverlay, alignment: .bottomTrailing)
                    .background(bubbleColor)
                    .clipShape(bubbleShape)
                    .padding(.top, connectedTop ? 2 : 8)
                    .padding(.bottom, connectedBottom ? 2 : 8)
                    .opacity(attachment.isLocalEcho ? 0.7 : 1)
                }
                .onAppear {
                    room.room.moveReadMarker(toEventId: event.eventId)
                }
            }
            
        case .roomMember:
            ChatRoomMemberEventView(
                model: .init(avatar: senderAvatar, sender: senderName, event: event)
            )
            
        case .roomName:
            ChatRoomNameEventView(
                model: .init(avatar: senderAvatar, sender: senderName, event: event)
            )
            
        case .roomTopic:
            ChatRoomTopicEventView(
                model: .init(avatar: senderAvatar, sender: senderName, event: event)
            )
            
        case .callInvite, .callAnswer, .callReject, .callHangup:
            ChatCallEventView(
                model: .init(avatar: senderAvatar, sender: senderName, event: event)
            )
            
        default:
            ChatSystemEventView(avatarURL: senderAvatar, displayname: senderName, text: "Unhandled event type: \(event.type ?? "nil")")
        }
    }
    
    // MARK: - Room Message Events
    
    private var isMyEvent: Bool {
        userId == event.sender
    }
    private var connectedTop: Bool {
        connectedEdges.contains(.topEdge)
    }
    private var connectedBottom: Bool {
        connectedEdges.contains(.bottomEdge)
    }
    private var bubbleColor: Color {
        isMyEvent ? .postMyCommentBackground : .postOtherCommentBackground
    }
    private var textColor: Color {
        isMyEvent ? .black : .black
    }
    private var messageTime: String {
        Formatter.string(for: event.timestamp, timeStyle: .short)
    }
    private var headerBottomPadding: CGFloat {
        event.isMediaAttachment() && !event.isVoiceMessage() ? 8 : 0
    }
    
    private var bubbleShape: IndividuallyRoundedRectangle {
        IndividuallyRoundedRectangle(
            topLeft: !isMyEvent && connectedTop ? 4 : 16,
            topRight: isMyEvent && connectedTop ? 4 : 16,
            bottomLeft: !isMyEvent && connectedBottom ? 4 : 16,
            bottomRight: isMyEvent && connectedBottom ? 4 : 16
        )
    }
    
    @ViewBuilder
    private var messageView: some View {
        // Media event with image, audio, video, file or sticker
        // Otherwise no decoding problems for encrypted messages
        switch event.messageType! {
        case .text:
            ChatTextMessageView(model: .init(event: event))
                .padding(.horizontal, 8)
                .padding(.top, connectedTop ? 8 : 0)
                .padding(.bottom, reactions.isEmpty ? 8 : 0)
            
        case .image:
            ChatImageMessageView(model: .init(attachment: attachment))
            
        case .video:
            ChatVideoMessageView(model: .init(attachment: attachment))
            
        case .audio:
            if event.isVoiceMessage() {
                ChatVoiceMessageView(model: .init(attachment: attachment))
            } else {
                ChatAudioMessageView(model: .init(attachment: attachment))
            }
            
        case .file:
            ChatFileMessageView(model: .init(attachment: attachment))
            
        default:
            ChatTextMessageView(model: .init(message: "Unhandled message type: \(event.messageType?.identifier ?? "nil")", replyToText: nil, replyToUser: nil))
                .padding(.horizontal, 8)
                .padding(.top, connectedTop ? 8 : 0)
                .padding(.bottom, reactions.isEmpty ? 8 : 0)
        }
    }
    
    @ViewBuilder
    private var messageHeader: some View {
        if !connectedTop {
            HStack {
                if !isMyEvent {
                    Text(verbatim: senderName ?? event.sender.dropAllgramSuffix)
                        .font(.subheadline).bold()
                        .foregroundColor(.pink)
                }
                Text(verbatim: messageTime)
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            .padding([.top, .horizontal], 8)
            .padding(.bottom, headerBottomPadding)
        }
    }
    
    @ViewBuilder
    private var badgeOverlay: some View {
        HStack {
            if !edits.isEmpty {
                // Edit badge
                Image(systemName: "pencil")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 8, height: 8)
                    .foregroundColor(.gray)
            }
            if isRead {
                // Seen badge
                Image(systemName: "eye.fill")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 8, height: 8)
                    .foregroundColor(.gray)
            }
        }
        .padding(.all, 4)
    }
    
    @ViewBuilder
    private var reactionsView: some View {
        if !reactions.isEmpty {
            ReactionGridView(
                reactions: reactions,
                widthLimit: UIScreen.main.bounds.width - 60,
                alignment: isMyEvent ? .trailing : .leading,
                textColor: .black,
                backColor: .allgramMain,
                userColor: .allgramMain
            ) { group in
                if let reaction = group.reaction(from: userId) {
                    room.redact(eventId: reaction.id, reason: nil)
                } else {
                    room.react(toEventId: event.eventId, emoji: group.reaction)
                }
            }
                .padding(.all, 6)
        } else {
            EmptyView()
        }
    }
}
