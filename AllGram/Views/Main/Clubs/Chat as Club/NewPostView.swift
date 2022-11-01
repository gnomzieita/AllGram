//
//  NewPostView.swift
//  AllGram
//
//  Created by Alex Pirog on 15.03.2022.
//

import SwiftUI
import Kingfisher
import MatrixSDK
import AVKit

extension NewPostView: Equatable {
    static func == (lhs: NewPostView, rhs: NewPostView) -> Bool {
        lhs.room.id == rhs.room.id
    }
}

struct NewPostView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private(set) var feedVM: ClubFeedViewModel
    @ObservedObject private(set) var room: AllgramRoom
    
    /// Handles creating posts from combined media and text
    @ObservedObject private var inputHandler: NewPostInputHandler
    
    /// Handles input view and provides data for new post
    @ObservedObject private var inputVM: MessageInputViewModel
    
    init(feedVM: ClubFeedViewModel) {
        self.feedVM = feedVM
        self.room = feedVM.room
        let handler = NewPostInputHandler(room: feedVM.room)
        self.inputHandler = handler
        self.inputVM = handler.inputVM
    }
    
    @State var showPermissionAlert = false
    @State var permissionAlertText = ""
    
    var body: some View {
        ZStack {
            ZStack {
                // Navigation
                VStack {
                    NavigationLink(
                        destination: mediaDetailsDestination,
                        isActive: $showMediaDetails
                    ) {
                        EmptyView()
                    }
                }
                // Input
                VStack(spacing: 0) {
                    // Preview
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            postPreview
                        }
                    }
                    .onTapGesture { hideKeyboard() }
                    // Message input
                    Divider()
                    MessageInputView(viewModel: inputVM, showPermissionAlert: $showPermissionAlert, permissionAlertText: $permissionAlertText)
                        .equatable()
                        .onAppear {
                            inputHandler.sendPostHandler = { result in
                                withAnimation {
                                    if result.success {
                                        loaderText = "Paginating to new post."
                                        // Delay club feed update and dismiss
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            feedVM.paginate() { done in
                                                if done {
                                                    showingLoader = false
                                                    presentationMode.wrappedValue.dismiss()
                                                } else {
                                                    feedVM.paginate() { done in
                                                        showingLoader = false
                                                        presentationMode.wrappedValue.dismiss()
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        showingLoader = false
                                        failureText = result.problem
                                        showingFailure = true
                                    }
                                }
                            }
                        }
                }
                // Custom Alerts
                if showingLoader { loaderAlert }
                if showingFailure { failureAlert }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: inputHandler.isLoading) { newValue in
                guard newValue else { return }
                loaderText = "Creating new post."
                withAnimation { showingLoader = true }
            }
            .ourToolbar(
                leading:
                    HStack {
                        AvatarImageView(feedVM.clubLogoURL, name: feedVM.clubName)
                            .frame(width: Constants.clubLogoSize, height: Constants.clubLogoSize)
                        VStack(alignment: .leading) {
                            Text("Creating a post").bold()
                        }
                    }
            )
            if showPermissionAlert { permissionAlertView }
        }
    }
    
    private var permissionAlertView: some View {
        ActionAlert(showAlert: $showPermissionAlert, title: "Access to \(permissionAlertText)", text: "Tap Settings and enable \(permissionAlertText)", actionTitle: "Settings") {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    
    // MARK: - Media Details
    
    @State private var showMediaDetails = false
    
    private var mediaDetailsDestination: some View {
        VStack {
            Spacer()
            switch inputHandler.postMedia {
            case .none, .voice:
                ExpandingHStack() {
                    Text("No Media")
                        .foregroundColor(.white)
                }
            case .image(let image):
                Image(uiImage: image)
                    .resizable().scaledToFit()
            case .video(let url, _):
                NativePlayerContainer(videoURL: url)
            }
            Spacer()
        }
        .background(Color.black)
    }
    
    // MARK: - Loading
    
    @State private var showingLoader = false
    @State private var loaderText: String?
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderText, shown: $showingLoader)
        }
    }
    
    // MARK: - Failure
    
    @State private var showingFailure = false
    @State private var failureText: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: "Failed to create new post." + (failureText == nil ? "" : "\n\(failureText!)"), shown: $showingFailure)
        }
    }
    
    // MARK: - Preview
    
    /// Whole screen width minus some padding
    private var postWidth: CGFloat {
        let width = UIScreen.main.bounds.width
        return width - 32
    }
    
    /// Required height to fit image/video according to its aspect ratio or fixed for audio
    private var postHeight: CGFloat {
        switch inputHandler.postMedia {
        case .none:
            return 30
        case .image(let image):
            let ratio = image.size.width / image.size.height
            return postWidth / (ratio.isNaN ? 1 : ratio)
        case .video(_, let thumbnail):
            let ratio = thumbnail.size.width / thumbnail.size.height
            return postWidth / (ratio.isNaN ? 1 : ratio)
        case .voice:
            return 30
        }
    }
    
    private var postPreview: some View {
        VStack {
            switch inputHandler.postMedia {
            case .none:
                Text("Required: Add post media")
                    .foregroundColor(.gray)
                    .padding(.vertical)
            case .image(let image):
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(height: postHeight)
                    .frame(width: postWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onTapGesture {
                        withAnimation { showMediaDetails = true }
                    }
            case .video(_, let thumbnail):
                Image(uiImage: thumbnail)
                    .resizable().scaledToFit()
                    .frame(height: postHeight)
                    .frame(width: postWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(PlayImageOverlay())
                    .onTapGesture {
                        withAnimation { showMediaDetails = true }
                    }
            case .voice:
                Text("Audio files not supported yet")
                    .foregroundColor(.red)
                    .padding(.vertical)
            }
            if inputVM.message.hasContent {
                Text(inputVM.message)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            } else if inputHandler.mediaTypesCount == 1 {
                Text("Optional: Add post text")
                    .foregroundColor(.gray)
                    .padding(.vertical)
            }
        }
    }
    
    // MARK: - Input
    
//    private var postInput: some View {
//        VStack {
//            MessageComposerView(
//                showAttachmentPicker: $showAttachmentPicker,
//                isEditing: $isEditingMessage,
//                attributedMessage: $postText,
//                disableSendIfNoInput: false,
//                onCancel: {},
//                onEditingChanged: { _ in },
//                onRecord: recordVoiceMessage,
//                onRecordEnded: getVoiceMessage,
//                onRecordCancel: cancelRecordVoiceMessage,
//                onCommit: {
//                    hideKeyboard()
//                    sendPost() { success, problem in
//                        withAnimation {
//                            if success {
//                                // Delay a second to update club feed and dismiss
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                    feedVM.paginate() { _ in
//                                        showingLoader = false
//                                        presentationMode.wrappedValue.dismiss()
//                                    }
//                                }
//                            } else {
//                                showingLoader = false
//                                failureText = problem
//                                showingFailure = true
//                            }
//                        }
//                    }
//                }
//            )
//                .equatable()
//                .padding(.horizontal)
//                .padding(.vertical, 8)
//        }
//    }
    
    // MARK: -
    
    struct Constants {
        static let clubLogoSize: CGFloat = 32
        static let mediaPaddingV: CGFloat = 4
        static let senderAvatarSize: CGFloat = 48
        static let commentPaddingH: CGFloat = 16
        static let commentSpacing: CGFloat = 4
        static let commentBottomGap: CGFloat = 8
    }
    
}

