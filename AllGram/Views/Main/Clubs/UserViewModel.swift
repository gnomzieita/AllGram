//
//  UserViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 09.08.2022.
//

import Foundation
import MatrixSDK

/// Will provide display name and avatar URL for user with given userId if possible.
/// Expected to be used after user has logged in and uses shared `AuthViewModel`
class UserViewModel: ObservableObject {
    @Published private(set) var avatarURL: URL?
    @Published private(set) var avatarError: Error?
    
    // Cancelable loading user avatar url operation
    private var avatarOperation: MXHTTPOperation?
    
    let userId: String
    let displayName: String
    
    init(userId: String) {
        // We can not use MXUser's avatar url as it's invalid (link to identicon)
        // So we need to manually load avatar url by userId
        // On the other hand, display name is valid and can be used as is
        // If we are missing something, this will use formatted userId instead
        self.userId = userId
        self.displayName = AuthViewModel.shared.session!.user(withUserId: userId)?.displayname ?? userId.dropPrefix("@").dropAllgramSuffix
        loadAvatarURL()
    }
    
    deinit {
        avatarOperation?.cancel()
    }
    
    func loadAvatarURL() {
        guard avatarOperation == nil else { return }
        let client = AuthViewModel.shared.client!
        let mediaManager = AuthViewModel.shared.session!.mediaManager!
        avatarURL = nil
        avatarError = nil
        avatarOperation = client.avatarUrl(forUser: userId) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let matrixURL):
                let urlString = mediaManager.url(ofContent: matrixURL.absoluteString)!
                self.avatarURL = URL(string: urlString)
            case .failure(let error):
                self.avatarError = error
            }
            self.avatarOperation = nil
        }
    }
    
    func cancelAvatarLoading() {
        avatarOperation?.cancel()
        avatarOperation = nil
        avatarURL = nil
        avatarError = nil
    }
}

