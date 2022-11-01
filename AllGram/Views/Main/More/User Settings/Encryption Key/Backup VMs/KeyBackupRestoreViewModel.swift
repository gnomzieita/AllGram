//
//  KeyBackupRestoreViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 29.01.2022.
//

import Foundation
import Combine
import MatrixSDK

class KeyBackupRestoreViewModel: ObservableObject {
    
    enum RestoreState {
        case ready(hasProblems: Bool)
        case restored(foundKeys: Int, importedKeys: Int)
    }
    
    @Published private(set) var state: RestoreState = .ready(hasProblems: false)
    
    // Service for all backup actions
    private let backupService: KeyBackupService
    
    // Version to try to recover backup
    private let version: MXKeyBackupVersion
    
    init(backupService: KeyBackupService, version: MXKeyBackupVersion) {
        self.backupService = backupService
        self.version = version
    }
    
    // MARK: - Handle Selected Files
    
    func handleSelectedFile(at url: URL?) -> Result<String, Error> {
        guard let selectedFile: URL = url else {
            return .failure(KeyBackupError.fileNotSelected)
        }
        if selectedFile.startAccessingSecurityScopedResource() {
            defer { selectedFile.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: selectedFile),
                  let key = String(data: data, encoding: .utf8)
            else {
                return .failure(KeyBackupError.fileFailedToGetContent)
            }
            return .success(key)
        } else {
            return .failure(KeyBackupError.fileNoAccess)
        }
    }
    
    // MARK: - Handle Recovery
    
    /// Does restore and trust. Can fail half-way
    func recoverBackup(with key: String, completion: @escaping (Result<Void, Error>) -> Void) {
        backupService.restoreBackup(version: version, with: key) { [weak self] restoreResult in
            switch restoreResult {
            case .success((let foundKeys, let importedKeys)):
                guard let self = self else {
                    completion(.failure(KeyBackupError.lostSelfHalfWay))
                    return
                }
                self.backupService.setBackupTrust(true, version: self.version) { [weak self] trustResult in
                    switch trustResult {
                    case .success(()):
                        self?.state = .restored(foundKeys: Int(foundKeys), importedKeys: Int(importedKeys))
                        completion(.success(()))
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
