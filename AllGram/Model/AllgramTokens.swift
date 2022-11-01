//
//  AllgramTokens.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 20.01.2022.
//

import Foundation

struct AllgramTokens: Codable {
    let token: String
    let refresh_token: String

    enum CodingKeys: String, CodingKey {
        case token = "token"
        case refresh_token = "refresh_token"
    }
}
