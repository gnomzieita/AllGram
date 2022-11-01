import SwiftUI
import Down
import DTCoreText

struct MarkdownText: View {
    private let markdown: String
    private let textColor: UXColor

    @State private var contentSizeThatFits: CGSize = .zero

    private let textAttributes: TextAttributes
    private let linkColor: UXColor

    // #warning("Is onLinkInteraction needed?")
    private let onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))?

    private let attributedText : NSAttributedString
    
    public init(
        markdown: String,
        textColor: UXColor,
        textAttributes: TextAttributes = .init(),
        linkColor: UXColor,
        onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))? = nil
    ) {
        self.attributedText = MarkdownText.makeAttributedString(markdown: markdown, attributes: MarkdownText.attributes(textColor: textColor))
        
        self.markdown = markdown

        self.textColor = textColor.resolvedColor(with: .current)
        self.textAttributes = textAttributes
        self.linkColor = linkColor
        self.onLinkInteraction = onLinkInteraction
    }

    private static func attributes(textColor: UXColor) -> [NSAttributedString.Key: Any] {
        [
            .font: UXFont.preferredFont(forTextStyle: .body),
            .foregroundColor: textColor,
            .strokeColor: textColor
        ]
    }
    private static func makeAttributedString(markdown: String,
                                             attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let downObj = Down(markdownString: markdown)
        var convertedAttrString : NSAttributedString
        do {
            var colorColection = StaticColorCollection()
            if let textColor = attributes[.foregroundColor] as? UXColor {
                colorColection.quoteStripe = textColor.withAlphaComponent(0.5)
            }
            let conf = DownStylerConfiguration(colors: colorColection)
            
            let styler = DownStyler(configuration: conf)
            convertedAttrString = try downObj.toAttributedString(.default, styler: styler)
        } catch _ {
            return NSAttributedString(string: markdown, attributes: attributes)
        }
        
        // delete the extra newline characters that were added by Down object
        let convertedStr = convertedAttrString.string as NSString
        let trimmedStr = convertedStr.trimmingCharacters(in: .whitespacesAndNewlines) as NSString
        
        if trimmedStr.length < convertedStr.length {
            let range = convertedStr.range(of: trimmedStr as String)
            convertedAttrString = convertedAttrString.attributedSubstring(from: range)
        }
       
        // override the text color and font attributes that were set by Down object
        let mutableAttrString = NSMutableAttributedString(string: convertedAttrString.string, attributes: attributes)
        let fullRange = NSMakeRange(0, convertedAttrString.length)
        convertedAttrString.enumerateAttributes(in: fullRange, options: []) { existingAttribs, range, _ in
            // preserve italic or bold traits
            var withTraitAttribs = attributes
            updateAttributesWithFontTraits(dict: &withTraitAttribs, font: existingAttribs[.font] as? UIFont)
            let newAttribs = existingAttribs.merging(withTraitAttribs) { _, value2 in
                return value2
            }
            
            mutableAttrString.setAttributes(newAttribs, range: range)
        }

        return NSAttributedString(attributedString: mutableAttrString)
    }
    
    private static func updateAttributesWithFontTraits(dict: inout [NSAttributedString.Key: Any], font: UIFont?) {
        guard let traits = font?.fontDescriptor.symbolicTraits,
              let oldFont = dict[.font] as? UIFont
        else {
            return
        }
        let oldFontDescriptor = oldFont.fontDescriptor
        let oldTraits = oldFontDescriptor.symbolicTraits
        let boldItalic : UIFontDescriptor.SymbolicTraits = [.traitBold, .traitItalic]
        var newTraits = oldTraits.subtracting(boldItalic)
        newTraits.formUnion(traits.intersection(boldItalic))
        if newTraits == oldTraits {
            return
        }
        if let d = oldFontDescriptor.withSymbolicTraits(newTraits) {
            dict[.font] = UIFont(descriptor: d, size: oldFont.pointSize)
        }
    }

    private var textContainerInset: UXEdgeInsets {
        .init(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
    }

    private var lineFragmentPadding: CGFloat {
        0.0
    }

    var body: some View {
        GeometryReader { geometry in
            let size = MessageTextView(attributedString: attributedText,
                                            linkColor: linkColor,
                                            maxSize: geometry.size).intrinsicContentSize

            MessageTextViewWrapper(attributedString: attributedText, linkColor: linkColor, maxSize: geometry.size)
                .preference(key: ContentSizeThatFitsKey.self, value: size)
        }
        .onPreferenceChange(ContentSizeThatFitsKey.self) {
            contentSizeThatFits = $0
        }
        .frame(
            maxWidth: self.contentSizeThatFits.width,
            minHeight: self.contentSizeThatFits.height,
            maxHeight: self.contentSizeThatFits.height,
            alignment: .leading
        )
    }
}

@available(macOS, unavailable)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        let markdownString = #"""
        # [Universal Declaration of Human Rights][udhr]

        ## Article 1.

        All human beings are born free and equal in dignity and rights.
        They are endowed with reason and conscience
        and should act towards one another in a spirit of brotherhood.

        [udhr]: https://www.un.org/en/universal-declaration-human-rights/ "View full version"
        """#
        return MarkdownText(
            markdown: markdownString,
            textColor: .messageTextColor(for: .light, isOutgoing: false),
            linkColor: .blue
        ) { url, _ in
            return true
        }
            .padding(10.0)
    }
}
