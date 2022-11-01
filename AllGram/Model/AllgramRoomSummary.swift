import Foundation
import MatrixSDK

@dynamicMemberLookup
class AllgramRoomSummary: ObservableObject {
    internal var summary: MXRoomSummary

    var lastMessageDate: Date {
        let timestamp = Double(summary.lastMessage?.originServerTs ?? UInt64(Date.timeIntervalSinceReferenceDate))
        return Date(timeIntervalSince1970: timestamp / 1000)
    }

    init(_ summary: MXRoomSummary) {
        self.summary = summary
    }

    subscript<T>(dynamicMember keyPath: KeyPath<MXRoomSummary, T>) -> T {
        summary[keyPath: keyPath]
    }
}
