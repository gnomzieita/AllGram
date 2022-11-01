//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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

import CoreTelephony
import MatrixSDK

enum KeyPreSharingStrategy : Int {
    case mxkKeyPreSharingNone = 0
    case mxkKeyPreSharingWhenEnteringRoom = 1
    case mxkKeyPreSharingWhenTyping = 2
}

// get ISO country name
private var standardAppSettings: AppSettings? = nil
private let kMXAppGroupID = "group.org.matrix"

/// `MXKAppSettings` represents the application settings. Most of them are used to handle matrix session data.
/// The shared object `standardAppSettings` provides the default application settings defined in `standardUserDefaults`.
/// Any property change of this shared settings is reported into `standardUserDefaults`.
/// Developper may define their own `MXKAppSettings` instances to handle specific setting values without impacting the shared object.
class AppSettings: NSObject {
    // MARK: - /sync filter

    /// Lazy load room members when /syncing with the homeserver.

    private var _syncWithLazyLoadOfRoomMembers = false
    var syncWithLazyLoadOfRoomMembers: Bool {
        get {
            if self == AppSettings.standard() {
                let storedValue = UserDefaults.standard.object(forKey: "syncWithLazyLoadOfRoomMembers2")
                if let storedValue = storedValue {
                    return (storedValue as? NSNumber)?.boolValue ?? false
                } else {
                    // Enabled by default
                    return true
                }
            } else {
                return _syncWithLazyLoadOfRoomMembers
            }
        }
        set(syncWithLazyLoadOfRoomMembers) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(syncWithLazyLoadOfRoomMembers, forKey: "syncWithLazyLoadOfRoomMembers2")
            } else {
                #warning("Swiftify: Skipping redundant initializing to itself")
                //syncWithLazyLoadOfRoomMembers = syncWithLazyLoadOfRoomMembers
            }
        }
    }
    // MARK: - Room display

    /// Display all received events in room history (Only recognized events are displayed, presently `custom` events are ignored).
    /// This boolean value is defined in shared settings object with the key: `showAllEventsInRoomHistory`.
    /// Return NO if no value is defined.

    private var _showAllEventsInRoomHistory = false
    var showAllEventsInRoomHistory: Bool {
        get {
            if self == AppSettings.standard() {
                return UserDefaults.standard.bool(forKey: "showAllEventsInRoomHistory")
            } else {
                return _showAllEventsInRoomHistory
            }
        }
        set(boolValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(boolValue, forKey: "showAllEventsInRoomHistory")
            } else {
                _showAllEventsInRoomHistory = boolValue
            }
        }
    }
    /// The types of events allowed to be displayed in room history.
    /// Its value depends on `showAllEventsInRoomHistory`.

    private var _eventsFilterForMessages: [MXEventTypeString]?
    var eventsFilterForMessages: [MXEventTypeString]? {
        if showAllEventsInRoomHistory {
            // Consider all the event types
            return allEventTypesForMessages
        } else {
            // Display only a subset of events
            return _eventsFilterForMessages
        }
    }
    /// All the event types which may be displayed in the room history.

    private var _allEventTypesForMessages: [MXEventTypeString]?
    var allEventTypesForMessages: [MXEventTypeString]? {
        return _allEventTypesForMessages
    }
    /// Display redacted events in room history.
    /// This boolean value is defined in shared settings object with the key: `showRedactionsInRoomHistory`.
    /// Return NO if no value is defined.

    private var _showRedactionsInRoomHistory = false
    var showRedactionsInRoomHistory: Bool {
        get {
            if self == AppSettings.standard() {
                return UserDefaults.standard.bool(forKey: "showRedactionsInRoomHistory")
            } else {
                return _showRedactionsInRoomHistory
            }
        }
        set(boolValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(boolValue, forKey: "showRedactionsInRoomHistory")
            } else {
                _showRedactionsInRoomHistory = boolValue
            }
        }
    }
    /// Display unsupported/unexpected events in room history.
    /// This boolean value is defined in shared settings object with the key: `showUnsupportedEventsInRoomHistory`.
    /// Return NO if no value is defined.

    private var _showUnsupportedEventsInRoomHistory = false
    var showUnsupportedEventsInRoomHistory: Bool {
        get {
            if self == AppSettings.standard() {
                return UserDefaults.standard.bool(forKey: "showUnsupportedEventsInRoomHistory")
            } else {
                return _showUnsupportedEventsInRoomHistory
            }
        }
        set(boolValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(boolValue, forKey: "showUnsupportedEventsInRoomHistory")
            } else {
                _showUnsupportedEventsInRoomHistory = boolValue
            }
        }
    }
    /// Scheme with which to open HTTP links. e.g. if this is set to "googlechrome", any http:// links displayed in a room will be rewritten to use the googlechrome:// scheme.
    /// Defaults to "http".

    private var _httpLinkScheme: String?
    var httpLinkScheme: String? {
        get {
            if self == AppSettings.standard() {
                var ret = UserDefaults.standard.string(forKey: "httpLinkScheme")
                if ret == nil {
                    ret = "http"
                }
                return ret
            } else {
                return _httpLinkScheme
            }
        }
        set(stringValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(stringValue, forKey: "httpLinkScheme")
            } else {
                _httpLinkScheme = stringValue
            }
        }
    }
    /// Scheme with which to open HTTPS links. e.g. if this is set to "googlechromes", any https:// links displayed in a room will be rewritten to use the googlechromes:// scheme.
    /// Defaults to "https".

    private var _httpsLinkScheme: String?
    var httpsLinkScheme: String? {
        get {
            if self == AppSettings.standard() {
                var ret = UserDefaults.standard.string(forKey: "httpsLinkScheme")
                if ret == nil {
                    ret = "https"
                }
                return ret
            } else {
                return _httpsLinkScheme
            }
        }
        set(stringValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(stringValue, forKey: "httpsLinkScheme")
            } else {
                _httpsLinkScheme = stringValue
            }
        }
    }
    /// Indicate to hide un-decryptable events before joining the room. Default is `NO`.
    var hidePreJoinedUndecryptableEvents = false
    /// Indicate to hide un-decryptable events in the room. Default is `NO`.
    var hideUndecryptableEvents = false
    /// Indicates the strategy for sharing the outbound session key to other devices of the room
    var outboundGroupSessionKeyPreSharingStrategy: KeyPreSharingStrategy!
    // MARK: - Room members

    /// Sort room members by considering their presence.
    /// Set NO to sort members in alphabetic order.
    /// This boolean value is defined in shared settings object with the key: `sortRoomMembersUsingLastSeenTime`.
    /// Return YES if no value is defined.

    private var _sortRoomMembersUsingLastSeenTime = false
    var sortRoomMembersUsingLastSeenTime: Bool {
        get {
            if self == AppSettings.standard() {
                return UserDefaults.standard.bool(forKey: "sortRoomMembersUsingLastSeenTime")
            } else {
                return _sortRoomMembersUsingLastSeenTime
            }
        }
        set(boolValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(boolValue, forKey: "sortRoomMembersUsingLastSeenTime")
            } else {
                _sortRoomMembersUsingLastSeenTime = boolValue
            }
        }
    }
    /// Show left members in room member list.
    /// This boolean value is defined in shared settings object with the key: `showLeftMembersInRoomMemberList`.
    /// Return NO if no value is defined.

    private var _showLeftMembersInRoomMemberList = false
    var showLeftMembersInRoomMemberList: Bool {
        get {
            if self == AppSettings.standard() {
                return UserDefaults.standard.bool(forKey: "showLeftMembersInRoomMemberList")
            } else {
                return _showLeftMembersInRoomMemberList
            }
        }
        set(boolValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(boolValue, forKey: "showLeftMembersInRoomMemberList")
            } else {
                _showLeftMembersInRoomMemberList = boolValue
            }
        }
    }
    /// Flag to allow sharing a message or not. Default value is YES.
    var messageDetailsAllowSharing = false
    /// Flag to allow saving a message or not. Default value is YES.
    var messageDetailsAllowSaving = false
    /// Flag to allow copying a media/file or not. Default value is YES.
    var messageDetailsAllowCopyingMedia = false
    /// Flag to allow pasting a media/file or not. Default value is YES.
    var messageDetailsAllowPastingMedia = false
    // MARK: - Contacts

    /// Return YES if the user allows the local contacts sync.
    /// This boolean value is defined in shared settings object with the key: `syncLocalContacts`.
    /// Return NO if no value is defined.

    private var _syncLocalContacts = false
    var syncLocalContacts: Bool {
        get {
            if self == AppSettings.standard() {
                return UserDefaults.standard.bool(forKey: "syncLocalContacts")
            } else {
                return _syncLocalContacts
            }
        }
        set(boolValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(boolValue, forKey: "syncLocalContacts")
            } else {
                _syncLocalContacts = boolValue
            }
        }
    }
    /// Return YES if the user has been already asked for local contacts sync permission.
    /// This boolean value is defined in shared settings object with the key: `syncLocalContactsRequested`.
    /// Return NO if no value is defined.

    private var _syncLocalContactsPermissionRequested = false
    var syncLocalContactsPermissionRequested: Bool {
        get {
            if self == AppSettings.standard() {
                return UserDefaults.standard.bool(forKey: "syncLocalContactsPermissionRequested")
            } else {
                return _syncLocalContactsPermissionRequested
            }
        }
        set(theSyncLocalContactsPermissionRequested) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(theSyncLocalContactsPermissionRequested, forKey: "syncLocalContactsPermissionRequested")
            } else {
                _syncLocalContactsPermissionRequested = theSyncLocalContactsPermissionRequested
            }
        }
    }
    /// The current selected country code for the phonebook.
    /// This value is defined in shared settings object with the key: `phonebookCountryCode`.
    /// Return the SIM card information (if any) if no default value is defined.

    private var _phonebookCountryCode: String?
    var phonebookCountryCode: String? {
        get {
            var res = _phonebookCountryCode

            if self == AppSettings.standard() {
                res = UserDefaults.standard.string(forKey: "phonebookCountryCode")
            }

            // does not exist : try to get the SIM card information
            if res == nil {
                // get the current MCC
                let netInfo = CTTelephonyNetworkInfo()
                let carrier = netInfo.subscriberCellularProvider

                if let carrier = carrier {
                    res = carrier.isoCountryCode?.uppercased()

                    if let res = res {
                        self.phonebookCountryCode = res
                    }
                }
            }

            return res
        }
        set(stringValue) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(stringValue, forKey: "phonebookCountryCode")
            } else {
                _phonebookCountryCode = stringValue
            }
        }
    }
    // MARK: - Matrix users

    /// Color associated to online matrix users.
    /// This color value is defined in shared settings object with the key: `presenceColorForOnlineUser`.
    /// The default color is `[UIColor greenColor]`.

    private var _presenceColorForOnlineUser: UIColor?
    var presenceColorForOnlineUser: UIColor? {
        get {
            var color = _presenceColorForOnlineUser

            if self == AppSettings.standard() {
                let rgbValue = UserDefaults.standard.integer(forKey: "presenceColorForOnlineUser")
                if rgbValue != 0 {
                    color = Tools.color(withRGBValue: rgbValue)
                } else {
                    color = UIColor.green
                }
            }
            return color
        }
        set(color) {
            if self == AppSettings.standard() {
                if let color = color {
                    let rgbValue = Tools.rgbValue(with: color)
                    UserDefaults.standard.set(rgbValue, forKey: "presenceColorForOnlineUser")
                } else {
                    UserDefaults.standard.removeObject(forKey: "presenceColorForOnlineUser")
                }
            } else {
                _presenceColorForOnlineUser = color ?? UIColor.green
            }
        }
    }
    /// Color associated to unavailable matrix users.
    /// This color value is defined in shared settings object with the key: `presenceColorForUnavailableUser`.
    /// The default color is `[UIColor yellowColor]`.

    private var _presenceColorForUnavailableUser: UIColor?
    var presenceColorForUnavailableUser: UIColor? {
        get {
            var color = _presenceColorForUnavailableUser

            if self == AppSettings.standard() {
                let rgbValue = UserDefaults.standard.integer(forKey: "presenceColorForUnavailableUser")
                if rgbValue != 0 {
                    color = Tools.color(withRGBValue: rgbValue)
                } else {
                    color = UIColor.yellow
                }
            }
            return color
        }
        set(color) {
            if self == AppSettings.standard() {
                if let color = color {
                    let rgbValue = Tools.rgbValue(with: color)
                    UserDefaults.standard.set(rgbValue, forKey: "presenceColorForUnavailableUser")
                } else {
                    UserDefaults.standard.removeObject(forKey: "presenceColorForUnavailableUser")
                }
            } else {
                _presenceColorForUnavailableUser = color ?? UIColor.yellow
            }
        }
    }
    /// Color associated to offline matrix users.
    /// This color value is defined in shared settings object with the key: `presenceColorForOfflineUser`.
    /// The default color is `[UIColor redColor]`.

    private var _presenceColorForOfflineUser: UIColor?
    var presenceColorForOfflineUser: UIColor? {
        get {
            var color = _presenceColorForOfflineUser

            if self == AppSettings.standard() {
                let rgbValue = UserDefaults.standard.integer(forKey: "presenceColorForOfflineUser")
                if rgbValue != 0 {
                    color = Tools.color(withRGBValue: rgbValue)
                } else {
                    color = UIColor.red
                }
            }

            return color
        }
        set(color) {
            if self == AppSettings.standard() {
                if let color = color {
                    let rgbValue = Tools.rgbValue(with: color)
                    UserDefaults.standard.set(rgbValue, forKey: "presenceColorForOfflineUser")
                } else {
                    UserDefaults.standard.removeObject(forKey: "presenceColorForOfflineUser")
                }
            } else {
                _presenceColorForOfflineUser = color ?? UIColor.red
            }
        }
    }
    // MARK: - Notifications

    /// Flag to allow PushKit pushers or not. Default value is `NO`.
    var allowPushKitPushers = false
    /// A localization key used when registering the default notification payload.
    /// This key will be translated and displayed for APNS notifications as the body
    /// content, unless it is modified locally by a Notification Service Extension.
    /// The default value for this setting is "MESSAGE". Changes are *not* persisted.
    /// Updating the value after MXKAccount has called `enableAPNSPusher:success:failure:`
    /// will have no effect.
    var notificationBodyLocalizationKey: String?
    // MARK: - Calls

    /// Return YES if the user enable CallKit support.
    /// This boolean value is defined in shared settings object with the key: `enableCallKit`.
    /// Return YES if no value is defined.

    private var _enableCallKit = false
    var enableCallKit: Bool {
        get {
            if self == AppSettings.standard() {
                let storedValue = UserDefaults.standard.object(forKey: "enableCallKit")
                if let storedValue = storedValue {
                    return (storedValue as? NSNumber)?.boolValue ?? false
                } else {
                    return true
                }
            } else {
                return _enableCallKit
            }
        }
        set(enable) {
            if self == AppSettings.standard() {
                UserDefaults.standard.set(enable, forKey: "enableCallKit")
            } else {
                _enableCallKit = enable
            }
        }
    }
    // MARK: - Shared userDefaults

    /// A userDefaults object that is shared within the application group. The application group identifier
    /// is retrieved from MXSDKOptions sharedInstance (see `applicationGroupIdentifier` property).
    /// The default group is "group.org.matrix".

    private var _sharedUserDefaults: UserDefaults?
    var sharedUserDefaults: UserDefaults? {
        if _sharedUserDefaults != nil {
            // Check whether the current group id did not change.
            var applicationGroup = MXSDKOptions.sharedInstance().applicationGroupIdentifier
            if applicationGroup!.count == 0 {
                applicationGroup = kMXAppGroupID
            }

            if currentApplicationGroup != applicationGroup {
                // Reset the existing shared object
                _sharedUserDefaults = nil
            }
        }

        if _sharedUserDefaults == nil {
            currentApplicationGroup = MXSDKOptions.sharedInstance().applicationGroupIdentifier
            if (currentApplicationGroup?.count ?? 0) == 0 {
                currentApplicationGroup = kMXAppGroupID
            }

            _sharedUserDefaults = UserDefaults(suiteName: currentApplicationGroup)
        }

        return _sharedUserDefaults
    }
    private var currentApplicationGroup: String?

    // MARK: - Class methods

    /// Return the shared application settings object. These settings are retrieved/stored in the shared defaults object (`[NSUserDefaults standardUserDefaults]`).
    static func standard() -> AppSettings? {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            if standardAppSettings == nil {
                standardAppSettings = super.init() as? AppSettings
            }
        }
        return standardAppSettings
    }

    /// Return the folder to use for caching MatrixKit data.
    static func cacheFolder() -> String? {
        var cacheFolder: String?

        // Check for a potential application group id
        let applicationGroupIdentifier = MXSDKOptions.sharedInstance().applicationGroupIdentifier
        if applicationGroupIdentifier != "" {
            let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier!)
            cacheFolder = sharedContainerURL?.path
        } else {
            let cacheDirList = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).map(\.path)
            cacheFolder = cacheDirList[0]
        }

        // Use a dedicated cache folder for MatrixKit
        cacheFolder = URL(fileURLWithPath: cacheFolder ?? "").appendingPathComponent("MatrixKit").path

        // Make sure the folder exists so that it can be used
        if cacheFolder != nil && !FileManager.default.fileExists(atPath: cacheFolder ?? "") {
            var error: Error?
            do {
                try FileManager.default.createDirectory(atPath: cacheFolder ?? "", withIntermediateDirectories: true, attributes: nil)
            } catch {
            }
            if let error = error {
                print(">[cacheFolder] cacheFolder: Error: Cannot create MatrixKit folder at %@. Error: %@", cacheFolder, error)
            }
        }

        return cacheFolder
    }

    // MARK: -

    override init() {
        super.init()
            syncWithLazyLoadOfRoomMembers = true

            // Use presence to sort room members by default
            if UserDefaults.standard.object(forKey: "sortRoomMembersUsingLastSeenTime") == nil {
                UserDefaults.standard.set(true, forKey: "sortRoomMembersUsingLastSeenTime")
            }
            hidePreJoinedUndecryptableEvents = false
            hideUndecryptableEvents = false
            sortRoomMembersUsingLastSeenTime = true

            presenceColorForOnlineUser = UIColor.green
            presenceColorForUnavailableUser = UIColor.yellow
            presenceColorForOfflineUser = UIColor.red

            httpLinkScheme = "http"
            httpsLinkScheme = "https"

            allowPushKitPushers = false
            notificationBodyLocalizationKey = "MESSAGE"
            enableCallKit = true

            eventsFilterForMessages = [
                kMXEventTypeStringRoomCreate,
                kMXEventTypeStringRoomName,
                kMXEventTypeStringRoomTopic,
                kMXEventTypeStringRoomMember,
                kMXEventTypeStringRoomEncrypted,
                kMXEventTypeStringRoomEncryption,
                kMXEventTypeStringRoomHistoryVisibility,
                kMXEventTypeStringRoomMessage,
                kMXEventTypeStringRoomThirdPartyInvite,
                kMXEventTypeStringRoomGuestAccess,
                kMXEventTypeStringRoomJoinRules,
                kMXEventTypeStringCallInvite,
                kMXEventTypeStringCallAnswer,
                kMXEventTypeStringCallHangup,
                kMXEventTypeStringCallReject,
                kMXEventTypeStringCallNegotiate,
                kMXEventTypeStringSticker,
                kMXEventTypeStringKeyVerificationCancel,
                kMXEventTypeStringKeyVerificationDone
            ]


            // List all the event types, except kMXEventTypeStringPresence which are not related to a specific room.
            allEventTypesForMessages = [
                kMXEventTypeStringRoomName,
                kMXEventTypeStringRoomTopic,
                kMXEventTypeStringRoomMember,
                kMXEventTypeStringRoomCreate,
                kMXEventTypeStringRoomEncrypted,
                kMXEventTypeStringRoomEncryption,
                kMXEventTypeStringRoomJoinRules,
                kMXEventTypeStringRoomPowerLevels,
                kMXEventTypeStringRoomAliases,
                kMXEventTypeStringRoomHistoryVisibility,
                kMXEventTypeStringRoomMessage,
                kMXEventTypeStringRoomMessageFeedback,
                kMXEventTypeStringRoomRedaction,
                kMXEventTypeStringRoomThirdPartyInvite,
                kMXEventTypeStringRoomRelatedGroups,
                kMXEventTypeStringReaction,
                kMXEventTypeStringCallInvite,
                kMXEventTypeStringCallAnswer,
                kMXEventTypeStringCallSelectAnswer,
                kMXEventTypeStringCallHangup,
                kMXEventTypeStringCallReject,
                kMXEventTypeStringCallNegotiate,
                kMXEventTypeStringSticker,
                kMXEventTypeStringKeyVerificationCancel,
                kMXEventTypeStringKeyVerificationDone
            ]

            messageDetailsAllowSharing = true
            messageDetailsAllowSaving = true
            messageDetailsAllowCopyingMedia = true
            messageDetailsAllowPastingMedia = true
            outboundGroupSessionKeyPreSharingStrategy = .mxkKeyPreSharingWhenTyping
    }

    /// Restore the default values.
    func reset() {
        if self == AppSettings.standard() {
            // Flush shared user defaults
            UserDefaults.standard.removeObject(forKey: "syncWithLazyLoadOfRoomMembers2")

            UserDefaults.standard.removeObject(forKey: "showAllEventsInRoomHistory")
            UserDefaults.standard.removeObject(forKey: "showRedactionsInRoomHistory")
            UserDefaults.standard.removeObject(forKey: "showUnsupportedEventsInRoomHistory")

            UserDefaults.standard.removeObject(forKey: "sortRoomMembersUsingLastSeenTime")
            UserDefaults.standard.removeObject(forKey: "showLeftMembersInRoomMemberList")

            UserDefaults.standard.removeObject(forKey: "syncLocalContactsPermissionRequested")
            UserDefaults.standard.removeObject(forKey: "syncLocalContacts")
            UserDefaults.standard.removeObject(forKey: "phonebookCountryCode")

            UserDefaults.standard.removeObject(forKey: "presenceColorForOnlineUser")
            UserDefaults.standard.removeObject(forKey: "presenceColorForUnavailableUser")
            UserDefaults.standard.removeObject(forKey: "presenceColorForOfflineUser")

            UserDefaults.standard.removeObject(forKey: "httpLinkScheme")
            UserDefaults.standard.removeObject(forKey: "httpsLinkScheme")

            UserDefaults.standard.removeObject(forKey: "enableCallKit")
        } else {
            syncWithLazyLoadOfRoomMembers = true

            showAllEventsInRoomHistory = false
            showRedactionsInRoomHistory = false
            showUnsupportedEventsInRoomHistory = false

            sortRoomMembersUsingLastSeenTime = true
            showLeftMembersInRoomMemberList = false

            syncLocalContactsPermissionRequested = false
            syncLocalContacts = false
            phonebookCountryCode = nil

            presenceColorForOnlineUser = UIColor.green
            presenceColorForUnavailableUser = UIColor.yellow
            presenceColorForOfflineUser = UIColor.red

            httpLinkScheme = "http"
            httpsLinkScheme = "https"

            enableCallKit = true
        }
    }

    /// Add event types to `eventsFilterForMessages` and `eventsFilterForMessages`.
    /// - Parameter eventTypes: the event types to add.
    func addSupportedEventTypes(_ eventTypes: [String]?) {
        if let eventTypes = eventTypes {
            eventsFilterForMessages?.append(contentsOf: eventTypes)
            allEventTypesForMessages?.append(contentsOf: eventTypes)
        }
    }

    /// Remove event types from `eventsFilterForMessages` and `eventsFilterForMessages`.
    /// - Parameter eventTypes: the event types to remove.
    func removeSupportedEventTypes(_ eventTypes: [String]?) {
        eventsFilterForMessages = eventsFilterForMessages?.filter({ !eventTypes.contains($0) })
        allEventTypesForMessages = allEventTypesForMessages?.filter({ !eventTypes.contains($0) })
    }
}
