//
//  Data+Extensions.swift
//  AllGram
//
//  Created by Alex Pirog on 22.06.2022.
//

import Foundation

extension Data {
    /// Returns `true` when file size is less than `50 MB`
    var isValidUploadSize: Bool {
        let mbScale = 1048576 // 1024 * 1024
        let mbSize = self.count / mbScale
        return mbSize < 50
    }
    // From: https://stackoverflow.com/a/42722744/10353982
    /// Returns file size formatted to string with given units, uses most fitting units as default
    func fileSize(in units: ByteCountFormatter.Units = [.useAll]) -> String {
        let byteFormatter = ByteCountFormatter()
        byteFormatter.allowedUnits = units
        byteFormatter.countStyle = .file
        return byteFormatter.string(fromByteCount: Int64(self.count))
    }
}
