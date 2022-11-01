//
//  VideoControlsView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.06.2022.
//

import SwiftUI
import AVFoundation

/// Horizontal stack of basic video controls: play/pause button and progress slider
struct VideoControlsView: View {
    let videoURL: URL
    
    @Binding var play: Bool
    @Binding var time: CMTime
    @Binding var timeRange: ClosedRange<Float>
    
    var startTime: CMTime {
        CMTime(seconds: Double(timeRange.lowerBound), preferredTimescale: time.timescale)
    }
    var endTime: CMTime {
        CMTime(seconds: Double(timeRange.upperBound), preferredTimescale: time.timescale)
    }
    
    var leftText: String {
        "\((time - startTime).positionalTime)\n\(startTime.positionalTime)"
    }
    var rightText: String {
        "-\((endTime - time).positionalTime)\n\(endTime.positionalTime)"
    }
    
    @State var isEditing: Bool = false
    @State var seconds: Float = 0
    
    init(videoURL: URL, play: Binding<Bool>, time: Binding<CMTime>, timeRange: Binding<ClosedRange<Float>>) {
        self.videoURL = videoURL
        _play = play
        _time = time
        _timeRange = timeRange
    }
    
    var body: some View {
        HStack {
            // Play/pause
            Button {
                withAnimation {
                    // Reset to beginning if played to the end
                    if time.seconds >= endTime.seconds {
                        time = startTime
                        DispatchQueue.main.async {
                            play = true
                        }
                    } else {
                        play.toggle()
                    }
                }
            } label: {
                Image(systemName: play ? "pause.fill" : "play.fill")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.reverseColor)
                    .padding(6)
            }
            // Progress
            Slider(
                value: $seconds,
                in: timeRange,
                label: {
                    Text("what?").foregroundColor(.red)
                },
                minimumValueLabel: {
                    Text(verbatim: leftText)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                },
                maximumValueLabel: {
                    Text(verbatim: rightText)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.trailing)
                },
                onEditingChanged: { editing in
                    isEditing = editing
                }
            )
        }
        .onChange(of: seconds) { value in
            // When user is dragging - update video time
            guard isEditing else { return }
            withAnimation {
                play = false
                time = CMTime(seconds: Double(value), preferredTimescale: time.timescale)
            }
        }
        .onChange(of: time) { value in
            // When video is playing - update slider progress
            guard !isEditing else { return }
            withAnimation {
                if time.seconds > Double(timeRange.upperBound) {
                    // Played till trim end time - stop video
                    play = false
                    time = endTime
                } else if time.seconds < Double(timeRange.lowerBound) {
                    // Playing earlier than trim start time - fix
                    play = false
                    time = startTime
                } else {
                    // Playing somewhere inside a range - update
                    seconds = Float(time.seconds)
                }
            }
        }
    }
}

extension CMTime {
    var roundedSeconds: TimeInterval { seconds.isNaN ? 0 : seconds.rounded() }
    var second: Int { Int(roundedSeconds.truncatingRemainder(dividingBy: 60)) }
    var minute: Int { Int(roundedSeconds.truncatingRemainder(dividingBy: 3600) / 60) }
    var hour: Int { Int(roundedSeconds / 3600) }
    var positionalTime: String {
        return hour > 0
        ? String(format: "%d:%02d:%02d", hour, minute, second)
        : String(format: "%02d:%02d", minute, second)
    }
}
