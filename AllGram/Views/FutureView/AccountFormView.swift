//
//  AccountFormView.swift
//  AllGram
//
//  Created by Alex Pirog on 14.07.2022.
//

import SwiftUI
import MatrixSDK

struct AccountFormView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    // Handling profile photo
    @State private var showingProfileImageOptions = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var showingImagePicker = false
    @State private var showImagePruning = false
    
    // Handling display name
    @State private var showingDisplayNameChange = false
    @State private var displayName: String = ""
    @State private var displayNameChanged = false
    
    // Handling password
    @State private var showingPasswordChange = false
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var passwordChanged = false
    
    @ObservedObject var sessionVM = (AuthViewModel.shared.sessionVM)!
    
    var body: some View {
        ZStack {
            content
            if showingDisplayNameChange { changingDisplayNameAlert }
            if showingPasswordChange { changingPasswordAlert }
            if showingLoader { loaderAlert }
            if showingFailure { failureAlert }
        }
        .actionSheet(isPresented: $showingProfileImageOptions) {
            ActionSheet(
                title: Text("Set Profile Photo"),
                buttons: [
                    .default(Text("Take Photo")) {
                        switch PermissionsManager.shared.getAuthStatusFor(.video) {
                        case .notDetermined: // User has not yet been asked for camera access
                            AVCaptureDevice.requestAccess(for: .video) { response in
                                if response {
                                    sourceType = .camera
                                    showingImagePicker = true
                                } else {
                                    permissionAlertText = "camera"
                                    showPermissionAlert = true
                                }
                            }
                        case .authorized:
                            sourceType = .camera
                            showingImagePicker = true
                        default:
                            permissionAlertText = "camera"
                            showPermissionAlert = true
                        }
                    },
                    .default(Text("Choose Photo")) {
                        sourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                sourceType: sourceType,
                restrictToImagesOnly: true,
                allowDefaultEditing: false,
                createVideoThumbnail: false,
                onImagePicked: { image in
                    withAnimation {
                        imageToEdit = image
                        showImagePruning = true
                    }
                },
                onVideoPicked: nil
            )
        }
        .onChange(of: showingImagePicker) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
        .fullScreenCover(isPresented: $showImageEditor) {
            imageEditorView
        }
        .onChange(of: imageToEdit) { newValue in
            withAnimation { showImageEditor = newValue != nil }
        }
        .onDisappear() {
            // Reset display name
            showingDisplayNameChange = false
            displayNameChanged = false
            displayName = authViewModel.session?.myUser.displayname ?? "noname"
            // Reset password
            showingPasswordChange = false
            passwordChanged = false
            oldPassword = ""
            newPassword = ""
            // Hide loader
            showingLoader = false
            loaderInfo = ""
        }
        .alert(isPresented: $showPermissionAlert) {
            permissionAlertView
        }
    }
    
        
    
    
    @State private var showPermissionAlert = false
    @State private var permissionAlertText = ""
    
    private var permissionAlertView: Alert {
        return Alert(
            title: Text("Access to \(permissionAlertText)"),
            message: Text("Tap Settings and enable \(permissionAlertText)"),
            primaryButton: .default(
                Text("Settings"),
                action: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            ),
            secondaryButton: .cancel()
        )
    }
    
    private var content: some View {
        Form {
            Section {
                Button {
                    withAnimation { showingProfileImageOptions = true }
                } label: {
                    HStack(spacing: 0) {
                        AvatarImageView(authViewModel.sessionVM?.userAvatarURL, name: authViewModel.session?.myUser.displayname ?? "MY")
                            .frame(width: 44, height: 44)
                            .padding(.trailing, 24)
                        Text("Change user avatar")
                            .font(.headline)
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 6)
                }
                Button {
                    withAnimation { showingDisplayNameChange = true }
                } label: {
                    UserSettingsOptionView(iconName: "address-book", title: "Change display name", subtitle: "\(authViewModel.session?.myUser.displayname ?? " ")", iconForegroundColor: .primary)
                }
                Button {
                    withAnimation { showingPasswordChange = true }
                } label: {
                    UserSettingsOptionView(iconName: "lock-solid", title: "Change Password", subtitle: "Set a new account password", iconForegroundColor: .primary)
                }
                NavigationLink(destination: DeactivateAccountView(password: "")) {
                    UserSettingsOptionView(iconName: "user-slash-solid", title: "Deactivate account", subtitle: "Deactivate account configuration", iconForegroundColor: .primary)
                }
            }
        }
        .padding(.top, 1)
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: -
    
    @State private var showImageEditor = false
    @State private var imageToEdit: UIImage?
    
    @ViewBuilder
    private var imageEditorView: some View {
        NavigationView {
            if let image = imageToEdit {
                ImageEditor(
                    originalImage: image,
                    cropHandler: { cropped in
                        imageToEdit = nil
                        withAnimation {
                        guard let data = cropped.jpeg(.medium),
                              let session = authViewModel.session,
                              let uploader = MXMediaManager.prepareUploader(withMatrixSession: session, initialRange: 0, andRange: 1)
                        else {
                            failureInfo = "Failed to change avatar."
                            showingFailure = true
                            return
                        }
                            loaderInfo = "Uploading new avatar..."
                            showingLoader = true
                            uploader.uploadData(
                                data,
                                filename: nil,
                                mimeType: "image/jpeg",
                                success: { urlString in
                                    loaderInfo = "Setting new avatar..."
                                    sessionVM.setAvatar(uri: urlString!) { success in
                                        if success {
                                            showingLoader = false
                                        } else {
                                            showingLoader = false
                                            failureInfo = "Failed to set new avatar."
                                            showingFailure = true
                                        }
                                    }
//                                    session.myUser.setAvatarUrl(
//                                        urlString,
//                                        success: {
//                                            authViewModel.sessionVM?.updateAvatarURL()
//                                            showingLoader = false
//                                        },
//                                        failure: { error in
//                                            showingLoader = false
//                                            failureInfo = "Failed to set new avatar."
//                                            + (error != nil ? "\n\(error!.localizedDescription)" : "")
//                                            showingFailure = true
//                                        }
//                                    )
                                },
                                failure: { error in
                                    showingLoader = false
                                    failureInfo = "Failed to upload new avatar."
                                    + (error != nil ? "\n\(error!.localizedDescription)" : "")
                                    showingFailure = true
                                }
                            )
                        }
                    },
                    cancelHandler: {
                        imageToEdit = nil
                    }
                )
                    .background(Color.black.edgesIgnoringSafeArea(.bottom))
                    .navigationBarTitle("Image Editor")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyView()
                    .onAppear {
                        showImageEditor = false
                    }
            }
        }
    }
    
    // MARK: -
    
    @State private var loaderInfo = ""
    @State private var showingLoader = false
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showingLoader)
        }
    }
    
    @State private var failureInfo = ""
    @State private var showingFailure = false
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: failureInfo, shown: $showingFailure)
        }
    }
    
    // MARK: -
    
    private var changingDisplayNameAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingDisplayNameChange) {
            TextInputAlertView(title: "Display Name", textInput: $displayName, inputPlaceholder: "Display name", success: $displayNameChanged, shown: $showingDisplayNameChange)
                .onDisappear() {
                    withAnimation {
                        guard displayNameChanged else {
                            displayName = authViewModel.session?.myUser.displayname ?? "noname"
                            return
                        }
                        loaderInfo = "Changing display name..."
                        showingLoader = true
                        authViewModel.session?.myUser.setDisplayName(
                            displayName,
                            success: {
                                displayName = authViewModel.session?.myUser.displayname ?? "noname"
                                showingLoader = false
                            },
                            failure: { error in
                                displayName = authViewModel.session?.myUser.displayname ?? "noname"
                                showingLoader = false
                                failureInfo = "Failed to change display name"
                                showingFailure = true
                            }
                        )
                    }
                }
        }
    }
    
    private var changingPasswordAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingPasswordChange) {
            ChangePasswordAlertView(passwordInput: $oldPassword, passwordOutput: $newPassword, success: $passwordChanged, shown: $showingPasswordChange)
                .onDisappear() {
                    withAnimation {
                        guard passwordChanged else {
                            oldPassword = ""
                            newPassword = ""
                            return
                        }
                        loaderInfo = "Changing password..."
                        showingLoader = true
                        authViewModel.client?.changePassword(from: oldPassword, to: newPassword) { response in
                            switch response {
                            case .success():
                                showingLoader = false
                            case .failure(_):
                                showingLoader = false
                                failureInfo = "Failed to change password"
                                showingFailure = true
                            }
                        }
                    }
                }
        }
    }
}
