//
//  KeyBackupSetupViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 29.01.2022.
//

import Foundation
import Combine
import MatrixSDK

class KeyBackupSetupViewModel: ObservableObject {
    
    enum SetupState {
        case noBackup
        case pending(recoveryKey: String)
        case backup(version: String)
    }
    
    @Published private(set) var state: SetupState = .noBackup
    
    var shortInfo: String {
        switch state {
        case .noBackup: return "Never lose encrypted messages"
        case .pending: return "Save your recovery key"
        case .backup: return "Your keys are being backed up"
        }
    }
    
    var longInfo: String {
        switch state {
        case .noBackup: return "Messages in encrypted clubs and chats are secured with end-to-end encryption. Only you and recipient(s) have the keys to read these messages.\n\nSecurely back up your keys to avoid losing them."
        case .pending: return "Keep your recovery key somewhere very secure, like password manager (or a safe)"
        case .backup(let version): return "Backup version: \(version)"
        }
    }
    
    var shareActivities: [AnyObject] {
        // Options only when the recovery key is there
        guard case let .pending(key) = state else { return [] }
        let activities: [AnyObject] = [
            key as AnyObject
        ]
        return activities
    }
    
    // Temporary hold to it until confirming backup
    private var preparedBackupInfo: MXMegolmBackupCreationInfo?
    
    // Service for all backup actions
    private let backupService: KeyBackupService
    
    init(backupService: KeyBackupService) {
        self.backupService = backupService
    }

    
    // MARK: - Usage
    
    /// Prepares a new backup info if needed. Returns recovery key in success
    func prepareBackup(completion: @escaping (Result<String, Error>) -> Void) {
        // Already have a prepared backup info -> use it
        guard preparedBackupInfo == nil else {
            completion(.success(preparedBackupInfo!.recoveryKey))
            return
        }
        // Prepare new backup info
        backupService.prepareNewBackup() { [weak self] result in
            switch result {
            case .success(let info):
                self?.preparedBackupInfo = info
                self?.state = .pending(recoveryKey: info.recoveryKey)
                completion(.success(info.recoveryKey))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Creates new backup if there is already prepared info available. Returns backup version in success
    func confirmBackup(completion: @escaping (Result<String, Error>) -> Void) {
        // No prepared info available -> fail
        guard let info = preparedBackupInfo else {
            completion(.failure(KeyBackupError.noPreparedInfoForNewBackup))
            return
        }
        // Create new backup with prepared info
        backupService.createNewBackup(info) { [weak self] result in
            switch result {
            case .success(let version):
                let versionValue = version.version ?? "nil"
                self?.preparedBackupInfo = nil
                self?.state = .backup(version: versionValue)
                completion(.success(versionValue))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
}
