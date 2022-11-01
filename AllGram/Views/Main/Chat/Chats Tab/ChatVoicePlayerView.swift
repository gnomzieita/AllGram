//
//  ChatVoicePlayerView.swift
//  AllGram
//
//  Created by Alex Pirog on 19.07.2022.
//

import SwiftUI
import MatrixSDK

struct ChatVoicePlayerView: View {
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    @ObservedObject var voicePlayer: ChatVoicePlayer
    
    var voiceAttachments: [ChatMediaAttachment]
    
    init(voicePlayer: ChatVoicePlayer, voiceEvents: [MXEvent]) {
        self.voicePlayer = voicePlayer
        self.voiceAttachments = voiceEvents.compactMap { ChatMediaAttachment(event: $0) }
    }
    
    private var currentIndex: Int? {
        voiceAttachments.firstIndex { $0.mediaName == voicePlayer.currentURL?.lastPathComponent }
    }
    
    private var canBackward: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }
    
    private var canForward: Bool {
        guard let index = currentIndex else { return false }
        return index < voiceAttachments.count - 1
    }
    
    private var senderName: String {
        guard let index = currentIndex else { return "Sender Name" }
        let sender = voiceAttachments[index].event.sender!
        return  membersVM.member(with: sender)?.member.displayname ?? sender.dropAllgramSuffix
    }
    
    private var sendTime: String {
        guard let index = currentIndex else { return "00:00" }
        let timestamp = voiceAttachments[index].event.timestamp
        return Formatter.string(for: timestamp, format: .voice)
    }
    
    private var voiceTitle: String {
        "\(senderName) at \(sendTime)"
    }
    
    // For duration slider
    @State var isEditing: Bool = false
    @State var seconds: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Control Buttons
                HStack(spacing: 4) {
                    getPlayerButton("step-backward-solid") {
                        if let index = currentIndex, index - 1 >= 0 {
                            let previous = voiceAttachments[index - 1]
                            if let data = previous.mainData, let name = previous.mediaName {
                                voicePlayer.play(data, named: name, title: voiceTitle)
                            }
                        }
                    }
                    .foregroundColor(canBackward ? .accentColor : .gray)
                    .disabled(!canBackward)
                    getPlayerButton(voicePlayer.isPlaying ? "pause-solid" : "play-solid") {
                        if voicePlayer.isPlaying {
                            voicePlayer.pause()
                        } else {
                            voicePlayer.resume()
                        }
                    }
                    getPlayerButton("step-forward-solid") {
                        if let index = currentIndex, index <= voiceAttachments.count - 2 {
                            let next = voiceAttachments[index + 1]
                            if let data = next.mainData, let name = next.mediaName {
                                voicePlayer.play(data, named: name, title: voiceTitle)
                            }
                        }
                    }
                    .foregroundColor(canForward ? .accentColor : .gray)
                    .disabled(!canForward)
                }
                Spacer()
                // Sender and time
                Text(voicePlayer.title ?? voiceTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                // Close
                getPlayerButton("times-solid") {
                    voicePlayer.clear()
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            if let duration = voicePlayer.currentDuration {
                Slider(
                    value: $seconds,
                    in: 0...max(duration.seconds, voicePlayer.currentTime.seconds),
                    label: {
                        Text("what?").foregroundColor(.red)
                    },
                    onEditingChanged: { editing in
                        isEditing = editing
                        if editing { voicePlayer.pause() }
                        else { voicePlayer.resume() }
                    }
                )
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            }
        }
        .onChange(of: seconds) { value in
            // When user is dragging - update video time
            guard isEditing else { return }
            withAnimation {
                let newTime = CMTime(seconds: value, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                voicePlayer.seek(to: newTime)
            }
        }
        .onChange(of: voicePlayer.currentTime) { value in
            // When video is playing - update slider progress
            guard !isEditing else { return }
            withAnimation {
                seconds = value.roundedSeconds
            }
        }
    }
    
    private func getPlayerButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(name)
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
        }
    }
}
