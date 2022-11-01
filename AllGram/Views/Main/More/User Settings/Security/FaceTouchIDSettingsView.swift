//
//  FaceTouchIDSettings.swift
//  AllGram
//
//  Created by Eugene Ned on 01.08.2022.
//

import SwiftUI
import LocalAuthentication

extension UserDefaults {
    
    var securityFaceIDEnabled: Bool {
        set { UserDefaults.standard.setValue(newValue, forKey: "securityFaceIDEnabled") }
        get { UserDefaults.standard.bool(forKey: "securityFaceIDEnabled") }
    }
    
    var securityTouchIDEnabled: Bool {
        set { UserDefaults.standard.setValue(newValue, forKey: "securityTouchIDEnabled") }
        get { UserDefaults.standard.bool(forKey: "securityTouchIDEnabled") }
    }
}

class SecurityManager {
    
    enum BiometricType: String {
        case faceID
        case touchID
        case none // Passcode only?
        case unavailable
    }
    
    static let shared = SecurityManager()
    
    private(set) var biometricType: BiometricType = .unavailable
    
    var shouldLock: Bool {
        if UserDefaults.standard.securityFaceIDEnabled && biometricType == .faceID { return true }
        if UserDefaults.standard.securityTouchIDEnabled && biometricType == .touchID { return true }
        return false
    }
    
    private init() { }
    
    typealias AskPermissionHandler = (Bool, Error?) -> Void
    
    func askForPermission(completion: @escaping AskPermissionHandler) {
        checkPermissions()
        // Request authentication (will start with biometric and fall back to passcode)
        let context = LAContext()
        let reason = "We want to protect your session."
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) {
            success, authenticationError in
            // Authentication completed
            completion(success, authenticationError)
        }
    }
    
    func checkPermissions() {
        let context = LAContext()
        var error: NSError?
        // Check whether biometric authentication is possible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Some biometrics
            switch context.biometryType {
            case .faceID: biometricType = .faceID
            case .touchID: biometricType = .touchID
            case .none: biometricType = .none
            @unknown default: break
            }
        } else {
            // No biometrics (no permission)
            biometricType = .unavailable
        }
    }
    
}

struct FaceTouchIDSettingsView: View {
    
    @State private var faceOn = UserDefaults.standard.securityFaceIDEnabled
    @State private var fingerOn = UserDefaults.standard.securityTouchIDEnabled
    
    var body: some View {
        Form {
            Section {
                if hasFaceID {
                    HStack {
                        Image(systemName: "faceid")
                            .resizable().scaledToFit()
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .foregroundColor(.accentColor)
                            .padding(.trailing, Constants.iconSpacing)
                        Toggle("Face ID", isOn: $faceOn)
                            .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                            .padding(.vertical, Constants.togglePadding)
                    }
                }
                if hasTouchID {
                    HStack {
                        Image(systemName: "touchid")
                            .resizable().scaledToFit()
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .foregroundColor(.accentColor)
                            .padding(.trailing, Constants.iconSpacing)
                        Toggle("Touch ID", isOn: $fingerOn)
                            .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                            .padding(.vertical, Constants.togglePadding)
                    }
                }
                if hasNothing {
                    Text("This device does not support Face ID or Touch ID")
                        .padding(.vertical, Constants.togglePadding)
                }
                if hasBlockedPermission {
                    Button(action: { openSettings() }, label: {
                        HStack {
                            Image(systemName: "gear")
                                .resizable().scaledToFit()
                                .frame(width: Constants.iconSize, height: Constants.iconSize)
                                .foregroundColor(.accentColor)
                                .padding(.trailing, Constants.iconSpacing)
                            Text("Open Settings")
                                .padding(.vertical, Constants.buttonPadding)
                        }
                    })
                    Text("Please, grant allgram permission to use Face ID or Touch ID in the settings")
                        .padding(.vertical, Constants.togglePadding)
                }
            }
            .padding(.horizontal, Constants.togglePadding)
            .onChange(of: faceOn) { on in
                if on {
                    SecurityManager.shared.askForPermission { success, error in
                        UserDefaults.standard.securityFaceIDEnabled = success
                        faceOn = success
                    }
                } else {
                    UserDefaults.standard.securityFaceIDEnabled = false
                }
            }
            .onChange(of: fingerOn) { on in
                if on {
                    SecurityManager.shared.askForPermission { success, error in
                        UserDefaults.standard.securityTouchIDEnabled = success
                        fingerOn = success
                    }
                } else {
                    UserDefaults.standard.securityTouchIDEnabled = false
                }
            }
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitle("Fingerprint/FaceID protection")
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    private var hasFaceID: Bool {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        } else {
            return SecurityManager.shared.biometricType == .faceID
        }
    }
    
    private var hasTouchID: Bool {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        } else {
            return SecurityManager.shared.biometricType == .touchID
        }
    }
    
    private var hasNothing: Bool {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        } else {
            return SecurityManager.shared.biometricType == .none
        }
    }
    
    private var hasBlockedPermission: Bool {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        } else {
            return SecurityManager.shared.biometricType == .unavailable
        }
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let iconSpacing: CGFloat = 8
        static let togglePadding: CGFloat = 8
        static let buttonPadding: CGFloat = 10
    }
}

struct FaceTouchIDSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FaceTouchIDSettingsView()
    }
}
