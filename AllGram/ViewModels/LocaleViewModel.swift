//
//  LocaleViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 25.04.2022.
//

import SwiftUI

/// Uses LocalisationManager to change app language and updates locale to get the effect on the fly
class LocaleViewModel: ObservableObject {
    
    @Published private(set) var locale: Locale
    
    init() {
        locale = Locale(identifier: LocalisationManager.shared.currentLanguage.rawValue)
    }
    
    func changeLanguage(to language: Language) {
        LocalisationManager.shared.setLanguage(language)
        locale = Locale(identifier: LocalisationManager.shared.currentLanguage.rawValue)
    }
    
}
