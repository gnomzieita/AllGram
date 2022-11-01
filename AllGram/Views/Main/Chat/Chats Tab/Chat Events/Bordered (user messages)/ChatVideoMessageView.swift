//
//  ChatVideoMessageView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK

struct ChatVideoMessageView: View {
    let model: Model
    
    var safeSize: CGSize {
        model.size ?? CGSize(width: 300, height: 200)
    }
    
    var body: some View {
        if let image = model.thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(safeSize, contentMode: .fit)
                .frame(maxHeight: UIScreen.main.bounds.height / 2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(PlayImageOverlay(size: 32))
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
        } else if model.thumbnail != nil {
            // Image available
            EmptyView()
        } else {
            // Failed to get image
            Text("Video").foregroundColor(.red)
        }
    }
    
    struct Model {
        let video: Data?
        let thumbnail: UIImage?
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
            if let videoData = attachment.videoData {
                self.video = videoData
            } else {
                self.video = nil
            }
            if let imageData = attachment.thumbnailData {
                self.thumbnail = UIImage(data: imageData)
            } else {
                self.thumbnail = nil
            }
            self.isBusy = !attachment.isReady
        }
    }
}
