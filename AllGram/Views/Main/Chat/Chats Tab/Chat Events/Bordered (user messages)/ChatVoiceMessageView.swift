//
//  ChatVoiceMessageView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI
import MatrixSDK
import DSWaveformImage

struct ChatVoiceMessageView: View {
    let model: Model
    
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    var voiceTitle: String {
        let senderName = membersVM.member(with: model.sender)?.member.displayname ?? model.sender.dropAllgramSuffix
        let sendTime = Formatter.string(for: model.timestamp, format: .voice)
        return "\(senderName) at \(sendTime)"
    }
    
    /// `true` if voice player current item matches this voice message data
    var isPlayerItem: Bool {
        if let playerName = voicePlayer.currentURL?.lastPathComponent,
           let modelName = model.name {
            return playerName == modelName
        }
        return false
    }
    
    /// Checks voice player only when needed, otherwise returns `false`
    var isPlaying: Bool {
        guard !model.isBusy && isPlayerItem else { return false }
        return voicePlayer.isPlaying
    }
    
    /// Takes either voice player current time or voice message duration
    var time: TimeInterval {
        if isPlayerItem && voicePlayer.currentTime > .zero {
            return min(model.duration, voicePlayer.roundedTime)
        } else {
            return model.duration
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Play button
            Button {
                if isPlaying {
                    voicePlayer.pause()
                } else {
                    voicePlayer.play(model.audioData!, named: model.name!, title: voiceTitle)
                }
            } label: {
                Image(isPlaying ? "pause-solid" : "play-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(.gray)
                    .padding(6)
                    .opacity(model.isBusy ? 0 : 1)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(
                        Spinner(.gray)
                            .opacity(model.isBusy ? 1 : 0)
                    )
            }
            .frame(width: 40, height: 40)
            .padding(6)
            .disabled(model.isBusy)
            // Time (keep width for maximum possible space)
            Text(model.duration > 3600 ? "00:00:00" : "00:00")
                .opacity(0)
                .overlay(
                    Text(time.durationText)
                        .foregroundColor(.gray)
                )
            // Waveform
            if let wave = model.waveform {
                Image(uiImage: wave)
                    .resizable()//.scaledToFill()
                    .frame(width: wave.size.width, height: wave.size.height)
                    //.clipped()
                    .padding(.horizontal, 6)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 2)
                    .padding(.horizontal, 6)
            }
        }
    }
    
    struct Model {
        let audioData: Data?
        let name: String?
        let duration: TimeInterval
        let waveform: UIImage?
        let isBusy: Bool
        // For global voice player
        let sender: String
        let timestamp: Date
        
        init(attachment: ChatMediaAttachment) {
            let event = attachment.event
            if let voiceData: [String: Any] = event.content(valueFor: "org.matrix.msc1767.audio"),
               let rawDuration = voiceData["duration"] as? Int,
               let rowWave = voiceData["waveform"] as? [Float]
            {
                self.duration = max(TimeInterval(rawDuration) / 1000, 1)
                
                // We need no normilize waveform values to (0...1)
                // and provide size where width should be exactly
                // number of samples divided by waveform scale
                
                // Event contains up to 100 samples for all durations,
                // but short (1 sec) can provide 100 and long (1 min) only 60
                // and each sample ranges from 0 to up almost to 1000
                
                let max: Float = 1000 //rowWave.sorted().last ?? 0
                let normalizedWave = rowWave.map({ 1 - $0 / max })
                
                let waveScale: CGFloat = 2
                // UIScreen.main.scale / 3 // default in waveform drawer / 3
                let waveSize = CGSize(width: CGFloat(normalizedWave.count) / waveScale, height: 30)
                
                let waveformImageDrawer = WaveformImageDrawer()
                self.waveform = waveformImageDrawer.waveformImage(
                    from: normalizedWave,
                    with: .init(
                        size: waveSize,
                        backgroundColor: .clear, // default
                        style: .striped(
                            .init(
                                color: .gray,
                                width: 1, spacing: 1,
                                lineCap: CGLineCap.round
                            )
                        ),
                        dampening: nil, // default
                        position: .middle, // default
                        scale: waveScale > 1 ? waveScale : 1, // at least 1
                        verticalScalingFactor: 0.95, // default
                        shouldAntialias: false // default
                    )
                )
            } else {
                self.duration = 1234
                self.waveform = nil
            }
            self.audioData = attachment.voiceData
            self.name = attachment.mediaName
            self.isBusy = !attachment.isReady
            // For global voice player
            self.sender = attachment.event.sender!
            self.timestamp = attachment.event.timestamp
        }
    }
}
