//
//  ChatRoomTopicEventView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

/// Handles room topic type events to provide valid text to `ChatSystemEventView`
struct ChatRoomTopicEventView: View {
    let model: Model

    var body: some View {
        ChatSystemEventView(avatarURL: model.avatar, displayname: model.sender, text: model.text)
    }
    
    struct Model {
        // Sender data
        let avatar: URL?
        let sender: String
        // Event data
        let topic: String
        let oldTopic: String?

        init(avatar: URL?, sender: String, topic: String, oldTopic: String?) {
            self.avatar = avatar
            self.sender = sender
            self.topic = topic
            self.oldTopic = oldTopic
        }

        init(avatar: URL?, sender: String?, event: MXEvent) {
            self.avatar = avatar
            self.sender = sender ?? event.sender.dropAllgramSuffix
            self.topic = event.content(valueFor: "topic") ?? "Unknown"
            self.oldTopic = event.prevContent(valueFor: "topic")
        }
        
        var text: String {
            return "\(sender) changed the topic to '\(topic)'"
//            if let old = oldTopic {
//                return "\(sender) changed the room topic from '\(old)' to '\(topic)'"
//            } else {
//                return "\(sender) changed the topic to '\(topic)'"
//            }
        }
    }
}
