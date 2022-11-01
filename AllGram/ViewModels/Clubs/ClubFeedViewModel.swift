//
//  ClubFeedViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 16.02.2022.
//

import Foundation
import Combine
import MatrixSDK

/*
 m.room.message - посты и комментарии к ним.
 m.sticker - сообщение-стикер.
 m.reaction - лайк для m.room.message.
 m.room.encrypted - ивент-контейнер для зашифрованных ивентов. Внутри обычно m.message.
 m.room.redaction - удаление ивента (то есть, если приложение приняло ивент m.message, а позже - m.room.redaction с указанием на этот ивент, клиент должен трактовать m.message как удаленное).

 Для постов в клуб я сейчас реализовал два варианта:
 - если это одиночная картинка, клиент ее отправляет как есть.
 - если пост из картинки и текста - отправляется сообщение-заголовок (m.room.message, текст - "gRoUp\r\n2"). Затем отправляются два m.room.message (текст и картинка). В них клиент прописывает, что это ответы на сообщение-заголовок (используются атрибуты m.relates_to, m.in_reply_to для m.room.message).

 В комментариях к посту тоже прописывается связь с текстовой частью поста или с картинкой (тоже через m.in_reply_to). Главное, чтобы комментарии к посту отвечали на одну часть поста (или на картинку, или на текст).

 Редактирование текста существующего сообщения выполняется как отправка нового ивента m.room.message (с отредактированным текстом) и привязкой к редактируемому сообщению (m.relates_to.type == "m.replace").

 То есть, как такового удаления или редактирования сообщений в Matrix нет. Это больше на систему контроля версий похоже, вроде Git.

 Существующие клубы сейчас все еще по старой системе (картинка и текст в посте никак не связаны между собой, принадлежность частей к одному посту надо определять через близость по времени отправки; я для этого использую origin_server_ts, метки времени сервера).
 */

extension MXEvent {
    /// Event id for the other MXEvent that this one is replying to.
    /// MXEvent.repatesTo is insufficient in most cases, so here is the workaround.
    /// Created for club post comments
    var replyToEventId: String? {
        guard let relates = content["m.relates_to"] as? [String: Any],
              let inReply = relates["m.in_reply_to"] as? [String: Any],
              let id = inReply["event_id"] as? String
        else { return nil }
        return id
    }
}

class ClubFeedViewModel: ObservableObject {
    @Published private(set) var posts = [ClubPost]()
    @Published private(set) var isBusy = false
    @Published private(set) var isPaginating = false
    
    /// Will be called each time `updatePosts()` is finished with some changes
    var postsChangeOnUpdateHandler: (() -> Void)?
    
    let room: AllgramRoom
    
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
        updatePosts()
    }
    
    // MARK: - Public
    
    /// Finds club post for a given event, checks if this event is part of the post or one of its comments
    func getPost(for event: MXEvent) -> ClubPost? {
//        print("[P] selected event id: \(event.eventId!)")
//        print("[P] posts events ids: \(posts.map({ $0.postEvents.map({ $0.eventId! }) }))")
//        print("[P] comments events ids: \(posts.map({ $0.comments.map({ $0.commentEvent.eventId! }) }))")
        return posts.first { post in
            if post.postEvents.contains(where: { $0.eventId == event.eventId }) {
                return true
            }
            if post.comments.contains(where: { $0.commentEvent.eventId == event.eventId }) {
                return true
            }
            return false
        }
    }
    
    /// Removes reaction from post if available and adds it otherwise
    func handlePostReaction(_ post: ClubPost, with emoji: String, completion: (() -> Void)? = nil) {
        guard let userId = room.session.myUserId,
              let index = posts.firstIndex(of: post)
        else {
            completion?()
            return
        }
        if posts[index].reactions.contains(where: { $0.sender == userId && $0.reaction == emoji }) {
            // Already contains this emoji by current user - remove it
            removeReaction(emoji, from: post, completion: completion)
        } else {
            // No such emoji by current user yet - add one
            react(to: post, with: emoji, completion: completion)
        }
    }
    
    /// Removes reaction from comment if available and adds it otherwise
    func handleCommentReaction(_ comment: ClubComment, with emoji: String, completion: (() -> Void)? = nil) {
        let userId = room.session.myUserId
        if let commentReaction = comment.reactions.first(where: { $0.sender == userId && $0.reaction == emoji }) {
            // Already contains this emoji by current user - remove it
            room.redact(eventId: commentReaction.id, reason: "Removing comment reaction") { success in
                completion?()
            }
        } else {
            // No such emoji by current user yet - add one
            room.react(toEventId: comment.id, emoji: emoji) { success in
                completion?()
            }
        }
    }
    
    /// Adds a reaction to the post if not already added
    func react(to post: ClubPost, with emoji: String = "👍", completion: (() -> Void)? = nil) {
        guard let index = posts.firstIndex(of: post),
              emoji.isSingleEmoji,
              !posts[index].reactions.contains(where: { $0.reaction == emoji })
        else {
            completion?()
            return
        }
        room.react(toEventId: posts[index].id, emoji: emoji) { _ in
            completion?()
        }
    }
    
    /// Removes a reaction if possible
    func removeReaction(_ emoji: String = "👍", from post: ClubPost, completion: (() -> Void)? = nil) {
        guard let userId = room.session.myUserId,
              let index = posts.firstIndex(of: post),
              let reaction = posts[index].reactions
                .first(where: { $0.sender == userId && $0.reaction == emoji })
        else {
            completion?()
            return
        }
        room.redact(eventId: reaction.id, reason: "Removing post reaction") { _ in
            completion?()
        }
    }
    
    /// Deletes post if possible
    func delete(post: ClubPost, completion: (() -> Void)? = nil) {
        guard post.canDelete, posts.contains(post) else {
            completion?()
            return
        }
        // Redact all post events
        var eventsToRedact = post.postEvents.count
        for e in post.postEvents {
            room.redact(eventId: e.eventId, reason: "Deleting club post") { _ in
                eventsToRedact -= 1
                if eventsToRedact == 0 {
                    completion?()
                }
            }
        }
    }
    
    /// Paginates more events
    func paginate(untilGotNewPosts: Int = 3, completion: ((_ done: Bool) -> Void)? = nil) {
        guard room.expectMoreHistory && !isPaginating && untilGotNewPosts > 0 else {
            completion?(false)
            return
        }
        isPaginating = true
        let oldCount = posts.count
        room.paginateBackward() { [weak self] successful in
            self?.isPaginating = false
            self?.updatePosts()
            let newCount = self?.posts.count ?? oldCount
            let diff = newCount - oldCount
            if diff < untilGotNewPosts {
                self?.paginate(untilGotNewPosts: untilGotNewPosts - diff, completion: completion)
            } else {
                completion?(true)
            }
        }
    }
    
    /// Updates all posts, clearing old and reconstructing all again
    func updatePosts() {
        isBusy = true
        let oldPosts = posts
        var newPosts = [ClubPost]()
        
        // Posts with content (image, video) and text consist of 2 messages
        // First, the text message, then image/video message
        // Try to combine 2 close enough events info a post
        let lastEventDiff: UInt64 = 10_000 // What value to put here?
        var lastEvent: MXEvent?
        
        // If a message is a reply to a post message
        // Try to insert comment below that post
        var replies = [MXEvent]()
        
        // New combined posts (media + text) is now starts with
        // special text message "gRoUp\n2" (where 2 is number of parts)
        // Actual content (media, text) follows as replies to it
        var newCombinedPostsMainEvents = [MXEvent]()
        
        /// If we got a redact event that means that other event was deleted
        /// and we should not show original event if we already cached it
        var redactEvents = [MXEvent]()
        
        print("<e> handle events from '\(clubName)' START")
        let collection = room.getClubEvents()
        for e in collection.renderableEvents {
            _ = collection.relatedEvents(of: e)
            switch MXEventType(identifier: e.type) {
                // Post or comment?
            case .roomMessage:
                // Handle replies seperatly
                guard !e.isReply() else {
                    replies.append(e)
                    continue
                }
                // Look for our custom header message for combined posts
                if let body = e.content["body"] as? String, body.starts(with: "gRoUp") {
                    newCombinedPostsMainEvents.append(e)
                    continue
                }
                // Check for single media posts or old combined posts (close in time)
                if let typeString = e.content["msgtype"] as? String {
                    let diff = e.originServerTs - (lastEvent?.originServerTs ?? 0)
                    var closeEvent: MXEvent?
                    if diff < lastEventDiff {
                        closeEvent = lastEvent
                    }
                    switch MXMessageType(identifier: typeString) {
                    case .image:
                        if var c = getImagePost(from: e, and: closeEvent) {
                            c.reactions = checkReactions(for: e, in: collection, lastEvent: lastEvent)
                            newPosts.append(c)
                        }
                    case .video:
                        if var c = getVideoPost(from: e, and: closeEvent) {
                            c.reactions = checkReactions(for: e, in: collection, lastEvent: lastEvent)
                            newPosts.append(c)
                        }
                    default:
                        break
                    }
                    lastEvent = e
                }
                
            case .roomEncrypted:
                print("<e> Event: encrypted - encrypted, but failed to decode")
            case .roomRedaction:
                print("<e> Event: redaction - points to a post that should be deleted")
                redactEvents.append(e)
            default:
                print("<e> Event: unknown - do we even need to handle this? - \(e.type ?? "nil")")
            }
        }
        
        // MARK: New Combined Posts
        
        for e in newCombinedPostsMainEvents {
            var combined = [MXEvent]()
            while let index = replies.firstIndex(where: { $0.replyToEventId == e.eventId }) {
                // Reply to the new combined post main event
                let r = replies.remove(at: index)
                combined.append(r)
            }
            if var combinedPost = getNewPost(headerEvent: e, combined: combined) {
                combinedPost.postEvents.append(e)
                var allReactions = checkReactions(for: e, in: collection)
                for c in combined {
                    allReactions += checkReactions(for: c, in: collection)
                }
                combinedPost.reactions = allReactions
                newPosts.append(combinedPost)
            }
        }
        newPosts = newPosts.sorted(by: { $0.timestamp < $1.timestamp })
        
        // MARK: Remove witch Redacted
        
        if !redactEvents.isEmpty {
            for e in redactEvents {
                // Remove unwanted posts (simple, combined and old way combined)
                newPosts = newPosts.filter({ !$0.postEvents.contains(where: { $0.eventId == e.redacts }) })
                // Remove unwanted replies (comments)
                replies = replies.filter({ $0.eventId != e.redacts })
            }
        }
        
        // MARK: Comments
        
        /// Recursively tries to find index of a post passed reply is related
        func relatedPostIndex(for reply: MXEvent) -> Int? {
            if let index = newPosts.firstIndex(where: { $0.isEventReply(reply) }) {
                return index
            } else if let otherReplyIndex = replies.firstIndex(where: { $0.eventId == reply.replyToEventId! }) {
                return relatedPostIndex(for: replies[otherReplyIndex])
            } else {
                return nil
            }
        }
        
        for e in replies {
            if let index = relatedPostIndex(for: e) {
                // Reply to the post message - good
                newPosts[index].postRelatedEvents.append(e)
                if var comment = getComment(from: e) {
                    if let replyToEventId = e.replyToEventId,
                       let otherReplyIndex = replies.firstIndex(where: { $0.eventId == replyToEventId }),
                       let otherComment = getComment(from: replies[otherReplyIndex])
                    {
                        comment.replyToSender = otherComment.commentEvent.sender
                        comment.replyToMedia = otherComment.commentMedia
                    }
                    comment.reactions = checkReactions(for: e, in: collection)
                    newPosts[index].comments.append(comment)
                }
            } else {
                // Reply to what?!
            }
        }
        print("<e> handle events from '\(clubName)' END")
        
        posts = newPosts
        isBusy = false
        
        // Trigger handler when something actually changed
        // ClubPost struct is Equitable, so it's OK, right?
        if oldPosts != newPosts { postsChangeOnUpdateHandler?() }
        
        // Maybe last post event was a long time ago?
        // Like lots of membership events and zero actual messages
        guard posts.isEmpty else { return }
        paginate()
    }
    
    // MARK: - Events -> Comments
    
    private func getComment(from event: MXEvent) -> ClubComment? {
        guard let mediaManager = room.session.mediaManager,
              let typeString = event.content["msgtype"] as? String
        else { return nil }
        var media: CommentMediaType?
        switch MXMessageType(identifier: typeString) {
        case .image:
            let info = event.isEncrypted
            ? ImageInfo(encryptedEvent: event, mediaManager: mediaManager)
            : ImageInfo(imageEvent: event, mediaManager: mediaManager)
            if let info = info {
                media = .image(info)
            }
        case .video:
            let info = event.isEncrypted
            ? VideoInfo(encryptedEvent: event, mediaManager: mediaManager)
            : VideoInfo(videoEvent: event, mediaManager: mediaManager)
            if let info = info {
                media = .video(info)
            }
        case .text:
            if let body = event.content["body"] as? String {
                let components = body.components(separatedBy: "\n\n")
                let replyMessage = components.last ?? "failed"
                media = .text(replyMessage)
            }
        case .audio:
            if event.isVoiceMessage() {
                if let info = VoiceInfo(voiceEvent: event, mediaManager: mediaManager) {
                    media = .voice(info)
                }
            }
        default:
            break
        }
        guard let realMedia = media else { return nil }
        return ClubComment(commentEvent: event, commentMedia: realMedia)
    }
    
    // MARK: - Events -> Posts
    
    /// Expects 2 combined events, a text one and another media
    private func getNewPost(headerEvent: MXEvent, combined: [MXEvent]) -> ClubPost? {
        guard !combined.isEmpty else { return nil }
        let textIndex = combined.firstIndex(where: { (MXMessageType(identifier: $0.content["msgtype"] as! String) == .text) })
        let mediaIndex = textIndex == 0 ? 1 : 0
        guard combined.count > mediaIndex else { return nil }
        let textEvent = textIndex != nil ? combined[textIndex!] : nil
        let mediaEvent = combined[mediaIndex]
        switch MXMessageType(identifier:mediaEvent.content["msgtype"] as! String) {
        case .image:
            return getImagePost(from: mediaEvent, and: textEvent)
        case .video:
            return getVideoPost(from: mediaEvent, and: textEvent)
        default:
            return nil
        }
    }
    
    /// Expects event of type MXMessageType.image aka 'm.image'
    private func getImagePost(from contentEvent: MXEvent, and textEvent: MXEvent?) -> ClubPost? {
        guard let mediaManager = room.session.mediaManager else { return nil }
        let image = contentEvent.isEncrypted
        ? ImageInfo(encryptedEvent: contentEvent, mediaManager: mediaManager)
        : ImageInfo(imageEvent: contentEvent, mediaManager: mediaManager)
        guard let image = image else { return nil }
        let events = textEvent != nil ? [contentEvent, textEvent!] : [contentEvent]
        let text = textEvent?.content["body"] as? String
        let deletable = contentEvent.sender == room.session.myUserId
        let c = ClubPost(clubRoomId: room.room.roomId, clubName: self.clubName, clubLogoURL: self.clubLogoURL, postEvents: events, postMedia: .image(info: image, text: text), canDelete: deletable, canEdit: deletable && textEvent != nil)
        return c
    }
    
    /// Expects event of type MXMessageType.video aka 'm.video'
    private func getVideoPost(from contentEvent: MXEvent, and textEvent: MXEvent?) -> ClubPost? {
        guard let mediaManager = room.session.mediaManager else { return nil }
        let video = contentEvent.isEncrypted
        ? VideoInfo(encryptedEvent: contentEvent, mediaManager: mediaManager)
        : VideoInfo(videoEvent: contentEvent, mediaManager: mediaManager)
        guard let video = video else { return nil }
        let events = textEvent != nil ? [contentEvent, textEvent!] : [contentEvent]
        let text = textEvent?.content["body"] as? String
        let deletable = contentEvent.sender == room.session.myUserId
        let c = ClubPost(clubRoomId: room.room.roomId, clubName: self.clubName, clubLogoURL: self.clubLogoURL, postEvents: events, postMedia: .video(info: video, text: text), canDelete: deletable, canEdit: deletable && textEvent != nil)
        return c
    }
    
    /// Gets all reactions for an event and possible for last event for compound posts
    private func checkReactions(for event: MXEvent, in collection: ClubEventCollection, lastEvent: MXEvent? = nil) -> [Reaction] {
        var result = [Reaction]()
        let mainReactions = collection.reactions(for: event)

        result += mainReactions
        // Do we need this check? Leave just in case
        // In composed posts check both parts
        if let otherEvent = lastEvent {
            let minorReaction = collection.reactions(for: otherEvent)

            result += minorReaction
        }
        return result
    }
    
}
