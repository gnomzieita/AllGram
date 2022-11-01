//
//  NewFeedVideoView.swift
//  AllGram
//
//  Created by Alex Pirog on 23.09.2022.
//

import SwiftUI
import AVFoundation

struct NewFeedVideoView: View {
    let videoURL: URL
    
    @Binding var play: Bool
    
    @State private var time: CMTime = .zero
    @State private var isMuted: Bool = true
    
    init(_ videoURL: URL, play: Binding<Bool>) {
        self.videoURL = videoURL
        self._play = play
    }
    
    var body: some View {
        VideoPlayerContainer(videoURL: videoURL, play: $play, time: $time, loop: true, mute: isMuted)
            .overlay(
                MuteVideoOverlay(isMuted: isMuted) { wasMuted in
                    withAnimation { isMuted = !wasMuted }
                }
            )
            .onChange(of: isMuted) { value in
                guard !isMuted else { return }
                // Pause current playing voice message if any
                ChatVoicePlayer.shared.pause()
            }
    }
}
