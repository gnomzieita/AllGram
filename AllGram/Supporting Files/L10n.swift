//
//  L10n.swift
//  AllGram
//
//  Created by Alex Pirog on 25.04.2022.
//

import SwiftUI

/// Helper enum for all available localised options
enum nL10n {
    enum TypingIndicator {
        /// Several people are typing
        static var many: LocalizedStringKey {
            LocalizedStringKey("typing-indicator.many")
        }
        /// %@ is typing
        static func single(_ p: Any) -> LocalizedStringKey {
            LocalizedStringKey("typing-indicator.single \(String(describing: p))")
        }
        /// %@ and %@ are typing
        static func two(_ p1: Any, _ p2: Any) -> LocalizedStringKey {
            LocalizedStringKey("typing-indicator.two \(String(describing: p1)) \(String(describing: p2))")
        }
    }
    enum Tabs {
        static var home: LocalizedStringKey {
            LocalizedStringKey("tabs.home")
        }
        static var calendar: LocalizedStringKey {
            LocalizedStringKey("tabs.calendar")
        }
        static var chats: LocalizedStringKey {
            LocalizedStringKey("tabs.chats")
        }
        static var clubs: LocalizedStringKey {
            LocalizedStringKey("tabs.clubs")
        }
        static var calls: LocalizedStringKey {
            LocalizedStringKey("tabs.calls")
        }
        static var more: LocalizedStringKey {
            LocalizedStringKey("tabs.more")
        }
    }
    
    // MARK: - Home Tab
    
    // MARK: - Chats Tab
    
    // MARK: - Clubs Tab
    
    // MARK: - More Tab
    
    enum UserSettings {
        static var title: LocalizedStringKey {
            LocalizedStringKey("user-settings.title")
        }
    }
    // Done
    enum PrivacyStatement {
        static var title: LocalizedStringKey {
            LocalizedStringKey("privacy-statement.title")
        }
    }
    // Done
    enum TermsAndConditions {
        static var title: LocalizedStringKey {
            LocalizedStringKey("terms-and-conditions.title")
        }
    }
    // Done
    enum CommunityGuidelines {
        static var title: LocalizedStringKey {
            LocalizedStringKey("community-guidelines.title")
        }
    }
    // Done
    enum DeactivateAccount {
        static var title: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.title")
        }
        static var firstTime: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.first-time")
        }
        static var sorry: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.sorry")
        }
        static var irreversible: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.irreversible")
        }
        static var actionDescription: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.action-description")
        }
        static var actionRequirement: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.action-requirement")
        }
        static var passwordPlaceholder: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.password-placeholder")
        }
        static var actionButtonTitle: LocalizedStringKey {
            LocalizedStringKey("deactivate-account.action-button-title")
        }
    }
    // Done
    enum AppearanceSettings {
        static var title: LocalizedStringKey {
            LocalizedStringKey("appearance-settings.title")
        }
        static var colorScheme: LocalizedStringKey {
            LocalizedStringKey("appearance-settings.color-scheme")
        }
        static var light: LocalizedStringKey {
            LocalizedStringKey("appearance-settings.light")
        }
        static var dark: LocalizedStringKey {
            LocalizedStringKey("appearance-settings.dark")
        }
        static var changeHomeBackground: LocalizedStringKey {
            LocalizedStringKey("appearance-settings.change-home-background")
        }
        static var changeChatBackground: LocalizedStringKey {
            LocalizedStringKey("appearance-settings.change-chat-background")
        }
        static var selectFromGallery: LocalizedStringKey {
            LocalizedStringKey("appearance-settings.select-from-gallery")
        }
    }
    // Done
    enum LanguageSettings {
        static var title: LocalizedStringKey {
            LocalizedStringKey("language-settings.title")
        }
        static var current: LocalizedStringKey {
            LocalizedStringKey("language-settings.current")
        }
        static var otherAvailable: LocalizedStringKey {
            LocalizedStringKey("language-settings.other-available")
        }
    }
    // Done
    enum About {
        static var title: LocalizedStringKey {
            LocalizedStringKey("about.title")
        }
        static var version: LocalizedStringKey {
            LocalizedStringKey("about.version")
        }
        static var newVersion: LocalizedStringKey {
            LocalizedStringKey("about.new-version")
        }
    }
}
