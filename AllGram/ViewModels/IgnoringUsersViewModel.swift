//
//  IgnoringUsersViewModel.swift
//  AllGram
//
//  Created by Eugene Ned on 02.08.2022.
//

import MatrixSDK
import Foundation

class IgnoringUsersViewModel: ObservableObject {
    @Published private(set) var ignoredUsers: [String] = []
    
    static let shared = IgnoringUsersViewModel()
    
    private init() {
        self.getIgnoredUsersList()
        NotificationCenter.default.addObserver(self, selector: #selector(getIgnoredUsersList), name: .mxSessionIgnoredUsersDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func getIgnoredUsersList() {
        ignoredUsers = AuthViewModel.shared.session!.ignoredUsers ?? []
    }
    
    func ignoreUser(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        AuthViewModel.shared.session?.ignore(users: [userId]) { response in
            switch response {
            case .success():
                completion(.success(()))
            case .failure(let error):
                print("Error when ignoring user: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func unIgnoreUser(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        AuthViewModel.shared.session?.unIgnore(users: [userId]) { response in
            switch response {
            case .success():
                completion(.success(()))
            case .failure(let error):
                print("Error when unignoring user: \(error)")
                completion(.failure(error))
            }
        }
    }
}
