//
//  InputManager.swift
//  AllGram
//
//  Created by Eugene Ned on 17.08.2022.
//

import Foundation
import Combine

class InputManager: ObservableObject {
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var input: String
    
    @Published private(set) var isValid: Bool = true
    @Published private(set) var validations: [Validation]
    
    private let requiredContent: Bool
    private var isEmptyContentValid: Bool = true
    
    init(input: String = "", validations: [Validation], requiredContent: Bool = true) {
        self.input = input
        self.validations = validations
        self.requiredContent = requiredContent
        
        // If input content changes for the first time ->
        // set empty content to fail for required content
        $input
            .removeDuplicates()
            .eraseToAnyPublisher()
            .receive(on: RunLoop.main)
            .map { [weak self] newInput in
                guard let self = self else { return true }
                guard self.requiredContent else { return true }
                if newInput.hasContent {
                    return false
                } else {
                    return self.isEmptyContentValid
                }
            }
            .assign(to: \.isEmptyContentValid, on: self)
            .store(in: &cancellables)
        
        // If input changes -> re-validate
        $input
            .removeDuplicates()
            .eraseToAnyPublisher()
            .receive(on: RunLoop.main)
            .map { [weak self] newInput in
                guard let self = self else { return true }
                guard newInput.hasContent else { return self.isEmptyContentValid }
                return self.validations.filter { !$0.validate(newInput) }.isEmpty
            }
            .assign(to: \.isValid, on: self)
            .store(in: &cancellables)
    }
}

struct Validation {
    let type: ValidationType
    let requirementDescription: String?
    
    init(type: ValidationType, requirementDescription: String? = nil) {
        self.type = type
        self.requirementDescription = requirementDescription
    }
    
    // MARK: - Validation
    
    /// Checks if given string fulfils validation type or not
    func validate(_ string: String) -> Bool {
        switch type {
            // Length validation
        case .minCharacters(let count):
            return string.count >= count
        case .maxCharacters(let count):
            return string.count <= count
        case .rangeCharacters(let range):
            return range.contains(string.count)
            
            // Content has something
        case .hasDigits:
            return string.hasDigits()
        case .hasLatinLetters:
            return string.hasLatinLetters()
        case .hasLowercasedLetters:
            return string.hasLowercasedCharacters()
        case .hasUppercasedLetters:
            return string.hasUppercasedCharacters()
        case .hasSpecialSymbols:
            return string.hasSpecialCharacters()
            
            // Restrictions
        case .onlyDigits:
            return string.hasOnlyDigits()
            
            // Complex
        case .matchesPredicate(let regex):
            return string.matchesPredicate(regex: regex)
        }
    }
    
    // MARK: - Our Validators
    
    // TODO: add proper username validation
    static let username: [Validation] = [
        Validation(type: .minCharacters(3)),
        Validation(type: .hasLatinLetters),
    ]
    
    static let password: [Validation] = [
        Validation(type: .rangeCharacters(8...50),
                   requirementDescription: "Minimum and maximum length: 8 to 50"),
        Validation(type: .hasUppercasedLetters,
                   requirementDescription: "One upper case letter"),
        Validation(type: .hasLowercasedLetters,
                   requirementDescription: "One lower case letter"),
        Validation(type: .hasDigits,
                   requirementDescription: "At least one digit"),
        Validation(type: .hasSpecialSymbols,
                   requirementDescription: "One special symbol"),
    ]
    
    static let email: [Validation] = [
        Validation(type: .matchesPredicate(regex: "^([a-zA-Z0-9_\\-\\.]+)@((\\[[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.)|(([a-zA-Z0-9\\-]+\\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\\]?)$")),
    ]
    
    // TODO: add proper phone number validation
    static let phone: [Validation] = [
        Validation(type: .onlyDigits),
    ]
    
    // TODO: add proper invitation key validation
    static let invitationKey: [Validation] = [
        Validation(type: .minCharacters(1)),
    ]
}

enum ValidationType {
    // Length of string
    case minCharacters(_ count: Int)
    case maxCharacters(_ count: Int)
    case rangeCharacters(_ range: ClosedRange<Int>)
    
    // Content has something
    case hasDigits
    case hasLatinLetters
    case hasLowercasedLetters
    case hasUppercasedLetters
    case hasSpecialSymbols
    
    // Restrictions
    case onlyDigits
    
    // Regex
    case matchesPredicate(regex: String)
}

extension String {
    func hasDigits() -> Bool {
        return matchesPredicate(regex:  ".*[0-9]+.*")
    }
    func hasOnlyDigits() -> Bool {
        return matchesPredicate(regex:  "^[0-9]+$")
    }
    func hasLatinLetters() -> Bool {
        return matchesPredicate(regex:  ".*[a-zA-Z]+.*")
    }
    func hasUppercasedCharacters() -> Bool {
        return !self.filter { $0.isUppercase }.isEmpty
    }
    func hasLowercasedCharacters() -> Bool {
        return !self.filter { $0.isLowercase }.isEmpty
    }
    func hasSpecialCharacters() -> Bool {
        return matchesPredicate(regex: ".*[^A-Za-z0-9].*")
    }
    func matchesPredicate(regex: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }
}

extension String {
    /// If `hasContent` returns this string, otherwise - `nil`
    var optionalContent: String? { self.hasContent ? self : nil }
}
