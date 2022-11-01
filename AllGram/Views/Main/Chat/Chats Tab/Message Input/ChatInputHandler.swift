//
//  ChatInputHandler.swift
//  AllGram
//
//  Created by Alex Pirog on 13.06.2022.
//

import SwiftUI

/// Handles sending messages in chat room
class ChatInputHandler: MessageInputViewModelDelegate {
    let room: AllgramRoom
    var clearHandler: (() -> Void)?
    
    init(room: AllgramRoom, clearHandler: (() -> Void)? = nil) {
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
            room.send(text: text) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        case .edit(let id, _):
            room.edit(text: text, eventId: id)
        case .reply(let id, _):
            room.sendReplyToEvent(withId: id, withTextMessage: text) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        }
    }
    
    func sendImageMessage(_ image: UIImage, inputType: MessageInputType) {
        switch inputType {
        case .new, .edit:
            // Not possible to edit image messages -> just send
            room.sendImage(image: image) { success in
                if success {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        case .reply(let id, _):
            room.reply(to: id, with: image, named: nil) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        }
    }
    
    func sendVideoMessage(_ url: URL, thumbnail: UIImage, inputType: MessageInputType) {
        switch inputType {
        case .new, .edit:
            // Not possible to edit image messages -> just send
            room.sendVideo(url: url, thumbnail: thumbnail) { success in
                if success {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        case .reply(let id, _):
            room.reply(to: id, with: url, thumbnail: thumbnail) { messageId in
                if messageId != nil {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        }
    }
    
    func sendVoiceMessage(_ url: URL, duration: Int, samples: [Float]?, inputType: MessageInputType) {
        // We need to copy file for some reason to send voice message
        // Probably due to encryption messing up temp file...
        let tempURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("temp_\(url.lastPathComponent)")
        try? FileManager.default.copyItem(at: url, to: tempURL)
        // Try to send only when we have copied something
        if FileManager.default.fileExists(atPath: tempURL.path) {
            room.sendVoiceMessage(
                didRequestSendForFileAtURL: tempURL,
                duration: duration,
                samples: samples
            ) { result in
                // Clear temp file either way
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }
    
    func sendAudioMessage(_ url: URL, inputType: MessageInputType) {
        switch inputType {
        case .new, .edit:
            room.sendAudio(url: url) { success in
                if success {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        case .reply:
            // TODO: Implement reply with audio message
            break
        }
    }
    
    func sendFileMessage(_ url: URL, inputType: MessageInputType) {
        switch inputType {
        case .new, .edit:
            room.sendFile(localURL: url) { success in
                if success {
                    NotificationCenter.default.post(name: .userSendMessage, object: nil)
                }
            }
        case .reply:
            // TODO: Implement reply with file message
            break
        }
    }
    
    func sendEmptyMessage(inputType: MessageInputType) {
        // No allowed here
    }
}

extension ChatInputHandler: Equatable {
    static func == (lhs: ChatInputHandler, rhs: ChatInputHandler) -> Bool {
        lhs.room.roomId == rhs.room.roomId
    }
}
