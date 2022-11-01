//
//  ChatsSectionView.swift
//  AllGram
//
//  Created by Alex Pirog on 03.05.2022.
//

import SwiftUI

/// Section of chats, like favourites, general, meeting, etc.
/// Tells what chat was selected (tap) or highlighted (long press)
struct ChatsSectionView: View {
    
    enum SectionCategory: String {
        case other = "Other" // For strange cases
        case invited = "Invited"
        case favourites = "Favorites"
        case general = "General Сhats"
        case lowPriority = "Low Priority"
        case meetings = "Meetings"
        
        var allowTap: Bool {
            switch self {
            case .invited:
                return false
            default:
                return true
            }
        }
        
        var allowLongPress: Bool {
            switch self {
            case .other, .invited:
                return false
            default:
                return true
            }
        }
    }
    
    let categoryTitle: String
    let allowTap: (String) -> Bool
    let allowLongPress: (String) -> Bool
    
    let rooms: [AllgramRoom]
    
    @Binding var selectedRoomId: String?
    @Binding var highlightedRoomId: String?
    
    // Old (with same rules for whole category)
    init(category: SectionCategory, rooms: [AllgramRoom], selectedRoomId: Binding<String?>, highlightedRoomId: Binding<String?>) {
        self.rooms = rooms
        _selectedRoomId = selectedRoomId
        _highlightedRoomId = highlightedRoomId
        self.categoryTitle = category.rawValue
        self.allowTap = { _ in
            return category.allowTap
        }
        self.allowLongPress = { _ in
            return category.allowLongPress
        }
    }
    
    // New (with custom rules for each row)
    init(rooms: [AllgramRoom],
         selectedRoomId: Binding<String?>,
         highlightedRoomId: Binding<String?>,
         categoryTitle: String,
         allowTap: @escaping (String) -> Bool,
         allowLongPress: @escaping (String) -> Bool
    ) {
        self.rooms = rooms
        _selectedRoomId = selectedRoomId
        _highlightedRoomId = highlightedRoomId
        self.categoryTitle = categoryTitle
        self.allowTap = allowTap
        self.allowLongPress = allowLongPress
    }
    
    var body: some View {
        Section {
            sectionContent
        } header: {
            Text(categoryTitle)
                .font(.subheadline)
        }
    }
    
    private var sectionContent: some View {
        ForEach(rooms) { room in
            ZStack {
                ChatsItemContainerView(
                    room: room,
                    highlighted: highlightedRoomId == room.roomId
                )
                // Almost transparent color to handle tap/press
                // Need this to intercept gestures over the whole row
                if allowTap(room.roomId) || allowLongPress(room.roomId) {
                    Color.green.opacity(0.0001)
                        .onTapGesture {
                            guard allowTap(room.roomId) else { return }
                            withAnimation { selectedRoomId = room.roomId }
                        }
                        .onLongPressGesture {
                            guard allowLongPress(room.roomId) else { return }
                            withAnimation { highlightedRoomId = room.roomId }
                        }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
    
}
