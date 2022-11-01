//
//  ContentView.swift
//  AllGram
//
//  Created by Admin on 11.08.2021.
//

import SwiftUI
import PartialSheet
import AVFoundation

struct ContentView: View {
    @StateObject var authViewModel = AuthViewModel.shared
    @StateObject var localeViewModel = LocaleViewModel()
    
    @State private var isLocked = SecurityManager.shared.shouldLock
    
    @AppStorage("ShowIntro") private var showIntro = true
    
    init() {
        // Try to allow sound when device is in silent mode
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        // Keep the app active even if user stops interaction
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    var body: some View {
        VStack {
            switch authViewModel.loginState {
            case .loggedIn(let vm):
                ZStack {
                    if showIntro {
                        OnboardingView(showIntro: $showIntro)
                    } else {
                        MainTabView(vm)
                            .disabled(isLocked)
                            .blur(radius: isLocked ? 30 : 0)
                            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                                if SecurityManager.shared.shouldLock {
                                    isLocked = true
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                                if isLocked {
                                    handleUnlocking()
                                }
                            }
                            .onAppear() {
                                SecurityManager.shared.checkPermissions()
                                isLocked = SecurityManager.shared.shouldLock
                                if isLocked {
                                    handleUnlocking()
                                }
                            }
                        if isLocked {
                            Button(action: { handleUnlocking() }, label: {
                                Text("Your session is protected.")
                            })
                        }
                    }
                }
                .onAppear() {
                    SecurityManager.shared.checkPermissions()
                }
            case .loggedOut:
                BrandNewLoginView()
                    .preferredColorScheme(.light)
            case .authenticating(let inRegistration):
                LoaderView(cancellable: true, info: inRegistration ? "Registering..." : "Authenticating...", cancelAction: { authViewModel.logout() })
            case .failure(let error):
                VStack{
                    Spacer()
                    Text(verbatim: error.localizedDescription)
                    Spacer()
                    Button(action: {self.authViewModel.loginState = .loggedOut}, label: {
                        Text("Login again, please")
                    })
                        .padding()
                }
            }
        }
        .addPartialSheet()
        .environmentObject(localeViewModel)
        .environment(\.locale, localeViewModel.locale)
        .onOpenURL { url in
            if let token = authViewModel.getRedirectLoginToken(from: url) {
                if case .loggedIn = authViewModel.loginState {
                    // What to do if we already logged in?
                } else {
                    authViewModel.loginUser(redirectToken: token)
                }
            }
        }
    }
    
    private func handleUnlocking() {
        SecurityManager.shared.askForPermission { success, error in
            if success {
                isLocked = false
            } else {
                // Failed, canceled or fallback to other option (password)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .colorScheme(.dark)
            .previewDevice("iPhone 11")
        ContentView()
            .colorScheme(.light)
            .previewDevice("iPhone 8 Plus")
    }
}
