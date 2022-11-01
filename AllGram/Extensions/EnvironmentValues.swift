import SwiftUI

struct UserIDKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var userId: String {
        get {
            return self[UserIDKey.self]
        }
        set {
            self[UserIDKey.self] = newValue
        }
    }
}

extension ContentSizeCategory {
    var scalingFactor: CGFloat {
        switch self {
        case .extraSmall:
            return 0.8
        case .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.1
        case .extraLarge:
            return 1.2
        case .extraExtraLarge:
            return 1.3
        case .extraExtraExtraLarge:
            return 1.4
        case .accessibilityMedium:
            return 1.5
        case .accessibilityLarge:
            return 1.6
        case .accessibilityExtraLarge:
            return 1.7
        case .accessibilityExtraExtraLarge:
            return 1.8
        case .accessibilityExtraExtraExtraLarge:
            return 1.9
        @unknown default:
            return 0.0
        }
    }
}

enum SFSymbol: String, View {
    case typing          = "scribble.variable"
    case close           = "xmark"

    case newConversation = "square.and.pencil"
    case settings        = "gear"
    case send            = "paperplane"
    case attach          = "paperclip"

    var body: some View {
        Image(systemName: self.rawValue)
    }
}

extension NSAttributedString {
    var isEmpty: Bool {
        self.length == 0
    }
}

// Leave only '<' as back button, no need for text
extension UINavigationController {
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }
}
