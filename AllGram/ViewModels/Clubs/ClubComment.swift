//
//  ClubComment.swift
//  AllGram
//
//  Created by Alex Pirog on 28.02.2022.
//

import Foundation
import Combine
import MatrixSDK

/// Interpreted post comment (message) from room events
struct ClubComment: Identifiable {
    
    /// Main comment event
    let commentEvent: MXEvent
    
    /// Main MXEvent id
    var id: String { commentEvent.eventId }
    
    /// Content of the post
    let commentMedia: CommentMediaType
    
    /// Aspect ration of the media content
    var mediaAspectRatio: CGFloat {
        switch commentMedia {
        case .text:
            return 1.0
        case .image(let info):
            return info.aspectRatio
        case .video(let info):
            return info.aspectRatio
        case .voice:
            return 1.0
        }
    }
    
    /// Short text representing media for reply/edit comment
    var mediaShortText: String {
        switch commentMedia {
        case .text(let text):
            return text
        case .image(let info):
            return info.type
        case .video(let info):
            return info.type
        case .voice(let info):
            return info.type
        }
    }
    
    /// Sender of the other comment that this one is a reply to
    var replyToSender: String?
    
    /// Media of the other comment that this one is a reply to
    var replyToMedia: CommentMediaType?
    
    /// Reactions for this comment
    var reactions = [Reaction]()
    
    init(
        commentEvent: MXEvent,
        commentMedia: CommentMediaType,
        replyToSender: String? = nil,
        replyToMedia: CommentMediaType? = nil,
        reactions: [Reaction] = [Reaction]()
    ) {
        self.commentEvent = commentEvent
        self.commentMedia = commentMedia
        self.replyToSender = replyToSender
        self.replyToMedia = replyToMedia
        self.reactions = reactions
    }
    
}

/// Comments can be text, image, video, voice, audio or file
enum CommentMediaType {
    /// Only text
    case text(_ text: String)
    /// Image message
    case image(_ info: ImageInfo)
    /// Video message
    case video(_ info: VideoInfo)
    /// Voice message
    case voice(_ info: VoiceInfo)
}

extension ClubComment: Equatable {
    static func == (lhs: ClubComment, rhs: ClubComment) -> Bool {
        return lhs.id == rhs.id && lhs.reactions == rhs.reactions
    }
}
