//
//  PermissionsManager.swift
//  AllGram
//
//  Created by Eugene Ned on 05.08.2022.
//

import AVKit
import AVFAudio
import Contacts
import Foundation

class PermissionsManager {
    static let shared = PermissionsManager()
    
    func getAuthStatusFor(_ mediaType: AVMediaType) -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: mediaType)
    }
}
