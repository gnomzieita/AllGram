//
//  LanguageSettingsView.swift
//  AllGram
//
//  Created by Alex Pirog on 20.04.2022.
//

import SwiftUI

struct LanguageSettingsView: View {
    
    @EnvironmentObject var localeViewModel: LocaleViewModel
    
    let allLanguageOptions = Language.allCases
    
    @State var currentLanguageIndex = 0
    
    var otherLanguageOptions: [Language] {
        allLanguageOptions.filter({ $0 != allLanguageOptions[currentLanguageIndex] })
    }
    
    private func updateCurrent() {
        if let index = allLanguageOptions.firstIndex(of: LocalisationManager.shared.currentLanguage) {
            withAnimation {
                currentLanguageIndex = index
            }
        }
    }
    
    var body: some View {
        VStack {
            current
            options
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationTitle(nL10n.LanguageSettings.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateCurrent()
        }
    }
    
    private var current: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                Text(nL10n.LanguageSettings.current)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.vertical)
            Text(allLanguageOptions[currentLanguageIndex].optionDescription)
                .padding(.vertical, 4)
        }
        .padding(.horizontal)
    }
    
    private var options: some View {
        VStack {
            HStack(spacing: 0) {
                Text(nL10n.LanguageSettings.otherAvailable)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.vertical)
            VStack() {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading) {
                        ForEach(otherLanguageOptions, id: \.self) { option in
                            Button(action: {
                                localeViewModel.changeLanguage(to: option)
                                updateCurrent()
                            }) {
                                Text(option.optionDescription)
                                    .padding(.vertical, 4)
                            }
                            .foregroundColor(.reverseColor)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
}
