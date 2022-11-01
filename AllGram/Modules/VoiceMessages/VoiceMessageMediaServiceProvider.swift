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
import MediaPlayer
import MatrixSDK

class VoiceMessageMediaServiceProvider: NSObject, VoiceMessageAudioRecorderProtocol {
    
    private enum Constants {
        static let roomAvatarImageSize: CGSize = CGSize(width: 600, height: 600)
        static let roomAvatarFontSize: CGFloat = 40.0
        static let roomAvatarMimetype: String = "image/jpeg"
    }
    
    private var roomAvatarLoader: MXMediaLoader?
    private var audioPlayers: [String: VoiceMessageAudioPlayer]
    private var audioRecorders: Set<VoiceMessageAudioRecorder>
    
    // Retain currently playing audio player so it doesn't stop playing on timeline cell reuse
    private var currentlyPlayingAudioPlayer: VoiceMessageAudioPlayer?
    
    public static let sharedProvider = VoiceMessageMediaServiceProvider()
    
    private var roomAvatar: UIImage?
    public var currentRoomSummary: MXRoomSummary? {
        didSet {
            //  set avatar placeholder for now
            roomAvatar = AvatarGenerator.generateAvatar(forMatrixItem: currentRoomSummary?.roomId,
                                                        withDisplayName: currentRoomSummary?.displayname,
                                                        size: Constants.roomAvatarImageSize.width,
                                                        andFontSize: Constants.roomAvatarFontSize)
            
            guard let avatarUrl = currentRoomSummary?.avatar else {
                return
            }
            
            if let cachePath = MXMediaManager.thumbnailCachePath(forMatrixContentURI: avatarUrl,
                                                                 andType: Constants.roomAvatarMimetype,
                                                                 inFolder: currentRoomSummary?.roomId,
                                                                 toFitViewSize: Constants.roomAvatarImageSize,
                                                                 with: MXThumbnailingMethodCrop),
               FileManager.default.fileExists(atPath: cachePath) {
                //  found in the cache, load it
                roomAvatar = MXMediaManager.loadThroughCache(withFilePath: cachePath)
            } else {
                //  cancel previous loader first
                roomAvatarLoader?.cancel()
                roomAvatarLoader = nil
                
                guard let mediaManager = currentRoomSummary?.mxSession.mediaManager else {
                    return
                }
                
                //  not found in the cache, download it
                roomAvatarLoader = mediaManager.downloadThumbnail(fromMatrixContentURI: avatarUrl,
                                                                  withType: Constants.roomAvatarMimetype,
                                                                  inFolder: currentRoomSummary?.roomId,
                                                                  toFitViewSize: Constants.roomAvatarImageSize,
                                                                  with: MXThumbnailingMethodCrop,
                                                                  success: { filePath in
                                                                    if let filePath = filePath {
                                                                        self.roomAvatar = MXMediaManager.loadThroughCache(withFilePath: filePath)
                                                                    }
                                                                    self.roomAvatarLoader = nil
                                                                  }, failure: { error in
                                                                    self.roomAvatarLoader = nil
                                                                  })
            }
        }
    }
    
    private override init() {
        audioPlayers = [:]
        audioRecorders = Set<VoiceMessageAudioRecorder>()
        
        super.init()
        
    }
    
    func audioPlayerForIdentifier(_ identifier: String) -> VoiceMessageAudioPlayer {
        if let audioPlayer = audioPlayers[identifier] {
            return audioPlayer
        }
        
        let audioPlayer = VoiceMessageAudioPlayer()
        audioPlayers[identifier] = audioPlayer
        return audioPlayer
    }
    
    func audioRecorder() -> VoiceMessageAudioRecorder {
        let audioRecorder = VoiceMessageAudioRecorder()
        audioRecorders.insert(audioRecorder)
        return audioRecorder
    }
    
    func stopAllServices() {
        stopAllServicesExcept(nil)
    }
    
    // MARK: - VoiceMessageAudioPlayerDelegate
    
    func audioPlayerDidStartPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        currentlyPlayingAudioPlayer = audioPlayer
        setUpRemoteCommandCenter()
        stopAllServicesExcept(audioPlayer)
    }
    
    func audioPlayerDidStopPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        if currentlyPlayingAudioPlayer == audioPlayer {
            currentlyPlayingAudioPlayer = nil
            tearDownRemoteCommandCenter()
        }
    }
    
    func audioPlayerDidFinishPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        if currentlyPlayingAudioPlayer == audioPlayer {
            currentlyPlayingAudioPlayer = nil
            tearDownRemoteCommandCenter()
        }
    }
    
    // MARK: - VoiceMessageAudioRecorderDelegate
    
    func audioRecorderDidStartRecording(_ audioRecorder: VoiceMessageAudioRecorder) {
        stopAllServicesExcept(audioRecorder)
    }
    
    // MARK: - Private
    
    private func stopAllServicesExcept(_ service: AnyObject?) {
        for audioRecorder in audioRecorders {
            if audioRecorder === service {
                continue
            }
            
            audioRecorder.stopRecording()
        }
        
        for (_, player) in audioPlayers {
            if player === service {
                continue
            }
            
            player.stop()
            player.unloadContent()
        }
    }
    
    private func setUpRemoteCommandCenter() {
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let audioPlayer = self?.currentlyPlayingAudioPlayer else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            audioPlayer.play()
            
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let audioPlayer = self?.currentlyPlayingAudioPlayer else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            audioPlayer.pause()

            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let audioPlayer = self?.currentlyPlayingAudioPlayer, let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            audioPlayer.seekToTime(audioPlayer.currentTime + skipEvent.interval)
            
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let audioPlayer = self?.currentlyPlayingAudioPlayer, let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            audioPlayer.seekToTime(audioPlayer.currentTime - skipEvent.interval)
            
            return MPRemoteCommandHandlerStatus.success
        }
    }
    
    private func tearDownRemoteCommandCenter() {
        
        UIApplication.shared.endReceivingRemoteControlEvents()
        
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        nowPlayingInfoCenter.nowPlayingInfo = nil
    }
    
    private func updateNowPlayingInfoCenter() {
        guard let audioPlayer = currentlyPlayingAudioPlayer else {
            return
        }
        
        let artwork = MPMediaItemArtwork(boundsSize: Constants.roomAvatarImageSize) { [weak self] size in
            return self?.roomAvatar ?? UIImage()
        }
        
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        nowPlayingInfoCenter.nowPlayingInfo = [MPMediaItemPropertyTitle: audioPlayer.displayName ?? "VectorL10n.voiceMessageLockScreenPlaceholder",
                                               MPMediaItemPropertyArtist: currentRoomSummary?.displayname as Any,
                                               MPMediaItemPropertyArtwork: artwork,
                                               MPMediaItemPropertyPlaybackDuration: audioPlayer.duration as Any,
                                               MPNowPlayingInfoPropertyElapsedPlaybackTime: audioPlayer.currentTime as Any]
    }
}
