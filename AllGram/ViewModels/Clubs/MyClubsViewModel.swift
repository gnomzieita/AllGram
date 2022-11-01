
//  MyClubsViewModel.swift
//  AllGram
//
//  Created by Igor Antonchenko on 22.02.2022.
//
import SwiftUI
import Foundation
import Combine
import MatrixSDK

struct MyClubInfo: Identifiable, Equatable {
    
    var id: String { roomId }
    
    let roomId: String
    let name: String
    let avatarURL: URL?
    var createdDate: Date?
    
    init(roomId: String, name: String, avatarURL: URL? = nil, createdDate: Date?) {
        self.roomId = roomId
        self.name = name
        self.avatarURL = avatarURL
        self.createdDate = createdDate
    }
    
    init(room: AllgramRoom) {
        self.roomId = room.summary.roomId
        self.name = room.summary.displayname
        self.avatarURL = room.realAvatarURL
        self.createdDate = nil
        
    }
    
    
}

class MyClubsViewModel: ObservableObject {
    
    private var clubs = [Club]()
    private var cancellables = Set<AnyCancellable>()
    private var accessToken: String?
    @Published private(set) var myClubsInfo = [RoomIsDirect]()
    
    @Published private(set) var myClubs = [MyClubInfo]()
    
    private let auth: AuthViewModel
    
    private var roomsInString: [String] {
        guard let myRooms = auth.sessionVM?.clubsCreatedByUser else { return [] }
        return myRooms.map { $0.summary.roomId }
    }
    
    func getCreatedDate(roomID: String) -> Date? {
        for club in myClubsInfo {
            if club.roomID == roomID, let time = club.dateCreated {
                return Date(timeIntervalSince1970: TimeInterval(time))
            }
        }
        return nil
    }
    
    var mxSession: MXSession { auth.session! }
    
    
    init(auth: AuthViewModel) {
        self.auth = auth
        self.accessToken = auth.session?.credentials.accessToken
        getRoomInfo()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func getRoomInfo() {
        NewApiManager.shared.getRoomsInfo(roomsIds: roomsInString)
            .sink { [weak self] roomsInfo in
                self?.myClubsInfo = roomsInfo
            }.store(in: &cancellables)
    }
}
