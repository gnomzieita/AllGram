//
//  EmailsAndPhonesViewModelProtocol.swift
//  AllGram
//
//  Created by Alex Pirog on 05.01.2022.
//

import Foundation
import MatrixSDK

enum EmailPhoneError: Error {
    
    /// Something important is found `nil`
    case `internal`
    
    /// For some reason will not work if user logged in from credentials
    case needsLogin
    
    case invalidInput
    case alreadyProcessing
    
    case noAddSession
    case noCode
    
    case requestValidationFailed
    case requestValidationAlreadyInUse
    
    case confirmValidationFailed
    case confirmValidationNotConfirmed
    case confirmValidationForbidden
    
    case removeValidFailed
    
    func problemDescription(for value: String) -> String {
        switch self {
        case .internal:
            return "Internal error"
            
        case .needsLogin:
            return "This action requires re-login"
            
        case .invalidInput:
            return "Invalid input"
        case .alreadyProcessing:
            return "\(value) already added"
            
        case .noAddSession:
            return "No add session for \(value)"
        case .noCode:
            return "No verification code for \(value) provided"
            
        case .requestValidationFailed:
            return "Failed to request validation for \(value)"
        case .requestValidationAlreadyInUse:
            return "\(value) already in use"
            
        case .confirmValidationNotConfirmed:
            return "\(value) not validated"
        case .confirmValidationForbidden:
            return "Invalid user password for confirming \(value)"
        case .confirmValidationFailed:
            return "Failed to confirm validation for \(value)"
            
        case .removeValidFailed:
            return "Failed to remove valid \(value)"
        }
    }
    
}

enum EmailPhoneType: Codable {
    
    case email
    case phone
    
    var medium: String {
        switch self {
        case .email: return kMX3PIDMediumEmail
        case .phone: return kMX3PIDMediumMSISDN
        }
    }
    
}

struct EmailPhone: Hashable {
    
    let type: EmailPhoneType
    let text: String
    var isValid: Bool
    var problem: EmailPhoneError?
    
    init(type: EmailPhoneType, text: String, isValid: Bool, problem: EmailPhoneError? = nil) {
        self.type = type
        self.text = text
        self.isValid = isValid
        self.problem = problem
    }

}

struct PendingEmailPhone: Codable {
    
    let type: EmailPhoneType
    let text: String
    let sessionId: String
    let clientSecret: String
    
    var asEmailPhone: EmailPhone {
        EmailPhone(type: type, text: text, isValid: false, problem: nil)
    }
    
}

protocol EmailsAndPhonesViewModelProtocol: ObservableObject {
    
    /// Completion handler for item actions. Returns resulting item in `success` and error in `failure`
    typealias CompletionHandler = (Result<String, EmailPhoneError>) -> Void
    
    /// List of all email addresses, both validated and pending
    var emails: [EmailPhone] { get }
    
    /// List of all phone numbers, both validated and pending
    var phones: [EmailPhone] { get }
    
    /// Reloads valid data for account from Matrix and pending data from local storage
    func reloadData(completion: ((Bool) -> Void)?)
    
    func requestValidation(for item: String, of type: EmailPhoneType, completion: CompletionHandler?)
    func cancelValidation(for item: String, of type: EmailPhoneType, completion: CompletionHandler?)
    func confirmValidation(for item: String, of type: EmailPhoneType, with code: String?, completion: CompletionHandler?)
    func removeValid(_ item: String, of type: EmailPhoneType, completion: CompletionHandler?)
    
}

extension UserDefaults {
    
    private var kPendingEmailsPhones: String { "PendingEmailsPhones" }
    var pendingEmailsPhones: [PendingEmailPhone] {
        get {
            if let data = object(forKey: kPendingEmailsPhones) as? Data {
                let decoder = JSONDecoder()
                if let result = try? decoder.decode([PendingEmailPhone].self, from: data) {
                    return result
                }
            }
            return []
        }
        set {  set(try? JSONEncoder().encode(newValue), forKey: kPendingEmailsPhones) }
    }
    
}
