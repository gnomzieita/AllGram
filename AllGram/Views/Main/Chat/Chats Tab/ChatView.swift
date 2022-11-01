//
//  ChatView.swift
//  AllGram
//
//  Created by Alex Pirog on 08.06.2022.
//

import SwiftUI
import Combine
import MatrixSDK
import Kingfisher

extension ChatView: Equatable {
    static func == (lhs: ChatView, rhs: ChatView) -> Bool {
        lhs.room.roomId == rhs.room.roomId
    }
}

/// Actual chat view
struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.userId) private var userId
    
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    @ObservedObject var room: AllgramRoom
    
    @Binding var scrollToEvent: MXEvent?
    @State var scrollToId: ObjectIdentifier?
    
    var onBack: (() -> Void)?

    @State private var shouldPaginate = false

    private var events: EventCollection {
        return room.events()
    }

    private var areOtherUsersTyping: Bool {
        return !(room.room.typingUsers?.filter({ $0 != userId }).isEmpty ?? true)
    }

    // Determines whether to put a date bubble before an event container or not
    private let breakManager = ChatEventsBreakdownManager()
    
    // All events that are on screen now
    @State private var visibleEvents = [MXEvent]()
    @State private var bubbleDateText = "Today"
    @State private var showScrollButton = false
    @State private var scrollToBottom = false
    
    @State private var eventToRedactId: String?
    @State private var eventToReactId: String?
    
    // Will take some time to prepare file for share
    @State var shareActivities: [AnyObject] = []
    @State var showShare = false
    
    /// Handles input view and provides data for new messages
    @StateObject private var inputVM: MessageInputViewModel
    
    /// Handles sending messages with data from inputVM
    let inputHandler: ChatInputHandler
    
    @State var showMedia = false
    @State var showAttachment: ChatMediaAttachment?
    
    init(room: AllgramRoom, scrollToEvent: Binding<MXEvent?>, onBack: (() -> Void)? = nil) {
        self.onBack = onBack
        self.room = room
        let handler = ChatInputHandler(room: room)
        self._inputVM = StateObject(wrappedValue: MessageInputViewModel(config: .chat, delegate: handler))
        self.inputHandler = handler
        self._scrollToEvent = scrollToEvent
    }
    
    @State var showPermissionAlert = false
    @State var permissionAlertText = ""

    var body: some View {
        ZStack {
            // Navigation
            VStack {
                NavigationLink(
                    destination:
                        Group {
                            if let attachment = showAttachment {
                                ChatFullscreenMediaView(attachment: attachment)
                            } else {
                                EmptyView().onAppear { showMedia = false }
                            }
                        }
                    ,
                    isActive: $showMedia
                ) {
                    EmptyView()
                }
            }
            // Content
            VStack(spacing: 0) {
                // Voice player
                if voicePlayer.currentURL != nil {
                    Divider()
                    ChatVoicePlayerView(
                        voicePlayer: voicePlayer,
                        voiceEvents: events.renderableEvents.filter { $0.isVoiceMessage() }
                    )
                        .background(Color("bgColor"))
                }
                // Messages
                Divider()
                ReverseList(
                    events.renderableEvents,
                    hasReachedTop: $shouldPaginate,
                    expectMore: room.expectMoreHistory,
                    scrollToId: $scrollToId,
                    scrollToBottom: $scrollToBottom,
                    spacing: 0 // Spacing handled by padding
                ) { event in
                    DateEventContainerWrapperView(
                        date: breakManager.shouldAddDateView(for: event, in: events.renderableEvents)
                    ) {
                        ChatEventContainerView(
                            event: event,
                            reactions: events.reactions(for: event),
                            connectedEdges: events.connectedEdges(of: event),
                            showSender: !room.isDirect,
                            edits: events.relatedEvents(of: event).filter { $0.isEdit() },
                            isRead: room.isReadedState(for: event.eventId)
                        )
                            .equatable()
                            .onTapGesture {
                                // Leave empty, this enables scrolling inside
                                // scrollview when items has long press gestures.
                                // However, it gives slight delay for long press
                                switch event.messageType {
                                case .image, .video:
                                    withAnimation {
                                        showAttachment = ChatMediaAttachment(event: event)
                                        showMedia = showAttachment != nil
                                    }
                                default:
                                    break
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.1) {
                                // TODO: Add event checking before options if needed
                                eventForSheet = event
                            }
                            .onAppear {
                                if !visibleEvents.contains(event) {
                                    visibleEvents.append(event)
                                    let date = breakManager.earliestDate(in: visibleEvents) ?? Date()
                                    withAnimation {
                                        bubbleDateText = date.chatBubbleDate(addYear: false)
                                        showScrollButton = !visibleEvents.contains(events.renderableEvents.last!)
                                    }
                                }
                            }
                            .onDisappear {
                                if let index = visibleEvents.firstIndex(of: event) {
                                    visibleEvents.remove(at: index)
                                    let date = breakManager.earliestDate(in: visibleEvents) ?? Date()
                                    withAnimation {
                                        bubbleDateText = date.chatBubbleDate(addYear: false)
                                        showScrollButton = !visibleEvents.contains(events.renderableEvents.last!)
                                    }
                                }
                            }
                    }
                    .padding(.horizontal, 6)
                }
                .onTapGesture { hideKeyboard() }
                .overlay(chatOverlay)
                // Typing indicator
                if areOtherUsersTyping {
                    TypingIndicatorContainerView()
                }
                // Message input
                Divider()
                MessageInputView(viewModel: inputVM, showPermissionAlert: $showPermissionAlert, permissionAlertText: $permissionAlertText)
                    .equatable()
                    .onAppear {
                        inputHandler.clearHandler = {
                            inputVM.inputType = .new
                        }
//                        inputVM.inputDelegate = inputHandler
                    }
                    .background(Color("bgColor"))
            }
            .background(chatBackground)
            // Custom Alerts
            if showingIgnoreAlert { ignoreAlert }
            if showingReportAlert { reportAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
            if showingLoader { loaderAlert }
        }
        .onAppear {
            room.listenIfOthersAreTyping = true
            IgnoringUsersViewModel.shared.getIgnoredUsersList()
        }
        .onDisappear {
            room.listenIfOthersAreTyping = false
        }
        .onChange(of: shouldPaginate) { newValue in
            if newValue {
                room.paginateBackward()
                shouldPaginate = false
            }
        }
        .onChange(of: scrollToEvent) { event in
            scrollToId = nil
            guard let event = event else { return }
            let message = ChatTextMessageView.Model(event: event).message
            //print("[P] start paginated to \(message)")
            loaderInfo = "Paginating back to \(message.truncate(length: 120))"
            withAnimation { showingLoader = true }
            room.paginate(till: event) { success in
                withAnimation { showingLoader = false }
                if success {
                    //print("[P] successfully paginated to event")
                    let paginateEvent = room.events().renderableEvents.first { $0.eventId == event.eventId }
                    scrollToId = paginateEvent?.id
                } else {
                    //print("[P] failed to paginate to event")
                    scrollToBottom = true
                }
                scrollToEvent = nil
            }
        }
        .partialSheet(isPresented: $showSheet) {
            sheetContent
        }
        .fullScreenCover(item: $eventToReactId) { eventId in
            ReactionPicker { reaction in
                room.react(toEventId: eventId, emoji: reaction)
                eventToReactId = nil
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityViewController(activityItems: shareActivities)
        }
        .onChange(of: showShare) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
        .background(Color("bgColor").edgesIgnoringSafeArea(.top))
    }
    
    private var permissionAlertView: some View {
        ActionAlert(showAlert: $showPermissionAlert, title: "Access to \(permissionAlertText)", text: "Tap Settings and enable \(permissionAlertText)", actionTitle: "Settings") {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    
    @ViewBuilder
    private var chatBackground: some View {
        if let name = SettingsManager.chatBackgroundImageName {
            Image(name)
                .resizable().scaledToFill()
                .clipped()
        } else if let image = SettingsManager.getChatBackgroundImage() {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .clipped()
        } else {
            Rectangle()
                .foregroundColor(Color("bgColor"))
        }
    }
    
    private var chatOverlay: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(verbatim: bubbleDateText)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .frame(height: 32)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .foregroundColor(.postMyCommentBackground)
                    )
                    .shadow(radius: 1)
                    .padding(.vertical)
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    if showScrollButton {
                        Button {
                            withAnimation { scrollToBottom.toggle() }
                        } label: {
                            Image("angle-down-solid")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .foregroundColor(.black)
                                .frame(width: 20, height: 20)
                                .padding(.all, 20)
                                .background(Circle().foregroundColor(.white))
                                .shadow(radius: 4)
                                .overlay(
                                    VStack {
                                        HStack {
                                            Spacer()
                                            let count = room.summary.notificationCount
                                            if count > 0 {
                                                Text(count > 99 ? "..." : "\(count)")
                                                    .bold()
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white)
                                                    .frame(width: 20, height: 20)
                                                    .background(
                                                        Circle()
                                                            .foregroundColor(.pink)
                                                    )
                                            }
                                        }
                                        Spacer()
                                    }
                                )
                        }
                        .padding(.all, 16)
                        .transition(.scale)
                        .animation(.easeInOut(duration: 0.15))
                    }
                }
            }
            if showPermissionAlert { permissionAlertView }
        }
    }
    
    private func getEventHighlight(for event: MXEvent) -> String? {
        if let typeString = event.content["msgtype"] as? String {
            switch MXMessageType(identifier: typeString) {
            case .image:
                return "image/jpeg"
            case .video:
                return "video/mp4"
            case .text:
                return ChatTextMessageView.Model(event: event).message
            case .audio:
                return "voice message"
            default:
                return nil
            }
        }
        return nil
    }
    
    /// Swipe left-to-right from the edge gesture to exit the chat
//    private var swipeGesture: some Gesture {
//        DragGesture(minimumDistance: 3.0, coordinateSpace: .local)
//            .onEnded { value in
//                let fromEdge = value.startLocation.x < UIScreen.main.bounds.width * 0.3
//                let leftToRight = value.translation.width > 30 && abs(value.translation.height) < 30
//                if fromEdge && leftToRight {
//                    // Gesture to exit chat
//                    presentationMode.wrappedValue.dismiss()
//                    onBack?()
//                }
//            }
//    }
    
    // MARK: - Sheet
    
    @State private var showSheet = false
    @State private var eventForSheet: MXEvent? {
        didSet { showSheet = eventForSheet != nil }
    }
    @State private var showReportOptions = false
    
    private var sheetContent: some View {
        VStack(spacing: 0) {
            if let event = eventForSheet, let id = event.eventId {
                // Generic detail, always include
                let sender = membersVM.member(with: event.sender)
                let senderURL = sender?.avatarURL
                let senderName = sender?.displayname ?? "Unknown"
                SheetMessageView(senderName: senderName, senderURL: senderURL, sentDate: event.timestamp)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                // Check what options is available
                let isMyEvent = event.sender == room.session.myUserId
                let isMessageEvent = event.eventType == .roomMessage
                let isTextMessage = event.messageType == .text
                let isVoiceMessage = event.isVoiceMessage()
                let isMediaMessage = event.messageType == .image || event.messageType == .video || event.messageType == .audio || event.messageType == .file
                // Only for message events
                let canReply = isMessageEvent
                // Only for own text messages
                let canEdit = isTextMessage && isMyEvent
                // Only for own message events
                let canRemove = isMessageEvent && isMyEvent
                // Only when text message
                let canCopy = isTextMessage
                // Only for message events
                let canReact = isMessageEvent
                // Only for text messages
                let canQuote = isTextMessage
                // Only for text or media message events
                let canShare = (isMediaMessage || isTextMessage) && !isVoiceMessage
//                // Only for media (image, video) messages
//                let canSave = isMediaMessage && !isVoiceMessage
//                // Only for message events
//                let canLink = isMessageEvent
                // Only for others messages
                let canReport = !isMyEvent && isMessageEvent
                // Only for others and NOT ignoring already
                let canIgnore = !isMyEvent && !IgnoringUsersViewModel.shared.ignoredUsers.contains(event.sender)
                // Show only needed options
                if canReact {
                    SheetReactionsView { emoji in
                        room.react(toEventId: id, emoji: emoji)
                        eventForSheet = nil
                    }
                }
                Group {
                    if canReply {
                        SheetActionView(title: "Reply", imageName: "reply-solid") {
                            let message = getEventHighlight(for: event)!
                            inputVM.inputType = .reply(eventId: id, highlight: .text(message))
                            eventForSheet = nil
                        }
                    }
                    if canEdit {
                        SheetActionView(title: "Edit", imageName: "pen-solid") {
                            let message = getEventHighlight(for: event)!
                            inputVM.message = message
                            inputVM.inputType = .edit(eventId: id, highlight: .text(message))
                            eventForSheet = nil
                        }
                    }
                    if canRemove {
                        SheetActionView(title: "Remove...", imageName: "times-solid") {
                            if event.sentState == MXEventSentStateFailed {
                                room.removeOutgoingMessage(event)
                            } else {
                                room.redact(eventId: id, reason: nil)
                            }
                            eventForSheet = nil
                        }
                        .foregroundColor(.red)
                    }
                    if canCopy {
                        SheetActionView(title: "Copy", imageName: "copy-solid") {
                            // Copy text message to clipboard
                            // It is also available in 'share' option
                            UIPasteboard.general.string = getEventHighlight(for: event)!
                            eventForSheet = nil
                        }
                    }
                    if canReact {
                        SheetActionView(title: "Add Reaction", imageName: "smile-solid") {
                            eventToReactId = id
                            eventForSheet = nil
                        }
                    }
                    if canQuote {
                        SheetActionView(title: "Quote", imageName: "align-left-solid") {
                            // Use reply option for now, quote is the same,
                            // but formats text without sender name
                            let message = getEventHighlight(for: event)!
                            inputVM.inputType = .reply(eventId: id, highlight: .text(message))
                            eventForSheet = nil
                        }
                    }
                    if canShare {
                        SheetActionView(title: "Share", imageName: "share-alt-square-solid") {
                            if isMediaMessage {
                                let checkEvent = eventForSheet!
                                let attachment = ChatMediaAttachment(event: checkEvent)
                                attachment.prepareShare { fileURL in
                                    guard checkEvent.eventId == attachment.event.eventId else { return }
                                    if let url = fileURL {
                                        shareActivities = [url as AnyObject]
                                        showShare = true
                                    }
                                }
                            } else {
                                let text = ChatTextMessageView.Model(event: event).message
                                shareActivities = [text as AnyObject]
                                showShare = true
                            }
                            eventForSheet = nil
                        }
                    }
//                    if canSave {
//                        SheetActionView(title: "Save", imageName: "download-solid") {
//                            // Do we need this? Share has this option
//                        }
//                    }
//                    if canLink {
//                        SheetActionView(title: "Permalink", imageName: "link-solid") {
//                            // Do not implement for now
//                        }
//                    }
                    // Basic option
                    if canReport {
                        SheetActionView(title: "Report Content", imageName: "flag-solid") {
                            reportEvent = event
                            withAnimation { showingReportAlert = true }
                            eventForSheet = nil
                        }
                    }
                    // Fancy custom options
//                    if canReport {
//                        SheetReportView(
//                            showOptions: $showReportOptions,
//                            reportSpam: { },
//                            reportInappropriate: { },
//                            reportCustom: { }
//                        )
//                    }
                    if canIgnore {
                        SheetActionView(title: "Ignore User", imageName: "exclamation-triangle-solid") {
                            ignoreUserId = event.sender
                            withAnimation { showingIgnoreAlert = true }
                            eventForSheet = nil
                        }
                        .foregroundColor(.red)
                    }
                }
                .foregroundColor(.gray)
            } else {
                // Should never happen, right?
                EmptyView().onAppear { eventForSheet = nil }
            }
        }
        .padding(.bottom)
        .onDisappear {
            eventForSheet = nil
            showReportOptions = false
        }
    }
    
//    private func message(from event: MXEvent) -> String {
//        var message: String? = event.type
//        switch event.eventType {
//        case .roomMessage:
//            message = try? MessageViewModel(event: event, reactions: [], showSender: false).text
//        case .roomMember:
//            message = ChatRoomMemberEventView.Model(avatar: nil, sender: nil, event: event).text
//        case .roomTopic:
//            message = ChatRoomTopicEventView.Model(avatar: nil, sender: nil, event: event).text
//        case .roomName:
//            message = ChatRoomNameEventView.Model(avatar: nil, sender: nil, event: event).text
//        default:
//            break
//        }
//        return message ?? "nil"
//    }
    
    // MARK: - Reporting
    
    @State private var showingReportAlert = false
    @State private var reportEvent: MXEvent?
    @State private var reportReason = ""
    @State private var reportConfirmed = false
    @State private var cancellables = Set<AnyCancellable>()
    
    private var reportAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingReportAlert) {
            TextInputAlertView(title: "Report Content", subtitle: nil, textInput: $reportReason, inputPlaceholder: "Reason for reporting this content", success: $reportConfirmed, shown: $showingReportAlert)
                .onDisappear() {
                    // Continue only when confirmed
                    guard reportConfirmed else {
                        reportEvent = nil
                        reportReason = ""
                        reportConfirmed = false
                        return
                    }
                    // Ensure we have all needed data
                    guard let event = reportEvent,
                          let access = AuthViewModel.shared.session?.credentials.accessToken
                    else {
                        reportEvent = nil
                        reportReason = ""
                        reportConfirmed = false
                        return
                    }
                    let reason = reportReason.hasContent ? reportReason : nil
                    let admins = membersVM.filteredMembers
                        .filter { $0.powerLevel == .admin }
                        .map { $0.id }
                    // Trigger the report
                    loaderInfo = "Reporting content..."
                    withAnimation { showingLoader = true }
                    reportEvent = nil
                    reportReason = ""
                    reportConfirmed = false
                    ApiManager.shared.reportEvent(event, score: -100, reason: reason, admins: admins, accessToken: access)
                        .sink(receiveValue: { success in
                            showingLoader = false
                        })
                        .store(in: &cancellables)
                }
        }
    }
    
    // MARK: - Ignoring
    
    @State private var showingIgnoreAlert = false
    @State private var ignoreUserId: String?
    
    private var ignoreAlert: some View {
        ActionAlert(showAlert: $showingIgnoreAlert, title: "Ignore User", text: "Ignoring this user will remove their messages from all chats and clubs you share. You can reverse this action at any time in the general settings.", actionTitle: "Ignore") {
            guard let id = ignoreUserId else { return }
            loaderInfo = "Ignoring user"
            withAnimation { showingLoader = true }
            ignoreUserId = nil
            IgnoringUsersViewModel.shared.ignoreUser(userId: id) { response in
                withAnimation { showingLoader = false }
                switch response {
                case .success:
                    successHint = "Successfully ignored \(membersVM.member(with: id)?.displayname ?? "user")."
                    withAnimation { showingSuccess = true }
                case .failure(let error):
                    failureHint = "Failed to ignore user.\n\(error.localizedDescription)"
                    withAnimation { showingFailure = true }
                }
                IgnoringUsersViewModel.shared.getIgnoredUsersList()
            }
        }
    }
    
    // MARK: - Loader
    
    @State private var showingLoader = false
    @State private var loaderInfo: String?
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showingLoader)
        }
    }
    
    // MARK: - Success Alert
    
    @State private var showingSuccess = false
    @State private var successHint: String?
    
    private var successAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingSuccess) {
            InfoAlertView(title: "Success", subtitle: successHint, shown: $showingSuccess)
        }
    }
    
    // MARK: - Failure Alert
    
    @State private var showingFailure = false
    @State private var failureHint: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: failureHint, shown: $showingFailure)
        }
    }
}

extension MXEvent {
    /// Returns message type if possible, for other events will return `nil`
    var messageType: MXMessageType? {
        guard let typeString = self.content?["msgtype"] as? String else { return nil }
        return MXMessageType(identifier: typeString)
    }
}
