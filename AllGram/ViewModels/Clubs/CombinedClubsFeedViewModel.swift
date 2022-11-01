//
//  CombinedClubsFeedViewModel.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 22.02.2022.
//

import Foundation
import Combine
import MatrixSDK

class CombinedClubsFeedViewModel: ObservableObject {
    
    @Published private(set) var isPaginating = false
    
    // MARK: - Rooms
    
    @Published private(set) var clubRooms: [AllgramRoom]
    
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
    
    // MARK: - Posts
    
    @Published private(set) var individualFeedVMs = [ClubFeedViewModel]()
    
    /// Combined posts from all `joined` clubs, sorted by timestamp
    @Published private(set) var combinedPosts = [ClubPost]()
    
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
    
    // MARK: - Init
    
    /// Filters only invited and
    init(clubRooms: [AllgramRoom]) {
        self.clubRooms = clubRooms
        
        // Create individual club feed VM for each club room
        for c in clubRooms {
            let feed = ClubFeedViewModel(room: c)
            
            // Add self as handler of posts changes in that club feed
            feed.postsChangeOnUpdateHandler = { [weak self] in
                // Some posts have changed in a specific club,
                // we need to update combined posts as well
                guard let self = self else { return }
                var result = [ClubPost]()
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
            feed.updatePosts()
        }
    }
    
    // MARK: - Public
    
    /// Updates posts in all joined club feeds and stores sorted posts in `combinedPosts`
    func updatePosts() {
        // We do not need this anymore as individual feeds update their posts
        // automatically and we respond with a handler on each change
        //print("[N] unneeded updatePosts() call")
//        var result = [ClubPost]()
//        for feed in individualFeedVMs {
//            guard feed.room.summary.membership == .join else { continue }
//            feed.updatePosts()
//            result += feed.posts
//        }
//        combinedPosts = result.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    /// Paginates more events
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
    
    /// Adds 👍 reaction to the post if not already existent
    func like(post: ClubPost, completion: (() -> Void)? = nil) {
        guard let feed = individualFeedVMs
                .first(where: { $0.room.room.roomId == post.clubRoomId })
        else {
            completion?()
            return
        }
        feed.react(to: post) {
            completion?()
        }
    }
    
    /// Removes 👍 reaction from the post if already added by current user
    func unlike(post: ClubPost, completion: (() -> Void)? = nil) {
        guard let feed = individualFeedVMs
                .first(where: { $0.room.room.roomId == post.clubRoomId })
        else {
            completion?()
            return
        }
        feed.removeReaction(from: post) {
            completion?()
        }
    }
    
    /// Deletes post if possible
    func delete(post: ClubPost, completion: (() -> Void)? = nil) {
        var feedsToCheck = individualFeedVMs.count
        for feed in individualFeedVMs {
            feed.delete(post: post) {
                feedsToCheck -= 1
                if feedsToCheck == 0 {
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Private
    

    
}

extension CombinedClubsFeedViewModel: Equatable {
    static func == (lhs: CombinedClubsFeedViewModel, rhs: CombinedClubsFeedViewModel) -> Bool {
        // Equal if operate with the same set of rooms
        let leftIDs = lhs.clubRooms.map({ $0.room.roomId ?? "nil" }).sorted()
        let rightIDs = rhs.clubRooms.map({ $0.room.roomId ?? "nil" }).sorted()
        let isEqual = leftIDs == rightIDs
        return isEqual
    }
}
