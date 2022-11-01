//
//  TextWithMention.swift
//  AllGram
//
//  Created by Alex Pirog on 04.07.2022.
//

import SwiftUI

struct TextWithMention: View {
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    let message: String
    let ranges: [Range<Int>]
    
    init(_ message: String) {
        let mentionOrLink = "(\(String.mentionRangePattern)|\(String.linkRangePattern))"
        self.message = message
        self.ranges = message.addedRanges(withPattern: mentionOrLink)
    }
    
    var body: some View {
        var content = Text("")
        //var printText = ""
        ranges.forEach { range in
            content = content + self.text(for: range)
            //printText += message[range] + "' + '"
        }
        //print("[T] '\(printText.dropSuffix("' + '").replacingOccurrences(of: "\n", with: "|new line|"))'")
        return content
    }
    
    private func text(for range: Range<Int>) -> Text {
        let content = message[range]
        if content.containsMention {
            // Check if we have this user that we are mentioning
            let safeMention = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
            if membersVM.hasMember(with: safeMention) {
                return Text(content).bold()
            } else {
                return Text(content)
            }
        } else if content.containsLink {
            // AttributedString will trim new lines,
            // so we need to add them back at start/end
            let start = content.hasPrefix("\n") ? "\n" : ""
            let end = content.hasSuffix("\n") ? "\n" : ""
            var link = try! AttributedString(markdown: "[\(content)](\(content))")
            link.foregroundColor = .blue
            return Text(start) + Text(link).underline() + Text(end)
        } else {
            return Text(content)
        }
    }
}

extension String {
    /// Pattern for mentioning users by id, like `@userId`
    /// Start: beginning of the line OR white space OR new line OR ',' OR '.'
    /// Body: @ and at least one letter & number
    /// End: end of the line OR white space OR new line OR ',' OR '.'
    static var mentionRangePattern: String {
        let start = "(^|\\s|\\\n|,|\\.)"
        let body = "@\\w+"
        let end = "($|\\s|\\\n|,|\\.)"
        return start + body + end
    }
    
    /// `true` when this string matches `mentionRangePattern`
    var containsMention: Bool {
        !self.ranges(withPattern: String.mentionRangePattern).isEmpty
    }
    
    /// Pattern for mentioning links, like `https://google.com`.
    /// Start: beginning of the line OR white space OR new line OR ','
    /// Body: http(s):// and something after it, dot, letters
    /// End: end of the line OR white space OR new line OR ','
    static var linkRangePattern: String {
        let start = "(^|\\s|\\\n|,)"
        let body = "(https://|http://)\\w+\\.\\w+"
        let end = "($|\\s|\\\n|,)"
        return start + body + end
    }
    
    /// `true` when this string matches `linkRangePattern`
    var containsLink: Bool {
        !self.ranges(withPattern: String.linkRangePattern).isEmpty
    }
    
    /// Gets all ranges matching given pattern and adds ranges for gaps between them if any.
    /// If no matches, returns range for the whole string
    func addedRanges(withPattern pattern: String) -> [Range<Int>] {
        var mRanges = self.ranges(withPattern: pattern)
        
        // No matches, just take whole string and leave
        guard !mRanges.isEmpty else {
            return [0..<self.count]
        }
        
        // Some matches, we need to fill the gaps
        var allRanges = [Range<Int>]()
        mRanges.sort(by: { $0.lowerBound < $1.lowerBound })
        
        // Matched ranges + ranges in-between
        for i in 0..<mRanges.count {
            let match = mRanges[i]
            if let last = allRanges.last {
                // Range from last match to this match
                if last.upperBound < match.lowerBound {
                    allRanges.append(last.upperBound..<match.lowerBound)
                }
            } else {
                // Range from start to first match
                if match.lowerBound > 0 {
                    allRanges.append(0..<match.lowerBound)
                }
            }
            allRanges.append(match)
        }
        
        // Additional range after last match if needed
        if mRanges.last!.upperBound < self.count {
            allRanges.append(mRanges.last!.upperBound..<self.count)
        }
        
        return allRanges
    }
}
