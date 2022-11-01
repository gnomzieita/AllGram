//
//  NativePlayerContainer.swift
//  AllGram
//
//  Created by Alex Pirog on 30.03.2022.
//

import SwiftUI
import AVKit

struct NativePlayerContainer: View {
    let videoURL: URL
    
    @State private var player = AVPlayer()
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        let item = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: item)
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player.play()
                // Pause current playing voice message if any
                ChatVoicePlayer.shared.pause()
            }
    }
}
