//
//  VideoDownloader.swift
//  AllGram
//
//  Created by Alex Pirog on 28.03.2022.
//

import SwiftUI

class VideoDownloader: ObservableObject {
    
    /// Path to local documents
    static let localSubfolder: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    /// Provides path where downloaded video will be stored
    static func filePath(for url: URL) -> URL {
        let last = url.lastPathComponent
        let name = (last.isEmpty ? "no_name" : last) + ".mp4"
        return localSubfolder
//            .appendingPathComponent("Videos", isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }
    
    enum State {
        /// Downloader is ready
        case waiting
        /// Percentage of the download process ranging from 0 to 100
        case downloading(progress: Int)
        /// Downloaded to local URL
        case done(localURL: URL)
        /// Download process failed (`nil` when no data downloaded)
        case failed(error: Error?)
    }
    
    @Published private(set) var state: State = .waiting
    
    private var currentTask: URLSessionDataTask?
    private var progressObserver: NSKeyValueObservation?
    
    init() { }
    

    // MARK: - Download
    
    /// Downloads video to local storage (if not already downloaded)
    func downloadVideo(_ url: URL, completion: ((URL?) -> Void)? = nil) {
        stopDownload()
        let destination = VideoDownloader.filePath(for: url)
        guard !FileManager().fileExists(atPath: destination.path) else {
            state = .done(localURL: destination)
            completion?(destination)
            return
        }
        // Download off the main queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            self?.currentTask = URLSession.shared.dataTask(with: request) {
                [weak self] data, response, error in
                // Update on the main queue
                DispatchQueue.main.async { [weak self] in
                    self?.progressObserver?.invalidate()
                    self?.progressObserver = nil
                    self?.currentTask?.cancel()
                    self?.currentTask = nil
                    if let downloadError = error {
                        self?.state = .failed(error: downloadError)
                        completion?(nil)
                        return
                    }
                    guard let downloadedData = data else {
                        self?.state = .failed(error: nil)
                        completion?(nil)
                        return
                    }
                    do {
                        try downloadedData.write(to: destination, options: Data.WritingOptions.atomic)
                    } catch let writeError {
                        self?.state = .failed(error: writeError)
                        completion?(nil)
                        return
                    }
                    self?.state = .done(localURL: destination)
                    completion?(destination)
                }
            }
            self?.progressObserver = self?.currentTask?.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                // Update on the main queue
                DispatchQueue.main.async { [weak self] in
                    let progress = Int(progress.fractionCompleted * 100)
                    self?.state = .downloading(progress: progress)
                }
            }
            self?.currentTask!.resume()
        }
    }
    
    /// Stops ongoing download (if any)
    func stopDownload() {
        progressObserver?.invalidate()
        progressObserver = nil
        currentTask?.cancel()
        currentTask = nil
        state = .waiting
    }
    
}
