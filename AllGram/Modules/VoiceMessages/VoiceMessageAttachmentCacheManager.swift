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
import DSWaveformImage
import AVFAudio

enum VoiceMessageAttachmentCacheManagerError: Error {
    case invalidEventId
    case invalidAttachmentType
    case decryptionError(Error)
    case preparationError(Error)
    case conversionError(Error)
    case durationError(Error?)
    case invalidNumberOfSamples
    case samplingError
    case cancelled
}

/**
 Swift optimizes the callbacks to be the same instance. Wrap them so we can store them in an array.
 */
private class CompletionWrapper {
    let completion: (Result<VoiceMessageAttachmentCacheManagerLoadResult, Error>) -> Void
    
    init(_ completion: @escaping (Result<VoiceMessageAttachmentCacheManagerLoadResult, Error>) -> Void) {
        self.completion = completion
    }
}

private struct CompletionCallbackKey: Hashable {
    let eventIdentifier: String
    let requiredNumberOfSamples: Int
}

struct VoiceMessageAttachmentCacheManagerLoadResult {
    let eventIdentifier: String
    let url: URL
    let duration: TimeInterval
    let samples: [Float]
}

@objc class VoiceMessageAttachmentCacheManagerBridge: NSObject {
    @objc static func clearCache() {
        VoiceMessageAttachmentCacheManager.sharedManager.clearCache()
    }
}

class VoiceMessageAttachmentCacheManager {
    
    private struct Constants {
        static let taskSemaphoreTimeout = 5.0
    }
    
    static let sharedManager = VoiceMessageAttachmentCacheManager()
    
    private var completionCallbacks = [CompletionCallbackKey: [CompletionWrapper]]()
    private var samples = [String: [Int: [Float]]]()
    private var durations = [String: TimeInterval]()
    private var finalURLs = [String: URL]()
    
    private let workQueue: DispatchQueue
    private let operationQueue: OperationQueue
    
    private var temporaryFilesFolderURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("VoiceMessages")
    }
    
    private init() {
        workQueue = DispatchQueue(label: "io.element.VoiceMessageAttachmentCacheManager.queue", qos: .userInitiated)
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    func loadAttachment(_ attachment: Attachment, numberOfSamples: Int, completion: @escaping (Result<VoiceMessageAttachmentCacheManagerLoadResult, Error>) -> Void) {
        guard attachment.type == .voiceMessage else {
            completion(Result.failure(VoiceMessageAttachmentCacheManagerError.invalidAttachmentType))
            return
        }
        
        guard let identifier = attachment.eventId else {
            completion(Result.failure(VoiceMessageAttachmentCacheManagerError.invalidEventId))
            return
        }
        
        guard numberOfSamples > 0 else {
            completion(Result.failure(VoiceMessageAttachmentCacheManagerError.invalidNumberOfSamples))
            return
        }
        
        do {
            try setupTemporaryFilesFolder()
        } catch {
            completion(Result.failure(VoiceMessageAttachmentCacheManagerError.preparationError(error)))
            return
        }
        
        operationQueue.addOperation {
            if let finalURL = self.finalURLs[identifier], let duration = self.durations[identifier], let samples = self.samples[identifier]?[numberOfSamples] {
                let result = VoiceMessageAttachmentCacheManagerLoadResult(eventIdentifier: identifier, url: finalURL, duration: duration, samples: samples)
                DispatchQueue.main.async {
                    completion(Result.success(result))
                }
                return
            }
            
            self.enqueueLoadAttachment(attachment, identifier: identifier, numberOfSamples: numberOfSamples, completion: completion)
        }
    }
    
    func clearCache() {
        for key in completionCallbacks.keys {
            invokeFailureCallbacksForIdentifier(key.eventIdentifier, requiredNumberOfSamples: key.requiredNumberOfSamples, error: VoiceMessageAttachmentCacheManagerError.cancelled)
        }
        
        operationQueue.cancelAllOperations()
        samples.removeAll()
        durations.removeAll()
        finalURLs.removeAll()
        
        do {
            try FileManager.default.removeItem(at: temporaryFilesFolderURL)
        } catch {
        }
    }
    
    private func enqueueLoadAttachment(_ attachment: Attachment, identifier: String, numberOfSamples: Int, completion: @escaping (Result<VoiceMessageAttachmentCacheManagerLoadResult, Error>) -> Void) {
        let callbackKey = CompletionCallbackKey(eventIdentifier: identifier, requiredNumberOfSamples: numberOfSamples)
        
        if var callbacks = completionCallbacks[callbackKey] {
            callbacks.append(CompletionWrapper(completion))
            completionCallbacks[callbackKey] = callbacks
            return
        } else {
            completionCallbacks[callbackKey] = [CompletionWrapper(completion)]
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        if let finalURL = finalURLs[identifier], let duration = durations[identifier] {
            sampleFileAtURL(finalURL, duration: duration, numberOfSamples: numberOfSamples, identifier: identifier, semaphore: semaphore)
            let result = semaphore.wait(timeout: .now() + Constants.taskSemaphoreTimeout)
            if case DispatchTimeoutResult.timedOut = result {
            }
            return
        }
        
        DispatchQueue.main.async { // These don't behave accordingly if called from a background thread
            if attachment.isEncrypted {
                attachment.decrypt(toTempFile: { filePath in
                    self.workQueue.async {
                        self.handleFileAtPath(filePath, numberOfSamples: numberOfSamples, identifier: identifier, semaphore: semaphore)
                    }
                }, failure: { error in
                    // A nil error in this case is a cancellation on the MXMediaLoader
                    if let error = error {
                        self.invokeFailureCallbacksForIdentifier(identifier, requiredNumberOfSamples: numberOfSamples, error: VoiceMessageAttachmentCacheManagerError.decryptionError(error))
                    }
                    semaphore.signal()
                })
            } else {
                attachment.prepare({
                    self.workQueue.async {
                        self.handleFileAtPath(attachment.cacheFilePath, numberOfSamples: numberOfSamples, identifier: identifier, semaphore: semaphore)
                    }
                }, failure: { error in
                    // A nil error in this case is a cancellation on the MXMediaLoader
                    if let error = error {
                        self.invokeFailureCallbacksForIdentifier(identifier, requiredNumberOfSamples: numberOfSamples, error: VoiceMessageAttachmentCacheManagerError.preparationError(error))
                    }
                    semaphore.signal()
                })
            }
        }
        
        let result = semaphore.wait(timeout: .now() + Constants.taskSemaphoreTimeout)
        if case DispatchTimeoutResult.timedOut = result {
        }
    }
    
    private func handleFileAtPath(_ path: String?, numberOfSamples: Int, identifier: String, semaphore: DispatchSemaphore) {
        let path = URL(fileURLWithPath: path ?? "")

        self.workQueue.async {
            self.finalURLs[identifier] = path//newURL
            
            do {
                let data = try Data(contentsOf: path)
                let audioPlayer = try AVAudioPlayer(data: data)
                let duration = audioPlayer.duration
                self.durations[identifier] = duration
                self.sampleFileAtURL(path/*newURL*/, duration: duration, numberOfSamples: numberOfSamples, identifier: identifier, semaphore: semaphore)
            } catch let error {
                self.invokeFailureCallbacksForIdentifier(identifier, requiredNumberOfSamples: numberOfSamples, error: VoiceMessageAttachmentCacheManagerError.durationError(error))
                semaphore.signal()
            }
        }
    }
    
    private func sampleFileAtURL(_ url: URL, duration: TimeInterval, numberOfSamples: Int, identifier: String, semaphore: DispatchSemaphore) {
        let analyser = WaveformAnalyzer(audioAssetURL: url)
        
        analyser?.samples(count: numberOfSamples, completionHandler: { samples in
            self.workQueue.async {
                guard let samples = samples else {
                    self.invokeFailureCallbacksForIdentifier(identifier, requiredNumberOfSamples: numberOfSamples, error: VoiceMessageAttachmentCacheManagerError.samplingError)
                    semaphore.signal()
                    return
                }

                if var existingSamples = self.samples[identifier] {
                    existingSamples[numberOfSamples] = samples
                    self.samples[identifier] = existingSamples
                } else {
                    self.samples[identifier] = [numberOfSamples: samples]
                }

                self.invokeSuccessCallbacksForIdentifier(identifier, url: url, duration: duration, samples: samples)
                semaphore.signal()
            }
        })
    }
    
    private func invokeSuccessCallbacksForIdentifier(_ identifier: String, url: URL, duration: TimeInterval, samples: [Float]) {
        let callbackKey = CompletionCallbackKey(eventIdentifier: identifier, requiredNumberOfSamples: samples.count)
        
        guard let callbacks = completionCallbacks[callbackKey] else {
            return
        }
        
        let result = VoiceMessageAttachmentCacheManagerLoadResult(eventIdentifier: identifier, url: url, duration: duration, samples: samples)
        
        let copy = callbacks.map { $0 }
        DispatchQueue.main.async {
            for wrapper in copy {
                wrapper.completion(Result.success(result))
            }
        }
        
        self.completionCallbacks[callbackKey] = nil
        }
    
    private func invokeFailureCallbacksForIdentifier(_ identifier: String, requiredNumberOfSamples: Int, error: Error) {
        let callbackKey = CompletionCallbackKey(eventIdentifier: identifier, requiredNumberOfSamples: requiredNumberOfSamples)
        
        guard let callbacks = completionCallbacks[callbackKey] else {
            return
        }
        
        let copy = callbacks.map { $0 }
        DispatchQueue.main.async {
            for wrapper in copy {
                wrapper.completion(Result.failure(error))
            }
        }
        
        self.completionCallbacks[callbackKey] = nil
        
    }
    
    private func setupTemporaryFilesFolder() throws {
        let url = temporaryFilesFolderURL
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
}
