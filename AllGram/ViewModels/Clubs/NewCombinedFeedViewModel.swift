//
//  NewCombinedFeedViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 23.09.2022.
//

import Foundation
import Combine
import MatrixSDK

class NewCombinedFeedViewModel: ObservableObject {
    @Published private(set) var combinedPosts = [NewClubPost]()
    @Published private(set) var isPaginating = false
    
    /// Club in `invited` state
    var invitedToClubs: [AllgramRoom] {
//        clubRooms.filter({ $0.summary.membership == .invite })
        clubRooms.filter({ !$0.session.isJoined(onRoom: $0.room.roomId) })
    }
    
    /// Club in `joined` state
    var joinedClubs: [AllgramRoom] {
//        clubRooms.filter({ $0.summary.membership == .join })
        clubRooms.filter({ $0.session.isJoined(onRoom: $0.room.roomId) })
    }
    
    /// `True` when at least one of the rooms expects more history.
    /// Checks only `joined` club rooms
    var expectsMorePosts: Bool {
        for room in joinedClubs {
            if room.expectMoreHistory {
                return true
            }
        }
        return false
    }
    
    let clubRooms: [AllgramRoom]
    
    private var individualFeedVMs = [NewClubFeedViewModel]()
    
    /// Filters only invited and
    init(clubRooms: [AllgramRoom]) {
        self.clubRooms = clubRooms
        
        // Create individual club feed VM for each club room
        for c in clubRooms {
            let feed = NewClubFeedViewModel(room: c)
            
            // Add self as handler of posts changes in that club feed
            feed.postsChangeOnUpdateHandler = { [weak self] id, posts in
                // Some posts have changed in a specific club,
                // we need to update combined posts as well
                guard let self = self else { return }
                var result = [NewClubPost]()
                for feed in self.individualFeedVMs {
                    guard feed.room.summary.membership == .join else { continue }
                    result += feed.posts
                }
                self.combinedPosts = result.sorted(by: { $0.timestamp < $1.timestamp })
                //print("[N] \(feed.clubName) - new posts updated")
            }
            
            individualFeedVMs.append(feed)
        }
        
        // Gather initial posts from all feeds
        for feed in individualFeedVMs {
            guard feed.room.summary.membership == .join else { continue }
            feed.updateFeed()
        }
    }
    
    func handleReaction(_ emoji: String = "👍", post: NewClubPost, completion: ((NewClubFeedViewModel.ReactionResult) -> Void)? = nil) {
        guard let feed = individualFeedVMs
                .first(where: { $0.clubRoomId == post.clubRoomId })
        else {
            completion?(.impossible)
            return
        }
        feed.handleReaction(emoji, post: post, completion: completion)
    }
    
    func findFeed(by roomId: String) -> NewClubFeedViewModel? {
        individualFeedVMs.first { $0.clubRoomId == roomId }
    }
    
    func findPost(by postId: String) -> NewClubPost? {
        combinedPosts.first { $0.id == postId }
    }
    
    func delete(post: NewClubPost, completion: (() -> Void)? = nil) {
        guard let feed = individualFeedVMs
                .first(where: { $0.clubRoomId == post.clubRoomId })
        else {
            completion?()
            return
        }
        feed.deletePost(post, completion: completion)
    }
    
    func paginate(untilGotNewPosts: Int = 1) {
        guard expectsMorePosts && !isPaginating && untilGotNewPosts > 0 else { return }
        isPaginating = true
        var paginateCount = individualFeedVMs.count
        for feed in individualFeedVMs {
            feed.paginate(untilGotNewPosts: untilGotNewPosts) { [weak self] _ in
                paginateCount -= 1
                if paginateCount < 1 {
                    self?.isPaginating = false
                }
            }
        }
    }
}

extension NewCombinedFeedViewModel: Equatable {
    static func == (lhs: NewCombinedFeedViewModel, rhs: NewCombinedFeedViewModel) -> Bool {
        lhs.combinedPosts == rhs.combinedPosts && lhs.isPaginating == rhs.isPaginating
    }
}
