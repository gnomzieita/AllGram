//
//  SessionViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 15.08.2022.
//

import Foundation
import Combine
import MatrixSDK

class SessionViewModel: ObservableObject {
    private var cancellable = Set<AnyCancellable>()
    
    let session: MXSession
    
    var myUserId: String { session.myUserId! }
    var myDeviceId: String { session.myDeviceId! }
    var myUser: MXMyUser! { session.myUser }
    
    var client: MXRestClient { session.matrixRestClient! }
    var accessToken: String { session.credentials.accessToken! }
    
    init(_ session: MXSession) {
        self.session = session
        
        listenToRoomListChange()
        
        // Initial get user avatar
        getAvatar { _ in }
    }
    
    deinit {
        cancellableGetAvatar = nil
        cancellableSetAvatar = nil
        cancellable.removeAll()
    }
    
    // MARK: -
    
    @Published private(set) var userAvatarURL: URL?
    
    private var cancellableGetAvatar: AnyCancellable?
    private var cancellableSetAvatar: AnyCancellable?
    
    func getAvatar(completion: @escaping (Result<URL?, Error>) -> Void) {
        cancellableGetAvatar?.cancel()
        cancellableGetAvatar = ApiManager.shared.getCustomAvatar(userId: myUserId, accessToken: accessToken)
            .sink { co in
                switch co {
                case .finished:
                    break
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { [weak self] uri in
                let url = self?.realUrl(from: uri)
                self?.userAvatarURL = url
                completion(.success(url))
            }
    }
    
    func setAvatar(uri: String, completion: @escaping (Bool) -> Void) {
        cancellableSetAvatar?.cancel()
        cancellableSetAvatar = ApiManager.shared.setCustomAvatar(uri: uri, userId: myUserId, accessToken: accessToken)
            .sink { [weak self] success in
                let url = self?.realUrl(from: uri)
                self?.userAvatarURL = url
                completion(success)
            }
    }
    
    /// Gets real URL from matrix storage URI if possible
    func realUrl(from uri: String?) -> URL? {
        var realUrl: URL?
        if let urlString = session.mediaManager.url(ofContent: uri) {
            realUrl = URL(string: urlString)
        }
        return realUrl
    }
    
    // MARK: - Rooms Updates
    
    private var roomsListChangePublisher : Publishers.MergeMany<NotificationCenter.Publisher>?
    
    private func listenToRoomListChange() {
        let nc = NotificationCenter.default
        let listOfNotificationNames : [Notification.Name] =
        [
            // Matrix Notifications
            .mxSessionNewRoom,
            .mxSessionDidLeaveRoom,
            .mxSessionInvitedRoomsDidChange,
            .mxSessionIgnoredUsersDidChange,
            .mxRoomSummaryDidChange,
            
            // Also update to fix new created chat not being chat at first
//            .allgramRoomIsDirectStateChanged
        ]
        
        let mergedPublisher = Publishers.MergeMany(
            listOfNotificationNames.map { nc.publisher(for: $0, object: nil) }
        )
        roomsListChangePublisher = mergedPublisher
        
        mergedPublisher.sink { _ in
            self.counterOfRoomChanges += 1
        }.store(in: &cancellable)
    }
    
    //MARK: - Rooms Actions
    
    @Published var counterOfRoomChanges = 0
    
    func join(to room: MXRoom, completion: ((Bool) -> Void)? = nil) {
        room.join { [weak self] response in
            self?.session.roomsSummaries()
            self?.counterOfRoomChanges += 1
            switch response {
            case .failure(_):
                completion?(false)
            case .success():
                completion?(true)
            }
        }
    }
    
    func leave(from room: MXRoom, completion: ((Bool) -> Void)? = nil) {
        room.leave { [weak self] response in
            self?.session.roomsSummaries()
            self?.counterOfRoomChanges += 1
            switch response {
            case .failure(_):
                completion?(false)
            case .success():
                completion?(true)
            }
        }
    }
    
    // MARK: - Rooms
    
    private var roomCache = [ObjectIdentifier: AllgramRoom]()
    
    private func makeRoom(from mxRoom: MXRoom) -> AllgramRoom {
        let room = AllgramRoom(mxRoom, in: session)
        roomCache[mxRoom.id] = room
        return room
    }
    
    private func updateUserDefaults(with rooms: [AllgramRoom]) {
        let roomItems = rooms.map { RoomItem(room: $0.room) }
        do {
            let data = try JSONEncoder().encode(roomItems)
            UserDefaults.group.set(data, forKey: "roomList")
        } catch {
            // Why have this if not to handle errors?
        }
    }
    
    /// Rooms that are chats (direct chats, group chats, meetings)
    var chatRooms: [AllgramRoom] { rooms.filter({ $0.isChat }) }
    
    /// Rooms that are clubs. Hide if only advertisement club `!etgWYERjldsmjYdnMp:allgram.me`
    var clubRooms: [AllgramRoom] {
        let allClubs = rooms.filter({ $0.isClub })
        return allClubs.count == 1 ? allClubs.filter({ $0.roomId == "!etgWYERjldsmjYdnMp:allgram.me" }) : allClubs
    }
    
    /// All rooms that did NOT go into `chatRooms` and `clubRooms` (should be empty)
    var otherRooms: [AllgramRoom] {
        rooms.filter { room in
            return !chatRooms.contains(where: { $0.room.roomId == room.room.roomId })
            && !clubRooms.contains(where: { $0.room.roomId == room.room.roomId })
        }
    }
    
    /// Rooms created by current user that are clubs
    var clubsCreatedByUser: [AllgramRoom] { clubRooms.filter({ $0.summary.creatorUserId == myUserId }) }
    
    /// All rooms
    var rooms: [AllgramRoom] {
        let rooms = session.rooms
            .map { roomCache[$0.id] ?? makeRoom(from: $0) }
            .sorted { $0.summary.lastMessageDate > $1.summary.lastMessageDate }
        updateUserDefaults(with: rooms)
        return rooms
    }
    
    func room(with roomId: String) -> AllgramRoom? {
        rooms.first(where: { $0.roomId == roomId })
    }
    
    // MARK: - Tab Bar Counters
    
    var unreadChatsCount: Int {
        var result = 0
        for room in chatRooms {
            if room.summary.notificationCount > 0 {
                // Count rooms with unread messages
                result += 1
            } else if room.summary.membership == .invite {
                // Also count invites to rooms
                result += 1
            }
        }
        return result
    }
    
    var unreadClubsCount: Int {
        var result = 0
        for room in clubRooms {
            if room.summary.notificationCount > 0 {
                // Count rooms with unread messages
                result += 1
            } else if room.summary.membership == .invite {
                // Also count invites to rooms
                result += 1
            }
        }
        return result
    }
    
    @Published private(set) var missedCallsCount = 0
    private var isUpdatingMissed = false
    
    /// Initiates update of missed calls count
    func updateMissed() {
        guard !isUpdatingMissed else { return }
        isUpdatingMissed = true
        NewApiManager.shared.getMissedCalls(accessToken: accessToken)
            .sink(receiveValue: { [weak self] count in
                self?.isUpdatingMissed = false
                self?.missedCallsCount = count
            })
            .store(in: &cancellable)
    }
    
    // MARK: - Device List
    
    @discardableResult
    func getDevicesList(completion: @escaping (Result<[MXDevice], Error>) -> Void) -> MXHTTPOperation {
        client.devices() { response in
            switch response {
            case .success(let devices):
                completion(.success(devices))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    func setDeviceName(_ deviceName: String, forDevice deviceId: String, completion: @escaping (Result<Void, Error>) -> Void) -> MXHTTPOperation {
        client.setDeviceName(deviceName, forDevice: deviceId) { response in
            switch response {
            case .success(()):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    func getAuthSession(toDeleteDevice deviceId: String, completion: @escaping (Result<MXAuthenticationSession, Error>) -> Void) -> MXHTTPOperation {
        client.getSession(toDeleteDevice: deviceId) { response in
            switch response {
            case .success(let authSession):
                completion(.success(authSession))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    func deleteDevice(_ deviceID: String, password: String, authSession: MXAuthenticationSession, completion: @escaping (Result<Void, Error>) -> Void) -> MXHTTPOperation {
        let parameters: [String: Any] = [
            "type": kMXLoginFlowTypePassword,
            "user": myUserId,
            "password": password,
            "session": authSession.session!
        ]
        return client.deleteDevice(deviceID, authParameters: parameters) { response in
            switch response {
            case .success(()):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Account Actions
    
    private func getEmail(_ callback: @escaping (String) -> ()) {
        let storedEmails = UserDefaults.group.pendingEmailsPhones.map({ $0.asEmailPhone }).filter({ $0.type == .email })
        if let email = storedEmails.first?.text, email.count > 0 {
            callback(email)
        } else {
            client.thirdPartyIdentifiers() { response in
                switch response {
                case .success(let data):
                    let loaded: [EmailPhone] = (data ?? [])
                        .filter({ $0.medium == kMX3PIDMediumEmail })
                        .map({ EmailPhone(type: .email, text: $0.address, isValid: true) })
                    let stored = UserDefaults.group.pendingEmailsPhones.map({ $0.asEmailPhone })
                    let emails = loaded + stored.filter({ $0.type == .email })
                    if let email = emails.first?.text, email.count > 0 {
                        callback(email)
                    }
                case .failure(_): break
                }
            }
        }
    }
    
    @discardableResult
    func deactivateAccount(password: String, completion: @escaping (Result<Void, Error>) -> Void) -> MXHTTPOperation{
        let parameters: [String: Any] = [
            "type": kMXLoginFlowTypePassword,
            "user": myUserId,
            "password": password,
            //"session": authSession.session ?? "" // Optional, do we need it?
        ]
        return session.deactivateAccount(withAuthParameters: parameters, eraseAccount: false) { response in
            switch response {
            case .success(()):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    @discardableResult
    func resetPassword(withParameters parameters: [String : Any], completion: @escaping (Result<Void, Error>) -> Void) -> MXHTTPOperation {
        client.resetPassword(parameters: parameters) { response in
            switch response {
            case .success(()):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    @discardableResult
    func changePassword(from current: String, to new: String, completion: @escaping (Result<Void, Error>) -> Void) -> MXHTTPOperation {
        client.changePassword(from: current, to: new) { response in
            switch response {
            case .success(()):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
