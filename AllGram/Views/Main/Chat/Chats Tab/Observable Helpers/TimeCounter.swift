//
//  TimeCounter.swift
//  AllGram
//
//  Created by Alex Pirog on 09.05.2022.
//

import SwiftUI

class TimeCounter: ObservableObject {
    /// Current counting time in seconds or `nil` if not counting ATM.
    /// For retrieving time after counting is stopped, see `lastTime`
    @Published private(set) var currentTime: Int?
    
    /// Time in seconds of the last counting or `nil` if not counted yet
    @Published private(set) var lastTime: Int?
    
    private var timer: Timer?
    
    init() { }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    /// Handles only minutes & seconds, not hours
    func text(for time: Int) -> String {
        let minutes = time / 60
        let seconds = time - 60 * minutes
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Starts counting seconds, stopping current count if any
    func startCounting() {
        stopCounting()
        currentTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            if self?.currentTime == nil {
                self?.currentTime = 1
            } else {
                self?.currentTime! += 1
            }
        }
        timer!.tolerance = 0.1
    }
    
    /// Stops current count if any
    func stopCounting() {
        timer?.invalidate()
        timer = nil
        lastTime = currentTime
        currentTime = nil
    }
}
