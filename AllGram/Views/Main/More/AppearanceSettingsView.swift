//
//  AppearanceSettingsView.swift
//  AllGram
//
//  Created by Ярослав Шерстюк on 08.09.2021.
//

import SwiftUI

struct ColorThemeBoxView: View {
    let title: String
    let isSelected: Bool
    let backColor: Color
    let myMessageColor: Color
    let otherMessageColor: Color
    
    init(title: String, isSelected: Bool, backColor: Color, myMessageColor: Color, otherMessageColor: Color) {
        self.title = title
        self.isSelected = isSelected
        self.backColor = backColor
        self.myMessageColor = myMessageColor
        self.otherMessageColor = otherMessageColor
    }
    
    var body: some View {
        VStack {
            // Message bubbles
            VStack(spacing: 8) {
                Rectangle()
                    .fill(myMessageColor)
                    .clipShape(Capsule())
                    .padding(.leading, 24)
                    .frame(height: Constants.bubbleHeight)
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(otherMessageColor)
                        .clipShape(Capsule())
                        .padding(.trailing, 36)
                        .frame(height: Constants.bubbleHeight)
                    Rectangle()
                        .fill(otherMessageColor)
                        .clipShape(Capsule())
                        .padding(.trailing, 24)
                        .frame(height: Constants.bubbleHeight)
                }
                Rectangle()
                    .fill(myMessageColor)
                    .clipShape(Capsule())
                    .padding(.leading, 36)
                    .frame(height: Constants.bubbleHeight)
            }
            .frame(height: 120)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.gray, lineWidth: 0.5)
            )
            // Box title
            Text(title)
            // Selected circle
            Image(systemName: isSelected ? "checkmark.circle" : "circle")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(isSelected ? .accentColor : .gray)
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let bubbleHeight: CGFloat = 12
    }
}

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    @State private var theme = SettingsManager.colorTheme
    
    var body: some View {
        Form {
            Section(header: Text("Color Theme")) {
                HStack {
                    automaticBox
                    lightBox
                    darkBox
                }
                .padding(.vertical, 16)
            }
            .onChange(of: theme) { newValue in
                SettingsManager.colorTheme = theme
            }
            Section(header: Text("General")) {
                NavigationLink(destination: HomeBackgroundSettingsView()) {
                    MoreOptionView("Change Home Background", imageName: "images-solid")
                }
                NavigationLink(destination: ChatBackgroundSettingsView()) {
                    MoreOptionView("Change Chat Background", imageName: "images-solid")
                }
            }
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitle("Appearance Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var automaticBox: some View {
        ColorThemeBoxView(
            title: "Auto",
            isSelected: theme == .automatic,
            backColor: colorScheme == .light ? .white : .black,
            myMessageColor: colorScheme == .light ? .orange : .pink,
            otherMessageColor: colorScheme == .light ? .gray : .white
        )
            .padding(2)
            .onTapGesture {
                withAnimation { theme = .automatic }
            }
    }
    
    private var lightBox: some View {
        ColorThemeBoxView(
            title: "Light",
            isSelected: theme == .light,
            backColor: .white,
            myMessageColor: .orange,
            otherMessageColor: .gray
        )
            .padding(2)
            .onTapGesture {
                withAnimation { theme = .light }
            }
    }
    
    private var darkBox: some View {
        ColorThemeBoxView(
            title: "Dark",
            isSelected: theme == .dark,
            backColor: .black,
            myMessageColor: .pink,
            otherMessageColor: .white
        )
            .padding(2)
            .onTapGesture {
                withAnimation { theme = .dark }
            }
    }
}
