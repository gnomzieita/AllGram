//
//  ImagePruningModel.swift
//  AllGram
//
//  Created by Wladislaw Derevianko on 09.01.2022.
//

import Foundation
import Combine
import UIKit
import MatrixSDK

enum UploadProgressEnum {
    case notStarted, uploadingImage, changingAvatarUrl, done
    case error(NSError?)
    
    func isStarted() -> Bool {
        if case .notStarted = self { return false }
        return true
    }
    func isBusy() -> Bool {
        switch self {
        case .uploadingImage, .changingAvatarUrl: return true
        default: return false
        }
    }
}


class ImagePruningModel : ObservableObject {
    static var shared = ImagePruningModel()
    
    private init() { }
    func resetModel() {
        scale = 1; offset = .zero;
        uploadingProgress = .notStarted
    }
    
	@Published var scale = CGFloat(1)
	@Published var offset = CGSize.zero
    @Published var uploadingProgress = UploadProgressEnum.notStarted
    
	private var radius = CGFloat(0)
	private var areaSize = CGSize.zero
	private var rawImageSize = CGSize.zero
	private var scale0 = CGFloat(1)
	private var offset0 = CGSize.zero

	func holeRadius(in size: CGSize) -> CGFloat {
		let minSide = min(size.width, size.height)
		let r = round(0.45 * minSide)
		radius = r // save for future use by gestures
		return r
	}
	
	func currentImageSize(in size: CGSize, rawImgSize: CGSize?) -> CGSize {
		areaSize = size
		self.rawImageSize = rawImgSize ?? .zero
		return calculateImageSize(forScale: scale)
	}
	
	func adjustScale(multiplier: CGFloat) {
		let newScale = scale0 * multiplier
		if newScale > 6 {
			// do not allow too much magnification
			return
		}
		let relativeScale = newScale / scale
		let dx = offset.width * relativeScale
		let dy = offset.height * relativeScale
		
		let limits = offsetLimits(scale: newScale)
		if abs(dx) <= limits.width && abs(dy) <= limits.height {
			scale = newScale
			offset = CGSize(width: dx, height: dy)
		} else if relativeScale < 1 && limits.width >= 0 && limits.height >= 0 {
			// calculate
			let biggerScale = scaleUpToBump()
			
			if biggerScale > scale {
				let relScale = biggerScale / scale
				let dx = offset.width * relScale
				let dy = offset.height * relScale
				scale = biggerScale
				offset = CGSize(width: dx, height: dy)
			}
			
		}
	}
	func resetScaling() {
		scale0 = scale
	}
	
	func adjustOffset(translation: CGSize) {
		var dx = offset0.width + translation.width
		var dy = offset0.height + translation.height
		
		let limits = offsetLimits(scale: self.scale)
		if abs(dx) > limits.width {
			if limits.width < 0 {
				dx = offset.width
			} else if dx > 0 {
				dx = limits.width
			} else {
				dx = -limits.width
			}
		}
		if abs(dy) > limits.height {
			if limits.height < 0 {
				dy = offset.height
			} else if dy > 0 {
				dy = limits.height
			} else {
				dy = -limits.height
			}
		}
		if dx != offset.width || dy != offset.height {
			offset = CGSize(width: dx, height: dy)
		}
	}
	func resetTranslation() {
		offset0 = offset
	}
    
    func uploadScaledImage(image: UIImage?, session: MXSession) {
//        guard let data = cropAndScale(image: image)?.jpegData(compressionQuality: 0.6) else {
        
        guard let data = image?.jpegData(compressionQuality: 0.6) else {

            return
        }
        uploadingProgress = .uploadingImage
     
        let uploader = MXMediaManager.prepareUploader(withMatrixSession: session, initialRange: 0, andRange: 1)
        uploader?.uploadData(data, filename: nil, mimeType: "image/jpeg", success: { [weak self]  urlString in
            guard let self = self else { return }
            self.uploadingProgress = .changingAvatarUrl

            session.myUser.setAvatarUrl(urlString) { [weak self] in
                self?.uploadingProgress = .done
            } failure: { [weak self] error in
                self?.uploadingProgress = .error(error as NSError?)
            }

        }, failure: { [weak self] error in
            self?.uploadingProgress = .error(error as NSError?)
        })
    }
	
	func cropAndScale(image: UIImage?) -> UIImage? {
        guard let image = image, let cgImage = image.cgImage else { return nil }
		let visibleImgSize = calculateImageSize(forScale: self.scale)
        let visibleWidth = visibleImgSize.width
        
        // note that Y-coordinate is flipped (SwiftUI - downward, CGContext - upward)
        let visibleX = max(0.5 * visibleWidth + offset.width - radius, 0)
        let visibleY = max(0.5 * visibleImgSize.height - offset.height - radius, 0)
        
		let rawSide = 2 * radius * rawImageSize.width / visibleWidth
		let kPixelSizeLimit = CGFloat(300)
		let pixelSide = min(rawSide * UIScreen.main.scale, kPixelSizeLimit)
        
        let scaleToPixels = pixelSide / (2 * radius)
		let dx = visibleX * scaleToPixels
        let dy = visibleY * scaleToPixels
        let rectInPixels = CGRect(x: -dx, y: -dy,
                                  width: visibleWidth * scaleToPixels,
                                  height: visibleImgSize.height * scaleToPixels)
        
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.opaque = true
        // the avatar will be uploaded to server in fixed pixels, same for all devices
        // ignoring screen resolution of particular device
        rendererFormat.scale = 1
        rendererFormat.preferredRange = .standard
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: pixelSide, height: pixelSide),
                                               format: rendererFormat)
        
        let croppedImage = renderer.image { graphicsContext in
            let transform : CGAffineTransform
            switch image.imageOrientation {
            case .up:
                transform = .identity
            case .down:
                transform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: pixelSide, ty: pixelSide)
            case .downMirrored:
                transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: pixelSide)
            case .left:
                transform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: pixelSide, ty: 0)
            case .right:
                transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: pixelSide)
            case .upMirrored:
                transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: pixelSide, ty: 0)
            case .leftMirrored:
                transform = CGAffineTransform(a: 0, b: 1, c: 0, d: -1, tx: 0, ty: pixelSide)
            case .rightMirrored:
                transform = CGAffineTransform(a: 0, b: 1, c: 0, d: -1, tx: 0, ty: pixelSide)
            @unknown default:
                transform = .identity
                break
                //fatalError()
            }
            
            let ctx = graphicsContext.cgContext
            ctx.concatenate(transform)
            ctx.draw(cgImage, in: rectInPixels.applying(transform.inverted()))
        }
        
		return croppedImage
	}
}

private extension ImagePruningModel {
	
	func calculateImageSize(forScale k: CGFloat) -> CGSize {
		if rawImageSize.width < 1 || rawImageSize.height < 1 { return .zero }
		let aw = areaSize.width / rawImageSize.width
		let ah = areaSize.height / rawImageSize.height
		let coef = k * min(aw, ah)
		return CGSize(width: coef * rawImageSize.width, height: coef * rawImageSize.height)
	}
	
	func offsetLimits(scale k: CGFloat) -> CGSize {
		let imageSize = calculateImageSize(forScale: k)
		let maxX = imageSize.width * 0.5 - radius
		let maxY = imageSize.height * 0.5 - radius
		return CGSize(width: maxX, height: maxY)
	}
	
	func checkTheCircleIsInsideImage(dx: CGFloat, dy: CGFloat, k: CGFloat) -> Bool {
		let imageSize = calculateImageSize(forScale: k)
		let minDistanceToCenterX = imageSize.width * 0.5 - abs(dx)
		if minDistanceToCenterX < radius {
			if k != scale || (dx * (dx - offset.width)) > 0 {
				return false
			}
		}
		let minDistanceToCenterY = imageSize.height * 0.5 - abs(dy)
		if minDistanceToCenterY < radius {
			if k != scale || (dy * (dy - offset.height)) > 0 {
				return false
			}
		}
		return true
	}
	
	// returns the new scale
	func scaleUpToBump() -> CGFloat {
		let sz = calculateImageSize(forScale: self.scale)
		let minX = sz.width * 0.5 - abs(offset.width)
		let minY = sz.height * 0.5 - abs(offset.height)
		let m = min(minX, minY)
		if m > 0 {
			return scale * radius / m
		} else {
			return scale
		}
	}
}
