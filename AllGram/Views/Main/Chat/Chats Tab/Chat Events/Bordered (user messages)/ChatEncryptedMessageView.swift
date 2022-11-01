//
//  ChatEncryptedMessageView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI

/// Shows default text for any encrypted message
struct ChatEncryptedMessageView: View {
    let text = "This message has not been decrypted"
    
    var body: some View {
        Text(verbatim: text)
            .foregroundColor(.gray)
    }
}
