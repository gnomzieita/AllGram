//
//  ChatMediaAttachment.swift
//  AllGram
//
//  Created by Alex Pirog on 08.07.2022.
//

import SwiftUI
import MatrixSDK

/// Provides observable object for `EventMediaAttachment` for `MXEvent`s with media
class ChatMediaAttachment: ObservableObject {
    @Published private(set) var isLoading: Bool = true {
        didSet { isReady = !isLoading && !isDecrypting }
    }
    @Published private(set) var isDecrypting: Bool = true {
        didSet { isReady = !isLoading && !isDecrypting }
    }
    @Published private(set) var isReady: Bool = false
    
    /// `Key`: matrix uri & `Value`: decrypted data
    @Published private(set) var mediaData: [String: NSData] = [:]
    
    /// `Key`: matrix uri & `Value`: error during download/decryption
    @Published private(set) var mediaErrors: [String: Error] = [:]
    
    /// Temporary local url for main data ready for share
    @Published private(set) var shareURL: URL?
    
    /// There `is` EventMediaAttachment for a passed MXEvent
    var isValid: Bool { attachment != nil }
    
    let event: MXEvent
    private let attachment: EventMediaAttachment?
    
    init(event: MXEvent) {
        self.event = event
        self.attachment = EventMediaAttachment(event: event)
        
        // Handle non-media attachment
        if let validAttachment = attachment {
            validAttachment.delegate = self
        } else {
            isLoading = false
            isDecrypting = false
        }
        
        // Get local storage url right away
        self.prepareShare { [weak self] url in
            self?.shareURL = url
        }
    }
    
    deinit {
        // Remove temporary file at share url
        if let url = shareURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    var isLocalEcho: Bool { attachment?.isLocalEcho ?? false }
    
    /// Returns text from `body` field if any, trimming white spaces and new lines
    var mediaName: String? {
        guard let text = event.content["body"] as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Returns media type (if possible) followed by hashed event id for unique string
    var uniqueMediaName: String? {
        // Do not expose event id like this, use hash
        let secretId = event.eventId!.md5()
        // Do not use full string (too long), just take last 7 characters
        let shortId = secretId.dropFirstUntil(7)
        switch event.messageType {
        case .image: return "Image_\(shortId)"
        case .video: return "Video_\(shortId)"
        case .audio: return "Audio_\(shortId)"
        case .file: return "File_\(shortId)"
        default: return "Media_\(shortId)"
        }
    }
    
    /// Returns main (first media uri from event) data when loaded/decrypted
    var mainData: Data? {
        mediaData[event.getMediaURLs().first ?? "nil"] as Data?
    }
    
    /// Returns data when loaded/decrypted. Only valid for voice messages
    var voiceData: Data? {
        guard event.isVoiceMessage() else { return nil }
        return mediaData[event.getMediaURLs().first ?? "nil"] as Data?
    }
    
    /// Returns data when loaded/decrypted. Only valid for image messages
    var imageData: Data? {
        guard event.messageType == .image else { return nil }
        return mediaData[event.getMediaURLs().first ?? "nil"] as Data?
    }
    
    /// Returns data when loaded/decrypted. Only valid for video messages
    var videoData: Data? {
        guard event.messageType == .video else { return nil }
        return mediaData[event.getMediaURLs().first ?? "nil"] as Data?
    }
    
    /// Returns data when loaded/decrypted. Only valid for video messages
    var thumbnailData: Data? {
        guard event.messageType == .video else { return nil }
        return mediaData[event.getMediaURLs().last ?? "nil"] as Data?
    }
    
    /// Puts decrypted main media data into temporary local storage if any,
    /// then passes resulting url or `nil` if failed.
    /// `Important:` don't forget to clear temporal storage after using!
    func prepareShare(completion: @escaping (URL?) -> Void) {
        // No need to prepare if already has a url
        if let url = shareURL {
            completion(url)
            return
        }
        guard let attachment = attachment else {
            completion(nil)
            return
        }
        if !isReady {
            // Delay while waiting for download/decoding
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
                self?.prepareShare(completion: completion)
            }
        } else {
            guard let data = mainData else {
                completion(nil)
                return
            }
            let fileName = uniqueMediaName ?? "Unknown"
            let fileExtension = MXTools.fileExtension(fromContentType: attachment.mimeType)!
            let destination = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(fileName + fileExtension)
            try? FileManager.default.removeItem(at: destination)
            if FileManager.default.createFile(atPath: destination.path, contents: data as Data, attributes: nil) {
                completion(destination)
            } else {
                completion(nil)
            }
        }
    }
}

extension ChatMediaAttachment: EventMediaAttachmentDelegate {
    func mediaLoaded(_ attachment: EventMediaAttachment, valid: Int, failed: Int, total: Int) {
        if valid + failed >= total {
            withAnimation { isLoading = false }
        }
    }
    func mediaDecrypted(_ attachment: EventMediaAttachment, valid: Int, failed: Int, total: Int) {
        if valid + failed >= total {
            withAnimation { isDecrypting = false }
        }
    }
    func gotNewRowData(_ attachment: EventMediaAttachment, uri: String, data: NSData) {
        mediaData[uri] = data
    }
    func failedToGetRowData(_ attachment: EventMediaAttachment, uri: String, error: Error) {
        mediaErrors[uri] = error
    }
    func decryptedNewData(_ attachment: EventMediaAttachment, uri: String, data: NSData) {
        mediaData[uri] = data
    }
    func failedToDecryptData(_ attachment: EventMediaAttachment, uri: String, error: Error) {
        mediaErrors[uri] = error
    }
}
