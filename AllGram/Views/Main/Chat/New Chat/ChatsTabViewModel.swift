//
//  ChatsTabViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 07.10.2022.
//

import Foundation
import MatrixSDK

enum ChatsTabSection {
    case favorites, chats, meetings, lowPriority
    
    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .chats: return "General chat"
        case .meetings: return "Meetings"
        case .lowPriority: return "Low priority"
        }
    }
}

class ChatsTabViewModel: ObservableObject {
    
    let sessionVM: SessionViewModel
    
    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
    }
    
    // MARK: - Sections
    
    /// Includes `favorites` and `low priority` only when there is something in them
    var availableSections: [ChatsTabSection] {
        var result = [ChatsTabSection]()
        if !getRooms(for: .favorites).isEmpty {
            result.append(.favorites)
        }
        result.append(.chats)
        if !getRooms(for: .meetings).isEmpty {
            result.append(.meetings)
        }
        if !getRooms(for: .lowPriority).isEmpty {
            result.append(.lowPriority)
        }
        return result
    }
    
    /// Returns all rooms for the given section. May contain invites
    func getRooms(for section: ChatsTabSection) -> [AllgramRoom] {
        switch section {
        case .favorites:
            return sessionVM.chatRooms
                .filter { $0.isFavorite }
            
        case .chats:
            return sessionVM.chatRooms
                .filter { !$0.isMeeting && $0.isGeneral }
            
        case .meetings:
            return sessionVM.chatRooms
                .filter { $0.isMeeting && $0.isGeneral }
            
        case .lowPriority:
            return sessionVM.chatRooms
                .filter { $0.isLowPriority }
        }
    }
    
    func markFavorite(_ mark: Bool, room: AllgramRoom) {
        let mxRoom = room.room
        let order = room.session.tagOrderToBe(at: 0, from: UInt(NSNotFound), withTag: kMXRoomTagFavourite)!
        if mark {
            mxRoom.removeTag(kMXRoomTagLowPriority) { _ in
                mxRoom.addTag(kMXRoomTagFavourite, withOrder: order) { _ in
                    //
                }
            }
        } else {
            mxRoom.removeTag(kMXRoomTagFavourite) { _ in
                //
            }
        }
    }
    
    func markLowPriority(_ mark: Bool, room: AllgramRoom) {
        let mxRoom = room.room
        let order = room.session.tagOrderToBe(at: 0, from: UInt(NSNotFound), withTag: kMXRoomTagLowPriority)!
        if mark {
            mxRoom.removeTag(kMXRoomTagFavourite) { _ in
                mxRoom.addTag(kMXRoomTagLowPriority, withOrder: order) { _ in
                    //
                }
            }
        } else {
            mxRoom.removeTag(kMXRoomTagLowPriority) { _ in
                //
            }
        }
    }
}
