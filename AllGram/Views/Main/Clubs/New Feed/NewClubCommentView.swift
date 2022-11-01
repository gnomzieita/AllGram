//
//  NewClubCommentView.swift
//  AllGram
//
//  Created by Alex Pirog on 22.09.2022.
//

import SwiftUI

struct NewClubCommentView: View {
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    @StateObject var attachment: ChatMediaAttachment
    
    let comment: NewClubComment
    let replyToComment: NewClubComment?
    let sendByMe: Bool
    let maxWidth: CGFloat
    let reactionTapHandler: (ReactionGroup) -> Void
    
    private let mediaWidth: CGFloat
    private let mediaHeight: CGFloat
    
    init(comment: NewClubComment,
         replyToComment: NewClubComment?,
         maxWidth: CGFloat,
         reactionTapHandler: @escaping (ReactionGroup) -> Void
    ) {
        self.comment = comment
        self.replyToComment = replyToComment
        self.sendByMe = comment.commentEvent.sender == AuthViewModel.shared.sessionVM?.myUserId
        self.maxWidth = maxWidth
        self.reactionTapHandler = reactionTapHandler
        self._attachment = StateObject(wrappedValue: ChatMediaAttachment(event: comment.commentEvent))
        
        // Handle size
        let mediaSize = comment.commentEvent.mediaSize
        self.mediaWidth = maxWidth
        self.mediaHeight = maxWidth / (mediaSize?.aspectRatio ?? 1)
    }
    
    private var textFrontColor: Color {
        .black//sendByMe ? .backColor : .reverseColor
    }
    
    private var textBackColor: Color {
        sendByMe ? .postMyCommentBackground : .postOtherCommentBackground
    }
    
    private var eventSendTime: String {
        let time = comment.commentEvent.timestamp
        var dateFormat : DateFormatter.Style = .none
        if time < Calendar.current.startOfDay(for: Date()) {
            dateFormat = .short
        }
        return Formatter.string(for: time, dateStyle: dateFormat, timeStyle: .short)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            supportingTextContainer(for: comment.commentEvent.sender.dropAllgramSuffix)
            VStack(alignment: .leading, spacing: 0) {
                replyView
                messageView
            }
            .background(
                RoundedRectangle(cornerRadius: 8).foregroundColor(textBackColor)
            )
            if !comment.reactions.isEmpty {
                ReactionGridView(
                    reactions: comment.reactions,
                    widthLimit: UIScreen.main.bounds.width - 24,
                    alignment: .leading,
                    textColor: .reverseColor,
                    backColor: .accentColor,
                    userColor: .accentColor
                ) { group in
                    reactionTapHandler(group)
                }
                    .padding(.vertical, 6)
            }
            supportingTextContainer(for: eventSendTime)
        }
    }
    
    @ViewBuilder
    private func supportingTextContainer(for content: String) -> some View {
        Text(content)
            .font(.footnote)
            .foregroundColor(.gray)
            .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var messageView: some View {
        switch comment.commentEvent.messageType! {
        case .text:
            Text(ChatTextMessageView.Model.init(event: comment.commentEvent).message)
                .foregroundColor(textFrontColor)
                .padding(.all, 8)
            
        case .image:
            if let data = attachment.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(width: mediaWidth, height: mediaHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
                    .frame(width: mediaWidth, height: mediaHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
        case .video:
            if let data = attachment.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .overlay(PlayImageOverlay())
                    .frame(width: mediaWidth, height: mediaHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
                    .frame(width: mediaWidth, height: mediaHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
        case .audio:
            if comment.commentEvent.isVoiceMessage() {
                let model = ChatVoiceMessageView.Model.init(attachment: attachment)
                HStack(spacing: 0) {
                    // Play button
                    Button {
                        if isPlaying {
                            voicePlayer.pause()
                        } else {
                            voicePlayer.play(attachment.voiceData!, named: attachment.mediaName!, title: voiceTitle)
                        }
                    } label: {
                        Image(isPlaying ? "pause-solid" : "play-solid")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .foregroundColor(.gray)
                            .padding(6)
                            .opacity(attachment.isReady ? 1 : 0)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(
                                Spinner(.gray)
                                    .opacity(attachment.isReady ? 0 : 1)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .padding(6)
                    .disabled(!attachment.isReady)
                    // Time (keep width for maximum possible space)
                    Text(model.duration > 3600 ? "00:00:00" : "00:00")
                        .opacity(0)
                        .overlay(
                            Text(time.durationText)
                                .foregroundColor(.gray)
                        )
                    // Waveform
                    if let wave = model.waveform {
                        Image(uiImage: wave)
                            .resizable()
                            .frame(width: wave.size.width, height: wave.size.height)
                            .padding(.horizontal, 6)
                    } else {
                        RoundedRectangle(cornerRadius: 1)
                            .foregroundColor(.gray)
                            .frame(width: 60, height: 2)
                            .padding(.horizontal, 6)
                    }
                }
            } else {
                NewFeedMediaPlaceholder(isBusy: false)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
        case .file:
            NewFeedMediaPlaceholder(isBusy: false)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
        default:
            Text("Unhandled message type")
                .foregroundColor(.gray)
                .padding(.all, 8)
        }
    }
    
    @ViewBuilder
    private var replyView: some View {
        if comment.isReplyToComment {
            HStack(spacing: 8) {
                Rectangle()
                    .frame(width: 2)
                    .foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 0) {
                    let textModel = ChatTextMessageView.Model.init(event: comment.commentEvent)
                    Text(verbatim: textModel.replyToUser ?? "Unknown").italic()
                        .foregroundColor(textFrontColor)
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Text(verbatim: textModel.replyToText ?? "Comment").italic()
                        .lineLimit(1)
                        .foregroundColor(textFrontColor)
                }
            }
            .padding([.top, .horizontal], 8)
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Voice
    
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    var voiceTitle: String {
        let senderName = membersVM.member(with: comment.commentEvent.sender)?.member.displayname ?? comment.commentEvent.sender.dropAllgramSuffix
        let sendTime = Formatter.string(for: comment.commentEvent.timestamp, format: .voice)
        return "\(senderName) at \(sendTime)"
    }
    
    /// `true` if voice player current item matches this voice message data
    var isPlayerItem: Bool {
        if let itemName = attachment.mediaName, let playerName = voicePlayer.currentURL?.lastPathComponent {
            return itemName == playerName
        }
        return false
    }
    
    /// Checks voice player only when needed, otherwise returns `false`
    var isPlaying: Bool {
        guard attachment.isReady && isPlayerItem else { return false }
        return voicePlayer.isPlaying
    }
    
    /// Takes either voice player current time or voice message duration
    var time: TimeInterval {
        let duration = ChatVoiceMessageView.Model(attachment: attachment).duration
        if isPlayerItem && voicePlayer.currentTime > .zero {
            return min(duration, voicePlayer.roundedTime)
        } else {
            return duration
        }
    }
}

extension NewClubCommentView: Equatable {
    static func == (lhs: NewClubCommentView, rhs: NewClubCommentView) -> Bool {
        lhs.comment == rhs.comment
    }
}
