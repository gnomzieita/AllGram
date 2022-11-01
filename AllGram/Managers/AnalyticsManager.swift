//
//  AnalyticsManager.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 20.01.2022.
//

import Foundation
import FirebaseAnalytics

// Default events docs: https://developers.google.com/analytics/devguides/collection/ga4/reference/events

/// Logs events to Firebase Analytics.
struct AnalyticsManager {
    
    /// Sends an event that indicates that a user has signed up for an account.
    /// - Parameter method: The method used for sign up.
    static func logSignUp(_ method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod : method
        ])
    }
    
    /// Sends an event to signify that a user has logged in.
    /// - Parameter method: The method used to login.
    static func logLogin(_ method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod : method
        ])
    }
    
}
