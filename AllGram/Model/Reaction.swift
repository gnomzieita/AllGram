import Foundation

struct Reaction: Identifiable {
    let id: String
    let sender: String
    let timestamp: Date
    let reaction: String

    init(id: String, sender: String, timestamp: Date, reaction: String) {
        self.id = id
        self.sender = sender
        self.timestamp = timestamp
        self.reaction = reaction
    }
}

extension Reaction: Equatable {
    static func == (lhs: Reaction, rhs: Reaction) -> Bool {
        // Id is Matrix event id for this reaction, so it's
        // safe to assume that all are unique by id and as they
        // can't change - also equal
        return lhs.id == rhs.id
    }
}

struct ReactionGroup: Identifiable {
    let reactions: [Reaction]
    let reaction: String
    let count: Int
    let timestamp: Date

    var id: String { reaction }
    
    init?(reaction: String, from reactions: [Reaction]) {
        let fittingReactions = reactions.filter { $0.reaction == reaction }
        let sortedReactions = fittingReactions.sorted(by: { $0.timestamp < $1.timestamp })
        guard let first = sortedReactions.first else { return nil }
        self.reactions = sortedReactions
        self.reaction = reaction
        self.count = sortedReactions.count
        self.timestamp = first.timestamp
    }

    func containsReaction(from sender: String) -> Bool {
        reactions.contains { $0.sender == sender }
    }
    
    func reaction(from sender: String) -> Reaction? {
        reactions.first(where: { $0.sender == sender })
    }
}
