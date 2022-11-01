//
//  String+Extensions.swift
//  AllGram
//
//  Created by Alex Pirog on 10.05.2022.
//

import Foundation

extension String {
    /// Drops `:allgram.me` suffix (does nothing if has no such suffix)
    var dropAllgramSuffix: String {
        self.dropSuffix(":allgram.me")
    }
    /// Returns up to 2 letters to use when there is no avatar image provided
    var avatarLetters: String {
        let words = self.split(separator: " ")
        if words.isEmpty {
            // Unable to split, try first 2 symbols
            return self
                .replacingOccurrences(of: " ", with: "")
                .prefix(2).uppercased()
        } else {
            if words.count == 1 {
                // Only one word?! Hm, use it...
                return String(words.first!)
                    .replacingOccurrences(of: " ", with: "")
                    .prefix(2).uppercased()
            } else {
                // Take first and last word, one letter from each one
                return String(words.first!)
                    .replacingOccurrences(of: " ", with: "")
                    .prefix(1).uppercased() +
                String(words.last!)
                    .replacingOccurrences(of: " ", with: "")
                    .prefix(1).uppercased()
            }
        }
    }
}

import CryptoKit

extension String {
    /// Returns MD5 hash value of the string
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}

// MARK: - General

extension String: Identifiable {
    public var id: String { self }
}

extension String {
    /// Returns `true` when this string contains something other than white spaces and new lines
    var hasContent: Bool {
        !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Drops given prefix (does nothing if has no such prefix)
    func dropPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
    /// Drops given suffix (does nothing if has no such suffix)
    func dropSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }
    /// Truncates the string to a given length and appends an optional trailing string if longer
    func truncate(length: Int, trailing: String = "...") -> String {
        guard self.count > length else { return self }
        var truncated = self.prefix(length)
        while truncated.last != " " {
            truncated = truncated.dropLast()
        }
        return truncated + trailing
    }
    /// Drops characters at the end of the string until given length is matched.
    /// Returns empty string if provided length is zero or less.
    /// Returns current string of provided length is more than current length (does not add value)
    func dropLastUntil(_ length: Int) -> String {
        guard count > 0 else { return "" }
        let currentCount = self.count
        guard currentCount > length else { return self }
        let dropCount = currentCount - length
        return String(self.dropLast(dropCount))
    }
    /// Drops characters at the start of the string until given length is matched.
    /// Returns empty string if provided length is zero or less.
    /// Returns current string of provided length is more than current length (does not add value)
    func dropFirstUntil(_ length: Int) -> String {
        guard count > 0 else { return "" }
        let currentCount = self.count
        guard currentCount > length else { return self }
        let dropCount = currentCount - length
        return String(self.dropFirst(dropCount))
    }
}

extension String {
    /// Allows subscript for `Range<Int>` with `String` result
    subscript(range: Range<Int>) -> String {
        let startIndex = index(self.startIndex, offsetBy: range.lowerBound)
        let endIndex = index(self.startIndex, offsetBy: range.upperBound)
        return String(self[startIndex..<endIndex])
    }
    /// Gets regex matches on the whole range of `self` if any, otherwise returns an empty array.
    /// `Important:` you are responsible for providing a valid regex pattern
    func ranges(withPattern pattern: String) -> [Range<Int>] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.count)
        let matches = regex.matches(in: self, options: [], range: range)
        return matches.compactMap { Range<Int>($0.range) }
    }
}

// MARK: - Phone Number

// via https://stackoverflow.com/a/63187893/10353982

extension String {
    var isValidPhoneNumber: Bool {
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return false }
        if let match = detector.matches(in: self, options: [], range: NSMakeRange(0, self.count)).first?.phoneNumber {
            return match == self
        } else {
            return false
        }
    }
}

//print("\("+96 (123) 456-0990".isValidPhoneNumber)") //returns false, smart enough to know if country phone code is valid as well 🔥
//print("\("+994 (123) 456-0990".isValidPhoneNumber)") //returns true because +994 country code is an actual country phone code
//print("\("(123) 456-0990".isValidPhoneNumber)") //returns true
//print("\("123-456-0990".isValidPhoneNumber)") //returns true
//print("\("1234560990".isValidPhoneNumber)") //returns true

// MARK: - Emoji

// via https://stackoverflow.com/a/39425959/1843020

extension Character {
    /// A simple emoji is one scalar and presented to the user as an Emoji
    var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
    }
    /// Checks if the scalars will be merged into an emoji
    var isCombinedIntoEmoji: Bool {
        unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false
    }
    /// Any emoji, simple or combined
    var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}

extension String {
    func replaceEmoji(with character: Character) -> String {
        return String(map { $0.isEmoji ? character : $0 })
    }
}

extension String {
    var isSingleEmoji: Bool { count == 1 && containsEmoji }
    var containsEmoji: Bool { contains { $0.isEmoji } }
    var containsOnlyEmoji: Bool { !isEmpty && !contains { !$0.isEmoji } }
    var emojiString: String { emojis.map { String($0) }.reduce("", +) }
    var emojis: [Character] { filter { $0.isEmoji } }
    var emojiScalars: [UnicodeScalar] { filter { $0.isEmoji }.flatMap { $0.unicodeScalars } }
}
