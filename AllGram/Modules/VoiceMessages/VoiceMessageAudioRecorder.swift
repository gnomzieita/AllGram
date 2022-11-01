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

protocol VoiceMessageAudioRecorderProtocol: AnyObject {
    func audioRecorderDidStartRecording(_ audioRecorder: VoiceMessageAudioRecorder)
    func audioRecorderDidFinishRecording(_ audioRecorder: VoiceMessageAudioRecorder)
    func audioRecorder(_ audioRecorder: VoiceMessageAudioRecorder, didFailWithError: Error)
}

enum VoiceMessageAudioRecorderError: Error {
    case genericError
}

class VoiceMessageAudioRecorder: NSObject, AVAudioRecorderDelegate {
    
    private enum Constants {
        static let silenceThreshold: Float = -50.0
    }
    
    var audioRecorder: AVAudioRecorder?
    
    var url: URL? {
        return audioRecorder?.url
    }
    
    var currentTime: TimeInterval {
        return audioRecorder?.currentTime ?? 0
    }
    
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }

    func recordWithOutputURL(_ url: URL) {
        
        let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 48000,
                        AVEncoderBitRateKey: 128000,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            if granted {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    self?.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                    self?.audioRecorder?.delegate = self
                    self?.audioRecorder?.isMeteringEnabled = true
                    self?.audioRecorder?.record()
                } catch {
                    
                }
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
    }
    
    func peakPowerForChannelNumber(_ channelNumber: Int) -> Float {
        guard self.isRecording, let audioRecorder = audioRecorder else {
            return 0.0
        }
        
        audioRecorder.updateMeters()

        return self.normalizedPowerLevelFromDecibels(audioRecorder.peakPower(forChannel: channelNumber))
    }
    
    func averagePowerForChannelNumber(_ channelNumber: Int) -> Float {
        guard self.isRecording, let audioRecorder = audioRecorder else {
            return 0.0
        }
        
        audioRecorder.updateMeters()
        
        return self.normalizedPowerLevelFromDecibels(audioRecorder.averagePower(forChannel: channelNumber))
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully success: Bool) {

    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    }
    
    private func normalizedPowerLevelFromDecibels(_ decibels: Float) -> Float {
        return decibels / Constants.silenceThreshold
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

extension VoiceMessageAudioRecorderProtocol {
    func audioRecorderDidStartRecording(_ audioRecorder: VoiceMessageAudioRecorder) { }

    func audioRecorderDidFinishRecording(_ audioRecorder: VoiceMessageAudioRecorder) { }
    
    func audioRecorder(_ audioRecorder: VoiceMessageAudioRecorder, didFailWithError: Error) { }
}
