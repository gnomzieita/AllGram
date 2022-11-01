//
//  FeedVideoContainer.swift
//  AllGram
//
//  Created by Alex Pirog on 28.03.2022.
//

import SwiftUI
import AVFoundation
import Kingfisher

struct FeedVideoContainer: View {
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    let videoURL: URL
    let thumbnailURL: URL
    
    @Binding var play: Bool
    @State private var time: CMTime = .zero
    @State private var isMuted = true
    
    @ObservedObject private var downloader = VideoDownloader()
    
    init(videoInfo: VideoInfo, play: Binding<Bool>) {
        self.videoURL = videoInfo.url
        self.thumbnailURL = videoInfo.thumbnail.url
        _play = play
        downloader.downloadVideo(videoURL)
    }
    
    var body: some View {
//        if !play && time == .zero {
//            // Not issued play and not paused -> show thumbnail
//            KFImage(thumbnailURL)
//                .resizable().scaledToFit()
//                .overlay(PlayImageOverlay())
//                .overlay(
//                    MuteVideoOverlay(isMuted: isMuted) { wasMuted in
//                        withAnimation { isMuted = !wasMuted }
//                    }
//                )
//        } else {
            // Otherwise -> try video
            switch downloader.state {
            case .waiting:
                KFImage(thumbnailURL)
                    .resizable().scaledToFit()
            case .downloading(let progress):
                KFImage(thumbnailURL)
                    .resizable().scaledToFit()
                    .overlay(progressOverlay(progress))
            case .done(let localURL):
                VideoPlayerContainer(videoURL: localURL, play: _play, time: $time, loop: true, mute: isMuted)
                    .overlay(
                        MuteVideoOverlay(isMuted: isMuted) { wasMuted in
                            withAnimation { isMuted = !wasMuted }
                        }
                    )
                    .onChange(of: isMuted) { value in
                        guard !isMuted else { return }
                        // Pause current playing voice message if any
                        voicePlayer.pause()
                    }
            case .failed(let error):
                let problem = (error as NSError?)?.localizedDescription ?? "No data downloaded"
                KFImage(thumbnailURL)
                    .resizable().scaledToFit()
                    .overlay(errorOverlay(problem))
            }
       // }
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

extension FeedVideoContainer: Equatable {
    static func == (lhs: FeedVideoContainer, rhs: FeedVideoContainer) -> Bool {
        lhs.videoURL == rhs.videoURL && lhs.thumbnailURL == rhs.thumbnailURL && lhs.play == rhs.play && lhs.isMuted == rhs.isMuted
    }
}

