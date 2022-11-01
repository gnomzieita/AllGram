//
//  String+validPhoneNumber.swift
//  AllGram
//
//  Created by Ярослав Шерстюк on 21.09.2021.
//

import Foundation

extension String {
    public var validPhoneNumber: Bool {
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return false }
        if let match = detector.matches(in: self, options: [], range: NSMakeRange(0, self.count)).first?.phoneNumber {
            return match == self
        } else {
            return false
        }
    }
}



//  print("\("+96 (123) 456-0990".validPhoneNumber)") //returns false, smart enough to know if country phone code is valid as well 🔥
//  print("\("+994 (123) 456-0990".validPhoneNumber)") //returns true because +994 country code is an actual country phone code
//  print("\("(123) 456-0990".validPhoneNumber)") //returns true
//  print("\("123-456-0990".validPhoneNumber)") //returns true
//  print("\("1234560990".validPhoneNumber)") //returns true
