//
//  VideoPlayerContainer.swift
//  AllGram
//
//  Created by Alex Pirog on 28.03.2022.
//

import SwiftUI
import AVFoundation
import VideoPlayer

struct VideoPlayerContainer: View {
    let videoURL: URL
    
    @Binding private var play: Bool
    @Binding private var time: CMTime
    
    let loop: Bool
    let mute: Bool
    
    let onVideoEnded: (() -> Void)?
    
    @State private var playerState: VideoPlayer.State?
    
    init(videoURL: URL, play: Binding<Bool>, time: Binding<CMTime>, loop: Bool, mute: Bool, onVideoEnded: (() -> Void)? = nil) {
        self.videoURL = videoURL
        _play = play
        _time = time
        self.loop = loop
        self.mute = mute
        self.onVideoEnded = onVideoEnded
    }
    
    var body: some View {
        VideoPlayer(url: videoURL, play: $play, time: $time)
            .contentMode(.scaleAspectFit) // Fit or Fill?
            .autoReplay(loop)
            .mute(mute)
            .onBufferChanged { progress in
                //
            }
            .onPlayToEndTime {
                onVideoEnded?()
            }
            .onReplay {
                //
            }
            .onStateChanged { state in
                playerState = state
            }
            .overlay(
                VStack {
                    switch playerState {
                    case .loading:
                        ProgressView()
                            .scaleEffect(2)
                    case .playing:
                        EmptyView()
                    case .paused(_, let bufferProgress):
                        if bufferProgress == 0 {
                            // No buffer - failed to load?
                            Text("Ops!")
                                .foregroundColor(.red)
                        } else {
                            // Just paused - show image
                            PlayImageOverlay()
                        }
                    case .error(let error):
                        Text("Error: " + error.localizedDescription)
                            .foregroundColor(.red)
                    case .none:
                        // `Play` not issued - offscreen?
                        EmptyView()
                    }
                }
            )
    }
}

// MARK: -

struct PlayImageOverlay: View {
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 60, color: Color = .allgramMain) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Image(systemName: "play.circle")
            .resizable().scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

// MARK: -

struct MuteVideoOverlay: View {
    typealias MuteChangeHandler = (_ wasMuted: Bool) -> Void
    
    let isMuted: Bool
    let tapHandler: MuteChangeHandler
    
    var imageName: String {
        isMuted
        ? "volume-off-solid"
        : "volume-up-solid"
    }
    
    init(isMuted: Bool, tapHandler: @escaping MuteChangeHandler) {
        self.isMuted = isMuted
        self.tapHandler = tapHandler
    }
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(imageName)
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.black.opacity(0.3))
                    )
                    .onTapGesture { tapHandler(isMuted) }
            }
            .padding(6)
        }
    }
}
