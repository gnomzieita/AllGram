import Foundation
import MatrixSDK

fileprivate var callsInfoMap = [String : (String, UInt64, UInt64?)]()

func durationOfCall(_ event: MXEvent) -> TimeInterval? {
    if let callId = event.content["call_id"] as? String {
        if let tuple = callsInfoMap[callId], let endTime = tuple.2 {
            return TimeInterval(endTime - tuple.1) / 1000
        }
    }
    return nil
}

struct EventCollection {
    private var wrapped: [MXEvent]

    init(_ events: [MXEvent]) {
        self.wrapped = events
    }

    static let renderableEventTypes: Set = [
        kMXEventTypeStringRoomMessage,
//        kMXEventTypeStringRoomPowerLevels,
        kMXEventTypeStringRoomMember,
        kMXEventTypeStringRoomTopic,
        kMXEventTypeStringRoomName,
        kMXEventTypeStringCallInvite,
        kMXEventTypeStringCallAnswer,
        kMXEventTypeStringCallHangup,
        kMXEventTypeStringCallReject,
        // Encrypted version of kMXEventTypeStringRoomMessage
        kMXEventTypeStringRoomEncrypted,
    ]

    /// Events that can be directly rendered in the timeline with a corresponding view.
    /// This for example does not include reactions, which are instead rendered as
    /// accessories on their corresponding related events.
    var renderableEvents: [MXEvent] {
        // gather call events
        // [callId: (eventId: timeStart, timeEnd?)]
        callsInfoMap.removeAll()
        
        for ev in wrapped {
            var startTime, endTime: UInt64?
            switch ev.eventType {
            case .callInvite, .callAnswer: startTime = ev.originServerTs
            case .callHangup, .callReject: endTime = ev.originServerTs
            default: continue
            }
            guard let callId = ev.content["call_id"] as? String else {
                continue
            }
            if let t = startTime {
                callsInfoMap[callId] = (ev.eventId, t, nil)
            } else if let t = endTime {
                if let oldTuple = callsInfoMap[callId] {
                    callsInfoMap[callId] = (ev.eventId, oldTuple.1, t)
                }
            }
        }
        
        return wrapped.filter { event in
            guard let eventType = event.type else {
                return false
            }
            guard Self.renderableEventTypes.contains(eventType) else {
                return false
            }
            // Some events are duplicated with with 01/01/1970 as timestamp
            guard event.timestamp.timeIntervalSince1970 > 0 else {
                return false
            }
            let callTypes : Set<__MXEventType> = [.callInvite, .callAnswer, .callHangup, .callReject]
            if callTypes.contains(event.eventType) {
                if let callId = event.content["call_id"] as? String {
                    return (callsInfoMap[callId]?.0 == event.eventId)
                }
                return false
            }
            return true
        }
    }

    func relatedEvents(of event: MXEvent) -> [MXEvent] {
        wrapped.filter { $0.relatesTo?.eventId == event.eventId }
    }

    func reactions(for event: MXEvent) -> [Reaction] {
        relatedEvents(of: event)
            .filter { $0.type == kMXEventTypeStringReaction }
            .compactMap { event in
                guard let id = event.eventId,
                      let sender = event.sender,
                      let relatesToContent = event.content["m.relates_to"] as? [String: Any],
                      let reaction = relatesToContent["key"] as? String
                else { return nil }
                return Reaction(
                    id: id,
                    sender: sender,
                    timestamp: event.timestamp,
                    reaction: reaction
                )
            }
    }
}

// MARK: Grouping

extension EventCollection {
    static let groupableEventTypes = [
        kMXEventTypeStringRoomMessage,
        kMXEventTypeStringRoomEncrypted,
    ]

    func connectedEdges(of event: MXEvent) -> ConnectedEdges {
        guard let idx = wrapped.firstIndex(of: event) else {
            fatalError("Event not found in event collection.")
        }

        guard idx >= wrapped.startIndex else {
            return []
        }

        // Note to self: `first(where:)` should not filter redacted messages here, since that would skip them and base the decision on the message event before that, possibly wrapping the redaction inside the group. Redacted state is checked separately.
        let precedingMessageEvent = wrapped[..<idx]
            .last { Self.groupableEventTypes.contains($0.type ?? "nil") }

        let succeedingMessageEvent = wrapped[wrapped.index(after: idx)...]
            .first { Self.groupableEventTypes.contains($0.type ?? "nil") }
        
        var result = ConnectedEdges()
        if shouldGroup(event: event, to: precedingMessageEvent) {
            result.insert(.topEdge)
        }
        if shouldGroup(event: event, to: succeedingMessageEvent) {
            result.insert(.bottomEdge)
        }
        
        return result
    }
    
    private func shouldGroup(event: MXEvent, to neighborEvent: MXEvent?) -> Bool {
        guard let e = neighborEvent, e.sender == event.sender else {
            return false
        }
        if e.isRedactedEvent() || e.isEdit() {
            return false
        }

        let kTimeBeforeNewGroupMs : UInt64 = 5 * 60 * 1000 // 5 minutes
      
        let t1 = event.originServerTs
        let t2 = e.originServerTs
        return (t1 != kMXUndefinedTimestamp && t2 != kMXUndefinedTimestamp &&
                t1 < t2 + kTimeBeforeNewGroupMs && t2 < t1 + kTimeBeforeNewGroupMs)
        
    }
}

struct ConnectedEdges: OptionSet {
    let rawValue: Int

    static let topEdge: Self = .init(rawValue: 1 << 0)
    static let bottomEdge: Self = .init(rawValue: 1 << 1)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

struct ClubEventCollection {
    private var wrapped: [MXEvent]

    init(_ events: [MXEvent]) {
        self.wrapped = events
    }

    static let renderableEventTypes: Set = [
        kMXEventTypeStringRoomMessage,
        // Encrypted version of kMXEventTypeStringRoomMessage
        kMXEventTypeStringRoomEncrypted,
    ]

    var renderableEvents: [MXEvent] {
        wrapped.filter { event in
            guard let eventType = event.type else {
                return false
            }
            guard Self.renderableEventTypes.contains(eventType) else {
                return false
            }
            // Some events are duplicated with with 01/01/1970 as timestamp
            guard event.timestamp.timeIntervalSince1970 > 0 else {
                return false
            }
            return true
        }
    }

    func relatedEvents(of event: MXEvent) -> [MXEvent] {
        wrapped.filter { $0.relatesTo?.eventId == event.eventId }
    }

    func reactions(for event: MXEvent) -> [Reaction] {
        relatedEvents(of: event)
            .filter { $0.type == kMXEventTypeStringReaction }
            .compactMap { event in
                guard let id = event.eventId,
                      let sender = event.sender,
                      let relatesToContent = event.content["m.relates_to"] as? [String: Any],
                      let reaction = relatesToContent["key"] as? String
                else { return nil }
                return Reaction(
                    id: id,
                    sender: sender,
                    timestamp: event.timestamp,
                    reaction: reaction
                )
            }
    }
}
