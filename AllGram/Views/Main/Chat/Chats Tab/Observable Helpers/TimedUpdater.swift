//
//  TimedUpdater.swift
//  AllGram
//
//  Created by Alex Pirog on 03.05.2022.
//

import SwiftUI

class TimedUpdater: ObservableObject {
    /// Increments on timer (if needed)
    @Published private(set) var updates = 0 {
        didSet { updateHandler?() }
    }
    
    /// Is called every time variable `updates` is changed
    var updateHandler: (() -> Void)?
    
    private var timer: Timer?
    
    init() { }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    /// Invalidates current update timer (with optional last update)
    func invalidate(triggerUpdate: Bool = false) {
        timer?.invalidate()
        timer = nil
        if triggerUpdate { updates = 0 }
    }
    
    /// Issues a one time update after a given time.
    /// Does nothing if a given time is less than a second or
    /// current update timer will fire earlier than new update time
    func issueUpdate(in time: TimeInterval) {
        // Guard updates to be at least a second
        guard time >= 1 else { return }
        let newFire = Date(timeIntervalSinceNow: time)
        if let oldFire = timer?.fireDate, oldFire < newFire {
            // Update will come even faster, do nothing
            return
        } else {
            // Not issued an update yet, or new one should happen faster
            invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: time, repeats: false) {
                [weak self] _ in
                self?.invalidate(triggerUpdate: true)
            }
            timer!.tolerance = time / 10
        }
    }
}
