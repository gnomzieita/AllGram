//
//  KeyBackupInfoListener.swift
//  AllGram
//
//  Created by Alex Pirog on 19.08.2022.
//

import SwiftUI

extension NSNotification.Name {
    /// User created new room (meeting, chat or club)
    static var userCreatedRoom = NSNotification.Name("userCreatedRoom")
    /// User sent new message in meeting/chat or commented or created new post in any club
    static var userSendMessage = NSNotification.Name("userSendMessage")
    /// User created new post (simple or combined) in any club
    static var userCreatedPost = NSNotification.Name("userCreatedPost")
    /// User commented any post in any club
    static var userCommentedPost = NSNotification.Name("userCommentedPost")
}

class KeyBackupInfoListener: ObservableObject {
    @Published var showAlert = false
    @Published var stopShowing = false
    
    let backupVM: NewKeyBackupViewModel
    
    init(backupVM: NewKeyBackupViewModel) {
        self.backupVM = backupVM
        
        // Listen for notifications to show alert if needed
        let notificationNames: [Notification.Name] = [
//            .userCreatedRoom,
            .userSendMessage,
            .userCreatedPost,
            .userCommentedPost,
        ]
        for name in notificationNames {
            NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name: name, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    private func handleNotification(_ notification: Notification) {
        guard case .noBackup = backupVM.state else { return }
        guard !stopShowing else { return }
        withAnimation { showAlert = true }
    }
}
