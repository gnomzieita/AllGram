//
//  LocalisationManager.swift
//  AllGram
//
//  Created by Alex Pirog on 25.04.2022.
//

import Foundation

/// Language options supported by the app
enum Language: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    
    var optionDescription: String {
        switch self {
        case .english: return "English (United States)"
        case .russian: return "Русский"
        }
    }
}

/// Shared manager to set in app language. Takes effect after restart.
/// Check `LocaleViewModel` for switching language on the fly
class LocalisationManager {
    static let shared = LocalisationManager()
    private init() {
        if let stored = UserDefaults.standard.object(forKey: keyCurrentLanguage) as? String {
            // Already set a language beforehand - use it
            setLanguage(Language(rawValue: stored)!)
        } else {
            // Begin with locale language if not
            setToLocale()
        }
    }
    
    private let keyAppleLanguage = "AppleLanguages"
    private let keyCurrentLanguage = "CurrentLanguage"
    
    private(set) var appBundle = Bundle.main
    private(set) var currentLanguage: Language! // Will be set in init
    
    func setLanguage(_ language: Language) {
        let short = language.rawValue
        let langPath = Bundle.main.path(forResource: short, ofType: "lproj")!
        appBundle = Bundle(path: langPath)!
        currentLanguage = language
        UserDefaults.standard.set([short], forKey: keyAppleLanguage)
        UserDefaults.standard.set(short, forKey: keyCurrentLanguage)
    }
    
    private func setToLocale(fallbackLanguage: Language = .english) {
        if let systemCode = Locale.current.languageCode,
           let systemLanguage = Language(rawValue: systemCode) {
            setLanguage(systemLanguage)
        } else {
            setLanguage(fallbackLanguage)
        }
    }
}
