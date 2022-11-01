//
//  EditVideoContainer.swift
//  AllGram
//
//  Created by Alex Pirog on 06.06.2022.
//

import SwiftUI
import AVFoundation
import VideoPlayer

/// Basic view that shows only video player, without UI for controls
struct EditVideoContainer: View {
    let videoURL: URL
    
    @Binding private var play: Bool
    @Binding private var time: CMTime
    @Binding private var mute: Bool
    
    init(videoURL: URL, play: Binding<Bool>, time: Binding<CMTime>, mute: Binding<Bool>) {
        self.videoURL = videoURL
        _play = play
        _time = time
        _mute = mute
    }
    
    var body: some View {
        VideoPlayer(url: videoURL, play: $play, time: $time)
            .contentMode(.scaleAspectFit) // Fit or Fill?
            .autoReplay(false)
            .mute(mute)
            .onPlayToEndTime {
                // Played to the end - pause
                play = false
            }
    }
}
