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
import UIKit

class VoiceMessageViewModel: NSObject, ObservableObject, VoiceMessageAudioRecorderProtocol {
    
    private enum Constants {
        static let maximumAudioRecordingDuration: TimeInterval = 120.0
        static let maximumAudioRecordingLengthReachedThreshold: TimeInterval = 10.0
        static let elapsedTimeFormat = "m:ss"
        static let fileNameFormat = "'Voice message - 'MM.dd.yyyy HH.mm.ss"
        static let minimumRecordingDuration = 1.0
    }
    
    private let mediaServiceProvider: VoiceMessageMediaServiceProvider
    private var temporaryFileURL: URL!
    
    private(set) var audioRecorder: VoiceMessageAudioRecorder?
    
    private var audioPlayer: VoiceMessageAudioPlayer?
    private var waveformAnalyser: WaveformAnalyzer?
    
    private var audioSamples: [Float] = []
    private var isInLockedMode: Bool = false
    private var notifiedRemainingTime = false
    
    private static let elapsedTimeFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Constants.elapsedTimeFormat
        return dateFormatter
    }()
    
    private static let fileNameDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Constants.fileNameFormat
        return dateFormatter
    }()
    
    var isRecordingAudio: Bool {
        return audioRecorder?.isRecording ?? false || isInLockedMode
    }
    
    private(set) var hasRecorded = false
    
    init(mediaServiceProvider: VoiceMessageMediaServiceProvider) {
        self.mediaServiceProvider = mediaServiceProvider
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
    }
    
    // MARK: - VoiceMessage public func's
    
    func voiceMessageDidRequestRecordingStart() {
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                if granted {
                    self?.voiceMessageDidRequestRecordingStart()
                }
            }
            return
        }
        
        // Haptic are not played during record on iOS by default. This fix works
        // only since iOS 13. A workaround for iOS 12 and earlier would be to
        // dispatch after at least 100ms recordWithOutputURL call
        if #available(iOS 13.0, *) {
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try? AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        audioRecorder = mediaServiceProvider.audioRecorder()
        
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileName = VoiceMessageViewModel.fileNameDateFormatter.string(from: Date())
        temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(fileName).appendingPathExtension("m4a")
        
        audioRecorder?.recordWithOutputURL(temporaryFileURL)
    }
    
    func voiceMessageDidRequestRecordingFinish() {
        finishRecording()
    }
    
    // Have to called on CancelButtonTap
    func voiceMessageDidRequestRecordingCancel() {
        isInLockedMode = false
        audioPlayer?.stop()
        audioRecorder?.stopRecording()
        deleteRecordingAtURL(temporaryFileURL)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    func voiceMessageDidRequestLockedModeRecording() {
        isInLockedMode = true
    }
    
    func voiceMessageDidRequestPlaybackToggle() {
        guard let audioPlayer = audioPlayer else {
            return
        }
        
        if audioPlayer.url != nil {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.play()
            }
        } else {
            audioPlayer.loadContentFromURL(temporaryFileURL)
            audioPlayer.play()
        }
    }
    
    // Have to called on SendButtonTap
    func voiceMessageDidRequestSend(completion: @escaping (URL, Int, [Float]?) -> Void) {
        audioPlayer?.stop()
        audioRecorder?.stopRecording()
        
        if let tmpUrl = temporaryFileURL {
            sendRecordingAtURL(tmpUrl) { url, duration, samples in
                completion(url, duration, samples)
            }
        }
        
        isInLockedMode = false
        hasRecorded = false
    }
    
    // MARK: - AudioRecorderDelegate
    
    func audioRecorderDidStartRecording(_ audioRecorder: VoiceMessageAudioRecorder) {
        notifiedRemainingTime = false
    }
    
    func audioRecorderDidFinishRecording(_ audioRecorder: VoiceMessageAudioRecorder) {
        hasRecorded = true
    }
    
    func audioRecorder(_ audioRecorder: VoiceMessageAudioRecorder, didFailWithError: Error) {
        isInLockedMode = false
        hasRecorded = false
        
    }
    
    // MARK: - AudioPlayerDelegate
    
    func audioPlayerDidStartPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        
    }
    
    func audioPlayerDidPausePlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        
    }
    
    func audioPlayerDidStopPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        
    }
    
    func audioPlayerDidFinishPlaying(_ audioPlayer: VoiceMessageAudioPlayer) {
        audioPlayer.seekToTime(0.0)
    }
    
    func audioPlayer(_ audioPlayer: VoiceMessageAudioPlayer, didFailWithError: Error) {
    }
    
    // MARK: - Private
    
    private func finishRecording() {
        // let recordDuration = audioRecorder?.currentTime
        audioRecorder?.stopRecording()
        hasRecorded = true

        
        audioPlayer = mediaServiceProvider.audioPlayerForIdentifier(UUID().uuidString)
        if let temporaryFileURL = temporaryFileURL {
            audioPlayer?.loadContentFromURL(temporaryFileURL)
        }
        
        audioSamples = []
    }
    
    private func sendRecordingAtURL(_ sourceURL: URL,
                                    completion: @escaping (URL, Int, [Float]?) -> Void = {_,_,_ in } ) {
        let dispatchGroup = DispatchGroup()
        var duration = 0.0
        var invertedSamples: [Float]?
        
        dispatchGroup.enter()
        VoiceMessageViewModel.mediaDuration(sourceURL) { result in
            switch result {
            case .success(let someDuration):
                duration = someDuration
            case .failure(_):
                break
            }
            
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let analyser = WaveformAnalyzer(audioAssetURL: sourceURL)
        analyser?.samples(count: 100, completionHandler: { samples in
            // Dispatch back from the WaveformAnalyzer's internal queue
            DispatchQueue.main.async {
                if let samples = samples {
                    invertedSamples = samples.compactMap { return 1.0 - $0 } // linearly normalized to [0, 1] (1 -> -50 dB)
                }
                dispatchGroup.leave()
            }
        })
        
        dispatchGroup.notify(queue: .main) {
            completion(sourceURL, Int(duration * 1000), invertedSamples)
            self.deleteRecordingAtURL(sourceURL)
        }
    }
    
    private func deleteRecordingAtURL(_ url: URL?) {
        guard let url = url else {
            return
        }
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
        }
    }
    
    @objc private func applicationWillResignActive() {
        finishRecording()
    }
    
    private static func mediaDuration(_ url: URL, completion: @escaping (Result<Double, Error>) -> Void ) {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            let duration = Double(audioPlayer.duration)
            completion(.success(duration))
        } catch {
            // assertionFailure("Failed crating audio player: \(error).")
            completion(.failure(error))
        }
    }
}
