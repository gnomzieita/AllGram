//
//  CreateRoomResponse.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 26.01.2022.
//

import Foundation

struct CreateRoomResponse: Codable {
    let roomID: String

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
    }
}
extension CreateRoomResponse: Identifiable{
    var id: String { roomID }
}
