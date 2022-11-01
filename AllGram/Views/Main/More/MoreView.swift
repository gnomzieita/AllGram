//
//  MoreView.swift
//  AllGrammDev
//
//  Created by Ярослав Шерстюк on 31.08.2021.
//

import SwiftUI

struct MoreOptionView: View {
    
    let text: Text
    let icon: Image
    let foregroundColor: Color
    let badge: Int
    
    init(flat flatText: String, imageSystemName: String, foregroundColor: Color = .reverseColor, badge: Int = 0) {
        self.text = Text(verbatim: flatText)
        self.icon = Image(systemName: imageSystemName)
        self.foregroundColor = foregroundColor
        self.badge = badge
    }
    
    init(flat flatText: String, imageName: String, foregroundColor: Color = .reverseColor, badge: Int = 0) {
        self.text = Text(verbatim: flatText)
        self.icon = Image(imageName)
        self.foregroundColor = foregroundColor
        self.badge = badge
    }
    
    init(_ localisedText: LocalizedStringKey, imageSystemName: String, foregroundColor: Color = .reverseColor, badge: Int = 0) {
        self.text = Text(localisedText)
        self.icon = Image(systemName: imageSystemName)
        self.foregroundColor = foregroundColor
        self.badge = badge
    }
    
    init(_ localisedText: LocalizedStringKey, imageName: String, foregroundColor: Color = .reverseColor, badge: Int = 0) {
        self.text = Text(localisedText)
        self.icon = Image(imageName)
        self.foregroundColor = foregroundColor
        self.badge = badge
    }
    
    var body: some View {
        HStack {
            icon
                .resizable()
                .renderingMode(.template)
                .foregroundColor(self.foregroundColor)
                .frame(width: 24, height: 24)
                .padding(.trailing, 12)
                .overlay(badgeOverlay)
            text
                .foregroundColor(self.foregroundColor)
        }
        .padding(.vertical, 12)
    }
    
    private var badgeOverlay: some View {
        VStack {
            if badge > 0 {
                Text(badge > 99 ? "..." : "\(badge)")
                    .bold()
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.red)
                    )
                    .offset(x: 4, y: -8)
            }
        }
    }
    
}

struct MoreView: View {
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingQRScanner = false
    
    var body: some View {
        NavigationView {
            // Content (with tab bar)
            TabContentView() {
                content
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var content: some View {
        Form {
            Section {
                NavigationLink(destination: UserSettingView(authViewModel: authViewModel)) {
                    MoreOptionView(nL10n.UserSettings.title, imageName: "user-cog-solid")
                }
                NavigationLink(destination: InfoWebView(.privacyStatement)) {
                    MoreOptionView(nL10n.PrivacyStatement.title, imageName: "user-shield-solid")
                }
                NavigationLink(destination: InfoWebView(.termsAndConditions)) {
                    MoreOptionView(nL10n.TermsAndConditions.title, imageName: "clipboard-list-solid")
                }
                NavigationLink(destination: InfoWebView(.communityGuidelines)) {
                    MoreOptionView(nL10n.CommunityGuidelines.title, imageName: "file-alt-solid")
                }
                NavigationLink(destination: DeactivateAccountView(password: "")) {
                    MoreOptionView(nL10n.DeactivateAccount.title, imageName: "user-slash-solid")
                }
                NavigationLink(destination: AppearanceSettingsView()) {
                    MoreOptionView(nL10n.AppearanceSettings.title, imageName: "image-solid")
                }
                NavigationLink(destination: LanguageSettingsView())  {
                    MoreOptionView(nL10n.LanguageSettings.title, imageName: "globe-solid")
                }
                NavigationLink(destination: AboutView()) {
                    MoreOptionView(nL10n.About.title, imageName: "info-circle-solid", badge: SettingsManager.versionUpdateAvailable ? 1 : 0)
                }
                //Text(UserDefaults.standard.string(forKey: "PushToken"))
            }
        }
        .padding(.top, 1)
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationTitle(nL10n.Tabs.more)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

//struct MoreView_Previews: PreviewProvider {
//    static var previews: some View {
//        MoreView()
//    }
//}

//struct MoreOptionView_Previews: PreviewProvider {
//    static var previews: some View {
//        Form {
//            Section {
//                MoreOptionView("Option without image", imageName: nil)
//                NavigationLink(destination: Text("Destination")) {
//                    MoreOptionView("Option with navigation link", imageName: nil)
//                }
//            }
//            Section {
//                MoreOptionView("Option with image", imageSystemName: "pencil.circle")
//                NavigationLink(destination: Text("Destination")) {
//                    MoreOptionView("Option with navigation link", imageSystemName: "pencil.circle")
//                }
//            }
//        }
//    }
//}
