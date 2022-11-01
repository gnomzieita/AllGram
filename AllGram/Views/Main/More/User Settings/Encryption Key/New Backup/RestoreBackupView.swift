//
//  RestoreBackupView.swift
//  AllGram
//
//  Created by Alex Pirog on 05.08.2022.
//

import SwiftUI

struct RestoreBackupView: View {
    @ObservedObject var viewModel: NewKeyBackupViewModel
    
    /// Will be set to `true` when `Create` option is selected
    @Binding var showCreate: Bool
    
    @State private var input = ""
    @State private var isImporting = false
    
    init(_ viewModel: NewKeyBackupViewModel, showCreate: Binding<Bool>) {
        self.viewModel = viewModel
        self._showCreate = showCreate
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
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                switch handleSelectedFile(at: urls.first) {
                case .success(let key):
                    withAnimation { input = key }
                case .failure(let error):
                    failureHint = "Failed to select file. \(error.localizedDescription)"
                    withAnimation { showingFailure = true }
                }
            case .failure(let error):
                failureHint = "Failed to select file. \(error.localizedDescription)"
                withAnimation { showingFailure = true }
            }
        }
        .onChange(of: isImporting) { show in
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
        VStack(spacing: 16) {
            Text("Use your Recovery Key to unlock your encrypted messages history")
                .bold()
                .multilineTextAlignment(.center)
                .padding()
                .padding(.horizontal)
            TextField("Recovery Key", text: $input)
                .frame(height: 48)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder()
                        .foregroundColor(.gray)
                )
            NewBackupButton(strokedTitle: "Select the key from my device") {
                withAnimation { isImporting = true }
            }
            NewBackupButton(filledTitle: "USE MY BACKUP KEY") {
                loadingHint = "Validating recovery key..."
                withAnimation { showingLoading = true }
                viewModel.recoverBackup(with: input) { result in
                    withAnimation { showingLoading = false }
                    switch result {
                    case .success(_):
                        successHint = "Recovery key is valid."
                        withAnimation { showingSuccess = true }
                    case .failure(let error):
                        failureHint = "Failed to validate recovery key. \(error.localizedDescription)"
                        withAnimation { showingFailure = true }
                    }
                }
            }
            .disabled(!input.hasContent)
            alertBox
            Spacer()
        }
    }
    
    private var alertBox: some View {
        VStack {
            HStack(alignment: .top, spacing: 16) {
                Image("exclamation-triangle-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading) {
                    Text("Lost your recovery key?").bold()
                        .foregroundColor(.black.opacity(0.8))
                    Text("Messages in encrypted clubs and chats are secured with the keys to read these messages. Securely back up your keys to avoid losing them.")
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            NewBackupButton("Create backup key", titleColor: .allgramMain, style: .stroked, buttonColor: .allgramMain) {
                withAnimation { showCreate = true }
            }
        }
        .padding(.all, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(Color(hex: "#F7F3D7"))
                .shadow(radius: 1)
        )
    }
    
    // MARK: - Handling file
    
    private func handleSelectedFile(at url: URL?) -> Result<String, Error> {
        guard let selectedFile: URL = url else {
            return .failure(KeyBackupError.fileNotSelected)
        }
        if selectedFile.startAccessingSecurityScopedResource() {
            defer { selectedFile.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: selectedFile),
                  let key = String(data: data, encoding: .utf8)
            else {
                return .failure(KeyBackupError.fileFailedToGetContent)
            }
            return .success(key)
        } else {
            return .failure(KeyBackupError.fileNoAccess)
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
