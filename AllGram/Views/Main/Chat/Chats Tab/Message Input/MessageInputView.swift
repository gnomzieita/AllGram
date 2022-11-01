//
//  MessageInputView.swift
//  AllGram
//
//  Created by Alex Pirog on 09.05.2022.
//

import SwiftUI
import AVKit

struct MessageInputView: View {
    @ObservedObject var voicePlayer = ChatVoicePlayer.shared
    
    @ObservedObject var viewModel: MessageInputViewModel
    @ObservedObject var counter: TimeCounter
    
    var showPermissionAlert: Binding<Bool>
    var permissionAlertText: Binding<String>
        
    init(viewModel: MessageInputViewModel, showPermissionAlert: Binding<Bool>, permissionAlertText: Binding<String>) {
        self.viewModel = viewModel
        self.counter = viewModel.timeCounter
        self.showPermissionAlert = showPermissionAlert
        self.permissionAlertText = permissionAlertText
    }
    
    var body: some View {
        VStack {
            if viewModel.highlight != nil {
                highlightView
            }
            HStack(alignment: .bottom) {
                attachmentButton
                messageEditorView
                switch viewModel.config.micOption {
                case .hidden:
                    sendButton
                    
                case .alwaysVisible:
                    audioButton
                    sendButton
                    
                case .onlyWhenNoContent:
                    if !viewModel.message.hasContent {
                        audioButton
                    } else {
                        sendButton
                    }
                }
            }
        }
        .padding()
        .actionSheet(isPresented: $showAttachmentPicker) {
            ActionSheet(
                title: Text("Send Media"),
                buttons: pickerOptions
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                sourceType: imagePickerSource,
                allowDefaultEditing: viewModel.config.editingOption == .default,
                onImagePicked: { image in
                    if viewModel.config.editingOption == .custom {
                        imageToEdit = image
                    } else {
                        viewModel.handleAttachment(image)
                    }
                },
                onVideoPicked: { url, thumbnail in
                    if viewModel.config.editingOption == .custom {
                        videoToEditURL = url
                    } else {
                        // Expects to always be able to get thumbnail
                        viewModel.handleAttachment(videoURL: url, thumbnail: thumbnail!)
                    }
                }
            )
        }
        .onChange(of: showImagePicker) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: viewModel.config.allowedFileTypesToSelect,
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleSelectingFile(result)
        }
        .onChange(of: showFilePicker) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
        // For some strange reason, .fullScreenCover will be same as .sheet
        .fullScreenCover(isPresented: $showImageEditor) {
            imageEditorView
        }
        .onChange(of: imageToEdit) { newValue in
            withAnimation { showImageEditor = newValue != nil }
        }
        .fullScreenCover(isPresented: $showVideoEditor) {
            videoEditorView
        }
        .onChange(of: videoToEditURL) { newValue in
            withAnimation { showVideoEditor = newValue != nil }
        }
        .fullScreenCover(isPresented: $showEditedVideo) {
            videoResultView
        }
        .onChange(of: editedVideoURL) { newValue in
            withAnimation { showEditedVideo = newValue != nil }
        }
    }
    
    // MARK: - Custom Image Editor
    
    @State private var showImageEditor = false
    @State private var imageToEdit: UIImage?
    
    @ViewBuilder
    private var imageEditorView: some View {
        NavigationView {
            if let image = imageToEdit {
                ImageEditor(
                    originalImage: image,
                    cropHandler: { cropped in
                        viewModel.handleAttachment(cropped)
                        imageToEdit = nil
                    },
                    cancelHandler: {
                        imageToEdit = nil
                    }
                )
                    .background(Color.black.edgesIgnoringSafeArea(.bottom))
                    .navigationBarTitle("Image Editor")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyView()
                    .onAppear {
                        showImageEditor = false
                    }
            }
        }
    }
    
    // MARK: - Custom Video Editor
    
    @State private var showVideoEditor = false
    @State private var videoToEditURL: URL?
    
    @State private var showEditedVideo = false
    @State private var editedVideoURL: URL?
    @State private var editedThumbnail: UIImage?
    
    private var videoEditorView: some View {
        NavigationView {
            if let url = videoToEditURL {
                VideoEditorView(
                    videoURL: url,
                    compressionHandler: { url, thumbnail in
                        // Show result with compressed video in DEV environment
                        if API.inDebug {
                            editedVideoURL = url
                            editedThumbnail = thumbnail
                        } else {
                            viewModel.handleAttachment(videoURL: url, thumbnail: thumbnail)
                        }
                        videoToEditURL = nil
                    },
                    cancelHandler: {
                        videoToEditURL = nil
                    }
                )
            } else {
                EmptyView()
                    .onAppear {
                        showVideoEditor = false
                    }
            }
        }
    }
    
    private var videoResultView: some View {
        NavigationView {
            if let url = editedVideoURL {
                NativePlayerContainer(videoURL: url)
                    .navigationBarTitleDisplayMode(.inline)
                    .ourToolbar(
                        title: "Edited Video",
                        leading:
                            HStack {
                                Button {
                                    editedVideoURL = nil
                                } label: {
                                    Text("Close")
                                }
                            }
                        ,
                        trailing:
                            HStack {
                                Button {
                                    viewModel.handleAttachment(
                                        videoURL: url,
                                        thumbnail: editedThumbnail!
                                    )
                                    editedVideoURL = nil
                                } label: {
                                    Text("Use")
                                }
                            }
                    )
            } else {
                EmptyView()
                    .onAppear {
                        showEditedVideo = false
                    }
            }
        }
    }
    
    // MARK: - Audio Components
    
    @State private var audioOffset = CGFloat.zero
    @State private var isAudioDragging = false
    @State private var isAudioLocked = false
    
    private var audioButton: some View {
        Group {
            if isAudioLocked {
                audioArrow
            } else {
                audioMic
            }
        }
        .background(
            Group {
                if isAudioDragging {
                    audioLock.offset(x: 0, y: Constants.audioMaxOffset)
                } else if isAudioLocked {
                    audioTrash.offset(x: 0, y: Constants.audioMaxOffset)
                } else {
                    // Not dragging and not locked, so none
                }
            }
        )
        .padding(.bottom, Constants.iconBottomPadding)
    }
    
    private var audioLock: some View {
        Image("lock-solid")
            .renderingMode(.template)
            .resizable().scaledToFit()
            .foregroundColor(.white)
            .padding(2)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(
                Circle().fill(.blue)
                    .scaleEffect(1.2)
            )
    }
    
    private var audioTrash: some View {
        Image(systemName: "trash")
//        Image("trash-alt") // Our icon is not centred...
            .renderingMode(.template)
            .resizable().scaledToFit()
            .foregroundColor(.white)
            .padding(4) // Padding as system icon is larger
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(
                Circle().fill(.red)
                    .scaleEffect(1.2)
            )
            .onTapGesture {
                withAnimation {
                    isAudioLocked = false
                    viewModel.cancelVoiceRecording()
                }
            }
    }
    
    private var audioArrow: some View {
        Image("arrow-circle-up-solid")
            .renderingMode(.template)
            .resizable().scaledToFit()
            .foregroundColor(.accentColor)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .onTapGesture {
                viewModel.sendRecordedVoice()
                withAnimation {
                    isAudioDragging = false
                    isAudioLocked = false
                }
            }
    }
    
    private var audioMic: some View {
        Image("microphone-solid")
            .renderingMode(.template)
            .resizable().scaledToFit()
            .foregroundColor(isAudioDragging ? .white : .accentColor)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .offset(x: 0, y: audioOffset)
            .background(
                Circle().fill(.green)
                    .scaleEffect(1.2)
                    .opacity(isAudioDragging ? 1 : 0)
                    .offset(x: 0, y: audioOffset)
            )
            .gesture(audioDragGesture)
    }
    
    private var audioDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                switch PermissionsManager.shared.getAuthStatusFor(.audio) {
                case .notDetermined: // User has not yet been asked for camera access
                    AVCaptureDevice.requestAccess(for: .audio) { response in
                        if response {
                            withAnimation {
                                if !isAudioDragging {
                                    // Audio not started yet -> start recording
                                    isAudioDragging = true
                                    viewModel.initiateVoiceRecording()
                                    // Pause current playing voice message if any
                                    voicePlayer.pause()
                                }
                                // Use only negative values (moving up)
                                // but not higher than lock icon
                                audioOffset = max(Constants.audioMaxOffset, min(.zero, gesture.translation.height))
                            }
                        } else {
                            permissionAlertText.wrappedValue = "microphone"
                            showPermissionAlert.wrappedValue = true
                        }
                    }
                case .authorized:
                    withAnimation {
                        if !isAudioDragging {
                            // Audio not started yet -> start recording
                            isAudioDragging = true
                            viewModel.initiateVoiceRecording()
                            // Pause current playing voice message if any
                            voicePlayer.pause()
                        }
                        // Use only negative values (moving up)
                        // but not higher than lock icon
                        audioOffset = max(Constants.audioMaxOffset, min(.zero, gesture.translation.height))
                    }
                default:
                    permissionAlertText.wrappedValue = "microphone"
                    showPermissionAlert.wrappedValue = true
                }
            }
            .onEnded { _ in
                withAnimation {
                    if !isAudioLocked {
                        // Not yet locked -> check position
                        if audioOffset < Constants.audioLockOffset {
                            // Lock audio (close enough to lock)
                            isAudioLocked = true
                            isAudioDragging = false
                        } else {
                            // No need to lock audio (far from lock)
                            isAudioDragging = false
                            viewModel.sendRecordedVoice()
                        }
                    } else {
                        // Already locked -> do nothing
                    }
                    // Reset position anyway
                    audioOffset = .zero
                }
            }
    }
    
    // MARK: - Attachment Components
    
    @State private var showAttachmentPicker: Bool = false
    @State private var showFilePicker = false
    @State private var showImagePicker: Bool = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    private var pickerOptions: [ActionSheet.Button] {
        var result = [ActionSheet.Button]()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            result.append(
                .default(
                    Text("Camera"),
                    action: {
                        switch PermissionsManager.shared.getAuthStatusFor(.video) {
                        case .notDetermined: // User has not yet been asked for camera access
                            AVCaptureDevice.requestAccess(for: .video) { response in
                                if response {
                                    imagePickerSource = .camera
                                    showImagePicker = true
                                } else {
                                    permissionAlertText.wrappedValue = "camera"
                                    showPermissionAlert.wrappedValue = true
                                }
                            }
                        case .authorized:
                            withAnimation {
                                imagePickerSource = .camera
                                showImagePicker = true
                            }
                        default:
                            permissionAlertText.wrappedValue = "camera"
                            showPermissionAlert.wrappedValue = true
                        }
                    }
                )
            )
        }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            result.append(
                .default(
                    Text("Photo Library"),
                    action: {
                        imagePickerSource = .photoLibrary
                        showImagePicker = true
                    }
                )
            )
        }
        if !viewModel.config.allowedFileTypesToSelect.isEmpty {
            result.append(
                .default(
                    Text("File System"),
                    action: {
                        showFilePicker = true
                    }
                )
            )
        }
        result.append(.cancel())
        return result
    }
    
    private var attachmentButton: some View {
        Button {
            withAnimation { showAttachmentPicker = true }
        } label: {
            Image("plus-circle-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
        }
        .disabled(isAudioDragging || isAudioLocked)
        .padding(.bottom, Constants.iconBottomPadding)
    }
    
    // MARK: - Other Components
    
    private var timeAvailable: Bool {
        viewModel.timeCounter.currentTime != nil
    }
        
    private var messageEditorView: some View {
        NMultilineTextField(
            text: $viewModel.message,
            initialHeight: Constants.inputMinHeight,
            heightLimit: timeAvailable ? Constants.inputMinHeight : Constants.inputMaxHeight,
            onCommit: nil // Keep 'return' button for new lines,
        ) {
            NMultilineTextFieldPlaceholder(text: viewModel.config.placeholder)
        }
            .opacity(timeAvailable ? 0 : 1)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(.gray.opacity(0.2))
            )
            .overlay(
                HStack {
                    if let time = viewModel.timeCounter.currentTime {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 4, height: 4)
                            .padding(.horizontal)
                        Text(verbatim: viewModel.timeCounter.text(for: time))
                        Spacer()
                    } else {
                        EmptyView()
                    }
                }
            )
    }
    
    private var highlightView: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 2)
                .foregroundColor(.gray)
                .padding(.horizontal)
            VStack(alignment: .leading) {
                Text(viewModel.highlightType!).italic()
                switch viewModel.highlight! {
                case .text(let string):
                    Text(verbatim: string)
                        .lineLimit(1)
                case .image(_):
                    Text(verbatim: "image/jpeg")
                        .lineLimit(1)
                case .video(_):
                    Text(verbatim: "video/mp4")
                        .lineLimit(1)
                case .voice(let duration):
                    Text(verbatim: "voice - duration: \(duration)")
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: { viewModel.inputType = .new }, label: {
                Image("times-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .scaleEffect(0.8)
            })
                .padding(.horizontal)
        }
        .frame(height: 40)
        .padding(.leading, Constants.iconSize)
    }
    
    private var sendButton: some View {
        Button {
            viewModel.handleSend()
            withAnimation {
                // Reset audio UI after sending
                isAudioDragging = false
                isAudioLocked = false
            }
        } label: {
            Image("paper-plane")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
        }
        .disabled(!viewModel.sendEnabled)
        .padding(.bottom, Constants.iconBottomPadding)
    }
    
    // MARK: -
    
    struct Constants {
        static let iconSize: CGFloat = 32
        static let iconBottomPadding: CGFloat = 3
        static var audioMaxOffset: CGFloat { -iconSize * 2 }
        static var audioLockOffset: CGFloat { audioMaxOffset + iconSize / 3 }
        static let inputMinHeight: CGFloat = 38 // Observed value
        static let inputMaxHeight: CGFloat = 100 // +22 for each line
    }
    
}

extension MessageInputView: Equatable {
    static func == (lhs: MessageInputView, rhs: MessageInputView) -> Bool {
        lhs.viewModel == rhs.viewModel
    }
}

// MARK: - [NEW] Multiline TextField

// Code snippet from this: https://stackoverflow.com/questions/56471973/how-do-i-create-a-multiline-textfield-in-swiftui
// Updated with custom line limit (for single/n-lines TextField)
// and handling first responder (internally and externally)

import SwiftUI
import UIKit

struct NMultilineTextFieldPlaceholder: View {
    let text: String
    let textColor: Color
    
    init(text: String, textColor: Color = .gray) {
        self.text = text
        self.textColor = textColor
    }
    
    var body: some View {
        Text(text)
            .lineLimit(1)
            .foregroundColor(textColor)
            .padding(.leading, 4)
    }
}

struct NMultilineTextField<Placeholder: View>: View {
    @Binding private var text: String
    
    let heightLimit: CGFloat
    let lineLimit: Int
    let onCommit: (() -> Void)?
    let placeholder: Placeholder
    
    @State private var dynamicHeight: CGFloat = 0
    @State private var showPlaceholder: Bool = true
    
    /// Creates TextField with dynamic height, but not more than given height limit
    init(text: Binding<String>,
         initialHeight: CGFloat = 0,
         heightLimit: CGFloat = .infinity,
         onCommit: (() -> Void)? = nil,
         @ViewBuilder placeholderBuilder: () -> Placeholder
    ) {
        self._text = text
        self.heightLimit = heightLimit
        self.lineLimit = 0
        self.onCommit = onCommit
        self.placeholder = placeholderBuilder()
        // Initial states
        self.dynamicHeight = initialHeight
        self.showPlaceholder = text.wrappedValue.isEmpty
    }
    
    /// Creates TextField with dynamic height, but not more than given number of lines
    init(text: Binding<String>,
         lineLimit: Int,
         onCommit: (() -> Void)? = nil,
         @ViewBuilder placeholderBuilder: () -> Placeholder
    ) {
        self._text = text
        self.heightLimit = .infinity
        self.lineLimit = lineLimit
        self.onCommit = onCommit
        self.placeholder = placeholderBuilder()
        // Initial states
        self.dynamicHeight = 0
        self.showPlaceholder = text.wrappedValue.isEmpty
    }

    var body: some View {
        NUITextViewWrapper(text: $text, calculatedHeight: $dynamicHeight, lineLimit: lineLimit, onDone: onCommit)
            .frame(minHeight: min(dynamicHeight, heightLimit),
                   maxHeight: min(dynamicHeight, heightLimit))
            .background(
                Group { if showPlaceholder { placeholder } }, alignment: .leading
            )
            .onChange(of: text) { newValue in
                showPlaceholder = newValue.isEmpty
            }
    }
}

struct NUITextViewWrapper: UIViewRepresentable {
    typealias UIViewType = UITextView

    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    
    let lineLimit: Int
    var onDone: (() -> Void)?

    func makeUIView(context: UIViewRepresentableContext<NUITextViewWrapper>) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        
        textView.isEditable = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.isScrollEnabled = true
        textView.backgroundColor = UIColor.clear
        if lineLimit > 0 {
            textView.textContainer.maximumNumberOfLines = lineLimit
            textView.textContainer.lineBreakMode = .byTruncatingHead
        }
        if onDone != nil {
            textView.returnKeyType = .done
        }
        
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<NUITextViewWrapper>) {
        // Fix text if needed
        if uiView.text != self.text {
            uiView.text = self.text
        }
        
        // Recalculate only when on screen
        if uiView.window != nil {
            NUITextViewWrapper.recalculateHeight(view: uiView, result: $calculatedHeight)
        }
    }

    static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
        let newSize = view.sizeThatFits(CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        if result.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                // Must be called asynchronously on main queue
                result.wrappedValue = newSize.height
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, height: $calculatedHeight, lineLimit: lineLimit, onDone: onDone)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var calculatedHeight: Binding<CGFloat>
        let lineLimit: Int
        let onDone: (() -> Void)?

        init(text: Binding<String>, height: Binding<CGFloat>, lineLimit: Int, onDone: (() -> Void)?) {
            self.text = text
            self.calculatedHeight = height
            self.lineLimit = lineLimit
            self.onDone = onDone
        }

        func textViewDidChange(_ uiView: UITextView) {
            text.wrappedValue = uiView.text
            NUITextViewWrapper.recalculateHeight(view: uiView, result: calculatedHeight)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if let onDone = self.onDone, text == "\n" {
                textView.resignFirstResponder()
                onDone()
                return false
            }
            return true
        }
    }
}
