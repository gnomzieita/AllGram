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

private let kMXAppGroupID = "group.org.matrix"

/// `MXKAppSettings` represents the application settings. Most of them are used to handle matrix session data.
/// The shared object `standardAppSettings` provides the default application settings defined in `standardUserDefaults`.
/// Any property change of this shared settings is reported into `standardUserDefaults`.
/// Developper may define their own `MXKAppSettings` instances to handle specific setting values without impacting the shared object.
class AppSettings: NSObject {
    static let shared = AppSettings()
    
    // MARK: - /sync filter

    /// Lazy load room members when /syncing with the homeserver.

    private var _syncWithLazyLoadOfRoomMembers = false
    var syncWithLazyLoadOfRoomMembers: Bool {
        get {
            let storedValue = UserDefaults.standard.object(forKey: "syncWithLazyLoadOfRoomMembers2")
            if let storedValue = storedValue {
                return (storedValue as? NSNumber)?.boolValue ?? false
            } else {
                // Enabled by default
                return true
            }
        }
        set(syncWithLazyLoadOfRoomMembers) {
            UserDefaults.standard.set(syncWithLazyLoadOfRoomMembers, forKey: "syncWithLazyLoadOfRoomMembers2")
        }
    }
    // MARK: - Room display

    /// Display all received events in room history (Only recognized events are displayed, presently `custom` events are ignored).
    /// This boolean value is defined in shared settings object with the key: `showAllEventsInRoomHistory`.
    /// Return NO if no value is defined.

    private var _showAllEventsInRoomHistory = false
    var showAllEventsInRoomHistory: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "showAllEventsInRoomHistory")
        }
        set(boolValue) {
            UserDefaults.standard.set(boolValue, forKey: "showAllEventsInRoomHistory")
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
            return UserDefaults.standard.bool(forKey: "showRedactionsInRoomHistory")
        }
        set(boolValue) {
            UserDefaults.standard.set(boolValue, forKey: "showRedactionsInRoomHistory")
        }
    }
    
    /// Display unsupported/unexpected events in room history.
    /// This boolean value is defined in shared settings object with the key: `showUnsupportedEventsInRoomHistory`.
    /// Return NO if no value is defined.
    private var _showUnsupportedEventsInRoomHistory = false
    var showUnsupportedEventsInRoomHistory: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "showUnsupportedEventsInRoomHistory")
        }
        set(boolValue) {
            UserDefaults.standard.set(boolValue, forKey: "showUnsupportedEventsInRoomHistory")
        }
    }
    /// Scheme with which to open HTTP links. e.g. if this is set to "googlechrome", any http:// links displayed in a room will be rewritten to use the googlechrome:// scheme.
    /// Defaults to "http".

    private var _httpLinkScheme: String?
    var httpLinkScheme: String? {
        get {
            let ret = UserDefaults.standard.string(forKey: "httpLinkScheme")
            return ret ?? "http"
        }
        set(stringValue) {
            UserDefaults.standard.set(stringValue, forKey: "httpLinkScheme")
        }
    }
    /// Scheme with which to open HTTPS links. e.g. if this is set to "googlechromes", any https:// links displayed in a room will be rewritten to use the googlechromes:// scheme.
    /// Defaults to "https".

    private var _httpsLinkScheme: String?
    var httpsLinkScheme: String? {
        get {
            let ret = UserDefaults.standard.string(forKey: "httpsLinkScheme")
            return ret ?? "https"
        }
        set(stringValue) {
            UserDefaults.standard.set(stringValue, forKey: "httpsLinkScheme")
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
            return UserDefaults.standard.bool(forKey: "sortRoomMembersUsingLastSeenTime")
        }
        set(boolValue) {
            UserDefaults.standard.set(boolValue, forKey: "sortRoomMembersUsingLastSeenTime")
        }
    }
    /// Show left members in room member list.
    /// This boolean value is defined in shared settings object with the key: `showLeftMembersInRoomMemberList`.
    /// Return NO if no value is defined.

    private var _showLeftMembersInRoomMemberList = false
    var showLeftMembersInRoomMemberList: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "showLeftMembersInRoomMemberList")
        }
        set(boolValue) {
            UserDefaults.standard.set(boolValue, forKey: "showLeftMembersInRoomMemberList")
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
            return UserDefaults.standard.bool(forKey: "syncLocalContacts")
        }
        set(boolValue) {
            UserDefaults.standard.set(boolValue, forKey: "syncLocalContacts")
        }
    }
    /// Return YES if the user has been already asked for local contacts sync permission.
    /// This boolean value is defined in shared settings object with the key: `syncLocalContactsRequested`.
    /// Return NO if no value is defined.

    private var _syncLocalContactsPermissionRequested = false
    var syncLocalContactsPermissionRequested: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "syncLocalContactsPermissionRequested")
        }
        set(theSyncLocalContactsPermissionRequested) {
            UserDefaults.standard.set(theSyncLocalContactsPermissionRequested, forKey: "syncLocalContactsPermissionRequested")
        }
    }
    /// The current selected country code for the phonebook.
    /// This value is defined in shared settings object with the key: `phonebookCountryCode`.
    /// Return the SIM card information (if any) if no default value is defined.

    private var _phonebookCountryCode: String?
    var phonebookCountryCode: String? {
        get {
            let res = UserDefaults.standard.string(forKey: "phonebookCountryCode")
            
            // does not exist : try to get the SIM card information
            if res == nil {
                // get the current MCC
                let netInfo = CTTelephonyNetworkInfo()
  
                if let carriers = netInfo.serviceSubscriberCellularProviders, !carriers.isEmpty {
                    var countryCode, countryCode2 : String?
                    for (service, ctCarrier) in carriers {
                        guard let cc = ctCarrier.isoCountryCode?.uppercased() else {
                            continue
                        }
                        if nil == netInfo.serviceCurrentRadioAccessTechnology?[service] {
                            countryCode2 = cc
                        } else {
                            countryCode = cc
                            break
                        }
                    }
                    if let result = countryCode ?? countryCode2 {
                        self.phonebookCountryCode = result
                        return result
                    }
                }
            }

            return res
        }
        set(stringValue) {
            UserDefaults.standard.set(stringValue, forKey: "phonebookCountryCode")
        }
    }
    // MARK: - Matrix users

    /// Color associated to online matrix users.
    /// This color value is defined in shared settings object with the key: `presenceColorForOnlineUser`.
    /// The default color is `[UIColor greenColor]`.

    private var _presenceColorForOnlineUser: UIColor?
    var presenceColorForOnlineUser: UIColor? {
        get {
            let ud = UserDefaults.standard
            let rgbValue = ud.integer(forKey: "presenceColorForOnlineUser")
            if 0 == rgbValue && nil == ud.object(forKey: "presenceColorForOnlineUser") {
                return .green
            }
            return Tools.color(withRGBValue: rgbValue)
        }
        set(color) {
            if let color = color {
                let rgbValue = Tools.rgbValue(with: color)
                UserDefaults.standard.set(rgbValue, forKey: "presenceColorForOnlineUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "presenceColorForOnlineUser")
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

            let rgbValue = UserDefaults.standard.integer(forKey: "presenceColorForUnavailableUser")
            if rgbValue != 0 {
                color = Tools.color(withRGBValue: rgbValue)
            } else {
                color = UIColor.yellow
            }

            return color
        }
        set(color) {
            if let color = color {
                let rgbValue = Tools.rgbValue(with: color)
                UserDefaults.standard.set(rgbValue, forKey: "presenceColorForUnavailableUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "presenceColorForUnavailableUser")
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

            let rgbValue = UserDefaults.standard.integer(forKey: "presenceColorForOfflineUser")
            if rgbValue != 0 {
                color = Tools.color(withRGBValue: rgbValue)
            } else {
                color = UIColor.red
            }
 
            return color
        }
        set(color) {
            if let color = color {
                let rgbValue = Tools.rgbValue(with: color)
                UserDefaults.standard.set(rgbValue, forKey: "presenceColorForOfflineUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "presenceColorForOfflineUser")
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
            if let storedValue = UserDefaults.standard.object(forKey: "enableCallKit") {
                return (storedValue as? NSNumber)?.boolValue ?? false
            } else {
                return true
            }
        }
        set(enable) {
            UserDefaults.standard.set(enable, forKey: "enableCallKit")
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
        if let cacheFolder = cacheFolder, !FileManager.default.fileExists(atPath: cacheFolder) {
            do {
                try FileManager.default.createDirectory(atPath: cacheFolder, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
            }
        }

        return cacheFolder
    }

    // MARK: -

    private override init() {
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

            _eventsFilterForMessages = [
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
            ] as [MXEventTypeString]


            // List all the event types, except kMXEventTypeStringPresence which are not related to a specific room.
            _allEventTypesForMessages = [
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
            ] as [MXEventTypeString]

            messageDetailsAllowSharing = true
            messageDetailsAllowSaving = true
            messageDetailsAllowCopyingMedia = true
            messageDetailsAllowPastingMedia = true
            outboundGroupSessionKeyPreSharingStrategy = .mxkKeyPreSharingWhenTyping
    }

    /// Restore the default values.
    func reset() {
        let keys = ["syncWithLazyLoadOfRoomMembers2", "showAllEventsInRoomHistory", "showRedactionsInRoomHistory",
                    "showUnsupportedEventsInRoomHistory", "sortRoomMembersUsingLastSeenTime", "showLeftMembersInRoomMemberList",
                    "syncLocalContactsPermissionRequested", "syncLocalContacts", "phonebookCountryCode",
                    "presenceColorForOnlineUser", "presenceColorForUnavailableUser", "presenceColorForOfflineUser",
                    "httpLinkScheme", "httpsLinkScheme", "enableCallKit"
        ]
        
        // Flush shared user defaults
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Add event types to `eventsFilterForMessages` and `eventsFilterForMessages`.
    /// - Parameter eventTypes: the event types to add.
    func addSupportedEventTypes(_ eventTypes: [String]?) {
        if let eventTypes = eventTypes as [MXEventTypeString]? {
            if _eventsFilterForMessages == nil {
                _eventsFilterForMessages = eventTypes
            } else {
                _eventsFilterForMessages!.append(contentsOf: eventTypes)
            }
            
            if _allEventTypesForMessages  == nil {
                _allEventTypesForMessages = eventTypes
            } else {
                _allEventTypesForMessages!.append(contentsOf: eventTypes)
            }
        }
    }

    /// Remove event types from `eventsFilterForMessages` and `eventsFilterForMessages`.
    /// - Parameter eventTypes: the event types to remove.
    func removeSupportedEventTypes(_ eventTypes: [String]?) {
        guard let eventTypes = eventTypes as [MXEventTypeString]? else { return }

        _eventsFilterForMessages?.removeAll(where: { eventTypes.contains($0) })
        _allEventTypesForMessages?.removeAll(where: { eventTypes.contains($0) })
    }
}
