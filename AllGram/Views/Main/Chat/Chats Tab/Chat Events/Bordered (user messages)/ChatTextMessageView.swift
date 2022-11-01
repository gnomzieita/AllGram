//
//  ChatTextMessageView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

struct ChatTextMessageView: View {
    let model: Model
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let replyToText = model.replyToText, let replyToUser = model.replyToUser {
                HStack(spacing: 0) {
                    Rectangle()
                        .foregroundColor(.gray)
                        .frame(width: 2, height: 30)
                        .clipShape(Capsule())
                        .padding(.trailing, 8)
                    VStack(alignment: .leading) {
                        Text(verbatim: replyToUser)
                            .bold()
                        Text(verbatim: replyToText)
                            .italic()
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.black)
                }
            }
            TextWithMention(model.message)
                .foregroundColor(.black)
        }
    }
    
    struct Model {
        let message: String
        let replyToText: String?
        let replyToUser: String?
        
        init(message: String, replyToText: String?, replyToUser: String?) {
            self.message = message
            self.replyToText = replyToText
            self.replyToUser = replyToUser
        }

        init(event: MXEvent) {
            if event.isEdit() {
                // Edit event -> use new content
                let newContent = event.content["m.new_content"]! as? NSDictionary
                self.message = (newContent?["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Error: edit expects string body"
                self.replyToText = nil
                self.replyToUser = nil
            } else if event.isReply() {
                // Reply event -> show reply
                if let body = (event.content["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let username = Formatter.usernameFromString(body)
                    if let (quoteMessage, message) = Formatter.extractMessagesFromString(body) {
                        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.replyToUser = "\(username):"
                        self.replyToText = "\(quoteMessage.trimmingCharacters(in: .whitespacesAndNewlines))"
                    } else {
                        self.message = body
                        self.replyToUser = "\(username):"
                        self.replyToText = "Failed to get quote"
                    }
                } else {
                    self.message = "Error: reply expects string body"
                    self.replyToText = nil
                    self.replyToUser = nil
                }
            } else {
                // Regular message -> use body text
                self.message = (event.content["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Error: expects string body"
                self.replyToText = nil
                self.replyToUser = nil
            }
        }
    }
}
