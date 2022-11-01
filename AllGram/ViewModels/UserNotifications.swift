//
//  UserNotifications.swift
//  AllGram
//
//  Created by Alex Pirog on 14.04.2022.
//

import UIKit
import Combine
import UserNotifications

class UserNotifications {
    static let shared = UserNotifications()
    private init() { }
    
    deinit {
        cancellables.removeAll()
    }
    
    /// Set this to `true` to register device token or to `false` to unregister one
    private var needsRegistration = false {
        didSet {
            guard let token = deviceToken else {
                return
            }
            guard let accessToken = authViewModel?.session?.credentials.accessToken else {
                return
            }
            if needsRegistration {
                
                UserDefaults.standard.set(token, forKey: "PushToken")
                
                NewApiManager.shared.registerAPNToken(token, type: .default, accessToken: accessToken)
                    .sink {  result in

                    } receiveValue: { response in
                    }
                    .store(in: &cancellables)
            } else {
                NewApiManager.shared.unregisterAPNToken(token, type: .default, accessToken: accessToken)
                    .sink { result in

                    } receiveValue: {  response in
                    }
                    .store(in: &cancellables)
            }
        }
    }
    
    private var deviceToken: String?
    private weak var authViewModel: AuthViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    func subscribe(with authVM: AuthViewModel) {
        authViewModel = authVM
        needsRegistration = true
    }
    
    func unsubscribe() {
        needsRegistration = false
    }
    
    func updateDeviceToken(_ token: String) {
        guard deviceToken != token else { return }
        deviceToken = token
        needsRegistration = true
    }
    
    func failedToRegister(with error: Error) {
        needsRegistration = false
    }
    
    func appLaunchedWithNotification(_ notification: [String: AnyObject]) {
    }
    
    func gotNotificationWhileRunning(_ userInfo: [AnyHashable: Any]) -> Bool {
        // Return true when new data successfully downloaded
        // or false when there was no new data to download
        return false
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) {
                [weak self] granted, error in

                guard granted else { return }
                self?.getNotificationSettings()
            }
    }
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    

}
