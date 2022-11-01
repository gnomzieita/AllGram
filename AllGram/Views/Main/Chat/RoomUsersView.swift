//
//  RoomUsersView.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 16.02.2022.
//

import SwiftUI
import MatrixSDK
import Kingfisher

class RoomMembersViewModel: ObservableObject {
    @Published private var allMembers: [MemberInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var filterString: String = ""
    
    var filteredMembers: [MemberInfo] {
        guard filterString.hasContent else { return allMembers }
        return allMembers.filter {
            $0.displayname.lowercased().contains(filterString.lowercased())
            || $0.id.lowercased().contains(filterString.lowercased())
        }
    }
    
    let room: AllgramRoom
    
    init(room: AllgramRoom) {
        self.room = room
        self.loadMembers()
    }
    
    func loadMembers() {
        guard !isLoading else { return }
        withAnimation {
            isLoading = true
            error = nil
        }
        room.room.members() { [weak self] response in
            withAnimation {
                guard let self = self else { return }
                self.isLoading = false
                switch response {
                case .success(let roomMembers):
                    self.allMembers = roomMembers?.members?.map { MemberInfo(room: self.room, member: $0) } ?? []
                case .failure(let error):
                    self.error = error
                    self.allMembers = []
                }
            }
        }
    }
    
    /// Expects full user id for proper checking
    func member(with id: String) -> MemberInfo? {
        allMembers.first(where: { $0.id == id })
    }
    
    /// Checks if this room has a member with a given id.
    /// Checks with `:allgram.me` removed and without whitespaces and new lines
    func hasMember(with id: String) -> Bool {
        let match = id.trimmingCharacters(in: .whitespacesAndNewlines).dropAllgramSuffix
        return allMembers.contains(where: { $0.id.dropAllgramSuffix == match })
    }
}

enum PowerLevel: Equatable {
    case unavailable // missing something
    case admin // power level 100
    case moderator // power level 50
    case user // power level 0
    case custom(Int) // custom power level
    
    /// Expects power from in range of 0 to 100
    init(power: Int) {
        switch power {
        case 100: self = .admin
        case 50: self = .moderator
        case 0: self = .user
        case 0...100: self = .custom(power)
        default: self = .unavailable
        }
    }
    
    /// Power level of the role, ranges from 0 to 100
    var power: Int {
        switch self {
        case .unavailable: return -1
        case .admin: return 100
        case .moderator: return 50
        case .user: return 0
        case .custom(let p): return p
        }
    }
    
    /// Role that has this power level
    var role: String {
        switch self {
        case .unavailable: return "Unavailable"
        case .admin: return "Admin"
        case .moderator: return "Moderator"
        case .user: return "User"
        case .custom(let p): return "Custom (\(p))"
        }
    }
}

/// Extends `MXRoomMember` with power levels and real world avatar URL
struct MemberInfo: Identifiable, Equatable {
    static func == (lhs: MemberInfo, rhs: MemberInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    let room: AllgramRoom
    let member: MXRoomMember
    
    init(room: AllgramRoom, member: MXRoomMember) {
        self.room = room
        self.member = member
    }
    
    var id: String { member.userId }
    var displayname: String { member.displayname ?? id.dropAllgramSuffix }
    var avatarURL: URL? { room.realUrl(from: member.avatarUrl) }
    
    var powerLevel: PowerLevel {
        var roomState : MXRoomState?
        room.room.state { aRoomState in
            roomState = aRoomState
        }
        // Room state may be not yet load power levels
        let userPower = roomState?.powerLevels.powerLevelOfUser(withUserID: member.userId)
        return PowerLevel(power: userPower ?? -1)
    }
    
    /// Needs at least one of the following abilities: set role, kick, ban
    func hasAdminActions(over other: MemberInfo) -> Bool {
        canSetRole(for: other) || canKick(other) || canBan(other)
    }
    
    /// Can set role only for members who has `less` power.
    /// Also needs at least `admin` power level
    func canSetRole(for other: MemberInfo) -> Bool {
        guard self.powerLevel.power > other.powerLevel.power else { return false }
        return self.powerLevel.power >= PowerLevel.admin.power
    }
    
    /// Can kick only for members who has `less` power.
    /// Also needs at least `moderator` power level
    func canKick(_ other: MemberInfo) ->  Bool {
        guard self.powerLevel.power > other.powerLevel.power else { return false }
        return self.powerLevel.power >= PowerLevel.moderator.power
    }
    
    /// Can ban only for members who has `less` power.
    /// Also needs at least `moderator` power level
    func canBan(_ other: MemberInfo) ->  Bool {
        guard self.powerLevel.power > other.powerLevel.power else { return false }
        return self.powerLevel.power >= PowerLevel.moderator.power
    }
}

struct RoomUsersView: View {
    @Environment(\.userId) private var userId
    
    @State var room: AllgramRoom
    @StateObject var roomMembersVM: RoomMembersViewModel
    
    var host: MemberInfo? {
        roomMembersVM.member(with: userId)
    }
    
    init(room: AllgramRoom) {
        self.room = room
        self._roomMembersVM = StateObject(wrappedValue: RoomMembersViewModel(room: room))
    }
    
    var body: some View {
        VStack {
            if let error = roomMembersVM.error {
                Text(verbatim: "Error loading members:\n\n\(error.localizedDescription)")
                    .padding()
                Button { roomMembersVM.loadMembers() } label: {
                    Text("Reload")
                        .frame(width: 80, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                        )
                }
            } else {
                HStack {
                    Image("search-solid")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                    TextField("Filter members", text: $roomMembersVM.filterString)
                        .autocapitalization(.none)
                }
                .padding(.horizontal)
                if roomMembersVM.isLoading {
                    ProgressView()
                        .padding()
                    Text("Loading...")
                        .foregroundColor(.gray)
                } else {
                    membersView
                }
            }
        }
        .padding(.top, 8)
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(title: room.room.summary.displayname ?? "")
    }
    
    @ViewBuilder
    private var membersView: some View {
        if !roomMembersVM.filteredMembers.isEmpty {
            ScrollView {
                let powerfulMembers = roomMembersVM.filteredMembers.filter { $0.powerLevel == .admin }
                if !powerfulMembers.isEmpty {
                    ExpandingHStack(contentPosition: .left()) {
                        Text("Admins:")
                            .padding(.horizontal)
                            .padding(.top)
                    }
                    LazyVStack(spacing: 0) {
                        Divider()
                        ForEach(powerfulMembers) { memberInfo in
                            if memberInfo.id == userId {
                                userInfoView(memberInfo)
                            } else {
                                NavigationLink {
                                    RoomUserSettings(room: room, host: host, user: memberInfo)
                                } label: {
                                    userInfoView(memberInfo)
                                }
                            }
                        }
                    }
                }
                // Regular members
                let regularMembers = roomMembersVM.filteredMembers.filter { $0.powerLevel != .admin }
                if !regularMembers.isEmpty {
                    ExpandingHStack(contentPosition: .left()) {
                        Text("Users:")
                            .padding(.horizontal)
                            .padding(.top)
                    }
                    LazyVStack(spacing: 0) {
                        Divider()
                        ForEach(regularMembers) { memberInfo in
                            if memberInfo.id == userId {
                                userInfoView(memberInfo)
                            } else {
                                NavigationLink {
                                    RoomUserSettings(room: room, host: host, user: memberInfo)
                                } label: {
                                    userInfoView(memberInfo)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            Spacer()
            Text("No members")
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func userInfoView(_ item: MemberInfo) -> some View {
        VStack(spacing: 0) {
            HStack {
                AvatarImageView(item.avatarURL, name: item.displayname.dropPrefix("@"))
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.displayname)
                        .font(.headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.reverseColor)
                    Text(verbatim: item.id.dropAllgramSuffix)
                        .font(.subheadline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            Divider()
        }
    }
}
