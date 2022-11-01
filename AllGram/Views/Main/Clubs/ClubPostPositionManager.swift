//
//  ClubPostPositionManager.swift
//  AllGram
//
//  Created by Alex Pirog on 28.03.2022.
//

import SwiftUI

class ClubPostPositionManager: ObservableObject {
    
    @Published private(set) var shouldPlay = false
    
    private let updateChangeThreshold: CGFloat = 5.0
    
    let postId: String
    
    // Weak to break memory cycle...
    private(set) weak var feedManager: FeedPositionManager?
    
    /// Changing this property will trigger an update only in case of notable changes
    /// (more than `updateChangeThreshold` value)
    var contentHeight: CGFloat = 0 {
        didSet { updateIfNeeded() }
    }
    private var lastUpdateHeight: CGFloat = 0
    
    /// Changing this property will trigger an update only in case of notable changes
    /// (more than `updateChangeThreshold` value)
    var contentOriginY: CGFloat = 0 {
        didSet { updateIfNeeded() }
    }
    private var lastUpdateOriginY: CGFloat = 0
    
    /// Checks if feed manager is treating this post as valid for playing
    func updateShouldPlay() {
        let should = feedManager?.accent == self && canPlay
        if should != shouldPlay {
            shouldPlay = should
        }
    }
    
    /// Additional cases to stop playing if not needed
    var canPlay = true
    
    init(postId: String, feedManager: FeedPositionManager) {
        self.postId = postId
        self.feedManager = feedManager
    }

    private func updateIfNeeded() {
        // Update only when both height and origin available
        guard contentHeight > 0 && contentOriginY > 0 else { return }
        let diffHeight = abs(contentHeight - lastUpdateHeight)
        let diffOriginY = abs(contentOriginY - lastUpdateOriginY)
        // Update only when notable changes
        guard (diffHeight + diffOriginY) > updateChangeThreshold else { return }
        lastUpdateHeight = contentHeight
        lastUpdateOriginY = contentOriginY
        feedManager?.updateAccentPost()
    }
    
    // MARK: - Fits or Not
    
    func fits(in frame: CGRect) -> Bool {
        let fits = canFullyFit(in: frame) ? fitsFully(in: frame) : fitsOversized(in: frame)
        return fits
    }
    
    private func canFullyFit(in frame: CGRect, allowedGap: CGFloat = 30) -> Bool {
        let feedHeight = frame.height
        return (contentHeight + allowedGap) < feedHeight
    }
    
    private func fitsOversized(in frame: CGRect, allowedGap: CGFloat = 60) -> Bool {
        let feedHeight = frame.height
        let feedTopY = frame.origin.y
        let postHeight = contentHeight
        let postTopY = contentOriginY
        let offGap = (postHeight - feedHeight) + allowedGap
        return abs(feedTopY - postTopY) <= offGap
    }
    
    private func fitsFully(in frame: CGRect) -> Bool {
        return fitsTop(in: frame) && fitsBot(in: frame)
    }
    
    private func fitsTop(in frame: CGRect) -> Bool {
        let feedHeight = frame.height
        let feedTopY = frame.origin.y
        let feedBotY = feedTopY + feedHeight
        return contentOriginY >= feedTopY && contentOriginY <= feedBotY
    }
    
    private func fitsBot(in frame: CGRect) -> Bool {
        let feedHeight = frame.height
        let feedTopY = frame.origin.y
        let feedBotY = feedTopY + feedHeight
        let postHeight = contentHeight
        let postTopY = contentOriginY
        let postBotY = postTopY + postHeight
        return postBotY >= feedTopY && postBotY <= feedBotY
    }
    
}

extension ClubPostPositionManager: Equatable {
    static func == (lhs: ClubPostPositionManager, rhs: ClubPostPositionManager) -> Bool {
        lhs.postId == rhs.postId
    }
}
