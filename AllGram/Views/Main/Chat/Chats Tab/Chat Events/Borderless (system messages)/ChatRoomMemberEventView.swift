//
//  ChatRoomMemberEventView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

/// Handles room member type events to provide valid text to `ChatSystemEventView`
struct ChatRoomMemberEventView: View {
    var model: Model

    var body: some View {
        if model.isMembershipChange {
            ChatSystemEventView(avatarURL: model.avatar, displayname: model.sender, text: model.text)
        } else {
            EmptyView()
        }
    }
    
    struct Model {
        // Sender data
        let avatar: URL?
        let sender: String
        // Event data
        let current: User
        let previous: User?

        struct User {
            let displayName: String
            let avatarURI: String?
            let membership: String
        }

        init(avatar: URL?, sender: String, current: User, previous: User?) {
            self.avatar = avatar
            self.sender = sender
            self.current = current
            self.previous = previous
        }

        init(avatar: URL?, sender: String?, event: MXEvent) {
            self.avatar = avatar
            self.sender = sender ?? event.sender.dropAllgramSuffix
            self.current = User(
                displayName: event.content(valueFor: "displayname") ?? event.sender,
                avatarURI: event.content(valueFor: "avatar_url"),
                membership: event.content(valueFor: "membership") ?? "nil"
            )
            if let prevDisplayname: String = event.prevContent(valueFor: "displayname"),
               let prevAvatarURI: String? = event.prevContent(valueFor: "avatar_url"),
               let prevMembership: String = event.prevContent(valueFor: "membership")
            {
                self.previous = User(
                    displayName: prevDisplayname,
                    avatarURI: prevAvatarURI,
                    membership: prevMembership
                )
            } else {
                self.previous = nil
            }
        }
        
        /// `true` only when this event is for changing user profile data (avatar or display name)
        var isUserProfileChange: Bool {
            if current.membership == "join", let previous = previous {
                return current.displayName != previous.displayName
                || current.avatarURI != previous.avatarURI
            }
            return false
        }
        
        /// `true` only when this event is for changing user membership
        var isMembershipChange: Bool {
            switch current.membership {
            case "invite", "leave", "ban", "knock":
                return true
            case "join":
                return !isUserProfileChange
            default:
                return false
            }
        }

        var text: String {
            // One of: ["invite", "join", "knock", "leave", "ban"]
            switch current.membership {
            case "invite":
                return "\(sender) invited \(current.displayName)"
            case "leave":
                return "\(sender) left"
            case "ban":
                return "\(sender) banned \(current.displayName)"
            case "knock":
                return "\(sender) kicked \(current.displayName)"
            case "join":
                if let previous = previous {
                    if current.displayName != previous.displayName {
                        return "\(sender) changed their display name"
//                        return "\(sender) changed their display name from '\(previous.displayName)' to '\(current.displayName)'"
                    }
                    if current.avatarURI != previous.avatarURI {
                        // TODO: Handle various cases if needed
                        // cases: nil -> URI or URI -> URI or URI -> nil
                        return "\(sender) changed their avatar"
                    }
                    if previous.membership == "invite" {
                        // Do we need it?
                        return "\(sender) joined"
                    } else {
                        // What to expect here?
                    }
                } else {
                    return "\(sender) joined"
                }
            default:
                break
            }
            return "Unknown state event for \(sender) | \(current.membership)"
        }
    }
}
