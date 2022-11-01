//
//  SearcherForUsers.swift
//  AllGram
//
//  Created by Vladyslav on 03.01.2022.
//

import Foundation
import Combine
import MatrixSDK

struct UserInfo: Identifiable {
    
    /// Use `userId` as an identifier
    var id: String { userId }
    
    /// User id in Matrix variant, starts with `@` and ends with `:allgram.me`
    let userId: String
    
    let displayName: String
    let avatarURL: URL?
    
    /// Drops `@` prefix and `:allgram.me` suffix from the `userId`
    var shortUserId: String {
        return userId.dropPrefix("@").dropSuffix(":allgram.me")
    }
    
    /// Adds `@` prefix and `:allgram.me` suffix to the `userId` if needed
    init(userId: String, displayName: String, avatarURL: URL? = nil) {
        let properId = (!userId.hasPrefix("@") ? "@" : "") + userId + (!userId.hasSuffix(":allgram.me") ? ":allgram.me" : "")
        self.userId = properId
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
    
    /// MXMediaManager used to get proper URL from avatar matrix URI if any
    init(user: User, mediaManager: MXMediaManager?) {
        var realAvatarUrl: URL?
        if let urlString = mediaManager?.url(ofContent: user.avatarURL) {
            realAvatarUrl = URL(string: urlString)
        }
        self.init(userId: user.userID, displayName: user.displayname, avatarURL: realAvatarUrl)
    }
    
    /// MXMediaManager used to get proper URL from avatar matrix URI if any
    init(member: MXRoomMember, mediaManager: MXMediaManager?) {
        var realAvatarUrl: URL?
        if let urlString = mediaManager?.url(ofContent: member.avatarUrl) {
            realAvatarUrl = URL(string: urlString)
        }
        let name = member.displayname ?? member.userId.dropAllgramSuffix
        self.init(userId: member.userId, displayName: name, avatarURL: realAvatarUrl)
    }
    
    /// MXMediaManager used to get proper URL from avatar matrix URI if any
    init(myUser: MXMyUser, mediaManager: MXMediaManager?) {
        var realAvatarUrl: URL?
        if let urlString = mediaManager?.url(ofContent: myUser.avatarUrl) {
            realAvatarUrl = URL(string: urlString)
        }
        self.init(userId: myUser.userId, displayName: myUser.displayname, avatarURL: realAvatarUrl)
    }
    
}

extension UserInfo: Equatable {
    static func == (lhs: UserInfo, rhs: UserInfo) -> Bool {
        return lhs.userId == rhs.userId
    }
}

class SearcherForUsers: ObservableObject {
    
    /// All search results, including current user of the session if matches the search
    @Published private(set) var searchResult = [UserInfo]()
    
    /// `true` when loading new search results
    @Published private(set) var isBusy = false
    
    var searchString: String = "" {
        didSet {
            if searchString != oldValue {
                DispatchQueue.main.async { [weak self] in
                    self?.resetSearch()
                }
            }
        }
    }
    
    /// Returns search result except of the current user of the session
    var searchResultWithoutSelf: [UserInfo] {
        return searchResult.filter({ $0.userId != mxSession.myUserId })
    }
    
    let mxSession: MXSession
    
    init(session: MXSession) {
        mxSession = session
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func noteIsVisible(item: UserInfo) {
        guard searchResult.last?.id == item.id else { return }
        startSearch()
    }
    
    /// Stops all ongoing searches
    func stop() {
        cancellables.removeAll()
        isBusy = false
    }
    
    func findItem(itemId: String?) -> UserInfo? {
        guard let itemId = itemId else { return nil }
        return searchResult.first { $0.id == itemId }
    }

    private var users = [User]()
    private var cancellables = Set<AnyCancellable>()
    private var nextOffset = 0
    private var isReachedEnd = false
    private var fetchLimit = 30
    
}

private extension SearcherForUsers {
    
    /// Stops ongoing searches, clears old data and start new search if needed
    func resetSearch() {
        stop()
        users.removeAll()
        searchResult.removeAll()
        nextOffset = 0
        isReachedEnd = false
        startSearch()
    }
    
    /// Starts new search if needed (not busy, has search string, etc)
    func startSearch() {
        guard !searchString.isEmpty && !isReachedEnd && !isBusy else { return }
        isBusy = true
        let lower = searchString.lowercased()
        let myId = mxSession.myUserId ?? "nil"
        NewApiManager.shared.redisSearch(searchRequest: lower, fromUserId: myId, limit: fetchLimit, offset: nextOffset)
            .sink { [weak self] nextUsers in
                self?.appendNextUsers(nextUsers)
            }.store(in: &cancellables)
        nextOffset += fetchLimit
    }
    
    func appendNextUsers(_ nextUsers: [User]) {
        isBusy = false
        users.append(contentsOf: nextUsers)
        let mediaManager = mxSession.mediaManager
        searchResult.append(contentsOf: nextUsers.map({ UserInfo(user: $0, mediaManager: mediaManager) }))
        if nextUsers.count < fetchLimit {
            isReachedEnd = true
            // Why sort? it's users, not search result...
            users.sort { user1, user2 in
                let name1 = user1.displayname
                let name2 = user2.displayname
                return (name1 < name2) || (name1 == name2 && user1.userID < user2.userID)
            }
        }
    }
    
}
