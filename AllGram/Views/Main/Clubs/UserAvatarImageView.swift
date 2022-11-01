//
//  UserAvatarImageView.swift
//  AllGram
//
//  Created by Alex Pirog on 09.08.2022.
//

import SwiftUI

/// Uses `UserViewModel` to get avatar url and display name for `AvatarImageView`
struct UserAvatarImageView: View {
    @StateObject private var viewModel: UserViewModel
    
    init(userId: String) {
        self._viewModel = StateObject(wrappedValue: UserViewModel(userId: userId))
    }
    
    var body: some View {
        AvatarImageView(viewModel.avatarURL, name: viewModel.displayName)
    }
}
