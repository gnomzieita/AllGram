//
//  SettingsFormView.swift
//  AllGram
//
//  Created by Alex Pirog on 14.07.2022.
//

import SwiftUI
import Kingfisher

struct SettingsFormView: View {
    @Environment(\.presentationMode) var presentationMode
    
    /// Cache size of all images loaded with Kingfisher
    @State private var cacheSize: UInt = 0
    
    private var humanCacheSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(cacheSize), countStyle: .binary)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                content
                if showingLoader { loaderAlert }
            }
            .onAppear {
                KingfisherManager.shared.cache.calculateDiskStorageSize { result in
                    switch result {
                    case .success(let bytes):
                        cacheSize = bytes
                    case .failure(_):
                        break
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var content: some View {
        Form {
            Section {
                NavigationLink(destination: AccountFormView()) {
                    UserSettingsOptionView(iconName: "user-cog-solid", title: "Account", subtitle: "Your account information", iconForegroundColor: .primary)
                }
                NavigationLink(destination: NotificationsSettingsView()) {
                    UserSettingsOptionView(iconName: "bell", title: "Notifications", subtitle: "Notification settings", iconForegroundColor: .primary)
                }
                NavigationLink(destination: AppearanceSettingsView()) {
                    UserSettingsOptionView(iconName: "image-solid", title: "Appearance", subtitle: "The look and feel of your app", iconForegroundColor: .primary)
                }
                NavigationLink(destination: LanguageSettingsView()) {
                    UserSettingsOptionView(iconName: "globe-solid", title: "Language", subtitle: LocalisationManager.shared.currentLanguage.optionDescription, iconForegroundColor: .primary)
                }
                Button {
                    loaderInfo = "Clearing cache..."
                    showingLoader = true
                    KingfisherManager.shared.cache.clearCache {
                        showingLoader = false
                        cacheSize = 0
                    }
                } label: {
                    UserSettingsOptionView(iconName: "broom-solid", title: "Clear media cache", subtitle: "\(humanCacheSize)", iconForegroundColor: .primary)
                }
                NavigationLink(destination: SecurityView()) {
                    UserSettingsOptionView(iconName: "user-shield-solid", title: "Security", subtitle: "Set security password or fingerprint", iconForegroundColor: .primary)
                }
            }
        }
        .padding(.top, 1)
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            leading:
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Close")
                }
        )
    }
    
    @State private var showingLoader = false
    @State private var loaderInfo: String?
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showingLoader)
        }
    }
}
