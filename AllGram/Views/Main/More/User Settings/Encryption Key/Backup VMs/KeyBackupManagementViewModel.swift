//
//  KeyBackupManagementViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 24.01.2022.
//

import Foundation
import Combine
import MatrixSDK

class KeyBackupManagementViewModel: ObservableObject {
    
    enum ManageState {
        case checking
        case noBackup
        case backup(version: MXKeyBackupVersion, state: KeyBackupState)
        case error(info: String)
    }
    
    @Published private(set) var state: ManageState = .noBackup
        
    var usingInfo: String {
        switch state {
        case .checking: return "Checking..."
        case .noBackup: return "Your keys are not being backed up from this session."
        case .backup: return "Key backup has been correctly set up."
        case .error(let info): return "Something went wrong. \(info)"
        }
    }
    
    /// Convenience for setting up backup
    func getSetupVM() -> KeyBackupSetupViewModel {
        KeyBackupSetupViewModel(backupService: backupService)
    }
    
    /// Convenience for restoring backup
    func getRestoreVM(with version: MXKeyBackupVersion) -> KeyBackupRestoreViewModel {
        KeyBackupRestoreViewModel(backupService: backupService, version: version)
    }
    
    private let backupService: KeyBackupService
    
    init(backupService: KeyBackupService) {
        self.backupService = backupService
        // Update right away
        update()
    }
    
    func update() {
        if case .checking = state {
            // Already checking...
        } else {
            state = .checking
            backupService.checkBackupVersion { [weak self] result in
                switch result {
                case .success(let serverVersion):
                    if let version = serverVersion {
                        self?.backupService.checkBackupState() { state in
                            self?.state = .backup(version: version, state: state)
                        }
                    } else {
                        // No backup version on homeserver
                        self?.state = .noBackup
                    }
                case .failure(let error):
                    self?.state = .error(info: error.localizedDescription)
                }
            }
        }
    }
    
    func deleteBackup(completion: @escaping (Result<Void, Error>) -> Void) {
        guard case let .backup(version, _) = state else {
            completion(.failure(KeyBackupError.noBackupToDelete))
            return
        }
        backupService.deleteOldBackup(version: version.version!) { [weak self] result in
            switch result {
            case .success(()):
                completion(.success(()))
                self?.update()
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
