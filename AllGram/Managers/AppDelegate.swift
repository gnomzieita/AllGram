//
//  AppDelegate.swift
//  AllGram
//
//  Created by Vladyslav on 16.12.2021.
//

import Foundation
import UIKit
import MatrixSDK
import MetricKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    static var shared: UIApplicationDelegate? {
        UIApplication.shared.delegate
    }
    
    private var observers = [NSObjectProtocol]()
    private var matrixSessions = Set<MXSession>()
    
    func application(_ app: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        MXMetricManager.shared.add(self)
        SettingsManager.applicationLaunchCounter += 1
        SettingsManager.checkVersion()
        
        // Add matrix observers, and initialize matrix sessions if the app is not launched in background.
        initMatrixSessions()
        
        JitsiService.shared.application(app, didFinishLaunchingWithOptions: launchOptions)
        
        // Clear badge count on launch
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // When app launches by tap on notification
        let notificationOption = launchOptions?[.remoteNotification]
        if let notification = notificationOption as? [String: AnyObject],
           let aps = notification["aps"] as? [String: AnyObject],
           !aps.isEmpty {
            UserNotifications.shared.appLaunchedWithNotification(notification)
        }
        
        UserNotifications.shared.requestAuthorization()
        PushNotifications.shared.appState = .launched
        
        return true
    }
    
    // MARK: - Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        UserNotifications.shared.updateDeviceToken(token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        UserNotifications.shared.failedToRegister(with: error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let aps = userInfo["aps"] as? [String: AnyObject], !aps.isEmpty else {
            completionHandler(.failed)
            return
        }
        UserNotifications.shared.gotNotificationWhileRunning(userInfo)
        ? completionHandler(.newData)
        : completionHandler(.noData)
    }
    
    // MARK: - Background Task
    
    private var backgroundTaskToKeepAppAlive: UIBackgroundTaskIdentifier?
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundTaskToKeepAppAlive = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Also clear badge count on reopening app
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        guard let task = backgroundTaskToKeepAppAlive else { return }
        UIApplication.shared.endBackgroundTask(task)
    }
}

private extension AppDelegate {
    func initMatrixSessions() {
        let nc = NotificationCenter.default
        let observer = nc.addObserver(forName: .mxSessionStateDidChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, let mxSession = notification.object as? MXSession else {
                return
            }
            switch mxSession.state {
            case .initialised:
                self.addMatrixSession(mxSession)
            case .closed:
                self.removeMatrixSession(mxSession)
            default: break
            }
        }
        observers.append(observer)
    }
    
    func addMatrixSession(_ session: MXSession) {
        WidgetManager.shared.add(matrixSession: session)
        matrixSessions.insert(session)
    }
    func removeMatrixSession(_ session: MXSession) {
        WidgetManager.shared.remove(matrixSession: session)
        matrixSessions.remove(session)
    }
}

extension AppDelegate: MXMetricManagerSubscriber {
  func didReceive(_ payloads: [MXMetricPayload]) {

  }

  func didReceive(_ payloads: [MXDiagnosticPayload]) {

  }
}
