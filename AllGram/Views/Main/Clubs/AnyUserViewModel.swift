//
//  AnyUserViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 12.08.2022.
//

import Foundation
import MatrixSDK

/// Will provide display name and avatar URL for user with given userId if possible.
/// This is a safer version of `UserViewModel` that will load both name and avatar.
/// Expected to be used after user has logged in and uses shared `AuthViewModel`
class AnyUserViewModel: ObservableObject {
    @Published private(set) var displayName: String?
    @Published private(set) var avatarURL: URL?
    
    // Errors id loading failed
    @Published private(set) var nameError: Error?
    @Published private(set) var avatarError: Error?
    
    // Cancelable loading user avatar url operation
    private var nameOperation: MXHTTPOperation?
    
    // Cancelable loading user avatar url operation
    private var avatarOperation: MXHTTPOperation?
    
    var isLoading: Bool { isLoadingName || isLoadingAvatar }
    var isLoadingName: Bool { nameOperation != nil }
    var isLoadingAvatar: Bool { avatarOperation != nil }
    
    let userId: String
    
    init(userId: String) {
        self.userId = userId
        loadDisplayName()
        loadAvatarURL()
    }
    
    deinit {
        nameOperation?.cancel()
        avatarOperation?.cancel()
    }
    
    func loadDisplayName() {
        guard nameOperation == nil else { return }
        let client = AuthViewModel.shared.client!
        displayName = nil
        nameError = nil
        nameOperation = client.displayName(forUser: userId) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let name):
                self.displayName = name
            case .failure(let error):
                self.nameError = error
            }
            self.nameOperation = nil
        }
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
    
    func cancelNameLoading(clear: Bool = false) {
        nameOperation?.cancel()
        nameOperation = nil
        if clear {
            displayName = nil
            nameError = nil
        }
    }
    
    func cancelAvatarLoading(clear: Bool = false) {
        avatarOperation?.cancel()
        avatarOperation = nil
        if clear {
            avatarURL = nil
            avatarError = nil
        }
    }
}
