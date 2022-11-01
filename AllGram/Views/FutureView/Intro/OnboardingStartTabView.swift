//
//  OnboardingStartTabView.swift
//  AllGram
//
//  Created by Eugene Ned on 02.08.2022.
//

import SwiftUI
import WebKit

struct YouTubeVideoViewer: UIViewRepresentable {
    let videoID: String
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let youtubeURL = URL(string: "https://www.youtube.com/embed/\(videoID)") else { return }
        uiView.scrollView.isScrollEnabled = false
        uiView.load(URLRequest(url: youtubeURL))
    }
}

struct OnboardingStartTabView: View {
    
    let pageTitle: String
    let pageDescription: String
    @Binding var showVideo: Bool
    
    
    var body: some View {
        VStack {
            Image("promoPreview")
                .resizable()
                .scaledToFit()
                .overlay(
                    Button(action: { withAnimation { self.showVideo = true }  }, label: {
                        HStack{
                            Image("play-solid")
                                .renderingMode(.template)
                                .foregroundColor(.white)
                            
                            Text("Play video presentation")
                                .font(.subheadline)
                                .bold()
                                .kerning(0.1)
                                .foregroundColor(.white)
                        }
                        .frame(width: 228, height: 48)
                    })
                    .background(Color("onboardingPlayButton"))
                    .cornerRadius(36)
                    .padding(.bottom, 32)
                    , alignment: .bottom)
            Spacer()
            Text(pageTitle)
                .font(.title2)
                .bold()
                .padding([.bottom, .horizontal])
            Text(pageDescription)
                .font(.subheadline)
                .kerning(0.25)
                .padding([.horizontal, .bottom])
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(0.6)
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct OnboardingStartTabView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingStartTabView(pageTitle: "Hi there!", pageDescription: "We will now introduce you to the basic features of allgram", showVideo: .constant(false))
    }
}
