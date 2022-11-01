//
//  EventContainerWrapper.swift
//  AllGram
//
//  Created by Alex Pirog on 08.04.2022.
//

import SwiftUI
import MatrixSDK

class ChatEventsBreakdownManager {
    
    func shouldAddDateView(for event: MXEvent, in collection: [MXEvent]) -> Date? {
        // Check only events from a given collection
        guard let index = collection.firstIndex(of: event) else { return nil }
        // Exclude hidden events (changed avatar/name)
        if event.eventType == .roomMember {
            let memberEvent = ChatRoomMemberEventView.Model(avatar: nil, sender: nil, event: event)
            guard memberEvent.isMembershipChange else { return nil }
        }
        // First event? -> use its date
        if index == 0 { return event.timestamp }
        // Was in same day as previous? -> no need in date
        if collection[index - 1].timestamp.isSameDay(as: event.timestamp) { return nil }
        // Other day -> use the date
        return event.timestamp
    }
    
    func earliestDate(in collection: [MXEvent]) -> Date? {
        collection.map({ $0.timestamp }).sorted(by: { $0 < $1 }).first
    }
    
}

extension Date {
    
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }
    
    func isSame(as anotherDate: Date, by component: Calendar.Component) -> Bool {
        Calendar.current.isDate(self, equalTo: anotherDate, toGranularity: component)
    }
    
    func isSameDay(as anotherDate: Date) -> Bool {
        isSame(as: anotherDate, by: .day)
    }
    
    func isSameYear(as anotherDate: Date) -> Bool {
        isSame(as: anotherDate, by: .year)
    }
    
    /// Today, yesterday, or day + month + year
    func chatBubbleDate(addYear: Bool = true) -> String {
        if self.isToday {
            return "Today"
        } else if self.isYesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            if addYear {
                formatter.dateStyle = .medium
            } else {
                formatter.dateFormat = "dd MMMM"
            }
            return formatter.string(from: self)
        }
    }
    
}

struct DateEventContainerWrapperView<Content>: View where Content: View {
    let date: Date?
    let content: Content
    
    init(date: Date?, @ViewBuilder contentBuilder: () -> Content) {
        self.date = date
        self.content = contentBuilder()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let text = date?.chatBubbleDate(addYear: true) {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            }
            content
        }
    }
}
