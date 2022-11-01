//
//  NotificationsSettingsView.swift
//  AllGram
//
//  Created by Eugene Ned on 18.07.2022.
//

import SwiftUI

struct NotificationsSettingsView: View {
    
    @StateObject var VM = NotificationSettingsViewModel()
    
    var body: some View {
        contentView()
            .alert(isPresented: $VM.showAlert) {
                alertView
            }
            .navigationBarTitle("Notifications")
    }
    
    private var alertView: Alert {
        if case .error(.downloading) = VM.state {
            return Alert(
                title: Text("Error"),
                message: Text("Failed to download your data"),
                primaryButton: .default(
                    Text("Try again"),
                    action: { VM.getCurrentNotificationSettings() }
                ),
                secondaryButton: .cancel())
        } else {
            return Alert(
                title: Text("Error"),
                message: Text("Failed to upload your data, please check your internet connection and try again"),
                dismissButton: .default(Text("Ok")))
        }
        
    }
    
    @ViewBuilder func contentView() -> some View {
        switch VM.state {
        case .loading(.downloading):
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                .scaleEffect(2)
        case .received, .error, .loading(.uploading):
            Form {
                Section {
                    Toggle("Chat notifications", isOn: $VM.enableChatNotifications)
                        .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                    Toggle("Club notifications", isOn: $VM.enableClubNotifications)
                        .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                    Toggle("Meeting notifications", isOn: $VM.enableMeetingNotifications)
                        .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                }
            }
            .background(Color.moreBackColor.ignoresSafeArea())
            .disabled(VM.state == .loading(.uploading))
        }
    }
}

struct NotificationsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsSettingsView()
            .preferredColorScheme(.dark)
        NotificationsSettingsView()
            .preferredColorScheme(.light)
    }
}
