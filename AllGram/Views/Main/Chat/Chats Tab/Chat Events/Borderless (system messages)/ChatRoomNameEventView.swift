//
//  ChatRoomNameEventView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

/// Handles room name type events to provide valid text to `ChatSystemEventView`
struct ChatRoomNameEventView: View {
    let model: Model

    var body: some View {
        ChatSystemEventView(avatarURL: model.avatar, displayname: model.sender, text: model.text)
    }
    
    struct Model {
        // Sender data
        let avatar: URL?
        let sender: String
        // Event data
        let name: String
        let oldName: String?
        
        init(avatar: URL?, sender: String, name: String, oldName: String?) {
            self.avatar = avatar
            self.sender = sender
            self.name = name
            self.oldName = oldName
        }

        init(avatar: URL?, sender: String?, event: MXEvent) {
            self.avatar = avatar
            self.sender = sender ?? event.sender.dropAllgramSuffix
            self.name = event.content(valueFor: "name") ?? "Unknown"
            self.oldName = event.prevContent(valueFor: "name")
        }
        
        var text: String {
            return "\(sender) set the room to '\(name)'"
//            if let old = oldName {
//                return "\(sender) changed the room name from '\(old)' to '\(name)'"
//            } else {
//                return "\(sender) set the room to '\(name)'"
//            }
        }
    }
}
