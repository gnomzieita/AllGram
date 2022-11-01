//
//  TrimVideoView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.06.2022.
//

import SwiftUI
import AVFoundation

struct TrimVideoView: View {
    let videoURL: URL
    let imageGenerator: AVAssetImageGenerator
    let duration: CMTime
    
    @Binding var trimRange: ClosedRange<Float>
    
    let cancelTrim: () -> Void
    let confirmTrim: () -> Void
    
    init(videoURL: URL, trimRange: Binding<ClosedRange<Float>>, cancel: @escaping () -> Void, confirm: @escaping () -> Void) {
        self.videoURL = videoURL
        _trimRange = trimRange
        let asset = AVAsset(url: videoURL)
        self.imageGenerator = AVAssetImageGenerator(asset: asset)
        self.duration = asset.duration
        self.cancelTrim = cancel
        self.confirmTrim = confirm
        imageGenerator.appliesPreferredTrackTransform = true
    }
    
    var body: some View {
        HStack {
            Button {
                withAnimation { cancelTrim() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
            }
            TrimVideoRangeSliderView(
                value: $trimRange,
                bounds: Float(CMTime.zero.seconds)...Float(duration.seconds),
                frameImages: frames
            )
                .padding(.horizontal)
            Button {
                withAnimation { confirmTrim() }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(.green)
                    .frame(width: 32, height: 32)
            }
        }
        .onAppear {
            // Always use frames for whole duration
            updateFrames(from: .zero, to: duration)
        }
    }
    
    // MARK: - Calculate Frames
    
    @State private var frames: [TimedFrameImage] = []
    
    private func updateFrames(from: CMTime, to: CMTime) {
        frames.removeAll()
        let startSeconds = from.roundedSeconds
        let endSeconds = to.roundedSeconds
        let steps = max(8, min(24, duration.roundedSeconds))
        let stepSeconds = (endSeconds - startSeconds) / steps
        for seconds in stride(from: startSeconds, to: endSeconds, by: stepSeconds) {
            let time = CMTime(seconds: seconds, preferredTimescale: duration.timescale)
            let cgImage = try! imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            let frame = TimedFrameImage(time:time, image: uiImage)
            frames.append(frame)
        }
    }
}

struct TimedFrameImage: Identifiable {
    var id: String { "\(time)" }
    let time: CMTime
    let image: UIImage
}

struct TrimVideoRangeSliderView: View {
    let currentValue: Binding<ClosedRange<Float>>
    let sliderBounds: ClosedRange<Float>
    let frameImages: [TimedFrameImage]
    
    let minRangeValue: Float = 1.0 // No sorter than 1 second
    let capHeight: CGFloat = 48 // Limit height, but take all width
    
    init(value: Binding<ClosedRange<Float>>, bounds: ClosedRange<Float>, frameImages: [TimedFrameImage]) {
        self.currentValue = value
        self.sliderBounds = bounds
        self.frameImages = frameImages
    }
    
    var body: some View {
        GeometryReader { geomentry in
            sliderView(sliderSize: geomentry.size)
        }
        .frame(height: capHeight)
    }
    
    @ViewBuilder
    private func sliderView(sliderSize: CGSize) -> some View {
        let sliderViewYCenter = sliderSize.height / 2
        ZStack {
            // Background
            backgroundView(of: sliderSize, with: frameImages)
            // Slider
            ZStack {
                let sliderBoundDifference = sliderBounds.upperBound - sliderBounds.lowerBound
                let stepWidthInPixel = CGFloat(sliderSize.width) / CGFloat(sliderBoundDifference)
                
                // Calculate left/right location
                let leftLocation: CGFloat = currentValue.wrappedValue.lowerBound == Float(sliderBounds.lowerBound)
                    ? 0
                    : CGFloat(currentValue.wrappedValue.lowerBound - Float(sliderBounds.lowerBound)) * stepWidthInPixel
                let rightLocation = CGFloat(currentValue.wrappedValue.upperBound) * stepWidthInPixel
                
                // Blur cut off background
                let leftWidth = leftLocation
                blurView(
                    at: CGPoint(x: 0 + leftWidth / 2, y: sliderViewYCenter),
                    of: CGSize(width: leftWidth, height: capHeight)
                )
                let rightWidth = sliderSize.width - rightLocation
                blurView(
                    at: CGPoint(x: rightLocation + rightWidth / 2, y: sliderViewYCenter),
                    of: CGSize(width: rightWidth, height: capHeight)
                )
                
                // Left handle
                let leftPoint = CGPoint(x: leftLocation, y: sliderViewYCenter)
                handleView(at: leftPoint, facingLeft: true)
                    .highPriorityGesture(
                        DragGesture().onChanged { dragValue in
                            let dragLocation = dragValue.location
                            let xThumbOffset = min(max(0, dragLocation.x), sliderSize.width)
                            
                            let newValue = Float(sliderBounds.lowerBound) + Float(xThumbOffset / stepWidthInPixel)
                            
                            // Stop the range thumbs from colliding each other
                            if newValue < currentValue.wrappedValue.upperBound - minRangeValue {
                                currentValue.wrappedValue = newValue...currentValue.wrappedValue.upperBound
                            }
                        }
                    )
                
                // Right Thumb Handle
                let rightPoint = CGPoint(x: rightLocation, y: sliderViewYCenter)
                handleView(at: rightPoint, facingLeft: false)
                    .highPriorityGesture(
                        DragGesture().onChanged { dragValue in
                            let dragLocation = dragValue.location
                            let xThumbOffset = min(max(CGFloat(leftLocation), dragLocation.x), sliderSize.width)
                            
                            var newValue = Float(xThumbOffset / stepWidthInPixel) // convert back the value bound
                            newValue = min(newValue, Float(sliderBounds.upperBound))
                            
                            // Stop the range thumbs from colliding each other
                            if newValue > currentValue.wrappedValue.lowerBound + minRangeValue {
                                currentValue.wrappedValue = currentValue.wrappedValue.lowerBound...newValue
                            }
                        }
                    )
            }
        }
    }
    
    @ViewBuilder
    private func backgroundView(of size: CGSize, with frames: [TimedFrameImage]) -> some View {
        HStack(spacing: 0) {
            ForEach(frames) { frame in
                Image(uiImage: frame.image)
                    .resizable().scaledToFill()
                    .frame(width: size.width / CGFloat(frameImages.count),
                           height: capHeight)
                    .clipped()
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
    
    @ViewBuilder
    private func blurView(at position: CGPoint, of size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .foregroundColor(.white.opacity(0.6))
            .frame(width: size.width, height: size.height)
            .position(x: position.x, y: position.y)
    }
    
    @ViewBuilder
    private func handleView(at position: CGPoint, facingLeft: Bool) -> some View {
        Image(systemName: "chevron.compact." + (facingLeft ? "left" : "right"))
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(height: capHeight / 2)
                .padding(.horizontal, 2)
                .padding(.vertical, capHeight / 4)
                .background(Color.orange)
                .clipShape(Capsule())
                .position(x: position.x, y: position.y)
    }
}

// Slider with 2 handles, subrange from given range
// https://stackoverflow.com/a/71910078/10353982
struct RangedSliderView: View {
    let currentValue: Binding<ClosedRange<Float>>
    let sliderBounds: ClosedRange<Float>
    let minRangeValue: Float
    
    // Configuration
    let capWidth: CGFloat?
    let capHeight: CGFloat?
    
    init(value: Binding<ClosedRange<Float>>, bounds: ClosedRange<Float>, minRange: Float = 0.0, capWidth: CGFloat? = nil, capHeight: CGFloat? = nil) {
        self.currentValue = value
        self.sliderBounds = bounds
        self.minRangeValue = minRange
        self.capWidth = capWidth
        self.capHeight = capHeight
    }
    
    var body: some View {
        GeometryReader { geomentry in
            sliderView(sliderSize: geomentry.size)
        }
        .frame(width: capWidth, height: capHeight)
    }
    
    @ViewBuilder private func sliderView(sliderSize: CGSize) -> some View {
        let sliderViewYCenter = sliderSize.height / 2
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(.gray)
                .frame(height: 4)
            ZStack {
                let sliderBoundDifference = sliderBounds.upperBound - sliderBounds.lowerBound
                let stepWidthInPixel = CGFloat(sliderSize.width) / CGFloat(sliderBoundDifference)
                
                // Calculate Left Thumb initial position
                let leftThumbLocation: CGFloat = currentValue.wrappedValue.lowerBound == Float(sliderBounds.lowerBound)
                    ? 0
                    : CGFloat(currentValue.wrappedValue.lowerBound - Float(sliderBounds.lowerBound)) * stepWidthInPixel
                
                // Calculate right thumb initial position
                let rightThumbLocation = CGFloat(currentValue.wrappedValue.upperBound) * stepWidthInPixel
                
                // Path between both handles
                lineBetweenThumbs(from: .init(x: leftThumbLocation, y: sliderViewYCenter), to: .init(x: rightThumbLocation, y: sliderViewYCenter))
                
                // Left Thumb Handle
                let leftThumbPoint = CGPoint(x: leftThumbLocation, y: sliderViewYCenter)
                thumbView(position: leftThumbPoint, value: Float(currentValue.wrappedValue.lowerBound))
                    .highPriorityGesture(DragGesture().onChanged { dragValue in
                        let dragLocation = dragValue.location
                        let xThumbOffset = min(max(0, dragLocation.x), sliderSize.width)
                        
                        let newValue = Float(sliderBounds.lowerBound) + Float(xThumbOffset / stepWidthInPixel)
                        
                        // Stop the range thumbs from colliding each other
                        if newValue < currentValue.wrappedValue.upperBound - minRangeValue {
                            currentValue.wrappedValue = newValue...currentValue.wrappedValue.upperBound
                        }
                    })
                
                // Right Thumb Handle
                thumbView(position: CGPoint(x: rightThumbLocation, y: sliderViewYCenter), value: currentValue.wrappedValue.upperBound)
                    .highPriorityGesture(DragGesture().onChanged { dragValue in
                        let dragLocation = dragValue.location
                        let xThumbOffset = min(max(CGFloat(leftThumbLocation), dragLocation.x), sliderSize.width)
                        
                        var newValue = Float(xThumbOffset / stepWidthInPixel) // convert back the value bound
                        newValue = min(newValue, Float(sliderBounds.upperBound))
                        
                        // Stop the range thumbs from colliding each other
                        if newValue > currentValue.wrappedValue.lowerBound + minRangeValue {
                            currentValue.wrappedValue = currentValue.wrappedValue.lowerBound...newValue
                        }
                    })
            }
        }
    }
    
    @ViewBuilder func lineBetweenThumbs(from: CGPoint, to: CGPoint) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }.stroke(Color.accentColor, lineWidth: 4)
    }
    
    @ViewBuilder func thumbView(position: CGPoint, value: Float) -> some View {
        ZStack {
            Text(String(value))
                .font(.system(size: 10))
                .offset(y: -20)
            Circle()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
                .contentShape(Rectangle())
        }
        .position(x: position.x, y: position.y)
    }
}
