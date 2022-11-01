//
//  InfoWebView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 15.12.2021.
//

import SwiftUI

struct InfoWebView: View {
    
    enum InfoOption {
        case privacyStatement
        case termsAndConditions
        case communityGuidelines
        
        var title: LocalizedStringKey {
            switch self {
            case .privacyStatement:
                return nL10n.PrivacyStatement.title
            case .termsAndConditions:
                return nL10n.TermsAndConditions.title
            case .communityGuidelines:
                return nL10n.CommunityGuidelines.title
            }
        }
        
        var url: URL {
            switch self {
            case .privacyStatement:
                return URL(string: "https://allgram.com/info-pp")!
            case .termsAndConditions:
                return URL(string: "https://allgram.com/info-terms")!
            case .communityGuidelines:
                return URL(string: "https://allgram.com/info-cg")!
            }
        }
    }
    
    let option: InfoOption
    
    init(_ option: InfoOption) {
        self.option = option
    }
    
    var body: some View {
        WebView(url: option.url)
            .navigationTitle(option.title)
            .navigationBarTitleDisplayMode(.inline)
    }
    
}

struct InfoWebView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InfoWebView(.privacyStatement)
        }
    }
}
