//
//  KeyBackupRestoreView.swift
//  AllGram
//
//  Created by Alex Pirog on 25.01.2022.
//

import SwiftUI
import MatrixSDK

struct KeyBackupRestoreView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    private func dismiss() {
        withAnimation {
            presentationMode.projectedValue.wrappedValue.dismiss()
            show = false
        }
    }
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @ObservedObject var viewModel: KeyBackupRestoreViewModel
    
    @State private var input = ""
    @State private var canContinue = false
    @State private var isImporting = false
    
    @Binding private var show: Bool
    
    init(_ viewModel: KeyBackupRestoreViewModel, showBinding: Binding<Bool> = .constant(true)) {
        self.viewModel = viewModel
        self._show = showBinding
    }
    
    var body: some View {
        ZStack {
            VStack {
                switch viewModel.state {
                case .ready(let hasProblems):
                    Text("Select your Recovery Key, or input it manually by typing it or pasting it from clipboard.")
                        .padding()
                    VStack(alignment: .leading) {
                        TextField("Enter recovery key", text: $input)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(height: Constants.textHeight)
                        if hasProblems {
                            Text("Backup couldn't be decrypted with this passphrase: please verify that you entered the correct recovery passphrase.")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    HStack {
                        Button(action: {
                            withAnimation { isImporting = true }
                        }) {
                            HStack(spacing: 0) {
                                Image("file-alt-solid")
                                    .renderingMode(.template)
                                    .resizable().scaledToFit()
                                    .foregroundColor(.accentColor)
                                    .frame(width: Constants.fileIconSize, height: Constants.fileIconSize)
                                Text("Use file")
                                    .foregroundColor(.accentColor)
                                    .padding()
                            }
                        }
                        Spacer()
                        Button(action: {
                            withAnimation {
                                loadingHint = "Recovering from backup..."
                                showingLoading = true
                                viewModel.recoverBackup(with: input) { result in
                                    withAnimation {
                                        showingLoading = false
                                        switch result {
                                        case .success(_):
                                            successHint = "Recovered from backup."
                                            showingSuccess = true
                                        case .failure(let error):
                                            failureHint = "Failed to recover from backup. \(error.localizedDescription)"
                                            showingFailure = true
                                        }
                                    }
                                }
                            }
                        }) {
                            Text("Continue")
                                .foregroundColor(.accentColor)
                                .padding()
                        }
                        .disabled(!canContinue)
                    }
                    .padding()
                case .restored(let foundKeys, let importedKeys):
                    Text("Backup Restored!").bold()
                        .padding()
                    HStack {
                        Spacer()
                        Text("Restored and backed up with \(importedKeys) out of \(foundKeys) key(s).")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    NiceButton(title: "DONE", appearance: .filled) {
                        dismiss()
                    }
                    .padding()
                }
                Spacer()
            }
            .padding(.horizontal)
            if showingLoading { loadingAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitle("Recovery Key")
        .onChange(of: input) { value in
            // TODO: Provide actual continue checking (if needed)
            canContinue = value.hasContent
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            withAnimation {
                switch result {
                case .success(let urls):
                    switch viewModel.handleSelectedFile(at: urls.first) {
                    case .success(let key):
                        input = key
                    case .failure(let error):
                        failureHint = "Failed to select file.\n\(error.localizedDescription)"
                        showingFailure = true
                    }
                case .failure(let error):
                    failureHint = "Failed to select file.\n\(error.localizedDescription)"
                    showingFailure = true
                }
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
    
    // MARK: - Success Alert
    
    @State private var showingSuccess = false
    @State private var successHint: String?
    
    private var successAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingSuccess) {
            InfoAlertView(title: "Success", subtitle: successHint, shown: $showingSuccess)
                .onDisappear {
                    dismiss()
                }
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
        static let fileIconSize: CGFloat = 40
        static let warningIconSize: CGFloat = 30
        static let textHeight: CGFloat = 48
    }
    
}

//struct KeyBackupRestoreView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            NavigationView {
//                KeyBackupRestoreView(viewModel: KeyBackupRestoreViewModel(backupService: KeyBackupService(crypto: nil)))
//            }
//            .colorScheme(.dark)
//            .previewDevice("iPhone 11")
////            NavigationView {
//                KeyBackupRestoreView(viewModel: KeyBackupRestoreViewModel(backupService: KeyBackupService(crypto: nil)))
////            }
//            .colorScheme(.light)
//            .previewDevice("iPhone 8 Plus")
//        }
//    }
//}

