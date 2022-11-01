//
//  NewClubViewModel.swift
//  AllGram
//
//  Created by Igor Antonchenko on 10.02.2022.
//

import Foundation
import Combine
import MatrixSDK
import SwiftUI

class NewClubViewModel: SearcherForUsers {
    
    private var accessToken: String?
    private var cancels: Set<AnyCancellable> = []
    
    @Published var users = [UserInfo]()
    @Published var isKeyboardShown = false
    @Published var savingInProgress = false
    
    @Published var errorMessage: String?
    
    private var cancellableObjs = Set<AnyCancellable>()
    
    override init(session: MXSession) {
        self.accessToken = session.credentials.accessToken
        super.init(session: session)
        let publisher = NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        publisher.sink { [weak self] notif in
            guard let rect = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }
            let screenBounds = UIScreen.main.bounds
            self?.isKeyboardShown = (rect.minY < 0.7 * screenBounds.height) ||
            (rect.minY < 500.0 && screenBounds.height > 500.0)
        }.store(in: &cancellableObjs)
    }
    deinit {
        cancellableObjs.removeAll()
    }
    
    enum NewClubError: Error, LocalizedError {
        case noAccessToken
        case alreadyInProcess
    }
    
    func save(roomName: String, topic: String, privateClub: Bool, encrypted: Bool, roomAliasName: String, roomDescription: String, completion: ((Result<String, Error>) -> ())? = nil) {
        guard let accessToken = accessToken else {
            completion?(.failure(NewClubError.noAccessToken))
            return
        }
        guard !savingInProgress else {
            completion?(.failure(NewClubError.alreadyInProcess))
            return
        }
        var clubType: ClubRoomType {
            if encrypted {
                return .encrypted
            } else if privateClub {
                return .private
            } else {
                return .public
            }
        }
        self.savingInProgress = true
        ApiManager.shared.createClubRoom(
            roomName: roomName,
            topic: topic,
            type: clubType,
            roomAliasName: roomAliasName,
            roomDescription: roomDescription,
            accessToken: accessToken
        )
            .sink { result in
                switch result {
                case .finished:
                    break
                case .failure(let error):
                    self.savingInProgress = false
                    completion?(.failure(error))
                }
            } receiveValue: { response in
                NotificationCenter.default.post(name: .userCreatedRoom, object: nil)
                
                self.savingInProgress = false
                let roomID = response.roomID
                // We are sure this is a club
                UserDefaults.group.setStoredType(for: roomID, isChat: false, isMeeting: false, forSure: true)
                // Do the update again to ensure correct state
                let newRoom = AuthViewModel.shared.sessionVM?.rooms.first(where: { $0.roomId == roomID })
                newRoom?.checkIsDirectState()
                completion?(.success(roomID))
            }
            .store(in: &cancellableObjs)
    }
    
}
