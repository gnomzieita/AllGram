//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import AddressBook
import DTCoreText
//import libPhoneNumber_iOS
import MatrixSDK
import UIKit

let MXKTOOLS_LARGE_IMAGE_SIZE = 1024
let MXKTOOLS_MEDIUM_IMAGE_SIZE = 768
let MXKTOOLS_SMALL_IMAGE_SIZE = 512

let MXKTOOLS_USER_IDENTIFIER_BITWISE = 0x01
let MXKTOOLS_ROOM_IDENTIFIER_BITWISE = 0x02
let MXKTOOLS_ROOM_ALIAS_BITWISE = 0x04
let MXKTOOLS_EVENT_IDENTIFIER_BITWISE = 0x08
let MXKTOOLS_GROUP_IDENTIFIER_BITWISE = 0x10

// Attribute in an NSAttributeString that marks a blockquote block that was in the original HTML string.
/// Structure representing an the size of an image and its file size.
typealias MXKImageCompressionSize = (imageSize: CGSize, fileSize: Int)
/// Structure representing the sizes of image (image size and file size) according to
/// different level of compression.
typealias MXKImageCompressionSizes = (small: MXKImageCompressionSize, medium: MXKImageCompressionSize, large: MXKImageCompressionSize, original: MXKImageCompressionSize, actualLargeSize: CGFloat)
// MARK: - Constants definitions

// Temporary background color used to identify blockquote blocks with DTCoreText.
let kMXKToolsBlockquoteMarkColor = UIColor.magenta

// Attribute in an NSAttributeString that marks a blockquote block that was in the original HTML string.
let kMXKToolsBlockquoteMarkAttribute = "kMXKToolsBlockquoteMarkAttribute"
// MARK: - Tools static private members
// The regex used to find matrix ids.
private var userIdRegex: NSRegularExpression?
private var roomIdRegex: NSRegularExpression?
private var roomAliasRegex: NSRegularExpression?
private var eventIdRegex: NSRegularExpression?
private var groupIdRegex: NSRegularExpression?
// A regex to find http URLs.
private var httpLinksRegex: NSRegularExpression?
// A regex to find all HTML tags
private var htmlTagsRegex: NSRegularExpression?

var backgroundByImageNameDict: [AnyHashable : Any]?

class Tools: NSObject {
    override init() {
        // TODO: [Swiftify] ensure that the code below is executed only once (`dispatch_once()` is deprecated)
        do {
            userIdRegex = try NSRegularExpression(pattern: kMXToolsRegexStringForMatrixUserIdentifier, options: .caseInsensitive)
        } catch {
        }
        do {
            roomIdRegex = try NSRegularExpression(pattern: kMXToolsRegexStringForMatrixRoomIdentifier, options: .caseInsensitive)
        } catch {
        }
        do {
            roomAliasRegex = try NSRegularExpression(pattern: kMXToolsRegexStringForMatrixRoomAlias, options: .caseInsensitive)
        } catch {
        }
        do {
            eventIdRegex = try NSRegularExpression(pattern: kMXToolsRegexStringForMatrixEventIdentifier, options: .caseInsensitive)
        } catch {
        }
        do {
            groupIdRegex = try NSRegularExpression(pattern: kMXToolsRegexStringForMatrixGroupIdentifier, options: .caseInsensitive)
        } catch {
        }
        
        do {
            httpLinksRegex = try NSRegularExpression(pattern: "(?i)\\b(https?://.*)\\b", options: .caseInsensitive)
        } catch {
        }
        do {
            htmlTagsRegex = try NSRegularExpression(pattern: "<(\\w+)[^>]*>", options: .caseInsensitive)
        } catch {
        }
    }

    // MARK: - Strings

    /// Determine if a string contains one emoji and only one.
    /// - Parameter string: the string to check.
    /// - Returns: YES if YES.

    // MARK: - Strings

    class func isSingleEmojiString(_ string: String?) -> Bool {
        return Tools.isEmojiString(string, singleEmoji: true)
    }

    /// Determine if a string contains only emojis.
    /// - Parameter string: the string to check.
    /// - Returns: YES if YES.
    class func isEmojiOnlyString(_ string: String?) -> Bool {
        return Tools.isEmojiString(string, singleEmoji: false)
    }

    // Highly inspired from https://stackoverflow.com/a/34659249
    class func isEmojiString(_ string: String?, singleEmoji: Bool) -> Bool {
        if (string?.count ?? 0) == 0 {
            return false
        }

        var result = true

        let stringRange = NSRange(location: 0, length: string?.count ?? 0)

        (string as NSString?)?.enumerateSubstrings(in: stringRange, options: .byComposedCharacterSequences, using: { substring, substringRange, enclosingRange, stop in
            var isEmoji = false

            if singleEmoji && !NSEqualRanges(stringRange, substringRange) {
                // The string contains several characters. Go out
                result = false
                stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
                return
            }

            let hs = unichar(substring?[substring?.index(substring?.startIndex, offsetBy: 0)])
            // Surrogate pair
            if 0xd800 <= hs && hs <= 0xdbff {
                if (substring?.count ?? 0) > 1 {
                    let ls = unichar(substring?[substring?.index(substring?.startIndex, offsetBy: 1) ?? <#default value#>] ?? 0)
                    let uc = (Int((hs - 0xd800)) * 0x400) + Int((ls - 0xdc00)) + 0x10000
                    if 0x1d000 <= uc && uc <= 0x1f9ff {
                        isEmoji = true
                    }
                }
            } else if (substring?.count ?? 0) > 1 {
                let ls = unichar(substring?[substring?.index(substring?.startIndex, offsetBy: 1)] ?? 0)
                if ls == 0x20e3 || ls == 0xfe0f || ls == 0xd83c {
                    isEmoji = true
                }
            } else {
                // Non surrogate
                if 0x2100 <= hs && hs <= 0x27ff {
                    isEmoji = true
                } else if 0x2b05 <= hs && hs <= 0x2b07 {
                    isEmoji = true
                } else if 0x2934 <= hs && hs <= 0x2935 {
                    isEmoji = true
                } else if 0x3297 <= hs && hs <= 0x3299 {
                    isEmoji = true
                } else if hs == 0xa9 || hs == 0xae || hs == 0x303d || hs == 0x3030 || hs == 0x2b55 || hs == 0x2b1c || hs == 0x2b1b || hs == 0x2b50 {
                    isEmoji = true
                }
            }

            if !isEmoji {
                result = false
                stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
            }
        })

        return result
    }

    // MARK: - Time

    /// Format time interval.
    /// ex: "5m 31s".
    /// - Parameter secondsInterval: time interval in seconds.
    /// - Returns: formatted string

    // MARK: - Time interval

    class func formatSecondsInterval(_ secondsInterval: CGFloat) -> String? {
        var formattedString = ""

        if secondsInterval < 1 {
            formattedString += "< 1s"
        } else if secondsInterval < 60 {
            formattedString += "\(Int(secondsInterval))s"
        } else if secondsInterval < 3600 {
            formattedString += String(format: "%d%@ %2d%@", Int(secondsInterval / 60), "m", (Int(secondsInterval)) % 60, "s")
        } else if secondsInterval >= 3600 {
            formattedString += "\(Int(secondsInterval / 3600))h \((Int(secondsInterval) % 3600) / 60)m \(Int(secondsInterval) % 60)s"
        }
        formattedString += " left"

        return formattedString
    }

    /// Format time interval but rounded to the nearest time unit below.
    /// ex: "5s", "1m", "2h" or "3d".
    /// - Parameter secondsInterval: time interval in seconds.
    /// - Returns: formatted string
    class func formatSecondsIntervalFloored(_ secondsInterval: CGFloat) -> String? {
        var formattedString: String?

        if secondsInterval < 0 {
            formattedString = "0s"
        } else {
            let seconds = Int(secondsInterval)
            if seconds < 60 {
                formattedString = String(format: "%tu%@", seconds, "s")
            } else if secondsInterval < 3600 {
                formattedString = String(format: "%tu%@", seconds / 60, "m")
            } else if secondsInterval < 86400 {
                formattedString = String(format: "%tu%@", seconds / 3600, "h")
            } else {
                formattedString = String(format: "%tu%@", seconds / 86400, "d")
            }
        }

        return formattedString
    }

    // MARK: - Phone number

    /// Return the number used to identify a mobile phone number internationally.
    /// The provided country code is ignored when the phone number is already internationalized, or when it
    /// is a valid msisdn.
    /// - Parameters:
    ///   - phoneNumber: the phone number.
    ///   - countryCode: the ISO 3166-1 country code representation (required when the phone number is in national format).
    /// - Returns: a valid msisdn or nil if the provided phone number is invalid.

    // MARK: - Phone number

    static func msisdn(withPhoneNumber phoneNumber: String?, andCountryCode countryCode: String?) -> String? {
        var msisdn: String? = nil
        var phoneNb: NBPhoneNumber?

        if phoneNumber?.hasPrefix("+") ?? false || phoneNumber?.hasPrefix("00") ?? false {
            do {
                phoneNb = try NBPhoneNumberUtil.sharedInstance().parse(phoneNumber, defaultRegion: nil)
            } catch {
            }
        } else {
            // Check whether the provided phone number is a valid msisdn.
            let e164 = "+\(phoneNumber ?? "")"
            do {
                phoneNb = try NBPhoneNumberUtil.sharedInstance().parse(e164, defaultRegion: nil)
            } catch {
            }

            if !NBPhoneNumberUtil.sharedInstance().isValidNumber(phoneNb) {
                // Consider the phone number as a national one, and use the country code.
                do {
                    phoneNb = try NBPhoneNumberUtil.sharedInstance().parse(phoneNumber, defaultRegion: countryCode)
                } catch {
                }
            }
        }

        if NBPhoneNumberUtil.sharedInstance().isValidNumber(phoneNb) {
            var e164: String? = nil
            do {
                e164 = try NBPhoneNumberUtil.sharedInstance().format(phoneNb, numberFormat: NBEPhoneNumberFormatE164)
            } catch {
            }

            if e164?.hasPrefix("+") ?? false {
                msisdn = (e164 as NSString?)?.substring(from: 1)
            } else if e164?.hasPrefix("00") ?? false {
                msisdn = (e164 as NSString?)?.substring(from: 2)
            }
        }

        return msisdn
    }

    /// Format an MSISDN to a human readable international phone number.
    /// - Parameter msisdn: The MSISDN to format.
    /// - Returns: Human readable international phone number.
    static func readableMSISDN(_ msisdn: String?) -> String? {
        var e164: String?

        if (e164?.hasPrefix("+")) ?? false {
            e164 = msisdn
        } else {
            e164 = "+\(msisdn ?? "")"
        }

        var phoneNb: NBPhoneNumber? = nil
        do {
            phoneNb = try NBPhoneNumberUtil.sharedInstance().parse(e164, defaultRegion: nil)
        } catch {
        }
        return try? NBPhoneNumberUtil.sharedInstance().format(phoneNb, numberFormat: NBEPhoneNumberFormatINTERNATIONAL)
    }

    // MARK: - Hex color to UIColor conversion

    /// Build a UIColor from an hexadecimal color value
    /// - Parameter rgbValue: the color expressed in hexa (0xRRGGBB)
    /// - Returns: the UIColor

    // MARK: - Hex color to UIColor conversion

    static func color(withRGBValue rgbValue: Int) -> UIColor? {
        return UIColor(red: CGFloat((Float((rgbValue & 0xff0000) >> 16)) / 255.0), green: CGFloat((Float((rgbValue & 0xff00) >> 8)) / 255.0), blue: CGFloat((Float(rgbValue & 0xff)) / 255.0), alpha: 1.0)
    }

    /// Build a UIColor from an hexadecimal color value with transparency
    /// - Parameter argbValue: the color expressed in hexa (0xAARRGGBB)
    /// - Returns: the UIColor
    static func color(withARGBValue argbValue: Int) -> UIColor? {
        return UIColor(red: CGFloat((Float((argbValue & 0xff0000) >> 16)) / 255.0), green: CGFloat((Float((argbValue & 0xff00) >> 8)) / 255.0), blue: CGFloat((Float(argbValue & 0xff)) / 255.0), alpha: CGFloat((Float((argbValue & 0xff000000) >> 24)) / 255.0))
    }

    /// Return an hexadecimal color value from UIColor
    /// - Parameter color: the UIColor
    /// - Returns: rgbValue the color expressed in hexa (0xRRGGBB)
    static func rgbValue(with color: UIColor?) -> Int {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat

        color?.getRed(UnsafeMutablePointer<CGFloat>(mutating: &red), green: UnsafeMutablePointer<CGFloat>(mutating: &green), blue: UnsafeMutablePointer<CGFloat>(mutating: &blue), alpha: UnsafeMutablePointer<CGFloat>(mutating: &alpha))

        let rgbValue = Int(CGFloat((Int(red * 255) << 16) + (Int(green * 255) << 8)) + (blue * 255))

        return rgbValue
    }

    /// Return an hexadecimal color value with transparency from UIColor
    /// - Parameter color: the UIColor
    /// - Returns: argbValue the color expressed in hexa (0xAARRGGBB)
    static func argbValue(with color: UIColor?) -> Int {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat

        color?.getRed(UnsafeMutablePointer<CGFloat>(mutating: &red), green: UnsafeMutablePointer<CGFloat>(mutating: &green), blue: UnsafeMutablePointer<CGFloat>(mutating: &blue), alpha: UnsafeMutablePointer<CGFloat>(mutating: &alpha))

        let argbValue = Int(CGFloat((Int(alpha * 255) << 24) + (Int(red * 255) << 16) + (Int(green * 255) << 8)) + (blue * 255))

        return argbValue
    }

    // MARK: - Image processing

    /// Force image orientation to up
    /// - Parameter imageSrc: the original image.
    /// - Returns: image with `UIImageOrientationUp` orientation.

    // MARK: - Image

    static func forceImageOrientationUp(_ imageSrc: UIImage?) -> UIImage? {
        if (imageSrc?.imageOrientation == .up) || imageSrc == nil {
            // Nothing to do
            return imageSrc
        }

        // Draw the entire image in a graphics context, respecting the image’s orientation setting
        UIGraphicsBeginImageContext(imageSrc?.size ?? CGSize.zero)
        imageSrc?.draw(at: CGPoint(x: 0, y: 0))
        let retImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return retImage
    }

    /// Return struct MXKImageCompressionSizes representing the available compression sizes for the image
    /// - Parameters:
    ///   - image: the image to get available sizes for
    ///   - originalFileSize: the size in bytes of the original image file or the image data (0 if this value is unknown).
    static func availableCompressionSizes(for image: UIImage?, originalFileSize: Int) -> MXKImageCompressionSizes {
        var compressionSizes: MXKImageCompressionSizes
        memset(&compressionSizes, 0, MemoryLayout<MXKImageCompressionSizes>.size)

        // Store the original
        compressionSizes.original.imageSize() = image?.size ?? CGSize.zero
        (compressionSizes.original[FileAttributeKey.size] as? UInt64 ?? 0) = UInt64(originalFileSize != 0 ? originalFileSize : (image?.jpegData(compressionQuality: 0.9)?.count ?? 0))

        print("[MXKTools] availableCompressionSizesForImage: %f %f - File size: %tu", compressionSizes.original.imageSize().width, compressionSizes.original.imageSize().height, (compressionSizes.original[FileAttributeKey.size] as? UInt64 ?? 0))

        compressionSizes.actualLargeSize = MXKTOOLS_LARGE_IMAGE_SIZE

        // Compute the file size for each compression level
        let maxSize = CGFloat(max(compressionSizes.original.imageSize().width, compressionSizes.original.imageSize().height))
        if maxSize >= CGFloat(MXKTOOLS_SMALL_IMAGE_SIZE) {
            compressionSizes.small.imageSize() = Tools.resizeImageSize(compressionSizes.original.imageSize(), toFitIn: CGSize(width: CGFloat(MXKTOOLS_SMALL_IMAGE_SIZE), height: CGFloat(MXKTOOLS_SMALL_IMAGE_SIZE)), canExpand: false)

            (compressionSizes.small[FileAttributeKey.size] as? UInt64 ?? 0) = UInt64(Int(MXTools.roundFileSize(Int64(compressionSizes.small.imageSize().width * compressionSizes.small.imageSize().height * 0.20))))

            if maxSize >= CGFloat(MXKTOOLS_MEDIUM_IMAGE_SIZE) {
                compressionSizes.medium.imageSize() = Tools.resizeImageSize(compressionSizes.original.imageSize(), toFitIn: CGSize(width: CGFloat(MXKTOOLS_MEDIUM_IMAGE_SIZE), height: CGFloat(MXKTOOLS_MEDIUM_IMAGE_SIZE)), canExpand: false)

                (compressionSizes.medium[FileAttributeKey.size] as? UInt64 ?? 0) = UInt64(Int(MXTools.roundFileSize(Int64(compressionSizes.medium.imageSize().width * compressionSizes.medium.imageSize().height * 0.20))))

                if maxSize >= CGFloat(MXKTOOLS_LARGE_IMAGE_SIZE) {
                    // In case of panorama the large resolution (1024 x ...) is not relevant. We prefer consider the third of the panarama width.
                    compressionSizes.actualLargeSize = maxSize / 3
                    if compressionSizes.actualLargeSize < MXKTOOLS_LARGE_IMAGE_SIZE {
                        compressionSizes.actualLargeSize = MXKTOOLS_LARGE_IMAGE_SIZE
                    } else {
                        // Keep a multiple of predefined large size
                        compressionSizes.actualLargeSize = floor(compressionSizes.actualLargeSize / MXKTOOLS_LARGE_IMAGE_SIZE) * MXKTOOLS_LARGE_IMAGE_SIZE
                    }

                    compressionSizes.large.imageSize() = Tools.resizeImageSize(compressionSizes.original.imageSize(), toFitIn: CGSize(width: compressionSizes.actualLargeSize, height: compressionSizes.actualLargeSize), canExpand: false)

                    (compressionSizes.large[FileAttributeKey.size] as? UInt64 ?? 0) = UInt64(Int(MXTools.roundFileSize(Int64(compressionSizes.large.imageSize().width * compressionSizes.large.imageSize().height * 0.20))))
                } else {
                    print("    - too small to fit in", MXKTOOLS_LARGE_IMAGE_SIZE)
                }
            } else {
                print("    - too small to fit in", MXKTOOLS_MEDIUM_IMAGE_SIZE)
            }
        } else {
            print("    - too small to fit in", MXKTOOLS_SMALL_IMAGE_SIZE)
        }

        return compressionSizes
    }

    /// Compute image size to fit in specific box size (in aspect fit mode)
    /// - Parameters:
    ///   - originalSize: the original size
    ///   - maxSize: the box size
    ///   - canExpand: tell whether the image can be expand or not
    /// - Returns: the resized size.
    class func resizeImageSize(_ originalSize: CGSize, toFitIn maxSize: CGSize, canExpand: Bool) -> CGSize {
        if (originalSize.width == 0) || (originalSize.height == 0) {
            return CGSize.zero
        }

        var resized = originalSize

        if (maxSize.width > 0) && (maxSize.height > 0) && (canExpand || ((originalSize.width > maxSize.width) || (originalSize.height > maxSize.height))) {
            let ratioX = maxSize.width / originalSize.width
            let ratioY = maxSize.height / originalSize.height

            let scale = CGFloat(min(ratioX, ratioY))
            resized.width *= scale
            resized.height *= scale

            // padding
            resized.width = CGFloat(floorf(Float(resized.width / 2)) * 2)
            resized.height = CGFloat(floorf(Float(resized.height / 2)) * 2)
        }

        return resized
    }

    /// Compute image size to fill specific box size (in aspect fill mode)
    /// - Parameters:
    ///   - originalSize: the original size
    ///   - maxSize: the box size
    ///   - canExpand: tell whether the image can be expand or not
    /// - Returns: the resized size.
    class func resizeImageSize(_ originalSize: CGSize, toFillWith maxSize: CGSize, canExpand: Bool) -> CGSize {
        var resized = originalSize

        if (maxSize.width > 0) && (maxSize.height > 0) && (canExpand || ((originalSize.width > maxSize.width) && (originalSize.height > maxSize.height))) {
            let ratioX = maxSize.width / originalSize.width
            let ratioY = maxSize.height / originalSize.height

            let scale = CGFloat(max(ratioX, ratioY))
            resized.width *= scale
            resized.height *= scale

            // padding
            resized.width = CGFloat(floorf(Float(resized.width / 2)) * 2)
            resized.height = CGFloat(floorf(Float(resized.height / 2)) * 2)
        }

        return resized
    }

    /// Reduce image to fit in the provided size.
    /// The aspect ratio is kept.
    /// If the image is smaller than the provided size, the image is not recomputed.
    /// - Remark: This method call `+ [reduceImage:toFitInSize:useMainScreenScale:]` with `useMainScreenScale` value to `NO`.
    /// - Parameters:
    ///   - image: the image to modify.
    ///   - size: to fit in.
    /// - Returns: resized image.
    /// - seealso: reduceImage:toFitInSize:useMainScreenScale:
    class func reduce(_ image: UIImage?, toFitIn size: CGSize) -> UIImage? {
        return self.reduce(image, toFitIn: size, useMainScreenScale: false)
    }

    /// Reduce image to fit in the provided size.
    /// The aspect ratio is kept.
    /// If the image is smaller than the provided size, the image is not recomputed.
    /// - Parameters:
    ///   - image: the image to modify.
    ///   - size: to fit in.
    ///   - useMainScreenScale: Indicate true to use main screen scale.
    /// - Returns: resized image.
    class func reduce(_ image: UIImage?, toFitIn size: CGSize, useMainScreenScale: Bool) -> UIImage? {
        var resizedImage: UIImage?

        // Check whether resize is required
        if size.width != 0.0 && size.height != 0.0 {
            var width = image?.size.width ?? 0.0
            var height = image?.size.height ?? 0.0

            if width > size.width {
                height = (height * size.width) / width
                height = CGFloat(floorf(Float(height / 2)) * 2)
                width = size.width
            }
            if height > size.height {
                width = (width * size.height) / height
                width = CGFloat(floorf(Float(width / 2)) * 2)
                height = size.height
            }

            if width != image?.size.width || height != image?.size.height {
                // Create the thumbnail
                let imageSize = CGSize(width: width, height: height)

                // Convert first the provided size in pixels

                // The scale factor is set to 0.0 to use the scale factor of the device’s main screen.
                let scale: CGFloat = useMainScreenScale ? 0.0 : 1.0

                UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)

                //            // set to the top quality
                //            CGContextRef context = UIGraphicsGetCurrentContext();
                //            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

                var thumbnailRect = CGRect(x: 0, y: 0, width: 0, height: 0)
                thumbnailRect.origin = CGPoint(x: 0.0, y: 0.0)
                thumbnailRect.size.width = imageSize.width
                thumbnailRect.size.height = imageSize.height

                image?.draw(in: thumbnailRect)
                resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
        } else {
            resizedImage = image
        }

        return resizedImage
    }

    /// Reduce image to fit in the provided size.
    /// The aspect ratio is kept.
    /// - Remark: This method use less memory than `+ [reduceImage:toFitInSize:useMainScreenScale:]`.
    /// - Parameters:
    ///   - imageData: The image data.
    ///   - size: Size to fit in.
    /// - Returns: Resized image or nil if the data is not interpreted.
    class func resizeImage(with imageData: Data?, toFitIn size: CGSize) -> UIImage? {
        // Create the image source
        var imageSource: CGImageSource? = nil
        if let data = imageData as CFData? {
            imageSource = CGImageSourceCreateWithData(data, nil)
        }

        // Take the max dimension of size to fit in
        let maxPixelSize = CGFloat(fmax(Float(size.width), Float(size.height)))

        //Create thumbnail options
        let options = [
            kCGImageSourceCreateThumbnailWithTransform: kCFBooleanTrue,
            kCGImageSourceCreateThumbnailFromImageAlways: kCFBooleanTrue,
            kCGImageSourceThumbnailMaxPixelSize: NSNumber(value: Float(maxPixelSize))
        ] as CFDictionary

        // Generate the thumbnail
        var resizedImageRef: CGImage? = nil
        if let imageSource = imageSource {
            resizedImageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)
        }

        var resizedImage: UIImage? = nil
        if let resizedImageRef = resizedImageRef {
            resizedImage = UIImage(cgImage: resizedImageRef)
        }

        CGImageRelease(resizedImageRef!)


        return resizedImage
    }

    /// Resize image to a provided size.
    /// - Parameters:
    ///   - image: the image to modify.
    ///   - size: the new size.
    /// - Returns: resized image.
    class func resize(_ image: UIImage?, to size: CGSize) -> UIImage? {
        var resizedImage = image

        // Check whether resize is required
        if size.width != 0.0 && size.height != 0.0 {
            // Convert first the provided size in pixels
            // The scale factor is set to 0.0 to use the scale factor of the device’s main screen.
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

            let context = UIGraphicsGetCurrentContext()
            CGContextSetInterpolationQuality(context, CGInterpolationQuality.high)

            image?.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext()

            UIGraphicsEndImageContext()
        }

        return resizedImage
    }

    /// Resize image with rounded corners to a provided size.
    /// - Parameters:
    ///   - image: the image to modify.
    ///   - size: the new size.
    /// - Returns: resized image.
    class func resizeImage(withRoundedCorners image: UIImage?, to size: CGSize) -> UIImage? {
        var resizedImage = image

        // Check whether resize is required
        if size.width != 0.0 && size.height != 0.0 {
            // Convert first the provided size in pixels
            // The scale factor is set to 0.0 to use the scale factor of the device’s main screen.
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

            let context = UIGraphicsGetCurrentContext()
            CGContextSetInterpolationQuality(context, CGInterpolationQuality.high)

            // Add a clip to round corners
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerRadius: size.width / 2).addClip()

            image?.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext()

            UIGraphicsEndImageContext()
        }

        return resizedImage
    }

    /// Paint an image with a color.
    /// - Remark:
    /// All non fully transparent (alpha = 0) will be painted with the provided color.
    /// - Parameters:
    ///   - image: the image to paint.
    ///   - color: the color to use.
    /// - Returns: a new UIImage object.
    class func paint(_ image: UIImage?, with color: UIColor?) -> UIImage? {
        var newImage: UIImage?

        let colorComponents = color?.cgColor.components

        // Create a new image with the same size
        UIGraphicsBeginImageContextWithOptions(image?.size ?? CGSize.zero, Bool(0), 0)

        let gc = UIGraphicsGetCurrentContext()

        let rect = CGRect(size: image?.size)

        image?.draw(
            in: rect,
            blendMode: .normal,
            alpha: 1)

        // Binarize the image: Transform all colors into the provided color but keep the alpha
        gc?.setBlendMode(.sourceIn)
        gc?.setFillColor(red: colorComponents?[0] ?? 0.0, green: colorComponents?[1] ?? 0.0, blue: colorComponents?[2] ?? 0.0, alpha: colorComponents?[3] ?? 0.0)
        gc?.fill(rect)

        // Retrieve the result into an UIImage
        newImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return newImage
    }

    /// Convert a rotation angle to the most suitable image orientation.
    /// - Parameter angle: rotation angle in degree.
    /// - Returns: image orientation.
    class func imageOrientationForRotationAngle(inDegree angle: Int) -> UIImage.Orientation {
        let modAngle = angle % 360

        let orientation: UIImage.Orientation = .up
        if 45 <= modAngle && modAngle < 135 {
            return .right
        } else if 135 <= modAngle && modAngle < 225 {
            return .down
        } else if 225 <= modAngle && modAngle < 315 {
            return .left
        }

        return orientation
    }

    /// Draw the image resource in a view and transforms it to a pattern color.
    /// The view size is defined by patternSize and will have a "backgroundColor" backgroundColor.
    /// The resource image is drawn with the resourceSize size and is centered into its parent view.
    /// - Parameters:
    ///   - reourceName: the image resource name.
    ///   - backgroundColor: the pattern background color.
    ///   - patternSize: the pattern size.
    ///   - resourceSize: the resource size in the pattern.
    /// - Returns: the pattern color which can be used to define the background color of a view in order to display the provided image as its background.
    class func convertImage(toPatternColor resourceName: String?, backgroundColor: UIColor?, patternSize: CGSize, resourceSize: CGSize) -> UIColor? {
        if resourceName == nil {
            return backgroundColor
        }

        if backgroundByImageNameDict == nil {
            backgroundByImageNameDict = [:]
        }

        let key = "\(resourceName ?? "") \(patternSize.width) \(resourceSize.width)"

        var bgColor = backgroundByImageNameDict?[key] as? UIColor

        if bgColor == nil {
            let backgroundView = UIImageView(frame: CGRect(x: 0, y: 0, width: patternSize.width, height: patternSize.height))
            backgroundView.backgroundColor = backgroundColor

            let offsetX = (patternSize.width - resourceSize.width) / 2.0
            let offsetY = (patternSize.height - resourceSize.height) / 2.0

            let resourceImageView = UIImageView(frame: CGRect(x: offsetX, y: offsetY, width: resourceSize.width, height: resourceSize.height))
            resourceImageView.backgroundColor = UIColor.clear
            let resImage = UIImage(named: resourceName ?? "")
            if resImage?.size.equalTo(resourceSize) ?? false {
                resourceImageView.image = resImage
            } else {
                resourceImageView.image = Tools.resize(resImage, to: resourceSize)
            }


            backgroundView.addSubview(resourceImageView)

            // Create a "canvas" (image context) to draw in.
            UIGraphicsBeginImageContextWithOptions(backgroundView.frame.size, false, 0)

            // set to the top quality
            let context = UIGraphicsGetCurrentContext()
            CGContextSetInterpolationQuality(context, CGInterpolationQuality.high)
            if let context1 = UIGraphicsGetCurrentContext() {
                backgroundView.layer.render(in: context1)
            }
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()


            if let image = image {
                bgColor = UIColor(patternImage: image)
            }
            backgroundByImageNameDict?[key] = bgColor
        }

        return bgColor
    }

    // MARK: - App permissions

    /// Check permission to access a media.
    /// - Remark:
    /// If the access was not yet granted, a dialog will be shown to the user.
    /// If it is the first attempt to access the media, the dialog is the classic iOS one.
    /// Else, the dialog will ask the user to manually change the permission in the app settings.
    /// - Parameters:
    ///   - mediaType: the media type, either AVMediaTypeVideo or AVMediaTypeAudio.
    ///   - manualChangeMessage: the message to display if the end user must change the app settings manually.
    ///   - viewController: the view controller to attach the dialog displaying manualChangeMessage.
    ///   - handler: the block called with the result of requesting access

    // MARK: - App permissions

    static func checkAccess(
        forMediaType mediaType: String?,
        manualChangeMessage: String?,
        showPopUpIn viewController: UIViewController?,
        completionHandler handler: @escaping (Bool) -> Void
    ) {
        AVCaptureDevice.requestAccess(for: AVMediaType(mediaType)) { granted in

            DispatchQueue.main.async(execute: {

                if granted {
                    handler(true)
                } else {
                    // Access not granted to mediaType
                    // Display manualChangeMessage
                    let alert = UIAlertController(title: nil, message: manualChangeMessage, preferredStyle: .alert)

                    // On iOS >= 8, add a shortcut to the app settings (This requires the shared application instance)
                    let sharedApplication = UIApplication.perform(#selector(UIApplication.shared)) as? UIApplication
                    if sharedApplication != nil && UIApplication.openSettingsURLString != "" {
                        alert.addAction(
                            UIAlertAction(
                                title: Bundle.mxk_localizedString(forKey: "settings"),
                                style: .default,
                                handler: { action in

                                    let url = URL(string: UIApplication.openSettingsURLString)
                                    sharedApplication?.perform(#selector(UIApplication.openURL(_:)), with: url)

                                    // Note: it does not worth to check if the user changes the permission
                                    // because iOS restarts the app in case of change of app privacy settings
                                    handler(false)

                                }))
                    }

                    alert.addAction(
                        UIAlertAction(
                            title: Bundle.mxk_localizedString(forKey: "ok"),
                            style: .default,
                            handler: { action in

                                handler(false)

                            }))

                    viewController?.present(alert, animated: true)
                }

            })
        }
    }

    /// Check required permission for the provided call.
    /// - Parameters:
    ///   - isVideoCall: flag set to YES in case of video call.
    ///   - manualChangeMessageForAudio: the message to display if the end user must change the app settings manually for audio.
    ///   - manualChangeMessageForVideo: the message to display if the end user must change the app settings manually for video
    ///   - viewController: the view controller to attach the dialog displaying manualChangeMessage.
    ///   - handler: the block called with the result of requesting access
    static func checkAccess(
        forCall isVideoCall: Bool,
        manualChangeMessageForAudio: String?,
        manualChangeMessageForVideo: String?,
        showPopUpIn viewController: UIViewController?,
        completionHandler handler: @escaping (_ granted: Bool) -> Void
    ) {
        // Check first microphone permission
        Tools.checkAccess(forMediaType: AVMediaType.audio, manualChangeMessage: manualChangeMessageForAudio, showPopUpIn: viewController) { granted in

            if granted {
                // Check camera permission in case of video call
                if isVideoCall {
                    MXKTools.checkAccess(forMediaType: AVMediaType.video, manualChangeMessage: manualChangeMessageForVideo, showPopUpIn: viewController) { granted in

                        handler(granted)
                    }
                } else {
                    handler(true)
                }
            } else {
                handler(false)
            }
        }
    }

    /// Check permission to access Contacts.
    /// - Remark:
    /// If the access was not yet granted, a dialog will be shown to the user.
    /// If it is the first attempt to access the media, the dialog is the classic iOS one.
    /// Else, the dialog will ask the user to manually change the permission in the app settings.
    /// - Parameters:
    ///   - manualChangeMessage: the message to display if the end user must change the app settings manually.
    /// If nil, the dialog for displaying manualChangeMessage will not be shown.
    ///   - viewController: the view controller to attach the dialog displaying manualChangeMessage.
    ///   - handler: the block called with the result of requesting access
    static func checkAccess(
        forContacts manualChangeMessage: String?,
        showPopUpIn viewController: UIViewController?,
        completionHandler handler: @escaping (_ granted: Bool) -> Void
    ) {
        // Check if the application is allowed to list the contacts
        let cbStatus = ABAddressBookGetAuthorizationStatus()
        if cbStatus == .authorized {
            handler(true)
        } else if cbStatus == .notDetermined {
            // Request address book access
            let ab = ABAddressBookCreateWithOptions(nil, nil) as? ABAddressBookRef
            if let ab = ab {
                ABAddressBookRequestAccessWithCompletion(ab, { granted, error in
                    DispatchQueue.main.async(execute: {

                        handler(granted)

                    })
                })
            } else {
                // No phonebook
                handler(true)
            }
        } else if cbStatus == .denied && viewController != nil && manualChangeMessage != nil {
            // Access not granted to the local contacts
            // Display manualChangeMessage
            let alert = UIAlertController(title: nil, message: manualChangeMessage, preferredStyle: .alert)

            // On iOS >= 8, add a shortcut to the app settings (This requires the shared application instance)
            let sharedApplication = UIApplication.perform(#selector(UIApplication.shared)) as? UIApplication
            if sharedApplication != nil && UIApplication.openSettingsURLString != "" {
                alert.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "settings"),
                        style: .default,
                        handler: { action in

                            let url = URL(string: UIApplication.openSettingsURLString)
                            sharedApplication?.perform(#selector(UIApplication.openURL(_:)), with: url)

                            // Note: it does not worth to check if the user changes the permission
                            // because iOS restarts the app in case of change of app privacy settings
                            handler(false)

                        }))
            }
            alert.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "ok"),
                    style: .default,
                    handler: { action in

                        handler(false)

                    }))

            viewController?.present(alert, animated: true)
        } else {
            handler(false)
        }
    }

    // MARK: - HTML processing

    /// Sanitise an HTML string to keep permitted HTML tags defined by 'allowedHTMLTags'.
    /// !!!!!! WARNING !!!!!!
    /// IT IS NOT REMOTELY A COMPREHENSIVE SANITIZER AND SHOULD NOT BE TRUSTED FOR SECURITY PURPOSES.
    /// WE ARE EFFECTIVELY RELYING ON THE LIMITED CAPABILITIES OF THE HTML RENDERER UI TO AVOID SECURITY ISSUES LEAKING UP.
    /// - Parameters:
    ///   - htmlString: the HTML code to sanitise.
    ///   - allowedHTMLTags: the list of allowed HTML tags
    ///   - imageHandler: the block called with the parameters of each image when 'img' tag is allowed. This handler must return a local path for this image. The image is removed from the html content if this handler is nil or the returned url is nil.
    /// - Returns: a sanitised HTML string.

    // MARK: - HTML processing

    class func sanitiseHTML(
        _ htmlString: String?,
        withAllowedHTMLTags allowedHTMLTags: [String]?,
        imageHandler: @escaping (_ sourceURL: String?, _ width: CGFloat, _ height: CGFloat) -> String
    ) -> String? {
        var html = htmlString

        // List all HTML tags used in htmlString
        let tagsInTheHTML = htmlTagsRegex?.matches(in: htmlString ?? "", options: [], range: NSRange(location: 0, length: htmlString?.count ?? 0))

        // Find those that are not allowed
        var tagsToRemoveSet: Set<AnyHashable> = []
        for result in tagsInTheHTML ?? [] {
            let tag = (htmlString as NSString?)?.substring(with: result.range(at: 1)).lowercased()
            if (allowedHTMLTags?.firstIndex(of: tag ?? "") ?? NSNotFound) == NSNotFound {
                tagsToRemoveSet.insert(tag)
            } else if tag == "img" {
                var originalStr: String?
                var sourceURL: String?
                var localSourcePath: String?

                if imageHandler != nil {
                    var width: CGFloat = -1
                    var height: CGFloat = -1

                    var characterSet = CharacterSet(charactersIn: "\"")
                    characterSet.formUnion(CharacterSet.whitespaces)

                    // Parse image parameters
                    originalStr = (htmlString as NSString?)?.substring(with: result.range(at: 0))
                    let components = originalStr?.components(separatedBy: " ")
                    for index in 1..<(components?.count ?? 0) {
                        let attributs = components?[index]?.components(separatedBy: "=")

                        if (attributs?.count ?? 0) == 2 {
                            if attributs?[0] == "src" {
                                sourceURL = attributs?[1]?.trimmingCharacters(in: characterSet)
                            } else if attributs?[0] == "width" {
                                let widthStr = attributs?[1]?.trimmingCharacters(in: characterSet)
                                width = CGFloat(Float(widthStr ?? "") ?? 0.0)
                            } else if attributs?[0] == "height" {
                                let heightStr = attributs?[1]?.trimmingCharacters(in: characterSet)
                                height = CGFloat(Float(heightStr ?? "") ?? 0.0)
                            }
                        }
                    }

                    localSourcePath = imageHandler(sourceURL, width, height)
                }

                if let localSourcePath = localSourcePath {
                    // Replace the image source with the right local url
                    let updatedStr = originalStr?.replacingOccurrences(of: sourceURL ?? "", with: localSourcePath)
                    html = (html as NSString?)?.replacingCharacters(in: result.range(at: 0), with: updatedStr ?? "")
                } else {
                    tagsToRemoveSet.insert(tag)
                }
            }
        }

        // And remove them from the HTML string
        if tagsToRemoveSet.count != 0 {
            let tagsToRemove = Array(tagsToRemoveSet)

            var tagsToRemoveString = tagsToRemove[0] as? String
            for i in 1..<tagsToRemove.count {
                tagsToRemoveString = (tagsToRemoveString ?? "") + "|\(tagsToRemove[i])"
            }

            html = (html as NSString?)?.replacingOccurrences(of: "<\\/?(\(tagsToRemoveString ?? ""))[^>]*>", with: "", options: [.regularExpression, .caseInsensitive], range: NSRange(location: 0, length: html?.count ?? 0))
        }

        // TODO: Sanitise other things: attributes, URL schemes, etc

        return html
    }

    /// Removing DTCoreText artifacts:
    /// - Trim trailing whitespace and newlines in the string content.
    /// - Replace DTImageTextAttachments with a simple NSTextAttachment subclass.
    /// - Parameter attributedString: an attributed string.
    /// - Returns: the resulting string.
    class func removeDTCoreTextArtifacts(_ attributedString: NSAttributedString?) -> NSAttributedString? {
        var mutableAttributedString: NSMutableAttributedString? = nil
        if let attributedString = attributedString {
            mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        }

        // DTCoreText adds a newline at the end of plain text ( https://github.com/Cocoanetics/DTCoreText/issues/779 )
        // or after a blockquote section.
        // Trim trailing whitespace and newlines in the string content
        while mutableAttributedString?.string.hasSuffixCharacter(from: CharacterSet.whitespacesAndNewlines) {
            mutableAttributedString?.deleteCharacters(in: NSRange(location: (mutableAttributedString?.length ?? 0) - 1, length: 1))
        }

        // New lines may have also been introduced by the paragraph style
        // Make sure the last paragraph style has no spacing
        mutableAttributedString?.enumerateAttributes(in: NSRange(location: 0, length: mutableAttributedString?.length ?? 0), options: usingBlock as? NSAttributedStringEnumerationReverse, { attrs, range, stop in

            if attrs?[NSAttributedString.Key.paragraphStyle] != nil {
                let subString = (mutableAttributedString?.string as NSString?).substring(with: range)
                let components = subString?.components(separatedBy: CharacterSet.newlines)

                var updatedAttrs = attrs
                let paragraphStyle = updatedAttrs[NSAttributedString.Key.paragraphStyle] as? NSMutableParagraphStyle
                paragraphStyle?.paragraphSpacing = 0
                if let paragraphStyle = paragraphStyle {
                    updatedAttrs[NSAttributedString.Key.paragraphStyle] = paragraphStyle
                }

                if (components?.count ?? 0) > 1 {
                    let lastComponent = components?.last

                    var range2 = NSRange(location: range.location, length: range.length - (lastComponent?.count ?? 0))
                    mutableAttributedString?.setAttributes(attrs as? [NSAttributedString.Key : Any], range: range2)

                    range2 = NSRange(location: range2.location + range2.length, length: lastComponent?.count ?? 0)
                    mutableAttributedString?.setAttributes(updatedAttrs as? [NSAttributedString.Key : Any], range: range2)
                } else {
                    mutableAttributedString?.setAttributes(updatedAttrs as? [NSAttributedString.Key : Any], range: range)
                }
            }

            // Check only the last paragraph
            stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
        })

        // Image rendering failed on an exception until we replace the DTImageTextAttachments with a simple NSTextAttachment subclass
        // (thanks to https://github.com/Cocoanetics/DTCoreText/issues/863).
        mutableAttributedString?.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutableAttributedString?.length ?? 0),
            options: [],
            using: { value, range, stop in

                if value is DTImageTextAttachment {
                    let attachment = value as? DTImageTextAttachment
                    let textAttachment = NSTextAttachment()
                    if attachment?.image {
                        textAttachment.image = attachment?.image

                        var frame = textAttachment.bounds
                        frame.size = attachment?.displaySize ?? CGSize.zero
                        textAttachment.bounds = frame
                    }
                    // Note we remove here attachment without image.
                    let attrStringWithImage = NSAttributedString(attachment: textAttachment)
                    mutableAttributedString?.replaceCharacters(in: range, with: attrStringWithImage)
                }
            })

        return mutableAttributedString
    }

    /// Make some matrix identifiers clickable in the string content.
    /// - Parameters:
    ///   - attributedString: an attributed string.
    ///   - enabledMatrixIdsBitMask: the bitmask used to list the types of matrix id to process (see MXKTOOLS_XXX__BITWISE).
    /// - Returns: the resulting string.
    class func createLinks(in attributedString: NSAttributedString?, forEnabledMatrixIds enabledMatrixIdsBitMask: Int) -> NSAttributedString? {
        if attributedString == nil {
            return nil
        }

        var postRenderAttributedString: NSMutableAttributedString?

        // If enabled, make user id clickable
        if enabledMatrixIdsBitMask & MXKTOOLS_USER_IDENTIFIER_BITWISE != 0 {
            Tools.createLinks(in: attributedString, matchingRegex: userIdRegex, withWorking: &postRenderAttributedString)
        }

        // If enabled, make room id clickable
        if enabledMatrixIdsBitMask & MXKTOOLS_ROOM_IDENTIFIER_BITWISE != 0 {
            Tools.createLinks(in: attributedString, matchingRegex: roomIdRegex, withWorking: &postRenderAttributedString)
        }

        // If enabled, make room alias clickable
        if enabledMatrixIdsBitMask & MXKTOOLS_ROOM_ALIAS_BITWISE != 0 {
            Tools.createLinks(in: attributedString, matchingRegex: roomAliasRegex, withWorking: &postRenderAttributedString)
        }

        // If enabled, make event id clickable
        if enabledMatrixIdsBitMask & MXKTOOLS_EVENT_IDENTIFIER_BITWISE != 0 {
            Tools.createLinks(in: attributedString, matchingRegex: eventIdRegex, withWorking: &postRenderAttributedString)
        }

        // If enabled, make group id clickable
        if enabledMatrixIdsBitMask & MXKTOOLS_GROUP_IDENTIFIER_BITWISE != 0 {
            Tools.createLinks(in: attributedString, matchingRegex: groupIdRegex, withWorking: &postRenderAttributedString)
        }

        return (postRenderAttributedString ?? attributedString) as? NSAttributedString
    }

    class func createLinks(in attributedString: NSAttributedString?, matchingRegex regex: NSRegularExpression?, withWorking mutableAttributedString: NSMutableAttributedString?) {
        var mutableAttributedString = mutableAttributedString
        var linkMatches: [AnyHashable]?

        // Enumerate each string matching the regex
        regex?.enumerateMatches(in: attributedString?.string ?? "", options: [], range: NSRange(location: 0, length: attributedString?.length ?? 0), using: { match, flags, stop in

            // Do not create a link if there is already one on the found match
            var hasAlreadyLink = false
            if let range1 = match?.range {
                attributedString?.enumerateAttributes(in: range1, options: [], using: { attrs, range, stop in

                    if attrs[NSAttributedString.Key.link] != nil {
                        hasAlreadyLink = true
                        stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
                    }
                })
            }

            // Do not create a link if the match is part of an http link.
            // The http link will be automatically generated by the UI afterwards.
            // So, do not break it now by adding a link on a subset of this http link.
            if !hasAlreadyLink {
                if linkMatches == nil {
                    // Search for the links in the string only once
                    // Do not use NSDataDetector with NSTextCheckingTypeLink because is not able to
                    // manage URLs with 2 hashes like "https://matrix.to/#/#matrix:matrix.org"
                    // Such URL is not valid but web browsers can open them and users C+P them...
                    // NSDataDetector does not support it but UITextView and UIDataDetectorTypeLink
                    // detect them when they are displayed. So let the UI create the link at display.
                    linkMatches = httpLinksRegex?.matches(in: attributedString?.string ?? "", options: [], range: NSRange(location: 0, length: attributedString?.length ?? 0))
                }

                for linkMatch in linkMatches ?? [] {
                    guard let linkMatch = linkMatch as? NSTextCheckingResult else {
                        continue
                    }
                    // If the match is fully in the link, skip it
                    if let range1 = match?.range {
                        if NSIntersectionRange(range1, linkMatch.range).length == (match?.range.length ?? 0) {
                            hasAlreadyLink = true
                            break
                        }
                    }
                }
            }

            if !hasAlreadyLink {
                // Create the output string only if it is necessary because attributed strings cost CPU
                if mutableAttributedString == nil {
                    if let attributedString = attributedString {
                        mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
                    }
                }

                // Make the link clickable
                // Caution: We need here to escape the non-ASCII characters (like '#' in room alias)
                // to convert the link into a legal URL string.
                var link: String? = nil
                if let range1 = match?.range {
                    link = (attributedString?.string as NSString?).substring(with: range1)
                }
                link = (link as NSString?)?.addingPercentEscapes(using: String.Encoding.utf8.rawValue)
                if let range1 = match?.range {
                    mutableAttributedString?.addAttribute(.link, value: link, range: range1)
                }
            }
        })
    }

    // MARK: - HTML processing - blockquote display handling

    /// Return a CSS to make DTCoreText mark blockquote blocks in the `NSAttributedString` output.
    /// These blocks  output will have a `DTTextBlocksAttribute` attribute in the `NSAttributedString`
    /// that can be used for later computation (in `removeMarkedBlockquotesArtifacts`).
    /// - Returns: a CSS string.

    // MARK: - HTML processing - blockquote display handling

    class func cssToMarkBlockquotes() -> String? {
        return String(format: "blockquote {background: #%lX; display: block;}", UInt(Tools.rgbValue(with: kMXKToolsBlockquoteMarkColor)))
    }

    /// Removing DTCoreText artifacts used to mark blockquote blocks.
    /// - Parameter attributedString: an attributed string.
    /// - Returns: the resulting string.
    class func removeMarkedBlockquotesArtifacts(_ attributedString: NSAttributedString?) -> NSAttributedString? {
        var mutableAttributedString: NSMutableAttributedString? = nil
        if let attributedString = attributedString {
            mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        }

        // Enumerate all sections marked thanks to `cssToMarkBlockquotes`
        // and apply our own attribute instead.

        // According to blockquotes in the string, DTCoreText can apply 2 policies:
        //     - define a `DTTextBlocksAttribute` attribute on a <blockquote> block
        //     - or, just define a `NSBackgroundColorAttributeName` attribute

        // `DTTextBlocksAttribute` case
        attributedString?.enumerateAttribute(
            DTTextBlocksAttribute,
            in: NSRange(location: 0, length: attributedString?.length ?? 0),
            options: [],
            using: { value, range, stop in
                if value is [AnyHashable] {
                    let array = value as? [AnyHashable]
                    if (array?.count ?? 0) > 0 && (array?[0] is DTTextBlock) {
                        let dtTextBlock = array?[0] as? DTTextBlock
                        if dtTextBlock?.backgroundColor == kMXKToolsBlockquoteMarkColor {
                            // Apply our own attribute
                            mutableAttributedString?.addAttribute(NSAttributedString.Key(kMXKToolsBlockquoteMarkAttribute), value: NSNumber(value: true), range: range)

                            // Fix a boring behaviour where DTCoreText add a " " string before a string corresponding
                            // to an HTML blockquote. This " " string has ParagraphStyle.headIndent = 0 which breaks
                            // the blockquote block indentation
                            if range.location > 0 {
                                let prevRange = NSRange(location: range.location - 1, length: 1)

                                var effectiveRange: NSRange
                                let paragraphStyle = attributedString?.attribute(
                                    .paragraphStyle,
                                    at: prevRange.location,
                                    effectiveRange: &effectiveRange) as? NSParagraphStyle

                                // Check if this is the " " string
                                if paragraphStyle != nil && effectiveRange.length == 1 && paragraphStyle?.firstLineHeadIndent != 25 {
                                    // Fix its paragraph style
                                    let newParagraphStyle = paragraphStyle as? NSMutableParagraphStyle
                                    newParagraphStyle?.firstLineHeadIndent = 25.0
                                    newParagraphStyle?.headIndent = 25.0

                                    mutableAttributedString?.addAttribute(.paragraphStyle, value: newParagraphStyle, range: prevRange)
                                }
                            }
                        }
                    }
                }
            })

        // `NSBackgroundColorAttributeName` case
        mutableAttributedString?.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: mutableAttributedString?.length ?? 0),
            options: [],
            using: { value, range, stop in

                if (value is UIColor) && ((value as? UIColor) == UIColor.magenta) {
                    // Remove the marked background
                    mutableAttributedString?.removeAttribute(.backgroundColor, range: range)

                    // And apply our own attribute
                    mutableAttributedString?.addAttribute(NSAttributedString.Key(kMXKToolsBlockquoteMarkAttribute), value: NSNumber(value: true), range: range)
                }
            })

        return mutableAttributedString
    }

    /// Enumerate all sections of the attributed string that refer to an HTML blockquote block.
    /// Must be used with `cssToMarkBlockquotes` and `removeMarkedBlockquotesArtifacts`.
    /// - Parameters:
    ///   - attributedString: the attributed string.
    ///   - block: a block called for each HTML blockquote blocks.
    class func enumerateMarkedBlockquotes(in attributedString: NSAttributedString?, usingBlock block: @escaping (_ range: NSRange, _ stop: UnsafeMutablePointer<ObjCBool>?) -> Void) {
        attributedString?.enumerateAttribute(
            NSAttributedString.Key(kMXKToolsBlockquoteMarkAttribute),
            in: NSRange(location: 0, length: attributedString?.length ?? 0),
            options: [],
            using: { value, range, stop in
                if (value is NSNumber) && (value as? NSNumber)?.boolValue ?? false {
                    block(range, stop)
                }
            })
    }

    // MARK: - Push

    /// Trim push token in order to log it.
    /// - Parameter pushToken: the token to trim.
    /// - Returns: a trimmed description.

    // MARK: - Push

    // Trim push token before printing it in logs
    class func log(forPushToken pushToken: Data?) -> String? {
        let len = ((pushToken?.count ?? 0) > 8) ? 8 : (pushToken?.count ?? 0) / 2
        if let subdata = pushToken?.subdata(in: NSRange(location: 0, length: len)) {
            return "\(subdata)..."
        }
        return nil
    }
}
