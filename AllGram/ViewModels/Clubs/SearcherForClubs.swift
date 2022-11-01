//
//  SearcherForClubs.swift
//  AllGram
//
//  Created by Alex Pirog on 15.02.2022.
//

import Foundation
import Combine
import MatrixSDK

struct ClubInfo: Identifiable, Equatable {
    
    var id: String { roomId }
    
    let roomId: String
    let name: String
    let avatarURL: URL?
    var isMember: Bool? // nil when checking membership
    
    init(roomId: String, name: String, avatarURL: URL? = nil, isMember: Bool? = nil) {
        self.roomId = roomId
        self.name = name
        self.avatarURL = avatarURL
        self.isMember = isMember
    }
    
    /// MXMediaManager used to get proper URL from avatar matrix URI if any
    init(club: Club, isMember: Bool? = nil, mediaManager: MXMediaManager?) {
        var realAvatarUrl: URL?
        if let urlString = mediaManager?.url(ofContent: club.avatarURI) {
            realAvatarUrl = URL(string: urlString)
        }
        self.roomId = club.roomId
        self.name = club.name ?? "nil"
        self.avatarURL = realAvatarUrl
        self.isMember = isMember
    }
    
}

enum ClubsSearchProcessingState {
    case ready, searching, checkingMembership, finished, failed
}

class SearcherForClubs: ObservableObject {
    
    private var clubs = [Club]()
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var searchResult = [ClubInfo]()
    @Published private(set) var state: ClubsSearchProcessingState = .ready 
    
    var isBusy: Bool {
        switch state {
        case .searching, .checkingMembership: return true
        default: return false
        }
    }
    
    var searchString: String = "" {
        didSet {
            if searchString != oldValue {
                DispatchQueue.main.async { [weak self] in
                    self?.resetSearch()
                }
            }
        }
    }
    
    private let auth: AuthViewModel
    
    var mxSession: MXSession { auth.session! }
    
    init(auth: AuthViewModel) {
        self.auth = auth
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    
    // MARK: - Room for Selected
    
    func getAllgramRoom(for roomId: String?) -> AllgramRoom? {
        return auth.sessionVM?.rooms.first(where: { $0.room.roomId == roomId })
    }
    
    // MARK: - Join
    
    func joinClub(_ club: ClubInfo, completion: ((Bool) -> Void)? = nil) {
        mxSession.joinRoom(club.roomId, viaServers: nil, withSignUrl: nil) { [weak self] response in

            switch response {
            case .success(_):
                if let index = self?.searchResult.firstIndex(of: club) {
                    self?.searchResult[index].isMember = true
                }
                completion?(true)
            case .failure(_):
                completion?(false)
            }
        }
    }
    
    // MARK: - Search
    
    /// Stops ongoing searches, clears old data and start new search if needed
    func resetSearch() {
        stop(clearData: true)
        startSearch()
    }
    
    /// Stops all ongoing searches. Does not clear loaded data by default
    func stop(clearData: Bool = false) {
        cancellables.removeAll()
        state = .ready
        if clearData {
            clubs.removeAll()
            searchResult.removeAll()
        }
    }
    
    /// Starts new search if needed (not busy, has search string, etc)
    private func startSearch() {
        guard !isBusy else {
            return
        }
        state = .searching
        let lower = searchString.lowercased()
        ApiManager.shared.clubsSearch(userId: mxSession.myUserId, searchTerm: lower)
            .sink { [weak self] newClubs in
                self?.state = .checkingMembership
                self?.clubs = newClubs
                self?.checkMembership(on: newClubs)
            }.store(in: &cancellables)

    }
    
    /// Checks membership and updates search results accordingly
    private func checkMembership(on newClubs: [Club]) {
        guard state == .checkingMembership else { return }
        let mediaManager = mxSession.mediaManager
        searchResult = newClubs
            .map {
                ClubInfo(club: $0, isMember: mxSession.isJoined(onRoom: $0.roomId), mediaManager: mediaManager)
            }
            .sorted(by: { a, b in
                if a.isMember == true {
                    return true
                } else {
                    return false
                }
            })
        state = .finished
    }
    
}
