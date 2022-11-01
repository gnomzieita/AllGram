//
//  CreateChatView.swift
//  AllGram
//
//  Created by Alex Pirog on 11.10.2022.
//

import SwiftUI

struct YellowAlertBox: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Image("exclamation-circle-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .foregroundColor(.ourOrange)
                .frame(width: 32, height: 32)
                .padding(.trailing, 8)
            Text(verbatim: text)
                .font(.subheadline)
                .foregroundColor(.textHigh)
            Spacer()
        }
        .padding(.all, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.infoBoxBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.cardBorder)
        )
    }
}

struct NavSearchBar: View {
    @Binding var text: String
    
    let placeholder: String
    
    init(_ text: Binding<String>, placeholder: String) {
        self._text = text
        self.placeholder = placeholder
    }
    
    var color: Color {
        text.isEmpty ? Color.textMedium : .textHigh
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Image("search-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .padding(.all, Constants.iconPadding)
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image("times-circle-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                        .padding(.all, Constants.iconPadding)
                        .foregroundColor(Color.reverseColor)
                }
            }
        }
        .foregroundColor(color)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
        .padding(.bottom, 8)
        .padding(.horizontal, 16)
        .background(Color.allgramMain)
        .colorScheme(.light)
    }
    
    struct Constants {
        static let iconSize: CGFloat = 20
        static let iconPadding: CGFloat = 8
    }
}

struct SearchSelectedUserView: View {
    let user: UserInfo
    
    var body: some View {
        HStack(spacing: 8) {
            AvatarImageView(user.avatarURL, name: user.displayName)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(user.displayName).bold()
                    .font(.subheadline)
                    .foregroundColor(.textHigh)
                Text(user.userId.dropAllgramSuffix)
                    .font(.caption)
                    .foregroundColor(.textMedium)
            }
            Image("times-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundColor(Color.reverseColor)
        }
        .padding(.all, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.cardBorder)
        )
    }
}

struct SearchUserView: View {
    let user: UserInfo
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.allgramMain)
                    .frame(width: 16, height: 16)
                    .padding(.all, 4)
                    .overlay(
                        Image("check-solid")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.textMedium, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .padding(.all, 4)
            }
            AvatarImageView(user.avatarURL, name: user.displayName)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(user.displayName).bold()
                    .font(.subheadline)
                    .foregroundColor(.textHigh)
                Text(user.userId.dropAllgramSuffix)
                    .font(.caption)
                    .foregroundColor(.textMedium)
            }
            Spacer()
        }
    }
}

struct CreateChatView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @StateObject var viewModel = StartChatViewModel(session: AuthViewModel.shared.sessionVM!.session)
    
    @Binding var createdRoomId: String?
    
    @State private var showSearchBar = false
    
    init(createdRoomId: Binding<String?>) {
        self._createdRoomId = createdRoomId
    }
        
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backImage
                // Content
                VStack(spacing: 0) {
                    if showSearchBar {
                        NavSearchBar($viewModel.searchString, placeholder: "Search")
                            .transition(.move(edge: .top))
                    }
                    selectedStack
                    searchResults
                    Spacer()
                }
                .frame(width: UIScreen.main.bounds.width)
//                .background(backImage, alignment: .top)
                .disabled(viewModel.isCreating)
                .onAppear {
                    withAnimation(.easeOut.delay(0.5)) { showSearchBar = true }
                }
                // Alerts
                if showingLoading { loadingAlert }
                if showingFailure { failureAlert }
            }
            .navigationBarTitleDisplayMode(.inline)
            .ourToolbar(
                leading:
                    HStack {
                        navigationBackButton
                        Text("Create a chat").bold()
                            .foregroundColor(.white)
                    }
                ,
                trailing:
                    createButton
            )
        }
    }
    
    @ViewBuilder
    private var selectedStack: some View {
        if viewModel.selectedToInvite.isEmpty {
            YellowAlertBox(text: "To create a chat, you need to add users. You can search user by name or ID")
                .padding(.all, 16)
        } else {
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(viewModel.selectedToInvite) { user in
                        SearchSelectedUserView(user: user)
                            .onTapGesture {
                                withAnimation {
                                    viewModel.deselectFromInvite(user)
                                }
                            }
                    }
                }
                .padding(.leading, 16)
            }
            .frame(height: 48)
            .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private var searchResults: some View {
        if !viewModel.searchResult.isEmpty {
            VStack {
                HStack {
                    Text("USERS FOUND").bold()
                        .font(.caption)
                        .foregroundColor(.textMedium)
                    Spacer()
                    Button{
                        withAnimation { viewModel.selectedToInvite.removeAll() }
                    } label: {
                        Text("Clear").bold()
                            .font(.caption)
                            .foregroundColor(.ourPurple)
                    }
                }
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResult) { user in
                            SearchUserView(user: user, isSelected: viewModel.selectedToInvite.contains(user))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .onTapGesture {
                                    withAnimation { viewModel.selectForInvite(user) }
                                }
                            if user != viewModel.searchResult.last {
                                Divider()
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.cardBorder)
                    )
                }
            }
            .padding(.horizontal, 16)
        } else if viewModel.isBusy {
            Spinner()
        }
    }
    
    // MARK: - Background image
    
    @ViewBuilder
    private var backImage: some View {
        if SettingsManager.homeBackgroundImageName == nil,
           let customImage = SettingsManager.getSavedHomeBackgroundImage() {
            Image(uiImage: customImage)
                .resizable().scaledToFill()
                .frame(width: UIScreen.main.bounds.width)
                .ignoresSafeArea()
        } else {
            Image(SettingsManager.homeBackgroundImageName!)
                .resizable().scaledToFill()
                .frame(width: UIScreen.main.bounds.width)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Loading Alert
    
    @State private var showingLoading = false
    
    private var loadingAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoading) {
            LoaderAlertView(title: "Creating chat...", subtitle: nil, shown: $showingLoading)
        }
    }
    
    // MARK: - Failure
    
    @State private var showingFailure = false
    @State private var failureText: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: "Failed to create new chat." + (failureText == nil ? "" : "\n\(failureText!)"), shown: $showingFailure)
        }
    }
    
    // MARK: - Navigation
    
    private var navigationBackButton: some View {
        Button {
            presentationMode.wrappedValue.dismiss()
        } label: {
            Image("times-solid")
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder private var createButton: some View {
        if viewModel.isCreating {
            ProgressView()
                .tint(.white)
        } else {
            Button {
                withAnimation { showingLoading = true }
                viewModel.createChatRoom() { result in
                    switch result {
                    case .success(let id):
                        // Our is_direct returns wrong result right after
                        // new chat is created, so need to wait and do again
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            if let newRoom = authViewModel.sessionVM?.rooms.first(where: { $0.room.roomId == id }) {
                                newRoom.checkIsDirectState {
                                    // Update AuthViewModel to get new
                                    // Chats/Clubs rooms separation
                                    authViewModel.sessionVM?.counterOfRoomChanges += 1
                                    presentationMode.wrappedValue.dismiss()
                                    // Also need to wait in order to jump to
                                    // new created chat (without will stuck)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        createdRoomId = id
                                    }
                                }
                            } else {
                                withAnimation {
                                    showingLoading = false
                                    failureText = "Missing room by id."
                                    showingFailure = true
                                }
                            }
                        }
                    case .failure(let error):
                        withAnimation {
                            showingLoading = false
                            failureText = error.localizedDescription
                            showingFailure = true
                        }
                    }
                }
            } label: {
                Text("Create").bold()
            }
            .disabled(viewModel.selectedToInvite.isEmpty)
            .opacity(viewModel.selectedToInvite.isEmpty ? 0.5 : 1)
        }
    }
}
