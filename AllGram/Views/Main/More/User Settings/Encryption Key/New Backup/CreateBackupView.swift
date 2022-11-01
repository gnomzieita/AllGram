//
//  CreateBackupView.swift
//  AllGram
//
//  Created by Alex Pirog on 05.08.2022.
//

import SwiftUI

struct CreateBackupView: View {
    @ObservedObject var viewModel: NewKeyBackupViewModel
    
    init(_ viewModel: NewKeyBackupViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Content
            content.padding()
            // Custom alerts
            if showingLoading { loadingAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Key Backup")
    }
    
    private var content: some View {
        VStack(alignment: .leading) {
            Text("Your key is not being backed up from this session")
                .font(.title)
            Text("allgram cares about your security and uses the principle of encrypted messaging. This means that your messages will be available for you to view only during the active session. If the active session ends, you log out of your account or delete the application and do not create a key for decryption, then it will not be possible to restore all messages created within this session")
                .foregroundColor(.gray)
                .padding(.vertical, 6)
            alertBox
                .padding(.vertical, 18)
            NewBackupButton(filledTitle: "Start using key backup") {
                if viewModel.backup != nil {
                    // Need to delete all old backups before creating new one
                    loadingHint = "Deleting old backups..."
                    withAnimation { showingLoading = true }
                    viewModel.deleteAllBackups { deleteResult in
                        switch deleteResult {
                        case .success(()):
                            withAnimation { loadingHint = "Backing up your data..." }
                            viewModel.createNewBackup { result in
                                withAnimation {
                                    withAnimation { showingLoading = false }
                                    switch result {
                                    case .success(_):
                                        successHint = "Your data is backed up successfully."
                                        withAnimation { showingSuccess = true }
                                    case .failure(let error):
                                        failureHint = "Failed to backup your data. \(error.localizedDescription)"
                                        withAnimation { showingFailure = true }
                                    }
                                }
                            }
                        case .failure(let error):
                            withAnimation { showingLoading = false }
                            failureHint = "Failed to delete old backups. \(error.localizedDescription)"
                            withAnimation { showingFailure = true }
                        }
                    }
                } else {
                    // No old backups, just create new one
                    loadingHint = "Backing up your data..."
                    withAnimation { showingLoading = true }
                    viewModel.createNewBackup { result in
                        withAnimation {
                            withAnimation { showingLoading = false }
                            switch result {
                            case .success(_):
                                successHint = "Your data is backed up successfully."
                                withAnimation { showingSuccess = true }
                            case .failure(let error):
                                failureHint = "Failed to backup your data. \(error.localizedDescription)"
                                withAnimation { showingFailure = true }
                            }
                        }
                    }
                }
            }
            Spacer()
        }
    }
    
    private var alertBox: some View {
        HStack(alignment: .top, spacing: 16) {
            Image("exclamation-triangle-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
            Text("Messages in encrypted clubs and chats are secured with the keys to read these messages. Securely back up your keys to avoid losing them.")
                .foregroundColor(.black.opacity(0.5))
        }
        .padding(.all, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(Color(hex: "#F7F3D7"))
                .shadow(radius: 1)
        )
    }
    
    // MARK: - Loading Alert
    
    @State private var showingLoading = false
    @State private var loadingHint: String?
    
    private var loadingAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoading) {
            LoaderAlertView(title: "Loading", subtitle: loadingHint, shown: $showingLoading)
        }
    }
    
    // MARK: - Success Alert
    
    @State private var showingSuccess = false
    @State private var successHint: String?
    
    private var successAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingSuccess) {
            InfoAlertView(title: "Success", subtitle: successHint, shown: $showingSuccess)
        }
    }
    
    // MARK: - Failure Alert
    
    @State private var showingFailure = false
    @State private var failureHint: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: failureHint, shown: $showingFailure)
        }
    }
}
