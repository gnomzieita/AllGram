//
//  SoundPlayer.swift
//  AllGram
//
//  Created by Wladislaw Derevianko on 08.11.2021.
//

import Foundation
import AVFoundation

class SoundPlayer : NSObject {
    
	static let shared = SoundPlayer()
	var shouldRepeat = false
    
    private var audioPlayer : AVAudioPlayer?
    var isVibrating = false
	
	func play(name: String, repeat doRepeat: Bool, vibrate: Bool, builtInReceiver: Bool) {
		if nil != audioPlayer {
			stop(deactivatingAudioSession: false)
		}
		guard let url = soundFileURL(name: name),
			  let player = try? AVAudioPlayer(contentsOf: url)
		else {
			return
		}
		shouldRepeat = doRepeat
        let numberOfLoops:Int = (doRepeat ? 10 : 0)
		player.numberOfLoops = numberOfLoops
        
		player.delegate = self
		self.audioPlayer = player
		player.prepareToPlay()
		
		// Setup AVAudioSession
		// We use SoloAmbient instead of Playback category to respect silent mode
		try? AVAudioSession.sharedInstance().setCategory(builtInReceiver ? .playAndRecord : .soloAmbient)
		
		player.play()
				
		if vibrate {
			startVibrating(withRepeat: doRepeat, isFirstTime: true)
		}
	}
    
	func stop(deactivatingAudioSession: Bool) {
		if nil != audioPlayer {
			audioPlayer?.delegate = nil
			audioPlayer?.stop()
			audioPlayer = nil
			if deactivatingAudioSession {
				try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
			}
		}
		if isVibrating {
			stopVibrating()
		}
	}
    
    /// Returns `true` if success or `false` if error occurred
    func forceOutput(toSpeaker: Bool) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(toSpeaker ? .speaker : .none)
            forcedSpeaker = toSpeaker
            return true
        } catch _ {
            return false
        }
    }
    
    private(set) var forcedSpeaker = false
    
    /// Number of options for sound output
    var outputOptions: Int {
        AVAudioSession.sharedInstance().currentRoute.outputs.count
    }
    
}

private extension SoundPlayer {
	func soundFileURL(name: String) -> URL? {
		return Bundle.main.url(forResource: name, withExtension: "mp3")
	}
	
	func startVibrating(withRepeat doRepeat: Bool, isFirstTime: Bool) {
		if isFirstTime {
			isVibrating = true
		} else {
			guard isVibrating && shouldRepeat else {
				stopVibrating(); return
			}
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500)) {
			AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
			
			AudioServicesAddSystemSoundCompletion(kSystemSoundID_Vibrate,
												  nil,
												  nil,
												  vibrationCompleted,
												  nil)
		}
	}
	
	func stopVibrating() {
		isVibrating = false
		AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate)
	}
}

fileprivate func vibrationCompleted(_ soundID: SystemSoundID, _ pointer: UnsafeMutableRawPointer?) {
	SoundPlayer.shared.startVibrating(withRepeat: true, isFirstTime: false)
}

extension SoundPlayer : AVAudioPlayerDelegate {
	func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		self.audioPlayer = nil;
		
		// Release the audio session to allow resuming of background music app
		try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
	}
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print(error)
    }
}

