//
//  Base32Converter.swift
//  AllGram
//
//  Created by Vladyslav on 15.12.2021.
//

// Equivalent for the cocoapod SwiftBase32

import Foundation

class Base32Coder {
    
    // encoding without padding
    static func encode(_ str: String) -> String {
        return str.utf8CString.withUnsafeBytes { rawBufPointer in
            var outStr = ""
            var x = 0, bitOffset = 0
            for ch in rawBufPointer {
                x += Int(ch) << bitOffset
                outStr.append(table32[x & 31])
                x >>= 5
                
                // balance: we have added 8 bits from rawBuffer, and already tranferred 5 bits
                bitOffset += 8 - 5
                if bitOffset >= 5 {
                    outStr.append(table32[x & 31])
                    x >>= 5
                    bitOffset -= 5
                }
            }
            if bitOffset > 0 {
                outStr.append(table32[x & 31])
            }
            return outStr
        }
    }
    
    static func decode(_ codedString: String) -> String {
        // TODO: implement if will be needed in application
        return ""
    }
}

fileprivate let table32 = ["A","B","C","D","E","F","G","H",
                           "I","J","K","L","M","N","O","P",
                           "Q","R","S","T","U","V","W","X",
                           "Y","Z","2","3","4","5","6","7"]

