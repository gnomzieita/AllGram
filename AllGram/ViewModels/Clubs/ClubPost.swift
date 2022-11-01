//
//  ClubPost.swift
//  AllGram
//
//  Created by Alex Pirog on 18.02.2022.
//

import Foundation
import Combine
import MatrixSDK

/// Interpreted post content from room events
struct ClubPost: Identifiable {
    
    // Club data
    let clubRoomId: String
    let clubName: String
    let clubLogoURL: URL?
    
    /// Main post events, should be at lest 1 event in simple posts
    var postEvents: [MXEvent]
    
    /// Main MXEvent id
    var id: String { postEvents.first!.eventId }
    
    /// Server timestamp of the main event of the post
    var timestamp: UInt64 { postEvents.first!.originServerTs }
    
    /// Content of the post
    let postMedia: PostMediaType
    
    /// Aspect ration of the media content
    var mediaAspectRatio: CGFloat {
        switch postMedia {
        case .image(let info, _):
            return info.aspectRatio
        case .video(let info, _):
            return info.aspectRatio
        }
    }
    
    /// Only returns `true` when there is a 👍 reaction to this post
    var isLicked: Bool {
        reactions.contains(where: { $0.reaction == "👍" })
    }
    
    /// Can current user delete the post?
    let canDelete: Bool
    
    /// Can current user edit the post?
    let canEdit: Bool
    
    /// MXEvents related to the post directly or recursively
    var postRelatedEvents = [MXEvent]()
    
    /// Reactions for this post
    var reactions = [Reaction]()
    
    /// Related events that were handled properly as comments
    var comments = [ClubComment]()
    
    /// In combined posts, returns the first event of type `text` if allowed to edit.
    /// Otherwise, returns `nil`
    var textEvent: MXEvent? {
        guard canEdit else { return nil }
        return postEvents.first(where: { $0.content["msgtype"] as? String == kMXMessageTypeText })
    }
    
    init(clubRoomId: String, clubName: String, clubLogoURL: URL?,
         postEvents: [MXEvent], postMedia: PostMediaType,
         canDelete: Bool, canEdit: Bool,
         postRelatedEvents: [MXEvent] = [MXEvent](),
         reactions: [Reaction] = [Reaction](),
         comments: [ClubComment] = [ClubComment]()
    ) {
        self.clubRoomId = clubRoomId
        self.clubName = clubName
        self.clubLogoURL = clubLogoURL
        self.postEvents = postEvents
        self.postMedia = postMedia
        self.canDelete = canDelete
        self.canEdit = canEdit
        self.postRelatedEvents = postRelatedEvents
        self.reactions = reactions
    }
    
    /// Returns `true` is a given event is a reply to one of the post events
    func isEventReply(_ reply: MXEvent) -> Bool {
        for e in postEvents {
            if e.eventId == reply.replyToEventId {
                return true
            }
        }
        return false
    }
    
    func sortedReactions() -> [String: [Reaction]] {
        var result = [String: [Reaction]]()
        for r in reactions {
            if let old = result[r.reaction] {
                result[r.reaction] = old + [r]
            } else {
                result[r.reaction] = [r]
            }
        }
        return result
    }
    
}

extension ClubPost: Equatable {
    static func == (lhs: ClubPost, rhs: ClubPost) -> Bool {
        return lhs.id == rhs.id && lhs.comments == rhs.comments && lhs.reactions == rhs.reactions
    }
}

/// Now, can only be image or video posts with optional text
enum PostMediaType {
    /// Image and optional post text
    case image(info: ImageInfo, text: String?)
    /// Video and optional post text
    case video(info: VideoInfo, text: String?)
    
    /// Optional text alongside with media
    var text: String? {
        switch self {
        case .image(_, let text):
            return text
        case .video(_, let text):
            return text
        }
    }
    
    /// Last path component of the content (image/video) URL
    var preview: String {
        switch self {
        case .image(let info, _):
            return info.url.lastPathComponent
        case .video(let info, _):
            return info.url.lastPathComponent
        }
    }
}

// MARK: - Video message (post)

struct VideoInfo {
    let width: CGFloat
    let height: CGFloat
    let type: String
    let size: Int? // Not available in some cases?!
    let duration: Int // In some cases is 0...
    let url: URL
    let thumbnail: ImageInfo
    let name: String?
    
    let encryptedEvent: MXEvent?
    
    var isEncrypted: Bool { encryptedEvent?.isEncrypted ?? false }
    
    /// Width divided by height (replaces `NaN` with `1`)
    var aspectRatio: CGFloat {
        let ratio = width / height
        return ratio.isNaN ? 1 : ratio
    }
    
    /// Expects event to be of type `.video`
    init?(videoEvent: MXEvent, mediaManager: MXMediaManager) {
        guard let uri = videoEvent.content["url"] as? String,
              let urlString = mediaManager.url(ofContent: uri),
              let realURL = URL(string: urlString)
        else {
            // Invalid video url
            return nil
        }
        guard let info = videoEvent.content["info"] as? [String: Any],
              let duration = info["duration"] as? Int,
              let w = info["w"] as? CGFloat,
              let h = info["h"] as? CGFloat,
              let mime = info["mimetype"] as? String
        else {
            // Invalid info dictionary
            return nil
        }
        guard let thumbnailInfo = info["thumbnail_info"] as? [String: Any],
              let thumbnailURI = info["thumbnail_url"] as? String,
              let thumbnailStringURL = mediaManager.url(ofContent: thumbnailURI),
              let thumbnailURL = URL(string: thumbnailStringURL),
              let imageInfo = ImageInfo(
                imageInfoDictionary: thumbnailInfo,
                imageURL: thumbnailURL
              )
        else {
            // Invalid thumbnail data
            return nil
        }
        self.width = w
        self.height = h
        self.type = mime
        self.duration = duration
        self.size = info["size"] as? Int
        self.url = realURL
        self.thumbnail = imageInfo
        self.name = videoEvent.content["body"] as? String
        self.encryptedEvent = nil
    }
    
    /// Expects decrypted video message event
    init?(encryptedEvent: MXEvent, mediaManager: MXMediaManager) {
        guard let file = encryptedEvent.content["file"] as? [String: Any],
              let uri = file["url"] as? String,
              let urlString = mediaManager.url(ofContent: uri),
              let realURL = URL(string: urlString)
        else {
            // Invalid video url
            return nil
        }
        guard let info = encryptedEvent.content["info"] as? [String: Any],
              let duration = info["duration"] as? Int,
              let w = info["w"] as? CGFloat,
              let h = info["h"] as? CGFloat,
              let mime = info["mimetype"] as? String
        else {
            // Invalid info dictionary
            return nil
        }
        guard let thumbnailFile = info["thumbnail_file"] as? [String: Any],
              let thumbnailURI = thumbnailFile["url"] as? String,
              let thumbnailStringURL = mediaManager.url(ofContent: thumbnailURI),
              let thumbnailURL = URL(string: thumbnailStringURL),
              let thumbnailInfo = info["thumbnail_info"] as? [String: Any],
              let imageInfo = ImageInfo(
                imageInfoDictionary: thumbnailInfo,
                imageURL: thumbnailURL
              )
        else {
            // Invalid thumbnail data
            return nil
        }
        self.width = w
        self.height = h
        self.type = mime
        self.duration = duration
        self.size = info["size"] as? Int
        self.url = realURL
        self.thumbnail = imageInfo
        self.name = encryptedEvent.content["body"] as? String
        self.encryptedEvent = encryptedEvent
    }
}

// MARK: - Image message (post)

struct ImageInfo {
    let width: CGFloat
    let height: CGFloat
    let type: String
    let size: Int
    let url: URL
    let name: String?
    
    let encryptedEvent: MXEvent?
    
    var isEncrypted: Bool { encryptedEvent?.isEncrypted ?? false }
    
    /// Width divided by height (replaces `NaN` with `1`)
    var aspectRatio: CGFloat {
        let ratio = width / height
        return ratio.isNaN ? 1 : ratio
    }
    
    /// Expects event to be of type `.image`
    init?(imageEvent: MXEvent, mediaManager: MXMediaManager) {
        guard let uri = imageEvent.content["url"] as? String,
              let urlString = mediaManager.url(ofContent: uri),
              let realURL = URL(string: urlString),
              let info = imageEvent.content["info"] as? [String: Any]
        else {
            // Invalid event passed
            return nil
        }
        self.init(imageInfoDictionary: info, imageURL: realURL, name: imageEvent.content["body"] as? String)
    }
    
    /// Expects decrypted image message event
    init?(encryptedEvent: MXEvent, mediaManager: MXMediaManager) {
        guard let file = encryptedEvent.content["file"] as? [String: Any],
              let uri = file["url"] as? String,
              let urlString = mediaManager.url(ofContent: uri),
              let realURL = URL(string: urlString),
              let info = encryptedEvent.content["info"] as? [String: Any]
        else {
            // Invalid event passed
            return nil
        }
        self.init(imageInfoDictionary: info, imageURL: realURL, name: encryptedEvent.content["body"] as? String, encryptedEvent: encryptedEvent)
    }
    
    /// Intended for internal usage and for video thumbnails
    init?(imageInfoDictionary info: [String: Any], imageURL: URL, name: String? = nil, encryptedEvent: MXEvent? = nil) {
        guard let w = info["w"] as? CGFloat,
              let h = info["h"] as? CGFloat,
              let mime = info["mimetype"] as? String,
              let s = info["size"] as? Int
        else {
            // Invalid info dictionary
            return nil
        }
        self.width = w
        self.height = h
        self.type = mime
        self.size = s
        self.url = imageURL
        self.name = name
        self.encryptedEvent = encryptedEvent
    }
}

// MARK: - Voice message (post)

import DSWaveformImage

struct VoiceInfo {
    let name: String?
    let type: String
    let size: Int
    let duration: TimeInterval
    let waveform: UIImage?
    let url: URL
    
    /// Expects event to be of type `.audio` and `isVoiceMessage()` (does not check inside)
    init?(voiceEvent: MXEvent, mediaManager: MXMediaManager) {
        guard let voiceData: [String: Any] = voiceEvent.content(valueFor: "org.matrix.msc1767.audio"),
              let rawDuration = voiceData["duration"] as? Int,
              let rowWave = voiceData["waveform"] as? [Float],
              let voiceInfo: [String: Any] = voiceEvent.content(valueFor: "info"),
              let mime = voiceInfo["mimetype"] as? String,
              let s = voiceInfo["size"] as? Int,
              let uri = voiceEvent.content["url"] as? String,
              let urlString = mediaManager.url(ofContent: uri),
              let realURL = URL(string: urlString)
        else {
            // Invalid event passed
            return nil
        }
        
        self.name = voiceEvent.content["body"] as? String
        self.type = mime
        self.size = s
        self.url = realURL
        self.duration = max(TimeInterval(rawDuration) / 1000, 1)
        
        // We need no normilize waveform values to (0...1)
        // and provide size where width should be exactly
        // number of samples divided by waveform scale
        
        // Event contains up to 100 samples for all durations,
        // but short (1 sec) can provide 100 and long (1 min) only 60
        // and each sample ranges from 0 to up almost to 1000
        
        let max: Float = 1000 //rowWave.sorted().last ?? 0
        let normalizedWave = rowWave.map({ 1 - $0 / max })
        
        let waveScale: CGFloat = 2
        let waveSize = CGSize(width: CGFloat(normalizedWave.count) / waveScale, height: 30)
        
        let waveformImageDrawer = WaveformImageDrawer()
        self.waveform = waveformImageDrawer.waveformImage(
            from: normalizedWave,
            with: .init(
                size: waveSize,
                backgroundColor: .clear, // default
                style: .striped(
                    .init(
                        color: .gray,
                        width: 1, spacing: 1,
                        lineCap: CGLineCap.round
                    )
                ),
                dampening: nil, // default
                position: .middle, // default
                scale: waveScale > 1 ? waveScale : 1, // at least 1
                verticalScalingFactor: 0.95, // default
                shouldAntialias: false // default
            )
        )
    }
}
