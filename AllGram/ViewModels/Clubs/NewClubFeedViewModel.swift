//
//  NewClubFeedViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 21.09.2022.
//

import Foundation
import Combine
import MatrixSDK

extension MXEvent {
    /// Returns `true` for combined post header events.
    /// Content of the event should have a string body of value starting with `gRoUp`
    func isHeaderEvent() -> Bool {
        guard let body = self.content["body"] as? String else { return false }
        return body.starts(with: "gRoUp")
    }
    /// Returns width and height for media events if possible.
    /// Content of the event should have `info` block with `w` and `h` values
    var mediaSize: CGSize? {
        guard let info = self.content["info"] as? [String: Any],
              let w = info["w"] as? CGFloat,
              let h = info["h"] as? CGFloat
        else { return nil }
        return CGSize(width: w, height: h)
    }
    /// Returns mime type string for media events if possible.
    /// Content of the event should have `info` block with `mimetype` value
    var mediaMimeType: String? {
        guard let info = self.content["info"] as? [String: Any],
              let mime = info["mimetype"] as? String
        else { return nil }
        return mime
    }
}

extension CGSize {
    /// Width divided by height (replaces `NaN` with `1`)
    var aspectRatio: CGFloat {
        let ratio = width / height
        return ratio.isNaN ? 1 : ratio
    }
}

extension Array where Element == Reaction {
    func groupReactions() -> [ReactionGroup] {
        self.map { $0.reaction }
            .removingDuplicates()
            .compactMap { ReactionGroup(reaction: $0, from: self) }
            .sorted { $0.count > $1.count }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

extension Array where Element == ReactionGroup {
    func toReactions() -> [Reaction] {
        self.map { $0.reactions }.joined()
            .sorted { $0.timestamp < $1.timestamp }
    }
}

protocol ManagesReactions {
    var reactions: [Reaction] { get set }
    
    func hasReaction(_ emoji: String, by userId: String) -> Bool
    func getReaction(_ emoji: String, by userId: String) -> Reaction?
}

extension ManagesReactions {
    func hasReaction(_ emoji: String, by userId: String) -> Bool {
        reactions.contains(where: { $0.sender == userId && $0.reaction == emoji })
    }
    func getReaction(_ emoji: String, by userId: String) -> Reaction? {
        reactions.first(where: { $0.sender == userId && $0.reaction == emoji })
    }
}

struct NewClubPost: Identifiable, Equatable, ManagesReactions {
    /// Events that are combined to represent a post (at least one)
    let postEvents: [MXEvent]
    
    var id: String { postEvents.first!.eventId }
    var timestamp: UInt64 { postEvents.first!.originServerTs }
    var senderId: String { postEvents.first!.sender }
    var clubRoomId: String { postEvents.first!.roomId }
    var isValid: Bool { isValidBasicPost || isValidCombinedPost }
    var idForNewComment: String { (mediaEvent ?? textEvent)!.eventId }
    
    // Combined post helpers
    var headerEvent: MXEvent? {
        postEvents.first { $0.isHeaderEvent() }
    }
    var textEvent: MXEvent? {
        postEvents.first { !$0.isHeaderEvent() && $0.messageType == .text }
    }
    var mediaEvent: MXEvent? {
        postEvents.first { $0.isMediaAttachment() }
    }
    
    /// Basic post just have a single media event
    var isValidBasicPost: Bool {
        postEvents.count == 1 && (postEvents.first?.isMediaAttachment() ?? false)
    }
    
    /// Combined post starts with header event and then text and media events
    var isValidCombinedPost: Bool {
        headerEvent != nil && textEvent != nil && mediaEvent != nil
    }
    
    var comments = [NewClubComment]()
    var reactions = [Reaction]()
    
    init(events: [MXEvent]) {
        self.postEvents = events
    }
    
    static func == (lhs: NewClubPost, rhs: NewClubPost) -> Bool {
        // Guard same posts by id first, then compare content
        guard lhs.id == rhs.id else { return false }
        return lhs.comments == rhs.comments && lhs.reactions == rhs.reactions
    }
}

struct NewClubComment: Identifiable, Equatable, ManagesReactions {
    let commentEvent: MXEvent
    
    var id: String { commentEvent.eventId }
    
    var reactions = [Reaction]()
    var isReplyToComment = false
    
    init(event: MXEvent) {
        self.commentEvent = event
    }
    
    static func == (lhs: NewClubComment, rhs: NewClubComment) -> Bool {
        // Guard same comments by id first, then compare content
        guard lhs.id == rhs.id else { return false }
        return lhs.reactions == rhs.reactions
    }
}

class NewClubFeedViewModel: ObservableObject {
    @Published private(set) var posts = [NewClubPost]()
    @Published private(set) var isPaginating = false
    
    /// Will be called each time `updateFeed()` is finished with some changes
    var postsChangeOnUpdateHandler: ((String, [NewClubPost]) -> Void)?
    
    let room: AllgramRoom
    
    var clubRoomId: String { room.roomId }
    var clubName: String { room.displayName ?? "" }
    var clubLogoURL: URL? { room.realAvatarURL }
    var clubTopic: String? { room.topic }
    var clubDescription: String? { room.clubDescription }
    
    init(room: AllgramRoom) {
        self.room = room
        // Update posts on summary changes (possibly new events)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRoomSummaryChange), name: .mxRoomSummaryDidChange, object: room.room.summary)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    private func handleRoomSummaryChange(_ notification: Notification) {
        updateFeed()
    }
    
    // MARK: - Search
    
    enum SearchResult {
        case none
        case post(NewClubPost)
        case comment(NewClubPost, NewClubComment)
        
        var post: NewClubPost? {
            switch self {
            case .none: return nil
            case .post(let p): return p
            case .comment(let p, _): return p
            }
        }
        
        var comment: NewClubComment? {
            switch self {
            case .none: return nil
            case .post(_): return nil
            case .comment(_, let c): return c
            }
        }
    }
    
    func find(by id: String) -> SearchResult {
        for p in posts {
            if p.postEvents.map({ $0.eventId }).contains(id) {
                return .post(p)
            }
            if let c = p.comments.first(where: { $0.id == id }) {
                return .comment(p, c)
            }
        }
        return .none
    }
    
    // MARK: - Delete
    
    func deletePost(_ post: NewClubPost, completion: (() -> Void)? = nil) {
        var eventsToRedact = post.postEvents.count
        for event in post.postEvents {
            room.redact(eventId: event.eventId, reason: "Deleting club post") { _ in
                eventsToRedact -= 1
                if eventsToRedact == 0 {
                    completion?()
                }
            }
        }
    }
    
    func deleteComment(_ comment: NewClubComment, completion: (() -> Void)? = nil) {
        room.redact(eventId: comment.id, reason: "Deleting club comment") { _ in
            completion?()
        }
    }
    
    // MARK: - Reactions
    
    enum ReactionResult {
        case impossible
        case success
        case failure
    }
    
    func addReaction(_ emoji: String = "👍", to post: NewClubPost, completion: ((ReactionResult) -> Void)? = nil) {
        guard emoji.isSingleEmoji,
              let userId = room.session.myUserId,
              post.hasReaction(emoji, by: userId)
        else {
            completion?(.impossible)
            return
        }
        room.react(toEventId: post.id, emoji: emoji) { success in
            completion?(success ? .success : .failure)
        }
    }
    
    func removeReaction(_ emoji: String = "👍", from post: NewClubPost, completion: ((ReactionResult) -> Void)? = nil) {
        guard emoji.isSingleEmoji,
              let userId = room.session.myUserId,
              let reaction = post.getReaction(emoji, by: userId)
        else {
            completion?(.impossible)
            return
        }
        room.redact(eventId: reaction.id, reason: "Removing post reaction") { success in
            completion?(success ? .success : .failure)
        }
    }
    
    /// Removes reaction from the `post` if already has it or adds it otherwise
    func handleReaction(_ emoji: String = "👍", post: NewClubPost, completion: ((ReactionResult) -> Void)? = nil) {
        guard emoji.isSingleEmoji,
              let userId = room.session.myUserId
        else {
            completion?(.impossible)
            return
        }
        if let reaction = post.getReaction(emoji, by: userId) {
            room.redact(eventId: reaction.id, reason: "Removing post reaction") { success in
                completion?(success ? .success : .failure)
            }
        } else {
            room.react(toEventId: post.id, emoji: emoji) { success in
                completion?(success ? .success : .failure)
            }
        }
    }
    
    /// Removes reaction from `comment` if already has it or adds it otherwise
    func handleReaction(_ emoji: String = "👍", comment: NewClubComment, completion: ((ReactionResult) -> Void)? = nil) {
        guard emoji.isSingleEmoji,
              let userId = room.session.myUserId
        else {
            completion?(.impossible)
            return
        }
        if let reaction = comment.getReaction(emoji, by: userId) {
            room.redact(eventId: reaction.id, reason: "Removing comment reaction") { success in
                completion?(success ? .success : .failure)
            }
        } else {
            room.react(toEventId: comment.id, emoji: emoji) { success in
                completion?(success ? .success : .failure)
            }
        }
    }
    
    // MARK: - Update
    
    /// Updates feed (posts and comment)
    /// Clears old data and reconstructs all again
    func updateFeed() {
        let oldPosts = posts
        var newPosts = [NewClubPost]()
        
        // Parts of combined posts or just comments (reply to comments)
        var replies = [MXEvent]()
        
        // Header events for combined posts (text + media)
        var headers = [MXEvent]()
        
        // Basic posts with a single media event
        var basic = [MXEvent]()
        
        // MARK: Sort row events to categories
        
        let collection = room.getClubEvents()
        for event in collection.renderableEvents {
            switch event.eventType {
            case .roomMessage:
                // Omit redacted (deleted) events
                guard !event.isRedactedEvent() else { continue }
                
                // Also omit edit events as they already edited content
                guard !event.isEdit() else { continue }
                
                // Handle replies separately as they may be part of
                // combined posts or just a comment (reply to comment)
                guard !event.isReply() else {
                    replies.append(event)
                    continue
                }
                
                // Look for our custom header message for combined posts
                guard !event.isHeaderEvent() else {
                    headers.append(event)
                    continue
                }
                
                // Handle basic posts with just image/video
                switch event.messageType {
                case .image, .video:
                    basic.append(event)
                    
                default:
                    // Old and invalid way of combined posts, where parts
                    // of a post were send in close time proximity...
                    // Or just invalid (yet) media type for a post
                    break
                }
                
            case .roomEncrypted:
                // Event failed decryption for some reason or user lost keys
                break
                
            default:
                // Other events that are irrelevant to the feed
                break
            }
        }
        
        // MARK: Create basic/combined posts
        
        for event in basic {
            var post = NewClubPost(events: [event])
            post.reactions = collection.reactions(for: event)
            newPosts.append(post)
        }
        
        for header in headers {
            var combined = [MXEvent]()
            while let index = replies.firstIndex(where: { $0.replyToEventId == header.eventId }) {
                let r = replies.remove(at: index)
                combined.append(r)
            }
            guard !combined.isEmpty else { continue }
            var post = NewClubPost(events: [header] + combined)
            for event in post.postEvents {
                post.reactions += collection.reactions(for: event)
            }
            newPosts.append(post)
        }
        
        // MARK: Distribute comments
        
        /// Recursively tries to find index of a post passed reply is related
        func relatedPostIndex(for reply: MXEvent) -> Int? {
            if let index = newPosts.firstIndex(where: { $0.postEvents.map({ $0.eventId }).contains(reply.replyToEventId) }) {
                return index
            } else if let otherReplyIndex = replies.firstIndex(where: { $0.eventId == reply.replyToEventId! }) {
                return relatedPostIndex(for: replies[otherReplyIndex])
            } else {
                return nil
            }
        }
        
        // Get comments from replies
        for reply in replies {
            if let index = relatedPostIndex(for: reply) {
                var comment = NewClubComment(event: reply)
                comment.reactions = collection.reactions(for: reply)
                newPosts[index].comments.append(comment)
            }
        }
        
        // Handle reply to other comments
        for p in 0..<newPosts.count {
            let ids = newPosts[p].comments.compactMap { $0.commentEvent.eventId }
            for c in 0..<newPosts[p].comments.count {
                let id = newPosts[p].comments[c].commentEvent.replyToEventId!
                newPosts[p].comments[c].isReplyToComment = ids.contains(id)
            }
        }
        
        // MARK: Finish update
        
        posts = newPosts.filter { $0.isValid }
        
        // Trigger handler when something actually changed
        // ClubPost struct is Equitable, so it's OK, right?
        if posts != oldPosts { postsChangeOnUpdateHandler?(clubRoomId, posts) }
        
        // Maybe last post event was a long time ago?
        // Like lots of membership events and zero actual messages
        guard posts.isEmpty else { return }
        paginate()
    }
    
    // MARK: - Paginate
    
    enum FeedPaginateResult {
        case noHistory
        case requestedZero
        case alreadyInProgress
        case failed
        case done
    }
    
    func paginate(untilGotNewPosts: Int = 3, completion: ((FeedPaginateResult) -> Void)? = nil) {
        guard room.expectMoreHistory else {
            completion?(.noHistory)
            return
        }
        guard untilGotNewPosts > 0 else {
            completion?(.requestedZero)
            return
        }
        guard !isPaginating else {
            completion?(.alreadyInProgress)
            return
        }
        isPaginating = true
        let oldCount = posts.count
        room.paginateBackward() { [weak self] success in
            self?.isPaginating = false
            guard success else {
                completion?(.failed)
                return
            }
            self?.updateFeed()
            let newCount = self?.posts.count ?? oldCount
            let diff = newCount - oldCount
            if diff < untilGotNewPosts {
                self?.paginate(untilGotNewPosts: untilGotNewPosts - diff, completion: completion)
            } else {
                completion?(.done)
            }
        }
    }
}
