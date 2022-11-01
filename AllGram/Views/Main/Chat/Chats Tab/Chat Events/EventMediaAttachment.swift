//
//  EventMediaAttachment.swift
//  AllGram
//
//  Created by Alex Pirog on 08.07.2022.
//

import MatrixSDK

/// Wrapper for `MXMediaLoaderState` with copied state descriptions
enum MediaLoaderState: UInt {
    /**
     The loader has just been created.
     */
    case idle = 0
    /**
     The loader has been instantiated as a downloader, and the download is in progress.
     The download statistics are available in the property `statisticsDict`.
     */
    case downloadInProgress
    /**
     The loader has been instantiated as a downloader, and the download is completed.
     The downloaded data are available at the output file path: `downloadOutputFilePath`.
     */
    case downloadCompleted
    /**
     The loader has been instantiated as downloader, and the download failed.
     The error is available in the property `error`.
     */
    case downloadFailed
    /**
     The loader has been instantiated as a uploader, and the upload is in progress.
     The statistics are available in the property `statisticsDict`.
     */
    case uploadInProgress
    /**
     The loader has been instantiated as a uploader, and the upload is completed.
     */
    case uploadCompleted
    /**
     The loader has been instantiated as uploader, and the upload failed.
     The error is available in the property `error`.
     */
    case uploadFailed
    /**
     The current operation (downloading or uploading) has been cancelled.
     */
    case canceled
}

/// Handles loading of media from room message event
class EventMediaAttachment: NSObject {
    let event: MXEvent
    let mediaManager: MXMediaManager
    
    /// In NOT encrypted events, media is valid to use as is.
    /// `Key`: matrix uri & `Value`: row data
    private(set) var rowData: [String: NSData] = [:]
    
    /// In encrypted events, media is itself encrypted.
    /// `Key`: matrix uri & `Value`: decrypted data
    private(set) var decryptedData: [String: NSData] = [:]
    
    /// All problems that occurred during download/decryption.
    /// `Key`: matrix uri & `Value`: error
    private(set) var errors: [String: Error] = [:]
    
    // Track loading progress
    private(set) var mediaToLoad: Int = 0
    private(set) var loadedMedia: Int = 0 {
        didSet {
            delegate?.mediaLoaded(self, valid: loadedMedia, failed: failedLoading, total: mediaToLoad)
        }
    }
    private(set) var failedLoading: Int = 0 {
        didSet {
            delegate?.mediaLoaded(self, valid: loadedMedia, failed: failedLoading, total: mediaToLoad)
        }
    }
    
    // Track decryption progress for encrypted event
    // or getting loaded data for NOT encrypted event
    private(set) var mediaToDecrypt: Int = 0
    private(set) var decryptedMedia: Int = 0 {
        didSet {
            delegate?.mediaDecrypted(self, valid: decryptedMedia, failed: failedDecryption, total: mediaToDecrypt)
        }
    }
    private(set) var failedDecryption: Int = 0 {
        didSet {
            delegate?.mediaDecrypted(self, valid: decryptedMedia, failed: failedDecryption, total: mediaToDecrypt)
        }
    }
    
    /// Is `weak` to break memory cycle. Also updates delegate on `didSet`
    weak var delegate: EventMediaAttachmentDelegate? {
        didSet {
            delegate?.mediaLoaded(self, valid: loadedMedia, failed: failedLoading, total: mediaToLoad)
            delegate?.mediaDecrypted(self, valid: decryptedMedia, failed: failedDecryption, total: mediaToDecrypt)
            for (uri, data) in rowData {
                delegate?.gotNewRowData(self, uri: uri, data: data)
            }
            for (uri, data) in decryptedData {
                delegate?.decryptedNewData(self, uri: uri, data: data)
            }
            for (uri, error) in errors {
                if event.isEncrypted {
                    delegate?.failedToDecryptData(self, uri: uri, error: error)
                } else {
                    delegate?.failedToGetRowData(self, uri: uri, error: error)
                }
            }
        }
    }
    
    /// Mime type from the event (not actual media, but should always match)
    private(set) var mimeType: String!
    
    /// `True` when we upload media for local echo event
    private(set) var isLocalEcho = false
    
    /// Fails for non-media room message events or if something is missing
    init?(event: MXEvent, delegate: EventMediaAttachmentDelegate? = nil) {
        guard let manager = AuthViewModel.shared.session?.mediaManager, event.isMediaAttachment() else { return nil }
        self.event = event
        self.mediaManager = manager
        self.delegate = delegate
        super.init()
        
        let roomId = event.roomId
        guard let info = event.content["info"] as? [String: Any],
              let mimeType = info["mimetype"] as? String
        else { return nil }
        self.mimeType = mimeType
        
        if event.isEncrypted {
            // Data loaded from the URL is also encrypted
            // We need to decrypt it manually
            guard let encryptedContentFiles = event.getEncryptedContentFiles(), !encryptedContentFiles.isEmpty else {
                return nil
            }
            self.mediaToLoad = encryptedContentFiles.count
            self.mediaToDecrypt = self.mediaToLoad
            for encryptedFile in encryptedContentFiles {
                // Check if it local echo event (uploading media)
                guard !encryptedFile.url.starts(with: "upload") else {
                    self.isLocalEcho = true
                    if let loader = MXMediaManager.existingUploader(withId: encryptedFile.url) {
                        NotificationCenter.default.addObserver(self, selector: #selector(handleLoaderStateChange), name: .mxMediaLoaderStateDidChange, object: loader)
                    }
                    return
                }
                let cachePath = MXMediaManager.cachePath(forMatrixContentURI: encryptedFile.url, andType: mimeType, inFolder: roomId)
                let downloadId = MXMediaManager.downloadId(forMatrixContentURI: encryptedFile.url, inFolder: roomId)
                if let path = cachePath, FileManager.default.fileExists(atPath: path) {
                    // Already cached this file
                    self.loadedMedia += 1
                    decrypt(file: encryptedFile, at: path)
                } else {
                    // Check if already downloading
                    var loader = MXMediaManager.existingDownloader(withIdentifier: downloadId)
                    if loader == nil {
                        // Need to initiate download
                        loader = mediaManager.downloadEncryptedMedia(
                            fromMatrixContentFile: encryptedFile,
                            mimeType: mimeType,
                            inFolder: roomId
                        )
                    }
                    // Subscribe for download finish
                    NotificationCenter.default.addObserver(self, selector: #selector(handleLoaderStateChange), name: .mxMediaLoaderStateDidChange, object: loader!)
                }
            }
        } else {
            // Nothing to decrypt, just load media data
            guard let mediaURLs = event.getMediaURLs(), !mediaURLs.isEmpty else {
                return nil
            }
            self.mediaToLoad = mediaURLs.count
            self.mediaToDecrypt = self.mediaToLoad
            for uri in mediaURLs {
                // Check if it local echo event (uploading media)
                guard !uri.starts(with: "upload") else {
                    self.isLocalEcho = true
                    if let loader = MXMediaManager.existingUploader(withId: uri) {
                        NotificationCenter.default.addObserver(self, selector: #selector(handleLoaderStateChange), name: .mxMediaLoaderStateDidChange, object: loader)
                    }
                    return
                }
                let cachePath = MXMediaManager.cachePath(forMatrixContentURI: uri, andType: mimeType, inFolder: roomId)
                let downloadId = MXMediaManager.downloadId(forMatrixContentURI: uri, inFolder: roomId)
                if let path = cachePath, FileManager.default.fileExists(atPath: path) {
                    // Already cached this file
                    self.loadedMedia += 1
                    getData(from: uri, at: path)
                } else {
                    // Check if already downloading
                    var loader = MXMediaManager.existingDownloader(withIdentifier: downloadId)
                    if loader == nil {
                        // Need to initiate download
                        loader = mediaManager.downloadMedia(
                            fromMatrixContentURI: uri,
                            withType: mimeType,
                            inFolder: roomId
                        )
                    }
                    // Subscribe for download finish
                    NotificationCenter.default.addObserver(self, selector: #selector(handleLoaderStateChange), name: .mxMediaLoaderStateDidChange, object: loader!)
                }
            }
        }
    }
    
    deinit {
        delegate = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    private func decrypt(file: MXEncryptedContentFile, at path: String) {
        let uri = file.url!
        if decryptedData[uri] != nil {
            let error = EventMediaAttachmentError.noDecryptedURL
            errors[uri] = error
            delegate?.failedToDecryptData(self, uri: uri, error: error)
            failedDecryption += 1
            return
        }
        let input = InputStream(fileAtPath: path)!
        let output = OutputStream(toMemory: ())
        MXEncryptedAttachments.decryptAttachment(
            file,
            inputStream: input,
            outputStream: output,
            success: { [weak self] in
                if let data = output.property(forKey: .dataWrittenToMemoryStreamKey) as? NSData {
                    self?.decryptedData[uri] = data
                    self?.delegate?.decryptedNewData(self!, uri: uri, data: data)
                    self?.decryptedMedia += 1
                } else {
                    let error = EventMediaAttachmentError.noDecryptedData
                    self?.errors[uri] = error
                    self?.delegate?.failedToDecryptData(self!, uri: uri, error: error)
                    self?.failedDecryption += 1
                }
            },
            failure: { [weak self] error in
                self?.errors[uri] = error!
                self?.delegate?.failedToDecryptData(self!, uri: uri, error: error!)
                self?.failedDecryption += 1
            }
        )
    }
    
    private func getData(from uri: String, at path: String) {
        if rowData[uri] != nil {
            let error = EventMediaAttachmentError.noRowURL
            errors[uri] = error
            delegate?.failedToGetRowData(self, uri: uri, error: error)
            failedDecryption += 1
            return
        }
        if let data = NSData(contentsOfFile: path) {
            rowData[uri] = data
            delegate?.gotNewRowData(self, uri: uri, data: data)
            decryptedMedia += 1
        } else {
            let error = EventMediaAttachmentError.noRowData
            errors[uri] = error
            delegate?.failedToGetRowData(self, uri: uri, error: error)
            failedDecryption += 1
        }
    }
    
    @objc private func handleLoaderStateChange(_ notification: Notification) {
        guard let loader = notification.object as? MXMediaLoader else { return }
        guard let state = MediaLoaderState(rawValue: loader.state.rawValue) else { return }
        // Handles upload cases for local echo events
        switch state {
        case .downloadInProgress:
            // Still downloading
            break
            
        case .downloadCompleted:
            // Finished downloading
            if let path = loader.downloadOutputFilePath,
               let loadedURL = loader.downloadMediaURL
            {
                if event.isEncrypted {
                    let urlName = loadedURL.split(separator: "/").last!
                    if let file = event.getEncryptedContentFiles().first(where: {
                        $0.url.split(separator: "/").last == urlName
                    }) {
                        self.loadedMedia += 1
                        decrypt(file: file, at: path)
                    }
                } else {
                    if let uri = event.getMediaURLs().first(where: {
                        $0 == loadedURL
                    }) {
                        self.loadedMedia += 1
                        getData(from: uri, at: path)
                    }
                }
            }
            
        case .downloadFailed:
            self.failedLoading += 1
            break
            
        case .uploadInProgress:
            // Still uploading
            break
            
        case .uploadCompleted:
            // Finished uploading
            break
            
        case .uploadFailed:
            break
            
        case .canceled:
            // Cancelled
            break
            
        case .idle:
            // Why we would get it?
            break
        }
    }
}

/// Special cases for `EventMediaAttachment` when failed with no error
enum EventMediaAttachmentError: Error, LocalizedError {
    case noDecryptedURL
    case noDecryptedData
    case noRowURL
    case noRowData
}

/// Responds to `EventMediaAttachment` download/decryption progress
protocol EventMediaAttachmentDelegate: AnyObject {
    // Track progress
    func mediaLoaded(_ attachment: EventMediaAttachment, valid: Int, failed: Int, total: Int)
    func mediaDecrypted(_ attachment: EventMediaAttachment, valid: Int, failed: Int, total: Int)
    // NOT encrypted data
    func gotNewRowData(_ attachment: EventMediaAttachment, uri: String, data: NSData)
    func failedToGetRowData(_ attachment: EventMediaAttachment, uri: String, error: Error)
    // Encrypted data
    func decryptedNewData(_ attachment: EventMediaAttachment, uri: String, data: NSData)
    func failedToDecryptData(_ attachment: EventMediaAttachment, uri: String, error: Error)
}
