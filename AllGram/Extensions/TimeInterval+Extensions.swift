//
//  TimeInterval+Extensions.swift
//  AllGram
//
//  Created by Alex Pirog on 08.07.2022.
//

import Foundation

extension TimeInterval {
    static let second: TimeInterval = 1
    static let minute: TimeInterval = second * 60
    static let hour: TimeInterval = minute * 60
    static let day: TimeInterval = hour * 24
}

extension TimeInterval {
    /// Returns duration string in `hh:mm:ss` format (omitting hours if 0)
    var durationText: String {
        let time = Int(self)
        let hours = time / 3600
        let minutes = (time - hours * 3600) / 60
        let seconds = time - 60 * minutes
        if hours > 0 {
            return String(format: "%d:%0d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// From: https://stackoverflow.com/a/49069866/10353982

extension TimeInterval {
    func timeString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = style
        return formatter.string(from: self) ?? "?"
    }
}

/*
 10000.asString(style: .positional)  // 2:46:40
 10000.asString(style: .abbreviated) // 2h 46m 40s
 10000.asString(style: .short)       // 2 hr, 46 min, 40 sec
 10000.asString(style: .full)        // 2 hours, 46 minutes, 40 seconds
 10000.asString(style: .spellOut)    // two hours, forty-six minutes, forty seconds
 10000.asString(style: .brief)       // 2hr 46min 40sec
 */
