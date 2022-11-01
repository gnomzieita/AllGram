//
//  CrashlyticsManager.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 20.01.2022.
//

import Foundation
import FirebaseCrashlytics

struct CrashlyticsManager {
    
    
    /// Records a user identifier that's associated with subsequent fatal and non-fatal reports in Crashlytics
    /// - Parameter is: Unique user identifier
    static func setUserId(_ id: String) {
        Crashlytics.crashlytics().setUserID(id)
    }
    
    /// Sets some environment variables for a crash report
    static func setupEnvironment() {
        Crashlytics.crashlytics().setCustomValue(softwareVersion, forKey: "software_version")
        Crashlytics.crashlytics().setCustomValue(API.server, forKey: "main_server")
        Crashlytics.crashlytics().setCustomValue(API.identityServer, forKey: "identity_server")
//        Crashlytics.crashlytics().setCustomValue(API.calendarServer, forKey: "calendar_server")
        Crashlytics.crashlytics().setCustomValue(API.botServer, forKey: "bot_server")
    }
    
}
