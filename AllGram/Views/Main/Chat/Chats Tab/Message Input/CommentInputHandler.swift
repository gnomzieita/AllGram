//
//  CommentInputHandler.swift
//  AllGram
//
//  Created by Alex Pirog on 13.06.2022.
//

import SwiftUI

class CommentInputHandler: MessageInputViewModelDelegate {
    let postId: String
    let room: AllgramRoom
    var clearHandler: (() -> Void)?
    
    init(postId: String, room: AllgramRoom, clearHandler: (() -> Void)? = nil) {
        self.postId = postId
        self.room = room
        self.clearHandler = clearHandler
    }
    
    // MARK: - Input Delegate
    
    func clearHighlight() {
        clearHandler?()
    }
    
    func sendTextMessage(_ text: String, inputType: MessageInputType) {
        switch inputType {
        case .new:
            // New comment is a reply to post event
            room.sendReplyToEvent(withId: postId, withTextMessage: text) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                }
            }
        case .edit(let id, _):
            room.edit(text: text, eventId: id)
        case .reply(let id, _):
            room.sendReplyToEvent(withId: id, withTextMessage: text) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                }
            }
        }
    }
    
    func sendImageMessage(_ image: UIImage, inputType: MessageInputType) {
        switch inputType {
        case .new, .edit:
            // New comment is a reply to post event
            room.reply(to: postId, with: image, named: nil) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                }
            }
        case .reply(let id, _):
            room.reply(to: id, with: image, named: nil) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                }
            }
        }
    }
    
    func sendVideoMessage(_ url: URL, thumbnail: UIImage, inputType: MessageInputType) {
        switch inputType {
        case .new, .edit:
            // New comment is a reply to post event
            room.reply(to: postId, with: url, thumbnail: thumbnail) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                }
            }
        case .reply(let id, _):
            room.reply(to: id, with: url, thumbnail: thumbnail) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                }
            }
        }
    }
    
    func sendVoiceMessage(_ url: URL, duration: Int, samples: [Float]?, inputType: MessageInputType) {
        guard let samples = samples else { return }
        // We need to copy file for some reason to send voice message
        // Probably due to encryption messing up temp file...
        let tempURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("temp_\(url.lastPathComponent)")
        try? FileManager.default.copyItem(at: url, to: tempURL)
        // Try to send only when we have copied something
        if FileManager.default.fileExists(atPath: tempURL.path) {
//            room.sendVoiceMessage(
//                didRequestSendForFileAtURL: tempURL,
//                duration: duration,
//                samples: samples
//            ) { result in
//                // Clear temp file either way
//                try? FileManager.default.removeItem(at: tempURL)
//            }
            switch inputType {
            case .new, .edit:
                // New comment is a reply to post event
                room.reply(to: postId, with: url, samples: samples, duration: duration) { messageId in
                    if messageId != nil {
                        NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                    }
                }
            case .reply(let id, _):
                room.reply(to: id, with: url, samples: samples, duration: duration) { messageId in
                    if messageId != nil {
                        NotificationCenter.default.post(name: .userCommentedPost, object: nil)
                    }
                }
            }
        }
    }

    func sendAudioMessage(_ url: URL, inputType: MessageInputType) {
        // TODO: Implement replying with audio messages
    }

    func sendFileMessage(_ url: URL, inputType: MessageInputType) {
        // TODO: Implement replying with file messages
    }

    func sendEmptyMessage(inputType: MessageInputType) {
        // No allowed here
    }
}

extension CommentInputHandler: Equatable {
    static func == (lhs: CommentInputHandler, rhs: CommentInputHandler) -> Bool {
        lhs.room.roomId == rhs.room.roomId
    }
}

