//
//  AllGramApp.swift
//  AllGram
//
//  Created by Admin on 11.08.2021.
//

import SwiftUI
import Firebase
import PartialSheet

@main
struct AllGramApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        FirebaseApp.configure()
    }
    
    let sheetManager: PartialSheetManager = PartialSheetManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sheetManager)
                .onAppear() {
                    UITableView.appearance().backgroundColor = UIColor.clear
                    UITableViewCell.appearance().backgroundColor = UIColor.clear
                    
                    // Set all navigation bars with our colors
                    let coloredAppearance = UINavigationBarAppearance()
                    coloredAppearance.configureWithTransparentBackground()
                    coloredAppearance.backgroundColor = Color.allgramMain.uiColor
                    coloredAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                    coloredAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                    coloredAppearance.shadowColor = .clear
                    
                    // Button fix
                    let backItemAppearance = UIBarButtonItemAppearance()
                    backItemAppearance.normal.titleTextAttributes = [.foregroundColor : UIColor.white] // fix text color
                    coloredAppearance.backButtonAppearance = backItemAppearance
                    let image = UIImage(systemName: "chevron.backward")?.withTintColor(.white, renderingMode: .alwaysOriginal) // fix indicator color
                    coloredAppearance.setBackIndicatorImage(image, transitionMaskImage: image)
                    
                    // Set new appearance preference
                    let navBarAppearance = UINavigationBar.appearance()
                    navBarAppearance.standardAppearance = coloredAppearance
                    navBarAppearance.compactAppearance = coloredAppearance
                    navBarAppearance.scrollEdgeAppearance = coloredAppearance
                    navBarAppearance.compactScrollEdgeAppearance = coloredAppearance
                    navBarAppearance.tintColor = .white
                    
                    SettingsManager.setupDisplayMode()
                    CrashlyticsManager.setupEnvironment()
                }
        }
    }
}
