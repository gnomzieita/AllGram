//
//  StartChatViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 14.02.2022.
//

import Foundation
import Combine
import MatrixSDK

class StartChatViewModel: SearcherForUsers {
    private let accessToken: String?
    
    @Published var selectedToInvite = [UserInfo]()
    @Published private(set) var isCreating = false
    
    /// Current user + all users selected to be invited to the room
    var meAndSelected: [UserInfo] {
        let mediaManager = mxSession.mediaManager
        let me = UserInfo(myUser: mxSession.myUser, mediaManager: mediaManager)
        return [me] + selectedToInvite
    }
    
    override init(session: MXSession) {
        self.accessToken = session.credentials.accessToken
        super.init(session: session)
    }
    
    deinit {
        stop()
        cancellables.removeAll()
    }
    
    func selectForInvite(_ user: UserInfo) {
        if selectedToInvite.contains(user) {
            deselectFromInvite(user)
        } else {
            selectedToInvite.append(user)
        }
    }
    
    func deselectFromInvite(_ user: UserInfo) {
        selectedToInvite = selectedToInvite.filter({ $0.id != user.id })
    }
    
    enum NewChatError: Error, LocalizedError {
        case noAccessToken
        case alreadyInProcess
    }
    
    /// Passes created chat roomId on success or error on failure
    func createChatRoom(completion: ((Result<String, Error>) -> ())? = nil) {
        guard let accessToken = accessToken else {
            completion?(.failure(NewChatError.noAccessToken))
            return
        }
        guard !isCreating else {
            completion?(.failure(NewChatError.alreadyInProcess))
            return
        }
        isCreating = true
        ApiManager.shared.createChatRoom(inviteIDs: selectedToInvite.map { $0.userId }, accessToken: accessToken)
            .sink { result in
                switch result {
                case .finished: break
                case .failure(let error):
                    self.isCreating = false
                    completion?(.failure(error))
                }
            } receiveValue: { response in
                NotificationCenter.default.post(name: .userCreatedRoom, object: nil)
                
                self.isCreating = false
                let roomID = response.roomID
                // We are sure this is a chat
                UserDefaults.group.setStoredType(for: roomID, isChat: true, isMeeting: false, forSure: true)
                // Do the update again to ensure correct states
                let newRoom = AuthViewModel.shared.sessionVM?.rooms.first(where: { $0.roomId == roomID })
                newRoom?.checkIsDirectState()
                newRoom?.checkMeetingState()
                completion?(.success(roomID))
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
