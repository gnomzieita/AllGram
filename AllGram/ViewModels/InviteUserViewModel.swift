//
//  InviteUserViewModel.swift
//  AllGram
//
//  Created by Vladyslav on 23.12.2021.
//

import Foundation
import Combine
import MatrixSDK

enum InvitationProcessingState: Int {
    case none, inviting, doneSuccessfully, failed, timeoutOfDisplayingSuccess
}

class InviteUserViewModel: SearcherForUsers {
    
    @Published private(set) var processingState = InvitationProcessingState.none
    @Published private(set) var selectedToInvite = [UserInfo]()
    
    /// Room members + all users selected to be invited to the room
    var allSelected: [UserInfo] {
        let mediaManager = mxSession.mediaManager
        let members = roomMembers?.members.map({ UserInfo(member: $0, mediaManager: mediaManager) }) ?? []
        return members + selectedToInvite
    }
    
    let room: AllgramRoom
    let canInvite: Bool

    init(room: AllgramRoom) {
        self.room = room
        
        var isPossibleToInvite = false
        if let roomState = room.room.dangerousSyncState {
            roomMembers = roomState.members
            if let levels = roomState.powerLevels {
                let myLevel = levels.powerLevelOfUser(withUserID: room.session.myUserId)
                isPossibleToInvite = (myLevel >= levels.invite)
            }
        } else {
            roomMembers = nil
        }
        self.canInvite = isPossibleToInvite
        self.wasDirectRoom = room.isDirect
        
        super.init(session: room.session)
    }
    
    deinit {
        stop()
        cancellables.removeAll()
    }
    
    func selectForInvite(_ user: UserInfo) {
        if allSelected.contains(user) {
            deselectFromInvite(user)
        } else {
            selectedToInvite.append(user)
        }
    }
    
    func deselectFromInvite(_ user: UserInfo) {
        selectedToInvite = selectedToInvite.filter({ $0.id != user.id })
    }
    
    func inviteSelected() {
        guard !selectedToInvite.isEmpty else {
            return
        }
        self.processingState = .inviting
        var inviteCount = selectedToInvite.count
        for item in selectedToInvite {
            let operation = room.room.invite(.userId(item.userId)) { [weak self] response in
                inviteCount -= 1
                if inviteCount < 1 {
                    self?.onNewMemberInvited()
                }
            }
            cancellables.insert(AnyCancellable({ operation.cancel() }))
        }
    }
    
    func reset() {
        stop()
        processingState = .none
        searchString = ""
    }
    
    func isRoomMember(item: UserInfo) -> Bool {
        guard let members = roomMembers?.members else {
            return false
        }
        return members.contains {
            $0.displayname == item.displayName && $0.userId == item.userId
        }
    }
    
    func inviteNewRoomMember(item: UserInfo) {
        if isRoomMember(item: item) {
            self.processingState = .doneSuccessfully
            return
        }
        self.processingState = .inviting
        
        let operation = room.room.invite(.userId(item.userId)) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(_):
                self.onNewMemberInvited()
            case .failure(_):
                self.processingState = .failed
            }
        }
        
        cancellables.insert(AnyCancellable({ operation.cancel() }))
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let roomMembers: MXRoomMembers?
    private let wasDirectRoom: Bool
}

private extension InviteUserViewModel {
    
    func scheduleEndOfDisplay() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.processingState = .timeoutOfDisplayingSuccess
        }
        cancellables.insert(AnyCancellable({ timer.invalidate() }))
    }
    
    func onNewMemberInvited() {
        if wasDirectRoom {
            room.room.setIsDirect(false, withUserId: nil) {
                self.processingState = .doneSuccessfully
                self.scheduleEndOfDisplay()
            } failure: { error in
                self.processingState = .failed
            }
            return
        } else {
            processingState = .doneSuccessfully
            scheduleEndOfDisplay()
        }
    }
}
