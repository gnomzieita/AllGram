//
//  FeedPositionManager.swift
//  AllGram
//
//  Created by Alex Pirog on 28.03.2022.
//

import SwiftUI

class FeedPositionManager {
    
    private var positionManagers = [ClubPostPositionManager]()
    
    private(set) var accent: ClubPostPositionManager? {
        didSet {
            positionManagers.forEach({ $0.updateShouldPlay() })
        }
    }
    
    var allowPlaying = true {
        didSet {
            allowPlaying
            ? updateAccentPost()
            : updateAccentIfNeeded(to: nil)
        }
    }
    
    var feedFrame: CGRect = .zero
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func appMovedToBackground() {
        allowPlaying = false
    }
    
    @objc
    private func appMovedToForeground() {
        allowPlaying = true
    }
    
    func createManager(for postId: String) -> ClubPostPositionManager {
        if let manager = positionManagers.first(where: { $0.postId == postId }) {
            return manager
        }
        let new = ClubPostPositionManager(postId: postId, feedManager: self)
        positionManagers.append(new)
        return new
    }
    
    func updateAccentPost() {
        guard !feedFrame.isEmpty else { return }
        guard !positionManagers.isEmpty else { return }
        let onScreen = getOnScreen()
        if !onScreen.isEmpty {
            var top: ClubPostPositionManager!
            for full in onScreen {
                if top == nil {
                    top = full
                } else if full.contentOriginY < top!.contentOriginY {
                    top = full
                }
            }
            updateAccentIfNeeded(to: top)
        } else {
            updateAccentIfNeeded(to: nil)
        }
    }
    
    private func updateAccentIfNeeded(to new: ClubPostPositionManager?) {
        guard accent != new else { return }
        accent = new
    }
    
    private func getOnScreen() -> [ClubPostPositionManager] {
        guard !feedFrame.isEmpty else { return [] }
        guard !positionManagers.isEmpty else { return [] }
        var fullOnScreen = [ClubPostPositionManager]()
        for postPosition in positionManagers {
            if postPosition.fits(in: feedFrame) {
                fullOnScreen.append(postPosition)
            }
        }
        return fullOnScreen
    }

    
}
