//
//  ChatRedactionEventView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

/// Handles redacted (deleted) events to provide valid text to `ChatSystemEventView`
struct ChatRedactionEventView: View {
    let model: Model
    
    var body: some View {
        ChatSystemEventView(avatarURL: model.avatar, displayname: model.sender, text: model.text)
    }
    
    struct Model {
        // Sender data
        let avatar: URL?
        let sender: String
        // Event data
        let redactor: String
        let reason: String?
        
        init(avatar: URL?, sender: String, redactor: String, reason: String?) {
            self.avatar = avatar
            self.sender = sender
            self.redactor = redactor
            self.reason = reason
        }
        
        init(avatar: URL?, sender: String?, event: MXEvent) {
            self.avatar = avatar
            self.sender = sender ?? event.sender.dropAllgramSuffix
            self.redactor = (event.redactedBecause["sender"] as? String ?? "Unknown").dropAllgramSuffix
            self.reason = (event.redactedBecause["content"] as? [AnyHashable: Any])?["body"] as? String
        }
        
        var text: String {
            if sender == redactor {
                return "Message removed by \(sender)" + safeReason
            } else {
                return "\(sender) removed \(redactor)'s message" + safeReason
            }
        }
        
        private var safeReason: String {
            guard let reason = reason else { return "" }
            return "\nReason: \(reason)"
        }
    }
}
