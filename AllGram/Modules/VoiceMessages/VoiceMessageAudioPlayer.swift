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
import Combine

protocol VoiceMessageAudioPlayerDelegate: AnyObject {
    func audioPlayerDidStartLoading(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidFinishLoading(_ audioPlayer: VoiceMessageAudioPlayer)
    
    func audioPlayerDidStartPlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidPausePlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidStopPlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    func audioPlayerDidFinishPlaying(_ audioPlayer: VoiceMessageAudioPlayer)
    
    func audioPlayer(_ audioPlayer: VoiceMessageAudioPlayer, didFailWithError: Error)
}

enum VoiceMessageAudioPlayerError: Error {
    case genericError
}

class VoiceMessageAudioPlayer: NSObject, ObservableObject {
    
    @Published private var playerItem: AVPlayerItem?
    @Published private(set) var audioPlayer: AVPlayer?
    
    private var statusObserver: AnyCancellable?
    private var playbackBufferEmptyObserver: AnyCancellable?
    private var rateObserver: AnyCancellable?
    private var playToEndObserver: NSObjectProtocol?
        
    private(set) var url: URL?
    private(set) var displayName: String?
    
    var isPlaying: Bool {
        guard let audioPlayer = audioPlayer else {
            return false
        }
        
        return (audioPlayer.rate > 0)
    }
    
    var duration: TimeInterval {
        return abs(CMTimeGetSeconds(self.audioPlayer?.currentItem?.duration ?? .zero))
    }
    
    var currentTime: TimeInterval {
        return abs(CMTimeGetSeconds(audioPlayer?.currentTime() ?? .zero))
    }
    
    private(set) var isStopped = true
    
    func loadContentFromURL(_ url: URL, displayName: String? = nil) {
        if self.url == url {
            return
        }
        
        self.url = url
        self.displayName = displayName
        
        playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)

    }
    
    func unloadContent() {
        url = nil
        audioPlayer?.replaceCurrentItem(with: nil)
    }
    
    func play() {
        isStopped = false
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
        
        audioPlayer?.play()
    }
    
    func pause() {
        audioPlayer?.pause()
    }
    
    func stop() {
        if isStopped {
            return
        }
        
        isStopped = true
        audioPlayer?.pause()
        audioPlayer?.seek(to: .zero)
    }
    
    func seekToTime(_ time: TimeInterval) {
        audioPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 60000))
    }
    
    // MARK: - Private
    
    private func addObservers() {
        guard audioPlayer != nil, playerItem != nil else {
            return
        }
        
        statusObserver = $playerItem
            .map { $0?.status }
            .sink(receiveCompletion: { completion in
            }, receiveValue: { status in

            })
        
        playbackBufferEmptyObserver = $playerItem
            .map { $0?.isPlaybackBufferEmpty }
            .sink(receiveCompletion: { completion in
            }, receiveValue: { state in

            })
        
        rateObserver = $audioPlayer
            .map { $0?.rate }
            .sink(receiveCompletion: { completion in
            }, receiveValue: { rate in

            })
        
        playToEndObserver = NotificationCenter.default.addObserver(forName: Notification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil) { [weak self] notification in
            guard self != nil else { return }
            
        }
    }
    
    private func removeObservers() {
        statusObserver?.cancel()
        playbackBufferEmptyObserver?.cancel()
        rateObserver?.cancel()
        NotificationCenter.default.removeObserver(playToEndObserver as Any)
    }
}
