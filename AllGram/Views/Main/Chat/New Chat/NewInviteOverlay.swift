//
//  NewInviteOverlay.swift
//  AllGram
//
//  Created by Alex Pirog on 07.10.2022.
//

import SwiftUI

struct NewInviteOverlay: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var viewModel: ClubInviteViewModel
    
    typealias StateChangeHandler = (ClubInviteViewModel.State) -> Void
    
    let onChange: StateChangeHandler
    
    init(vm: ClubInviteViewModel, onChange: @escaping StateChangeHandler = { _ in }) {
        self.viewModel = vm
        self.onChange = onChange
    }
    
    var body: some View {
        ZStack {
            // Invite box
            VStack {
                inviteBox.padding(.all, 16)
                Spacer()
            }
            
            // Alerts
            if showingLoader { loaderAlert }
            if showingFailure { failureAlert }
        }
        .background(backImage.ignoresSafeArea())
        .onChange(of: viewModel.state) { state in
            showingLoader = false
            showingFailure = false
            switch state {
            case .joining, .leaving:
                showingLoader = true
            case .failed:
                showingFailure = true
            default:
                break
            }
            onChange(state)
        }
    }
    
    struct InviteBoxButton: View {
        let title: String
        let fill: Bool
        let action: () -> Void
        
        var body: some View {
            Button {
                action()
            } label: {
                Text(title).bold()
                    .font(.subheadline)
                    .foregroundColor(fill ? .white : .accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(fill ? Color.allgramMain : .clear)
                    )
            }
        }
    }
    
    var inviteBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image("exclamation-circle-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(.ourOrange)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.inviteUserDisplayname ?? "Unknown").bold()
                        .font(.subheadline)
                        .foregroundColor(.textHigh)
                        .lineLimit(1)
                    Text(viewModel.inviteUserNickname ?? "@none")
                        .font(.caption)
                        .foregroundColor(.textMedium)
                        .lineLimit(1)
                    Text("Sent you an invitation to \(viewModel.room.isMeeting ? "meeting" : "chat"):")
                        .font(.subheadline)
                        .foregroundColor(.textHigh)
                        .padding(.top, 8)
                }
            }
            Divider()
            HStack(spacing: 8) {
                Spacer()
                InviteBoxButton(title: "Block", fill: false) {
                    guard let id = viewModel.inviteUserId else { return }
                    withAnimation { showingLoader = true }
                    IgnoringUsersViewModel.shared.ignoreUser(userId: id) { result in
                        switch result {
                        case .success:
                            presentationMode.wrappedValue.dismiss()
                        case .failure:
                            withAnimation { showingFailure = true }
                        }
                        showingLoader = false
                    }
                }
                InviteBoxButton(title: "Reject", fill: false) {
                    withAnimation { viewModel.reject() }
                }
                InviteBoxButton(title: "Accept", fill: true) {
                    withAnimation { viewModel.accept() }
                }
            }
        }
        .padding([.horizontal, .top], 16)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.infoBoxBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.cardBorder)
        )
    }
    
    @ViewBuilder
    private var backImage: some View {
        if SettingsManager.homeBackgroundImageName == nil,
           let customImage = SettingsManager.getSavedHomeBackgroundImage() {
            Image(uiImage: customImage)
                .resizable().scaledToFill()
        } else {
            Image(SettingsManager.homeBackgroundImageName!)
                .resizable().scaledToFill()
        }
    }
    
    // MARK: - Loading
    
    @State private var showingLoader = false
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: nil, shown: $showingLoader)
        }
    }
    
    // MARK: - Failure
    
    @State private var showingFailure = false
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: nil, shown: $showingFailure)
        }
    }
}

extension NewInviteOverlay: Equatable {
    static func == (lhs: NewInviteOverlay, rhs: NewInviteOverlay) -> Bool {
        lhs.viewModel.room.roomId == rhs.viewModel.room.roomId
    }
}
