//
//  ChatVoicePlayer.swift
//  AllGram
//
//  Created by Alex Pirog on 08.07.2022.
//

import AVFoundation

class ChatVoicePlayer: NSObject, ObservableObject {
    private let player: AVPlayer
    
    @Published private(set) var title: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime = CMTime.zero
    
    var roundedTime: TimeInterval {
        currentTime.roundedSeconds
    }
    
    private(set) var currentURL: URL?
    private(set) var currentDuration: CMTime?
    
    static let shared = ChatVoicePlayer()
    
    private override init() {
        self.player = AVPlayer()
        super.init()
        addPeriodicTimeObserver()
    }
    
    deinit {
        player.replaceCurrentItem(with: nil)
        removePeriodicTimeObserver()
        removeBoundaryTimeObserver()
    }
    
    // MARK: - Handle Updates
    
    private let periodicTimeStep = 0.15
    private var periodicTimeObserverToken: Any?
    
    private func addPeriodicTimeObserver() {
        removePeriodicTimeObserver()
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let updateTime = CMTime(seconds: periodicTimeStep, preferredTimescale: timeScale)
        periodicTimeObserverToken = player.addPeriodicTimeObserver(forInterval: updateTime, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time
        }
    }

    private func removePeriodicTimeObserver() {
        if let token = periodicTimeObserverToken {
            player.removeTimeObserver(token)
            periodicTimeObserverToken = nil
        }
    }
    
    private let boundaryTimeSafeguard = 0.123
    private var boundaryTimeObserverToken: Any?
    
    private func addBoundaryTimeObserver(for time: CMTime) {
        removeBoundaryTimeObserver()
        let durationValue = NSValue(time: time)
        boundaryTimeObserverToken = player.addBoundaryTimeObserver(forTimes: [durationValue], queue: .main) { [weak self] in
            self?.stop()
        }
    }
    
    private func removeBoundaryTimeObserver() {
        if let token = boundaryTimeObserverToken {
            player.removeTimeObserver(token)
            boundaryTimeObserverToken = nil
        }
    }
    
    // Key-value observing context
    private var playerItemContext = 0
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            // Switch over status value
            switch status {
            case .readyToPlay:
                // Ready to play - set played to the end timed observer
                let itemDuration = player.currentItem!.duration
                let timeScale = CMTimeScale(NSEC_PER_SEC)
                currentDuration = CMTime(seconds: itemDuration.seconds - boundaryTimeSafeguard, preferredTimescale: timeScale)
                addBoundaryTimeObserver(for: currentDuration!)
            case .failed:
                // Failed to play - clear player from this item
                clear()
//                if let error = player.currentItem?.error {
//                    print("[V] failed to play with error: \(error)")
//                } else {
//                    print("[V] failed to play with error: nil")
//                }
            default:
                break
            }
        }
    }
    
    // MARK: - Controls
    
    /// Stops and clears current item if any
    func clear() {
        player.replaceCurrentItem(with: nil)
        title = nil
        isPlaying = false
        currentTime = .zero
        currentURL = nil
    }
    
    /// Stops (pauses and seeks to beginning) current playing item if any
    func stop() {
        player.pause()
        player.seek(to: CMTime.zero)
        currentTime = .zero
        isPlaying = false
    }
    
    /// Pauses current playing item if any
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    /// Resumes current playing item if any
    func resume() {
        guard currentURL != nil else { return }
        player.play()
        isPlaying = true
    }
    
    /// Plays provided audio data if possible (storing it in temporary folder)
    func play(_ audioData: Data, named name: String, title: String) {
        if let url = prepareData(audioData, named: name) {
            play(url, title: title)
        }
    }
    
    /// Expects `data` to contain any audio data and be `named` with corresponding extension.
    /// Puts provided data into temporary local storage and returns resulting URL if possible.
    /// `Important:` don't forget to clear temporal storage after using!
    private func prepareData(_ data: Data, named name: String) -> URL? {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destination)
        if FileManager.default.createFile(atPath: destination.path, contents: data, attributes: nil) {
            return destination
        } else {
            return nil
        }
    }
    
    /// Plays audio from provided URL if possible
    private func play(_ url: URL, title: String) {
        guard url.contains(.audio) else {
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        } catch _ { }
        if currentURL == url {
            player.play()
            isPlaying = true
            self.title = title
        } else {
            let item = AVPlayerItem(url: url)
            // Register as an observer of the player item's status property
            // This is how to get item duration when it is ready
            item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
            player.replaceCurrentItem(with: item)
            player.play()
            currentURL = url
            isPlaying = true
            self.title = title
        }
    }
    
    func seek(to time: CMTime) {
        player.seek(to: time)
    }
}
