//
//  UserSettingView.swift
//  AllGrammDev
//
//  Created by Ярослав Шерстюк on 02.09.2021.
//

import SwiftUI
import Kingfisher

struct UserSettingView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    // Handling profile photo
    @State private var showingProfileImageOptions = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    @State private var showingImagePicker = false
    @State private var showImagePruning = false
    
    @State private var newProfilePhoto: UIImage?
    @State private var profilePhotoURL: URL?
    
    // Handling display name
    @State private var showingDisplayNameChange = false
    @State private var displayName: String = ""
    @State private var displayNameChanged = false
    
    // Handling password
    @State private var showingPasswordChange = false
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var passwordChanged = false
    
    // Handle loading state
    @State private var loaderInfo = ""
    @State private var showingLoader = false
    
    @State private var failureInfo = ""
    @State private var showingFailure = false
    
    /// Cache size of all images loaded with Kingfisher
    @State private var cacheSize: UInt = 0
    
    private var humanCacheSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(cacheSize), countStyle: .binary)
    }
    
    private var blurred: Bool {
        showingDisplayNameChange || showingPasswordChange
    }
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @ObservedObject var sessionVM = (AuthViewModel.shared.sessionVM)!
    
    private let epVM: EmailsAndPhonesViewModel
    
    init(authViewModel: AuthViewModel) {
        self.epVM = EmailsAndPhonesViewModel(authViewModel: authViewModel)
    }
    
    var body: some View {
        ZStack {
            Form {
                Section {
                    profilePhotoSectionContent
                }
                Section {
                    Button(action: { withAnimation { showingDisplayNameChange = true } }, label: {
                        UserSettingsOptionView(iconName: "address-book",
                                               title: displayName,
                                               subtitle: "Display name",
                                               iconForegroundColor: colorScheme == .dark ? .white : .black)
                    })
                    Button(action: { withAnimation { showingPasswordChange = true } } , label: {
                        UserSettingsOptionView(iconName: "lock-solid",
                                               title: "Password",
                                               subtitle: "Set new account password",
                                               iconForegroundColor: colorScheme == .dark ? .white : .black)
                    })
                    NavigationLink(destination: EmailsAndPhonesView(viewModel: epVM), label: {
                        UserSettingsOptionView(iconName: "envelope-solid",
                                               title: "Email & Phone",
                                               subtitle: "Change email and phone number",
                                               iconForegroundColor: colorScheme == .dark ? .white : .black)
                    })
                    NavigationLink(destination: SecurityView(), label: {
                        UserSettingsOptionView(iconName: "user-shield-solid",
                                               title: "Security",
                                               subtitle: "Set security password or fingerpring",
                                               iconForegroundColor: colorScheme == .dark ? .white : .black)
                    })
                    Button(action: {
                        loaderInfo = "Clearing cache..."
                        showingLoader = true
                        KingfisherManager.shared.cache.clearCache {
                            showingLoader = false
                            cacheSize = 0
                        }
                    }, label: {
                        UserSettingsOptionView(iconName: "broom-solid",
                                               title: "Clear media cache",
                                               subtitle: "\(humanCacheSize)",
                                               iconForegroundColor: colorScheme == .dark ? .white : .black)
                    })
                }
                Section {
                    NavigationLink(destination: MyQRCodeView(), label: {
                        UserSettingsOptionView(iconName: "qrcode-solid",
                                               title: "My QR code",
                                               subtitle: "Share this code with others and start chatting",
                                               iconForegroundColor: colorScheme == .dark ? .white : .black)
                    })
                }
                Section {
                    NavigationLink(destination: KeyBackupManagementView(viewModel: KeyBackupManagementViewModel(backupService: KeyBackupService(crypto: authViewModel.session!.crypto))), label: {
                        UserSettingsOptionView(iconName: "key-solid",
                                               title: "Encryption key management",
                                               subtitle: "Manage message encryption keys",
                                               iconForegroundColor: colorScheme == .dark ? .white : .black)
                    })
                }
            }
            .background(Color.moreBackColor.ignoresSafeArea())
//            .blur(radius: blurred ? 30 : 0)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: sourceType, restrictToImagesOnly: true, allowDefaultEditing: false, createVideoThumbnail: true, onImagePicked: {image in
                    newProfilePhoto = image
                    showImagePruning = true
                }, onVideoPicked: nil)
            }
            .fullScreenCover(isPresented: $showImagePruning, onDismiss: {
                profilePhotoURL = authViewModel.sessionVM?.userAvatarURL
            }, content: {
                ImagePruningView(uiImage: $newProfilePhoto, mxSession: authViewModel.session)
            })
            .navigationBarTitle(nL10n.UserSettings.title)
            .navigationBarTitleDisplayMode(.inline)
            .disabled(blurred)
            .onAppear() {
                // MARK: Do not use authVM in order to get preview
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    displayName = "Alex Boushman"
                } else {
                    displayName = authViewModel.session?.myUser.displayname ?? "noname"
                    profilePhotoURL = authViewModel.sessionVM?.userAvatarURL
                }
                loaderInfo = "Calculating cache size..."
                showingLoader = true
                KingfisherManager.shared.cache.calculateDiskStorageSize { result in
                    showingLoader = false
                    switch result {
                    case .success(let bytes):
                        cacheSize = bytes
                    case .failure(_):
                        failureInfo = "Failed to calculate cache size"
                        showingFailure = true
                    }
                }
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
            if showingDisplayNameChange {
                changingDisplayNameAlert
            }
            if showingPasswordChange {
                changingPasswordAlert
            }
            if showingLoader {
                loaderAlert
            }
            if showingFailure {
                failureAlert
            }
        }
    }
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showingLoader)
        }
    }
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: failureInfo, shown: $showingFailure)
        }
    }
    
    private var profilePhotoSectionContent: some View {
        HStack(spacing: Constants.profileImageSpacing) {
            AvatarImageView(profilePhotoURL, name: authViewModel.session?.myUser.displayname)
                .frame(width: Constants.profileImageSize, height: Constants.profileImageSize)
            
            Button(action: {
                showingProfileImageOptions = true
            }, label: {
                Text("Set Profile Photo")
                    .foregroundColor(.primary)
            })
            .actionSheet(isPresented: $showingProfileImageOptions) {
                ActionSheet(
                    title: Text("Set Profile Photo"),
                    buttons: [
                        .default(Text("Take Photo")) {
                            sourceType = .camera
                            showingImagePicker = true
                        },
                        .default(Text("Choose Photo")) {
                            sourceType = .photoLibrary
                            showingImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
        }
        .padding(.vertical, Constants.verticalPadding)
    }
    
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
    
    struct Constants {
        static let profileImageSize: CGFloat = 32
        static let profileImageSpacing: CGFloat = 18
        static let verticalPadding: CGFloat = 6
    }
    
}

//struct UserSettingView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            NavigationView {
//                UserSettingView()
//            }
//            .colorScheme(.dark)
//            NavigationView {
//                UserSettingView()
//            }
//            .colorScheme(.light)
//        }
//    }
//}
