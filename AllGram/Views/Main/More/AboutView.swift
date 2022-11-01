//
//  AboutView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 15.12.2021.
//

import SwiftUI

struct AboutView: View {
    
    let storeID: String = "id123456789"
    let url: String = "https://allgram.com/info-about"
    
    var body: some View {
        VStack {
            HStack {
                Text(nL10n.About.version)
                Spacer()
                Text(softwareVersion)
            }
            .padding()
            if SettingsManager.versionUpdateAvailable {
                Button(action: {
                    // TODO: Add Correct App ID
                    if let url = URL(string: "itms-apps://apple.com/app/\(storeID)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(nL10n.About.newVersion)
                        .padding(.bottom)
                }
            }
            // }
            //            Button(action: { let array = [1]; let _ = array[99] }) {
            //                Text("Test crash the App")
            //                    .foregroundColor(.red)
            //            }
            WebView(url: URL(string: url)!)
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationTitle(nL10n.About.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
}
