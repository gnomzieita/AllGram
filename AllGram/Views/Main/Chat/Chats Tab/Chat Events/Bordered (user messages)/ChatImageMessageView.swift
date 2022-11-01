//
//  ChatImageMessageView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

struct ChatImageMessageView: View {
    let model: Model
    
    var safeSize: CGSize {
        model.size ?? CGSize(width: 200, height: 300)
    }
    
    var body: some View {
        if let image = model.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(safeSize, contentMode: .fit)
                .frame(maxHeight: UIScreen.main.bounds.height / 2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Rectangle()
                .foregroundColor(model.isBusy ? .clear : .black)
                .aspectRatio(safeSize, contentMode: .fit)
                .frame(maxHeight: UIScreen.main.bounds.height / 2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(overlayView)
        }
    }
    
    @ViewBuilder
    private var overlayView: some View {
        if model.isBusy {
            // Is busy loading/decrypting
            ProgressView()
        } else if model.image != nil {
            // Image available
            EmptyView()
        } else {
            // Failed to get image
            Text("Image").foregroundColor(.red)
        }
    }
    
    struct Model {
        let image: UIImage?
        let size: CGSize?
        let isBusy: Bool

        init(attachment: ChatMediaAttachment) {
            let event = attachment.event
            if let info: [String: Any] = event.content(valueFor: "info"),
               let width = info["w"] as? Double,
               let height = info["h"] as? Double
            {
                self.size = CGSize(width: width, height: height)
            } else {
                self.size = nil
            }
            if let imageData = attachment.imageData {
                self.image = UIImage(data: imageData)
            } else {
                self.image = nil
            }
            self.isBusy = !attachment.isReady
        }
    }
}
