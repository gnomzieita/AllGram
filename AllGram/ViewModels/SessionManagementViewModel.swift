//
//  SessionManagementViewModel.swift
//  AllGram
//
//  Created by Eugene Ned on 21.07.2022.
//

import Foundation
import MatrixSDK
import Combine

class SessionManagementViewModel: ObservableObject {
    @Published private(set) var currentDevice: MXDevice?
    @Published private(set) var devicesList: [MXDevice] = []
    
    init() { }
    
    func getDevicesList(completion: @escaping (Result<Void, Error>) -> Void) {
        AuthViewModel.shared.sessionVM?.getDevicesList { [weak self] result in
            switch result {
            case .success(let devices):
                self?.devicesList = devices.filter { $0.deviceId != AuthViewModel.shared.session?.myDeviceId }
                self?.currentDevice = devices.first { $0.deviceId == AuthViewModel.shared.session?.myDeviceId }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func renameDevice(_ name: String, deviceId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        AuthViewModel.shared.sessionVM?.setDeviceName(name, forDevice: deviceId) { [weak self] result in
            switch result {
            case .success(()):
                self?.getDevicesList(completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func terminateSession(deviceId: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        AuthViewModel.shared.sessionVM?.getAuthSession(toDeleteDevice: deviceId) { [weak self] sessionResult in
            switch sessionResult {
            case .success(let session):
                AuthViewModel.shared.sessionVM?.deleteDevice(deviceId, password: password, authSession: session) { [weak self] deleteResult in
                    switch deleteResult {
                    case .success(()):
                        self?.getDevicesList(completion: completion)
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

