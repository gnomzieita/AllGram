import MatrixSDK
import  SwiftUI

/// `AvatarGenerator` class generate an avatar image from objects

var imageByKeyDict: [AnyHashable : Any]? = nil
var colorsList: [UIColor] = [.blue]
var backgroundLabel: UILabel? = nil
    /// Init the generated avatar colors.
    /// Should be the same as the webclient.
class AvatarGenerator {
    static func initColorList() {
        colorsList = [.red, .blue, .yellow]
        
    }

    /// Generate the selected color index in colorsList list.
    static func colorIndex() -> Int {
        AvatarGenerator.initColorList()
        let maximumIndex = colorsList.count - 1
        let randomInt = Int.random(in: 0...maximumIndex)
        return randomInt
    }

    /// Return the first valid character for avatar creation.
    static func firstChar(_ text: String?) -> String? {
        var text = text
        if text?.hasPrefix("@") ?? false || text?.hasPrefix("#") ?? false || text?.hasPrefix("!") ?? false || text?.hasPrefix("+") ?? false {
            text = (text as NSString?)?.substring(from: 1)
        }

        // default firstchar
        var firstChar = " "

        if (text?.count ?? 0) > 0 {
            if let range = (text as NSString?)?.rangeOfComposedCharacterSequence(at: 0) {
                firstChar = (text as NSString?)?.substring(to: NSMaxRange(range)).uppercased() ?? ""
            }
        }

        return firstChar
    }

    /// Create a squared UIImage with the text and the background color.
    /// - Parameters:
    ///   - text: the text.
    ///   - color: the background color.
    /// - Returns: the avatar image.
    static func image(fromText text: String?, withBackgroundColor color: UIColor?) -> UIImage? {
        if backgroundLabel == nil {
            backgroundLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
            backgroundLabel?.textColor = colorsList[colorIndex()]
            backgroundLabel?.textAlignment = .center
            backgroundLabel?.font = UIFont.boldSystemFont(ofSize: 25)
        }

        backgroundLabel?.text = text
        backgroundLabel?.backgroundColor = color

        // Create a "canvas" (image context) to draw in.
        UIGraphicsBeginImageContextWithOptions(backgroundLabel?.frame.size ?? CGSize.zero, false, 0)

        // set to the top quality
        let context = UIGraphicsGetCurrentContext()
        var image: UIImage?
        if let context = context {
            context.interpolationQuality = CGInterpolationQuality.high
            backgroundLabel?.layer.render(in: context)
            image = UIGraphicsGetImageFromCurrentImageContext()
        }

        UIGraphicsEndImageContext()

        // Return the image.
        return image
    }

    static func image(fromText text: String?, withBackgroundColor color: UIColor?, size: CGFloat, andFontSize fontSize: CGFloat) -> UIImage? {
        let bgLabel = UILabel(frame: CGRect(x: 0, y: 0, width: size, height: size))
        bgLabel.textColor = colorsList[colorIndex()]
        bgLabel.textAlignment = .center
        bgLabel.font = UIFont.boldSystemFont(ofSize: fontSize)

        bgLabel.text = text
        bgLabel.backgroundColor = color

        // Create a "canvas" (image context) to draw in.
        UIGraphicsBeginImageContextWithOptions(bgLabel.frame.size, false, 0)

        // set to the top quality
        let context = UIGraphicsGetCurrentContext()
        var image: UIImage?
        if let context = context {
            context.interpolationQuality = CGInterpolationQuality.high
            bgLabel.layer.render(in: context)
            image = UIGraphicsGetImageFromCurrentImageContext()
        }

        UIGraphicsEndImageContext()

        // Return the image.
        return image
    }

    /// Returns the UIImage for the text and a selected color.
    /// It checks first if it is not yet cached before generating one.
    class func avatar(forText text: String?, andColorIndex colorIndex: Int) -> UIImage? {
        let firstChar = AvatarGenerator.firstChar(text)

        // the images are cached to avoid create them several times
        // the key is <first upper character><index in the colors array>
        // it should be smaller than using the text as a key
        let key = String(format: "%@%tu", firstChar ?? "", colorIndex)

        if imageByKeyDict == nil {
            imageByKeyDict = [:]
        }

        var image = imageByKeyDict?[key] as? UIImage

        if image == nil {
            image = AvatarGenerator.image(fromText: firstChar, withBackgroundColor: colorsList[colorIndex])
            imageByKeyDict?[key] = image
        }

        return image
    }

    /// Generate an avatar for a text.
    /// - Parameter text: the text.
    /// - Returns: the avatar image
    class func generateAvatar(forText text: String?) -> UIImage? {
        return AvatarGenerator.avatar(forText: text, andColorIndex: AvatarGenerator.colorIndex())
    }

    class func generateAvatar(forMatrixItem itemId: String?, withDisplayName displayname: String?) -> UIImage? {
        return AvatarGenerator.avatar(forText: displayname ?? itemId, andColorIndex: AvatarGenerator.colorIndex())
    }

    /// Generate a squared avatar for a matrix item (room, room member...) with a preferred size
    /// - Parameters:
    ///   - itemId: the matrix identifier of the item
    ///   - displayname: the item displayname (if nil, the itemId is used by default).
    ///   - size: the expected size of the returned image
    ///   - fontSize: the expected font size
    /// - Returns: the avatar image
    class func generateAvatar(forMatrixItem itemId: String?, withDisplayName displayname: String?, size: CGFloat, andFontSize fontSize: CGFloat) -> UIImage? {
        let firstChar = AvatarGenerator.firstChar(displayname ?? itemId)
        let colorIndex = AvatarGenerator.colorIndex()

        return AvatarGenerator.image(fromText: firstChar, withBackgroundColor: colorsList[colorIndex], size: size, andFontSize: fontSize)
    }

    /// Clear all the resources stored in memory.
    class func clear() {
        imageByKeyDict?.removeAll()
        colorsList = [.blue]
        backgroundLabel = nil
    }
}
