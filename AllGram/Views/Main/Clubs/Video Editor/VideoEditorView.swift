//
//  VideoEditorView.swift
//  AllGram
//
//  Created by Alex Pirog on 01.06.2022.
//

import SwiftUI
import AVKit

/// Expected to be inside NavigationView as has controls in navigation bar
struct VideoEditorView: View {
    let url: URL
    let destination: URL
    let compressionHandler: (URL, UIImage) -> Void
    let cancelHandler: () -> Void
    
    init(videoURL: URL, compressionHandler: @escaping (URL, UIImage) -> Void, cancelHandler: @escaping () -> Void) {
        self.compressionHandler = compressionHandler
        self.cancelHandler = cancelHandler
        self.url = videoURL
        // Declare temporary destination path
        self.destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("compressed.mp4")
        // Set initial time range for whole duration
        let asset = AVAsset(url: videoURL)
        _timeRange = State(initialValue: 0...Float(asset.duration.seconds))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                editVideo
                if let progress = progress {
                    ProgressView(progress)
                        .padding()
                } else if isTrimming {
                    TrimVideoView(
                        videoURL: url,
                        trimRange: $timeRange,
                        cancel: {
                            withAnimation {
                                isTrimming = false
                                // Clear trim time
                                let asset = AVAsset(url: url)
                                timeRange = 0...Float(asset.duration.seconds)
                            }
                        },
                        confirm: {
                            withAnimation { isTrimming = false }
                        }
                    )
                    .padding()
                } else {
                    // editOptionsStack
                    niceOptionsStack
                }
            }
        }
        .background(Color.tabBackground)
        .colorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            title: "Video Editor",
            leading:
                HStack {
                    Button {
                        withAnimation {
                            cancelable?.cancel = true
                            cancelHandler()
                        }
                    } label: {
                        Text("Cancel")
                    }
                }
            ,
            trailing:
                HStack {
                    if let cancelable = cancelable {
                        Button {
                            withAnimation {
                                cancelable.cancel = true
                            }
                        } label: {
                            Text("Stop")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button {
                            withAnimation {
                                compress()
                            }
                        } label: {
                            Text("Compress")
                        }
                    }
                }
        )
    }
    
    // MARK: - Video View
    
    @State var play: Bool = true
    @State var time: CMTime = .zero
    @State var mute: Bool = false
    @State var timeRange: ClosedRange<Float>
    
    // Our changes to video, will be applied at compression
    @State private var videoTransform: CGAffineTransform = .identity
    
    // Local variables to show transform to user
    @State private var flippedHorizontally = false
    @State private var flippedVertically = false
    @State private var rotateAngle = Angle.zero
    @State private var rotatedSideways = false
    
    var editVideo: some View {
        VStack(spacing: 0) {
            EditVideoContainer(videoURL: url, play: $play, time: $time, mute: $mute)
                .scaleEffect(x: flippedHorizontally ? -1 : 1,
                             y: flippedVertically ? -1 : 1)
                .rotationEffect(rotateAngle)
            Divider()
            VideoControlsView(videoURL: url, play: $play, time: $time, timeRange: $timeRange)
                .padding()
            Divider()
        }
//        .overlay(
//            Image("qrcode-solid")
//                .renderingMode(.template)
//                .resizable().scaledToFit()
//                .frame(width: 80, height: 80)
//                .foregroundColor(.red)
//                .transformEffect(videoTransform)
//        )
    }
    
    // MARK: - Edit Options
    
    @State private var isTrimming = false
    
    var editOptionsStack: some View {
        EditorOptionsView { tapOption in
            switch tapOption {
            case .trim:
                withAnimation {
                    isTrimming = true
                }
            case .rotateR:
                withAnimation {
                    let rotate = CGAffineTransform(rotationAngle: -.pi / 2)
                    videoTransform = videoTransform.concatenating(rotate)
                    rotateAngle += Angle(radians: .pi / 2) // Inverted
                    rotatedSideways.toggle()
                }
            case .rotateL:
                withAnimation {
                    let rotate = CGAffineTransform(rotationAngle: .pi / 2)
                    videoTransform = videoTransform.concatenating(rotate)
                    rotateAngle += Angle(radians: -.pi / 2) // Inverted
                    rotatedSideways.toggle()
                }
            case .flipH:
                withAnimation {
                    let flip = CGAffineTransform(scaleX: -1, y: 1)
                    videoTransform = videoTransform.concatenating(flip)
                    rotatedSideways
                    ? flippedVertically.toggle()
                    : flippedHorizontally.toggle()
                }
            case .flipV:
                withAnimation {
                    let flip = CGAffineTransform(scaleX: 1, y: -1)
                    videoTransform = videoTransform.concatenating(flip)
                    rotatedSideways
                    ? flippedHorizontally.toggle()
                    : flippedVertically.toggle()
                }
            case .clear:
                withAnimation {
                    videoTransform = .identity
                    rotateAngle = .zero
                    rotatedSideways = false
                    flippedHorizontally = false
                    flippedVertically = false
                }
            }
        }
    }
    
    private var niceOptionsStack: some View {
        HStack(spacing: 0) {
            Spacer()
            // Show trim options
            Button {
                withAnimation {
                    isTrimming = true
                }
            } label: {
                VStack(spacing: 0) {
                    Image(systemName: "timeline.selection")
                        .renderingMode(.template)
                        .resizable().scaledToFill()
                        .frame(width: 36, height: 24)
                        .padding(.vertical, 6)
                    Text("Trim")
                        .font(.footnote)
                }
            }
            Spacer()
            Group {
                // Rotate
                Button {
                    withAnimation {
                        let rotate = CGAffineTransform(rotationAngle: .pi / 2)
                        videoTransform = videoTransform.concatenating(rotate)
                        rotateAngle += Angle(radians: -.pi / 2) // Inverted
                        rotatedSideways.toggle()
                    }
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "rotate.left.fill")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(.all, 6)
                        Text("Rotate L")
                            .font(.footnote)
                    }
                }
                Spacer()
                Button {
                    withAnimation {
                        let rotate = CGAffineTransform(rotationAngle: -.pi / 2)
                        videoTransform = videoTransform.concatenating(rotate)
                        rotateAngle += Angle(radians: .pi / 2) // Inverted
                        rotatedSideways.toggle()
                    }
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "rotate.right.fill")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(.all, 6)
                        Text("Rotate R")
                            .font(.footnote)
                    }
                }
            }
            Spacer()
            Group {
                // Flip
                Button {
                    withAnimation {
                        let flip = CGAffineTransform(scaleX: -1, y: 1)
                        videoTransform = videoTransform.concatenating(flip)
                        rotatedSideways
                        ? flippedVertically.toggle()
                        : flippedHorizontally.toggle()
                    }
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(.all, 6)
                        Text("Flip H")
                            .font(.footnote)
                    }
                }
                Spacer()
                Button {
                    withAnimation {
                        let flip = CGAffineTransform(scaleX: 1, y: -1)
                        videoTransform = videoTransform.concatenating(flip)
                        rotatedSideways
                        ? flippedHorizontally.toggle()
                        : flippedVertically.toggle()
                    }
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down.fill")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(.all, 6)
                        Text("Flip V")
                            .font(.footnote)
                    }
                }
            }
            Spacer()
            // Clear (reset)
            Button {
                withAnimation {
                    videoTransform = .identity
                    rotateAngle = .zero
                    rotatedSideways = false
                    flippedHorizontally = false
                    flippedVertically = false
                }
            } label: {
                VStack(spacing: 0) {
                    Image(systemName: "trash.fill")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(.all, 6)
                    Text("Clear")
                        .font(.footnote)
                }
            }
            .foregroundColor(videoTransform == .identity ? .gray : .white)
            .disabled(videoTransform == .identity)
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.top, 4)
        .padding(.bottom)
    }
    
    // MARK: - Compressing
    
    @State var cancelable: CancelableCompression? {
        didSet { progress = nil }
    }
    @State var progress: Progress?
    
    private func compress() {
        // Cancel current compress (should not happen)
        cancelable?.cancel = true
        // Pause video
        play = false
        // Remove last compressed file if any
        try? FileManager.default.removeItem(at: destination)
        // Do the compression
        let track = AVAsset(url: url).tracks(withMediaType: .video).first!
        let naturalSize = track.naturalSize
        let preferredTransform = track.preferredTransform
        let transformedSize = naturalSize.applying(preferredTransform)
        let resolution = CGSize(width: abs(transformedSize.width),
                                height: abs(transformedSize.height))
        let ourBitRate = Float(3 * resolution.height * resolution.width)
        let minBitRate = min(track.estimatedDataRate, ourBitRate)
        let combinedTransform = preferredTransform.concatenating(videoTransform)
        let combinedSize = naturalSize.applying(combinedTransform)
        let startTime = CMTime(seconds: Double(timeRange.lowerBound), preferredTimescale: time.timescale)
        let endTime = CMTime(seconds: Double(timeRange.upperBound), preferredTimescale: time.timescale)
        let range = CMTimeRange(start: startTime, end: endTime)
        cancelable = compressh264Video(
            videoToCompress: url,
            destinationPath: destination,
            size: combinedSize,
            timeRange: range,
            compressionTransform: .fixFromCameraAndCustom(combinedTransform),
            compressionConfig: .defaultConfig(with: Int(minBitRate), fps: Int(track.nominalFrameRate)),
            progressHandler: { progress in
                withAnimation {
                    self.progress = progress
                }
            },
            completion: { result in
                switch result {
                case .success(let url):
                    withAnimation {
                        cancelable = nil
                    }

                    // Create thumbnail
                    let asset = AVURLAsset(url: url)
                    let imgGenerator = AVAssetImageGenerator(asset: asset)
                    imgGenerator.appliesPreferredTrackTransform = true
                    let cgImage = try? imgGenerator.copyCGImage(at: range.start, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage!)
                    compressionHandler(url, thumbnail)
                case .failure(_):
                    withAnimation {
                        cancelable = nil
                    }
                case .cancelled:
                    withAnimation {
                        cancelable = nil
                    }
                }
            }
        )
    }
}
