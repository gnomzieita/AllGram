//
//  PastboardManager.swift
//  AllGram
//
//  Created by Serg Basin on 20.09.2021.
//

import Foundation
import UIKit

public class PasteboardManager {
    
    public static let shared = PasteboardManager(withPasteboard: .general)
    
    private init(withPasteboard pasteboard: UIPasteboard) {
        self.pasteboard = pasteboard
    }
    
    /// Pasteboard to use on copy operations. Defaults to `UIPasteboard.generalPasteboard`.
    public var pasteboard: UIPasteboard
    
}
