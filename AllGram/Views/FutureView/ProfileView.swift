//
//  ProfileView.swift
//  AllGrammDev
//
//  Created by Ярослав Шерстюк on 03.09.2021.
//

import SwiftUI
import Kingfisher
import AVKit

struct ProfileButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(icon)
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
                Spacer()
            }
            .foregroundColor(.primary)
            .padding()
        }
    }
}

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var backupVM: NewKeyBackupViewModel
    @EnvironmentObject var sessionVM: SessionViewModel
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    let displayName: String
    let nickname: String
    
    @State private var showingShare = false
    @State private var showingUserQR = false
    @State private var showingQRScan = false
    @State private var showingHelp = false
    @State private var showingInfo = false
    @State private var showingSettings = false
    @State private var showingAccount = false
    @State private var showAbout = false
    
    @State private var showLogoutAlert = false
    @State private var logoutWithBackup = false
    @State private var showKeyBackup = false
    
    init() {
        self.displayName = AuthViewModel.shared.session?.myUser.displayname ?? "noname"
        self.nickname = AuthViewModel.shared.session?.myUser.userId.components(separatedBy: ":").first ?? "@none"
    }
    
    private var urlString: String {
        "\(API.server.getURL()!.absoluteString)/#/\(nickname)"
    }
    
    private var shareActivities: [AnyObject] {
        let activities: [AnyObject] = [
            "You are invited to join allgram by \(displayName)" as AnyObject,
            UIImage(named: "logo") as AnyObject,
            URL(string: urlString)! as AnyObject
        ]
        return activities
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top part
            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    AvatarImageView(sessionVM.userAvatarURL, name: displayName)
                        .frame(width: Constants.photoSize, height: Constants.photoSize)
                        .onTapGesture {
                            showingAccount = true
                        }
                    Text(displayName)
                        .bold()
                        .onTapGesture {
                            showingAccount = true
                        }
                    Text(nickname)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .onTapGesture {
                            showingAccount = true
                        }
                }
                Spacer()
            }
            .padding()
            .background(Color(Constants.backgroundTop))
            .alert(isPresented: $showPermissionAlert) {
                permissionAlertView
            }
            // Menu part
            VStack(alignment: .leading, spacing: 0) {
                // No more that 10 items in stack
                Group {
                    Divider()
                    ProfileButton(title: "Digital ID", icon: "user-circle-solid") {
                        showingUserQR = true
                    }
                    Divider()
                    ProfileButton(title: "Scan QR", icon: "expand-solid") {
                        switch PermissionsManager.shared.getAuthStatusFor(.video) {
                        case .notDetermined: // User has not yet been asked for camera access
                            AVCaptureDevice.requestAccess(for: .video) { response in
                                if response {
                                    showingQRScan = true
                                } else {
                                    permissionAlertText = "camera"
                                    showPermissionAlert = true
                                }
                            }
                        case .authorized:
                            withAnimation { showingQRScan = true }
                        default:
                            permissionAlertText = "camera"
                            showPermissionAlert = true
                        }
                        
                    }
                    Divider()
                }
                Group {
                    ProfileButton(title: "Help", icon: "question-circle") {
                        showingHelp = true
                    }
                    Divider()
                    ProfileButton(title: "Info", icon: "info-circle-solid") {
                        showingInfo = true
                    }
                    Divider()
                    ProfileButton(title: "Settings", icon: "cog-solid") {
                        showingSettings = true
                    }
                    Divider()
                    ProfileButton(title: "Sign out", icon: "sign-out-alt-solid") {
                        switch backupVM.state {
                        case .noBackup, .unverifiedBackup:
                            logoutWithBackup = false
                        default:
                            logoutWithBackup = true
                        }
                        withAnimation { showLogoutAlert = true }
//                        authViewModel.logout()
//                        presentationMode.wrappedValue.dismiss()
                    }
                }
                Divider()
                Spacer()
                Button {
                    showAbout = true
                } label: {
                    HStack {
                        Text(softwareVersion)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    }
                }
            }
            .background(Color(Constants.backgroundBottom))
            .alert(isPresented: $showLogoutAlert) {
                logoutWithBackup ? shortLogoutAlert : longLogoutAlert
            }
        }
        .frame(width: Constants.widthOfProfileView)
        .clipShape(
            IndividuallyRoundedRectangle(topLeft: Constants.cornerRadius)
        )
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
        .sheet(isPresented: $showingUserQR) {
            NavigationView {
                MyQRCodeView()
                .ourToolbar(
                    leading:
                        Button {
                            showingUserQR = false
                        } label: {
                            Text("Close")
                        }
                )
            }
        }
        .sheet(isPresented: $showingQRScan) {
            QRScannerView()
        }
        .sheet(isPresented: $showingHelp) {
            SimpleWebView(title: "Help", url: "https://www.allgram.com/help")
        }
        .sheet(isPresented: $showingInfo) {
            InfoFormView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsFormView()
        }
        .sheet(isPresented: $showingAccount) {
            NavigationView {
                AccountFormView()
                    .ourToolbar(
                        leading:
                            Button {
                                showingAccount = false
                            } label: {
                                Text("Close")
                            }
                    )
            }
        }
        .sheet(isPresented: $showAbout) {
            NavigationView {
                AboutView()
                    .ourToolbar(
                        leading:
                            Button {
                                showAbout = false
                            } label: {
                                Text("Close")
                            }
                    )
            }
        }
        .sheet(isPresented: $showKeyBackup) {
            NavigationView {
                ManageBackupView(backupVM)
                    .ourToolbar(
                        leading:
                            Button {
                                withAnimation { showKeyBackup = false }
                            } label: {
                                Text("Close")
                            }
                    )
            }
        }
    }
    
    // MARK: - Logout
    
    private var shortLogoutAlert: Alert {
        Alert(
            title: Text("Sign Out"),
            message: Text("Are you sure you want to sign out?"),
            primaryButton:
                    .destructive(Text("Sign Out"), action: {
                        authViewModel.logout()
                        presentationMode.wrappedValue.dismiss()
                    })
            ,
            secondaryButton: .cancel()
        )
    }
    
    private var longLogoutAlert: Alert {
        Alert(
            title: Text("Sign Out"),
            message: Text("You have not backed up the encryption key. Please do this, otherwise your data will be lost when you exit the application or log out."),
            primaryButton:
                    .default(Text("Generate Key"), action: {
                        withAnimation { showKeyBackup = true }
                    })
            ,
            secondaryButton:
                    .destructive(Text("Sign Out"), action: {
                        authViewModel.logout()
                        presentationMode.wrappedValue.dismiss()
                    })
        )
    }
    
    // MARK: - Permission
    
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
    
    // MARK: -
    
    struct Constants {
        static let widthOfProfileView: CGFloat = UIScreen.main.bounds.width - 48
        static let iconSize: CGFloat = 20
        static let photoSize: CGFloat = 60
        static let cornerRadius: CGFloat = 30
        // TODO: Fix this vise-versa colors
        static let backgroundTop: String = "profileBottomBackground"
        static let backgroundBottom: String = "profileTopBackground"
    }
}

//struct ProfileView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            NavigationView {
//                ProfileView()
//            }
//            .colorScheme(.dark)
//            //            NavigationView {
//            ProfileView()
//            //            }
//                .colorScheme(.light)
//        }
//    }
//}
