//
//  NotificationUpdater.swift
//  AllGram
//
//  Created by Alex Pirog on 03.05.2022.
//

import SwiftUI

class NotificationUpdater: ObservableObject {
    /// Increments on notification (if needed)
    @Published private(set) var updates = 0 {
        didSet { updateHandler?() }
    }
    
    /// Is called every time variable `updates` is changed
    var updateHandler: (() -> Void)?
    
    /// Determines whether to update by a given notification or not.
    /// Always updates if not set (default case)
    var updateChecker: ((Notification) -> Bool)?
    
    init() { }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Stops updating (with optional last update) and removes notification observer
    func stopNotificationUpdates(triggerUpdate: Bool = false) {
        NotificationCenter.default.removeObserver(self)
        if triggerUpdate { updates = 0 }
    }
    
    /// Starts updating and adds observer to a given notification and optional object
    func updateOnNotification(name: Notification.Name, object: Any? = nil) {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler), name: name, object: object)
    }
    
    @objc
    private func notificationHandler(_ notification: Notification) {
        // Check notification if provided or update by default
        if updateChecker?(notification) ?? true { updates += 1 }
    }
}
