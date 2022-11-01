//
//  ClubPostCommentView.swift
//  AllGram
//
//  Created by Alex Pirog on 02.03.2022.
//

import SwiftUI
import Kingfisher
import MatrixSDK

struct ClubPostCommentView: View {
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    @StateObject var attachment: CommentMediaAttachment
    
    let comment: ClubComment
    let sendByMe: Bool
    let maxWidth: CGFloat
    let reactionTapHandler: (ReactionGroup) -> Void
    
    init(comment: ClubComment,
         sendByMe: Bool,
         maxWidth: CGFloat,
         reactionTapHandler: @escaping (ReactionGroup) -> Void
    ) {
        self.comment = comment
        self.sendByMe = sendByMe
        self.maxWidth = maxWidth
        self.reactionTapHandler = reactionTapHandler
        // TODO: Do not download other media except voice
        self._attachment = StateObject(wrappedValue: CommentMediaAttachment(comment: comment))
    }
    
    private var postWidth: CGFloat {
        return maxWidth
    }
    
    private var postHeight: CGFloat {
        let width = postWidth
        return width / comment.mediaAspectRatio
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
                if let reply = comment.replyToMedia, let who = comment.replyToSender {
                    replyToMediaContainer(for: reply, sender: who.dropAllgramSuffix)
                }
                commentMediaContainer(for: comment.commentMedia)
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
    private func commentMediaContainer(for content: CommentMediaType) -> some View {
        switch content {
        case .text(let text):
            Text(text)
                .foregroundColor(textFrontColor)
                .padding(.all, 8)
        case .image(let info):
            if info.isEncrypted {
                EncryptedClubPlaceholder(text: "Image")
                    .frame(width: postWidth, height: postHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                KFImage(info.url)
                    .resizable().scaledToFit()
                    .placeholder(when: true, alignment: .center) {
                        ProgressView()
                            .scaleEffect(2.0)
                    }
                    .frame(width: postWidth, height: postHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        case .video(let info):
            if info.isEncrypted {
                EncryptedClubPlaceholder(text: "Video")
                    .frame(width: postWidth, height: postHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                KFImage(info.thumbnail.url)
                    .resizable().scaledToFit()
                    .placeholder(when: true, alignment: .center) {
                        ProgressView()
                            .scaleEffect(2.0)
                    }
                    .frame(width: postWidth, height: postHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(PlayImageOverlay())
            }
        case .voice(let info):
            HStack(spacing: 0) {
                // Play button
                Button {
                    if isPlaying {
                        voicePlayer.pause()
                    } else {
                        voicePlayer.play(attachment.voiceData!, named: info.name!, title: voiceTitle)
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
                // Time (keep width for maximum possible space)
                Text(info.duration > 3600 ? "00:00:00" : "00:00")
                    .opacity(0)
                    .overlay(
                        Text(info.duration.durationText)
                            .foregroundColor(.gray)
                    )
                // Waveform
                if let wave = info.waveform {
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
        }
    }
    
    @ViewBuilder
    private func replyToMediaContainer(for content: CommentMediaType, sender: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .frame(width: 2)
                .foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 0) {
                Text(sender).italic()
                    .foregroundColor(textFrontColor)
                    .font(.footnote)
                    .foregroundColor(.gray)
                switch content {
                case .text(let text):
                    Text(text).italic()
                        .lineLimit(1)
                        .foregroundColor(textFrontColor)
                case .image(let info):
                    KFImage(info.url)
                        .resizable().scaledToFit()
                        .frame(width: Constants.replyContentSize)
                        .frame(height: Constants.replyContentSize)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.vertical, 4)
                case .video(let info):
                    KFImage(info.thumbnail.url)
                        .resizable().scaledToFit()
                        .frame(width: Constants.replyContentSize)
                        .frame(height: Constants.replyContentSize)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.vertical, 4)
                        .overlay(PlayImageOverlay(size: Constants.replyContentSize / 2))
                case .voice(_):
                    Text("voice message").italic()
                        .lineLimit(1)
                        .foregroundColor(textFrontColor)
                }
            }
        }
        .padding([.top, .horizontal], 8)
    }
    
    // MARK: - Voice
    
    var voiceInfo: VoiceInfo? {
        if case .voice(let info) = comment.commentMedia {
            return info
        }
        return nil
    }
    
    var voiceTitle: String {
        let senderName = membersVM.member(with: comment.commentEvent.sender)?.member.displayname ?? comment.commentEvent.sender.dropAllgramSuffix
        let sendTime = Formatter.string(for: comment.commentEvent.timestamp, format: .voice)
        return "\(senderName) at \(sendTime)"
    }
    
    /// `true` if voice player current item matches this voice message data
    var isPlayerItem: Bool {
        if let itemName = voiceInfo?.name, let playerName = voicePlayer.currentURL?.lastPathComponent {
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
        if isPlayerItem && voicePlayer.currentTime > .zero {
            return min(voiceInfo!.duration, voicePlayer.roundedTime)
        } else {
            return voiceInfo!.duration
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let replyContentSize: CGFloat = 40
    }
}

extension ClubPostCommentView: Equatable {
    static func == (lhs: ClubPostCommentView, rhs: ClubPostCommentView) -> Bool {
        return lhs.sendByMe == rhs.sendByMe && lhs.maxWidth == rhs.maxWidth && lhs.comment.id == rhs.comment.id &&  lhs.comment.reactions.map({ $0.id }) == rhs.comment.reactions.map({ $0.id })
    }
}

class CommentMediaAttachment: ObservableObject {
    @Published private(set) var voiceAttachment: ChatMediaAttachment?
    
    var isReady: Bool { voiceAttachment?.isReady ?? true }
    var voiceData: Data? { voiceAttachment?.voiceData }
    
    let comment: ClubComment
    
    init(comment: ClubComment) {
        self.comment = comment
        // Only download voice data
        if comment.commentEvent.isVoiceMessage() {
            self.voiceAttachment = ChatMediaAttachment(event: comment.commentEvent)
        }
    }
}
