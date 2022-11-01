//
//  ChatFullscreenMediaView.swift
//  AllGram
//
//  Created by Alex Pirog on 05.07.2022.
//

import SwiftUI

struct ChatFullscreenMediaView: View {
    let attachment: ChatMediaAttachment
    
    @State var mediaLocalURL: URL?
    
    init(attachment: ChatMediaAttachment) {
        self.attachment = attachment
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            switch attachment.event.messageType! {
            case .image:
                if let data = attachment.imageData, let image = UIImage(data: data) {
                    // Media as row data
                    ZoomableScrollView {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                    }
                } else {
                    // Media is not ready yet
                    ExpandingHStack() {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                    }
                }
            case .video:
                if let data = attachment.thumbnailData, let image = UIImage(data: data) {
                    if let url = mediaLocalURL {
                        // Video is ready
                        PostVideoContainer(videoURL: url, thumbnailImage: image)
                            .equatable()
                    } else {
                        // Only thumbnail yet
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                    }
                } else {
                    // Media is not ready yet
                    ExpandingHStack() {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                    }
                }
            default:
                ExpandingHStack() {
                    Text("NOT A MEDIA")
                        .foregroundColor(.white)
                }
            }
            Spacer()
        }
        .onAppear {
            attachment.prepareShare { url in
                mediaLocalURL = url
            }
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
                    if let title = attachment.uniqueMediaName {
                        Text(title).bold()
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
        mediaLocalURL != nil
    }
    
    private var shareActivities: [AnyObject] {
        var activities = [AnyObject]()
        if let url = mediaLocalURL {
            activities.append(url as AnyObject)
        }
        return activities
    }
}

// From: https://stackoverflow.com/a/64110231/10353982
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // set up the UIScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator  // for viewForZooming(in:)
        scrollView.maximumZoomScale = 10
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true
        
        // create a UIHostingController to hold our SwiftUI content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)
        
        // we use black background
        hostedView.backgroundColor = .black
        
        return scrollView
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content))
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // update the hosting controller's SwiftUI content
        context.coordinator.hostingController.rootView = self.content
        assert(context.coordinator.hostingController.view.superview == uiView)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        
        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}
