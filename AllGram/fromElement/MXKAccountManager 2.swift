//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

/// Posted when the user logged in with a matrix account.
/// The notification object is the new added account.
/// Posted when an existing account is logged out.
/// The notification object is the removed account./// Posted when an existing account is soft logged out.
/// The notification object is the account./// Used to identify the type of data when requesting MXKeyProviderprivate let kMXKAccountsKeyOld = "accounts"
private let kMXKAccountsKey = "accountsV2"
let kMXKAccountManagerDidAddAccountNotification = "kMXKAccountManagerDidAddAccountNotification"
let kMXKAccountManagerDidRemoveAccountNotification = "kMXKAccountManagerDidRemoveAccountNotification"
let kMXKAccountManagerDidSoftlogoutAccountNotification = "kMXKAccountManagerDidSoftlogoutAccountNotification"
let MXKAccountManagerDataType = "org.matrix.kit.MXKAccountManagerDataType"

/// `MXKAccountManager` manages a pool of `MXKAccount` instances.
class MXKAccountManager: NSObject {
    /// The list of all accounts (enabled and disabled). Each value is a `MXKAccount` instance.
    private var mxAccounts: [MXKAccount]?

    /// The class of store used to open matrix session for the accounts. This class must be conformed to MXStore protocol.
    /// By default this class is MXFileStore.

    private var _storeClass: AnyClass?
    var storeClass: AnyClass? {
        get {
            _storeClass
        }
        set(storeClass) {
            // Sanity check
            assert(storeClass is MXStore, "MXKAccountManager only manages store class that conforms to MXStore protocol")

            _storeClass = storeClass
        }
    }
    /// List of all available accounts (enabled and disabled).

    var accounts: [MXKAccount]? {
        return mxAccounts
    }
    /// List of active accounts (only enabled accounts)

    var activeAccounts: [MXKAccount]? {
        var activeAccounts = [AnyHashable](repeating: 0, count: mxAccounts?.count ?? 0)
        for account in mxAccounts ?? [] {
            if !account.disabled && !account.isSoftLogout {
                activeAccounts.append(account)
            }
        }
        return activeAccounts as? [MXKAccount]
    }
    /// The device token used for Apple Push Notification Service registration.

    var apnsDeviceToken: Data? {
        get {
            var token = UserDefaults.standard.object(forKey: "apnsDeviceToken") as? Data
            if (token?.count ?? 0) == 0 {
                UserDefaults.standard.removeObject(forKey: "apnsDeviceToken")
                token = nil
            }

            MXLogDebug("[MXKAccountManager][Push] apnsDeviceToken: %@", MXKTools.log(forPushToken: token))
            return token
        }
        set(apnsDeviceToken) {
            MXLogDebug("[MXKAccountManager][Push] setApnsDeviceToken: %@", MXKTools.log(forPushToken: apnsDeviceToken))

            let oldToken = self.apnsDeviceToken
            if (apnsDeviceToken?.count ?? 0) == 0 {
                MXLogDebug("[MXKAccountManager][Push] setApnsDeviceToken: reset APNS device token")

                if oldToken != nil {
                    // turn off the Apns flag for all accounts if any
                    for account in mxAccounts ?? [] {
                        account.enablePushNotifications(false, success: { _ in }, failure: { _ in })
                    }
                }

                UserDefaults.standard.removeObject(forKey: "apnsDeviceToken")
            } else {
                let activeAccounts = self.activeAccounts

                if oldToken == nil {
                    MXLogDebug("[MXKAccountManager][Push] setApnsDeviceToken: set APNS device token")

                    UserDefaults.standard.set(apnsDeviceToken, forKey: "apnsDeviceToken")

                    // turn on the Apns flag for all accounts, when the Apns registration succeeds for the first time
                    for account in activeAccounts ?? [] {
                        account.enablePushNotifications(true, success: { _ in }, failure: { _ in })
                    }
                } else if let apnsDeviceToken = apnsDeviceToken {
                    if !(oldToken?.isEqual(to: apnsDeviceToken) ?? false) {
                        MXLogDebug("[MXKAccountManager][Push] setApnsDeviceToken: update APNS device token")

                        var accountsWithAPNSPusher: [MXKAccount]? = []

                        // Delete the pushers related to the old token
                        for account in activeAccounts ?? [] {
                            if account.hasPusherForPushNotifications {
                                accountsWithAPNSPusher?.append(account)
                            }

                            account.enablePushNotifications(false, success: { _ in }, failure: { _ in })
                        }

                        // Update the token
                        UserDefaults.standard.set(apnsDeviceToken, forKey: "apnsDeviceToken")

                        // Refresh pushers with the new token.
                        for account in activeAccounts ?? [] {
                            if accountsWithAPNSPusher?.contains(account) ?? false {
                                MXLogDebug("[MXKAccountManager][Push] setApnsDeviceToken: Resync APNS for %@ account", account.mxCredentials?.userId)
                                account.enablePushNotifications(true, success: { _ in }, failure: { _ in })
                            } else {
                                MXLogDebug("[MXKAccountManager][Push] setApnsDeviceToken: hasPusherForPushNotifications = NO for %@ account. Do not enable Push", account.mxCredentials?.userId)
                            }
                        }
                    } else {
                        MXLogDebug("[MXKAccountManager][Push] setApnsDeviceToken: Same token. Nothing to do.")
                    }
                }
            }
        }
    }
    /// The APNS status: YES when app is registered for remote notif, and device token is known.

    var isAPNSAvailable: Bool {
        // [UIApplication isRegisteredForRemoteNotifications] tells whether your app can receive
        // remote notifications or not. Receiving remote notifications does not guarantee it will
        // display them to the user as they may have notifications set to deliver quietly.

        var isRemoteNotificationsAllowed = false

        let sharedApplication = UIApplication.perform(#selector(UIApplication.shared)) as? UIApplication
        if let sharedApplication = sharedApplication {
            isRemoteNotificationsAllowed = sharedApplication.isRegisteredForRemoteNotifications

            MXLogDebug("[MXKAccountManager][Push] isAPNSAvailable: The user %@ remote notification", (isRemoteNotificationsAllowed ? "allowed" : "denied"))
        }

        let isAPNSAvailable = isRemoteNotificationsAllowed && apnsDeviceToken != nil

        MXLogDebug("[MXKAccountManager][Push] isAPNSAvailable: %@", NSNumber(value: isAPNSAvailable))

        return isAPNSAvailable
    }
    /// The device token used for Push notifications registration (PushKit support).

    var pushDeviceToken: Data? {
        var token = UserDefaults.standard.object(forKey: "pushDeviceToken") as? Data
        if (token?.count ?? 0) == 0 {
            UserDefaults.standard.removeObject(forKey: "pushDeviceToken")
            UserDefaults.standard.removeObject(forKey: "pushOptions")
            token = nil
        }

        MXLogDebug("[MXKAccountManager][Push] pushDeviceToken: %@", MXKTools.log(forPushToken: token))
        return token
    }
    /// The current options of the Push notifications based on PushKit.

    var pushOptions: [AnyHashable : Any]? {
        let pushOptions = UserDefaults.standard.object(forKey: "pushOptions") as? [AnyHashable : Any]

        MXLogDebug("[MXKAccountManager][Push] pushOptions: %@", pushOptions)
        return pushOptions
    }
    /// The PushKit status: YES when app is registered for push notif, and push token is known.

    var isPushAvailable: Bool {
        // [UIApplication isRegisteredForRemoteNotifications] tells whether your app can receive
        // remote notifications or not. Receiving remote notifications does not guarantee it will
        // display them to the user as they may have notifications set to deliver quietly.

        var isRemoteNotificationsAllowed = false

        let sharedApplication = UIApplication.perform(#selector(UIApplication.shared)) as? UIApplication
        if let sharedApplication = sharedApplication {
            isRemoteNotificationsAllowed = sharedApplication.isRegisteredForRemoteNotifications

            MXLogDebug("[MXKAccountManager][Push] isPushAvailable: The user %@ remote notification", (isRemoteNotificationsAllowed ? "allowed" : "denied"))
        }

        let isPushAvailable = isRemoteNotificationsAllowed && pushDeviceToken != nil

        MXLogDebug("[MXKAccountManager][Push] isPushAvailable: %@", NSNumber(value: isPushAvailable))
        return isPushAvailable
    }

    /// Retrieve the MXKAccounts manager.
    /// - Returns: the MXKAccounts manager.
    static let sharedManagerSharedAccountManager: MXKAccountManager? = nil

    class func shared() -> MXKAccountManager? {
        // `dispatch_once()` call was converted to a static variable initializer

        return sharedManagerSharedAccountManager
    }

    override init() {
        super.init()
        storeClass = MXFileStore.self

        // Migrate old account file to new format
        migrateAccounts()

        // Load existing accounts from local storage
        loadAccounts()
    }

    deinit {
        mxAccounts = nil
    }

    /// Check for each enabled account if a matrix session is already opened.
    /// Open a matrix session for each enabled account which doesn't have a session.
    /// The developper must set 'storeClass' before the first call of this method 
    /// if the default class is not suitable.

    // MARK: -

    func prepareSessionForActiveAccounts() {
        for account in mxAccounts ?? [] {
            // Check whether the account is enabled. Open a new matrix session if none.
            if !account.disabled && !account.isSoftLogout && account.mxSession == nil {
                MXLogDebug("[MXKAccountManager] openSession for %@ account", account.mxCredentials?.userId)

                weak var store: MXStore? = storeClass?.init() as? MXStore
                account.openSession(with: store)
            }
        }
    }

    /// Save a snapshot of the current accounts.
    func saveAccounts() {
        let startDate = Date()

        MXLogDebug("[MXKAccountManager] saveAccounts...")

        var data = Data()
        let encoder = NSKeyedArchiver(forWritingWith: data)

        encoder.encode(mxAccounts, forKey: "mxAccounts")

        encoder.finishEncoding()

        if let encrypt = encryptData(data) {
            data.setData(encrypt)
        }

        let result = NSData(data: data).write(toFile: accountFile() ?? "", atomically: true)

        MXLogDebug("[MXKAccountManager] saveAccounts. Done (result: %@) in %.0fms", NSNumber(value: result), Date().timeIntervalSince(startDate) * 1000)
    }

    /// Add an account and save the new account list. Optionally a matrix session may be opened for the provided account.
    /// - Parameters:
    ///   - account: a matrix account.
    ///   - openSession: YES to open a matrix session (this value is ignored if the account is disabled).
    func add(_ account: MXKAccount?, andOpenSession openSession: Bool) {
        MXLogDebug("[MXKAccountManager] login (%@)", account?.mxCredentials?.userId)

        if let account = account {
            mxAccounts?.append(account)
        }
        saveAccounts()

        // Check conditions to open a matrix session
        if openSession && !(account?.disabled ?? false) {
            // Open a new matrix session by default
            MXLogDebug("[MXKAccountManager] openSession for %@ account", account?.mxCredentials?.userId)

            weak var store: MXStore? = storeClass?.init() as? MXStore
            account?.openSession(with: store)
        }

        // Post notification
        NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountManagerDidAddAccountNotification), object: account, userInfo: nil)
    }

    /// Remove the provided account and save the new account list. This method is used in case of logout.
    /// @note equivalent to `removeAccount:sendLogoutRequest:completion:` method with `sendLogoutRequest` parameter to YES
    /// - Parameters:
    ///   - account: a matrix account.
    ///   - completion: the block to execute at the end of the operation.
    func remove(_ theAccount: MXKAccount?, completion: @escaping () -> Void) {
        remove(theAccount, sendLogoutRequest: true, completion: completion)
    }

    /// Remove the provided account and save the new account list. This method is used in case of logout or account deactivation.
    /// - Parameters:
    ///   - account: a matrix account.
    ///   - sendLogoutRequest: Indicate whether send logout request to homeserver.
    ///   - completion: the block to execute at the end of the operation.
    func remove(
        _ theAccount: MXKAccount?,
        sendLogoutRequest: Bool,
        completion: @escaping () -> Void
    ) {
        MXLogDebug("[MXKAccountManager] logout (%@), send logout request to homeserver: %d", theAccount?.mxCredentials?.userId, sendLogoutRequest)

        // Close session and clear associated store.
        theAccount?.logoutSendingServerRequest(sendLogoutRequest) { [self] in

            // Retrieve the corresponding account in the internal array
            var removedAccount: MXKAccount? = nil

            for account in mxAccounts ?? [] {
                if account.mxCredentials?.userId == theAccount?.mxCredentials?.userId {
                    removedAccount = account
                    break
                }
            }

            if let removedAccount = removedAccount {
                mxAccounts?.removeAll { $0 as AnyObject === removedAccount as AnyObject }

                saveAccounts()

                // Post notification
                NotificationCenter.default.post(name: NSNotification.Name(kMXKAccountManagerDidRemoveAccountNotification), object: removedAccount, userInfo: nil)
            }

            if completion != nil {
                completion()
            }

        }
    }

    /// Log out and remove all the existing accounts
    /// - Parameter completion: the block to execute at the end of the operation.
    func logout(withCompletion completion: @escaping () -> Void) {
        // Logout one by one the existing accounts
        if (mxAccounts?.count ?? 0) != 0 {
            remove(mxAccounts?.last) { [self] in

                // loop: logout the next existing account (if any)
                logout(withCompletion: completion)

            }

            return
        }

        let sharedUserDefaults = MXKAppSettings.standard().sharedUserDefaults

        // Remove APNS device token
        UserDefaults.standard.removeObject(forKey: "apnsDeviceToken")

        // Remove Push device token
        UserDefaults.standard.removeObject(forKey: "pushDeviceToken")
        UserDefaults.standard.removeObject(forKey: "pushOptions")

        // Be sure that no account survive in local storage
        UserDefaults.standard.removeObject(forKey: kMXKAccountsKey)
        sharedUserDefaults?.removeObject(forKey: kMXKAccountsKey)
        do {
            try FileManager.default.removeItem(atPath: accountFile() ?? "")
        } catch {
        }

        if completion != nil {
            completion()
        }
    }

    /// Soft logout an account.
    /// - Parameter account: a matrix account.
    func softLogout(_ account: MXKAccount?) {
        account?.softLogout()
        NotificationCenter.default.post(
            name: NSNotification.Name(kMXKAccountManagerDidSoftlogoutAccountNotification),
            object: account,
            userInfo: nil)
    }

    /// Hydrate an existing account by using the credentials provided.
    /// This updates account credentials and restarts the account session
    /// If the credentials belong to a different user from the account already stored,
    /// the old account will be cleared automatically.
    /// - Parameters:
    ///   - account: a matrix account.
    ///   - credentials: the new credentials.
    func hydrateAccount(_ account: MXKAccount?, with credentials: MXCredentials?) {
        MXLogDebug("[MXKAccountManager] hydrateAccount: %@", account?.mxCredentials?.userId)

        if account?.mxCredentials?.userId == credentials?.userId {
            // Restart the account
            account?.hydrate(with: credentials)

            MXLogDebug("[MXKAccountManager] hydrateAccount: Open session")

            weak var store: MXStore? = storeClass?.init() as? MXStore
            account?.openSession(with: store)

            NotificationCenter.default.post(
                name: NSNotification.Name(kMXKAccountManagerDidAddAccountNotification),
                object: account,
                userInfo: nil)
        } else {
            MXLogDebug("[MXKAccountManager] hydrateAccount: Credentials given for another account: %@", credentials?.userId)

            // Logout the old account and create a new one with the new credentials
            remove(account, sendLogoutRequest: true) { _ in }

            let newAccount = MXKAccount(credentials: credentials)
            add(newAccount, andOpenSession: true)
        }
    }

    /// Retrieve the account for a user id.
    /// - Parameter userId: the user id.
    /// - Returns: the user's account (nil if no account exist).
    func account(forUserId userId: String?) -> MXKAccount? {
        for account in mxAccounts ?? [] {
            if account.mxCredentials?.userId == userId {
                return account
            }
        }
        return nil
    }

    /// Retrieve an account that knows the room with the passed id or alias.
    /// Note: The method is not accurate as it returns the first account that matches.
    /// - Parameter roomIdOrAlias: the room id or alias.
    /// - Returns: the user's account. Nil if no account matches.
    func accountKnowingRoom(withRoomIdOrAlias roomIdOrAlias: String?) -> MXKAccount? {
        var theAccount: MXKAccount? = nil

        let activeAccounts = self.activeAccounts

        for account in activeAccounts ?? [] {
            if roomIdOrAlias?.hasPrefix("#") ?? false {
                if account.mxSession?.room(withAlias: roomIdOrAlias) {
                    theAccount = account
                    break
                }
            } else {
                if account.mxSession?.room(withRoomId: roomIdOrAlias) {
                    theAccount = account
                    break
                }
            }
        }
        return theAccount
    }

    /// Retrieve an account that knows the user with the passed id.
    /// Note: The method is not accurate as it returns the first account that matches.
    /// - Parameter userId: the user id.
    /// - Returns: the user's account. Nil if no account matches.
    func accountKnowingUser(withUserId userId: String?) -> MXKAccount? {
        var theAccount: MXKAccount? = nil

        let activeAccounts = self.activeAccounts

        for account in activeAccounts ?? [] {
            if account.mxSession?.user(withUserId: userId) {
                theAccount = account
                break
            }
        }
        return theAccount
    }

    /// Set the push token and the potential push options.
    /// For example, for clients that want to go & fetch the body of the event themselves anyway,
    /// the key-value `format: event_id_only` may be used in `pushOptions` dictionary to tell the
    /// HTTP pusher to send just the event_id of the event it's notifying about, the room id and
    /// the notification counts.
    /// - Parameters:
    ///   - pushDeviceToken: the push token.
    ///   - pushOptions: dictionary of the push options (may be nil).
    func setPushDeviceToken(_ pushDeviceToken: Data?, withPushOptions pushOptions: [AnyHashable : Any]?) {
        MXLogDebug("[MXKAccountManager][Push] setPushDeviceToken: %@ withPushOptions: %@", MXKTools.log(forPushToken: pushDeviceToken), pushOptions)

        let oldToken = self.pushDeviceToken
        if (pushDeviceToken?.count ?? 0) == 0 {
            MXLogDebug("[MXKAccountManager][Push] setPushDeviceToken: Reset Push device token")

            if oldToken != nil {
                // turn off the Push flag for all accounts if any
                for account in mxAccounts ?? [] {
                    account.enablePushKitNotifications(false, success: {
                        //  make sure pusher really removed before losing token.
                        UserDefaults.standard.removeObject(forKey: "pushDeviceToken")
                        UserDefaults.standard.removeObject(forKey: "pushOptions")
                    }, failure: { _ in })
                }
            }
        } else {
            let activeAccounts = self.activeAccounts

            if oldToken == nil {
                MXLogDebug("[MXKAccountManager][Push] setPushDeviceToken: Set Push device token")

                UserDefaults.standard.set(pushDeviceToken, forKey: "pushDeviceToken")
                if let pushOptions = pushOptions {
                    UserDefaults.standard.set(pushOptions, forKey: "pushOptions")
                } else {
                    UserDefaults.standard.removeObject(forKey: "pushOptions")
                }

                // turn on the Push flag for all accounts
                for account in activeAccounts ?? [] {
                    account.enablePushKitNotifications(true, success: { _ in }, failure: { _ in })
                }
            } else if let pushDeviceToken = pushDeviceToken {
                if !(oldToken?.isEqual(to: pushDeviceToken) ?? false) {
                    MXLogDebug("[MXKAccountManager][Push] setPushDeviceToken: Update Push device token")

                    var accountsWithPushKitPusher: [MXKAccount]? = []

                    // Delete the pushers related to the old token
                    for account in activeAccounts ?? [] {
                        if account.hasPusherForPushKitNotifications {
                            accountsWithPushKitPusher?.append(account)
                        }

                        account.enablePushKitNotifications(false, success: { _ in }, failure: { _ in })
                    }

                    // Update the token
                    UserDefaults.standard.set(pushDeviceToken, forKey: "pushDeviceToken")
                    if let pushOptions = pushOptions {
                        UserDefaults.standard.set(pushOptions, forKey: "pushOptions")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "pushOptions")
                    }

                    // Refresh pushers with the new token.
                    for account in activeAccounts ?? [] {
                        if accountsWithPushKitPusher?.contains(account) ?? false {
                            MXLogDebug("[MXKAccountManager][Push] setPushDeviceToken: Resync Push for %@ account", account.mxCredentials?.userId)
                            account.enablePushKitNotifications(true, success: { _ in }, failure: { _ in })
                        } else {
                            MXLogDebug("[MXKAccountManager][Push] setPushDeviceToken: hasPusherForPushKitNotifications = NO for %@ account. Do not enable Push", account.mxCredentials?.userId)
                        }
                    }
                } else {
                    MXLogDebug("[MXKAccountManager][Push] setPushDeviceToken: Same token. Nothing to do.")
                }
            }
        }
    }

    // MARK: -

    // Return the path of the file containing stored MXAccounts array
    func accountFile() -> String? {
        let matrixKitCacheFolder = MXKAppSettings.cacheFolder()
        return URL(fileURLWithPath: matrixKitCacheFolder).appendingPathComponent(kMXKAccountsKey).path
    }

    func loadAccounts() {
        MXLogDebug("[MXKAccountManager] loadAccounts")

        let accountFile = self.accountFile()
        if FileManager.default.fileExists(atPath: accountFile ?? "") {
            let startDate = Date()

            var error: Error? = nil
            var filecontent: Data? = nil
            do {
                filecontent = try NSData(contentsOfFile: accountFile ?? "", options: [.alwaysMapped, .uncached]) as Data?
            } catch {
            }

            if error == nil {
                // Decrypt data if encryption method is provided
                let unciphered = decryptData(filecontent)
                var decoder: NSKeyedUnarchiver? = nil
                if let unciphered = unciphered {
                    decoder = NSKeyedUnarchiver(forReadingWith: unciphered)
                }
                mxAccounts = decoder?.decodeObject(forKey: "mxAccounts") as? [MXKAccount]

                if mxAccounts == nil && MXKeyProvider.sharedInstance().isEncryptionAvailableForData(ofType: MXKAccountManagerDataType) {
                    // This happens if the V2 file has not been encrypted -> read file content then save encrypted accounts
                    MXLogDebug("[MXKAccountManager] loadAccounts. Failed to read decrypted data: reading file data without encryption.")
                    if let filecontent = filecontent {
                        decoder = NSKeyedUnarchiver(forReadingWith: filecontent)
                    }
                    mxAccounts = decoder?.decodeObject(forKey: "mxAccounts") as? [MXKAccount]

                    if mxAccounts != nil {
                        MXLogDebug("[MXKAccountManager] loadAccounts. saving encrypted accounts")
                        saveAccounts()
                    }
                }
            }

            MXLogDebug("[MXKAccountManager] loadAccounts. %tu accounts loaded in %.0fms", (mxAccounts?.count ?? 0), Date().timeIntervalSince(startDate) * 1000)
        } else {
            // Migration of accountData from sharedUserDefaults to a file
            let sharedDefaults = MXKAppSettings.standard().sharedUserDefaults

            var accountData = sharedDefaults?.object(forKey: kMXKAccountsKey) as? Data
            if accountData == nil {
                // Migration of accountData from [NSUserDefaults standardUserDefaults], the first location storage
                accountData = UserDefaults.standard.object(forKey: kMXKAccountsKey) as? Data
            }

            if let accountData = accountData {
                if let unarchive = NSKeyedUnarchiver.unarchiveObject(with: accountData) as? [Any] {
                    mxAccounts = unarchive as? [MXKAccount]
                }
                saveAccounts()

                MXLogDebug("[MXKAccountManager] loadAccounts: performed data migration")

                // Now that data has been migrated, erase old location of accountData
                UserDefaults.standard.removeObject(forKey: kMXKAccountsKey)

                sharedDefaults?.removeObject(forKey: kMXKAccountsKey)
            }
        }

        if mxAccounts == nil {
            MXLogDebug("[MXKAccountManager] loadAccounts. No accounts")
            mxAccounts = []
        }
    }

    /// Force the account manager to reload existing accounts from the local storage.
    /// The account manager is supposed to handle itself the list of the accounts.
    /// Call this method only when an account has been changed from an other application from the same group.
    func forceReloadAccounts() {
        MXLogDebug("[MXKAccountManager] Force reload existing accounts from local storage")
        loadAccounts()
    }

    func encryptData(_ data: Data?) -> Data? {
        // Exceptions are not caught as the key is always needed if the KeyProviderDelegate
        // is provided.
        let keyData = MXKeyProvider.sharedInstance().requestKeyForData(ofType: MXKAccountManagerDataType, isMandatory: true, expectedKeyType: kAes)
        if keyData != nil && (keyData is MXAesKeyData) {
            let aesKey = keyData as? MXAesKeyData
            var cipher: Data? = nil
            do {
                cipher = try MXAes.encrypt(data, aesKey: aesKey?.key, iv: aesKey?.iv)
            } catch {
            }
            return cipher
        }

        MXLogDebug("[MXKAccountManager] encryptData: no key method provided for encryption.")
        return data
    }

    func decryptData(_ data: Data?) -> Data? {
        // Exceptions are not cached as the key is always needed if the KeyProviderDelegate
        // is provided.
        let keyData = MXKeyProvider.sharedInstance().requestKeyForData(ofType: MXKAccountManagerDataType, isMandatory: true, expectedKeyType: kAes)
        if keyData != nil && (keyData is MXAesKeyData) {
            let aesKey = keyData as? MXAesKeyData
            var decrypt: Data? = nil
            do {
                decrypt = try MXAes.decrypt(data, aesKey: aesKey?.key, iv: aesKey?.iv)
            } catch {
            }
            return decrypt
        }

        MXLogDebug("[MXKAccountManager] decryptData: no key method provided for decryption.")
        return data
    }

    func migrateAccounts() {
        let pathOld = URL(fileURLWithPath: MXKAppSettings.cacheFolder()).appendingPathComponent(kMXKAccountsKeyOld).path
        let pathNew = URL(fileURLWithPath: MXKAppSettings.cacheFolder()).appendingPathComponent(kMXKAccountsKey).path
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: pathOld) {
            if !fileManager.fileExists(atPath: pathNew) {
                MXLogDebug("[MXKAccountManager] migrateAccounts: reading account")
                mxAccounts = NSKeyedUnarchiver.unarchiveObject(withFile: pathOld) as? [MXKAccount]
                MXLogDebug("[MXKAccountManager] migrateAccounts: writing to accountV2")
                saveAccounts()
            }

            MXLogDebug("[MXKAccountManager] migrateAccounts: removing account")
            do {
                try fileManager.removeItem(atPath: pathOld)
            } catch {
            }
        }
    }
}