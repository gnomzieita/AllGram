//
//  ChatCallEventView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

/// Handles call type events to provide valid text to `ChatSystemEventView`
struct ChatCallEventView: View {
    let model: Model
    
    var body: some View {
        ChatSystemEventView(avatarURL: model.avatar, displayname: model.sender, text: model.text)
    }
    
    enum CallEventType {
        case unknown(String)
        case invite(Date)
        case answer(Date)
        case reject(Date)
        case hangup(TimeInterval?)
    }
    
    struct Model {
        // Sender data
        let avatar: URL?
        let sender: String
        // Event data
        let callType: CallEventType
        
        init(avatar: URL?, sender: String, callType: CallEventType) {
            self.avatar = avatar
            self.sender = sender
            self.callType = callType
        }
        
        init(avatar: URL?, sender: String?, event: MXEvent) {
            self.avatar = avatar
            self.sender = sender ?? event.sender.dropAllgramSuffix
            switch event.eventType {
            case .callInvite:
                self.callType = .invite(event.timestamp)
            case .callAnswer:
                self.callType = .answer(event.timestamp)
            case .callReject:
                self.callType = .reject(event.timestamp)
            case .callHangup:
                let duration = durationOfCall(event)
                self.callType = .hangup(duration)
            default:
                self.callType = .unknown(event.type ?? "nil")
            }
        }
        
        var text: String {
            switch callType {
            case .unknown(let string):
                return "Unknown call event: \(string)"
            case .invite(let date):
                return "Initiated call at \(callTime(at: date))"
            case .answer(let date):
                return "Answered call at \(callTime(at: date))"
            case .reject(let date):
                return "Rejected call at \(callTime(at: date))"
            case .hangup(let timeInterval):
                return "Call lasted for \(callDuration(timeInterval))"
            }
        }
        
        private func callTime(at date: Date) -> String {
            let style = date < Calendar.current.startOfDay(for: Date())
            ? DateFormatter.Style.short
            : DateFormatter.Style.none
            return Formatter.string(for: date, dateStyle: style, timeStyle: .short)
        }
        
        private func callDuration(_ duration: TimeInterval?) -> String {
            guard let duration = duration else {
                return "still active"
            }
            let t = Int(duration)
            let seconds = t % 60
            let minutes = (t / 60) % 60
            let hours = t / 3600
            if hours > 0 {
                return "\(hours) hours and \(minutes) minutes"
            } else if minutes > 9 {
                return "\(minutes) minutes"
            } else if minutes > 0 {
                return "\(minutes) minutes and \(seconds) seconds"
            } else {
                return "\(seconds) seconds"
            }
        }
    }
}
