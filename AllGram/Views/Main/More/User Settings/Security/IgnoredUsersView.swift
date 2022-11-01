//
//  IgnoredUsersView.swift
//  AllGram
//
//  Created by Eugene Ned on 01.08.2022.
//

import SwiftUI
import MatrixSDK

struct IgnoredUserView: View {
    
    let userId: String
    let displayName: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                UserAvatarImageView(userId: userId)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.reverseColor)
                    Text(verbatim: userId.dropAllgramSuffix)
                        .font(.subheadline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            Divider()
        }
    }
}

struct IgnoredUsersView: View {
    
    @StateObject var VM = IgnoringUsersViewModel.shared
    @State var selectedUser: String?
    
    var body: some View {
        ZStack {
            if !VM.ignoredUsers.isEmpty {
                ScrollView {
                    ForEach(VM.ignoredUsers) { user in
                        IgnoredUserView(userId: user, displayName: AuthViewModel.shared.session!.user(withUserId: user).displayname)
                            .onTapGesture {
                                selectedUser = user
                                alertTitle = "Show all messages from this user?"
                                alertText = "Note that this action will restart the app and it may take some time"
                                alertActionTitle = "Unignore"
                                withAnimation { showUnIgnoreAlert = true }
                            }
                    }
                }
                .edgesIgnoringSafeArea(.bottom)
            } else {
                HStack {
                    VStack {
                        Text("You are not ignoring any users")
                            .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
            if showUnIgnoreAlert { unIgnoreAlert }
            if showLoader { loadingView }
        }
        .navigationTitle("Ignored Users")
    }
    
    @State private var showUnIgnoreAlert = false
    @State private var alertTitle = ""
    @State private var alertText = ""
    @State private var alertActionTitle = ""
    @State private var showLoader = false
    @State private var loaderInfo = ""
    
    private var loadingView: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showLoader)
        }
    }
    
    private var unIgnoreAlert: some View {
        ActionAlert(showAlert: $showUnIgnoreAlert, title: alertTitle, text: alertText, actionTitle: alertActionTitle) {
            loaderInfo = "Unignoring user"
            showLoader = true
            VM.unIgnoreUser(userId: selectedUser!) { response in
                switch response {
                case .success:
                    showLoader = false
                case .failure:
                    showLoader = false
                    alertTitle = "Error"
                    alertText = "Error while performing your action, try again?"
                    alertActionTitle = "Try again"
                    showUnIgnoreAlert = true
                }
            }
        }
    }
}

struct IgnoredUsersView_Previews: PreviewProvider {
    static var previews: some View {
        IgnoredUsersView()
    }
}
