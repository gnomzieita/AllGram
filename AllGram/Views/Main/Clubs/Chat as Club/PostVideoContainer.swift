//
//  PostVideoContainer.swift
//  AllGram
//
//  Created by Alex Pirog on 28.03.2022.
//

import SwiftUI
import AVFoundation
import Kingfisher

struct PostVideoContainer: View {
    let videoURL: URL
    let thumbnailURL: URL?
    let thumbnailImage: UIImage?
    
    @ObservedObject private var downloader = VideoDownloader()
    
    init(videoURL: URL, thumbnailURL: URL) {
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.thumbnailImage = nil
        downloader.downloadVideo(videoURL)
    }
    
    init(videoURL: URL, thumbnailImage: UIImage) {
        self.videoURL = videoURL
        self.thumbnailURL = nil
        self.thumbnailImage = thumbnailImage
        downloader.downloadVideo(videoURL)
    }
    
    init(videoInfo: VideoInfo) {
        self.videoURL = videoInfo.url
        self.thumbnailURL = videoInfo.thumbnail.url
        self.thumbnailImage = nil
        downloader.downloadVideo(videoURL)
    }
    
    var body: some View {
        switch downloader.state {
        case .waiting:
            thumbnailView
        case .downloading(let progress):
            thumbnailView
                .overlay(progressOverlay(progress))
        case .done(let localURL):
            NativePlayerContainer(videoURL: localURL)
        case .failed(let error):
            let problem = (error as NSError?)?.localizedDescription ?? "No data downloaded"
            thumbnailView
                .overlay(errorOverlay(problem))
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnailImage {
            Image(uiImage: image)
                .resizable().scaledToFit()
        } else {
            KFImage(thumbnailURL)
                .resizable().scaledToFit()
        }
    }
    
    private func progressOverlay(_ percent: Int) -> some View {
        Text("\(percent)%")
            .foregroundColor(.reverseColor)
            .frame(height: 32)
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 16)
                            .foregroundColor(.gray)
            )
    }
    
    private func errorOverlay(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
            .frame(height: 32)
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 16)
                            .foregroundColor(.gray)
            )
    }
    
}

extension PostVideoContainer: Equatable {
    static func == (lhs: PostVideoContainer, rhs: PostVideoContainer) -> Bool {
        lhs.videoURL == rhs.videoURL && lhs.thumbnailURL == rhs.thumbnailURL
    }
}

