//
//  NotificationSettingsViewModel.swift
//  AllGram
//
//  Created by Eugene Ned on 19.07.2022.
//

import Foundation
import Combine

class NotificationSettingsViewModel: ObservableObject{
    @Published var state: State
    @Published var showAlert = false
    @Published var enableChatNotifications = false {
        didSet {
            updateNotificationSettings(enableChatNotifications, .chat)
        }
    }
    @Published var enableClubNotifications = false {
        didSet {
            updateNotificationSettings(enableClubNotifications, .club)
        }
    }
    @Published var enableMeetingNotifications = false {
        didSet {
            updateNotificationSettings(enableMeetingNotifications, .meeting)
        }
    }
    private var cancellables = Set<AnyCancellable>()
    
    
    enum State: Equatable {
        case loading(LoadingType)
        case received
        case error(CustomError)
    }
    
    enum LoadingType {
        case downloading, uploading
    }
    
    enum CustomError {
        case downloading, uploading
    }
    
    init() {
        self.state = .loading(.downloading)
        self.getCurrentNotificationSettings()
        self.$state
            .sink { newValue in
                if case .error = newValue {
                    self.showAlert = true
                }
            }
            .store(in: &self.cancellables)
    }
    
    
    func getCurrentNotificationSettings() {
        self.state = .loading(.downloading)
        guard let accessToken = AuthViewModel.shared.session?.credentials.accessToken else {
            return
        }
        NewApiManager.shared.getNotificationSettings(accessToken: accessToken)
            .sink { [weak self] result in
                switch result {
                case .finished:
                    self?.state = .received
                case .failure:
                    self?.state = .error(.downloading)
                }
            } receiveValue: { [weak self] response in
                self?.enableChatNotifications = response["chat"] as? Bool ?? false
                self?.enableClubNotifications = response["club"] as? Bool ?? false
                self?.enableMeetingNotifications = response["meeting"] as? Bool ?? false
                self?.state = .received
            }.store(in: &cancellables)
    }
    
    private func updateNotificationSettings(_ value: Bool,_ type: NotificationsType) {
        self.state = .loading(.uploading)
        guard let accessToken = AuthViewModel.shared.session?.credentials.accessToken else {
            return
        }
        NewApiManager.shared.updateNotificationSettings(value, type, accessToken: accessToken)
            .sink { [weak self] result in
                switch result {
                case .finished:
                    self?.state = .received
                case .failure:
                    self?.state = .error(.uploading)
                }
            } receiveValue: { [weak self] response in
                self?.state = .received
            }.store(in: &cancellables)
    }
}
