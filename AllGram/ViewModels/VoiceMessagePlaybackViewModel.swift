// 
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import AVFoundation
import DSWaveformImage
import Combine
import SwiftUI

enum VoiceMessagePlaybackState {
    case stopped
    case playing
    case paused
    case error
}

class VoiceMessagePlaybackViewModel: ObservableObject, VoiceMessageAudioPlayerDelegate {
    
    private var cancels = Set<AnyCancellable>()
    
    private enum Constants {
        static let elapsedTimeFormat = "m:ss"
    }
    
    private let mediaServiceProvider: VoiceMessageMediaServiceProvider
    private let cacheManager: VoiceMessageAttachmentCacheManager
    
    private(set) var audioPlayer: VoiceMessageAudioPlayer?
    private var samples: [Float] = []
    private var duration: TimeInterval = 0
    private var urlToLoad: URL? {
        didSet {
            guard let urlToLoad = urlToLoad else {
                waveform = nil
                return
            }
            
            guard urlToLoad != oldValue else {
                return
            }

            
            let waveformImageDrawer = WaveformImageDrawer()
            waveformImageDrawer.waveformImage(fromAudioAt: urlToLoad, with: .init(
                                              size: CGSize(width: 200, height: 50),
                                              style: .striped(Waveform.Style.StripeConfig(color: .gray, width: 1, spacing: 1, lineCap: CGLineCap.round)),
                                              position: .middle)) { newImage in
                // need to jump back to main queue
                DispatchQueue.main.async {
                    self.waveform = newImage
                }
            }

        }
    }
    private var loading: Bool = false
    
    @Published var waveform: UIImage?
    @Published var state: VoiceMessagePlaybackState = .stopped
    @Published var currentTime: String = ""
    @Published var progress: Double = 0
    
    private var timeObserverToken: Any?
    
    private(set) var progressSeconds: Int? {
        didSet {
            guard let progressSeconds = progressSeconds else {
                progressSecondsString = nil
                return
            }
            let minutes = Int(progressSeconds / 60)
            let seconds = progressSeconds - (60 * minutes)
            progressSecondsString = String(format: "%d:%02d", minutes, seconds)
            
        }
    }
    
    @Published private(set) var progressSecondsString: String?
    
    func addPeriodicTimeObserver() {
        // Notify every half second
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 1, preferredTimescale: timeScale)

        timeObserverToken = audioPlayer?.audioPlayer?.addPeriodicTimeObserver(forInterval: time,
                                                          queue: .main) {
            [weak self] time in
            
            self?.progressSeconds = Int(CMTimeGetSeconds(time))
            // update player transport UI
        }
    }

    func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            audioPlayer?.audioPlayer?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private static let timeFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Constants.elapsedTimeFormat
        return dateFormatter
    }()

    init(mediaServiceProvider: VoiceMessageMediaServiceProvider, cacheManager: VoiceMessageAttachmentCacheManager) {
        self.mediaServiceProvider = mediaServiceProvider
        self.cacheManager = cacheManager
        
        $state
            .sink { [weak self] state in
                switch state {
                case .stopped:
                    self?.currentTime = VoiceMessagePlaybackViewModel.timeFormatter.string(from: Date(timeIntervalSinceReferenceDate: self?.duration ?? 0))
                    self?.progress = 0.0
                default:
                    if let audioPlayer = self?.audioPlayer {
                        self?.currentTime = VoiceMessagePlaybackViewModel.timeFormatter.string(from: Date(timeIntervalSinceReferenceDate: audioPlayer.currentTime))
                        self?.progress = (audioPlayer.duration > 0.0 ? audioPlayer.currentTime / audioPlayer.duration : 0.0)
                    }
                }
            }
            .store(in: &cancels)
    }
    
    var attachment: Attachment? {
        didSet {
            loadAttachmentData()
        }
    }
    
    // MARK: - VoiceMessagePlaybackViewDelegate
    func voiceMessagePlaybackViewDidRequestPlaybackToggle() {
        guard let audioPlayer = audioPlayer else {
            return
        }
        
        if audioPlayer.url != nil {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.seekToTime(0.0)
                audioPlayer.play()
            }
            addPeriodicTimeObserver()
        } else if let url = urlToLoad {
            audioPlayer.loadContentFromURL(url, displayName: attachment?.originalFileName)
            audioPlayer.play()
            addPeriodicTimeObserver()
        }
    }
    
    // MARK: - VoiceMessageAudioPlayerDelegate
    
    func audioPlayerDidFinishLoading(_ audioPlayer: VoiceMessageAudioPlayer) {

    }
    
    func audioPlayerDidStartPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        state = .playing
    }
    
    func audioPlayerDidPausePlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        state = .paused
    }
    
    func audioPlayerDidStopPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        state = .stopped
        removePeriodicTimeObserver()
    }
    
    func audioPlayer(_ audioPlayer: VoiceMessageAudioPlayer, didFailWithError error: Error) {
        state = .error
    }
    
    func audioPlayerDidStartLoading(_ audioPlayer: VoiceMessageAudioPlayer) {
        
    }
    
    func audioPlayerDidFinishPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        audioPlayer.seekToTime(0.0)
        state = .stopped
    }
    
    // MARK: - Private
        
    private func loadAttachmentData() {
        guard let attachment = attachment else {
            return
        }
        
//        self.state = .stopped
        
        let requiredNumberOfSamples = 35//playbackView.getRequiredNumberOfSamples()
        
        cacheManager.loadAttachment(attachment, numberOfSamples: requiredNumberOfSamples) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let result):
                guard result.eventIdentifier == attachment.eventId else {
                    return
                }
                
                self.audioPlayer = self.mediaServiceProvider.audioPlayerForIdentifier(result.eventIdentifier)
                
                self.loading = false
                self.urlToLoad = result.url
                self.duration = result.duration
                self.samples = result.samples
                
                if let audioPlayer = self.audioPlayer {
                    if audioPlayer.isPlaying {
                        self.state = .playing
                    } else if audioPlayer.currentTime > 0 {
                        self.state = .paused
                    } else {
                        self.state = .stopped
                    }
                }
            case .failure:
                self.state = .error
            }
        }
    }
}
