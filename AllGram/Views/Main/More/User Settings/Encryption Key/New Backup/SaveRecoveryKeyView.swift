//
//  SaveRecoveryKeyView.swift
//  AllGram
//
//  Created by Alex Pirog on 05.08.2022.
//

import SwiftUI

struct SaveRecoveryKeyView: View {
    let key: String
    
    @State private var showingShare = false
    @State private var shareActivities: [AnyObject] = []
    @State private var showCopyToast = false
    
    var body: some View {
        ZStack {
            // Content
            content.padding()
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Key Backup")
        .sheet(isPresented: $showingShare) {
            ActivityViewController(activityItems: shareActivities)
        }
        .onChange(of: showingShare) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading) {
            Text("Your keys are being backed up")
                .font(.title)
            Text("Keep your recovery key somewhere very secure, like password manager (or a safe)")
                .foregroundColor(.gray)
                .padding(.vertical, 6)
            saveBox
                .padding(.vertical, 18)
            Spacer()
        }
    }
    
    private var saveBox: some View {
        VStack {
            // Top part
            VStack {
                HStack(alignment: .top, spacing: 16) {
                    Image("key-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .foregroundColor(.reverseColor)
                        .frame(width: 32, height: 32)
                    Text(key).bold()
                        .multilineTextAlignment(.center)
                }
                .toast(message: "Copied to Clipboard", isShowing: $showCopyToast, duration: Toast.short)
                NewBackupButton(filledTitle: "Save backup key to my device") {
                    shareActivities = [key as AnyObject]
                    withAnimation { showingShare = true }
                }
            }
            .padding(.horizontal, 16)
            // OR-Divider
            ExpandingHStack {
                Text(" OR ")
                    .foregroundColor(.gray)
                    .background(Color.backColor)
            }
            .background(Divider())
            // Bottom part
            VStack {
                NewBackupButton(strokedTitle: "Copy backup key to the Clipboard") {
                    UIPasteboard.general.string = key
                    withAnimation { showCopyToast = true }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(.backColor)
                .shadow(radius: 1)
        )
    }
}
