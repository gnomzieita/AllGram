//
//  NewPostInputHandler.swift
//  AllGram
//
//  Created by Alex Pirog on 13.06.2022.
//

import SwiftUI

class NewPostInputHandler: ObservableObject {
    typealias SendPostResult = (success: Bool, problem: String?)
    
    let room: AllgramRoom
    var sendPostHandler: ((SendPostResult) -> Void)?
    
    init(room: AllgramRoom) {
        self.room = room
        self.inputVM = MessageInputViewModel(config: .newPost)
        // Set delegate to self
        inputVM.inputDelegate = self
    }
    
    @Published private(set) var inputVM: MessageInputViewModel
    
    @Published var postMedia: PreviewMedia = .none
    
    enum PreviewMedia {
        case none
        case image(_ image: UIImage)
        case video(_ videoURL: URL, thumbnail: UIImage)
        case voice(_ url: URL, duration: Int, samples: [Float]?)
    }
    
    // MARK: - Logic
    
    @Published private(set) var isLoading: Bool = false
    
    /// Counts all media added for the post (not counting text)
    var mediaTypesCount: Int {
        if case .none = postMedia { return 0 }
        return 1
    }
    
    /// `true` when there is NO text and only ONE media for the post
    private var isSimplePost: Bool {
        !inputVM.message.hasContent && mediaTypesCount == 1
    }
    
    /// `true` when there IS text and ONE media for the post
    private var isCombinedPost: Bool {
        inputVM.message.hasContent && mediaTypesCount == 1
    }
        
    /// When success - returns true and `nil` as problem field
    /// When failed - returns false and problem description
    private func sendPost(completion: @escaping ((SendPostResult) -> Void)) {
        withAnimation { isLoading = true }
        if isSimplePost {
            // Simple post -> only media to send
            switch postMedia {
            case .none:
                // What?!
                completion((false, "No media for post"))
            case .image(let image):
                room.sendImage(image: image) { success in
                    if success {
                        NotificationCenter.default.post(name: .userCreatedPost, object: nil)
                    }
                    completion((success, nil))
                }
            case .video(let url, let thumbnail):
                room.sendVideo(url: url, thumbnail: thumbnail) { success in
                    if success {
                        NotificationCenter.default.post(name: .userCreatedPost, object: nil)
                    }
                    completion((success, nil))
                }
            case .voice(_, _, _):
                completion((false, "Audio not supported yet"))
            }
        } else if isCombinedPost {
            // Combined post -> send header first
            let media = postMedia
            let text = inputVM.message
            room.sendPostHeader { [weak self] headerEventId in
                guard let self = self else { return }
                guard let eventId = headerEventId else {
                    completion((false, "Failed to send post header"))
                    return
                }
                self.room.reply(to: eventId, with: text) { [weak self] textId in
                    guard let self = self else { return }
                    guard textId != nil else {
                        completion((false, "Failed to reply with post text"))
                        return
                    }
                    switch media {
                    case .none:
                        // What?!
                        completion((false, "No media for post"))
                    case .image(let image):
                        self.room.reply(to: eventId, with: image, named: "custom_upload.jpeg") { imageId in
                            if imageId != nil {
                                NotificationCenter.default.post(name: .userCreatedPost, object: nil)
                                completion((true, nil))
                            } else {
                                completion((false, "Failed to reply with post image"))
                            }
                        }
                    case .video(let url, let thumbnail):
                        self.room.reply(to: eventId, with: url, thumbnail: thumbnail, named: "custom_upload.mp4") { videoId in
                            if videoId != nil {
                                NotificationCenter.default.post(name: .userCreatedPost, object: nil)
                                completion((true, nil))
                            } else {
                                completion((false, "Failed to reply with post video"))
                            }
                        }
                    case .voice(_, _, _):
                        // Not supported yet
                        completion((false, "Audio not supported yet"))
                    }
                }
            }
        } else {
            // What?!
            completion((false, "Unhandled post type"))
        }
    }
}

// MARK: - Input Delegate

extension NewPostInputHandler: MessageInputViewModelDelegate {
    func clearHighlight() {
        // Not possible when creating a post
    }
    
    func sendTextMessage(_ text: String, inputType: MessageInputType) {
        // We create new post here
        sendPost { [weak self] result in
            withAnimation{ self?.isLoading = false }
            self?.sendPostHandler?(result)
        }
    }
    
    func sendImageMessage(_ image: UIImage, inputType: MessageInputType) {
        withAnimation { postMedia = .image(image) }
    }
    
    func sendVideoMessage(_ url: URL, thumbnail: UIImage, inputType: MessageInputType) {
        withAnimation { postMedia = .video(url, thumbnail: thumbnail) }
    }
    
    func sendVoiceMessage(_ url: URL, duration: Int, samples: [Float]?, inputType: MessageInputType) {
        withAnimation { postMedia = .voice(url, duration: duration, samples: samples) }
    }
    
    func sendAudioMessage(_ url: URL, inputType: MessageInputType) {
        // Not allowed for new posts
    }
    
    func sendFileMessage(_ url: URL, inputType: MessageInputType) {
        // Not allowed for new posts
    }
    
    func sendEmptyMessage(inputType: MessageInputType) {
        // We create new post here (simple posts, without text)
        sendPost { [weak self] result in
            withAnimation{ self?.isLoading = false }
            self?.sendPostHandler?(result)
        }
    }
}

extension NewPostInputHandler: Equatable {
    static func == (lhs: NewPostInputHandler, rhs: NewPostInputHandler) -> Bool {
        lhs.room.roomId == rhs.room.roomId
    }
}
