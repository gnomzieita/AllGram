//
//  ManageBackupView.swift
//  AllGram
//
//  Created by Alex Pirog on 08.08.2022.
//

import SwiftUI

struct ManageBackupView: View {
    @ObservedObject var viewModel: NewKeyBackupViewModel
    
    @State private var forceCreate = false
    
    init(_ viewModel: NewKeyBackupViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Content
            content
                .onAppear {
                    viewModel.updateState() { result in
                        switch result {
                        case .success(()):
                            break
                        case .failure(let error):
                            failureHint = "Failed to check backup state. \(error.localizedDescription)"
                            withAnimation { showingFailure = true }
                        }
                    }
                }
            // Custom alerts
            if showingDeleteAlert { deleteAlert }
            if showingLoading { loadingAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Key Backup")
    }
    
    @ViewBuilder
    private var content: some View {
        if let key = viewModel.recoveryKey {
            SaveRecoveryKeyView(key: key)
                .onDisappear {
                    viewModel.recoveryKey = nil
                    forceCreate = false
                }
        } else if forceCreate {
            CreateBackupView(viewModel)
                .onDisappear {
                    forceCreate = false
                }
        } else {
            switch viewModel.state {
            case .unknown:
                // Theoretically will only happen in initial state, but
                // should start checking right away and other cases...
                checkingBackupView(hint: "Checking...")
                
            case .checkingBackup:
                checkingBackupView(hint: "Checking...")
                
            case .backupInProgress:
                checkingBackupView(hint: "Recovering your data...")
                
            case .noBackup:
                CreateBackupView(viewModel)
                
            case .unverifiedBackup:
                RestoreBackupView(viewModel, showCreate: $forceCreate)
                
            case .validBackup:
                validBackupView
            }
        }
    }
    
    // MARK: -
    
    private func checkingBackupView(hint: String) -> some View {
        VStack {
            // Text
            ExpandingHStack {
                Text(hint)
                    .padding()
            }
            // Spinner
            Spinner()
                .scaleEffect(2)
                .padding()
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Has Backup States
    
    private var validBackupView: some View {
        VStack {
            Text("Key backup has been correctly set up.")
                .bold()
                .multilineTextAlignment(.center)
                .padding()
                .padding(.horizontal)
            Text("Already restored to the latest backup")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal)
            NewBackupButton(destructiveTitle: "Delete backup") {
                withAnimation { showingDeleteAlert = true }
            }
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Delete Alert
    
    @State private var showingDeleteAlert = false
    
    private var deleteAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingDeleteAlert) {
            ConfirmAlertView(
                title: "Delete Backup",
                subtitle: "Delete your backed up encryption keys from the endpoint?\nYou will no longer be able to use your recovery key to read encrypted message history.",
                shown: $showingDeleteAlert
            ) { confirmed in
                guard confirmed else { return }
                loadingHint = "Deleting your backup..."
                withAnimation { showingLoading = true }
                viewModel.deleteBackup() { result in
                    withAnimation { showingLoading = false }
                    switch result {
                    case .success(_):
                        successHint = "Your backup deleted successfully."
                        withAnimation { showingSuccess = true }
                    case .failure(let error):
                        failureHint = "Failed to delete backup. \(error.localizedDescription)"
                        withAnimation { showingFailure = true }
                    }
                }
            }
        }
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
