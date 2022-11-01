//
//  RingtoneSoundPlayer.swift
//  AllGram
//
//  Created by Alex Agarkov on 19.09.2022.
//

import UIKit
import AVFoundation

class RingtoneSoundPlayer {
    
    static let shared = RingtoneSoundPlayer()
    var audioPlayer:AVAudioPlayer?
    
    func startBackgroundMusic() {
        if let bundle = Bundle.main.path(forResource: "ringback", ofType: "mp3") {
            let backgroundMusic = NSURL(fileURLWithPath: bundle)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: backgroundMusic as URL)
                guard let audioPlayer = audioPlayer else {return}
                audioPlayer.numberOfLoops = -1
//                audioPlayer.prepareToPlay()
//                audioPlayer.play()
            } catch {
                print(error)
            }}
        
        do{
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            guard let player = audioPlayer else{
                return
            }
            
            player.play()
        }
        catch {
            print ("oops")
        }
    }
}
