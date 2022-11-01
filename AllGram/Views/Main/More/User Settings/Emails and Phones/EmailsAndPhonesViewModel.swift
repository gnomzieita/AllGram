//
//  EmailsAndPhonesViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 05.01.2022.
//

import Foundation
import MatrixSDK

class EmailsAndPhonesViewModel: EmailsAndPhonesViewModelProtocol {
    
    @Published private(set) var emails: [EmailPhone] = []
    @Published private(set) var phones: [EmailPhone] = []
    
    /// Used to perform most actions
    let authViewModel: AuthViewModel
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    /// Current sessions for adding phone number
    private var phoneAddSession: [String: MX3PidAddSession] = [:]
    
    // MARK: - Reloading
    
    @Published private(set) var isReloading = false
    
    private var reloadAttempts = 0
    private let reloadAttemptLimit = 3
    
    func reloadData(completion: ((Bool) -> Void)? = nil) {
        guard let client = authViewModel.client else {
            completion?(false)
            return
        }
        guard !isReloading else {
            completion?(false)
            return
        }
        isReloading = true
        client.thirdPartyIdentifiers() { [weak self] response in
            guard let self = self else { return }
            self.isReloading = false
            switch response {
            case .success(let data):
                self.reloadAttempts = 0
                let loaded: [EmailPhone] = (data ?? []).map({
                    let t: EmailPhoneType = $0.medium == kMX3PIDMediumEmail ? .email : .phone
                    return EmailPhone(type: t, text: $0.address, isValid: true)
                })
                let stored = UserDefaults.group.pendingEmailsPhones.map({ $0.asEmailPhone })
                let fromPhoneAddSessions = self.phoneAddSession.keys.map({ EmailPhone(type: .phone, text: $0, isValid: false) })
                self.emails = loaded.filter({ $0.type == .email }) + stored.filter({ $0.type == .email })
                self.phones = loaded.filter({ $0.type == .phone }) + stored.filter({ $0.type == .phone }) + fromPhoneAddSessions
                completion?(true)
            case .failure(_):
                self.reloadAttempts += 1
                guard self.reloadAttempts >= self.reloadAttemptLimit else {
                    self.reloadData(completion: completion)
                    return
                }
                completion?(false)
            }
        }
    }
    
    // MARK: - Requesting Validation
    
    func requestValidation(for item: String, of type: EmailPhoneType, completion: CompletionHandler? = nil) {
        switch type {
        case .email: requestEmailValidation(item, completion: completion)
        case .phone: requestPhoneValidation(item, completion: completion)
        }
    }
    
    private func requestEmailValidation(_ item: String, completion: CompletionHandler? = nil) {
        guard let client = authViewModel.client else {
            completion?(.failure(.internal))
            return
        }
        guard MXTools.isEmailAddress(item) else {
            completion?(.failure(.invalidInput))
            return
        }
        guard !emails.contains(where: { $0.text == item }) else {
            completion?(.failure(.alreadyProcessing))
            return
        }
        let secret = MXTools.generateSecret()
        client.requestToken(
            forEmail: item, isDuringRegistration: false, clientSecret: secret, sendAttempt: 1, nextLink: nil,
            success: { [weak self] sid in
                let new = PendingEmailPhone(type: .email, text: item, sessionId: sid!, clientSecret: secret!)
                UserDefaults.group.pendingEmailsPhones.append(new)
                self?.emails.append(new.asEmailPhone)
                completion?(.success(item))
            },
            failure: { error in
                if let mxError = MXError(nsError: error) {
                    if mxError.errcode == "M_THREEPID_IN_USE" {
                        completion?(.failure(.requestValidationAlreadyInUse))
                    } else {
                        completion?(.failure(.requestValidationFailed))
                    }
                } else {
                    completion?(.failure(.requestValidationFailed))
                }
            }
        )
    }
    
    private func requestPhoneValidation(_ item: String, completion: CompletionHandler? = nil) {
        guard let client = authViewModel.client else {
            completion?(.failure(.internal))
            return
        }
        guard item.starts(with: "+") && item.count > 10 && item.count < 15 else {
            completion?(.failure(.invalidInput))
            return
        }
        guard !phones.contains(where: { $0.text == item }) else {
            completion?(.failure(.alreadyProcessing))
            return
        }
        let secret = MXTools.generateSecret()
        client.requestToken(
            forPhoneNumber: item, isDuringRegistration: false, countryCode: nil,
            clientSecret: secret, sendAttempt: 1, nextLink: nil,
            success: { [weak self] sid, phoneWithoutPlus, submitToken in
                let new = PendingEmailPhone(type: .phone, text: item, sessionId: sid!, clientSecret: secret!)
                UserDefaults.group.pendingEmailsPhones.append(new)
                self?.phones.append(new.asEmailPhone)
                completion?(.success(item))
            },
            failure: { error in
                if let mxError = MXError(nsError: error) {
                    if mxError.errcode == "M_THREEPID_IN_USE" {
                        completion?(.failure(.requestValidationAlreadyInUse))
                    } else {
                        completion?(.failure(.requestValidationFailed))
                    }
                } else {
                    completion?(.failure(.requestValidationFailed))
                }
            }
        )
    }
    
    /// Old attempt, with different flow
    private func _requestPhoneValidation(_ item: String, completion: CompletionHandler? = nil) {
        guard let manager = authViewModel.session?.threePidAddManager else {
            completion?(.failure(.internal))
            return
        }
        guard item.starts(with: "+") && item.count > 10 && item.count < 15 else {
            completion?(.failure(.invalidInput))
            return
        }
        guard !phones.contains(where: { $0.text == item }) else {
            completion?(.failure(.alreadyProcessing))
            return
        }
        var addSession: MX3PidAddSession!
        addSession = manager.startAddPhoneNumberSession(item, countryCode: nil) { [weak self] response in
            switch response {
            case .success():
                self?.phoneAddSession[item] = addSession
                self?.phones.append(EmailPhone(type: .phone, text: item, isValid: false))
                completion?(.success(item))
            case .failure(let error):
                manager.cancel(session: addSession)
                if let mxError = MXError(nsError: error) {
                    if mxError.errcode == "M_THREEPID_IN_USE" {
                        completion?(.failure(.requestValidationAlreadyInUse))
                    } else {
                        completion?(.failure(.requestValidationFailed))
                    }
                } else {
                    completion?(.failure(.requestValidationFailed))
                }
            }
        }
    }
    
    // MARK: - Cancelling Validation
    
    func cancelValidation(for item: String, of type: EmailPhoneType, completion: CompletionHandler? = nil) {
        switch type {
        case .email: cancelEmailValidation(item, completion: completion)
        case .phone: cancelPhoneValidation(item, completion: completion)
        }
    }
    
    private func cancelEmailValidation(_ item: String, completion: CompletionHandler? = nil) {
        guard let i = emails.firstIndex(where: { $0.text == item && !$0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        emails.remove(at: i)
        UserDefaults.group.pendingEmailsPhones.removeAll(where: { $0.text == item })
        completion?(.success(item))
    }
    
    private func cancelPhoneValidation(_ item: String, completion: CompletionHandler? = nil) {
        guard let i = phones.firstIndex(where: { $0.text == item && !$0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        phones.remove(at: i)
        UserDefaults.group.pendingEmailsPhones.removeAll(where: { $0.text == item }) // Keep it just in case))
        completion?(.success(item))
    }
    
    /// Old attempt, with different flow
    private func _cancelPhoneValidation(_ item: String, completion: CompletionHandler? = nil) {
        guard let i = phones.firstIndex(where: { $0.text == item && !$0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        phones.remove(at: i)
        if let manager = authViewModel.session?.threePidAddManager, let session = phoneAddSession[item] {
            phoneAddSession[item] = nil
            manager.cancel(session: session)
        }
        UserDefaults.group.pendingEmailsPhones.removeAll(where: { $0.text == item }) // Keep it just in case))
        completion?(.success(item))
    }
    
    // MARK: - Confirming Validation
    
    func confirmValidation(for item: String, of type: EmailPhoneType, with code: String? = nil, completion: CompletionHandler? = nil) {
        switch type {
        case .email: confirmEmailValidation(item, with: code, completion: completion)
        case .phone: confirmPhoneValidation(item, with: code, completion: completion)
        }
    }
    
    private func confirmEmailValidation(_ item: String, with code: String? = nil, completion: CompletionHandler? = nil) {
        guard let client = authViewModel.client else {
            completion?(.failure(.internal))
            return
        }
        guard !authViewModel.loggedInFromStoredCredentials else {
            completion?(.failure(.needsLogin))
            return
        }
        guard let pendingIndex = UserDefaults.group.pendingEmailsPhones.firstIndex(where: { $0.text == item }) else {
            completion?(.failure(.invalidInput))
            return
        }
        let pending = UserDefaults.group.pendingEmailsPhones[pendingIndex]
        guard emails.contains(where: { $0.text == item && !$0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        client.addThirdPartyIdentifier(pending.sessionId, clientSecret: pending.clientSecret, bind: true) { [weak self] response in
            guard let i = self?.emails.firstIndex(where: { $0.text == item && !$0.isValid }) else {
                completion?(.failure(.invalidInput))
                return
            }
            switch response {
            case .success():
                self?.emails[i].isValid = true
                self?.emails[i].problem = nil
                UserDefaults.group.pendingEmailsPhones.removeAll(where: { $0.text == item })
                completion?(.success(item))
            case .failure(let error):
                self?.emails[i].problem = .confirmValidationFailed
                if let mxError = MXError(nsError: error) {
                    if mxError.errcode == "M_THREEPID_AUTH_FAILED" {
                        self?.emails[i].problem = .confirmValidationNotConfirmed
                    } else if mxError.errcode == "M_FORBIDDEN" {
                        self?.emails[i].problem = .confirmValidationForbidden
                    }
                }
                completion?(.failure(self?.emails[i].problem ?? .internal))
            }
        }
    }
    
    private func confirmPhoneValidation(_ item: String, with code: String? = nil, completion: CompletionHandler? = nil) {
        guard authViewModel.client != nil else {
            completion?(.failure(.internal))
            return
        }
        guard !authViewModel.loggedInFromStoredCredentials else {
            completion?(.failure(.needsLogin))
            return
        }
        guard let pendingIndex = UserDefaults.group.pendingEmailsPhones.firstIndex(where: { $0.text == item }) else {
            completion?(.failure(.invalidInput))
            return
        }
        let pending = UserDefaults.group.pendingEmailsPhones[pendingIndex]
        guard phones.contains(where: { $0.text == item && !$0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        guard let phoneCode = code, !phoneCode.isEmpty else {
            completion?(.failure(.noCode))
            return
        }
        // Do the request myself as matrix has insufficient library
        let params = [
            "client_secret": pending.clientSecret,
            "sid": pending.sessionId,
            "token": phoneCode
        ]
        guard let url = URL(string: API.server.baseURL + "/_matrix/identity/api/v1/validate/msisdn/submitToken") else {
            completion?(.failure(.internal))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: JSONSerialization.WritingOptions())
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let i = self?.phones.firstIndex(where: { $0.text == item && !$0.isValid }) else {
                completion?(.failure(.invalidInput))
                return
            }

            if error != nil {
                completion?(.failure(.internal))
                return
            }
            guard let data = data else {
                completion?(.failure(.internal))
                return
            }
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? [String: Any] {
                if let success = jsonResponse["success"] as? Bool, success {
                    self?.finishConfirmedPhone(pending: pending, completion: completion)
                } else if let errorCode = jsonResponse["errcode"] as? String {
                    if errorCode == "M_NO_VALID_SESSION" {
                        self?.phones[i].problem = .confirmValidationNotConfirmed
                    } else {
                        self?.phones[i].problem = .confirmValidationFailed
                    }
                    completion?(.failure(self?.emails[i].problem ?? .internal))
                } else {
                    self?.phones[i].problem = .confirmValidationFailed
                    completion?(.failure(.internal))
                }
            } else {
                self?.phones[i].problem = .confirmValidationFailed
                completion?(.failure(.internal))
            }
        }.resume()
    }
    
    private func finishConfirmedPhone(pending: PendingEmailPhone, completion: CompletionHandler? = nil) {
        let item = pending.text
        guard let client = authViewModel.client else {
            completion?(.failure(.internal))
            return
        }
        client.addThirdPartyIdentifier(pending.sessionId, clientSecret: pending.clientSecret, bind: true) { [weak self] response in
            guard let i = self?.phones.firstIndex(where: { $0.text == item && !$0.isValid }) else {
                completion?(.failure(.invalidInput))
                return
            }
            switch response {
            case .success():
                self?.phones[i].isValid = true
                self?.phones[i].problem = nil
                UserDefaults.group.pendingEmailsPhones.removeAll(where: { $0.text == item })
                completion?(.success(item))
            case .failure(let error):
                self?.phones[i].problem = .confirmValidationFailed
                if let mxError = MXError(nsError: error) {
                    if mxError.errcode == "M_THREEPID_AUTH_FAILED" {
                        self?.phones[i].problem = .confirmValidationNotConfirmed
                    } else if mxError.errcode == "M_FORBIDDEN" {
                        self?.phones[i].problem = .confirmValidationForbidden
                    } else {
                    }
                }
                completion?(.failure(self?.phones[i].problem ?? .internal))
            }
        }
    }
    
    /// Old attempt, with different flow
    private func _confirmPhoneValidation(_ item: String, with code: String? = nil, completion: CompletionHandler? = nil) {
        guard let manager = authViewModel.session?.threePidAddManager else {
            completion?(.failure(.internal))
            return
        }
        guard let addSession = phoneAddSession[item] else {
            completion?(.failure(.noAddSession))
            return
        }
        guard !authViewModel.loggedInFromStoredCredentials else {
            completion?(.failure(.needsLogin))
            return
        }
        guard phones.contains(where: { $0.text == item && !$0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        guard let phoneCode = code, !phoneCode.isEmpty else {
            completion?(.failure(.noCode))
            return
        }
        internalValidatePhone(item, with: phoneCode) { [weak self] result in
            guard let i = self?.phones.firstIndex(where: { $0.text == item && !$0.isValid }) else {
                completion?(.failure(.invalidInput))
                return
            }
            switch result {
            case .success(_):
                self?.internalAddPhone(item) { result in
                    guard let i = self?.phones.firstIndex(where: { $0.text == item && !$0.isValid }) else {
                        completion?(.failure(.invalidInput))
                        return
                    }
                    switch result {
                    case .success(_):
                        self?.phones[i].isValid = true
                        self?.phones[i].problem = nil
                        self?.phoneAddSession[item] = nil
                        manager.cancel(session: addSession)
                        UserDefaults.group.pendingEmailsPhones.removeAll(where: { $0.text == item }) // Leave for now
                        completion?(.success(item))
                    case .failure(let error):
                        self?.phones[i].problem = .confirmValidationFailed
                        if let mxError = MXError(nsError: error) {
                            if mxError.errcode == "M_THREEPID_AUTH_FAILED" {
                                self?.phones[i].problem = .confirmValidationNotConfirmed
                            } else if mxError.errcode == "M_FORBIDDEN" {
                                self?.phones[i].problem = .confirmValidationForbidden
                            }
                        }
                        completion?(.failure(self?.phones[i].problem ?? .internal))
                    }
                }
            case .failure(let error):
                    self?.phones[i].problem = .confirmValidationFailed
                    if let mxError = MXError(nsError: error) {
                        if mxError.errcode == "M_THREEPID_AUTH_FAILED" {
                            self?.phones[i].problem = .confirmValidationNotConfirmed
                        } else if mxError.errcode == "M_FORBIDDEN" {
                            self?.phones[i].problem = .confirmValidationForbidden
                        }
                    }
                    completion?(.failure(self?.phones[i].problem ?? .internal))
            }
        }
    }
    
    /// Old attempt, with different flow
    private func internalValidatePhone(_ item: String, with code: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let manager = authViewModel.session?.threePidAddManager else {
            completion(.failure(EmailPhoneError.internal))
            return
        }
        guard let addSession = phoneAddSession[item] else {
            completion(.failure(EmailPhoneError.noAddSession))
            return
        }
        manager.finaliseAddPhoneNumberSession(addSession, token: code) { response in
            switch response {
            case .success():
                completion(.success(item))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Old attempt, with different flow
    private func internalAddPhone(_ item: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let client = authViewModel.client else {
            completion(.failure(EmailPhoneError.internal))
            return
        }
        guard let addSession = phoneAddSession[item] else {
            completion(.failure(EmailPhoneError.noAddSession))
            return
        }
        client.addThirdPartyIdentifier(addSession.sid, clientSecret: addSession.clientSecret, bind: true) { response in
            switch response {
            case .success():
                completion(.success(item))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Removing Valid
    
    func removeValid(_ item: String, of type: EmailPhoneType, completion: CompletionHandler? = nil)  {
        switch type {
        case .email: removeValidEmail(item, completion: completion)
        case .phone: removeValidPhone(item, completion: completion)
        }
    }
    
    private func removeValidEmail(_ item: String, completion: CompletionHandler? = nil) {
        guard let client = authViewModel.client else {
            completion?(.failure(.internal))
            return
        }
        guard let _ = emails.firstIndex(where: { $0.text == item && $0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        client.remove3PID(address: item, medium: EmailPhoneType.email.medium) { [weak self] response in
            guard let i = self?.emails.firstIndex(where: { $0.text == item && $0.isValid }) else {
                completion?(.failure(.invalidInput))
                return
            }
            switch response {
            case .success():
                self?.emails.remove(at: i)
                completion?(.success(item))
            case .failure(_):
                self?.emails[i].problem = .removeValidFailed
                completion?(.failure(.removeValidFailed))
            }
        }
    }
    
    private func removeValidPhone(_ item: String, completion: CompletionHandler? = nil) {
        guard let client = authViewModel.client else {
            completion?(.failure(.internal))
            return
        }
        guard let _ = phones.firstIndex(where: { $0.text == item && $0.isValid }) else {
            completion?(.failure(.invalidInput))
            return
        }
        client.remove3PID(address: item, medium: EmailPhoneType.phone.medium) { [weak self] response in
            guard let i = self?.phones.firstIndex(where: { $0.text == item && $0.isValid }) else {
                completion?(.failure(.invalidInput))
                return
            }
            switch response {
            case .success():
                self?.phones.remove(at: i)
                completion?(.success(item))
            case .failure(_):
                self?.phones[i].problem = .removeValidFailed
                completion?(.failure(.removeValidFailed))
            }
        }
    }
    
}
