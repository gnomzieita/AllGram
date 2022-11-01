//  Converted to Swift 5.4 by Swiftify v5.4.25812 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd

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

import MatrixKit
import OLMKit

let kSettingsViewControllerPhoneBookCountryCellId = "kSettingsViewControllerPhoneBookCountryCellId"
enum SectionTag : Int {
    case signOut = 0
    case userSettings
    case security
    case notifications
    case calls
    case discovery
    case identityServer
    case localContacts
    case ignoredUsers
    case integrations
    case userInterface
    case advanced
    case other
    case labs
    case flair
    case deactivateAccount
}

enum UserSettings : Int {
    case profilePictureIndex = 0
    case displaynameIndex
    case changePasswordIndex
    case firstNameIndex
    case surnameIndex
    case addEmailIndex
    case addPhonenumberIndex
    case threepidsInformationIndex
    case inviteFriendsIndex
}

enum UserSettings : Int {
    case emailsOffset = 2000
    case phonenumbersOffset = 1000
}

enum NotificationSettings : Int {
    case enablePushIndex = 0
    case systemSettings
    case showDecodedContent
    case globalSettingsIndex
    case pinMissedNotificationsIndex
    case pinUnreadIndex
    case defaultSettingsIndex
    case mentionAndKeywordsSettingsIndex
    case otherSettingsIndex
}

enum Calls : Int {
    case enableStunServerFallbackIndex = 0
    case stunServerFallbackDescriptionIndex
}

enum Integrations : Int {
    case index
    case descriptionIndex
}

enum LocalContacts : Int {
    case syncIndex
    case phonebookCountryIndex
}

enum UserInterface : Int {
    case languageIndex = 0
    case themeIndex
}

enum IdentityServer : Int {
    case index
    case descriptionIndex
}

enum Other : Int {
    case versionIndex = 0
    case olmVersionIndex
    case copyrightIndex
    case termConditionsIndex
    case privacyIndex
    case thirdPartyIndex
    case showNsfwRoomsIndex
    case crashReportIndex
    case enableRageshakeIndex
    case markAllAsReadIndex
    case clearCacheIndex
    case reportBugIndex
}

enum EnumA : Int {
    case labs_ENABLE_RINGING_FOR_GROUP_CALLS_INDEX = 0
}

enum EnumC : Int {
    case security_BUTTON_INDEX = 0
}

typealias blockSettingsViewController_onReadyToDestroy = () -> Void
// MARK: - SettingsViewController

class SettingsViewController: MXKTableViewController, UITextFieldDelegate, MXKCountryPickerViewControllerDelegate, MXKLanguagePickerViewControllerDelegate, MXKDataSourceDelegate, DeactivateAccountViewControllerDelegate, NotificationSettingsCoordinatorBridgePresenterDelegate, SecureBackupSetupCoordinatorBridgePresenterDelegate, SignOutAlertPresenterDelegate, SingleImagePickerPresenterDelegate, SettingsDiscoveryTableViewSectionDelegate, SettingsDiscoveryViewModelCoordinatorDelegate, SettingsIdentityServerCoordinatorBridgePresenterDelegate, TableViewSectionsDelegate {
    // Current alert (if any).
    private var currentAlert: UIAlertController?
    // listener
    private var removedAccountObserver: Any?
    private var accountUserInfoObserver: Any?
    private var pushInfoUpdateObserver: Any?
    private var notificationCenterWillUpdateObserver: Any?
    private var notificationCenterDidUpdateObserver: Any?
    private var notificationCenterDidFailObserver: Any?
    // profile updates
    // avatar
    private var newAvatarImage: UIImage?
    // the avatar image has been uploaded
    private var uploadedAvatarURL: String?
    // new display name
    private var newDisplayName: String?
    // password update
    private var currentPasswordTextField: UITextField?
    private var newPasswordTextField1: UITextField?
    private var newPasswordTextField2: UITextField?
    private var savePasswordAction: UIAlertAction?
    // New email address to bind
    private var newEmailTextField: UITextField?
    // New phone number to bind
    private var newPhoneNumberCell: TableViewCellWithPhoneNumberTextField?
    private var newPhoneNumberCountryPicker: CountryPickerViewController?
    private var newPhoneNumber: NBPhoneNumber?
    // Flair: the groups data source
    private var groupsDataSource: GroupsDataSource?
    // Observe kAppDelegateDidTapStatusBarNotification to handle tap on clock status bar.
    private var kAppDelegateDidTapStatusBarNotificationObserver: Any?
    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    private var kThemeServiceDidChangeThemeNotificationObserver: Any?
    // Postpone destroy operation when saving, pwd reset or email binding is in progress
    private var isSavingInProgress = false
    private var isResetPwdInProgress = false
    private var is3PIDBindingInProgress = false
    private var onReadyToDestroyHandler: blockSettingsViewController_onReadyToDestroy?
    //
    private var resetPwdAlertController: UIAlertController?
    private var keepNewEmailEditing = false
    private var keepNewPhoneNumberEditing = false
    // The current pushed view controller
    private var pushedViewController: UIViewController?
    private var identityServerSettingsCoordinatorBridgePresenter: SettingsIdentityServerCoordinatorBridgePresenter?

    /// Flag indicating whether the user is typing an email to bind.

    private var _newEmailEditingEnabled = false
    private var newEmailEditingEnabled: Bool {
        get {
            _newEmailEditingEnabled
        }
        set(newEmailEditingEnabled) {
            if newEmailEditingEnabled != _newEmailEditingEnabled {
                // Update the flag
                _newEmailEditingEnabled = newEmailEditingEnabled

                if !newEmailEditingEnabled {
                    // Dismiss the keyboard
                    newEmailTextField?.resignFirstResponder()
                    newEmailTextField = nil
                }

                DispatchQueue.main.async(execute: { [self] in

                    tableView.beginUpdates()

                    // Refresh the corresponding table view cell with animation
                    let addEmailIndexPath = tableViewSections?.exactIndexPath(
                        forRowTag: UserSettings.addEmailIndex,
                        sectionTag: SectionTag.userSettings)
                    if let addEmailIndexPath = addEmailIndexPath {
                        tableView.reloadRows(at: [addEmailIndexPath], with: .fade)
                    }

                    tableView.endUpdates()
                })
            }
        }
    }
    /// Flag indicating whether the user is typing a phone number to bind.

    private var _newPhoneEditingEnabled = false
    private var newPhoneEditingEnabled: Bool {
        get {
            _newPhoneEditingEnabled
        }
        set(newPhoneEditingEnabled) {
            if newPhoneEditingEnabled != _newPhoneEditingEnabled {
                // Update the flag
                _newPhoneEditingEnabled = newPhoneEditingEnabled

                if !newPhoneEditingEnabled {
                    // Dismiss the keyboard
                    newPhoneNumberCell?.mxkTextField.resignFirstResponder()
                    newPhoneNumberCell = nil
                }

                DispatchQueue.main.async(execute: { [self] in

                    tableView.beginUpdates()

                    // Refresh the corresponding table view cell with animation
                    let addPhoneIndexPath = tableViewSections?.exactIndexPath(
                        forRowTag: UserSettings.addPhonenumberIndex,
                        sectionTag: SectionTag.userSettings)
                    if let addPhoneIndexPath = addPhoneIndexPath {
                        tableView.reloadRows(at: [addPhoneIndexPath], with: .fade)
                    }

                    tableView.endUpdates()
                })
            }
        }
    }
    /// The current `UNUserNotificationCenter` notification settings for the app.
    private var systemNotificationSettings: UNNotificationSettings?
    private weak var deactivateAccountViewController: DeactivateAccountViewController?
    private var notificationSettingsBridgePresenter: NotificationSettingsCoordinatorBridgePresenter?
    private var signOutAlertPresenter: SignOutAlertPresenter?
    private weak var signOutButton: UIButton?
    private var imagePickerPresenter: SingleImagePickerPresenter?
    private var settingsDiscoveryViewModel: SettingsDiscoveryViewModel?
    private var settingsDiscoveryTableViewSection: SettingsDiscoveryTableViewSection?
    private var discoveryThreePidDetailsPresenter: SettingsDiscoveryThreePidDetailsCoordinatorBridgePresenter?
    private var secureBackupSetupCoordinatorBridgePresenter: SecureBackupSetupCoordinatorBridgePresenter?
    private var tableViewSections: TableViewSections?
    private var inviteFriendsPresenter: InviteFriendsPresenter?
    private var crossSigningSetupCoordinatorBridgePresenter: CrossSigningSetupCoordinatorBridgePresenter?
    private var reauthenticationCoordinatorBridgePresenter: ReauthenticationCoordinatorBridgePresenter?

    private var _userInteractiveAuthenticationService: UserInteractiveAuthenticationService?
    private var userInteractiveAuthenticationService: UserInteractiveAuthenticationService? {
        if _userInteractiveAuthenticationService == nil {
            _userInteractiveAuthenticationService = createUserInteractiveAuthenticationService()
        }

        return _userInteractiveAuthenticationService
    }

    class func instantiate() -> Self {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let settingsViewController = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController
        return settingsViewController!
    }

    func finalizeInit() {
        super.finalizeInit()

        // Setup `MXKViewControllerHandling` properties
        enableBarTintColorStatusChange = false
        rageShakeManager = RageShakeManager.shared()

        isSavingInProgress = false
        isResetPwdInProgress = false
        is3PIDBindingInProgress = false
    }

    func updateSections() {
        var tmpSections = [AnyHashable](repeating: 0, count: SectionTag.deactivateAccount.rawValue + 1) as? [Section]

        let sectionSignOut = Section(tag: SectionTag.signOut)
        sectionSignOut.addRow(withTag: 0)
        tmpSections?.append(sectionSignOut)

        let sectionUserSettings = Section(tag: SectionTag.userSettings)
        sectionUserSettings.addRow(withTag: UserSettings.profilePictureIndex)
        sectionUserSettings.addRow(withTag: UserSettings.displaynameIndex)
        if RiotSettings.shared.settingsScreenShowChangePassword {
            sectionUserSettings.addRow(withTag: UserSettings.changePasswordIndex)
        }
        if BuildSettings.settingsScreenShowUserFirstName {
            sectionUserSettings.addRow(withTag: UserSettings.firstNameIndex)
        }
        if BuildSettings.settingsScreenShowUserSurname {
            sectionUserSettings.addRow(withTag: UserSettings.surnameIndex)
        }
        let account = MXKAccountManager.shared().activeAccounts.first as? MXKAccount
        //  add linked emails
        for index in 0..<(account?.linkedEmails.count ?? 0) {
            sectionUserSettings.addRow(withTag: UserSettings.emailsOffset.rawValue + index)
        }
        //  add linked phone numbers
        for index in 0..<(account?.linkedPhoneNumbers.count ?? 0) {
            sectionUserSettings.addRow(withTag: UserSettings.phonenumbersOffset.rawValue + index)
        }
        if BuildSettings.settingsScreenAllowAddingEmailThreepids {
            sectionUserSettings.addRow(withTag: UserSettings.addEmailIndex)
        }
        if BuildSettings.settingsScreenAllowAddingPhoneThreepids {
            sectionUserSettings.addRow(withTag: UserSettings.addPhonenumberIndex)
        }
        if BuildSettings.settingsScreenShowThreepidExplanatory {
            sectionUserSettings.addRow(withTag: UserSettings.threepidsInformationIndex)
        }
        if RiotSettings.shared.settingsScreenShowInviteFriends {
            sectionUserSettings.addRow(withTag: UserSettings.inviteFriendsIndex)
        }

        sectionUserSettings.headerTitle = NSLocalizedString("settings_user_settings", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        tmpSections?.append(sectionUserSettings)

        let sectionSecurity = Section(tag: SectionTag.security)
        sectionSecurity.addRow(withTag: EnumC.security_BUTTON_INDEX)
        sectionSecurity.headerTitle = NSLocalizedString("settings_security", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        tmpSections?.append(sectionSecurity)

        let sectionNotificationSettings = Section(tag: SectionTag.notifications)
        sectionNotificationSettings.addRow(withTag: NotificationSettings.enablePushIndex)
        sectionNotificationSettings.addRow(withTag: NotificationSettings.systemSettings)
        if RiotSettings.shared.settingsScreenShowNotificationDecodedContentOption {
            sectionNotificationSettings.addRow(withTag: NotificationSettings.showDecodedContent)
        }

        if #available(iOS 14.0, *) {
            // Don't add Global settings message for iOS 14+
        } else {
            sectionNotificationSettings.addRow(withTag: NotificationSettings.globalSettingsIndex)
        }

        sectionNotificationSettings.addRow(withTag: NotificationSettings.pinMissedNotificationsIndex)
        sectionNotificationSettings.addRow(withTag: NotificationSettings.pinUnreadIndex)

        if #available(iOS 14.0, *) {
            sectionNotificationSettings.addRow(withTag: NotificationSettings.defaultSettingsIndex)
            sectionNotificationSettings.addRow(withTag: NotificationSettings.mentionAndKeywordsSettingsIndex)
            sectionNotificationSettings.addRow(withTag: NotificationSettings.otherSettingsIndex)
        } else {
            // Don't add new sections on pre iOS 14
        }

        sectionNotificationSettings.headerTitle = NSLocalizedString("settings_notifications", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        tmpSections?.append(sectionNotificationSettings)

        if BuildSettings.allowVoIPUsage && BuildSettings.stunServerFallbackUrlString {
            let sectionCalls = Section(tag: SectionTag.calls)
            sectionCalls.headerTitle = NSLocalizedString("settings_calls_settings", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

            if RiotSettings.shared.settingsScreenShowEnableStunServerFallback {
                sectionCalls.addRow(withTag: Calls.enableStunServerFallbackIndex)
                sectionCalls.addRow(withTag: Calls.stunServerFallbackDescriptionIndex)
            }

            if sectionCalls.rows.count {
                tmpSections?.append(sectionCalls)
            }
        }

        if BuildSettings.settingsScreenShowDiscoverySettings {
            let sectionDiscovery = Section(tag: SectionTag.discovery)
            let count = settingsDiscoveryTableViewSection?.numberOfRows ?? 0
            for index in 0..<count {
                sectionDiscovery.addRow(withTag: index)
            }
            sectionDiscovery.headerTitle = NSLocalizedString("settings_discovery_settings", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionDiscovery)
        }

        if BuildSettings.settingsScreenAllowIdentityServerConfig {
            let sectionIdentityServer = Section(tag: SectionTag.identityServer)
            sectionIdentityServer.addRow(withTag: IdentityServer.index)
            sectionIdentityServer.addRow(withTag: IdentityServer.descriptionIndex)
            sectionIdentityServer.headerTitle = NSLocalizedString("settings_identity_server_settings", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionIdentityServer)
        }

        if BuildSettings.allowLocalContactsAccess {
            let sectionLocalContacts = Section(tag: SectionTag.localContacts)
            sectionLocalContacts.addRow(withTag: LocalContacts.syncIndex)
            if MXKAppSettings.standardAppSettings.syncLocalContacts {
                sectionLocalContacts.addRow(withTag: LocalContacts.phonebookCountryIndex)
            }
            sectionLocalContacts.headerTitle = NSLocalizedString("settings_contacts", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionLocalContacts)
        }

        let session = AppDelegate.the().mxSessions.first as? MXSession
        if session?.ignoredUsers.count {
            let sectionIgnoredUsers = Section(tag: SectionTag.ignoredUsers)
            for index in 0..<(session?.ignoredUsers.count ?? 0) {
                sectionIgnoredUsers.addRow(withTag: index)
            }
            sectionIgnoredUsers.headerTitle = NSLocalizedString("settings_ignored_users", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionIgnoredUsers)
        }

        if RiotSettings.shared.matrixApps {
            let sectionIntegrations = Section(tag: SectionTag.integrations)
            sectionIntegrations.addRow(withTag: Integrations.index)
            sectionIntegrations.addRow(withTag: Integrations.descriptionIndex)
            sectionIntegrations.headerTitle = NSLocalizedString("settings_integrations", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionIntegrations)
        }

        let sectionUserInterface = Section(tag: SectionTag.userInterface)
        sectionUserInterface.addRow(withTag: UserInterface.languageIndex)
        sectionUserInterface.addRow(withTag: UserInterface.themeIndex)
        sectionUserInterface.headerTitle = NSLocalizedString("settings_user_interface", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        tmpSections?.append(sectionUserInterface)

        if BuildSettings.settingsScreenShowAdvancedSettings {
            let sectionAdvanced = Section(tag: SectionTag.advanced)
            sectionAdvanced.addRow(withTag: 0)
            sectionAdvanced.headerTitle = NSLocalizedString("settings_advanced", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionAdvanced)
        }

        let sectionOther = Section(tag: SectionTag.other)
        sectionOther.addRow(withTag: Other.versionIndex)
        sectionOther.addRow(withTag: Other.olmVersionIndex)
        if BuildSettings.applicationCopyrightUrlString.length {
            sectionOther.addRow(withTag: Other.copyrightIndex)
        }
        if BuildSettings.applicationTermsConditionsUrlString.length {
            sectionOther.addRow(withTag: Other.termConditionsIndex)
        }
        if BuildSettings.applicationPrivacyPolicyUrlString.length {
            sectionOther.addRow(withTag: Other.privacyIndex)
        }
        sectionOther.addRow(withTag: Other.thirdPartyIndex)
        if RiotSettings.shared.settingsScreenShowNsfwRoomsOption {
            sectionOther.addRow(withTag: Other.showNsfwRoomsIndex)
        }

        if BuildSettings.settingsScreenAllowChangingCrashUsageDataSettings {
            sectionOther.addRow(withTag: Other.crashReportIndex)
        }
        if BuildSettings.settingsScreenAllowChangingRageshakeSettings {
            sectionOther.addRow(withTag: Other.enableRageshakeIndex)
        }
        sectionOther.addRow(withTag: Other.markAllAsReadIndex)
        sectionOther.addRow(withTag: Other.clearCacheIndex)
        if BuildSettings.settingsScreenAllowBugReportingManually {
            sectionOther.addRow(withTag: Other.reportBugIndex)
        }
        sectionOther.headerTitle = NSLocalizedString("settings_other", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        tmpSections?.append(sectionOther)

        if BuildSettings.settingsScreenShowLabSettings {
            let sectionLabs = Section(tag: SectionTag.labs)
            sectionLabs.addRow(withTag: EnumA.labs_ENABLE_RINGING_FOR_GROUP_CALLS_INDEX)
            sectionLabs.headerTitle = NSLocalizedString("settings_labs", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            if sectionLabs.hasAnyRows {
                tmpSections?.append(sectionLabs)
            }
        }

        if groupsDataSource?.numberOfSections(in: tableView) != nil && groupsDataSource?.joinedGroupsSection != -1 {
            let count = groupsDataSource?.tableView(
                tableView,
                numberOfRowsInSection: groupsDataSource?.joinedGroupsSection ?? 0) ?? 0
            let sectionFlair = Section(tag: SectionTag.flair)
            for index in 0..<count {
                sectionFlair.addRow(withTag: index)
            }
            sectionFlair.headerTitle = NSLocalizedString("settings_flair", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionFlair)
        }

        if BuildSettings.settingsScreenAllowDeactivatingAccount {
            let sectionDeactivate = Section(tag: SectionTag.deactivateAccount)
            sectionDeactivate.addRow(withTag: 0)
            sectionDeactivate.headerTitle = NSLocalizedString("settings_deactivate_my_account", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            tmpSections?.append(sectionDeactivate)
        }

        //  update sections
        tableViewSections?.sections = tmpSections
    }

    func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        navigationItem.title = NSLocalizedString("settings_title", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

        // Remove back bar button title when pushing a view controller
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        tableView.register(MXKTableViewCellWithLabelAndTextField.self, forCellReuseIdentifier: MXKTableViewCellWithLabelAndTextField.defaultReuseIdentifier())
        tableView.register(MXKTableViewCellWithLabelAndSwitch.self, forCellReuseIdentifier: MXKTableViewCellWithLabelAndSwitch.defaultReuseIdentifier())
        tableView.register(MXKTableViewCellWithLabelAndMXKImageView.self, forCellReuseIdentifier: MXKTableViewCellWithLabelAndMXKImageView.defaultReuseIdentifier())
        tableView.register(TableViewCellWithPhoneNumberTextField.self, forCellReuseIdentifier: TableViewCellWithPhoneNumberTextField.defaultReuseIdentifier())
        tableView.register(GroupTableViewCellWithSwitch.self, forCellReuseIdentifier: GroupTableViewCellWithSwitch.defaultReuseIdentifier())
        tableView.register(MXKTableViewCellWithTextView.nib, forCellReuseIdentifier: MXKTableViewCellWithTextView.defaultReuseIdentifier())

        // Enable self sizing cells
        tableView.rowHeight = UITableViewDelegate.automaticDimension
        tableView.estimatedRowHeight = 50

        // Add observer to handle removed accounts
        removedAccountObserver = NotificationCenter.default.addObserver(forName: kMXKAccountManagerDidRemoveAccountNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

            if MXKAccountManager.shared().accounts.count {
                // Refresh table to remove this account
                refreshSettings()
            }

        })

        // Add observer to handle accounts update
        accountUserInfoObserver = NotificationCenter.default.addObserver(forName: kMXKAccountUserInfoDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

            stopActivityIndicator()

            refreshSettings()

        })

        // Add observer to push settings
        pushInfoUpdateObserver = NotificationCenter.default.addObserver(forName: kMXKAccountAPNSActivityDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

            stopActivityIndicator()

            refreshSettings()

        })

        registerAccountDataDidChangeIdentityServerNotification()

        // Add each matrix session, to update the view controller appearance according to mx sessions state
        let sessions = AppDelegate.the().mxSessions
        for mxSession in sessions {
            guard let mxSession = mxSession as? MXSession else {
                continue
            }
            addMatrixSession(mxSession)
        }

        setupDiscoverySection()

        groupsDataSource = GroupsDataSource(matrixSession: mainSession)
        groupsDataSource?.finalizeInitialization()
        groupsDataSource?.delegate = self

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(onSave(_:)))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "SettingsVCNavBarSaveButton"


        // Observe user interface theme change.
        kThemeServiceDidChangeThemeNotificationObserver = NotificationCenter.default.addObserver(forName: kThemeServiceDidChangeThemeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

            userInterfaceThemeDidChange()

        })
        userInterfaceThemeDidChange()

        signOutAlertPresenter = SignOutAlertPresenter()
        signOutAlertPresenter?.delegate = self

        tableViewSections = TableViewSections()
        tableViewSections?.delegate = self
        updateSections()
    }

    func userInterfaceThemeDidChange() {
        ThemeService.shared.theme.applyStyle(on: navigationController.navigationBar)

        activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor

        // Check the table view style to select its bg color.
        tableView.backgroundColor = (tableView.style == .plain) ? ThemeService.shared.theme.backgroundColor : ThemeService.shared.theme.headerBackgroundColor
        view.backgroundColor = tableView.backgroundColor
        tableView.separator = ThemeService.shared.theme.lineBreakColor

        if tableView.dataSource != nil {
            refreshSettings()
        }

        setNeedsStatusBarAppearanceUpdate()
    }

    func preferredStatusBarStyle() -> UIStatusBarStyle {
        return ThemeService.shared.theme.statusBarStyle
    }

    func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func destroy() {
        if groupsDataSource != nil {
            groupsDataSource?.delegate = nil
            groupsDataSource?.destroy()
            groupsDataSource = nil
        }

        // Release the potential pushed view controller
        releasePushedViewController()

        if kThemeServiceDidChangeThemeNotificationObserver != nil {
            if let kThemeServiceDidChangeThemeNotificationObserver = kThemeServiceDidChangeThemeNotificationObserver {
                NotificationCenter.default.removeObserver(kThemeServiceDidChangeThemeNotificationObserver)
            }
            kThemeServiceDidChangeThemeNotificationObserver = nil
        }

        if isSavingInProgress || isResetPwdInProgress || is3PIDBindingInProgress {
            weak var weakSelf = self
            onReadyToDestroyHandler = { [self] in

                if let weakSelf = weakSelf {
                    let self = weakSelf
                    destroy()
                }

            }
        } else {
            // Dispose all resources
            reset()

            super.destroy()
        }

        secureBackupSetupCoordinatorBridgePresenter = nil
        identityServerSettingsCoordinatorBridgePresenter = nil
    }

    func onMatrixSessionStateDidChange(_ notif: Notification?) {
        let mxSession = notif?.object as? MXSession

        // Check whether the concerned session is a new one which is not already associated with this view controller.
        if let mxSession = mxSession {
            if mxSession?.state == MXSessionStateInitialised && (mxSessions.firstIndex(of: mxSession) ?? NSNotFound) != NSNotFound {
                // Store this new session
                addMatrixSession(mxSession)
            } else {
                super.onMatrixSessionStateDidChange(notif)
            }
        }
    }

    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Screen tracking
        Analytics.sharedInstance().trackScreen("Settings")

        // Refresh display
        refreshSettings()

        // Refresh linked emails and phone numbers in parallel
        loadAccount3PIDs()

        // Observe kAppDelegateDidTapStatusBarNotificationObserver.
        kAppDelegateDidTapStatusBarNotificationObserver = NotificationCenter.default.addObserver(forName: kAppDelegateDidTapStatusBarNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in

            tableView.setContentOffset(CGPoint(x: -tableView.mxk_adjustedContentInset.left, y: -tableView.mxk_adjustedContentInset.top), animated: true)

        })

        newPhoneNumberCountryPicker = nil
    }

    func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Release the potential pushed view controller
        releasePushedViewController()

        settingsDiscoveryTableViewSection?.reload()
    }

    func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if currentAlert != nil {
            currentAlert?.dismiss(animated: false)
            currentAlert = nil
        }

        if resetPwdAlertController != nil {
            resetPwdAlertController?.dismiss(animated: false)
            resetPwdAlertController = nil
        }

        if notificationCenterWillUpdateObserver != nil {
            if let notificationCenterWillUpdateObserver = notificationCenterWillUpdateObserver {
                NotificationCenter.default.removeObserver(notificationCenterWillUpdateObserver)
            }
            notificationCenterWillUpdateObserver = nil
        }

        if notificationCenterDidUpdateObserver != nil {
            if let notificationCenterDidUpdateObserver = notificationCenterDidUpdateObserver {
                NotificationCenter.default.removeObserver(notificationCenterDidUpdateObserver)
            }
            notificationCenterDidUpdateObserver = nil
        }

        if notificationCenterDidFailObserver != nil {
            if let notificationCenterDidFailObserver = notificationCenterDidFailObserver {
                NotificationCenter.default.removeObserver(notificationCenterDidFailObserver)
            }
            notificationCenterDidFailObserver = nil
        }

        if kAppDelegateDidTapStatusBarNotificationObserver != nil {
            if let kAppDelegateDidTapStatusBarNotificationObserver = kAppDelegateDidTapStatusBarNotificationObserver {
                NotificationCenter.default.removeObserver(kAppDelegateDidTapStatusBarNotificationObserver)
            }
            kAppDelegateDidTapStatusBarNotificationObserver = nil
        }
    }

    // MARK: - Internal methods

    func push(_ viewController: UIViewController?) {
        // Keep ref on pushed view controller
        pushedViewController = viewController

        // Hide back button title
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        if let viewController = viewController {
            navigationController.pushViewController(viewController, animated: true)
        }
    }

    func releasePushedViewController() {
        if pushedViewController != nil {
            if pushedViewController is UINavigationController {
                let navigationController = pushedViewController as? UINavigationController
                for subViewController in navigationController?.viewControllers ?? [] {
                    if subViewController.responds(to: Selector("destroy")) {
                        subViewController.destroy()
                    }
                }
            } else if pushedViewController?.responds(to: Selector("destroy")) ?? false {
                pushedViewController?.destroy()
            }

            pushedViewController = nil
        }
    }

    func dismissKeyboard() {
        currentPasswordTextField?.resignFirstResponder()
        newPasswordTextField1?.resignFirstResponder()
        newPasswordTextField2?.resignFirstResponder()
        newEmailTextField?.resignFirstResponder()
        newPhoneNumberCell?.mxkTextField.resignFirstResponder()
    }

    func reset() {
        // Remove observers
        if removedAccountObserver != nil {
            if let removedAccountObserver = removedAccountObserver {
                NotificationCenter.default.removeObserver(removedAccountObserver)
            }
            removedAccountObserver = nil
        }

        if accountUserInfoObserver != nil {
            if let accountUserInfoObserver = accountUserInfoObserver {
                NotificationCenter.default.removeObserver(accountUserInfoObserver)
            }
            accountUserInfoObserver = nil
        }

        if pushInfoUpdateObserver != nil {
            if let pushInfoUpdateObserver = pushInfoUpdateObserver {
                NotificationCenter.default.removeObserver(pushInfoUpdateObserver)
            }
            pushInfoUpdateObserver = nil
        }

        NotificationCenter.default.removeObserver(self)

        onReadyToDestroyHandler = nil
    }

    func showValidationEmailDialog(withMessage message: String?, for3PidAddSession threePidAddSession: MX3PidAddSession?, threePidAddManager: MX3PidAddManager?, authenticationParameters: [AnyHashable : Any]?) {
        MXWeakify(self)
        currentAlert?.dismiss(animated: false)
        currentAlert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "account_email_validation_title"), message: message, preferredStyle: .alert)

        currentAlert?.addAction(UIAlertAction(title: Bundle.mxk_localizedString(forKey: "cancel"), style: .default, handler: { [self] action in
            MXStrongifyAndReturnIfNil(self)
            currentAlert = nil
            stopActivityIndicator()

            // Reset new email adding
            newEmailEditingEnabled = false
        }))

        currentAlert?.addAction(UIAlertAction(title: Bundle.mxk_localizedString(forKey: "continue"), style: .default, handler: { [self] action in
            MXStrongifyAndReturnIfNil(self)
            tryFinaliseAddEmailSession(
                threePidAddSession,
                withAuthenticationParameters: authenticationParameters,
                threePidAddManager: threePidAddManager)
        }))

        currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCEmailValidationAlert")
        if let currentAlert = currentAlert {
            present(currentAlert, animated: true)
        }
    }

    func tryFinaliseAddEmailSession(_ threePidAddSession: MX3PidAddSession?, withAuthenticationParameters authParams: [AnyHashable : Any]?, threePidAddManager: MX3PidAddManager?) {
        is3PIDBindingInProgress = true

        threePidAddManager?.tryFinaliseAddEmailSession(threePidAddSession, authParams: authParams, success: { [self] in

            is3PIDBindingInProgress = false

            // Check whether destroy has been called during email binding
            if onReadyToDestroyHandler != nil {
                // Ready to destroy
                onReadyToDestroyHandler()
                onReadyToDestroyHandler = nil
            } else {
                currentAlert = nil

                stopActivityIndicator()

                // Reset new email adding
                newEmailEditingEnabled = false

                // Update linked emails
                loadAccount3PIDs()
            }

        }, failure: { [self] error in
            MXLogDebug("[SettingsViewController] tryFinaliseAddEmailSession: Failed to bind email")

            let mxError = MXError(nsError: error)
            if mxError != nil && (mxError.errcode == kMXErrCodeStringForbidden) {
                MXLogDebug("[SettingsViewController] tryFinaliseAddEmailSession: Wrong credentials")

                // Ask password again
                currentAlert = UIAlertController(
                    title: nil,
                    message: NSLocalizedString("settings_add_3pid_invalid_password_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
                    preferredStyle: .alert)

                currentAlert?.addAction(UIAlertAction(title: NSLocalizedString("retry", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), style: .default, handler: { [self] action in
                    currentAlert = nil

                    showAuthenticationIfNeeded(forAdding: kMX3PIDMediumEmail, with: mainSession) { [self] authParams in
                        tryFinaliseAddEmailSession(threePidAddSession, withAuthenticationParameters: authParams, threePidAddManager: threePidAddManager)
                    }
                }))

                if let currentAlert = currentAlert {
                    present(currentAlert, animated: true)
                }

                return
            }

            is3PIDBindingInProgress = false

            // Check whether destroy has been called during email binding
            if onReadyToDestroyHandler != nil {
                // Ready to destroy
                onReadyToDestroyHandler()
                onReadyToDestroyHandler = nil
            } else {
                currentAlert = nil

                // Display the same popup again if the error is M_THREEPID_AUTH_FAILED
                let mxError = MXError(nsError: error)
                if mxError != nil && (mxError.errcode == kMXErrCodeStringThreePIDAuthFailed) {
                    showValidationEmailDialog(withMessage: Bundle.mxk_localizedString(forKey: "account_email_validation_error"), for3PidAddSession: threePidAddSession, threePidAddManager: threePidAddManager, authenticationParameters: authParams)
                } else {
                    stopActivityIndicator()

                    // Notify user
                    let myUserId = mainSession.myUser.userId // TODO: Hanlde multi-account
                    NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != "" ? [
                        kMXKErrorUserIdKey: myUserId
                    ] : nil)
                }
            }
        })
    }

    func showValidationMsisdnDialog(withMessage message: String?, for3PidAddSession threePidAddSession: MX3PidAddSession?, threePidAddManager: MX3PidAddManager?, authenticationParameters: [AnyHashable : Any]?) {
        MXWeakify(self)

        currentAlert?.dismiss(animated: false)
        currentAlert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "account_msisdn_validation_title"), message: message, preferredStyle: .alert)

        currentAlert?.addAction(UIAlertAction(title: Bundle.mxk_localizedString(forKey: "cancel"), style: .default, handler: { [self] action in
            MXStrongifyAndReturnIfNil(self)

            currentAlert = nil

            stopActivityIndicator()

            // Reset new phone adding
            newPhoneEditingEnabled = false
        }))

        currentAlert?.addTextField(configurationHandler: { textField in
            textField?.isSecureTextEntry = false
            textField?.placeholder = nil
            textField?.keyboardType = .decimalPad
        })

        currentAlert?.addAction(UIAlertAction(title: Bundle.mxk_localizedString(forKey: "submit"), style: .default, handler: { [self] action in

            MXStrongifyAndReturnIfNil(self)

            let smsCode = currentAlert?.textFields?.first?.text

            currentAlert = nil

            if (smsCode?.count ?? 0) != 0 {
                finaliseAddPhoneNumber(threePidAddSession, withToken: smsCode, andAuthenticationParameters: authenticationParameters, message: message, threePidAddManager: threePidAddManager)
            } else {
                // Ask again the sms token
                showValidationMsisdnDialog(withMessage: message, for3PidAddSession: threePidAddSession, threePidAddManager: threePidAddManager, authenticationParameters: authenticationParameters)
            }
        }))

        currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCMsisdnValidationAlert")
        if let currentAlert = currentAlert {
            present(currentAlert, animated: true)
        }
    }

    func finaliseAddPhoneNumber(_ threePidAddSession: MX3PidAddSession?, withToken token: String?, andAuthenticationParameters authParams: [AnyHashable : Any]?, message: String?, threePidAddManager: MX3PidAddManager?) {
        is3PIDBindingInProgress = true

        threePidAddManager?.finaliseAddPhoneNumber(threePidAddSession, withToken: token, authParams: authParams, success: { [self] in

            is3PIDBindingInProgress = false

            // Check whether destroy has been called during the binding
            if onReadyToDestroyHandler != nil {
                // Ready to destroy
                onReadyToDestroyHandler()
                onReadyToDestroyHandler = nil
            } else {
                stopActivityIndicator()

                // Reset new phone adding
                newPhoneEditingEnabled = false

                // Update linked 3pids
                loadAccount3PIDs()
            }

        }, failure: { [self] error in

            MXLogDebug("[SettingsViewController] finaliseAddPhoneNumberSession: Failed to submit the sms token")

            let mxError = MXError(nsError: error)
            if mxError != nil && (mxError.errcode == kMXErrCodeStringForbidden) {
                MXLogDebug("[SettingsViewController] finaliseAddPhoneNumberSession: Wrong authentication credentials")

                // Ask password again
                currentAlert = UIAlertController(
                    title: nil,
                    message: NSLocalizedString("settings_add_3pid_invalid_password_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
                    preferredStyle: .alert)

                currentAlert?.addAction(UIAlertAction(title: NSLocalizedString("retry", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), style: .default, handler: { [self] action in
                    currentAlert = nil

                    showAuthenticationIfNeeded(forAdding: kMX3PIDMediumMSISDN, with: mainSession) { [self] authParams in
                        finaliseAddPhoneNumber(threePidAddSession, withToken: token, andAuthenticationParameters: authParams, message: message, threePidAddManager: threePidAddManager)
                    }
                }))

                if let currentAlert = currentAlert {
                    present(currentAlert, animated: true)
                }

                return
            }

            is3PIDBindingInProgress = false

            // Check whether destroy has been called during phone binding
            if onReadyToDestroyHandler != nil {
                // Ready to destroy
                onReadyToDestroyHandler()
                onReadyToDestroyHandler = nil
            } else {
                // Ignore connection cancellation error
                if ((error as NSError).domain == NSURLErrorDomain) && (error as NSError).code == Int(NSURLErrorCancelled) {
                    stopActivityIndicator()
                    return
                }

                // Alert user
                var title = (error as NSError).userInfo[NSLocalizedFailureReasonErrorKey] as? String
                var msg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String
                if title == nil {
                    if msg != nil {
                        title = msg
                        msg = nil
                    } else {
                        title = Bundle.mxk_localizedString(forKey: "error")
                    }
                }


                currentAlert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

                currentAlert?.addAction(UIAlertAction(title: Bundle.mxk_localizedString(forKey: "ok"), style: .default, handler: { [self] action in
                    currentAlert = nil

                    // Ask again the sms token
                    showValidationMsisdnDialog(withMessage: message, for3PidAddSession: threePidAddSession, threePidAddManager: threePidAddManager, authenticationParameters: authParams)
                }))

                currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCErrorAlert")
                if let currentAlert = currentAlert {
                    present(currentAlert, animated: true)
                }
            }
        })
    }

    func loadAccount3PIDs() {
        // Refresh the account 3PIDs list
        let account = MXKAccountManager.shared().activeAccounts.first as? MXKAccount
        account?.load3PIDs({ [self] in

            let thirdPartyIdentifiers: [MXThirdPartyIdentifier]? = (account?.threePIDs ?? []) as? [MXThirdPartyIdentifier]
            settingsDiscoveryViewModel?.update(withThirdPartyIdentifiers: thirdPartyIdentifiers)

            // Refresh all the table (A slide down animation is observed when we limit the refresh to the concerned section).
            // Note: The use of 'reloadData' handles the case where the account has been logged out.
            refreshSettings()

        }, failure: { [self] error in

            // Display the data that has been loaded last time
            // Note: The use of 'reloadData' handles the case where the account has been logged out.
            refreshSettings()

        })
    }

    func editNewEmailTextField() {
        if newEmailTextField != nil && !(newEmailTextField?.becomeFirstResponder() ?? false) {
            // Retry asynchronously
            DispatchQueue.main.async(execute: { [self] in

                editNewEmailTextField()

            })
        }
    }

    func editNewPhoneNumberTextField() {
        if newPhoneNumberCell != nil && !(newPhoneNumberCell?.mxkTextField.becomeFirstResponder() ?? false) {
            // Retry asynchronously
            DispatchQueue.main.async(execute: { [self] in

                editNewPhoneNumberTextField()

            })
        }
    }

    func refreshSettings() {
        // Check whether a text input is currently edited
        keepNewEmailEditing = Bool((newEmailTextField != nil ? newEmailTextField?.isFirstResponder : false) ?? false)
        keepNewPhoneNumberEditing = Bool((newPhoneNumberCell != nil ? newPhoneNumberCell?.mxkTextField.isFirstResponder : false) ?? false)

        // Trigger a full table reloadData
        updateSections()

        // Restore the previous edited field
        if keepNewEmailEditing {
            editNewEmailTextField()
            keepNewEmailEditing = false
        } else if keepNewPhoneNumberEditing {
            editNewPhoneNumberTextField()
            keepNewPhoneNumberEditing = false
        }

        // Update notification access
        refreshSystemNotificationSettings()
    }

    func refreshSystemNotificationSettings() {
        MXWeakify(self)

        // Get the system notification settings to check authorization status and configuration.
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { [self] settings in
            DispatchQueue.main.async(execute: { [self] in
                MXStrongifyAndReturnIfNil(self)

                systemNotificationSettings = settings
                tableView.reloadData()
            })
        })
    }

    func formatNewPhoneNumber() {
        if let newPhoneNumber = newPhoneNumber {
            var formattedNumber: String? = nil
            do {
                formattedNumber = try NBPhoneNumberUtil.sharedInstance().format(newPhoneNumber, numberFormat: NBEPhoneNumberFormatINTERNATIONAL)
            } catch {
            }
            let prefix = newPhoneNumberCell?.mxkLabel.text
            if formattedNumber?.hasPrefix(prefix ?? "") ?? false {
                // Format the display phone number
                newPhoneNumberCell?.mxkTextField.text = (formattedNumber as NSString?)?.substring(from: prefix?.count ?? 0)
            }
        }
    }

    func setupDiscoverySection() {
        let account = MXKAccountManager.shared().activeAccounts.first as? MXKAccount

        let thirdPartyIdentifiers: [MXThirdPartyIdentifier]? = (account?.threePIDs ?? []) as? [MXThirdPartyIdentifier]

        let viewModel = SettingsDiscoveryViewModel(session: mainSession, thirdPartyIdentifiers: thirdPartyIdentifiers)
        viewModel.coordinatorDelegate = self

        let discoverySection = SettingsDiscoveryTableViewSection(viewModel: viewModel)
        discoverySection.delegate = self

        settingsDiscoveryViewModel = viewModel
        settingsDiscoveryTableViewSection = discoverySection
    }

    func createUserInteractiveAuthenticationService() -> UserInteractiveAuthenticationService? {
        let session = mainSession
        var userInteractiveAuthenticationService: UserInteractiveAuthenticationService?

        if let session = session {
            userInteractiveAuthenticationService = UserInteractiveAuthenticationService(session: session)
        }

        return userInteractiveAuthenticationService
    }

    // MARK: - 3Pid Add

    func showAuthenticationIfNeeded(forAdding medium: MX3PIDMedium, with session: MXSession?, completion: @escaping (_ authParams: [AnyHashable : Any]?) -> Void) {
        startActivityIndicator()

        MXWeakify(self)

        let animationCompletion: (() -> Void)? = { [self] in
            MXStrongifyAndReturnIfNil(self)

            stopActivityIndicator()
            reauthenticationCoordinatorBridgePresenter?.dismissWith(animated: true) {
            }
            reauthenticationCoordinatorBridgePresenter = nil
        }

        var title: String?

        if medium.isEqual(toString: kMX3PIDMediumMSISDN) {
            title = NSLocalizedString("settings_add_3pid_password_title_msidsn", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        } else {
            title = NSLocalizedString("settings_add_3pid_password_title_email", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        }

        let message = NSLocalizedString("settings_add_3pid_password_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")


        session?.matrixRestClient.add3PIDOnly(withSessionId: "", clientSecret: MXTools.generateSecret(), authParams: nil, success: {

        }, failure: { [self] error in

            if let error = error {
                userInteractiveAuthenticationService?.authenticationSession(fromRequestError: error, success: { [self] authenticationSession in

                    if let authenticationSession = authenticationSession {
                        let coordinatorParameters = ReauthenticationCoordinatorParameters(session: mainSession, presenter: self, title: title, message: message, authenticationSession: authenticationSession)

                        let reauthenticationPresenter = ReauthenticationCoordinatorBridgePresenter()

                        reauthenticationPresenter.present(with: coordinatorParameters, animated: true, success: { authParams in
                            completion(authParams)
                        }, cancel: {
                            animationCompletion?()
                        }, failure: { error in
                            animationCompletion?()
                            AppDelegate.the().showError(asAlert: error)
                        })

                        reauthenticationCoordinatorBridgePresenter = reauthenticationPresenter
                    } else {
                        animationCompletion?()
                        completion(nil)
                    }
                }, failure: { error in
                    animationCompletion?()
                    AppDelegate.the().showError(asAlert: error)
                })
            } else {
                animationCompletion?()
                AppDelegate.the().showError(asAlert: error)
            }
        })
    }

    // MARK: - Segues

    func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Keep ref on destinationViewController
        super.prepare(for: segue, sender: sender)

        // FIXME add night mode
    }

    // MARK: - UITableView data source

    func numberOfSections(in tableView: UITableView) -> Int {
        // update the save button if there is an update
        updateSaveButtonStatus()

        return tableViewSections?.sections.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionObject = tableViewSections?.section(at: section)
        return sectionObject?.rows.count ?? 0
    }

    func getLabelAndTextFieldCell(_ tableview: UITableView?, for indexPath: IndexPath?) -> MXKTableViewCellWithLabelAndTextField? {
        var cell: MXKTableViewCellWithLabelAndTextField? = nil
        if let indexPath = indexPath {
            cell = tableview?.dequeueReusableCell(withIdentifier: MXKTableViewCellWithLabelAndTextField.defaultReuseIdentifier(), for: indexPath) as? MXKTableViewCellWithLabelAndTextField
        }

        cell?.mxkLabelLeadingConstraint.constant = cell?.vc_separatorInset.left
        cell?.mxkTextFieldLeadingConstraint.constant = 16
        cell?.mxkTextFieldTrailingConstraint.constant = 15

        cell?.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor

        cell?.mxkTextField.isUserInteractionEnabled = true
        cell?.mxkTextField.borderStyle = .none
        cell?.mxkTextField.textAlignment = .right
        cell?.mxkTextField.textColor = ThemeService.shared.theme.textSecondaryColor
        cell?.mxkTextField.tintColor = ThemeService.shared.theme.tintColor
        cell?.mxkTextField.font = UIFont.systemFont(ofSize: 16)
        cell?.mxkTextField.placeholder = nil

        cell?.accessoryType = UITableViewCell.AccessoryType.none
        cell?.accessoryView = nil

        cell?.alpha = 1.0
        cell?.userInteractionEnabled = true

        cell?.layoutIfNeeded()

        return cell
    }

    func getLabelAndSwitchCell(_ tableview: UITableView?, for indexPath: IndexPath?) -> MXKTableViewCellWithLabelAndSwitch? {
        var cell: MXKTableViewCellWithLabelAndSwitch? = nil
        if let indexPath = indexPath {
            cell = tableview?.dequeueReusableCell(withIdentifier: MXKTableViewCellWithLabelAndSwitch.defaultReuseIdentifier(), for: indexPath) as? MXKTableViewCellWithLabelAndSwitch
        }

        cell?.mxkLabelLeadingConstraint.constant = cell?.vc_separatorInset.left
        cell?.mxkSwitchTrailingConstraint.constant = 15

        cell?.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor

        cell?.mxkSwitch.removeTarget(self, action: nil, for: .touchUpInside)

        // Force layout before reusing a cell (fix switch displayed outside the screen)
        cell?.layoutIfNeeded()

        return cell
    }

    func getDefaultTableViewCell(_ tableView: UITableView?) -> MXKTableViewCell? {
        var cell = tableView?.dequeueReusableCell(withIdentifier: MXKTableViewCell.defaultReuseIdentifier()) as? MXKTableViewCell
        if cell == nil {
            cell = MXKTableViewCell()
        } else {
            cell?.selectionStyle = UITableViewCell.SelectionStyle.default

            cell?.accessoryType = UITableViewCell.AccessoryType.none
            cell?.accessoryView = nil
        }
        cell?.textLabel.accessibilityIdentifier = nil
        cell?.textLabel.font = UIFont.systemFont(ofSize: 17)
        cell?.textLabel.textColor = ThemeService.shared.theme.textPrimaryColor
        cell?.contentView()?.backgroundColor = UIColor.clear

        return cell
    }

    func textViewCell(for tableView: UITableView?, at indexPath: IndexPath?) -> MXKTableViewCellWithTextView? {
        var textViewCell: MXKTableViewCellWithTextView? = nil
        if let indexPath = indexPath {
            textViewCell = tableView?.dequeueReusableCell(withIdentifier: MXKTableViewCellWithTextView.defaultReuseIdentifier(), for: indexPath) as? MXKTableViewCellWithTextView
        }

        textViewCell?.mxkTextView.textColor = ThemeService.shared.theme.textPrimaryColor
        textViewCell?.mxkTextView.font = UIFont.systemFont(ofSize: 17)
        textViewCell?.mxkTextView.backgroundColor = UIColor.clear
        textViewCell?.mxkTextViewLeadingConstraint.constant = tableView?.vc_separatorInset.left
        textViewCell?.mxkTextViewTrailingConstraint.constant = tableView?.vc_separatorInset.right
        textViewCell?.mxkTextView.accessibilityIdentifier = nil

        return textViewCell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tagsIndexPath = tableViewSections?.tagsIndexPath(fromTableViewIndexPath: indexPath)
        let section = tagsIndexPath?.section ?? 0
        let row = tagsIndexPath?.row ?? 0

        // set the cell to a default value to avoid application crashes
        var cell = UITableViewCell()
        cell.backgroundColor = UIColor.red

        // check if there is a valid session
        if (AppDelegate.the().mxSessions.count == 0) || (MXKAccountManager.shared().activeAccounts.count == 0) {
            // else use a default cell
            return cell
        }

        let session = mainSession
        let account = MXKAccountManager.shared().activeAccounts.first as? MXKAccount

        if section == SectionTag.signOut.rawValue {
            var signOutCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithButton.defaultReuseIdentifier()) as? MXKTableViewCellWithButton
            if signOutCell == nil {
                signOutCell = MXKTableViewCellWithButton()
            } else {
                // Fix https://github.com/vector-im/riot-ios/issues/1354
                // Do not move this line in prepareForReuse because of https://github.com/vector-im/riot-ios/issues/1323
                signOutCell?.mxkButton.titleLabel?.text = nil
            }

            let title = NSLocalizedString("settings_sign_out", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

            signOutCell?.mxkButton.setTitle(title, for: .normal)
            signOutCell?.mxkButton.setTitle(title, for: .highlighted)
            signOutCell?.mxkButton.tintColor = ThemeService.shared.theme.tintColor
            signOutCell?.mxkButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)

            signOutCell?.mxkButton.removeTarget(self, action: nil, for: .touchUpInside)
            signOutCell?.mxkButton.addTarget(self, action: #selector(onSignout(_:)), for: .touchUpInside)
            signOutCell?.mxkButton.accessibilityIdentifier = "SettingsVCSignOutButton"

            if let signOutCell = signOutCell {
                cell = signOutCell
            }
        } else if section == SectionTag.userSettings.rawValue {
            let myUser = session?.myUser

            if row == UserSettings.profilePictureIndex.rawValue {
                let profileCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithLabelAndMXKImageView.defaultReuseIdentifier(), for: indexPath) as? MXKTableViewCellWithLabelAndMXKImageView

                profileCell?.mxkLabelLeadingConstraint.constant = profileCell?.vc_separatorInset.left
                profileCell?.mxkImageViewTrailingConstraint.constant = 10

                profileCell?.mxkImageViewHeightConstraint.constant = 30
                profileCell?.mxkImageViewWidthConstraint.constant = profileCell?.mxkImageViewHeightConstraint.constant
                profileCell?.mxkImageViewDisplayBoxType = MXKTableViewCellDisplayBoxTypeCircle

                if (profileCell?.mxkImageView.gestureRecognizers.count ?? 0) == 0 {
                    // tap on avatar to update it
                    let tap = UITapGestureRecognizer(target: self, action: #selector(onProfileAvatarTap(_:)))
                    profileCell?.mxkImageView.addGestureRecognizer(tap)
                }

                profileCell?.mxkLabel.text = NSLocalizedString("settings_profile_picture", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                profileCell?.accessibilityIdentifier = "SettingsVCProfilPictureStaticText"
                profileCell?.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor

                // if the user defines a new avatar
                if let newAvatarImage = newAvatarImage {
                    profileCell?.mxkImageView.image = newAvatarImage
                } else {
                    let avatarImage = AvatarGenerator.generateAvatar(forMatrixItem: myUser?.userId, withDisplayName: myUser?.displayname)

                    if myUser?.avatarUrl {
                        profileCell?.mxkImageView.enableInMemoryCache = true

                        profileCell?.mxkImageView.setImageURI(
                            myUser?.avatarUrl,
                            withType: nil,
                            andImageOrientation: UIImage.Orientation.up,
                            toFitViewSize: profileCell?.mxkImageView.frame.size,
                            withMethod: MXThumbnailingMethodCrop,
                            previewImage: avatarImage,
                            mediaManager: session?.mediaManager)
                    } else {
                        profileCell?.mxkImageView.image = avatarImage
                    }
                }

                if let profileCell = profileCell {
                    cell = profileCell
                }
            } else if row == UserSettings.displaynameIndex.rawValue {
                let displaynameCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                displaynameCell?.mxkLabel.text = NSLocalizedString("settings_display_name", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                displaynameCell?.mxkTextField.text = myUser?.displayname

                displaynameCell?.mxkTextField.tag = row
                displaynameCell?.mxkTextField.delegate = self
                displaynameCell?.mxkTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
                displaynameCell?.mxkTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
                displaynameCell?.mxkTextField.accessibilityIdentifier = "SettingsVCDisplayNameTextField"

                if let displaynameCell = displaynameCell {
                    cell = displaynameCell
                }
            } else if row == UserSettings.firstNameIndex.rawValue {
                let firstCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                firstCell?.mxkLabel.text = NSLocalizedString("settings_first_name", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                firstCell?.mxkTextField.isUserInteractionEnabled = false

                if let firstCell = firstCell {
                    cell = firstCell
                }
            } else if row == UserSettings.surnameIndex.rawValue {
                let surnameCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                surnameCell?.mxkLabel.text = NSLocalizedString("settings_surname", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                surnameCell?.mxkTextField.isUserInteractionEnabled = false

                if let surnameCell = surnameCell {
                    cell = surnameCell
                }
            } else if row >= UserSettings.emailsOffset.rawValue {
                let emailIndex = row - UserSettings.emailsOffset.rawValue
                let emailCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                emailCell?.mxkLabel.text = NSLocalizedString("settings_email_address", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                emailCell?.mxkTextField.text = account?.linkedEmails[emailIndex]
                emailCell?.mxkTextField.isUserInteractionEnabled = false

                if let emailCell = emailCell {
                    cell = emailCell
                }
            } else if row >= UserSettings.phonenumbersOffset.rawValue {
                let phoneNumberIndex = row - UserSettings.phonenumbersOffset.rawValue
                let phoneCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                phoneCell?.mxkLabel.text = NSLocalizedString("settings_phone_number", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                phoneCell?.mxkTextField.text = MXKTools.readableMSISDN(account?.linkedPhoneNumbers[phoneNumberIndex])
                phoneCell?.mxkTextField.isUserInteractionEnabled = false

                if let phoneCell = phoneCell {
                    cell = phoneCell
                }
            } else if row == UserSettings.addEmailIndex.rawValue {
                let newEmailCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                // Render the cell according to the `newEmailEditingEnabled` property
                if !newEmailEditingEnabled {
                    newEmailCell?.mxkLabel.text = NSLocalizedString("settings_add_email_address", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    newEmailCell?.mxkTextField.text = nil
                    newEmailCell?.mxkTextField.isUserInteractionEnabled = false
                    newEmailCell?.accessoryView = UIImageView(image: UIImage(named: "plus_icon")?.vc_tintedImage(usingColor: ThemeService.shared.theme.textPrimaryColor))
                } else {
                    newEmailCell?.mxkLabel.text = nil
                    newEmailCell?.mxkTextField.placeholder = NSLocalizedString("settings_email_address_placeholder", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    newEmailCell?.mxkTextField.attributedPlaceholder = NSAttributedString(
                        string: newEmailCell?.mxkTextField.placeholder ?? "",
                        attributes: [
                            NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.placeholderText
                        ])
                    newEmailCell?.mxkTextField.text = newEmailTextField?.text
                    newEmailCell?.mxkTextField.isUserInteractionEnabled = true
                    newEmailCell?.mxkTextField.keyboardType = .emailAddress
                    newEmailCell?.mxkTextField.autocorrectionType = .no
                    newEmailCell?.mxkTextField.spellCheckingType = .no
                    newEmailCell?.mxkTextField.delegate = self
                    newEmailCell?.mxkTextField.accessibilityIdentifier = "SettingsVCAddEmailTextField"

                    newEmailCell?.mxkTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
                    newEmailCell?.mxkTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

                    newEmailCell?.mxkTextField.removeTarget(self, action: #selector(textFieldDidEnd(_:)), for: .editingDidEnd)
                    newEmailCell?.mxkTextField.addTarget(self, action: #selector(textFieldDidEnd(_:)), for: .editingDidEnd)

                    // When displaying the textfield the 1st time, open the keyboard
                    if newEmailTextField == nil {
                        newEmailTextField = newEmailCell?.mxkTextField
                        editNewEmailTextField()
                    } else {
                        // Update the current text field.
                        newEmailTextField = newEmailCell?.mxkTextField
                    }

                    let accessoryViewImage = UIImage(named: "plus_icon")?.vc_tintedImage(using: ThemeService.shared.theme.tintColor)
                    newEmailCell?.accessoryView = UIImageView(image: accessoryViewImage)
                }

                newEmailCell?.mxkTextField.tag = row

                if let newEmailCell = newEmailCell {
                    cell = newEmailCell
                }
            } else if row == UserSettings.addPhonenumberIndex.rawValue {
                // Render the cell according to the `newPhoneEditingEnabled` property
                if !newPhoneEditingEnabled {
                    let newPhoneCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                    newPhoneCell?.mxkLabel.text = NSLocalizedString("settings_add_phone_number", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    newPhoneCell?.mxkTextField.text = nil
                    newPhoneCell?.mxkTextField.isUserInteractionEnabled = false
                    newPhoneCell?.accessoryView = UIImageView(image: UIImage(named: "plus_icon")?.vc_tintedImage(usingColor: ThemeService.shared.theme.textPrimaryColor))

                    if let newPhoneCell = newPhoneCell {
                        cell = newPhoneCell
                    }
                } else {
                    let newPhoneCell = self.tableView.dequeueReusableCell(withIdentifier: TableViewCellWithPhoneNumberTextField.defaultReuseIdentifier(), for: indexPath) as? TableViewCellWithPhoneNumberTextField

                    newPhoneCell?.countryCodeButton.removeTarget(self, action: nil, for: .touchUpInside)
                    newPhoneCell?.countryCodeButton.addTarget(self, action: #selector(selectPhoneNumberCountry(_:)), for: .touchUpInside)
                    newPhoneCell?.countryCodeButton.accessibilityIdentifier = "SettingsVCPhoneCountryButton"

                    newPhoneCell?.mxkTextField.font = UIFont.systemFont(ofSize: 16)
                    newPhoneCell?.mxkLabel.font = newPhoneCell?.mxkTextField.font

                    newPhoneCell?.mxkTextField.isUserInteractionEnabled = true
                    newPhoneCell?.mxkTextField.keyboardType = .phonePad
                    newPhoneCell?.mxkTextField.autocorrectionType = .no
                    newPhoneCell?.mxkTextField.spellCheckingType = .no
                    newPhoneCell?.mxkTextField.delegate = self
                    newPhoneCell?.mxkTextField.accessibilityIdentifier = "SettingsVCAddPhoneTextField"

                    newPhoneCell?.mxkTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
                    newPhoneCell?.mxkTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

                    newPhoneCell?.mxkTextField.removeTarget(self, action: #selector(textFieldDidEnd(_:)), for: .editingDidEnd)
                    newPhoneCell?.mxkTextField.addTarget(self, action: #selector(textFieldDidEnd(_:)), for: .editingDidEnd)

                    newPhoneCell?.mxkTextField.tag = row

                    // When displaying the textfield the 1st time, open the keyboard
                    if newPhoneNumberCell == nil {
                        var countryCode = MXKAppSettings.standard().phonebookCountryCode
                        if countryCode == "" {
                            // If none, consider the preferred locale
                            let local = NSLocale(localeIdentifier: Bundle.main.preferredLocalizations[0])
                            if local.responds(to: #selector(CNContactsUserDefaults.countryCode)) {
                                countryCode = local.countryCode ?? ""
                            }

                            if countryCode == "" {
                                countryCode = "GB"
                            }
                        }
                        newPhoneCell?.isoCountryCode = countryCode
                        newPhoneCell?.mxkTextField.text = nil

                        newPhoneNumberCell = newPhoneCell

                        editNewPhoneNumberTextField()
                    } else {
                        newPhoneCell?.isoCountryCode = newPhoneNumberCell?.isoCountryCode
                        newPhoneCell?.mxkTextField.text = newPhoneNumberCell?.mxkTextField.text

                        newPhoneNumberCell = newPhoneCell
                    }

                    let accessoryViewImage = UIImage(named: "plus_icon")?.vc_tintedImage(using: ThemeService.shared.theme.tintColor)
                    newPhoneCell?.accessoryView = UIImageView(image: accessoryViewImage)

                    if let newPhoneCell = newPhoneCell {
                        cell = newPhoneCell
                    }
                }
            } else if row == UserSettings.threepidsInformationIndex.rawValue {
                let threePidsInformationCell = getDefaultTableViewCell(self.tableView)

                let attributedString = NSMutableAttributedString(string: NSLocalizedString("settings_three_pids_management_information_part1", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.textPrimaryColor
                ])
                if let tintColor = ThemeService.shared.theme.tintColor {
                    attributedString.append(NSAttributedString(string: NSLocalizedString("settings_three_pids_management_information_part2", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), attributes: [
                        NSAttributedString.Key.foregroundColor: tintColor
                    ]))
                }
                attributedString.append(NSAttributedString(string: NSLocalizedString("settings_three_pids_management_information_part3", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), attributes: [
                    NSAttributedString.Key.foregroundColor: ThemeService.shared.theme.textPrimaryColor
                ]))

                threePidsInformationCell?.textLabel.attributedText = attributedString
                threePidsInformationCell?.textLabel.numberOfLines = 0

                threePidsInformationCell?.selectionStyle = UITableViewCell.SelectionStyle.none

                if let threePidsInformationCell = threePidsInformationCell {
                    cell = threePidsInformationCell
                }
            } else if row == UserSettings.inviteFriendsIndex.rawValue {
                let inviteFriendsCell = getDefaultTableViewCell(tableView)

                inviteFriendsCell?.textLabel.text = String.localizedStringWithFormat(NSLocalizedString("invite_friends_action", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), BuildSettings.bundleDisplayName)

                let shareActionImage = UIImage(named: "share_action_button")?.vc_tintedImage(using: ThemeService.shared.theme.tintColor)
                let accessoryView = UIImageView(image: shareActionImage)
                inviteFriendsCell?.accessoryView = accessoryView

                if let inviteFriendsCell = inviteFriendsCell {
                    cell = inviteFriendsCell
                }
            } else if row == UserSettings.changePasswordIndex.rawValue {
                let passwordCell = getLabelAndTextFieldCell(tableView, for: indexPath)

                passwordCell?.mxkLabel.text = NSLocalizedString("settings_change_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                passwordCell?.mxkTextField.text = "*********"
                passwordCell?.mxkTextField.isUserInteractionEnabled = false
                passwordCell?.mxkLabel.accessibilityIdentifier = "SettingsVCChangePwdStaticText"

                if let passwordCell = passwordCell {
                    cell = passwordCell
                }
            }
        } else if section == SectionTag.notifications.rawValue {
            if row == NotificationSettings.enablePushIndex.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)

                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_enable_push_notif", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = true
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(togglePushNotifications(_:)), for: .touchUpInside)

                var isPushEnabled = account?.pushNotificationServiceIsActive ?? false

                // Even if push is enabled for the account, the user may have turned off notifications in system settings
                if isPushEnabled && systemNotificationSettings != nil {
                    isPushEnabled = systemNotificationSettings?.authorizationStatus == .authorized
                }

                labelAndSwitchCell?.mxkSwitch.on = isPushEnabled

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            } else if row == NotificationSettings.systemSettings.rawValue {
                if let dequeue = tableView.dequeueReusableCell(withIdentifier: kSettingsViewControllerPhoneBookCountryCellId) {
                    cell = dequeue
                }
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: kSettingsViewControllerPhoneBookCountryCellId)
                }

                cell.textLabel?.textColor = ThemeService.shared.theme.textPrimaryColor

                cell.textLabel?.text = NSLocalizedString("settings_device_notifications", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                cell.detailTextLabel?.text = ""

                cell.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()
                cell.selectionStyle = .default
            } else if row == NotificationSettings.showDecodedContent.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)

                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_show_decrypted_content", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.on = RiotSettings.shared.showDecryptedContentInNotifications
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = account?.pushNotificationServiceIsActive
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(toggleShowDecodedContent(_:)), for: .touchUpInside)


                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            } else if row == NotificationSettings.globalSettingsIndex.rawValue {
                let globalInfoCell = getDefaultTableViewCell(tableView)

                let appDisplayName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String

                globalInfoCell?.textLabel.text = String.localizedStringWithFormat(NSLocalizedString("settings_global_settings_info", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), appDisplayName ?? "")
                globalInfoCell?.textLabel.numberOfLines = 0

                globalInfoCell?.selectionStyle = UITableViewCell.SelectionStyle.none

                if let globalInfoCell = globalInfoCell {
                    cell = globalInfoCell
                }
            } else if row == NotificationSettings.pinMissedNotificationsIndex.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)

                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_pin_rooms_with_missed_notif", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.on = RiotSettings.shared.pinRoomsWithMissedNotificationsOnHome
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = true
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(togglePinRooms(withMissedNotif:)), for: .touchUpInside)

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            } else if row == NotificationSettings.pinUnreadIndex.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)

                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_pin_rooms_with_unread", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.on = RiotSettings.shared.pinRoomsWithUnreadMessagesOnHome
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = true
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(togglePinRooms(withUnread:)), for: .touchUpInside)

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            } else if row == NotificationSettings.defaultSettingsIndex.rawValue || row == NotificationSettings.mentionAndKeywordsSettingsIndex.rawValue || row == NotificationSettings.otherSettingsIndex.rawValue {
                if let get = getDefaultTableViewCell(tableView) {
                    cell = get
                }
                if row == NotificationSettings.defaultSettingsIndex.rawValue {
                    cell.textLabel?.text = NSLocalizedString("settings_default", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                } else if row == NotificationSettings.mentionAndKeywordsSettingsIndex.rawValue {
                    cell.textLabel?.text = NSLocalizedString("settings_mentions_and_keywords", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                } else if row == NotificationSettings.otherSettingsIndex.rawValue {
                    cell.textLabel?.text = NSLocalizedString("settings_other", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                }
                cell.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()
            }
        } else if section == SectionTag.calls.rawValue {
            if row == Calls.enableStunServerFallbackIndex.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)
                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_calls_stun_server_fallback_button", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.on = RiotSettings.shared.allowStunServerFallback
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = true
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(toggleStunServerFallback(_:)), for: .touchUpInside)

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            } else if row == Calls.stunServerFallbackDescriptionIndex.rawValue {
                var stunFallbackHost = BuildSettings.stunServerFallbackUrlString
                // Remove "stun:"
                stunFallbackHost = stunFallbackHost.components(separatedBy: ":").last ?? ""

                let globalInfoCell = getDefaultTableViewCell(tableView)
                globalInfoCell?.textLabel.text = String.localizedStringWithFormat(NSLocalizedString("settings_calls_stun_server_fallback_description", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), stunFallbackHost)
                globalInfoCell?.textLabel.numberOfLines = 0
                globalInfoCell?.selectionStyle = UITableViewCell.SelectionStyle.none

                if let globalInfoCell = globalInfoCell {
                    cell = globalInfoCell
                }
            }
        } else if section == SectionTag.discovery.rawValue {
            if let cell1 = settingsDiscoveryTableViewSection?.cellForRow(atRow: row) {
                cell = cell1
            }
        } else if section == SectionTag.identityServer.rawValue {
            switch row {
            case IdentityServer.index.rawValue:
                let isCell = getDefaultTableViewCell(tableView)

                if account?.mxSession.identityService.identityServer {
                    isCell?.textLabel.text = account?.mxSession.identityService.identityServer
                } else {
                    isCell?.textLabel.text = NSLocalizedString("settings_identity_server_no_is", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                }
                isCell?.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()
                if let isCell = isCell {
                    cell = isCell
                }
            case IdentityServer.descriptionIndex.rawValue:
                let descriptionCell = getDefaultTableViewCell(tableView)

                if account?.mxSession.identityService.identityServer {
                    descriptionCell?.textLabel.text = NSLocalizedString("settings_identity_server_description", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                } else {
                    descriptionCell?.textLabel.text = NSLocalizedString("settings_identity_server_no_is_description", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                }
                descriptionCell?.textLabel.numberOfLines = 0
                descriptionCell?.selectionStyle = UITableViewCell.SelectionStyle.none

                if let descriptionCell = descriptionCell {
                    cell = descriptionCell
                }
            default:
                break
            }
        } else if section == SectionTag.integrations.rawValue {
            switch row {
            case Integrations.index.rawValue:
                let sharedSettings = RiotSharedSettings(session: session)

                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)
                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_integrations_allow_button", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.on = sharedSettings.hasIntegrationProvisioningEnabled
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = true
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(toggleAllowIntegrations(_:)), for: .touchUpInside)

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            case Integrations.descriptionIndex.rawValue:
                let descriptionCell = getDefaultTableViewCell(tableView)

                let integrationManager = WidgetManager.sharedManager.config(forUser: session?.myUser.userId).apiUrl
                let integrationManagerDomain = URL(string: integrationManager)?.host

                let description = String.localizedStringWithFormat(NSLocalizedString("settings_integrations_allow_description", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), integrationManagerDomain ?? "")
                descriptionCell?.textLabel.text = description
                descriptionCell?.textLabel.numberOfLines = 0
                descriptionCell?.selectionStyle = UITableViewCell.SelectionStyle.none

                if let descriptionCell = descriptionCell {
                    cell = descriptionCell
                }
            default:
                break
            }
        } else if section == SectionTag.userInterface.rawValue {
            if row == UserInterface.languageIndex.rawValue {
                if let dequeue = tableView.dequeueReusableCell(withIdentifier: kSettingsViewControllerPhoneBookCountryCellId) {
                    cell = dequeue
                }
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: kSettingsViewControllerPhoneBookCountryCellId)
                }

                var language = Bundle.mxk_language()
                if language == "" {
                    language = MXKLanguagePickerViewController.defaultLanguage()
                }
                var languageDescription = MXKLanguagePickerViewController.languageDescription(language)

                // Capitalise the description in the language locale
                let locale = NSLocale(localeIdentifier: language)
                languageDescription = languageDescription.capitalized(with: locale as Locale)

                cell.textLabel?.textColor = ThemeService.shared.theme.textPrimaryColor

                cell.textLabel?.text = NSLocalizedString("settings_ui_language", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                cell.detailTextLabel?.text = languageDescription

                cell.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()
                cell.selectionStyle = .default
            } else if row == UserInterface.themeIndex.rawValue {
                if let dequeue = tableView.dequeueReusableCell(withIdentifier: kSettingsViewControllerPhoneBookCountryCellId) {
                    cell = dequeue
                }
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: kSettingsViewControllerPhoneBookCountryCellId)
                }

                var theme = RiotSettings.shared.userInterfaceTheme

                if theme == "" {
                    theme = "auto"
                }

                theme = "settings_ui_theme_\(theme)"
                let i18nTheme = NSLocalizedString(
                    theme,
                    tableName: "Vector",
                    bundle: Bundle.main,
                    value: "",
                    comment: "")

                cell.textLabel?.textColor = ThemeService.shared.theme.textPrimaryColor

                cell.textLabel?.text = NSLocalizedString("settings_ui_theme", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                cell.detailTextLabel?.text = i18nTheme

                cell.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()
                cell.selectionStyle = .default
            }
        } else if section == SectionTag.ignoredUsers.rawValue {
            let ignoredUserCell = getDefaultTableViewCell(tableView)

            ignoredUserCell?.textLabel.text = session?.ignoredUsers[row]

            if let ignoredUserCell = ignoredUserCell {
                cell = ignoredUserCell
            }
        } else if section == SectionTag.localContacts.rawValue {
            if row == LocalContacts.syncIndex.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)

                labelAndSwitchCell?.mxkLabel.numberOfLines = 0
                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_contacts_discover_matrix_users", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.on = MXKAppSettings.standard().syncLocalContacts
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = true
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(toggleLocalContactsSync(_:)), for: .touchUpInside)

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            } else if row == LocalContacts.phonebookCountryIndex.rawValue {
                if let dequeue = tableView.dequeueReusableCell(withIdentifier: kSettingsViewControllerPhoneBookCountryCellId) {
                    cell = dequeue
                }
                if cell == nil {
                    cell = UITableViewCell(style: .value1, reuseIdentifier: kSettingsViewControllerPhoneBookCountryCellId)
                }

                var countryCode = MXKAppSettings.standard().phonebookCountryCode()
                let local = NSLocale(localeIdentifier: Bundle.main.preferredLocalizations[0])
                let countryName = local.displayName(forKey: .countryCode, value: countryCode)

                cell.textLabel?.textColor = ThemeService.shared.theme.textPrimaryColor

                cell.textLabel?.text = NSLocalizedString("settings_contacts_phonebook_country", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                cell.detailTextLabel?.text = countryName

                cell.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()
                cell.selectionStyle = .default
            }
        } else if section == SectionTag.advanced.rawValue {
            let configCell = textViewCell(for: tableView, at: indexPath)

            let configFormat = "\(Bundle.mxk_localizedString(forKey: "settings_config_user_id"))\n\(Bundle.mxk_localizedString(forKey: "settings_config_home_server"))\n\(Bundle.mxk_localizedString(forKey: "settings_config_identity_server"))"

            if let userId = account?.mxCredentials.userId, let homeServer = account?.mxCredentials.homeServer, let identityServerURL = account?.identityServerURL {
                configCell?.mxkTextView.text = String(format: configFormat, userId, homeServer, identityServerURL)
            }
            configCell?.mxkTextView.accessibilityIdentifier = "SettingsVCConfigStaticText"

            if let configCell = configCell {
                cell = configCell
            }
        } else if section == SectionTag.other.rawValue {
            if row == Other.versionIndex.rawValue {
                let versionCell = getDefaultTableViewCell(tableView)

                let appVersion = AppDelegate.the().appVersion
                let build = AppDelegate.the().build

                versionCell?.textLabel.text = String.localizedStringWithFormat(NSLocalizedString("settings_version", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), "\(appVersion) \(build)")

                versionCell?.selectionStyle = UITableViewCell.SelectionStyle.none

                if let versionCell = versionCell {
                    cell = versionCell
                }
            } else if row == Other.olmVersionIndex.rawValue {
                let versionCell = getDefaultTableViewCell(tableView)

                versionCell?.textLabel.text = String.localizedStringWithFormat(NSLocalizedString("settings_olm_version", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), OLMKit.versionString())

                versionCell?.selectionStyle = UITableViewCell.SelectionStyle.none

                if let versionCell = versionCell {
                    cell = versionCell
                }
            } else if row == Other.termConditionsIndex.rawValue {
                let termAndConditionCell = getDefaultTableViewCell(tableView)

                termAndConditionCell?.textLabel.text = NSLocalizedString("settings_term_conditions", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                termAndConditionCell?.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()

                if let termAndConditionCell = termAndConditionCell {
                    cell = termAndConditionCell
                }
            } else if row == Other.copyrightIndex.rawValue {
                let copyrightCell = getDefaultTableViewCell(tableView)

                copyrightCell?.textLabel.text = NSLocalizedString("settings_copyright", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                copyrightCell?.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()

                if let copyrightCell = copyrightCell {
                    cell = copyrightCell
                }
            } else if row == Other.privacyIndex.rawValue {
                let privacyPolicyCell = getDefaultTableViewCell(tableView)

                privacyPolicyCell?.textLabel.text = NSLocalizedString("settings_privacy_policy", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                privacyPolicyCell?.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()

                if let privacyPolicyCell = privacyPolicyCell {
                    cell = privacyPolicyCell
                }
            } else if row == Other.thirdPartyIndex.rawValue {
                let thirdPartyCell = getDefaultTableViewCell(tableView)

                thirdPartyCell?.textLabel.text = NSLocalizedString("settings_third_party_notices", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                thirdPartyCell?.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()

                if let thirdPartyCell = thirdPartyCell {
                    cell = thirdPartyCell
                }
            } else if row == Other.showNsfwRoomsIndex.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)

                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_show_NSFW_public_rooms", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                labelAndSwitchCell?.mxkSwitch.on = RiotSettings.shared.showNSFWPublicRooms
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                labelAndSwitchCell?.mxkSwitch.enabled = true
                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(toggleNSFWPublicRoomsFiltering(_:)), for: .touchUpInside)

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            } else if row == Other.crashReportIndex.rawValue {
                let sendCrashReportCell = getLabelAndSwitchCell(tableView, for: indexPath)

                sendCrashReportCell?.mxkLabel.text = NSLocalizedString("settings_send_crash_report", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                sendCrashReportCell?.mxkSwitch.on = RiotSettings.shared.enableCrashReport
                sendCrashReportCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                sendCrashReportCell?.mxkSwitch.enabled = true
                sendCrashReportCell?.mxkSwitch.addTarget(self, action: #selector(toggleSendCrashReport(_:)), for: .touchUpInside)

                if let sendCrashReportCell = sendCrashReportCell {
                    cell = sendCrashReportCell
                }
            } else if row == Other.enableRageshakeIndex.rawValue {
                let enableRageShakeCell = getLabelAndSwitchCell(tableView, for: indexPath)

                enableRageShakeCell?.mxkLabel.text = NSLocalizedString("settings_enable_rageshake", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                enableRageShakeCell?.mxkSwitch.on = RiotSettings.shared.enableRageShake
                enableRageShakeCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor
                enableRageShakeCell?.mxkSwitch.enabled = true
                enableRageShakeCell?.mxkSwitch.addTarget(self, action: #selector(toggleEnableRageShake(_:)), for: .touchUpInside)

                if let enableRageShakeCell = enableRageShakeCell {
                    cell = enableRageShakeCell
                }
            } else if row == Other.markAllAsReadIndex.rawValue {
                var markAllBtnCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithButton.defaultReuseIdentifier()) as? MXKTableViewCellWithButton
                if markAllBtnCell == nil {
                    markAllBtnCell = MXKTableViewCellWithButton()
                } else {
                    // Fix https://github.com/vector-im/riot-ios/issues/1354
                    markAllBtnCell?.mxkButton.titleLabel?.text = nil
                }

                let btnTitle = NSLocalizedString("settings_mark_all_as_read", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                markAllBtnCell?.mxkButton.setTitle(btnTitle, for: .normal)
                markAllBtnCell?.mxkButton.setTitle(btnTitle, for: .highlighted)
                markAllBtnCell?.mxkButton.tintColor = ThemeService.shared.theme.tintColor
                markAllBtnCell?.mxkButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)

                markAllBtnCell?.mxkButton.removeTarget(self, action: nil, for: .touchUpInside)
                markAllBtnCell?.mxkButton.addTarget(self, action: #selector(markAll(asRead:)), for: .touchUpInside)
                markAllBtnCell?.mxkButton.accessibilityIdentifier = nil

                if let markAllBtnCell = markAllBtnCell {
                    cell = markAllBtnCell
                }
            } else if row == Other.clearCacheIndex.rawValue {
                var clearCacheBtnCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithButton.defaultReuseIdentifier()) as? MXKTableViewCellWithButton
                if clearCacheBtnCell == nil {
                    clearCacheBtnCell = MXKTableViewCellWithButton()
                } else {
                    // Fix https://github.com/vector-im/riot-ios/issues/1354
                    clearCacheBtnCell?.mxkButton.titleLabel?.text = nil
                }

                let btnTitle = NSLocalizedString("settings_clear_cache", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                clearCacheBtnCell?.mxkButton.setTitle(btnTitle, for: .normal)
                clearCacheBtnCell?.mxkButton.setTitle(btnTitle, for: .highlighted)
                clearCacheBtnCell?.mxkButton.tintColor = ThemeService.shared.theme.tintColor
                clearCacheBtnCell?.mxkButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)

                clearCacheBtnCell?.mxkButton.removeTarget(self, action: nil, for: .touchUpInside)
                clearCacheBtnCell?.mxkButton.addTarget(self, action: #selector(clearCache(_:)), for: .touchUpInside)
                clearCacheBtnCell?.mxkButton.accessibilityIdentifier = nil

                if let clearCacheBtnCell = clearCacheBtnCell {
                    cell = clearCacheBtnCell
                }
            } else if row == Other.reportBugIndex.rawValue {
                var reportBugBtnCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithButton.defaultReuseIdentifier()) as? MXKTableViewCellWithButton
                if reportBugBtnCell == nil {
                    reportBugBtnCell = MXKTableViewCellWithButton()
                } else {
                    // Fix https://github.com/vector-im/riot-ios/issues/1354
                    reportBugBtnCell?.mxkButton.titleLabel?.text = nil
                }

                let btnTitle = NSLocalizedString("settings_report_bug", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                reportBugBtnCell?.mxkButton.setTitle(btnTitle, for: .normal)
                reportBugBtnCell?.mxkButton.setTitle(btnTitle, for: .highlighted)
                reportBugBtnCell?.mxkButton.tintColor = ThemeService.shared.theme.tintColor
                reportBugBtnCell?.mxkButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)

                reportBugBtnCell?.mxkButton.removeTarget(self, action: nil, for: .touchUpInside)
                reportBugBtnCell?.mxkButton.addTarget(self, action: #selector(reportBug(_:)), for: .touchUpInside)
                reportBugBtnCell?.mxkButton.accessibilityIdentifier = nil

                if let reportBugBtnCell = reportBugBtnCell {
                    cell = reportBugBtnCell
                }
            }
        } else if section == SectionTag.labs.rawValue {
            if row == EnumA.labs_ENABLE_RINGING_FOR_GROUP_CALLS_INDEX.rawValue {
                let labelAndSwitchCell = getLabelAndSwitchCell(tableView, for: indexPath)

                labelAndSwitchCell?.mxkLabel.text = NSLocalizedString("settings_labs_enable_ringing_for_group_calls", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                labelAndSwitchCell?.mxkSwitch.on = RiotSettings.shared.enableRingingForGroupCalls
                labelAndSwitchCell?.mxkSwitch.onTintColor = ThemeService.shared.theme.tintColor

                labelAndSwitchCell?.mxkSwitch.addTarget(self, action: #selector(toggleEnableRinging(forGroupCalls:)), for: .valueChanged)

                if let labelAndSwitchCell = labelAndSwitchCell {
                    cell = labelAndSwitchCell
                }
            }
        } else if section == SectionTag.flair.rawValue {
            let indexPath = IndexPath(row: row, section: groupsDataSource?.joinedGroupsSection ?? 0)
            if let table = groupsDataSource?.tableView(tableView, cellForRowAt: indexPath) {
                cell = table
            }

            if cell is GroupTableViewCellWithSwitch {
                let groupWithSwitchCell = cell as? GroupTableViewCellWithSwitch
                weak var groupCellData = groupsDataSource?.cellData(atIndex: indexPath)

                // Display the groupId in the description label, except if the group has no name
                if groupWithSwitchCell?.groupName.text != groupCellData?.group.groupId {
                    groupWithSwitchCell?.groupDescription.hidden = false
                    groupWithSwitchCell?.groupDescription.text = groupCellData?.group.groupId
                }

                // Update the toogle button
                groupWithSwitchCell?.toggleButton.on = groupCellData?.group.summary.user.isPublicised
                groupWithSwitchCell?.toggleButton.enabled = true
                groupWithSwitchCell?.toggleButton.tag = row

                groupWithSwitchCell?.toggleButton.removeTarget(self, action: nil, for: .touchUpInside)
                groupWithSwitchCell?.toggleButton.addTarget(self, action: #selector(toggleCommunityFlair(_:)), for: .touchUpInside)
            }
        } else if section == SectionTag.security.rawValue {
            switch row {
            case EnumC.security_BUTTON_INDEX.rawValue:
                if let get = getDefaultTableViewCell(tableView) {
                    cell = get
                }
                cell.textLabel?.text = NSLocalizedString("security_settings_title", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                cell.vc_setAccessoryDisclosureIndicatorWithCurrentTheme()
            default:
                break
            }
        } else if section == SectionTag.deactivateAccount.rawValue {
            var deactivateAccountBtnCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithButton.defaultReuseIdentifier()) as? MXKTableViewCellWithButton

            if deactivateAccountBtnCell == nil {
                deactivateAccountBtnCell = MXKTableViewCellWithButton()
            } else {
                // Fix https://github.com/vector-im/riot-ios/issues/1354
                deactivateAccountBtnCell?.mxkButton.titleLabel?.text = nil
            }

            let btnTitle = NSLocalizedString("settings_deactivate_my_account", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            deactivateAccountBtnCell?.mxkButton.setTitle(btnTitle, for: .normal)
            deactivateAccountBtnCell?.mxkButton.setTitle(btnTitle, for: .highlighted)
            deactivateAccountBtnCell?.mxkButton.tintColor = ThemeService.shared.theme.warningColor
            deactivateAccountBtnCell?.mxkButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)

            deactivateAccountBtnCell?.mxkButton.removeTarget(self, action: nil, for: .touchUpInside)
            deactivateAccountBtnCell?.mxkButton.addTarget(self, action: #selector(deactivateAccountAction), for: .touchUpInside)
            deactivateAccountBtnCell?.mxkButton.accessibilityIdentifier = nil

            if let deactivateAccountBtnCell = deactivateAccountBtnCell {
                cell = deactivateAccountBtnCell
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionObj = tableViewSections?.section(at: section)
        return sectionObj?.headerTitle
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if view is UITableViewHeaderFooterView {
            // Customize label style
            let tableViewHeaderFooterView = view as? UITableViewHeaderFooterView
            tableViewHeaderFooterView?.textLabel?.textColor = ThemeService.shared.theme.textPrimaryColor
            tableViewHeaderFooterView?.textLabel?.font = UIFont.systemFont(ofSize: 15)
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let tagsIndexPath = tableViewSections?.tagsIndexPath(fromTableViewIndexPath: indexPath)
        let section = tagsIndexPath?.section ?? 0
        let row = tagsIndexPath?.row ?? 0

        if section == SectionTag.userSettings.rawValue {
            return row >= UserSettings.phonenumbersOffset.rawValue
        }
        return false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // iOS8 requires this method to enable editing (see editActionsForRowAtIndexPath).
    }

    // MARK: - UITableView delegate

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = ThemeService.shared.theme.backgroundColor

        if cell.selectionStyle != .none {
            // Update the selected background view
            if ThemeService.shared.theme.selectedBackgroundColor {
                cell.selectedBackgroundView = UIView()
                cell.selectedBackgroundView?.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor
            } else {
                if tableView.style == .plain {
                    cell.selectedBackgroundView = nil
                } else {
                    cell.selectedBackgroundView?.backgroundColor = nil
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 24
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 24
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let tagsIndexPath = tableViewSections?.tagsIndexPath(fromTableViewIndexPath: indexPath)
        let section = tagsIndexPath?.section ?? 0
        let row = tagsIndexPath?.row ?? 0

        var actions: [AnyHashable]?

        // Add the swipe to delete user's email or phone number
        if section == SectionTag.userSettings.rawValue {
            if row >= UserSettings.phonenumbersOffset.rawValue {
                actions = []

                let cell = tableView.cellForRow(at: indexPath)
                let cellHeight = (cell != nil ? cell?.frame.size.height : 50) ?? 0.0

                // Patch: Force the width of the button by adding whitespace characters into the title string.
                let leaveAction = UITableViewRowAction(style: .destructive, title: "    ", handler: { [self] action, indexPath in

                    onRemove3PID(indexPath)

                })

                leaveAction.backgroundColor = MXKTools.convertImage(toPatternColor: "remove_icon_pink", backgroundColor: ThemeService.shared.theme.headerBackgroundColor, patternSize: CGSize(width: 50, height: cellHeight), resourceSize: CGSize(width: 24, height: 24))
                actions?.insert(leaveAction, at: 0)
            }
        }

        return actions as? [UITableViewRowAction]
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.tableView == tableView {
            let tagsIndexPath = tableViewSections?.tagsIndexPath(fromTableViewIndexPath: indexPath)
            let section = tagsIndexPath?.section ?? 0
            let row = tagsIndexPath?.row ?? 0

            if section == SectionTag.userInterface.rawValue {
                if row == UserInterface.languageIndex.rawValue {
                    // Display the language picker
                    let languagePickerViewController = LanguagePickerViewController()
                    languagePickerViewController.selectedLanguage = Bundle.mxk_language()
                    languagePickerViewController.delegate = self
                    push(languagePickerViewController)
                } else if row == UserInterface.themeIndex.rawValue {
                    showThemePicker()
                }
            } else if section == SectionTag.userSettings.rawValue && row == UserSettings.threepidsInformationIndex.rawValue {
                // settingsDiscoveryTableViewSection is a dynamic section, so check number of rows before scroll to avoid crashes
                if (settingsDiscoveryTableViewSection?.numberOfRows ?? 0) > 0 {
                    let discoveryIndexPath = tableViewSections?.exactIndexPath(forRowTag: 0, sectionTag: SectionTag.discovery)
                    if let discoveryIndexPath = discoveryIndexPath {
                        tableView.scrollToRow(at: discoveryIndexPath, at: .top, animated: true)
                    }
                } else {
                    //  this won't be precise in scroll location, but seems the best option for now
                    let discoveryIndexPath = tableViewSections?.nearestIndexPath(forRowTag: 0, sectionTag: SectionTag.discovery)
                    if let discoveryIndexPath = discoveryIndexPath {
                        tableView.scrollToRow(at: discoveryIndexPath, at: .middle, animated: true)
                    }
                }
            } else if section == SectionTag.userSettings.rawValue && row == UserSettings.inviteFriendsIndex.rawValue {
                let selectedCell = tableView.cellForRow(at: indexPath)
                showInviteFriends(fromSourceView: selectedCell)
            } else if section == SectionTag.notifications.rawValue && row == NotificationSettings.systemSettings.rawValue {
                openSystemSettingsApp()
            } else if section == SectionTag.discovery.rawValue {
                settingsDiscoveryTableViewSection?.selectRow(row)
            } else if section == SectionTag.identityServer.rawValue {
                switch row {
                case IdentityServer.index.rawValue:
                    showIdentityServerSettingsScreen()
                default:
                    break
                }
            } else if section == SectionTag.ignoredUsers.rawValue {
                let session = mainSession

                let ignoredUserId = session?.ignoredUsers[row] as? String

                if let ignoredUserId = ignoredUserId {
                    currentAlert?.dismiss(animated: false)

                    weak var weakSelf = self

                    currentAlert = UIAlertController(title: String.localizedStringWithFormat(NSLocalizedString("settings_unignore_user", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), ignoredUserId), message: nil, preferredStyle: .alert)

                    currentAlert?.addAction(
                        UIAlertAction(
                            title: Bundle.mxk_localizedString(forKey: "yes"),
                            style: .default,
                            handler: { [self] action in

                                if let weakSelf = weakSelf {
                                    let self = weakSelf
                                    currentAlert = nil

                                    let session = mainSession

                                    // Remove the member from the ignored user list
                                    startActivityIndicator()
                                    session?.unIgnoreUsers([ignoredUserId], success: { [self] in

                                        stopActivityIndicator()

                                    }, failure: { [self] error in

                                        stopActivityIndicator()

                                        MXLogDebug("[SettingsViewController] Unignore %@ failed", ignoredUserId)

                                        let myUserId = session?.myUser.userId
                                        NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != nil ? [
                                            kMXKErrorUserIdKey: myUserId ?? ""
                                        ] : nil)

                                    })
                                }

                            }))

                    currentAlert?.addAction(
                        UIAlertAction(
                            title: Bundle.mxk_localizedString(forKey: "no"),
                            style: .default,
                            handler: { [self] action in

                                if let weakSelf = weakSelf {
                                    let self = weakSelf
                                    currentAlert = nil
                                }

                            }))

                    currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCUnignoreAlert")
                    if let currentAlert = currentAlert {
                        present(currentAlert, animated: true)
                    }
                }
            } else if section == SectionTag.other.rawValue {
                if row == Other.copyrightIndex.rawValue {
                    let webViewViewController = WebViewViewController(url: BuildSettings.applicationCopyrightUrlString)

                    webViewViewController.title = NSLocalizedString("settings_copyright", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                    push(webViewViewController)
                } else if row == Other.termConditionsIndex.rawValue {
                    let webViewViewController = WebViewViewController(url: BuildSettings.applicationTermsConditionsUrlString)

                    webViewViewController.title = NSLocalizedString("settings_term_conditions", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                    push(webViewViewController)
                } else if row == Other.privacyIndex.rawValue {
                    let webViewViewController = WebViewViewController(url: BuildSettings.applicationPrivacyPolicyUrlString)

                    webViewViewController.title = NSLocalizedString("settings_privacy_policy", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                    push(webViewViewController)
                } else if row == Other.thirdPartyIndex.rawValue {
                    let htmlFile = Bundle.main.path(forResource: "third_party_licenses", ofType: "html", inDirectory: nil)

                    let webViewViewController = WebViewViewController(localHTMLFile: htmlFile)

                    webViewViewController.title = NSLocalizedString("settings_third_party_notices", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

                    push(webViewViewController)
                }
            } else if section == SectionTag.userSettings.rawValue {
                if row == UserSettings.profilePictureIndex.rawValue {
                    onProfileAvatarTap(nil)
                } else if row == UserSettings.changePasswordIndex.rawValue {
                    displayPasswordAlert()
                } else if row == UserSettings.addEmailIndex.rawValue {
                    if !newEmailEditingEnabled {
                        // Enable the new email text field
                        newEmailEditingEnabled = true
                    } else if let newEmailTextField = newEmailTextField {
                        onAddNewEmail(newEmailTextField)
                    }
                } else if row == UserSettings.addPhonenumberIndex.rawValue {
                    if !newPhoneEditingEnabled {
                        // Enable the new phone text field
                        newPhoneEditingEnabled = true
                    } else if newPhoneNumberCell?.mxkTextField {
                        if let mxkTextField = newPhoneNumberCell?.mxkTextField {
                            onAddNewPhone(mxkTextField)
                        }
                    }
                }
            } else if section == SectionTag.localContacts.rawValue {
                if row == LocalContacts.phonebookCountryIndex.rawValue {
                    let countryPicker = CountryPickerViewController()
                    countryPicker.view.tag = SectionTag.localContacts
                    countryPicker.delegate = self
                    countryPicker.showCountryCallingCode = true
                    push(countryPicker)
                }
            } else if section == SectionTag.security.rawValue {
                switch row {
                case EnumC.security_BUTTON_INDEX.rawValue:
                    let securityViewController = SecurityViewController.instantiate(withMatrixSession: mainSession)

                    push(securityViewController)
                default:
                    break
                }
            } else if section == SectionTag.notifications.rawValue {
                if #available(iOS 14.0, *) {
                    switch row {
                    case NotificationSettings.defaultSettingsIndex.rawValue:
                        showNotificationSettings(NotificationSettingsScreenDefaultNotifications)
                    case NotificationSettings.mentionAndKeywordsSettingsIndex.rawValue:
                        showNotificationSettings(NotificationSettingsScreenMentionsAndKeywords)
                    case NotificationSettings.otherSettingsIndex.rawValue:
                        showNotificationSettings(NotificationSettingsScreenOther)
                    default:
                        break
                    }
                }
            }

            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - actions


    @objc func onSignout(_ sender: Any?) {
        signOutButton = sender as? UIButton

        let keyBackup = mainSession.crypto.backup

        signOutAlertPresenter?.present(
            for: keyBackup?.state,
            areThereKeysToBackup: keyBackup?.hasKeysToBackup,
            from: self,
            sourceView: signOutButton,
            animated: true)
    }

    func onRemove3PID(_ indexPath: IndexPath?) {
        let tagsIndexPath = tableViewSections?.tagsIndexPath(fromTableViewIndexPath: indexPath)
        let section = tagsIndexPath?.section ?? 0
        var row = tagsIndexPath?.row ?? 0

        if section == SectionTag.userSettings.rawValue {
            var address: String?
            var medium: String?
            let account = MXKAccountManager.shared().activeAccounts.first as? MXKAccount
            var promptMsg: String?

            if row >= UserSettings.emailsOffset.rawValue {
                medium = kMX3PIDMediumEmail
                row = row - UserSettings.emailsOffset.rawValue
                let linkedEmails = account?.linkedEmails
                if row < (linkedEmails?.count ?? 0) {
                    address = linkedEmails?[row]
                    promptMsg = String.localizedStringWithFormat(NSLocalizedString("settings_remove_email_prompt_msg", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), address ?? "")
                }
            } else if row >= UserSettings.phonenumbersOffset.rawValue {
                medium = kMX3PIDMediumMSISDN
                row = row - UserSettings.phonenumbersOffset.rawValue
                let linkedPhones = account?.linkedPhoneNumbers
                if row < (linkedPhones?.count ?? 0) {
                    address = linkedPhones?[row]
                    let e164 = "+\(address ?? "")"
                    var phoneNb: NBPhoneNumber? = nil
                    do {
                        phoneNb = try NBPhoneNumberUtil.sharedInstance().parse(e164, defaultRegion: nil)
                    } catch {
                    }
                    var phoneMunber: String? = nil
                    do {
                        phoneMunber = try NBPhoneNumberUtil.sharedInstance().format(phoneNb, numberFormat: NBEPhoneNumberFormatINTERNATIONAL)
                    } catch {
                    }

                    promptMsg = String.localizedStringWithFormat(NSLocalizedString("settings_remove_phone_prompt_msg", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), phoneMunber ?? "")
                }
            }

            if address != nil && medium != nil {
                weak var weakSelf = self

                if currentAlert != nil {
                    currentAlert?.dismiss(animated: false)
                    currentAlert = nil
                }

                // Remove ?
                currentAlert = UIAlertController(title: NSLocalizedString("settings_remove_prompt_title", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), message: promptMsg, preferredStyle: .alert)

                currentAlert?.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "cancel"),
                        style: .cancel,
                        handler: { [self] action in

                            if let weakSelf = weakSelf {
                                let self = weakSelf
                                currentAlert = nil
                            }

                        }))

                currentAlert?.addAction(
                    UIAlertAction(
                        title: NSLocalizedString("remove", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
                        style: .default,
                        handler: { [self] action in

                            if let weakSelf = weakSelf {
                                let self = weakSelf
                                currentAlert = nil

                                startActivityIndicator()

                                mainSession.matrixRestClient.remove3PID(address, medium: medium, success: { [self] in

                                    if weakSelf != nil {
                                        let self = weakSelf

                                        stopActivityIndicator()

                                        // Update linked 3pids
                                        loadAccount3PIDs()
                                    }

                                }, failure: { [self] error in

                                    MXLogDebug("[SettingsViewController] Remove 3PID: %@ failed", address)
                                    if weakSelf != nil {
                                        let self = weakSelf

                                        stopActivityIndicator()

                                        let myUserId = mainSession.myUser.userId // TODO: Hanlde multi-account
                                        NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != "" ? [
                                            kMXKErrorUserIdKey: myUserId
                                        ] : nil)
                                    }
                                })
                            }

                        }))

                currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCRemove3PIDAlert")
                if let currentAlert = currentAlert {
                    present(currentAlert, animated: true)
                }
            }
        }
    }

    @objc func togglePushNotifications(_ sender: UISwitch?) {
        // Check first whether the user allow notification from system settings
        if systemNotificationSettings?.authorizationStatus == .denied {
            currentAlert?.dismiss(animated: false)

            weak var weakSelf = self

            let title = NSLocalizedString("settings_notifications_disabled_alert_title", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
            let message = NSLocalizedString("settings_notifications_disabled_alert_message", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")

            currentAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)

            currentAlert?.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "cancel"),
                    style: .cancel,
                    handler: { [self] action in

                        if let weakSelf = weakSelf {
                            let self = weakSelf
                            currentAlert = nil
                        }

                    }))

            let settingsAction = UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "settings"),
                style: .default,
                handler: { [self] action in
                    if let weakSelf = weakSelf {
                        let self = weakSelf
                        currentAlert = nil

                        openSystemSettingsApp()
                    }
                })

            currentAlert?.addAction(settingsAction)
            currentAlert?.preferredAction = settingsAction

            currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCPushNotificationsAlert")
            if let currentAlert = currentAlert {
                present(currentAlert, animated: true)
            }

            // Keep off the switch
            sender?.isOn = false
        } else if MXKAccountManager.shared().activeAccounts.count {
            startActivityIndicator()

            let accountManager = MXKAccountManager.shared()
            let account = accountManager?.activeAccounts.first as? MXKAccount

            if accountManager?.apnsDeviceToken {
                account?.enablePushNotifications(!(account?.pushNotificationServiceIsActive)!, success: { [self] in
                    stopActivityIndicator()
                }, failure: { [self] error in
                    stopActivityIndicator()
                })
            } else {
                // Obtain device token when user has just enabled access to notifications from system settings
                AppDelegate.the().registerForRemoteNotifications() { [self] error in
                    if error != nil {
                        sender?.setOn(false, animated: true)
                        stopActivityIndicator()
                    } else {
                        account?.enablePushNotifications(true, success: { [self] in
                            stopActivityIndicator()
                        }, failure: { [self] error in
                            stopActivityIndicator()
                        })
                    }
                }
            }
        }
    }

    func openSystemSettingsApp() {
        let settingsAppURL = URL(string: UIApplication.openSettingsURLString)
        if let settingsAppURL = settingsAppURL {
            UIApplication.shared.open(settingsAppURL, options: [:])
        }
    }

    func toggleCallKit(_ sender: UISwitch?) {
        MXKAppSettings.standard().enableCallKit = sender?.isOn
    }

    @objc func toggleStunServerFallback(_ sender: UISwitch?) {
        RiotSettings.shared.allowStunServerFallback = sender?.isOn

        mainSession.callManager.fallbackSTUNServer = RiotSettings.shared.allowStunServerFallback ? BuildSettings.stunServerFallbackUrlString : nil
    }

    @objc func toggleAllowIntegrations(_ sender: UISwitch?) {
        let session = mainSession
        startActivityIndicator()

        var sharedSettings = RiotSharedSettings(session: session)
        sharedSettings.setIntegrationProvisioningWithEnabled(sender?.isOn, success: { [self] in
            sharedSettings = nil
            stopActivityIndicator()
        }, failure: { [self] error in
            sharedSettings = nil
            sender?.setOn(!(sender?.isOn ?? false), animated: true)
            stopActivityIndicator()
        })
    }

    @objc func toggleShowDecodedContent(_ sender: UISwitch?) {
        RiotSettings.shared.showDecryptedContentInNotifications = sender?.isOn
    }

    @objc func toggleLocalContactsSync(_ sender: UISwitch?) {
        if sender?.isOn ?? false {
            MXKContactManager.requestUserConfirmationForLocalContactsSync(in: self) { [self] granted in

                MXKAppSettings.standard().syncLocalContacts = granted

                updateSections()
            }
        } else {
            MXKAppSettings.standard().syncLocalContacts = false

            updateSections()
        }
    }

    @objc func toggleSendCrashReport(_ sender: Any?) {
        let enable = RiotSettings.shared.enableCrashReport
        if enable {
            MXLogDebug("[SettingsViewController] disable automatic crash report and analytics sending")

            RiotSettings.shared.enableCrashReport = false

            Analytics.sharedInstance().stop()

            // Remove potential crash file.
            MXLogger.deleteCrashLog()
        } else {
            MXLogDebug("[SettingsViewController] enable automatic crash report and analytics sending")

            RiotSettings.shared.enableCrashReport = true

            Analytics.sharedInstance().start()
        }
    }

    @objc func toggleEnableRageShake(_ sender: UISwitch?) {
        RiotSettings.shared.enableRageShake = sender?.isOn

        updateSections()
    }

    @objc func toggleEnableRinging(forGroupCalls sender: UISwitch?) {
        RiotSettings.shared.enableRingingForGroupCalls = sender?.isOn
    }

    @objc func togglePinRooms(withMissedNotif sender: UISwitch?) {
        RiotSettings.shared.pinRoomsWithMissedNotificationsOnHome = sender?.isOn
    }

    @objc func togglePinRooms(withUnread sender: UISwitch?) {
        RiotSettings.shared.pinRoomsWithUnreadMessagesOnHome = sender?.isOn
    }

    @objc func toggleCommunityFlair(_ sender: UISwitch?) {
        let indexPath = IndexPath(row: sender?.tag ?? 0, section: groupsDataSource?.joinedGroupsSection ?? 0)
        weak var groupCellData = groupsDataSource?.cellData(atIndex: indexPath)
        let group = groupCellData?.group

        if let group = group {
            startActivityIndicator()

            weak var weakSelf = self

            mainSession.updateGroupPublicity(group, isPublicised: sender?.isOn, success: { [self] in

                if let weakSelf = weakSelf {
                    let self = weakSelf
                    stopActivityIndicator()
                }

            }, failure: { [self] error in

                if let weakSelf = weakSelf {
                    let self = weakSelf
                    stopActivityIndicator()

                    // Come back to previous state button
                    sender?.setOn(!(sender?.isOn ?? false), animated: true)

                    // Notify user
                    AppDelegate.the().showError(asAlert: error)
                }
            })
        }
    }

    @objc func markAll(asRead sender: Any?) {
        // Feedback: disable button and run activity indicator
        let button = sender as? UIButton
        button?.isEnabled = false
        startActivityIndicator()

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(0.3 * Double(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: { [self] in

            AppDelegate.the().markAllMessagesAsRead()

            stopActivityIndicator()
            button?.isEnabled = true

        })
    }

    @objc func clearCache(_ sender: Any?) {
        // Feedback: disable button and run activity indicator
        let button = sender as? UIButton
        button?.isEnabled = false

        launchClearCache()
    }

    func launchClearCache() {
        startActivityIndicator()

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(0.3 * Double(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {

            AppDelegate.the().reloadMatrixSessions(true)

        })
    }

    @objc func reportBug(_ sender: Any?) {
        let bugReportViewController = BugReportViewController()
        bugReportViewController.show(in: self)
    }

    @objc func selectPhoneNumberCountry(_ sender: Any?) {
        newPhoneNumberCountryPicker = CountryPickerViewController()
        newPhoneNumberCountryPicker?.view.tag = SectionTag.userSettings
        newPhoneNumberCountryPicker?.delegate = self
        newPhoneNumberCountryPicker?.showCountryCallingCode = true
        push(newPhoneNumberCountryPicker)
    }

    @objc func onSave(_ sender: Any?) {
        // sanity check
        if MXKAccountManager.shared().activeAccounts.count == 0 {
            return
        }

        navigationItem.rightBarButtonItem?.isEnabled = false
        startActivityIndicator()
        isSavingInProgress = true
        weak var weakSelf = self

        let account = MXKAccountManager.shared().activeAccounts.first as? MXKAccount
        let myUser = account?.mxSession.myUser

        if newDisplayName != nil && (myUser?.displayname != newDisplayName) {
            // Save display name
            account?.setUserDisplayName(newDisplayName, success: { [self] in

                if let weakSelf = weakSelf {
                    // Update the current displayname
                    let self = weakSelf
                    newDisplayName = nil

                    // Go to the next change saving step
                    onSave(nil)
                }

            }, failure: { [self] error in

                MXLogDebug("[SettingsViewController] Failed to set displayName")

                if let weakSelf = weakSelf {
                    let self = weakSelf
                    handleErrorDuringProfileChangeSaving(error)
                }

            })

            return
        }

        if newAvatarImage != nil {
            // Retrieve the current picture and make sure its orientation is up
            let updatedPicture = MXKTools.forceImageOrientationUp(newAvatarImage)

            // Upload picture
            let uploader = MXMediaManager.prepareUploader(withMatrixSession: account?.mxSession, initialRange: 0, andRange: 1.0)

            uploader?.uploadData(updatedPicture?.jpegData(compressionQuality: 0.5), filename: nil, mimeType: "image/jpeg", success: { [self] url in

                if let weakSelf = weakSelf {
                    let self = weakSelf

                    // Store uploaded picture url and trigger picture saving
                    uploadedAvatarURL = url
                    newAvatarImage = nil
                    onSave(nil)
                }


            }, failure: { [self] error in

                MXLogDebug("[SettingsViewController] Failed to upload image")

                if let weakSelf = weakSelf {
                    let self = weakSelf
                    handleErrorDuringProfileChangeSaving(error)
                }

            })

            return
        } else if uploadedAvatarURL != nil {
            account?.setUserAvatarUrl(
                uploadedAvatarURL,
                success: { [self] in

                    if let weakSelf = weakSelf {
                        let self = weakSelf
                        uploadedAvatarURL = nil
                        onSave(nil)
                    }

                },
                failure: { [self] error in

                    MXLogDebug("[SettingsViewController] Failed to set avatar url")

                    if let weakSelf = weakSelf {
                        let self = weakSelf
                        handleErrorDuringProfileChangeSaving(error)
                    }

                })

            return
        }

        // Backup is complete
        isSavingInProgress = false
        stopActivityIndicator()

        // Check whether destroy has been called durign saving
        if onReadyToDestroyHandler != nil {
            // Ready to destroy
            onReadyToDestroyHandler()
            onReadyToDestroyHandler = nil
        } else {
            updateSections()
        }
    }

    func handleErrorDuringProfileChangeSaving(_ error: Error?) {
        // Sanity check: retrieve the current root view controller
        let rootViewController = AppDelegate.the().window.rootViewController
        if let rootViewController = rootViewController {
            weak var weakSelf = self

            // Alert user
            var title = (error as NSError?)?.userInfo[NSLocalizedFailureReasonErrorKey] as? String
            if title == nil {
                title = Bundle.mxk_localizedString(forKey: "settings_fail_to_update_profile")
            }
            let msg = (error as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String

            currentAlert?.dismiss(animated: false)

            currentAlert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

            currentAlert?.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "cancel"),
                    style: .default,
                    handler: { [self] action in

                        if let weakSelf = weakSelf {
                            let self = weakSelf

                            currentAlert = nil

                            // Reset the updated displayname
                            newDisplayName = nil

                            // Discard picture change
                            uploadedAvatarURL = nil
                            newAvatarImage = nil

                            // Loop to end saving
                            onSave(nil)
                        }

                    }))

            currentAlert?.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "retry"),
                    style: .default,
                    handler: { [self] action in

                        if let weakSelf = weakSelf {
                            let self = weakSelf

                            currentAlert = nil

                            // Loop to retry saving
                            onSave(nil)
                        }

                    }))

            currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCSaveChangesFailedAlert")
            if let currentAlert = currentAlert {
                rootViewController.present(currentAlert, animated: true)
            }
        }
    }

    @IBAction func onAddNewEmail(_ sender: Any) {
        // Ignore empty field
        if (newEmailTextField?.text?.count ?? 0) == 0 {
            // Reset new email adding
            newEmailEditingEnabled = false
            return
        }

        // Email check
        if !MXTools.isEmailAddress(newEmailTextField?.text) {
            weak var weakSelf = self

            currentAlert?.dismiss(animated: false)

            currentAlert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "account_error_email_wrong_title"), message: Bundle.mxk_localizedString(forKey: "account_error_email_wrong_description"), preferredStyle: .alert)

            currentAlert?.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "ok"),
                    style: .default,
                    handler: { [self] action in

                        if let weakSelf = weakSelf {
                            let self = weakSelf

                            currentAlert = nil
                        }

                    }))

            currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCAddEmailAlert")
            if let currentAlert = currentAlert {
                present(currentAlert, animated: true)
            }

            return
        }

        // Dismiss the keyboard
        newEmailTextField?.resignFirstResponder()

        let session = mainSession

        showAuthenticationIfNeeded(forAdding: kMX3PIDMediumEmail, with: session) { [self] authParams in
            startActivityIndicator()

            var thirdPidAddSession: MX3PidAddSession?
            thirdPidAddSession = session?.threePidAddManager.startAddEmailSession(withEmail: newEmailTextField?.text, nextLink: nil, success: { [self] in

                showValidationEmailDialog(
                    withMessage: Bundle.mxk_localizedString(forKey: "account_email_validation_message"),
                    for3PidAddSession: thirdPidAddSession,
                    threePidAddManager: session?.threePidAddManager,
                    authenticationParameters: authParams)

            }, failure: { [self] error in

                stopActivityIndicator()

                MXLogDebug("[SettingsViewController] Failed to request email token")

                // Translate the potential MX error.
                let mxError = MXError(nsError: error)
                if mxError != nil && ((mxError.errcode == kMXErrCodeStringThreePIDInUse) || (mxError.errcode == kMXErrCodeStringServerNotTrusted)) {
                    var userInfo: [AnyHashable : Any]?
                    if (error as NSError).userInfo != nil {
                        userInfo = (error as NSError).userInfo
                    } else {
                        userInfo = [:]
                    }

                    userInfo?[NSLocalizedFailureReasonErrorKey] = nil

                    if mxError.errcode == kMXErrCodeStringThreePIDInUse {
                        userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_email_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                        userInfo?["error"] = NSLocalizedString("auth_email_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    } else {
                        userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                        userInfo?["error"] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    }

                    error = NSError(domain: (error as NSError).domain, code: (error as NSError).code, userInfo: userInfo as? [String : Any])
                } else if ((error as NSError).domain == MX3PidAddManagerErrorDomain) && (error as NSError).code == Int(MX3PidAddManagerErrorDomainIdentityServerRequired) {
                    error = NSError(domain: (error as NSError).domain, code: (error as NSError).code, userInfo: [
                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "auth_email_is_required")
                    ])
                }

                // Notify user
                let myUserId = session?.myUser.userId // TODO: Hanlde multi-account
                NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != nil ? [
                    kMXKErrorUserIdKey: myUserId ?? ""
                ] : nil)

            })
        }
    }

    @IBAction func onAddNewPhone(_ sender: Any) {
        // Ignore empty field
        if !newPhoneNumberCell?.mxkTextField.text.length {
            // Disable the new phone edition if the text field is empty
            newPhoneEditingEnabled = false
            return
        }

        // Phone check
        if !NBPhoneNumberUtil.sharedInstance().isValidNumber(newPhoneNumber) {
            currentAlert?.dismiss(animated: false)
            weak var weakSelf = self

            currentAlert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "account_error_msisdn_wrong_title"), message: Bundle.mxk_localizedString(forKey: "account_error_msisdn_wrong_description"), preferredStyle: .alert)

            currentAlert?.addAction(
                UIAlertAction(
                    title: Bundle.mxk_localizedString(forKey: "ok"),
                    style: .default,
                    handler: { [self] action in

                        if let weakSelf = weakSelf {
                            let self = weakSelf
                            currentAlert = nil
                        }

                    }))

            currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCAddMsisdnAlert")
            if let currentAlert = currentAlert {
                present(currentAlert, animated: true)
            }

            return
        }

        // Dismiss the keyboard
        newPhoneNumberCell?.mxkTextField.resignFirstResponder()

        let session = mainSession

        var e164: String? = nil
        do {
            e164 = try NBPhoneNumberUtil.sharedInstance().format(newPhoneNumber, numberFormat: NBEPhoneNumberFormatE164)
        } catch {
        }
        var msisdn: String?
        if e164?.hasPrefix("+") ?? false {
            msisdn = e164
        } else if e164?.hasPrefix("00") ?? false {
            msisdn = "+\((e164 as NSString?)?.substring(from: 2) ?? "")"
        }

        showAuthenticationIfNeeded(forAdding: kMX3PIDMediumMSISDN, with: session) { [self] authParams in
            startActivityIndicator()

            var new3Pid: MX3PidAddSession?
            new3Pid = session?.threePidAddManager.startAddPhoneNumberSession(withPhoneNumber: msisdn, countryCode: nil, success: { [self] in

                showValidationMsisdnDialog(withMessage: Bundle.mxk_localizedString(forKey: "account_msisdn_validation_message"), for3PidAddSession: new3Pid, threePidAddManager: session?.threePidAddManager, authenticationParameters: authParams)

            }, failure: { [self] error in

                stopActivityIndicator()

                MXLogDebug("[SettingsViewController] Failed to request msisdn token")

                // Translate the potential MX error.
                let mxError = MXError(nsError: error)
                if mxError != nil && ((mxError.errcode == kMXErrCodeStringThreePIDInUse) || (mxError.errcode == kMXErrCodeStringServerNotTrusted)) {
                    var userInfo: [AnyHashable : Any]?
                    if (error as NSError?)?.userInfo != nil {
                        userInfo = (error as NSError?)?.userInfo
                    } else {
                        userInfo = [:]
                    }

                    userInfo?[NSLocalizedFailureReasonErrorKey] = nil

                    if mxError.errcode == kMXErrCodeStringThreePIDInUse {
                        userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_phone_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                        userInfo?["error"] = NSLocalizedString("auth_phone_in_use", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    } else {
                        userInfo?[NSLocalizedDescriptionKey] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                        userInfo?["error"] = NSLocalizedString("auth_untrusted_id_server", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                    }

                    error = NSError(domain: (error as NSError?)?.domain ?? "", code: (error as NSError?)?.code ?? 0, userInfo: userInfo as? [String : Any])
                } else if ((error as NSError?)?.domain == MX3PidAddManagerErrorDomain) && (error as NSError?)?.code == Int(MX3PidAddManagerErrorDomainIdentityServerRequired) {
                    error = NSError(domain: (error as NSError?)?.domain ?? "", code: (error as NSError?)?.code ?? 0, userInfo: [
                        NSLocalizedDescriptionKey: Bundle.mxk_localizedString(forKey: "auth_phone_is_required")
                    ])
                }

                // Notify user
                let myUserId = session?.myUser.userId
                NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != nil ? [
                    kMXKErrorUserIdKey: myUserId ?? ""
                ] : nil)
            })
        }
    }

    func updateSaveButtonStatus() {
        if AppDelegate.the().mxSessions.count > 0 {
            let session = mainSession
            let myUser = session?.myUser

            var saveButtonEnabled = nil != newAvatarImage

            if !saveButtonEnabled {
                if let newDisplayName = newDisplayName {
                    saveButtonEnabled = !(myUser?.displayname == newDisplayName)
                }
            }

            navigationItem.rightBarButtonItem?.isEnabled = saveButtonEnabled
        }
    }

    @objc func onProfileAvatarTap(_ recognizer: UITapGestureRecognizer?) {
        let singleImagePickerPresenter = SingleImagePickerPresenter(session: mainSession)
        singleImagePickerPresenter.delegate = self

        let indexPath = tableViewSections?.exactIndexPath(
            forRowTag: UserSettings.profilePictureIndex,
            sectionTag: SectionTag.userSettings)
        if let indexPath = indexPath {
            let cell = tableView.cellForRow(at: indexPath)

            let sourceView = cell

            singleImagePickerPresenter.present(from: self, sourceView: sourceView, sourceRect: sourceView?.bounds, animated: true)

            imagePickerPresenter = singleImagePickerPresenter
        }
    }

    func showThemePicker() {
        weak var weakSelf = self

        var autoAction: UIAlertAction?
        var lightAction: UIAlertAction?
        var darkAction: UIAlertAction?
        var blackAction: UIAlertAction?
        var themePickerMessage: String?

        let actionBlock: ((_ action: UIAlertAction?) -> Void)? = { [self] action in

            if let weakSelf = weakSelf {
                let self = weakSelf

                var newTheme: String?
                if action == autoAction {
                    newTheme = "auto"
                } else if action == lightAction {
                    newTheme = "light"
                } else if action == darkAction {
                    newTheme = "dark"
                } else if action == blackAction {
                    newTheme = "black"
                }

                let theme = RiotSettings.shared.userInterfaceTheme
                if newTheme != nil && (newTheme != theme) {
                    // Clear fake Riot Avatars based on the previous theme.
                    AvatarGenerator.clear()

                    // The user wants to select this theme
                    RiotSettings.shared.userInterfaceTheme = newTheme
                    ThemeService.shared.themeId = newTheme

                    updateSections()
                }
            }
        }

        // Show "auto" only from iOS 11
        autoAction = UIAlertAction(
            title: NSLocalizedString("settings_ui_theme_auto", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
            style: .default,
            handler: actionBlock)

        // Explain what is "auto"
        if #available(iOS 13, *) {
            // Observe application did become active for iOS appearance setting changes
            themePickerMessage = NSLocalizedString("settings_ui_theme_picker_message_match_system_theme", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        } else {
            // Observe "Invert Colours" settings changes (available since iOS 11)
            themePickerMessage = NSLocalizedString("settings_ui_theme_picker_message_invert_colours", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
        }

        lightAction = UIAlertAction(
            title: NSLocalizedString("settings_ui_theme_light", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
            style: .default,
            handler: actionBlock)

        darkAction = UIAlertAction(
            title: NSLocalizedString("settings_ui_theme_dark", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
            style: .default,
            handler: actionBlock)
        blackAction = UIAlertAction(
            title: NSLocalizedString("settings_ui_theme_black", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
            style: .default,
            handler: actionBlock)


        let themePicker = UIAlertController(
            title: NSLocalizedString("settings_ui_theme_picker_title", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
            message: themePickerMessage,
            preferredStyle: .actionSheet)

        if let autoAction = autoAction {
            themePicker.addAction(autoAction)
        }
        if let lightAction = lightAction {
            themePicker.addAction(lightAction)
        }
        if let darkAction = darkAction {
            themePicker.addAction(darkAction)
        }
        if let blackAction = blackAction {
            themePicker.addAction(blackAction)
        }

        // Cancel button
        themePicker.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "cancel"),
                style: .cancel,
                handler: nil))

        let indexPath = tableViewSections?.exactIndexPath(
            forRowTag: UserInterface.themeIndex,
            sectionTag: SectionTag.userInterface)
        if let indexPath = indexPath {
            let fromCell = tableView.cellForRow(at: indexPath)
            themePicker.popoverPresentationController?.sourceView = fromCell
            themePicker.popoverPresentationController?.sourceRect = fromCell?.bounds ?? CGRect.zero
            present(themePicker, animated: true)
        }
    }

    @objc func deactivateAccountAction() {
        let deactivateAccountViewController = DeactivateAccountViewController.instantiate(withMatrixSession: mainSession)

        let navigationController = RiotNavigationController(rootViewController: deactivateAccountViewController) as? UINavigationController
        navigationController?.modalPresentationStyle = .formSheet

        if let navigationController = navigationController {
            present(navigationController, animated: true)
        }

        deactivateAccountViewController?.delegate = self

        self.deactivateAccountViewController = deactivateAccountViewController
    }

    func showInviteFriends(fromSourceView sourceView: UIView?) {
        if inviteFriendsPresenter == nil {
            inviteFriendsPresenter = InviteFriendsPresenter()
        }

        let userId = mainSession.myUser.userId

        inviteFriendsPresenter?.present(
            for: userId,
            from: self,
            sourceView: sourceView,
            animated: true)
    }

    @objc func toggleNSFWPublicRoomsFiltering(_ sender: UISwitch?) {
        RiotSettings.shared.showNSFWPublicRooms = sender?.isOn
    }

    // MARK: - TextField listener

    @IBAction func textFieldDidChange(_ sender: Any) {
        let textField = sender as? UITextField

        if textField?.tag == UserSettings.displaynameIndex.rawValue {
            // Remove white space from both ends
            newDisplayName = textField?.text?.trimmingCharacters(in: CharacterSet.whitespaces)
            updateSaveButtonStatus()
        } else if textField?.tag == UserSettings.addPhonenumberIndex.rawValue {
            do {
                newPhoneNumber = try NBPhoneNumberUtil.sharedInstance().parse(textField?.text, defaultRegion: newPhoneNumberCell?.isoCountryCode)
            } catch {
            }

            formatNewPhoneNumber()
        }
    }

    @IBAction func textFieldDidEnd(_ sender: Any) {
        let textField = sender as? UITextField

        // Disable the new email edition if the user leaves the text field empty
        if textField?.tag == UserSettings.addEmailIndex.rawValue && (textField?.text?.count ?? 0) == 0 && !keepNewEmailEditing {
            newEmailEditingEnabled = false
        } else if textField?.tag == UserSettings.addPhonenumberIndex.rawValue && (textField?.text?.count ?? 0) == 0 && !keepNewPhoneNumberEditing && newPhoneNumberCountryPicker == nil {
            // Disable the new phone edition if the user leaves the text field empty
            newPhoneEditingEnabled = false
        }
    }

    // MARK: - UITextField delegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.tag == UserSettings.displaynameIndex.rawValue {
            textField.textAlignment = .left
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == UserSettings.displaynameIndex.rawValue {
            textField.textAlignment = .right
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == UserSettings.displaynameIndex.rawValue {
            textField.resignFirstResponder()
        } else if textField.tag == UserSettings.addEmailIndex.rawValue {
            onAddNewEmail(textField)
        }

        return true
    }

    //#pragma password update management

    @IBAction func passwordTextFieldDidChange(_ sender: Any) {
        savePasswordAction?.isEnabled = ((currentPasswordTextField?.text?.count ?? 0) > 0) && ((newPasswordTextField1?.text?.count ?? 0) > 2) && (newPasswordTextField1?.text == newPasswordTextField2?.text)
    }

    func displayPasswordAlert() {
        weak var weakSelf = self
        resetPwdAlertController?.dismiss(animated: false)

        resetPwdAlertController = UIAlertController(title: NSLocalizedString("settings_change_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), message: nil, preferredStyle: .alert)
        resetPwdAlertController?.accessibilityLabel = "ChangePasswordAlertController"
        savePasswordAction = UIAlertAction(title: NSLocalizedString("save", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), style: .default, handler: { [self] action in

            if let weakSelf = weakSelf {
                let self = weakSelf

                resetPwdAlertController = nil

                if MXKAccountManager.shared().activeAccounts.count > 0 {
                    startActivityIndicator()
                    isResetPwdInProgress = true

                    let account = MXKAccountManager.shared().activeAccounts.first as? MXKAccount

                    account?.changePassword(currentPasswordTextField?.text, with: newPasswordTextField1?.text, success: { [self] in

                        if weakSelf != nil {
                            let self = weakSelf

                            isResetPwdInProgress = false
                            stopActivityIndicator()

                            // Display a successful message only if the settings screen is still visible (destroy is not called yet)
                            if onReadyToDestroyHandler == nil {
                                currentAlert?.dismiss(animated: false)

                                currentAlert = UIAlertController(title: nil, message: NSLocalizedString("settings_password_updated", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), preferredStyle: .alert)

                                currentAlert?.addAction(
                                    UIAlertAction(
                                        title: Bundle.mxk_localizedString(forKey: "ok"),
                                        style: .default,
                                        handler: { [self] action in

                                            if weakSelf != nil {
                                                let self = weakSelf
                                                currentAlert = nil

                                                // Check whether destroy has been called durign pwd change
                                                if onReadyToDestroyHandler != nil {
                                                    // Ready to destroy
                                                    onReadyToDestroyHandler()
                                                    onReadyToDestroyHandler = nil
                                                }
                                            }

                                        }))

                                currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCOnPasswordUpdatedAlert")
                                if let currentAlert = currentAlert {
                                    present(currentAlert, animated: true)
                                }
                            } else {
                                // Ready to destroy
                                onReadyToDestroyHandler()
                                onReadyToDestroyHandler = nil
                            }
                        }

                    }, failure: { [self] error in

                        if weakSelf != nil {
                            let self = weakSelf

                            isResetPwdInProgress = false
                            stopActivityIndicator()

                            // Display a failure message on the current screen
                            let rootViewController = AppDelegate.the().window.rootViewController
                            if let rootViewController = rootViewController {
                                currentAlert?.dismiss(animated: false)

                                currentAlert = UIAlertController(title: nil, message: NSLocalizedString("settings_fail_to_update_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""), preferredStyle: .alert)

                                currentAlert?.addAction(
                                    UIAlertAction(
                                        title: Bundle.mxk_localizedString(forKey: "ok"),
                                        style: .default,
                                        handler: { [self] action in

                                            if weakSelf != nil {
                                                let self = weakSelf

                                                currentAlert = nil

                                                // Check whether destroy has been called durign pwd change
                                                if onReadyToDestroyHandler != nil {
                                                    // Ready to destroy
                                                    onReadyToDestroyHandler()
                                                    onReadyToDestroyHandler = nil
                                                }
                                            }

                                        }))

                                currentAlert?.mxk_setAccessibilityIdentifier("SettingsVCPasswordChangeFailedAlert")
                                if let currentAlert = currentAlert {
                                    rootViewController.present(currentAlert, animated: true)
                                }
                            }
                        }

                    })
                }
            }

        })

        // disable by default
        // check if the textfields have the right value
        savePasswordAction?.isEnabled = false

        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: { [self] action in

            if let weakSelf = weakSelf {
                let self = weakSelf

                resetPwdAlertController = nil
            }

        })

        resetPwdAlertController?.addTextField(configurationHandler: { [self] textField in

            if let weakSelf = weakSelf {
                let self = weakSelf

                currentPasswordTextField = textField
                currentPasswordTextField?.placeholder = NSLocalizedString("settings_old_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                currentPasswordTextField?.isSecureTextEntry = true
                currentPasswordTextField?.addTarget(self, action: #selector(passwordTextFieldDidChange(_:)), for: .editingChanged)
            }

        })

        resetPwdAlertController?.addTextField(configurationHandler: { [self] textField in

            if let weakSelf = weakSelf {
                let self = weakSelf

                newPasswordTextField1 = textField
                newPasswordTextField1?.placeholder = NSLocalizedString("settings_new_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                newPasswordTextField1?.isSecureTextEntry = true
                newPasswordTextField1?.addTarget(self, action: #selector(passwordTextFieldDidChange(_:)), for: .editingChanged)
            }

        })

        resetPwdAlertController?.addTextField(configurationHandler: { [self] textField in

            if let weakSelf = weakSelf {
                let self = weakSelf

                newPasswordTextField2 = textField
                newPasswordTextField2?.placeholder = NSLocalizedString("settings_confirm_password", tableName: "Vector", bundle: Bundle.main, value: "", comment: "")
                newPasswordTextField2?.isSecureTextEntry = true
                newPasswordTextField2?.addTarget(self, action: #selector(passwordTextFieldDidChange(_:)), for: .editingChanged)
            }
        })


        resetPwdAlertController?.addAction(cancel)
        if let savePasswordAction = savePasswordAction {
            resetPwdAlertController?.addAction(savePasswordAction)
        }
        if let resetPwdAlertController = resetPwdAlertController {
            present(resetPwdAlertController, animated: true)
        }
    }

    // MARK: - MXKCountryPickerViewControllerDelegate

    func countryPickerViewController(_ countryPickerViewController: MXKCountryPickerViewController?, didSelectCountry isoCountryCode: String?) {
        if countryPickerViewController?.view.tag == .localContacts {
            MXKAppSettings.standard().phonebookCountryCode = isoCountryCode
        } else if countryPickerViewController?.view.tag == .userSettings {
            if let newPhoneNumberCell = newPhoneNumberCell {
                newPhoneNumberCell?.isoCountryCode = isoCountryCode

                do {
                    newPhoneNumber = try NBPhoneNumberUtil.sharedInstance().parse(newPhoneNumberCell.mxkTextField.text, defaultRegion: isoCountryCode)
                } catch {
                }
                formatNewPhoneNumber()
            }
        }

        countryPickerViewController?.withdrawViewController(animated: true, completion: nil)
    }

    // MARK: - MXKCountryPickerViewControllerDelegate

    func languagePickerViewController(_ languagePickerViewController: MXKLanguagePickerViewController?, didSelectLangugage language: String?) {
        if (language != Bundle.mxk_language()) || (language == nil && Bundle.mxk_language()) {
            Bundle.mxk_setLanguage(language)

            // Store user settings
            var sharedUserDefaults = MXKAppSettings.standard().sharedUserDefaults
            sharedUserDefaults?.set(language, forKey: "appLanguage")

            // Do a reload in order to recompute strings in the new language
            // Note that "reloadMatrixSessions:NO" will reset room summaries
            startActivityIndicator()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(0.3 * Double(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {

                AppDelegate.the().reloadMatrixSessions(false)
            })
        }
    }

    // MARK: - MXKDataSourceDelegate

    func cellViewClass(for cellData: MXKCellData?) -> AnyClass & MXKCellRendering {
        // Return the class used to display a group with a toogle button
        return GroupTableViewCellWithSwitch.self
    }

    func cellReuseIdentifier(for cellData: MXKCellData?) -> String? {
        return GroupTableViewCellWithSwitch.defaultReuseIdentifier
    }

    func dataSource(_ dataSource: MXKDataSource?, didCellChange changes: Any?) {
        // Group data has been updated. Do a simple full reload
        refreshSettings()
    }

    // MARK: - DeactivateAccountViewControllerDelegate

    func deactivateAccountViewControllerDidDeactivate(withSuccess deactivateAccountViewController: DeactivateAccountViewController?) {
        MXLogDebug("[SettingsViewController] Deactivate account with success")

        AppDelegate.the().logoutSendingRequestServer(false) { isLoggedOut in
            MXLogDebug("[SettingsViewController] Complete clear user data after account deactivation")
        }
    }

    func deactivateAccountViewControllerDidCancel(_ deactivateAccountViewController: DeactivateAccountViewController?) {
        deactivateAccountViewController?.dismiss(animated: true)
    }

    // MARK: - NotificationSettingsCoordinatorBridgePresenter

    @available(iOS 14.0, *)
    func showNotificationSettings(_ screen: NotificationSettingsScreen) {
        let notificationSettingsBridgePresenter = NotificationSettingsCoordinatorBridgePresenter(session: mainSession)
        notificationSettingsBridgePresenter.delegate = self

        MXWeakify(self)
        notificationSettingsBridgePresenter.push(from: navigationController, animated: true, screen: screen) { [self] in
            MXStrongifyAndReturnIfNil(self)
            self.notificationSettingsBridgePresenter = nil
        }

        self.notificationSettingsBridgePresenter = notificationSettingsBridgePresenter
    }

    // MARK: - NotificationSettingsCoordinatorBridgePresenterDelegate

    @available(iOS 14.0, *)
    func notificationSettingsCoordinatorBridgePresenterDelegateDidComplete(_ coordinatorBridgePresenter: NotificationSettingsCoordinatorBridgePresenter?) {
        notificationSettingsBridgePresenter?.dismissWith(animated: true, completion: nil)
        notificationSettingsBridgePresenter = nil
    }

    // MARK: - SecureBackupSetupCoordinatorBridgePresenter

    func showSecureBackupSetupFromSignOutFlow() {
        if canSetupSecureBackup() {
            setupSecureBackup2()
        } else {
            // Set up cross-signing first
            setupCrossSigning(
                withTitle: NSLocalizedString("secure_key_backup_setup_intro_title", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
                message: NSLocalizedString("security_settings_user_password_description", tableName: "Vector", bundle: Bundle.main, value: "", comment: ""),
                success: { [self] in
                    setupSecureBackup2()
                },
                failure: { error in
                })
        }
    }

    func setupSecureBackup2() {
        let secureBackupSetupCoordinatorBridgePresenter = SecureBackupSetupCoordinatorBridgePresenter(session: mainSession, allowOverwrite: true)
        secureBackupSetupCoordinatorBridgePresenter.delegate = self

        secureBackupSetupCoordinatorBridgePresenter.present(from: self, animated: true)

        self.secureBackupSetupCoordinatorBridgePresenter = secureBackupSetupCoordinatorBridgePresenter
    }

    func canSetupSecureBackup() -> Bool {
        // Accept to create a setup only if we have the 3 cross-signing keys
        // This is the path to have a sane state
        // TODO: What about missing MSK that was not gossiped before?

        let recoveryService = mainSession.crypto.recoveryService

        let crossSigningServiceSecrets = [
            MXSecretId.crossSigningMaster,
            MXSecretId.crossSigningSelfSigning,
            MXSecretId.crossSigningUserSigning
        ]

        return recoveryService?.secretsStoredLocally.mx_intersectArray(crossSigningServiceSecrets).count == crossSigningServiceSecrets.count
    }

    // MARK: - SecureBackupSetupCoordinatorBridgePresenterDelegate

    func secureBackupSetupCoordinatorBridgePresenterDelegateDidComplete(_ coordinatorBridgePresenter: SecureBackupSetupCoordinatorBridgePresenter?) {
        secureBackupSetupCoordinatorBridgePresenter?.dismissWith(animated: true, completion: nil)
        secureBackupSetupCoordinatorBridgePresenter = nil
    }

    func secureBackupSetupCoordinatorBridgePresenterDelegateDidCancel(_ coordinatorBridgePresenter: SecureBackupSetupCoordinatorBridgePresenter?) {
        secureBackupSetupCoordinatorBridgePresenter?.dismissWith(animated: true, completion: nil)
        secureBackupSetupCoordinatorBridgePresenter = nil
    }

    // MARK: - SignOutAlertPresenterDelegate

    func signOutAlertPresenterDidTapBackupAction(_ presenter: SignOutAlertPresenter) {
        showSecureBackupSetupFromSignOutFlow()
    }

    func signOutAlertPresenterDidTapSignOutAction(_ presenter: SignOutAlertPresenter) {
        // Prevent user to perform user interaction in settings when sign out
        // TODO: Prevent user interaction in all application (navigation controller and split view controller included)
        view.isUserInteractionEnabled = false
        signOutButton?.isEnabled = false

        startActivityIndicator()

        MXWeakify(self)

        AppDelegate.the().logout(withConfirmation: false) { [self] isLoggedOut in
            MXStrongifyAndReturnIfNil(self)

            stopActivityIndicator()

            view.isUserInteractionEnabled = true
            signOutButton?.isEnabled = true
        }
    }

    func setupCrossSigning(
        withTitle title: String?,
        message: String?,
        success: @escaping () -> Void,
        failure: @escaping (_ error: Error?) -> Void
    ) {
        startActivityIndicator()
        view.isUserInteractionEnabled = false

        MXWeakify(self)

        let animationCompletion: (() -> Void)? = { [self] in
            MXStrongifyAndReturnIfNil(self)

            stopActivityIndicator()
            view.isUserInteractionEnabled = true
            self.crossSigningSetupCoordinatorBridgePresenter.dismissWith(animated: true) {
            }
            self.crossSigningSetupCoordinatorBridgePresenter = nil
        }

        let crossSigningSetupCoordinatorBridgePresenter = CrossSigningSetupCoordinatorBridgePresenter(session: mainSession)

        crossSigningSetupCoordinatorBridgePresenter.present(
            with: title,
            message: message,
            from: self,
            animated: true,
            success: {
                animationCompletion?()
                success()
            },
            cancel: {
                animationCompletion?()
                failure(nil)
            },
            failure: { error in
                animationCompletion?()
                AppDelegate.the().showError(asAlert: error)
                failure(error)
            })

        self.crossSigningSetupCoordinatorBridgePresenter = crossSigningSetupCoordinatorBridgePresenter
    }

    // MARK: - SingleImagePickerPresenterDelegate

    func singleImagePickerPresenterDidCancel(_ presenter: SingleImagePickerPresenter?) {
        presenter?.dismissWith(animated: true, completion: nil)
        imagePickerPresenter = nil
    }

    func singleImagePickerPresenter(_ presenter: SingleImagePickerPresenter?, didSelectImageData imageData: Data?, with uti: MXKUTI?) {
        presenter?.dismissWith(animated: true, completion: nil)
        imagePickerPresenter = nil

        if let imageData = imageData {
            newAvatarImage = UIImage(data: imageData)
        }

        updateSections()
    }

    // MARK: - Identity Server updates

    func registerAccountDataDidChangeIdentityServerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDataDidChangeIdentityServerNotification(_:)), name: kMXSessionAccountDataDidChangeIdentityServerNotification, object: nil)
    }

    @objc func handleAccountDataDidChangeIdentityServerNotification(_ notification: Notification?) {
        refreshSettings()
    }

    // MARK: - SettingsDiscoveryTableViewSectionDelegate

    func settingsDiscoveryTableViewSectionDidUpdate(_ settingsDiscoveryTableViewSection: SettingsDiscoveryTableViewSection?) {
        updateSections()
    }

    func settingsDiscoveryTableViewSection(_ settingsDiscoveryTableViewSection: SettingsDiscoveryTableViewSection?, tableViewCellClass: AnyClass, forRow: Int) -> MXKTableViewCell? {
        var tableViewCell: MXKTableViewCell?

        if tableViewCellClass == MXKTableViewCell.self {
            tableViewCell = getDefaultTableViewCell(tableView)
        } else if tableViewCellClass == MXKTableViewCellWithTextView.self {
            let indexPath = tableViewSections?.exactIndexPath(forRowTag: forRow, sectionTag: SectionTag.discovery)
            if let indexPath = indexPath {
                tableViewCell = textViewCell(for: tableView, at: indexPath)
            }
        } else if tableViewCellClass == MXKTableViewCellWithButton.self {
            var cell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithButton.defaultReuseIdentifier()) as? MXKTableViewCellWithButton

            if cell == nil {
                cell = MXKTableViewCellWithButton()
            } else {
                // Fix https://github.com/vector-im/riot-ios/issues/1354
                cell?.mxkButton.titleLabel?.text = nil
            }

            cell?.mxkButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            cell?.mxkButton.tintColor = ThemeService.shared.theme.tintColor

            tableViewCell = cell
        } else if tableViewCellClass == MXKTableViewCellWithLabelAndSwitch.self {
            let indexPath = tableViewSections?.exactIndexPath(forRowTag: forRow, sectionTag: SectionTag.discovery)
            if let indexPath = indexPath {
                tableViewCell = getLabelAndSwitchCell(tableView, for: indexPath)
            }
        }

        return tableViewCell
    }

    // MARK: - SettingsDiscoveryViewModelCoordinatorDelegate

    func settingsDiscoveryViewModel(_ viewModel: SettingsDiscoveryViewModel?, didSelectThreePidWith medium: String?, and address: String?) {
        let discoveryThreePidDetailsPresenter = SettingsDiscoveryThreePidDetailsCoordinatorBridgePresenter(session: mainSession, medium: medium, adress: address)

        MXWeakify(self)

        discoveryThreePidDetailsPresenter.push(from: navigationController, animated: true) { [self] in
            MXStrongifyAndReturnIfNil(self)

            self.discoveryThreePidDetailsPresenter = nil
        }

        self.discoveryThreePidDetailsPresenter = discoveryThreePidDetailsPresenter
    }

    func settingsDiscoveryViewModelDidTapUserSettingsLink(_ viewModel: SettingsDiscoveryViewModel?) {
        let discoveryIndexPath = tableViewSections?.exactIndexPath(
            forRowTag: UserSettings.addEmailIndex,
            sectionTag: SectionTag.userSettings)
        if let discoveryIndexPath = discoveryIndexPath {
            tableView.scrollToRow(at: discoveryIndexPath, at: .top, animated: true)
        }
    }

    // MARK: - Identity Server

    func showIdentityServerSettingsScreen() {
        identityServerSettingsCoordinatorBridgePresenter = SettingsIdentityServerCoordinatorBridgePresenter(session: mainSession)

        identityServerSettingsCoordinatorBridgePresenter?.push(from: navigationController, animated: true, popCompletion: nil)
        identityServerSettingsCoordinatorBridgePresenter?.delegate = self
    }

    // MARK: - SettingsIdentityServerCoordinatorBridgePresenterDelegate

    func settingsIdentityServerCoordinatorBridgePresenterDelegateDidComplete(_ coordinatorBridgePresenter: SettingsIdentityServerCoordinatorBridgePresenter?) {
        identityServerSettingsCoordinatorBridgePresenter = nil
        refreshSettings()
    }

    // MARK: - TableViewSectionsDelegate

    func tableViewSectionsDidUpdate(_ sections: TableViewSections?) {
        tableView.reloadData()
    }
}