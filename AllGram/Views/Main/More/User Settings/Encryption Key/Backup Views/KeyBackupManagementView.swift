//
//  KeyBackupManagementView.swift
//  AllGram
//
//  Created by Alex Pirog on 24.01.2022.
//

import SwiftUI
import MatrixSDK

struct KeyBackupManagementView: View {
    
    @ObservedObject var viewModel: KeyBackupManagementViewModel
    
    @State private var restoreVersion: MXKeyBackupVersion?
    @State private var showRestore = false
    
    var body: some View {
        ZStack {
            // Navigation
            VStack {
                NavigationLink(
                    destination:
                        Group {
                            if let version = restoreVersion {
                                KeyBackupRestoreView(viewModel.getRestoreVM(with: version))
                            } else {
                                EmptyView()
                            }
                        }
                    , isActive: $showRestore
                ) {
                    EmptyView()
                }
            }
            // Content
            VStack {
                HStack(spacing: 0) {
                    Spacer()
                    Text(viewModel.usingInfo)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
                .padding(.horizontal)
                switch viewModel.state {
                case .checking:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                        .scaleEffect(Constants.alertSpinnerScale)
                        .padding(.all, Constants.alertSpinnerPadding)
                case .noBackup:
                    NavigationLink(destination: KeyBackupSetupView(viewModel: viewModel.getSetupVM())) {
                        Text("Start using key backup")
                            .foregroundColor(.backColor)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: Constants.buttonCorner).foregroundColor(.accentColor))
                    }
                case .backup(let version, let state):
                    VStack {
                        if case .validBackup = state {
                            Text("Already restored to the latest backup")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            Button {
                                restoreVersion = version
                                withAnimation { showRestore = true }
                            } label: {
                                Text("Restore from backup")
                                    .foregroundColor(.backColor)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: Constants.buttonCorner)
                                                    .foregroundColor(.accentColor)
                                    )
                            }
                        }
                        Button(action: { showingDeleteAlert = true }) {
                            Text("Delete backup")
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                case .error(_):
                    EmptyView()
                }
                Spacer()
            }
            if showingDeleteAlert { deleteAlert }
            if showingLoading { loadingAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitle("Key Backup")
        .onAppear { viewModel.update() }
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
                withAnimation {
                    loadingHint = "Deleting your backup..."
                    showingLoading = true
                    viewModel.deleteBackup() { result in
                        showingLoading = false
                        switch result {
                        case .success():
                            successHint = "Your backup deleted successfully"
                            showingSuccess = true
                        case .failure(let error):
                            failureHint = "Failed to delete backup. \(error.localizedDescription)"
                            showingFailure = true
                        }
                    }
                }
            }
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
    
    // MARK: - Loading Alert
    
    @State private var showingLoading = false
    @State private var loadingHint: String?
    
    private var loadingAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoading) {
            LoaderAlertView(title: "Loading...", subtitle: loadingHint, shown: $showingLoading)
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let buttonCorner: CGFloat = 8
        static let alertSpinnerScale: CGFloat = 2
        static let alertSpinnerPadding: CGFloat = 20
    }
    
}

struct KeyBackupManagementView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                KeyBackupManagementView(viewModel: KeyBackupManagementViewModel(backupService: KeyBackupService(crypto: nil)))
            }
            .colorScheme(.dark)
            .previewDevice("iPhone 11")
//            NavigationView {
                KeyBackupManagementView(viewModel: KeyBackupManagementViewModel(backupService: KeyBackupService(crypto: nil)))
//            }
            .colorScheme(.light)
            .previewDevice("iPhone 8 Plus")
        }
    }
}

