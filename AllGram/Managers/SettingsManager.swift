//
//  SettingsManager.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 11.01.2022.
//

import Foundation
import SwiftUI
import Combine

class SettingsManager {
    private static var cancellable = Set<AnyCancellable>()
    
    // MARK: - App
    
    private static var applicationLaunchCounterKey: String = "applicationLaunchCounterKey"
    public static var applicationLaunchCounter: Int{
        get{
            return UserDefaults.standard.integer(forKey: applicationLaunchCounterKey)
        }
        set{
            UserDefaults.standard.set(newValue, forKey: applicationLaunchCounterKey)
        }
    }
    
    static var versionUpdateAvailable = false
    static func checkVersion(tryAgainOnError: Bool = true) {
        NewApiManager.shared.checkForUpdates(version: softwareVersion)
            .sink { noNeedForUpdate in
                if noNeedForUpdate != nil {
                    versionUpdateAvailable = !noNeedForUpdate!
                } else if tryAgainOnError {
                    checkVersion(tryAgainOnError: false)
                }
            }.store(in: &cancellable)
    }
    
    // MARK: - Background
    
    private static let homeImageFromGalleryURLKey: String = "homeImageFromGalleryURLKey"
    
    public static func setHomeBackgroundImage(_ image: UIImage) {
        _ = image.saveImage(name: "homeBackground")
        homeBackgroundImageName = nil
    }
    
    public static func getSavedHomeBackgroundImage() -> UIImage? {
        UIImage.getSavedImage(named: "homeBackground")
    }
    
    public static var getHomeBackgroundImageFromGalleryURL: String? {
        get {
            return UserDefaults.standard.value(forKey: homeImageFromGalleryURLKey) as? String
        }
    }
    
    private static let homeBackgroundImageNameKey = "homeBackgroundImageNameKey"
    
    public static var homeBackgroundImageName: String? {
        get {
            UserDefaults.standard.string(forKey: homeBackgroundImageNameKey) ?? "backgroundLogo"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: homeBackgroundImageNameKey)
        }
    }
    
    private static let useImageForChatBackgroundKey = "useImageForChatBackgroundKey"
    
    public static var useImageForChatBackground: Bool {
        get {
            UserDefaults.standard.bool(forKey: useImageForChatBackgroundKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useImageForChatBackgroundKey)
        }
    }
    
    private static var chatBackgroundImageNameKey = "chatBackgroundImageNameKey"
    
    public static var chatBackgroundImageName: String? {
        get {
            UserDefaults.standard.string(forKey: chatBackgroundImageNameKey) ?? "backgroundLogo"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: chatBackgroundImageNameKey)
        }
    }
    private static let chatImageFromGalleryURLKey: String = "chatImageFromGalleryURLKey"
    
    public static func setChatBackgroundImage(_ image: UIImage) {
        _ = image.saveImage(name: "chatBackground")
        chatBackgroundImageName = nil
        useImageForChatBackground = true
    }
    
    public static func getChatBackgroundImage() -> UIImage? {
        guard useImageForChatBackground else  { return nil }
        if let chatBackgroundImageName = chatBackgroundImageName {
            return UIImage(named: chatBackgroundImageName)
        } else {
            return getSavedChatBackgroundImage()
        }
    }
    
    public static func getSavedChatBackgroundImage() -> UIImage? {
        UIImage.getSavedImage(named: "chatBackground")
    }
    
    //MARK: - Appearance
    
    private static let colorThemeKey = "colorThemeKey"
    
    enum ColorTheme: String {
        case automatic, dark, light
    }
    
    static var colorTheme: ColorTheme {
        get {
            // We store only forced light/dark theme, not automatic
            if let theme = UserDefaults.group.string(forKey: colorThemeKey) {
                return ColorTheme(rawValue: theme)!
            }
            return .automatic
        }
        set {
            if newValue == .automatic {
                // We do not store theme if automatic, so remove
                UserDefaults.group.removeObject(forKey: colorThemeKey)
            } else {
                // Update stored theme to new value
                UserDefaults.group.set(newValue.rawValue, forKey: colorThemeKey)
            }
            setupDisplayMode()
        }
    }
    
    static func setupDisplayMode() {
        var userInterfaceStyle: UIUserInterfaceStyle
        switch colorTheme {
        case .dark: userInterfaceStyle = .dark
        case .light: userInterfaceStyle = .light
        case .automatic: userInterfaceStyle = .unspecified
        }
        UIApplication.shared.windows.first?.overrideUserInterfaceStyle = userInterfaceStyle
    }
}
