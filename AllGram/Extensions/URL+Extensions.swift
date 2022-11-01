//
//  URL+Extensions.swift
//  AllGram
//
//  Created by Alex Pirog on 05.07.2022.
//

import Foundation
import UniformTypeIdentifiers

extension URL {
    /// Returns preferred MIME type for file at this URL, like `image/jpeg` or `video/mp4`
    var mimeType: String {
        UTType(filenameExtension: self.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
    /// Checks if type for file at this URL conforms to a given type
    func contains(_ uttype: UTType) -> Bool {
        return UTType(mimeType: self.mimeType)?.conforms(to: uttype) ?? false
    }
}
