//
//  ChatRoomsView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.10.2022.
//

import SwiftUI

struct ChatRoomsView: View {
    let rooms: [AllgramRoom]
    
    @Binding var focused: AllgramRoom?
    
    typealias RoomHandler = (AllgramRoom) -> Void
    
    let tapHandler: RoomHandler?
    let pressHandler: RoomHandler?
    let actionHandler: RoomHandler?
    
    init(_ rooms: [AllgramRoom], focused: Binding<AllgramRoom?>, tapHandler: RoomHandler?, pressHandler: RoomHandler?, actionHandler: RoomHandler?) {
        self.rooms = rooms
        self._focused = focused
        self.tapHandler = tapHandler
        self.pressHandler = pressHandler
        self.actionHandler = actionHandler
    }
    
    var body: some View {
            LazyVStack(spacing: 0) {
                ForEach(rooms) { room in
                    ChatRowView(room: room) {
                        actionHandler?(room)
                    }
                    .padding(.horizontal, Constants.rowHPadding)
                    .padding(.vertical, Constants.rowVPadding)
                    .background(room.isInvite ? Color.cardDisabled : .cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.contentCorner)
                            .strokeBorder(Color.ourOrange, lineWidth: 2)
                            .opacity(room.roomId == focused?.roomId ? 1 : 0)
                    )
                    .onTapGesture {
                        tapHandler?(room)
                    }
                    .onLongPressGesture {
                        pressHandler?(room)
                    }
                    if room.roomId != rooms.last?.roomId {
                        Divider()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Constants.contentCorner))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.contentCorner)
                    .strokeBorder(Color.cardBorder)
            )
            .padding(.vertical, Constants.contentVPadding)
    }
    
    // MARK: -
    
    struct Constants {
        static let contentVPadding: CGFloat = 16
        static let contentCorner: CGFloat = 8
        static let rowVPadding: CGFloat = 10
        static let rowHPadding: CGFloat = 16
    }
}
