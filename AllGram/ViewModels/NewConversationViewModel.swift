//
//  NewConversationViewModel.swift
//  AllGram
//
//  Created by Serg Basin on 26.10.2021.
//

import Foundation
import Combine
import MatrixSDK

class NewConversationViewModel: SearcherForUsers {
    private var cancels: Set<AnyCancellable> = []
    let strippedMyUserID : String
    
    @Published var users = [UserInfo]()

    @Published var isWaiting = false
    @Published var roomName: String = ""
    @Published var isPublic = false
    @Published var foundUser : UserInfo?
    @Published var isKeyboardShown = false
    
    @Published var errorMessage: String?
    
    private var cancellableObjs = Set<AnyCancellable>()
    
    override init(session: MXSession) {
        var myuserid = session.myUserId ?? ""
        if myuserid.hasPrefix("@") {
            myuserid = String(myuserid.dropFirst())
        }
        if let idx = myuserid.lastIndex(of: ":") {
            myuserid = String(myuserid.prefix(upTo: idx))
        }
        strippedMyUserID = myuserid
        super.init(session: session)
        
        self.$searchResult.sink { namesIds in
            self.foundUser = namesIds.first { $0.shortUserId == self.searchString }
        }.store(in: &cancellableObjs)
        
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
    
    func isEligible(itemId: String) -> Bool {
        return nil != findEligibleUser(itemId: itemId)
    }
    
    func isLackingDataForRoomCreation() -> Bool {
        return users.isEmpty || (users.count > 1 && roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    func addUser() {
        if let u = foundUser {
            users.append(u)
        }
        foundUser = nil
    }
    
    func createRoom(completion: @escaping (ObjectIdentifier) -> Void) {
        isWaiting = true

        let parameters = MXRoomCreationParameters()
        parameters.inviteArray = users.map { $0.userId }
        if users.count == 1 {
            parameters.isDirect = true
            parameters.visibility = MXRoomDirectoryVisibility.private.identifier
            parameters.preset = MXRoomPreset.trustedPrivateChat.identifier
        } else {
            parameters.isDirect = false
            parameters.name = roomName
            if isPublic {
                parameters.visibility = MXRoomDirectoryVisibility.public.identifier
                parameters.preset = MXRoomPreset.publicChat.identifier
            } else {
                parameters.visibility = MXRoomDirectoryVisibility.private.identifier
                parameters.preset = MXRoomPreset.privateChat.identifier
            }
        }

        mxSession.createRoom(parameters: parameters) { [weak self] response in
            switch response {
            case .success(let room):
                completion(room.id)
            case.failure(let error):
                self?.errorMessage = error.localizedDescription
                self?.isWaiting = false
            }
        }
    }
}

private extension NewConversationViewModel {
    func findEligibleUser(itemId: String) -> UserInfo? {
        let item = searchResult.first { $0.id == itemId }
        if let userId = item?.id {
            let isAlreadyChosen = users.contains { $0.userId == userId }
            if isAlreadyChosen || mxSession.myUserId == userId {
                return nil
            }
        }
        return item
    }
}
