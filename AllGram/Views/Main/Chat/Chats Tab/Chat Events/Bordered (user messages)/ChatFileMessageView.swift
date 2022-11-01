//
//  ChatFileMessageView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

struct ChatFileMessageView: View {
    let model: Model
    
    var body: some View {
        HStack(spacing: 12) {
            Image("paperclip-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.allgramMain)
                .padding(.all, 12)
                .opacity(model.isBusy ? 0 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundColor(.gray)
                        .opacity(0.3)
                )
                .overlay(
                    Spinner(.allgramMain)
                        .opacity(model.isBusy ? 1 : 0)
                )
            Text(verbatim: model.fileName)
                .underline()
                .lineLimit(1)
        }
        .padding(12)
    }
    
    struct Model {
        let fileName: String
        let fileSize: Int
        let fileData: Data?
        let isBusy: Bool
        
        init(attachment: ChatMediaAttachment) {
            let event = attachment.event
            if let info: [String: Any] = event.content(valueFor: "info"),
               let size = info["size"] as? Int
            {
                self.fileSize = size
            } else {
                self.fileSize = -1
            }
            self.fileName = attachment.mediaName ?? "Unknown"
            self.fileData = attachment.mainData
            self.isBusy = !attachment.isReady
        }
    }
}
