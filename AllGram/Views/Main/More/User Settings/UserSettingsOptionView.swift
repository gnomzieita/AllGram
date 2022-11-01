//
//  UserSettingsOptionView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 20.12.2021.
//

import SwiftUI

struct UserSettingsOptionView: View {
    
    let icon: Image
    let title: String
    let subtitle: String
    let iconForegroundColor: Color
    
    init(icon: Image, title: String, subtitle: String, iconForegroundColor: Color = .accentColor) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconForegroundColor = iconForegroundColor
    }
    
    init(iconSystemName: String, title: String, subtitle: String, iconForegroundColor: Color = .accentColor) {
        self.icon = Image(systemName: iconSystemName)
        self.title = title
        self.subtitle = subtitle
        self.iconForegroundColor = iconForegroundColor
    }
    
    init(iconName: String, title: String, subtitle: String, iconForegroundColor: Color = .accentColor) {
        self.icon = Image(iconName)
        self.title = title
        self.subtitle = subtitle
        self.iconForegroundColor = iconForegroundColor
    }
    
    var body: some View {
        HStack(spacing: Constants.iconSpacing) {
            icon
                .resizable()
                .renderingMode(.template)
                .foregroundColor(iconForegroundColor)
                .scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Constants.verticalPadding)
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let iconSpacing: CGFloat = 24
        static let verticalPadding: CGFloat = 6
    }
    
}

struct UserSettingsOptionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Form {
                Section {
                    UserSettingsOptionView(iconSystemName: "person.crop.circle.fill",
                                           title: "Name Surname",
                                           subtitle: "Display name")
                    UserSettingsOptionView(iconSystemName: "lock.circle.fill",
                                           title: "Password",
                                           subtitle: "Set new account password")
                    UserSettingsOptionView(iconSystemName: "envelope.circle.fill",
                                           title: "Email & Phone",
                                           subtitle: "Change email and phone number")
                    UserSettingsOptionView(iconSystemName: "exclamationmark.shield.fill",
                                           title: "Security",
                                           subtitle: "Set security password or fingerpring")
                    UserSettingsOptionView(iconSystemName: "paintbrush.fill",
                                           title: "Clear media cache",
                                           subtitle: "??? MB")
                }
                Section {
                    UserSettingsOptionView(iconSystemName: "qrcode",
                                           title: "My QR code",
                                           subtitle: "Share this code with others and start chatting")
                }
                Section {
                    UserSettingsOptionView(iconSystemName: "key.fill",
                                           title: "Encryption key management",
                                           subtitle: "Manage message encryption keys")
                }
            }
            .colorScheme(.dark)
            Form {
                Section {
                    UserSettingsOptionView(iconSystemName: "person.crop.circle.fill",
                                           title: "Name Surname",
                                           subtitle: "Display name")
                    UserSettingsOptionView(iconSystemName: "lock.circle.fill",
                                           title: "Password",
                                           subtitle: "Set new account password")
                    UserSettingsOptionView(iconSystemName: "envelope.circle.fill",
                                           title: "Email & Phone",
                                           subtitle: "Change email and phone number")
                    UserSettingsOptionView(iconSystemName: "exclamationmark.shield.fill",
                                           title: "Security",
                                           subtitle: "Set security password or fingerpring")
                    UserSettingsOptionView(iconSystemName: "paintbrush.fill",
                                           title: "Clear media cache",
                                           subtitle: "??? MB")
                }
                Section {
                    UserSettingsOptionView(iconSystemName: "qrcode",
                                           title: "My QR code",
                                           subtitle: "Share this code with others and start chatting")
                }
                Section {
                    UserSettingsOptionView(iconSystemName: "key.fill",
                                           title: "Encryption key management",
                                           subtitle: "Manage message encryption keys")
                }
            }
            .colorScheme(.light)
        }
    }
}
