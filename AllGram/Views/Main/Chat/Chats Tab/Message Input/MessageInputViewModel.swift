//
//  MessageInputViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 09.05.2022.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Type of the input for messages
enum MessageInputType {
    case new
    case edit(eventId: String, highlight: MessageInputHighlight)
    case reply(eventId: String, highlight: MessageInputHighlight)
}

/// Data to highlight when edit, reply, etc
enum MessageInputHighlight {
    case text(String)
    case image(UIImage)
    case video(thumbnail: UIImage)
    case voice(duration: Int)
}

/// Conform to this delegate to handle message data from `MessageInputViewModel`.
/// `Important`: conform to equitable and extend VMs `==` method
protocol MessageInputViewModelDelegate {
    func clearHighlight()
    func sendTextMessage(_ text: String, inputType: MessageInputType)
    func sendImageMessage(_ image: UIImage, inputType: MessageInputType)
    func sendVideoMessage(_ url: URL, thumbnail: UIImage, inputType: MessageInputType)
    func sendVoiceMessage(_ url: URL, duration: Int, samples: [Float]?, inputType: MessageInputType)
    func sendAudioMessage(_ url: URL, inputType: MessageInputType)
    func sendFileMessage(_ url: URL, inputType: MessageInputType)
    func sendEmptyMessage(inputType: MessageInputType)
}

/// Editing option for picked media (images & videos)
enum MessageInputEditingOption {
    /// No editing at all, use original media
    case none
    /// System default editing when picking from albums/gallery
    case `default`
    /// Our custom image and video editor
    case custom
}

enum MessageInputMicOption {
    /// Not showing at all
    case hidden
    /// Always showing
    case alwaysVisible
    /// Showing instead of send button when there in no content
    case onlyWhenNoContent
}

/// Provides additional configuration options. Use one of the static for convenience
struct MessageInputConfiguration {
    let placeholder: String
    let editingOption: MessageInputEditingOption
    let micOption: MessageInputMicOption
    let disableSendWhenNoContent: Bool
    let allowedFileTypesToSelect: [UTType]
    
    static let chat = MessageInputConfiguration(
        placeholder: "New Message...",
        editingOption: .custom,
        micOption: .onlyWhenNoContent,
        disableSendWhenNoContent: true,
        allowedFileTypesToSelect: [.image, .audiovisualContent, .data]
    )
    static let comment = MessageInputConfiguration(
        placeholder: "New Comment...",
        editingOption: .custom,
        micOption: .onlyWhenNoContent,
        disableSendWhenNoContent: true,
        allowedFileTypesToSelect: [.image, .audiovisualContent]
    )
    static let newPost = MessageInputConfiguration(
        placeholder: "Post Message...",
        editingOption: .custom,
        micOption: .hidden,
        disableSendWhenNoContent: false,
        allowedFileTypesToSelect: [.image, .audiovisualContent]
    )
}

/// Handles input from `MessageInputView`
class MessageInputViewModel: ObservableObject {
    /// Configuration for the input view
    let config: MessageInputConfiguration
    
    /// Delegate object responsible for actual sending of messages
    var inputDelegate: MessageInputViewModelDelegate?
    
    init(config: MessageInputConfiguration, delegate: MessageInputViewModelDelegate? = nil) {
        self.config = config
        self.inputDelegate = delegate
    }
    
    /// Current text input of the user
    @Published var message: String = ""
    
    /// Either has text or voice to send
    var sendEnabled: Bool {
        guard config.disableSendWhenNoContent else { return true }
        return hasTextToSend || hasVoiceToSend
    }
    
    /// Message text is not empty (handles white spaces and new lines)
    var hasTextToSend: Bool {
        message.hasContent
    }
    
    /// Either recording voice ATM or had previously recorded one
    var hasVoiceToSend: Bool {
        voiceMessageVM.isRecordingAudio || voiceMessageVM.hasRecorded
    }
    
    /// Current input type. Considers `.new` as clear type and triggers delegate when set to it
    @Published var inputType: MessageInputType = .new {
        didSet {
            guard case .new = inputType else { return }
            if case .new = oldValue {
                // Already was clear -> do nothing
            } else {
                // Had something with highlight -> need to clear
                inputDelegate?.clearHighlight()
            }
        }
    }
    
    /// Highlight data or `nil` when `.new` input type
    var highlight: MessageInputHighlight? {
        switch inputType {
        case .new:
            return nil
        case .edit(_, let highlight), .reply(_, let highlight):
            return highlight
        }
    }
    
    /// Only available if there is a highlight for current input type
    var highlightType: String? {
        switch inputType {
        case .new: return nil
        case .edit: return "Edit message:"
        case .reply: return "Reply to:"
        }
    }
    
    /// Handles send by a button. Will prioritise to send voice message if any available
    /// or text message if user input has some content
    func handleSend() {
        if hasVoiceToSend {
            sendRecordedVoice()
        } else if hasTextToSend {
            inputDelegate?.sendTextMessage(message, inputType: inputType)
            inputType = .new
            message = ""
        } else {
            inputDelegate?.sendEmptyMessage(inputType: inputType)
            inputType = .new
            message = ""
        }
    }
    
    // MARK: - Attachments
    
    /// Handles sending images
    func handleAttachment(_ image: UIImage) {
        switch inputType {
        case .new, .edit:
            // Not possible to edit image messages
            // Just send new one (stay in edit mode?)
            inputDelegate?.sendImageMessage(image, inputType: inputType)
        case .reply:
            // Clear after reply
            inputDelegate?.sendImageMessage(image, inputType: inputType)
            inputType = .new
        }
    }
    
    /// Handles sending videos with thumbnail
    func handleAttachment(videoURL: URL, thumbnail: UIImage) {
        switch inputType {
        case .new, .edit:
            // Not possible to edit video messages
            // Just send new one (stay in edit mode?)
            inputDelegate?.sendVideoMessage(videoURL, thumbnail: thumbnail, inputType: inputType)
        case .reply:
            // Clear after reply
            inputDelegate?.sendVideoMessage(videoURL, thumbnail: thumbnail, inputType: inputType)
            inputType = .new
        }
    }
    
    /// Handles sending audio messages
    func handleAttachment(audioURL: URL) {
        switch inputType {
        case .new, .edit:
            // Not possible to add file on edit, just send as new message
            inputDelegate?.sendAudioMessage(audioURL, inputType: inputType)
        case .reply:
            // Clear after reply
            inputDelegate?.sendAudioMessage(audioURL, inputType: inputType)
            inputType = .new
        }
    }
    
    /// Handles sending files
    func handleAttachment(fileURL: URL) {
        switch inputType {
        case .new, .edit:
            // Not possible to add file on edit, just send as new message
            inputDelegate?.sendFileMessage(fileURL, inputType: inputType)
        case .reply:
            // Clear after reply
            inputDelegate?.sendFileMessage(fileURL, inputType: inputType)
            inputType = .new
        }
    }
    
    // MARK: - Voice Message
    
    /// Counts time of the voice recording and provide formatted text
    @Published private(set) var timeCounter = TimeCounter()

    /// Handles voice recording
    private let voiceMessageVM = VoiceMessageViewModel(mediaServiceProvider: VoiceMessageMediaServiceProvider.sharedProvider)
    
    /// Starts new recording if not in process already
    func initiateVoiceRecording() {
        guard !voiceMessageVM.isRecordingAudio else { return }
        voiceMessageVM.voiceMessageDidRequestRecordingStart()
        timeCounter.startCounting()
    }
    
    /// Finished current recording if any
    func finishVoiceRecoding() {
        guard voiceMessageVM.isRecordingAudio else { return }
        voiceMessageVM.voiceMessageDidRequestRecordingFinish()
        timeCounter.stopCounting()
    }

    /// Cancels and deletes current recording
    func cancelVoiceRecording() {
        voiceMessageVM.voiceMessageDidRequestRecordingCancel()
        timeCounter.stopCounting()
    }

    /// Sends current recording if available, finishing ongoing recording if needed
    func sendRecordedVoice() {
        if voiceMessageVM.isRecordingAudio {
            voiceMessageVM.voiceMessageDidRequestRecordingFinish()
            timeCounter.stopCounting()
        }
        guard voiceMessageVM.hasRecorded else { return }
        voiceMessageVM.voiceMessageDidRequestSend { [weak self] url, duration, samples in
            self?.inputDelegate?.sendVoiceMessage(url, duration: duration, samples: samples, inputType: self!.inputType)
        }
    }
    
    // MARK: - Selecting Files
    
    func handleSelectingFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // Remember this access start/stop
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if url.contains(.image) {
                        if let data = try? Data(contentsOf: url),
                           let image = UIImage(data: data) {
                            handleAttachment(image)
                        }
                    } else if url.contains(.audio) {
                        // Audio is sent as file
                        handleAttachment(audioURL: url)
                    } else if url.contains(.audiovisualContent) || url.contains(.video) {
                        do {
                            let asset = AVURLAsset(url: url)
                            let imgGenerator = AVAssetImageGenerator(asset: asset)
                            imgGenerator.appliesPreferredTrackTransform = true
                            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
                            let thumbnail = UIImage(cgImage: cgImage)
                            handleAttachment(videoURL: url, thumbnail: thumbnail)
                        } catch _ {
                        }
                    } else if url.contains(.data) {
                        handleAttachment(fileURL: url)
                    }
                }
            }
        case .failure(_):
            break
        }
    }
}

extension MessageInputViewModel: Equatable {
    static func == (lhs: MessageInputViewModel, rhs: MessageInputViewModel) -> Bool {
        // Try to compare by delegates
        guard let lDelegate = lhs.inputDelegate, let rDelegate = rhs.inputDelegate
        else {
            // One has delegate and the other one has NOT - not equal
            // Otherwise (both without delegates) - equal
            return lhs.inputDelegate == nil && rhs.inputDelegate == nil
        }
        if let ld = lDelegate as? ChatInputHandler,
            let rd = rDelegate as? ChatInputHandler {
            // Both chats input
            return ld == rd
        } else if let ld = lDelegate as? CommentInputHandler,
                  let rd = rDelegate as? CommentInputHandler {
            // Both comment input
            return ld == rd
        } else if let ld = lDelegate as? NewPostInputHandler,
                  let rd = rDelegate as? NewPostInputHandler {
            // Both new post input
            return ld == rd
        } else {
            // Safe to crush here?
            fatalError("Incomparable message input view model delegates!")
        }
    }
}
