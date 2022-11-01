//
//  KeyBackupSetupView.swift
//  AllGram
//
//  Created by Alex Pirog on 24.01.2022.
//

import SwiftUI
import MatrixSDK

struct KeyBackupSetupView: View {
    
    @Environment(\.presentationMode) private var presentationMode
    
    private func dismiss() {
        withAnimation {
            presentationMode.projectedValue.wrappedValue.dismiss()
        }
    }
    
    @ObservedObject var viewModel: KeyBackupSetupViewModel
    
    @State private var showingShare = false
    
    var body: some View {
        ZStack {
            VStack {
                Image("key-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(.accentColor)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                Text(viewModel.shortInfo).bold()
                    .multilineTextAlignment(.center)
                    .padding()
                Text(viewModel.longInfo)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
                switch viewModel.state {
                case .noBackup:
                    NiceButton(title: "Start Using Key Backup", appearance: .filled) {
                        withAnimation {
                            loadingHint = "Preparing your backup keys..."
                            showingLoading = true
                            viewModel.prepareBackup() { result in
                                withAnimation {
                                    showingLoading = false
                                    switch result {
                                    case .success(_):
                                        successHint = "Your backup keys is ready"
                                        showingSuccess = true
                                    case .failure(let error):
                                        failureHint = "Failed to prepare backup keys. \(error.localizedDescription)"
                                        showingFailure = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top)
                case .pending(let key):
                    Text(key)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.vertical)
                        .padding(.horizontal, Constants.keyPadding)
                    NiceButton(title: "Save Recovery Key", appearance: .stroked) {
                        withAnimation { showingShare = true }
                    }
                    NiceButton(title: "Create Backup", appearance: .filled) {
                        withAnimation {
                            confirmHint = "Note that you will not be able to see the recovery key again after you continue with the backup."
                            showingConfirm = true
                        }
                    }
                    .padding(.top)
                case .backup:
                    NiceButton(title: "Go Back", appearance: .stroked) {
                        dismiss()
                    }
                    .padding(.top)
                }
                Spacer()
            }
            if showingConfirm { confirmAlert }
            if showingLoading { loadingAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .sheet(isPresented: $showingShare) {
            ActivityViewController(activityItems: viewModel.shareActivities)
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
    
    // MARK: - Confirm Alert
    
    @State private var showingConfirm = false
    @State private var confirmHint: String?
    
    private var confirmAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingConfirm) {
            ConfirmAlertView(title: "Create Backup", subtitle: confirmHint, shown: $showingConfirm) { confirmed in
                guard confirmed else { return }
                withAnimation {
                    loadingHint = "Backing up your data..."
                    showingLoading = true
                    viewModel.confirmBackup() { result in
                        withAnimation {
                            showingLoading = false
                            switch result {
                            case .success(_):
                                successHint = "Your data is backed up"
                                showingSuccess = true
                            case .failure(let error):
                                failureHint = "Failed to prepare backup keys. \(error.localizedDescription)"
                                showingFailure = true
                            }
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
            LoaderAlertView(title: "Loading", subtitle: loadingHint, shown: $showingLoading)
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let iconSize: CGFloat = 60
        static let keyPadding: CGFloat = 32
    }
    
}

struct KeyBackupSetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                KeyBackupSetupView(viewModel: KeyBackupSetupViewModel(backupService: KeyBackupService(crypto: nil)))
            }
            .colorScheme(.dark)
            .previewDevice("iPhone 11")
//            NavigationView {
                KeyBackupSetupView(viewModel: KeyBackupSetupViewModel(backupService: KeyBackupService(crypto: nil)))
//            }
            .colorScheme(.light)
            .previewDevice("iPhone 8 Plus")
        }
    }
}
