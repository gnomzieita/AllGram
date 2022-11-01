//
//  SecurityView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 21.12.2021.
//

import SwiftUI
import MatrixSDK

struct SecurityView: View {
    
    var sid: String {
        AuthViewModel.shared.session?.credentials.sid ?? "..."
    }
    
    @State private var showCopySID = false
    
    var body: some View {
        Form {
            Section {
                Text("Session ID: \(sid)")
                    .lineLimit(1)
                    .padding(.vertical, Constants.togglePadding)
                    .onTapGesture {
                        UIPasteboard.general.string = sid
                        withAnimation { showCopySID = true }
                    }
            }
            
            NavigationLink(destination: FaceTouchIDSettingsView(),
                           label: {
                SecurityRowView(imageName: "fingerprint-solid",
                                title: "Fingerprint/FaceID protection",
                                subtitle: "Fingerprint/FaceID protection configuration")
                .accentColor(Color("reversedColor"))
            })
            
            NavigationLink(destination: IgnoredUsersView(),
                           label: {
                SecurityRowView(imageName: "user-slash-solid",
                                title: "Ignored users",
                                subtitle: "Ignored users configuration")
                .accentColor(Color("reversedColor"))
            })
        }
        .toast(message: "Copied to clipboard", isShowing: $showCopySID, duration: 2)
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitle("Security")
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let iconSpacing: CGFloat = 8
        static let togglePadding: CGFloat = 8
        static let buttonPadding: CGFloat = 10
    }
}

struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                SecurityView()
            }
            .colorScheme(.dark)
            NavigationView {
                SecurityView()
            }
            .colorScheme(.light)
        }
    }
}
