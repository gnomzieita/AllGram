//
//  NewKeyBackupViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 04.08.2022.
//

import Foundation
import Combine
import MatrixSDK

class NewKeyBackupViewModel: ObservableObject {
    @Published private(set) var state: KeyBackupState = .unknown
    
    /// Only available after new backup is created. Clear when done with it
    @Published var recoveryKey: String?
    
    /// Only available in `unverified`, `valid` or `in progress` states
    var backup: KeyBackup? {
        switch state {
        case .unverifiedBackup(let keyBackup), .validBackup(let keyBackup), .backupInProgress(let keyBackup):
            return keyBackup
        default:
            return nil
        }
    }
    
    let backupService: KeyBackupService
    
    init(backupService: KeyBackupService) {
        self.backupService = backupService
        // Update state on change notification
        backupService.backupStateChangedNotificationHandler = { [weak self] _ in
            self?.backupService.checkBackupState() { [weak self] newState in
                self?.state = newState
            }
        }
        backupService.checkBackupVersion() { result in
            // Do nothing... It is just to kick in initial backup state check
        }
    }
    
    /// Rechecks current backup state
    func updateState(completion: @escaping (Result<Void, Error>) -> Void) {
        backupService.checkBackupState() { [weak self] newState in
            guard let self = self else {
                completion(.failure(KeyBackupError.lostSelfHalfWay))
                return
            }
            self.state = newState
            completion(.success(()))
        }
    }
    
    /// Prepares info and then creates new backup with it. Can fail half-way
    func createNewBackup(completion: @escaping (Result<Void, Error>) -> Void) {
        // Prepare new backup info
        backupService.prepareNewBackup() { [weak self] result in
            switch result {
            case .success(let info):
                guard let self = self else {
                    completion(.failure(KeyBackupError.lostSelfHalfWay))
                    return
                }
                // Create new backup with prepared info
                self.backupService.createNewBackup(info) { [weak self] result in
                    switch result {
                    case .success(_):
                        if let self = self {
                            self.recoveryKey = info.recoveryKey
                            completion(.success(()))
                        } else {
                            completion(.failure(KeyBackupError.lostSelfHalfWay))
                            return
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Restores backup with given key and sets trust on this version. Can fail half-way
    /// Returns `true` if actually restored one or `false` if there was NO backup to restore
    func recoverBackup(with key: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let backup = backup else {
            completion(.success(false))
            return
        }
        backupService.restoreBackup(version: backup.version, with: key) { [weak self] restoreResult in
            switch restoreResult {
            case .success(_):
                guard let self = self else {
                    completion(.failure(KeyBackupError.lostSelfHalfWay))
                    return
                }
                self.backupService.setBackupTrust(true, version: backup.version) { trustResult in
                    switch trustResult {
                    case .success(()):
                        completion(.success(true))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Deletes existing backup if any.
    /// Returns `true` if actually deleted one or `false` if there was NO backup to delete
    func deleteBackup(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let backup = backup else {
            completion(.success(false))
            return
        }
        backupService.deleteOldBackup(version: backup.version.version!) { result in
            switch result {
            case .success(()):
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Deletes all backups one by one if any.
    /// This is needed because the user can create new backups without deleting old ones
    func deleteAllBackups(completion: @escaping (Result<Void, Error>) -> Void) {
        deleteBackup { [weak self] deleteResult in
            switch deleteResult {
            case .success(_):
                guard let self = self else {
                    completion(.failure(KeyBackupError.lostSelfHalfWay))
                    return
                }
                // One deleted, check for other backups
                self.updateState { [weak self] updateResult in
                    switch updateResult {
                    case .success(()):
                        guard let self = self else {
                            completion(.failure(KeyBackupError.lostSelfHalfWay))
                            return
                        }
                        // Checking done, continue if needed
                        if self.backup != nil {
                            self.deleteAllBackups(completion: completion)
                        } else {
                            completion(.success(()))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
