//
//  InfoFormView.swift
//  AllGram
//
//  Created by Alex Pirog on 14.07.2022.
//

import SwiftUI

struct InfoFormView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showIntro = false
    
    var body: some View {
        NavigationView {
            content
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(isPresented: $showIntro) {
            OnboardingView(showIntro: $showIntro)
        }
    }
    
    private var content: some View {
        Form {
            Section {
                NavigationLink(destination: InfoWebView(.privacyStatement)) {
                    MoreOptionView(nL10n.PrivacyStatement.title, imageName: "user-shield-solid")
                }
                NavigationLink(destination: InfoWebView(.termsAndConditions)) {
                    MoreOptionView(nL10n.TermsAndConditions.title, imageName: "clipboard-list-solid")
                }
                NavigationLink(destination: InfoWebView(.communityGuidelines)) {
                    MoreOptionView(nL10n.CommunityGuidelines.title, imageName: "file-alt-solid")
                }
                Button {
                    showIntro = true
                } label: {
                    MoreOptionView(flat: "Show App Guide", imageName: "info-circle-solid")
                }
            }
        }
        .padding(.top, 1)
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationTitle("Info")
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
}
