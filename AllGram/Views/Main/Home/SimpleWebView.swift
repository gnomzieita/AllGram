//
//  SimpleWebView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 03.12.2021.
//

import SwiftUI
import WebKit
 
struct WebView: UIViewRepresentable {
 
    let url: URL
 
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
 
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
}

struct SimpleWebView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    let title: String
    let url: String
    
    var body: some View {
        NavigationView {
            WebView(url: URL(string: url)!)
                .navigationBarTitle(title, displayMode: .inline)
                .ourToolbar(leading:
                                        Button(action: {
                                            self.presentationMode.projectedValue.wrappedValue.dismiss()
                                        }, label: {
                                            Text("Close")
                                        })
                )
        }
    }
    
}

struct SimpleWebView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleWebView(title: "Help", url: "https://www.allgram.com/help")
    }
}
