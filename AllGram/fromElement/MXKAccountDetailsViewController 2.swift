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

import MatrixSDK
import UIKit

/// 
typealias blockMXKAccountDetailsViewController_onReadyToLeave = () -> Void
let kMXKAccountDetailsLinkedEmailCellId = "kMXKAccountDetailsLinkedEmailCellId"

/// MXKAccountDetailsViewController instance may be used to display/edit the details of a matrix account.
/// Only one matrix session is handled by this view controller.
class MXKAccountDetailsViewController: MXKTableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    /// Section index
    var linkedEmailsSection = 0
    var notificationsSection = 0
    var configurationSection = 0
    /// The logout button
    var logoutButton: UIButton?
    /// Linked email
    var submittedEmail: MXK3PID?
    var emailSubmitButton: UIButton?
    var emailTextField: UITextField?
    // Notifications
    var apnsNotificationsSwitch: UISwitch?
    var inAppNotificationsSwitch: UISwitch?
    // The table cell with "Global Notification Settings" button
    var notificationSettingsButton: UIButton?

    private var alertsArray: [AnyHashable]?
    // User's profile
    private var imageLoader: MXMediaLoader?
    private var currentDisplayName: String?
    private var currentPictureURL: String?
    private var currentDownloadId: String?
    private var uploadedPictureURL: String?
    // Local changes
    private var isAvatarUpdated = false
    private var isSavingInProgress = false
    private var onReadyToLeaveHandler: blockMXKAccountDetailsViewController_onReadyToLeave?
    // account user's profile observer
    private var accountUserInfoObserver: Any?
    private var submittedEmailRowIndex = 0
    private var enablePushNotifRowIndex = 0
    private var enableInAppNotifRowIndex = 0
    private var mediaPicker: UIImagePickerController?

    /// The account displayed into the view controller.

    private var _mxAccount: MXKAccount?
    var mxAccount: MXKAccount? {
        get {
            _mxAccount
        }
        set(account) {
            // Remove observer and existing data
            reset()

            _mxAccount = account

            if let account = account {
                // Report matrix account session
                addMatrixSession(account.mxSession)

                // Set current user's information and add observers
                updateUserPicture(_mxAccount?.userAvatarUrl, force: true)
                currentDisplayName = _mxAccount?.userDisplayName
                userDisplayName.text = currentDisplayName
                updateSaveUserInfoButtonStatus()

                // Load linked emails
                loadLinkedEmails()

                // Add observer on user's information
                accountUserInfoObserver = NotificationCenter.default.addObserver(forName: kMXKAccountUserInfoDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [self] notif in
                    // Ignore any refresh when saving is in progress
                    if isSavingInProgress {
                        return
                    }

                    let accountUserId = notif?.object as? String

                    if accountUserId == _mxAccount.mxCredentials.userId {
                        // Update displayName
                        if currentDisplayName != _mxAccount.userDisplayName {
                            currentDisplayName = _mxAccount.userDisplayName
                            userDisplayName.text = _mxAccount.userDisplayName
                        }
                        // Update user's avatar
                        updateUserPicture(_mxAccount.userAvatarUrl, force: false)

                        // Update button management
                        updateSaveUserInfoButtonStatus()

                        // Display user's presence
                        let presenceColor = MXKAccount.presenceColor(_mxAccount.userPresence)
                        if let presenceColor = presenceColor {
                            userPictureButton.layer.borderWidth = 2
                            userPictureButton.layer.borderColor = presenceColor.cgColor
                        } else {
                            userPictureButton.layer.borderWidth = 0
                        }
                    }
                })
            }

            tableView.reloadData()
        }
    }
    /// The default account picture displayed when no picture is defined.

    var picturePlaceholder: UIImage? {
        return Bundle.mxk_imageFromMXKAssetsBundle(withName: "default-profile")
    }
    @IBOutlet private(set) var userPictureButton: UIButton!
    @IBOutlet private(set) var userDisplayName: UITextField!
    @IBOutlet private(set) var saveUserInfoButton: UIButton!
    @IBOutlet private(set) var profileActivityIndicatorBgView: UIView!
    @IBOutlet private(set) var profileActivityIndicator: UIActivityIndicatorView!

    // MARK: - Class methods

    /// Returns the `UINib` object initialized for a `MXKAccountDetailsViewController`.
    /// - Returns: The initialized `UINib` object or `nil` if there were errors during initialization
    /// or the nib file could not be located.
    /// - Remark: You may override this method to provide a customized nib. If you do,
    /// you should also override `accountDetailsViewController` to return your
    /// view controller loaded from your custom nib.

    // MARK: - Class methods

    class func nib() -> UINib? {
        return UINib(
            nibName: NSStringFromClass(MXKAccountDetailsViewController.self.self),
            bundle: Bundle(for: MXKAccountDetailsViewController.self))
    }

    /// Creates and returns a new `MXKAccountDetailsViewController` object.
    /// - Remark: This is the designated initializer for programmatic instantiation.
    /// - Returns: An initialized `MXKAccountDetailsViewController` object if successful, `nil` otherwise.
    convenience init() {
        self.init(
            nibName: NSStringFromClass(MXKAccountDetailsViewController.self.self),
            bundle: Bundle(for: MXKAccountDetailsViewController.self))
    }

    // MARK: -

    func finalizeInit() {
        super.finalizeInit()

        alertsArray = []

        isAvatarUpdated = false
        isSavingInProgress = false
    }

    func viewDidLoad() {
        super.viewDidLoad()

        // Check whether the view controller has been pushed via storyboard
        if userPictureButton == nil {
            // Instantiate view controller objects
            nib()?.instantiate(withOwner: self, options: nil)
        }

        userPictureButton.backgroundColor = UIColor.clear
        updateUserPictureButton(picturePlaceholder)

        userPictureButton.layer.cornerRadius = userPictureButton.frame.size.width / 2
        userPictureButton.clipsToBounds = true

        saveUserInfoButton.setTitle(Bundle.mxk_localizedString(forKey: "account_save_changes"), for: .normal)
        saveUserInfoButton.setTitle(Bundle.mxk_localizedString(forKey: "account_save_changes"), for: .highlighted)

        // Force refresh
        #warning("Swiftify: Skipping redundant initializing to itself")
        //mxAccount = mxAccount
    }

    func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.

        if imageLoader != nil {
            imageLoader?.cancel()
            imageLoader = nil
        }
    }

    deinit {
        alertsArray = nil
    }

    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(onAPNSStatusUpdate), name: kMXKAccountAPNSActivityDidChangeNotification, object: nil)
    }

    func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopProfileActivityIndicator()

        NotificationCenter.default.removeObserver(self, name: kMXKAccountAPNSActivityDidChangeNotification, object: nil)
    }

    // MARK: - override

    func onMatrixSessionChange() {
        super.onMatrixSessionChange()

        if mainSession.state != MXSessionStateRunning {
            userPictureButton.isEnabled = false
            userDisplayName.isEnabled = false
        } else if !isSavingInProgress {
            userPictureButton.isEnabled = true
            userDisplayName.isEnabled = true
        }
    }

    /// Prompt user to save potential changes before leaving the view controller.
    /// - Parameter handler: A block object called when the changes have been saved or discarded.
    /// - Returns: YES if no change is observed. NO when the user is prompted.
    func shouldLeave(_ handler: blockMXKAccountDetailsViewController_onReadyToLeave) -> Bool {
        // Check whether some local changes have not been saved
        if saveUserInfoButton.isEnabled {
            DispatchQueue.main.async(execute: { [self] in

                let alert = UIAlertController(title: nil, message: Bundle.mxk_localizedString(forKey: "message_unsaved_changes"), preferredStyle: .alert)

                alertsArray?.append(alert)
                alert.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "discard"),
                        style: .default,
                        handler: { [self] action in

                            alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }

                            // Discard changes
                            userDisplayName.text = currentDisplayName
                            updateUserPicture(mxAccount?.userAvatarUrl, force: true)

                            // Ready to leave
                            if handler != nil {
                                handler()
                            }

                        }))

                alert.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "save"),
                        style: .default,
                        handler: { [self] action in

                            alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }

                            // Start saving (Report handler to leave at the end).
                            onReadyToLeaveHandler = handler
                            saveUserInfo()

                        }))

                present(alert, animated: true)
            })

            return false
        } else if isSavingInProgress {
            // Report handler to leave at the end of saving
            onReadyToLeaveHandler = handler
            return false
        }
        return true
    }

    // MARK: - Internal methods

    func startProfileActivityIndicator() {
        if profileActivityIndicatorBgView.isHidden {
            profileActivityIndicatorBgView.isHidden = false
            profileActivityIndicator.startAnimating()
        }
        userPictureButton.isEnabled = false
        userDisplayName.isEnabled = false
        saveUserInfoButton.isEnabled = false
    }

    func stopProfileActivityIndicator() {
        if !isSavingInProgress {
            if !profileActivityIndicatorBgView.isHidden {
                profileActivityIndicatorBgView.isHidden = true
                profileActivityIndicator.stopAnimating()
            }
            userPictureButton.isEnabled = true
            userDisplayName.isEnabled = true
            updateSaveUserInfoButtonStatus()
        }
    }

    func reset() {
        dismissMediaPicker()

        // Remove observers
        NotificationCenter.default.removeObserver(self)

        // Cancel picture loader (if any)
        if imageLoader != nil {
            imageLoader?.cancel()
            imageLoader = nil
        }

        // Cancel potential alerts
        for alert in alertsArray ?? [] {
            guard let alert = alert as? UIAlertController else {
                continue
            }
            alert.dismiss(animated: false)
        }

        // Remove listener
        if accountUserInfoObserver != nil {
            if let accountUserInfoObserver = accountUserInfoObserver {
                NotificationCenter.default.removeObserver(accountUserInfoObserver)
            }
            accountUserInfoObserver = nil
        }

        currentPictureURL = nil
        currentDownloadId = nil
        uploadedPictureURL = nil
        isAvatarUpdated = false
        updateUserPictureButton(picturePlaceholder)

        currentDisplayName = nil
        userDisplayName.text = nil

        saveUserInfoButton.isEnabled = false

        submittedEmail = nil
        emailSubmitButton = nil
        emailTextField = nil

        removeMatrixSession(mainSession)

        logoutButton = nil

        onReadyToLeaveHandler = nil
    }

    func destroy() {
        if isSavingInProgress {
            weak var weakSelf = self
            onReadyToLeaveHandler = {
                let strongSelf = weakSelf
                strongSelf?.destroy()
            }
        } else {
            // Reset account to dispose all resources (Discard here potentials changes)
            mxAccount = nil

            if imageLoader != nil {
                imageLoader?.cancel()
                imageLoader = nil
            }

            // Remove listener
            if accountUserInfoObserver != nil {
                if let accountUserInfoObserver = accountUserInfoObserver {
                    NotificationCenter.default.removeObserver(accountUserInfoObserver)
                }
                accountUserInfoObserver = nil
            }

            super.destroy()
        }
    }

    func saveUserInfo() {
        startProfileActivityIndicator()
        isSavingInProgress = true

        // Check whether the display name has been changed
        let displayname = userDisplayName.text
        if ((displayname?.count ?? 0) != 0 || (currentDisplayName?.count ?? 0) != 0) && (displayname == currentDisplayName) == false {
            // Save display name
            weak var weakSelf = self

            mxAccount?.setUserDisplayName(displayname, success: { [self] in

                if let weakSelf = weakSelf {
                    // Update the current displayname
                    let self = weakSelf
                    currentDisplayName = displayname

                    // Go to the next change saving step
                    saveUserInfo()
                }

            }, failure: { [self] error in

                MXLogDebug("[MXKAccountDetailsVC] Failed to set displayName")
                if let weakSelf = weakSelf {
                    let self = weakSelf

                    // Alert user
                    var title = (error as NSError?)?.userInfo[NSLocalizedFailureReasonErrorKey] as? String
                    if title == nil {
                        title = Bundle.mxk_localizedString(forKey: "account_error_display_name_change_failed")
                    }
                    let msg = (error as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String

                    let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

                    alertsArray?.append(alert)

                    alert.addAction(
                        UIAlertAction(
                            title: Bundle.mxk_localizedString(forKey: "abort"),
                            style: .default,
                            handler: { [self] action in

                                alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }
                                // Discard changes
                                userDisplayName.text = currentDisplayName
                                updateUserPicture(mxAccount?.userAvatarUrl, force: true)
                                // Loop to end saving
                                saveUserInfo()

                            }))

                    alert.addAction(
                        UIAlertAction(
                            title: Bundle.mxk_localizedString(forKey: "retry"),
                            style: .default,
                            handler: { [self] action in

                                alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }
                                // Loop to retry saving
                                saveUserInfo()

                            }))


                    present(alert, animated: true)
                }

            })

            return
        }

        // Check whether avatar has been updated
        if isAvatarUpdated {
            if uploadedPictureURL == nil {
                // Retrieve the current picture and make sure its orientation is up
                let updatedPicture = MXKTools.forceImageOrientationUp(userPictureButton.image(for: .normal))

                MXWeakify(self)

                // Upload picture
                let uploader = MXMediaManager.prepareUploader(withMatrixSession: mainSession, initialRange: 0, andRange: 1.0)
                uploader?.uploadData(updatedPicture?.jpegData(compressionQuality: 0.5), filename: nil, mimeType: "image/jpeg", success: { [self] url in
                    MXStrongifyAndReturnIfNil(self)

                    // Store uploaded picture url and trigger picture saving
                    uploadedPictureURL = url
                    saveUserInfo()
                }, failure: { [self] error in
                    MXLogDebug("[MXKAccountDetailsVC] Failed to upload image")
                    MXStrongifyAndReturnIfNil(self)
                    handleErrorDuringPictureSaving(error)
                })
            } else {
                MXWeakify(self)

                mxAccount?.setUserAvatarUrl(
                    uploadedPictureURL,
                    success: { [self] in

                        // uploadedPictureURL becomes the user's picture
                        MXStrongifyAndReturnIfNil(self)

                        updateUserPicture(uploadedPictureURL, force: true)
                        // Loop to end saving
                        saveUserInfo()

                    },
                    failure: { [self] error in
                        MXLogDebug("[MXKAccountDetailsVC] Failed to set avatar url")
                        MXStrongifyAndReturnIfNil(self)
                        handleErrorDuringPictureSaving(error)
                    })
            }

            return
        }

        // Backup is complete
        isSavingInProgress = false
        stopProfileActivityIndicator()

        // Ready to leave
        if onReadyToLeaveHandler != nil {
            onReadyToLeaveHandler()
            onReadyToLeaveHandler = nil
        }
    }

    func handleErrorDuringPictureSaving(_ error: Error?) {
        var title = (error as NSError?)?.userInfo[NSLocalizedFailureReasonErrorKey] as? String
        if title == nil {
            title = Bundle.mxk_localizedString(forKey: "account_error_picture_change_failed")
        }
        let msg = (error as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String

        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

        alertsArray?.append(alert)
        alert.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "abort"),
                style: .default,
                handler: { [self] action in

                    alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }

                    // Remove change
                    userDisplayName.text = currentDisplayName
                    updateUserPicture(mxAccount?.userAvatarUrl, force: true)
                    // Loop to end saving
                    saveUserInfo()

                }))

        alert.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "retry"),
                style: .default,
                handler: { [self] action in

                    alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }

                    // Loop to retry saving
                    saveUserInfo()

                }))

        present(alert, animated: true)
    }

    func updateUserPicture(_ avatar_url: String?, force: Bool) {
        if force || currentPictureURL == nil || (currentPictureURL == avatar_url) == false {
            // Remove any pending observers
            NotificationCenter.default.removeObserver(self)
            // Cancel previous loader (if any)
            if imageLoader != nil {
                imageLoader?.cancel()
                imageLoader = nil
            }
            // Cancel any local change
            isAvatarUpdated = false
            uploadedPictureURL = nil

            currentPictureURL = (avatar_url == NSNull()) ? nil : avatar_url

            // Check whether this url is valid
            currentDownloadId = MXMediaManager.thumbnailDownloadId(
                forMatrixContentURI: currentPictureURL,
                inFolder: kMXMediaManagerAvatarThumbnailFolder,
                toFitViewSize: userPictureButton.frame.size,
                withMethod: MXThumbnailingMethodCrop)
            if currentDownloadId == nil {
                // Set the placeholder in case of invalid Matrix Content URI.
                updateUserPictureButton(picturePlaceholder)
            } else {
                // Check whether the image download is in progress
                let loader = MXMediaManager.existingDownloader(withIdentifier: currentDownloadId)
                if let loader = loader {
                    // Observe this loader
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(onMediaLoaderStateChange(_:)),
                        name: kMXMediaLoaderStateDidChangeNotification,
                        object: loader)
                } else {
                    let cacheFilePath = MXMediaManager.thumbnailCachePath(
                        forMatrixContentURI: currentPictureURL,
                        andType: nil,
                        inFolder: kMXMediaManagerAvatarThumbnailFolder,
                        toFitViewSize: userPictureButton.frame.size,
                        withMethod: MXThumbnailingMethodCrop)
                    // Retrieve the image from cache
                    let image = MXMediaManager.loadPicture(fromFilePath: cacheFilePath)
                    if let image = image {
                        updateUserPictureButton(image)
                    } else {
                        // Download the image, by adding download observer
                        NotificationCenter.default.addObserver(
                            self,
                            selector: #selector(onMediaLoaderStateChange(_:)),
                            name: kMXMediaLoaderStateDidChangeNotification,
                            object: nil)
                        imageLoader = mainSession.mediaManager.downloadThumbnail(
                            fromMatrixContentURI: currentPictureURL,
                            withType: nil,
                            inFolder: kMXMediaManagerAvatarThumbnailFolder,
                            toFitViewSize: userPictureButton.frame.size,
                            withMethod: MXThumbnailingMethodCrop,
                            success: nil,
                            failure: nil)
                    }
                }
            }
        }
    }

    func updateUserPictureButton(_ image: UIImage?) {
        userPictureButton.setImage(image, for: .normal)
        userPictureButton.setImage(image, for: .highlighted)
        userPictureButton.setImage(image, for: .disabled)
    }

    func updateSaveUserInfoButtonStatus() {
        // Check whether display name has been changed
        let displayname = userDisplayName.text
        let isDisplayNameUpdated = ((displayname?.count ?? 0) != 0 || (currentDisplayName?.count ?? 0) != 0) && (displayname == currentDisplayName) == false

        saveUserInfoButton.isEnabled = (isDisplayNameUpdated || isAvatarUpdated) && !isSavingInProgress
    }

    @objc func onMediaLoaderStateChange(_ notif: Notification?) {
        let loader = notif?.object as? MXMediaLoader
        if loader?.downloadId == currentDownloadId {
            // update the image
            switch loader?.state {
            case MXMediaLoaderStateDownloadCompleted:
                var image = MXMediaManager.loadPicture(fromFilePath: loader?.downloadOutputFilePath)
                if image == nil {
                    image = picturePlaceholder
                }
                updateUserPictureButton(image)
                // remove the observers
                NotificationCenter.default.removeObserver(self)
                imageLoader = nil
            case MXMediaLoaderStateDownloadFailed, MXMediaLoaderStateCancelled:
                updateUserPictureButton(picturePlaceholder)
                // remove the observers
                NotificationCenter.default.removeObserver(self)
                imageLoader = nil
                // Reset picture URL in order to try next time
                currentPictureURL = nil
            default:
                break
            }
        }
    }

    @objc func onAPNSStatusUpdate() {
        // Force table reload to update notifications section
        apnsNotificationsSwitch = nil

        tableView.reloadData()
    }

    func dismissMediaPicker() {
        if mediaPicker != nil {
            dismiss(animated: false)
            mediaPicker?.delegate = nil
            mediaPicker = nil
        }
    }

    func showValidationEmailDialog(withMessage message: String?) {
        let alert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "account_email_validation_title"), message: message, preferredStyle: .alert)

        alertsArray?.append(alert)
        alert.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "abort"),
                style: .default,
                handler: { [self] action in

                    alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }

                    emailSubmitButton?.isEnabled = true

                }))

        alert.addAction(
            UIAlertAction(
                title: Bundle.mxk_localizedString(forKey: "continue"),
                style: .default,
                handler: { [self] action in

                    alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }

                    weak var weakSelf = self

                    // We do not bind anymore emails when registering, so let's do the same here
                    submittedEmail?.add3PID(toUser: false, success: { [self] in

                        if let weakSelf = weakSelf {
                            let self = weakSelf

                            // Release pending email and refresh table to remove related cell
                            emailTextField?.text = nil
                            submittedEmail = nil

                            // Update linked emails
                            loadLinkedEmails()
                        }

                    }, failure: { [self] error in

                        if let weakSelf = weakSelf {
                            let self = weakSelf

                            MXLogDebug("[MXKAccountDetailsVC] Failed to bind email")

                            // Display the same popup again if the error is M_THREEPID_AUTH_FAILED
                            let mxError = MXError(nsError: error)
                            if mxError != nil && (mxError.errcode == kMXErrCodeStringThreePIDAuthFailed) {
                                showValidationEmailDialog(withMessage: Bundle.mxk_localizedString(forKey: "account_email_validation_error"))
                            } else {
                                // Notify MatrixKit user
                                let myUserId = mxAccount?.mxCredentials.userId
                                NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != nil ? [
                                    kMXKErrorUserIdKey: myUserId ?? ""
                                ] : nil)
                            }

                            // Release the pending email (even if it is Authenticated)
                            tableView.reloadData()
                        }

                    })

                }))

        present(alert, animated: true)
    }

    func loadLinkedEmails() {
        // Refresh the account 3PIDs list
        mxAccount?.load3PIDs({ [self] in

            tableView.reloadData()

        }, failure: { [self] error in
            // Display the data that has been loaded last time
            tableView.reloadData()
        })
    }

    /// Action registered on the following events:
    /// - 'UIControlEventTouchUpInside' for each UIButton instance.
    /// - 'UIControlEventValueChanged' for each UISwitch instance.

    // MARK: - Actions

    @IBAction func onButtonPressed(_ sender: Any) {
        dismissKeyboard()

        if (sender as? UIButton) == saveUserInfoButton {
            saveUserInfo()
        } else if (sender as? UIButton) == userPictureButton {
            // Open picture gallery
            mediaPicker = UIImagePickerController()
            mediaPicker?.delegate = self
            mediaPicker?.sourceType = .photoLibrary
            mediaPicker?.allowsEditing = false
            if let mediaPicker = mediaPicker {
                present(mediaPicker, animated: true)
            }
        } else if (sender as? UIButton) == logoutButton {
            MXKAccountManager.shared().remove(mxAccount, completion: nil)
            mxAccount = nil
        } else if (sender as? UIButton) == emailSubmitButton {
            // Email check
            if !MXTools.isEmailAddress(emailTextField?.text) {
                let alert = UIAlertController(title: Bundle.mxk_localizedString(forKey: "account_error_email_wrong_title"), message: Bundle.mxk_localizedString(forKey: "account_error_email_wrong_description"), preferredStyle: .alert)

                alertsArray?.append(alert)
                alert.addAction(
                    UIAlertAction(
                        title: Bundle.mxk_localizedString(forKey: "ok"),
                        style: .default,
                        handler: { [self] action in

                            alertsArray?.removeAll { $0 as AnyObject === alert as AnyObject }

                        }))

                present(alert, animated: true)

                return
            }

            if submittedEmail == nil || (submittedEmail?.address != emailTextField?.text) {
                submittedEmail = MXK3PID.init(medium: kMX3PIDMediumEmail, andAddress: emailTextField?.text)
            }

            emailSubmitButton?.isEnabled = false
            weak var weakSelf = self

            submittedEmail?.requestValidationToken(withMatrixRestClient: mainSession.matrixRestClient, isDuringRegistration: false, nextLink: nil, success: { [self] in

                if let weakSelf = weakSelf {
                    let self = weakSelf
                    showValidationEmailDialog(withMessage: Bundle.mxk_localizedString(forKey: "account_email_validation_message"))
                }

            }, failure: { [self] error in

                MXLogDebug("[MXKAccountDetailsVC] Failed to request email token")
                if let weakSelf = weakSelf {
                    let self = weakSelf
                    // Notify MatrixKit user
                    let myUserId = mxAccount?.mxCredentials.userId
                    NotificationCenter.default.post(name: kMXKErrorNotification, object: error, userInfo: myUserId != nil ? [
                        kMXKErrorUserIdKey: myUserId ?? ""
                    ] : nil)

                    emailSubmitButton?.isEnabled = true
                }

            })
        } else if (sender as? UISwitch) == apnsNotificationsSwitch {
            mxAccount?.enablePushNotifications(apnsNotificationsSwitch?.isOn, success: nil, failure: nil)
            apnsNotificationsSwitch?.isEnabled = false
        } else if (sender as? UISwitch) == inAppNotificationsSwitch {
            mxAccount?.enableInAppNotifications = inAppNotificationsSwitch?.isOn
            tableView.reloadData()
        }
    }

    // MARK: - keyboard

    func dismissKeyboard() {
        if userDisplayName.isFirstResponder {
            // Hide the keyboard
            userDisplayName.resignFirstResponder()
            updateSaveUserInfoButtonStatus()
        } else if emailTextField?.isFirstResponder ?? false {
            emailTextField?.resignFirstResponder()
        }
    }

    // MARK: - UITextField delegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // "Done" key has been pressed
        dismissKeyboard()
        return true
    }

    /// Action registered to handle text field edition
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        if (sender as? UITextField) == userDisplayName {
            updateSaveUserInfoButtonStatus()
        }
    }

    // MARK: - UITableView data source

    func numberOfSections(in tableView: UITableView) -> Int {
        let count = 0

        configurationSection = -1
        notificationsSection = configurationSection
        linkedEmailsSection = notificationsSection

        if !mxAccount?.disabled {
            linkedEmailsSection = count
            count += 1
            notificationsSection = count
            count += 1
        }

        configurationSection = count
        count += 1

        return count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = 0
        if section == linkedEmailsSection {
            count = mxAccount?.linkedEmails.count ?? 0
            submittedEmailRowIndex = count
            count += 1
        } else if section == notificationsSection {
            enablePushNotifRowIndex = -1
            enableInAppNotifRowIndex = enablePushNotifRowIndex

            if MXKAccountManager.shared().isAPNSAvailable {
                enablePushNotifRowIndex = count
                count += 1
            }
            enableInAppNotifRowIndex = count
            count += 1
        } else if section == configurationSection {
            count = 2
        }

        return count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == configurationSection {
            if indexPath.row == 0 {
                let textView = UITextView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: MAXFLOAT))
                textView.font = UIFont.systemFont(ofSize: 14)

                let configFormat = "\(Bundle.mxk_localizedString(forKey: "settings_config_home_server"))\n\(Bundle.mxk_localizedString(forKey: "settings_config_identity_server"))\n\(Bundle.mxk_localizedString(forKey: "settings_config_user_id"))"

                if let homeServer = mxAccount?.mxCredentials.homeServer, let identityServerURL = mxAccount?.identityServerURL, let userId = mxAccount?.mxCredentials.userId {
                    textView.text = String(format: configFormat, homeServer, identityServerURL, userId)
                }

                let contentSize = textView.sizeThatFits(textView.frame.size)
                return contentSize.height + 1
            }
        }

        return 44
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell? = nil

        if indexPath.section == linkedEmailsSection {
            if indexPath.row < (mxAccount?.linkedEmails.count ?? 0) {
                cell = tableView.dequeueReusableCell(withIdentifier: kMXKAccountDetailsLinkedEmailCellId)
                if cell == nil {
                    cell = UITableViewCell(style: .default, reuseIdentifier: kMXKAccountDetailsLinkedEmailCellId)
                }

                cell?.selectionStyle = .none
                cell?.textLabel?.text = mxAccount?.linkedEmails[indexPath.row] as? String
            } else if indexPath.row == submittedEmailRowIndex {
                // Report the current email value (if any)
                var currentEmail: String? = nil
                if let emailTextField = emailTextField {
                    currentEmail = emailTextField.text
                }

                var submittedEmailCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithTextFieldAndButton.defaultReuseIdentifier()) as? MXKTableViewCellWithTextFieldAndButton
                if submittedEmailCell == nil {
                    submittedEmailCell = MXKTableViewCellWithTextFieldAndButton()
                }

                submittedEmailCell?.mxkTextField.text = currentEmail
                submittedEmailCell?.mxkTextField.keyboardType = .emailAddress
                submittedEmailCell?.mxkButton.enabled = ((currentEmail?.count ?? 0) != 0)
                submittedEmailCell?.mxkButton.setTitle(Bundle.mxk_localizedString(forKey: "account_link_email"), for: .normal)
                submittedEmailCell?.mxkButton.setTitle(Bundle.mxk_localizedString(forKey: "account_link_email"), for: .highlighted)
                submittedEmailCell?.mxkButton.addTarget(self, action: #selector(MXKAuthenticationViewController.onButtonPressed(_:)), for: .touchUpInside)

                emailSubmitButton = submittedEmailCell?.mxkButton
                emailTextField = submittedEmailCell?.mxkTextField

                cell = submittedEmailCell
            }
        } else if indexPath.section == notificationsSection {
            var notificationsCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithLabelAndSwitch.defaultReuseIdentifier()) as? MXKTableViewCellWithLabelAndSwitch
            if notificationsCell == nil {
                notificationsCell = MXKTableViewCellWithLabelAndSwitch()
            } else {
                // Force layout before reusing a cell (fix switch displayed outside the screen)
                notificationsCell?.layoutIfNeeded()
            }

            notificationsCell?.mxkSwitch.addTarget(self, action: #selector(MXKAuthenticationViewController.onButtonPressed(_:)), for: .valueChanged)

            if indexPath.row == enableInAppNotifRowIndex {
                notificationsCell?.mxkLabel.text = Bundle.mxk_localizedString(forKey: "settings_enable_inapp_notifications")
                notificationsCell?.mxkSwitch.on = mxAccount?.enableInAppNotifications
                inAppNotificationsSwitch = notificationsCell?.mxkSwitch
            } else {
                notificationsCell?.mxkLabel.text = Bundle.mxk_localizedString(forKey: "settings_enable_push_notifications")
                notificationsCell?.mxkSwitch.on = mxAccount?.pushNotificationServiceIsActive
                notificationsCell?.mxkSwitch.enabled = true
                apnsNotificationsSwitch = notificationsCell?.mxkSwitch
            }

            cell = notificationsCell
        } else if indexPath.section == configurationSection {
            if indexPath.row == 0 {
                var configCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithTextView.defaultReuseIdentifier()) as? MXKTableViewCellWithTextView
                if configCell == nil {
                    configCell = MXKTableViewCellWithTextView()
                }

                let configFormat = "\(Bundle.mxk_localizedString(forKey: "settings_config_home_server"))\n\(Bundle.mxk_localizedString(forKey: "settings_config_identity_server"))\n\(Bundle.mxk_localizedString(forKey: "settings_config_user_id"))"

                if let homeServer = mxAccount?.mxCredentials.homeServer, let identityServerURL = mxAccount?.identityServerURL, let userId = mxAccount?.mxCredentials.userId {
                    configCell?.mxkTextView.text = String(format: configFormat, homeServer, identityServerURL, userId)
                }

                cell = configCell
            } else {
                var logoutBtnCell = tableView.dequeueReusableCell(withIdentifier: MXKTableViewCellWithButton.defaultReuseIdentifier()) as? MXKTableViewCellWithButton
                if logoutBtnCell == nil {
                    logoutBtnCell = MXKTableViewCellWithButton()
                }
                logoutBtnCell?.mxkButton.setTitle(Bundle.mxk_localizedString(forKey: "action_logout"), for: .normal)
                logoutBtnCell?.mxkButton.setTitle(Bundle.mxk_localizedString(forKey: "action_logout"), for: .highlighted)
                logoutBtnCell?.mxkButton.addTarget(self, action: #selector(MXKAuthenticationViewController.onButtonPressed(_:)), for: .touchUpInside)

                logoutButton = logoutBtnCell?.mxkButton

                cell = logoutBtnCell
            }
        } else {
            // Return a fake cell to prevent app from crashing.
            cell = UITableViewCell()
        }

        return cell!
    }

    // MARK: - UITableView delegate

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionHeader = UIView(frame: tableView.rectForHeader(inSection: section))
        sectionHeader.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        let sectionLabel = UILabel(frame: CGRect(x: 5, y: 5, width: sectionHeader.frame.size.width - 10, height: sectionHeader.frame.size.height - 10))
        sectionLabel.font = UIFont.boldSystemFont(ofSize: 16)
        sectionLabel.backgroundColor = UIColor.clear
        sectionHeader.addSubview(sectionLabel)

        if section == linkedEmailsSection {
            sectionLabel.text = Bundle.mxk_localizedString(forKey: "account_linked_emails")
        } else if section == notificationsSection {
            sectionLabel.text = Bundle.mxk_localizedString(forKey: "settings_title_notifications")
        } else if section == configurationSection {
            sectionLabel.text = Bundle.mxk_localizedString(forKey: "settings_title_config")
        }

        return sectionHeader
    }

    func tableView(_ aTableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == aTableView {
            aTableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let selectedImage = info[.originalImage] as? UIImage
        if let selectedImage = selectedImage {
            updateUserPictureButton(selectedImage)
            isAvatarUpdated = true
            saveUserInfoButton.isEnabled = true
        }
        dismissMediaPicker()
    }
}