//
//  OnboardingAgreementTabView.swift
//  AllGram
//
//  Created by Eugene Ned on 03.08.2022.
//

import SwiftUI

import WebKit
 
struct WebViewer: UIViewRepresentable {
 
    var url: URL
 
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
 
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

struct OnboardingAgreementTabView: View {
    var body: some View {
        WebViewer(url: URL(string: "https://allgram.com/info-eula/")!)
            .padding(.horizontal)
            .shadow(radius: 10)
            }
}

struct OnboardingAgreementTabView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingAgreementTabView()
    }
}
