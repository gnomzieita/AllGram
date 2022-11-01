//
//  VideoCompressionManager.swift
//  AllGram
//
//  Created by Alex Pirog on 31.05.2022.
//

import AVFoundation
import AssetsLibrary
import Foundation
import QuartzCore
import UIKit

/// Returns dimensions of a video at local storage URL or `nil` otherwise
func getVideoResolution(url: URL) -> CGSize? {
    guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first
    else { return nil }
    let size = track.naturalSize.applying(track.preferredTransform)
    return CGSize(width: abs(size.width), height: abs(size.height))
}

/// Tuple with bit rate and frames per second properties
typealias BitrateAndFPS = (bitRate: Float, fps: Float)

/// Returns bit rate and FPS of a video at local storage URL or `nil` otherwise
func getVideoBitRate(url: URL) -> BitrateAndFPS? {
    guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first
    else { return nil }
    return (track.estimatedDataRate, track.nominalFrameRate)
}

// Tuple with calculated raw file size in bits, bytes, megabytes, gigabytes
typealias FileSize = (bits: Float, bytes: Float, megabytes: Float, gigabytes: Float)

/// Calculates file size for anything at local storage URL or `nil` otherwise
func getFileSize(url: URL) -> FileSize? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    else { return nil }
    let bit = Float(attributes[FileAttributeKey.size] as! UInt64)
    let byte = bit / 1024
    let mb = byte / 1024
    let gb = mb / 1024
    return (bit, byte, mb, gb)
}

// Blog post with details:
// https://testfairy.com/blog/fine-tuned-video-compression-in-ios-swift-4-no-dependencies/

// Global Queue for All Compressions
fileprivate let compressQueue = DispatchQueue(label: "compressQueue", qos: .userInitiated)

// Angle Conversion Utility
extension Int {
    fileprivate var degreesToRadiansCGFloat: CGFloat {
        return CGFloat(Double(self) * Double.pi / 180)
    }
}

// Compression Interruption Wrapper
class CancelableCompression {
    var cancel = false
}

// Compression Error Messages
struct CompressionError: LocalizedError {
    let title: String
    let code: Int
    
    init(title: String = "Compression Error", code: Int = -1) {
        self.title = title
        self.code = code
    }
}

// Compression Transformation Configuration
enum CompressionTransform {
    /// Resets current transform to initial value
    case useOriginal
    /// Fixes transform for videos taken from device camera
    case fixFromCamera
    /// Applies custom transform (take care for videos from device camera)
    case custom(CGAffineTransform)
    /// Combines `fixFromCamera` and `custom` options
    case fixFromCameraAndCustom(CGAffineTransform)
}

// Compression Encode Parameters
struct CompressionConfig {
    let videoBitrate: Int
    let videomaxKeyFrameInterval: Int
    let avVideoProfileLevel: String
    let audioSampleRate: Int
    let audioBitrate: Int
    
    static let defaultConfig = CompressionConfig(
        videoBitrate: 1024 * 750,
        videomaxKeyFrameInterval: 30,
        avVideoProfileLevel: AVVideoProfileLevelH264High41,
        audioSampleRate: 22050,
        audioBitrate: 80000
    )
    
    static func defaultConfig(with bitrate: Int, fps: Int) -> CompressionConfig {
        CompressionConfig(
            videoBitrate: bitrate,
            videomaxKeyFrameInterval: fps,
            avVideoProfileLevel: AVVideoProfileLevelH264High41,
            audioSampleRate: 22050,
            audioBitrate: 80000
        )
    }
}

// Video Size
typealias CompressionSize = (width: Int, height: Int)

extension CGSize {
    fileprivate func toCompressionSize() -> CompressionSize {
        return (abs(Int(self.width)), abs(Int(self.height)))
    }
}

// Compression Result
enum CompressionResult {
    case success(URL)
    case failure(Error)
    case cancelled
}

// Compression with improved completion
func compressh264Video(
    videoToCompress: URL,
    destinationPath: URL,
    size: CGSize? = nil,
    timeRange: CMTimeRange? = nil,
    compressionTransform: CompressionTransform,
    compressionConfig: CompressionConfig,
    progressHandler: ((Progress) -> Void)? = nil,
    completion: @escaping (CompressionResult)->()
) -> CancelableCompression {
    compressh264Video(
        videoToCompress: videoToCompress,
        destinationPath: destinationPath,
        size: size?.toCompressionSize(),
        timeRange: timeRange,
        compressionTransform: compressionTransform,
        compressionConfig: compressionConfig,
        progressQueue: .main,
        progressHandler: { progress in
            progressHandler?(progress)
        },
        completionHandler: { url in
            completion(.success(url))
        },
        errorHandler: { error in
            completion(.failure(error))
        },
        cancelHandler: {
            completion(.cancelled)
        }
    )
}

// Compression Operation
func compressh264Video(
    videoToCompress: URL,
    destinationPath: URL,
    size: CompressionSize?,
    timeRange: CMTimeRange?,
    compressionTransform: CompressionTransform,
    compressionConfig: CompressionConfig,
    progressQueue: DispatchQueue,
    progressHandler: @escaping (Progress) -> Void,
    completionHandler: @escaping (URL) -> Void,
    errorHandler: @escaping (Error) -> Void,
    cancelHandler: @escaping () -> Void
) -> CancelableCompression {
    
    // Globals to store during compression
    class CompressionContext {
        var cgContext: CGContext?
        var pxbuffer: CVPixelBuffer?
        let colorSpace = CGColorSpaceCreateDeviceRGB()
    }
    
    // Draw Single Video Frame in Memory (will be used to loop for each video frame)
    func getCVPixelBuffer(_ i: CGImage?, compressionContext: CompressionContext) -> CVPixelBuffer? {
        // Allocate Temporary Pixel Buffer to Store Drawn Image
        weak var image = i!
        let imageWidth = image!.width
        let imageHeight = image!.height
        
        let attributes: [AnyHashable: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true as AnyObject,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true as AnyObject
        ]
        
        if compressionContext.pxbuffer == nil {
            CVPixelBufferCreate(
                kCFAllocatorSystemDefault,
                imageWidth,
                imageHeight,
                kCVPixelFormatType_32ARGB,
                attributes as CFDictionary?,
                &compressionContext.pxbuffer
            )
        }
        
        // Draw Frame to Newly Allocated Buffer
        if let _pxbuffer = compressionContext.pxbuffer {
            let flags = CVPixelBufferLockFlags(rawValue: 0)
            CVPixelBufferLockBaseAddress(_pxbuffer, flags)
            let pxdata = CVPixelBufferGetBaseAddress(_pxbuffer)
            
            if compressionContext.cgContext == nil {
                compressionContext.cgContext = CGContext(
                    data: pxdata,
                    width: imageWidth,
                    height: imageHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(_pxbuffer),
                    space: compressionContext.colorSpace,
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                )
            }
            
            if let _context = compressionContext.cgContext, let image = image {
                _context.draw(image, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            } else {
                CVPixelBufferUnlockBaseAddress(_pxbuffer, flags);
                return nil
            }
            
            CVPixelBufferUnlockBaseAddress(_pxbuffer, flags);
            return _pxbuffer;
        }
        
        return nil
    }
    
    // EXIF Orientation fix for Videos (from camera)
    func getExifOrientationFix(for orientation: UIImage.Orientation) -> Int32 {
        let fixOrientation = CGImagePropertyOrientation(orientation).fixOrientation
        //print("[I] !!! fix orientation: \(fixOrientation.textCase)")
        return Int32(fixOrientation.rawValue)
//        switch orientation {
//        case .up: return 6
//        case .down: return 8
//        case .left: return 3
//        case .right: return 1
//        case .upMirrored: return 2
//        case .downMirrored: return 4
//        case .leftMirrored: return 5
//        case .rightMirrored: return 7
//        @unknown default: return 1
//        }
    }
    
    // Asset, Output File
    let avAsset = AVURLAsset(url: videoToCompress)
    let filePath = destinationPath

    do {
        // Reader and Writer
        let writer = try AVAssetWriter(outputURL: filePath, fileType: AVFileType.mp4)
        let reader = try AVAssetReader(asset: avAsset)
        
        // Tracks
        let videoTrack = avAsset.tracks(withMediaType: AVMediaType.video).first!
        let audioTrack = avAsset.tracks(withMediaType: AVMediaType.audio).first!
        
        // Video Output Configuration
        let videoCompressionProps: Dictionary<String, Any> = [
            AVVideoAverageBitRateKey: compressionConfig.videoBitrate,
            AVVideoMaxKeyFrameIntervalKey: compressionConfig.videomaxKeyFrameInterval,
            AVVideoProfileLevelKey: compressionConfig.avVideoProfileLevel
        ]
        
        let videoOutputSettings: Dictionary<String, Any> = [
            AVVideoWidthKey: size == nil ? videoTrack.naturalSize.width : size!.width,
            AVVideoHeightKey: size == nil ? videoTrack.naturalSize.height : size!.height,
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoCompressionPropertiesKey: videoCompressionProps
        ]
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        let sourcePixelBufferAttributesDictionary: Dictionary<String, Any> = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32RGBA),
            String(kCVPixelFormatOpenGLESCompatibility): kCFBooleanTrue!
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        
        videoInput.performsMultiPassEncodingIfSupported = true
        guard writer.canAdd(videoInput) else {
            errorHandler(CompressionError(title: "Cannot add video input"))
            return CancelableCompression()
        }
        writer.add(videoInput)
        
        // Audio Output Configuration
        var acl = AudioChannelLayout()
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        acl.mChannelBitmap = AudioChannelBitmap(rawValue: UInt32(0))
        acl.mNumberChannelDescriptions = UInt32(0)
        
        let acll = MemoryLayout<AudioChannelLayout>.size
        let audioOutputSettings: Dictionary<String, Any> = [
            AVFormatIDKey: UInt(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey: UInt(2),
            AVSampleRateKey: compressionConfig.audioSampleRate,
            AVEncoderBitRateKey: compressionConfig.audioBitrate,
            AVChannelLayoutKey: NSData(bytes:&acl, length: acll)
        ]
        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
        audioInput.expectsMediaDataInRealTime = false
        
        guard writer.canAdd(audioInput) else {
            errorHandler(CompressionError(title: "Cannot add audio input"))
            return CancelableCompression()
        }
        writer.add(audioInput)
        
        // Video Input Configuration
        let videoOptions: Dictionary<String, Any> = [
            kCVPixelBufferPixelFormatTypeKey as String: UInt(kCVPixelFormatType_422YpCbCr8_yuvs),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let readerVideoTrackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoOptions)
        
        readerVideoTrackOutput.alwaysCopiesSampleData = true
        
        guard reader.canAdd(readerVideoTrackOutput) else {
            errorHandler(CompressionError(title: "Cannot add video output"))
            return CancelableCompression()
        }
        reader.add(readerVideoTrackOutput)
        
        // Audio Input Configuration
        let decompressionAudioSettings: Dictionary<String, Any> = [
            AVFormatIDKey: UInt(kAudioFormatLinearPCM)
        ]
        let readerAudioTrackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: decompressionAudioSettings)
        
        readerAudioTrackOutput.alwaysCopiesSampleData = true
        
        guard reader.canAdd(readerAudioTrackOutput) else {
            errorHandler(CompressionError(title: "Cannot add audio output"))
            return CancelableCompression()
        }
        reader.add(readerAudioTrackOutput)
        
//        // Orientation Fix for Videos Taken by Device Camera
//        var appliedTransform: CGAffineTransform
//        switch compressionTransform {
//        case .useOriginal:
//            // Reset to original
//            appliedTransform = CGAffineTransform.identity
//
//        case .fixFromCamera:
//            // We fix camera with another approach, so anything here
//            appliedTransform = CGAffineTransform.identity
//
//        case .custom(let transform):
//            // Will apply custom transform
//            appliedTransform = CGAffineTransform.identity//transform
//            videoInput.transform = transform // Not good on server
//        }
        
        // Orientation Fix for Videos Taken by Device Camera
        let orientationInt = getExifOrientationFix(for: avAsset.orientation)
        
        // Check duration for valid input
        let start: CMTime = timeRange?.start ?? .zero
        let duration: CMTime = timeRange?.duration ?? avAsset.duration
        let safeRange = CMTimeRangeMake(start: max(start, CMTime.zero),
                                        duration: min(duration, avAsset.duration))
        guard safeRange.duration.seconds > 0 else {
            errorHandler(CompressionError(title: "Cannot compress video with zero time range duration"))
            return CancelableCompression()
        }
        
        // Begin Compression
        reader.timeRange = safeRange
        writer.shouldOptimizeForNetworkUse = true
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: safeRange.start)
        
        // Compress in Background
        let cancelable = CancelableCompression()
        compressQueue.async {
            // Allocate OpenGL Context to Draw and Transform Video Frames
            let glContext = EAGLContext(api: .openGLES2)!
            let context = CIContext(eaglContext: glContext)
            let compressionContext = CompressionContext()
            
            // Loop Video Frames
            var frameCount = 0
            var videoDone = false
            var audioDone = false
            
            // Total Frames
            let durationInSeconds = safeRange.duration.seconds
            let frameRate = videoTrack.nominalFrameRate
            let totalFrames = ceil(durationInSeconds * Double(frameRate))
            
            // Progress
            let totalUnits = Int64(totalFrames)
            let progress = Progress(totalUnitCount: totalUnits)
            
            while !videoDone || !audioDone {
                // Check for Writer Errors (out of storage etc.)
                if writer.status == AVAssetWriter.Status.failed {
                    reader.cancelReading()
                    writer.cancelWriting()
                    compressionContext.pxbuffer = nil
                    compressionContext.cgContext = nil
                    
                    if let e = writer.error {
                        errorHandler(e)
                        return
                    }
                }
                
                // Check for Reader Errors (source file corruption etc.)
                if reader.status == AVAssetReader.Status.failed {
                    reader.cancelReading()
                    writer.cancelWriting()
                    compressionContext.pxbuffer = nil
                    compressionContext.cgContext = nil
                    
                    if let e = reader.error {
                        errorHandler(e)
                        return
                    }
                }
                
                // Check for Cancel
                if cancelable.cancel {
                    reader.cancelReading()
                    writer.cancelWriting()
                    compressionContext.pxbuffer = nil
                    compressionContext.cgContext = nil
                    cancelHandler()
                    return
                }
                
                // Check if enough data is ready for encoding a single frame
                if videoInput.isReadyForMoreMediaData {
                    // Copy a single frame from source to destination with applied transforms
                    if let vBuffer = readerVideoTrackOutput.copyNextSampleBuffer(), CMSampleBufferDataIsReady(vBuffer) {
                        frameCount += 1
                        
                        // Update progress
                        progress.completedUnitCount = Int64(frameCount)
                        progressQueue.async { progressHandler(progress) }
                        
                        autoreleasepool {
                            let presentationTime = CMSampleBufferGetPresentationTimeStamp(vBuffer)
                            let pixelBuffer = CMSampleBufferGetImageBuffer(vBuffer)!
                            
                            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue:0))
                            
                            // Apply transform
                            var frameBuffer: CVPixelBuffer?
                            switch compressionTransform {
                            case .useOriginal:
                                // Use 'identity' transform
                                let transformedFrame = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: .identity)
                                let frameImage = context.createCGImage(transformedFrame, from: transformedFrame.extent)
                                frameBuffer = getCVPixelBuffer(frameImage, compressionContext: compressionContext)
                                
                            case .fixFromCamera:
                                // Fix videos from camera if needed
                                let transformedFrame = CIImage(cvPixelBuffer: pixelBuffer)
                                    .oriented(forExifOrientation: orientationInt)
                                let frameImage = context.createCGImage(transformedFrame, from: transformedFrame.extent)
                                frameBuffer = getCVPixelBuffer(frameImage, compressionContext: compressionContext)
                                
                            case .custom(let transform):
                                // Apply custom transform
                                let transformedFrame = CIImage(cvPixelBuffer: pixelBuffer)
                                    .transformed(by: transform)
                                let frameImage = context.createCGImage(transformedFrame, from: transformedFrame.extent)
                                frameBuffer = getCVPixelBuffer(frameImage, compressionContext: compressionContext)
                                
                            case .fixFromCameraAndCustom(let transform):
                                // Fix videos from camera if needed
                                // and then apply custom transform
                                let transformedFrame = CIImage(cvPixelBuffer: pixelBuffer)
                                    .oriented(forExifOrientation: orientationInt)
                                    .transformed(by: transform)
                                let frameImage = context.createCGImage(transformedFrame, from: transformedFrame.extent)
                                frameBuffer = getCVPixelBuffer(frameImage, compressionContext: compressionContext)
                            }
                            
                            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                            
                            _ = pixelBufferAdaptor.append(frameBuffer!, withPresentationTime: presentationTime)
                        }
                    } else {
                        // Video source is depleted, mark as finished
                        if !videoDone {
                            videoInput.markAsFinished()
                        }
                        videoDone = true
                    }
                }
                
                if audioInput.isReadyForMoreMediaData {
                    // Copy a single audio sample from source to destination
                    if let aBuffer = readerAudioTrackOutput.copyNextSampleBuffer(), CMSampleBufferDataIsReady(aBuffer) {
                        _ = audioInput.append(aBuffer)
                    } else {
                        // Audio source is depleted, mark as finished
                        if !audioDone {
                            audioInput.markAsFinished()
                        }
                        audioDone = true
                    }
                }
                
                // Let background thread rest for a while
                Thread.sleep(forTimeInterval: 0.001)
            }
            
            // Write everything to output file
            writer.finishWriting(completionHandler: {
                compressionContext.pxbuffer = nil
                compressionContext.cgContext = nil
                completionHandler(filePath)
            })
        }
        
        // Return a cancel wrapper for users to let them interrupt the compression
        return cancelable
    } catch {
        // Error During Reader or Writer Creation
        errorHandler(error)
        return CancelableCompression()
    }
}

extension AVAsset {
    fileprivate var orientation: UIImage.Orientation {
        var trackOrientation = UIImage.Orientation.up
        if let track = tracks(withMediaType: .video).first {
            let size = track.naturalSize
            let transform = track.preferredTransform
//            var log = "[I] size - w: \(size.width.rounded()) | h: \(size.height.rounded())"
//            log += "\n[I] preferred transform:"
//            log += "\n[I] a: \(transform.a.rounded()) | b: \(transform.b.rounded())"
//            log += "\n[I] c: \(transform.c.rounded()) | d: \(transform.d.rounded())"
//            log += "\n[I] tx: \(transform.tx.rounded()) | ty: \(transform.ty.rounded())"
//            print(log)
            if transform.tx == size.height && transform.ty == 0 {
                // up
                trackOrientation = .up
            } else if transform.tx == 0 && transform.ty == 0 && transform.a == 1 {
                // left
                trackOrientation = .left
            } else if transform.tx == size.width && transform.ty == size.height {
                // right
                trackOrientation = .right
            } else if transform.tx == 0 && transform.ty == size.width {
                // down
                trackOrientation = .down
            } else if transform.tx == 0 && transform.ty == 0 && transform.a == 0 {
                // mirrored up
                trackOrientation = .upMirrored
            } else if transform.tx == size.width && transform.ty == 0 {
                // mirrored left
                trackOrientation = .leftMirrored
            } else if transform.tx == 0 && transform.ty == size.height {
                // mirrored right
                trackOrientation = .rightMirrored
            } else if transform.tx == size.height && transform.ty == size.width {
                // mirrored down
                trackOrientation = .downMirrored
            } else {
                // What?!
                print("[I] strange transform: \(transform)")
            }
//            switch (transform.tx, transform.ty) {
//            case (0, 0): trackOrientation = .right
//            case (size.width, size.height): trackOrientation = .left
//            case (0, size.width): trackOrientation = .down
//            default: trackOrientation = .up
//            }
        }
        
        // transform
        // a -- b -- 0
        // c -- d -- 0
        // tx - ty - 1
        
        /*
         straight up
         [I] thumbnail orientation: up
         [I] size - w: 480.0 | h: 360.0
         [I] preferred transform:
         [I] a: 0.0 | b: 1.0
         [I] c: -1.0 | d: 0.0
         [I] tx: 360.0 | ty: 0.0
         [I] ! track transform orientation: up
         [I] !!! fix orientation: down
         
         to left
         [I] thumbnail orientation: up
         [I] size - w: 480.0 | h: 360.0
         [I] preferred transform:
         [I] a: 1.0 | b: 0.0
         [I] c: 0.0 | d: 1.0
         [I] tx: 0.0 | ty: 0.0
         [I] ! track transform orientation: right
         [I] !!! fix orientation: up
         
         to right
         [I] thumbnail orientation: up
         [I] size - w: 480.0 | h: 360.0
         [I] preferred transform:
         [I] a: -1.0 | b: 0.0
         [I] c: 0.0 | d: -1.0
         [I] tx: 480.0 | ty: 360.0
         [I] ! track transform orientation: left
         [I] !!! fix orientation: up
         
         upside-down
         [I] thumbnail orientation: up
         [I] size - w: 480.0 | h: 360.0
         [I] preferred transform:
         [I] a: 0.0 | b: -1.0
         [I] c: 1.0 | d: 0.0
         [I] tx: 0.0 | ty: 480.0
         [I] ! track transform orientation: down
         [I] !!! fix orientation: down
         */
        
        /*
         mirrored up
         [I] thumbnail orientation: up
         [I] size - w: 1280.0 | h: 720.0
         [I] preferred transform:
         [I] a: 0.0 | b: 1.0
         [I] c: 1.0 | d: 0.0
         [I] tx: 0.0 | ty: 0.0
         [I] ! track transform orientation: right
         [I] !!! fix orientation: up
         
         mirrored to left
         [I] thumbnail orientation: up
         [I] size - w: 1280.0 | h: 720.0
         [I] preferred transform:
         [I] a: -1.0 | b: 0.0
         [I] c: 0.0 | d: 1.0
         [I] tx: 1280.0 | ty: 0.0
         [I] ! track transform orientation: up
         [I] !!! fix orientation: down
         
         mirrored to right
         [I] thumbnail orientation: up
         [I] size - w: 1280.0 | h: 720.0
         [I] preferred transform:
         [I] a: 1.0 | b: 0.0
         [I] c: 0.0 | d: -1.0
         [I] tx: 0.0 | ty: 720.0
         [I] ! track transform orientation: up
         [I] !!! fix orientation: down
         
         mirrored upside-down
         [I] thumbnail orientation: up
         [I] size - w: 1280.0 | h: 720.0
         [I] preferred transform:
         [I] a: 0.0 | b: -1.0
         [I] c: -1.0 | d: 0.0
         [I] tx: 720.0 | ty: 1280.0
         [I] ! track transform orientation: up
         [I] !!! fix orientation: down
         */
        
        // print("[I] ! track transform orientation: \(trackOrientation.textCase)")
        return trackOrientation
    }
}

extension UIImage.Orientation {
    init(_ cgOrientation: CGImagePropertyOrientation) {
        switch cgOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        }
    }
    var textCase: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        case .upMirrored: return "up mirrored"
        case .downMirrored: return "down mirrored"
        case .leftMirrored: return "left mirrored"
        case .rightMirrored: return "right mirrored"
        @unknown default: return "unknown"
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .right
        }
    }
    var textCase: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        case .upMirrored: return "up mirrored"
        case .downMirrored: return "down mirrored"
        case .leftMirrored: return "left mirrored"
        case .rightMirrored: return "right mirrored"
        }
    }
    var fixOrientation: CGImagePropertyOrientation {
        switch self {
            // From camera/gallery (back/front cameras)
            // Tested - all OK
        case .up: return .down
        case .down: return .down
        case .left: return .up
        case .right: return .up
            // When mirrored from gallery (as no system editing)
            // Tested - all OK
        case .upMirrored: return .down
        case .downMirrored: return .down
        case .leftMirrored: return .up
        case .rightMirrored: return .up
        }
    }
}
