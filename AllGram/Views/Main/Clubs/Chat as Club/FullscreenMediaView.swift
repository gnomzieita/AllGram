//
//  FullscreenMediaView.swift
//  AllGram
//
//  Created by Alex Pirog on 17.05.2022.
//

import SwiftUI
import Kingfisher

struct FullscreenMediaView: View {
    let title: String?
    
    let imageURL: URL?
    
    let videoURL: URL?
    let thumbnailURL: URL?
    
    init(title: String? = nil, imageURL: URL?) {
        self.title = title
        self.imageURL = imageURL
        self.videoURL = nil
        self.thumbnailURL = nil
    }
    
    init(title: String? = nil, videoURL: URL?, thumbnailURL: URL?) {
        self.title = title
        self.imageURL = nil
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
    }
    
    init(media: PostMediaType) {
        switch media {
        case .image(let info, _):
            self.title = info.name
            self.imageURL = info.url
            self.videoURL = nil
            self.thumbnailURL = nil
        case .video(let info, _):
            self.title = info.name
            self.imageURL = nil
            self.videoURL = info.url
            self.thumbnailURL = info.thumbnail.url
        }
    }
    
    init(media: CommentMediaType) {
        switch media {
        case .image(let info):
            self.title = info.name
            self.imageURL = info.url
            self.videoURL = nil
            self.thumbnailURL = nil
        case .video(let info):
            self.title = info.name
            self.imageURL = nil
            self.videoURL = info.url
            self.thumbnailURL = info.thumbnail.url
        default:
            self.title = nil
            self.imageURL = nil
            self.videoURL = nil
            self.thumbnailURL = nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let url = imageURL {
                ZoomableScrollView {
                    KFImage(url)
                        .onSuccess { result in
                            imageToShare = result.image
                        }
                        .resizable().scaledToFit()
                }
            } else if let url = videoURL, let thumbnail = thumbnailURL {
                PostVideoContainer(videoURL: url, thumbnailURL: thumbnail)
                    .equatable()
                    .onAppear {
                        downloader.downloadVideo(url) { localURL in
                            videoLocalURL = localURL
                        }
                    }
            } else {
                ExpandingHStack() {
                    Text("NOT A MEDIA")
                        .foregroundColor(.white)
                }
            }
            Spacer()
        }
        .sheet(isPresented: $showingShare) {
            ActivityViewController(activityItems: shareActivities)
        }
        .onChange(of: showingShare) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
        .ourToolbar(
            leading:
                Group {
                    if title != nil {
                        Text(title!).bold()
                    } else {
                        EmptyView()
                    }
                }
            ,
            trailing:
                Button {
                    showingShare = true
                } label: {
                    Image("share-alt-square-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                        .opacity(readyForShare ? 1 : 0)
                }
                .disabled(!readyForShare)
        )
        .background(Color.black.ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Share Media
    
    @State private var showingShare = false
    private var readyForShare: Bool {
        imageToShare != nil || videoLocalURL != nil
    }
    
    @ObservedObject private var downloader = VideoDownloader()
    @State private var videoLocalURL: URL?
    @State private var imageToShare: UIImage?
    
    private var shareActivities: [AnyObject] {
        var activities = [AnyObject]()
        if let image = imageToShare {
            activities.append(image as AnyObject)
        }
        if let video = videoLocalURL {
            activities.append(video as AnyObject)
        }
        return activities
    }
    
}
