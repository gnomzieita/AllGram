//
//  KeyBackupService.swift
//  AllGram
//
//  Created by Alex Pirog on 27.01.2022.
//

import Foundation
import MatrixSDK

// Wrapper for `MXKeyBackupVersion` and `MXKeyBackupVersionTrust`
typealias KeyBackup = (version: MXKeyBackupVersion, trust: MXKeyBackupVersionTrust)

enum KeyBackupState {
    /// Unhandled, failed to define or initial state
    case unknown
    /// There is no backup on the homeserver
    case noBackup
    /// Checking backup on the homeserver
    case checkingBackup
    /// There is a backup on the homeserver but it has not been verified yet
    case unverifiedBackup(KeyBackup)
    /// There is a valid backup on the homeserver. All keys have been backed up to it
    case validBackup(KeyBackup)
    /// There is a valid backup on the homeserver. Keys are being sent to it
    case backupInProgress(KeyBackup)
    
    /// Short info for debug prints
    var info: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .noBackup:
            return "No Backup"
        case .checkingBackup:
            return "Checking Backup"
        case .unverifiedBackup(let backup):
            return "Unverified Backup (version: \(backup.version.version ?? "nil"))"
        case .validBackup(let backup):
            return "Valid Backup (version: \(backup.version.version ?? "nil"))"
        case .backupInProgress(let backup):
            return "Backup (version: \(backup.version.version ?? "nil")) in progress"
        }
    }
}

extension KeyBackupState: Equatable {
    static func == (lhs: KeyBackupState, rhs: KeyBackupState) -> Bool {
        if case .unknown = lhs, case .unknown = rhs {
            return true
        } else if case .noBackup = lhs, case .noBackup = rhs {
            return true
        } else if case .checkingBackup = lhs, case .checkingBackup = rhs {
            return true
        } else if case .unverifiedBackup(let lb) = lhs,
                  case .unverifiedBackup(let rb) = rhs
        {
            return lb.version == rb.version && lb.trust == rb.trust
        } else if case .validBackup(let lb) = lhs,
                  case .validBackup(let rb) = rhs
        {
            return lb.version == rb.version && lb.trust == rb.trust
        } else if case .backupInProgress(let lb) = lhs,
                  case .backupInProgress(let rb) = rhs
        {
            return lb.version == rb.version && lb.trust == rb.trust
        }
        return false
    }
}

/// Not actually used by KeyBackupService itself, but by different KeyBackupViewModels
enum KeyBackupError: Error {
    case noBackupToRestore
    case noBackupToDelete
    case noPreparedInfoForNewBackup
    case fileNotSelected
    case fileFailedToGetContent
    case fileNoAccess
    case lostSelfHalfWay
}

class KeyBackupService {
    
    /// From Element (Riot) implementation.
    /// Are we supposed to expect this to be `false` all the time?
    var needSecretRecovery: Bool {
        // If key backup key is stored in SSSS ask for secrets recovery before restoring key backup.
        let secret = MXSecretId.keyBackup.takeUnretainedValue() as String
        if backup.hasPrivateKeyInCryptoStore && recoveryService.hasRecovery() && recoveryService.hasSecret(withSecretId: secret) {
            // showSecretsRecovery
            return true
        } else {
            // showKeyBackupRecover with keyBackupVersion
            return false
        }
    }
    
    /// Used when `mxKeyBackupDidStateChange` notification fired
    var backupStateChangedNotificationHandler: ((Notification) -> Void)?
    
    private let crypto: MXCrypto!
    private let backup: MXKeyBackup!
    private let recoveryService: MXRecoveryService!
    
    init(crypto: MXCrypto!) {
        self.crypto = crypto
        self.backup = crypto.backup
        self.recoveryService = crypto.recoveryService
        // Listen to backup changes notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyBackupDidStateChange), name: NSNotification.Name.mxKeyBackupDidStateChange, object: self.backup)
        // Checks if the module uses the latest version available on the homeserver.
        backup.forceRefresh(nil, failure: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyBackupDidStateChange(_ notification: Notification) {
        backupStateChangedNotificationHandler?(notification)
    }

    
    // MARK: - Backup States
    
    /// Interprets backup `MXKeyBackupState` into `KeyBackupState`.
    /// Requires `backupVersionTrust` for all backup states.
    /// Falls to `unknown` if unable to interpret or trust missing
    private func getCurrentBackupState(with backupVersionTrust: MXKeyBackupVersionTrust? = nil) -> KeyBackupState {
        switch backup.state {
            
        case MXKeyBackupStateUnknown, MXKeyBackupStateCheckingBackUpOnHomeserver:
            return .checkingBackup
            
        case MXKeyBackupStateDisabled, MXKeyBackupStateEnabling:
            return .noBackup

        case MXKeyBackupStateNotTrusted:
            if let keyBackupVersion = backup.keyBackupVersion,
               let keyBackupVersionTrust = backupVersionTrust {
                return .unverifiedBackup((keyBackupVersion, keyBackupVersionTrust))
            } else {
                return .unknown
            }

        case MXKeyBackupStateReadyToBackUp:
            if let keyBackupVersion = backup.keyBackupVersion,
               let keyBackupVersionTrust = backupVersionTrust {
                return .validBackup((keyBackupVersion, keyBackupVersionTrust))
            } else {
                return .unknown
            }
            
        case MXKeyBackupStateWillBackUp, MXKeyBackupStateBackingUp:
            if let keyBackupVersion = backup.keyBackupVersion,
               let keyBackupVersionTrust = backupVersionTrust {
                return .backupInProgress((keyBackupVersion, keyBackupVersionTrust))
            } else {
                return .unknown
            }

        default:
            return .unknown
        }
    }
    
    /// Checks current backup state. Takes additional time to get trust if needed
    func checkBackupState(completion: @escaping ((KeyBackupState) -> Void)) {
        if let backupVersion = backup.keyBackupVersion {
            backup.trust(for: backupVersion) { [weak self] trust in
                let result = self?.getCurrentBackupState(with: trust) ?? .unknown
                completion(result)
            }
        } else {
            let result = getCurrentBackupState()
            completion(result)
        }
    }
    
    // MARK: - Backup Actions
        
    /// Checks backup version. Provides `nil` if no backup
    func checkBackupVersion(completion: @escaping (Result<MXKeyBackupVersion?, Error>) -> Void) {
        // Only interested in current version
        backup.version(nil) { serverVersion in
            completion(.success(serverVersion))
        } failure: {  error in
            completion(.failure(error))
        }
    }
    
    /// Prepares data for creating new backup
    func prepareNewBackup(completion: @escaping (Result<MXMegolmBackupCreationInfo, Error>) -> Void) {
        // We do not support passphrase in the app
        backup.prepareKeyBackupVersion(withPassword: nil) { info in
            completion(.success(info))
        } failure: {  error in
            completion(.failure(error))
        }
    }
    
    /// Creates new backup and enables it with prepared info from `prepareNewBackup`
    func createNewBackup(_ info: MXMegolmBackupCreationInfo, completion: @escaping (Result<MXKeyBackupVersion, Error>) -> Void) {
        backup.createKeyBackupVersion(info) {  version in
            completion(.success(version))
        } failure: {  error in
            completion(.failure(error))
        }
    }
    
    /// Deletes old backup of a given version
    func deleteOldBackup(version: String, completion: @escaping (Result<Void, Error>) -> Void) {
        backup.deleteVersion(version) {
            completion(.success(()))
        } failure: { error in
            completion(.failure(error))
        }
    }
    
    /// Restores backup of a given version with provided recovery key.
    /// Provides number of found keys and number imported keys
    func restoreBackup(version: MXKeyBackupVersion, with recoveryKey: String, completion: @escaping (Result<(UInt, UInt), Error>) -> Void) {
        backup.restore(version, withRecoveryKey: recoveryKey, room: nil, session: nil) {  foundKeys, importedKeys in
            completion(.success((foundKeys, importedKeys)))
        } failure: {  error in
            completion(.failure(error))
        }
    }
    
    /// Sets provided trust on a given backup
    func setBackupTrust(_ trust: Bool, version: MXKeyBackupVersion, completion: @escaping (Result<Void, Error>) -> Void) {
        backup.trust(version, trust: true) {
            completion(.success(()))
        } failure: { error in
            completion(.failure(error))
        }
    }
    
    // MARK: -
    
    /// Recovers secrets, but for what?!
    private func recoverSecrets(with recoveryKey: String, completion: @escaping (Result<MXSecretRecoveryResult, Error>) -> Void) {
        do {
            let privateKey = try recoveryService.privateKey(fromRecoveryKey: recoveryKey)
            recoveryService.recoverSecrets(nil, withPrivateKey: privateKey, recoverServices: true) {  result in
                completion(.success(result))
            } failure: {  error in
                completion(.failure(error))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
}
