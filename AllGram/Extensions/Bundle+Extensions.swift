//
//  Bundle+Extensions.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 15.12.2021.
//

import Foundation

var softwareVersion: String {
    let version = Bundle.main.releaseVersionNumber ?? "no_version"
    let build = Bundle.main.buildVersionNumber ?? "no_build"
    return "\(version).\(build)-\(API.inDebug ? "dev" : "prod")"
}

extension Bundle {
    var releaseVersionNumber: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
    }
}
