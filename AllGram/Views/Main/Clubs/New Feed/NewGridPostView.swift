//
//  NewGridPostView.swift
//  AllGram
//
//  Created by Alex Pirog on 22.09.2022.
//

import SwiftUI

struct NewGridPostView: View {
    /// Handles downloading of media files, both encrypted and row
    @StateObject var attachment: ChatMediaAttachment
    
    let post: NewClubPost
    let mediaSize: CGFloat
    let tapHandler: (() -> Void)?
    
    init(post: NewClubPost, mediaSize: CGFloat, tapHandler: (() -> Void)? = nil) {
        self.post = post
        self.mediaSize = mediaSize
        self.tapHandler = tapHandler
        self._attachment = StateObject(wrappedValue: ChatMediaAttachment(event: post.mediaEvent!))
    }
    
    var body: some View {
        mediaView
            .frame(width: mediaSize, height: mediaSize)
            .clipped()
            .onTapGesture {
                tapHandler?()
            }
    }
    
    @ViewBuilder
    private var mediaView: some View {
        switch post.mediaEvent!.messageType! {
        case .image:
            if let data = attachment.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
            }
            
        case .video:
            if let data = attachment.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .overlay(PlayImageOverlay(size: mediaSize / 4))
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
            }
            
        default:
            Text("No Media!")
                .font(.largeTitle)
                .foregroundColor(.red)
        }
    }
}

extension NewGridPostView: Equatable {
    static func == (lhs: NewGridPostView, rhs: NewGridPostView) -> Bool {
        lhs.post == rhs.post
    }
}
