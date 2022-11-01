import SwiftUI
import MatrixSDK

extension MXPublicRoom: Identifiable {}
extension MXRoom: Identifiable {}
extension MXEvent: Identifiable {}

extension ObjectIdentifier: Identifiable {
    public var id: ObjectIdentifier {
        return self
    }
}
