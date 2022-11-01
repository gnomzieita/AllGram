import SwiftUI
import MatrixSDK
import Kingfisher
import DSWaveformImage

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

class MediaAttachment: NSObject, ObservableObject {
    let event: MXEvent
    let mediaManager: MXMediaManager
    
    /// Ready to use real world URLs for event
    @Published private(set) var mediaURLs: [URL] = []
    
    /// In  encrypted events, media is itself encrypted. This is decrypted data
    @Published private(set) var decryptedData: [NSData] = []
    
    init?(event: MXEvent, mediaManager: MXMediaManager) {
        guard event.isMediaAttachment() else { return nil }
        self.event = event
        self.mediaManager = mediaManager
        super.init()
        
        let roomId = event.roomId
        guard let info = event.content["info"] as? [String: Any],
              let mimeType = info["mimetype"] as? String
        else { return nil }
        
        if event.isEncrypted {
            // We handle encrypted media differently
            // as data from URL is also encrypted
            for encryptedFile in event.getEncryptedContentFiles() {
                let cachePath = MXMediaManager.cachePath(forMatrixContentURI: encryptedFile.url, andType: mimeType, inFolder: roomId)
                let downloadId = MXMediaManager.downloadId(forMatrixContentURI: encryptedFile.url, inFolder: roomId)
                if let path = cachePath, FileManager.default.fileExists(atPath: path) {
                    // Already cached this file
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
            // Not encrypted, should be good data from URL
            for uri in event.getMediaURLs() {
                if let mxURL = MXURL(mxContentURI: uri), let contentURL = mxURL.contentURL(on: API.server.getURL()!) {
                    mediaURLs.append(contentURL)
                }
            }
        }
    }
    
    private func decrypt(file: MXEncryptedContentFile, at path: String) {
        /*
         // decrypt the encrypted file
         NSInputStream *instream = [[NSInputStream alloc] initWithFileAtPath:self.cacheFilePath];
         NSOutputStream *outstream = [[NSOutputStream alloc] initToMemory];
         [MXEncryptedAttachments decryptAttachment:self->contentFile inputStream:instream outputStream:outstream success:^{
         onSuccess([outstream propertyForKey:NSStreamDataWrittenToMemoryStreamKey]);
         } failure:^(NSError *err) {
         if (err)
         {
         MXLogDebug(@"Error decrypting attachment! %@", err.userInfo);
         return;
         }
         }];
         */
        let input = InputStream(fileAtPath: path)
        let output = OutputStream(toMemory: ())
        MXEncryptedAttachments.decryptAttachment(
            file,
            inputStream: input,
            outputStream: output,
            success: { [weak self] in
                if let data = output.property(forKey: .dataWrittenToMemoryStreamKey) as? NSData {
                    self?.decryptedData.append(data)
                }
            },
            failure: { error in
            }
        )
    }
    
    @objc private func handleLoaderStateChange(_ notification: Notification) {
        guard let loader = notification.object as? MXMediaLoader else { return }
        guard let state = MediaLoaderState(rawValue: loader.state.rawValue) else { return }
        switch state {
        case .downloadInProgress:
            // Still loading
            break
        case .downloadCompleted:
            // Finished
            if let path = loader.downloadOutputFilePath {
                if let file = event.getEncryptedContentFiles().first(where: {
                    $0.url == loader.downloadMediaURL
                }) {
                    decrypt(file: file, at: path)
                }
            }
        case .downloadFailed, .canceled:
            // Failed to download (cancelled)
            break
        default:
            // Upload states
            break
        }
    }
}

struct MediaEventView: View {
    @Environment(\.userId) private var userId

    struct ViewModel {
        let event: MXEvent
        let showSender: Bool
        // Got from event
        let sender: String
        let timestamp: String
        var size: CGSize?
        var blurhash: String?

        init(event: MXEvent, showSender: Bool) {
            self.event = event
            self.showSender = showSender
            
            self.sender = event.sender ?? ""
            self.timestamp = Formatter.string(for: event.timestamp, timeStyle: .short)

            if let info: [String: Any] = event.content(valueFor: "info") {
                if let width = info["w"] as? Double,
                    let height = info["h"] as? Double {
                    self.size = CGSize(width: width, height: height)
                }
                self.blurhash = info["xyz.amorgan.blurhash"] as? String
            }
        }
    }

    let model: ViewModel
    let contextMenuModel: EventContextMenuModel?
    
    @ObservedObject var attachment: MediaAttachment
    
    init(model: ViewModel, contextMenuModel: EventContextMenuModel?) {
        self.model = model
        self.contextMenuModel = contextMenuModel
        let mediaManager = AuthViewModel.shared.session!.mediaManager!
        self.attachment = MediaAttachment(event: model.event, mediaManager: mediaManager)!
    }

    @ViewBuilder var placeholder: some View {
        // TBD: isn't there a "placeholder" generator in SwiftUI now?
        if let size = model.size,
           let blurhash = model.blurhash,
           let img = UIImage(blurHash: blurhash, size: size) {
            Image(uiImage: img)
        } else {
            Rectangle()
                .foregroundColor(Color.borderedMessageBackground)
        }
    }

    private var isMe: Bool {
        model.sender == userId
    }

    private var timestampView: some View {
        Text(model.timestamp)
        .font(.caption)
    }

    @ViewBuilder private var senderView: some View {
        if model.showSender && !isMe {
            Text(model.sender.dropAllgramSuffix)
                .font(.caption)
        }
    }

    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 5) {
            let type = model.event.content(valueFor: "msgtype") ?? "nil"
            switch type {
            case kMXMessageTypeAudio:
                if model.event.isVoiceMessage() {
                    AudioEventView(event: model.event)
                } else {
                    Text("ANOTHER MSGTYPE: \(type)")
                }
            case kMXMessageTypeImage:
                senderView
                // Сheck if decrypted data available
                if model.event.isEncrypted,
                   let nsData = attachment.decryptedData.first,
                   let data = Data(referencing: nsData),
                   let image = UIImage(data: data)
                {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(model.size ?? CGSize(width: 3, height: 2), contentMode: .fit)
                        .mask(RoundedRectangle(cornerRadius: 15))
                } else {
                    // Fallback to old ways
                    KFImage(attachment.mediaURLs.first)
                        .resizable()
                        .placeholder { placeholder }
                        .aspectRatio(model.size ?? CGSize(width: 3, height: 2), contentMode: .fit)
                        .mask(RoundedRectangle(cornerRadius: 15))
                }
                timestampView
            default:
                Text("ANOTHER MSGTYPE: \(type)")
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75,
                maxHeight: UIScreen.main.bounds.height * 0.75)
        .contextMenu(ContextMenu(menuItems: {
            if let model = contextMenuModel {
                EventContextMenu(model: model)
            }
        }))
    }
}

struct AudioEventView: View {
    @ObservedObject var voiceMessagePlaybackVM: VoiceMessagePlaybackViewModel
    
    let event: MXEvent
    let mediaManager: MXMediaManager
    let attachment: Attachment?
    
    init(event: MXEvent) {
        self.event = event
        mediaManager = MXMediaManager(homeServer: API.server.getURL()!.absoluteString)
        attachment = Attachment(event: event,
                                andMediaManager: mediaManager)
        voiceMessagePlaybackVM = VoiceMessagePlaybackViewModel(mediaServiceProvider: VoiceMessageMediaServiceProvider.sharedProvider, cacheManager: VoiceMessageAttachmentCacheManager.sharedManager)
        voiceMessagePlaybackVM.attachment = attachment
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
            
            HStack(alignment: .center) {
                Button {
                    voiceMessagePlaybackVM.voiceMessagePlaybackViewDidRequestPlaybackToggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                        Image(systemName: "play.fill")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.gray)
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                    }
                }
                .frame(width: 32, height: 32)
                .padding(5)
                
                Text("99:99")
                    .hidden()
                    .overlay(
                        HStack {
                            if let progressSecondsString = voiceMessagePlaybackVM.progressSecondsString {
                                Text("\(progressSecondsString)")
                                    .foregroundColor(.gray)
                            } else {
                                Text("\(voiceMessagePlaybackVM.currentTime)")
                                    .foregroundColor(.gray)
                            }
                        }
                    )
                
                HStack(alignment: .center) {
                    GeometryReader { geometry in
                        if let waveform = voiceMessagePlaybackVM.waveform {
                            Image(uiImage: waveform)
                                .resizable()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75,
                maxHeight: 40)
    }
}

//struct MediaEventView_Previews: PreviewProvider {
//    static var previews: some View {
//        let sendingModel = MediaEventView.ViewModel(
//            event: MXEvent(),
//            mediaURLs: [],
//            sender: "",
//            showSender: false,
//            timestamp: "9:41 am",
//            size: CGSize(width: 3000, height: 2000),
//            blurhash: nil)
//        MediaEventView(model: sendingModel, contextMenuModel: .previewModel)
//    }
//}
