//
//  OnboardingView.swift
//  AllGram
//
//  Created by Eugene Ned on 28.07.2022.
//

import SwiftUI
import AVKit
import AVFAudio
import Contacts

struct OnboardingView: View {
    
    @Binding var showIntro: Bool
    
    @State private var shownTab: ConstIntro.TabViewTags = .start
    @State private var showVideo = false
    @State private var signedAgreement = false
    
    var body: some View {
        ZStack {
            TabView(selection: $shownTab) {
//                VStack {
//                    OnboardingAgreementTabView()
//
//                    buildButtonsForAgreement(actionOnDecline: {
//                            withAnimation { self.showAgreementAlert = true }
//                    }, actionOnAgree: {
//                        signedAgreement = true
//                        withAnimation { self.shownTab = .start }
//                    })
//                }
//                .tag(ConstIntro.TabViewTags.agreement)
//                .gesture(signedAgreement ? nil : DragGesture())
//                .alert(isPresented: $showAgreementAlert) {
//                    agreementAlertView
//                }
                
                VStack {
                    OnboardingStartTabView(pageTitle: ConstIntro.Title.start.rawValue,
                                           pageDescription: ConstIntro.Description.start.rawValue,
                                           showVideo: $showVideo)
                    
                    buildButtonForIntro(buttonName: ConstIntro.ButtonType.start.rawValue,
                                        isAllowed: false,
                                        buttonAction: {
                        withAnimation { self.shownTab = .mic }
                    })
                }.tag(ConstIntro.TabViewTags.start)
                
                VStack{
                    OnboardingAccessTabView(imageName: ConstIntro.AccessTabImage.mic.rawValue,
                                            pageTitle: ConstIntro.Title.mic.rawValue,
                                            pageCaption: ConstIntro.Caption.mic.rawValue,
                                            pageDescription: ConstIntro.Description.mic.rawValue)
                    Spacer()
                    buildButtonForIntro(buttonName: ConstIntro.ButtonType.access.rawValue,
                                        isAllowed: micAccessGranted,
                                        buttonAction: {
                        if !micAccessGranted {
                            requestMediaTypeAccess(.audio, requestAccess: true, nextTab: .camera)
                        } else {
                            withAnimation { self.shownTab = .camera }
                        }
                        
                    })
                }.tag(ConstIntro.TabViewTags.mic)
                
                VStack{
                    OnboardingAccessTabView(imageName: ConstIntro.AccessTabImage.camera.rawValue,
                                            pageTitle: ConstIntro.Title.camera.rawValue,
                                            pageCaption: ConstIntro.Caption.camera.rawValue,
                                            pageDescription: ConstIntro.Description.camera.rawValue)
                    Spacer()
                    buildButtonForIntro(buttonName: ConstIntro.ButtonType.access.rawValue,
                                        isAllowed: cameraAccessGranted,
                                        buttonAction: {
                        if !cameraAccessGranted {
                            requestMediaTypeAccess(.video, requestAccess: true, nextTab: .finish)
                        } else {
                            withAnimation { self.shownTab = .finish }
                        }
                        
                        
                    })
                }.tag(ConstIntro.TabViewTags.camera)
                
//                VStack{
//                    OnboardingAccessTabView(imageName: ConstIntro.AccessTabImage.contacts.rawValue,
//                                            pageTitle: ConstIntro.Title.contacts.rawValue,
//                                            pageCaption: ConstIntro.Caption.contacts.rawValue,
//                                            pageDescription: ConstIntro.Description.contacts.rawValue)
//                    Spacer()
//                    buildButtonForIntro(buttonName: ConstIntro.ButtonType.access.rawValue,
//                                        isAllowed: contactsAccessGranted,
//                                        buttonAction: {
//                        if !contactsAccessGranted {
//                            requestContactAccess(nextTab: .finish)
//                        } else {
//                            withAnimation { self.shownTab = .finish }
//                        }
//
//                    })
//                }.tag(ConstIntro.TabViewTags.contacts)
                
                VStack{
                    OnboardingFinishTabView(pageTitle: ConstIntro.Title.finish.rawValue,
                                            pageCaption: ConstIntro.Caption.finish.rawValue)
                    
                    buildButtonForIntro(buttonName: ConstIntro.ButtonType.finish.rawValue,
                                        isAllowed: false,
                                        buttonAction: {
//                        if micAccessGranted && cameraAccessGranted && contactsAccessGranted {
                            withAnimation { showIntro = false }
//                        } else {
//                            alertText = "missing permissions"
//                            showingAlert = true
//                        }
                    })
                }.tag(ConstIntro.TabViewTags.finish)
            }
            .background(
                Image("backgroundLogo")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            )
            .padding(.bottom, 4)
            .ignoresSafeArea()
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            if showVideo {
                Rectangle()
                    .foregroundColor(.reverseColor.opacity(0.7))
                    .onTapGesture {
                        withAnimation { $showVideo.wrappedValue = false }
                    }
                    .opacity($showVideo.wrappedValue ? 1 : 0)
                    .overlay (
                        YouTubeVideoViewer(videoID: "sC2YXAoncP0")
                            .frame(height: UIScreen.main.bounds.height / 4)
                    )
                    .ignoresSafeArea()
            }
        }
        .alert(isPresented: $showingAlert) {
            errorAlertView
        }
        //        .edgesIgnoringSafeArea(.top)
    }
    
    // MARK: - Functions for requesting permission to audio, camera, contacts
    
    @State private var micAccessGranted = false
    @State private var cameraAccessGranted = false
    @State private var contactsAccessGranted = false
    
    private func requestMediaTypeAccess(_ mediaType: AVMediaType, requestAccess: Bool, nextTab: ConstIntro.TabViewTags) -> Void {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .notDetermined: // User has not yet been asked for camera access
            guard requestAccess else { return }
            AVCaptureDevice.requestAccess(for: mediaType) { response in
                if response {
                    if mediaType == .audio {
                        micAccessGranted = true
                    } else if mediaType == .video {
                        cameraAccessGranted = true
                    }
                    withAnimation { shownTab = nextTab }
                }
            }
        case .authorized:
            if mediaType == .audio {
                micAccessGranted = true
            } else if mediaType == .video {
                cameraAccessGranted = true
            }
            withAnimation { shownTab = nextTab }
        default:
            if mediaType == .audio {
                alertText = "microphone"
            } else if mediaType == .video {
                alertText = "camera"
            }
            showingAlert = true
        }
    }
    
    private func requestContactAccess(nextTab: ConstIntro.TabViewTags) {
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)
        let store = CNContactStore()
        
        switch authStatus {
        case .notDetermined:
            store.requestAccess(for: .contacts) { success, error  in
                if success {
                    print("Success!")
                    withAnimation { shownTab = nextTab }
                    contactsAccessGranted = true
                }
            }
        case .authorized:
            contactsAccessGranted = true
            withAnimation { shownTab = nextTab }
        default:
            alertText = "contacts"
            showingAlert = true
        }
    }
    
    // MARK: - Button
    
    private func buildButtonForIntro(buttonName: String, isAllowed: Bool, buttonAction: @escaping () -> Void ) -> some View {
        Button(action: buttonAction) {
            if !isAllowed {
                Text(buttonName)
                    .font(.headline)
                    .bold()
                    .kerning(0.1)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(Color("mainColor"))
            } else {
                withAnimation {
                    Image("check-solid")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.green)
                        .frame(width: 48, height: 48)
                }
            }
        }
        .cornerRadius(16)
        .padding(.bottom)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Button for agreement
    
    private func buildButtonsForAgreement(actionOnDecline: @escaping () -> Void, actionOnAgree: @escaping () -> Void) -> some View {
        HStack {
            Button(action: actionOnDecline) {
                Text("I Decline")
                    .font(.headline)
                    .bold()
                    .kerning(0.1)
                    .frame(width: 164, height: 48)
                    .foregroundColor(.white)
                    .background(Color.gray)
            }
            .cornerRadius(16)
            
            Button(action: actionOnAgree) {
                Text("I Agree")
                    .font(.headline)
                    .bold()
                    .kerning(0.1)
                    .frame(width: 164, height: 48)
                    .foregroundColor(.white)
                    .background(Color("mainColor"))
            }
            .cornerRadius(16)
        }
        .padding(.bottom)
    }
    
    // MARK: - Alert
    
    @State private var showingAlert = false
    @State private var alertText = ""
    
    private var errorAlertView: Alert {
        return Alert(
            title: Text("Access to \(alertText)"),
            message: Text("Tap Settings and enable \(alertText)"),
            primaryButton: .default(
                Text("Settings"),
                action: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            ),
            secondaryButton: .cancel()
        )
    }
    
    // MARK: - Agreement alert
    @State private var showAgreementAlert = false
    
    private var agreementAlertView: Alert {
        return Alert(
            title: Text("User agreement"),
            message: Text("Please note that in order to start using our products you need to agree with the user agreement."),
            dismissButton: .default(Text("OK"))
        )
    }
    
    // MARK: - Constants
    
    private struct ConstIntro {
        enum TabViewTags {
            case agreement, start, mic, camera, contacts, finish
        }
        
        enum ButtonType: String {
            case start =    "Start onboarding"
            case access =   "Allow access"
            case finish =   "Go to app"
        }
        
        enum Title: String {
            case start =    "Hi there!"
            case mic =      "Microphone"
            case camera =   "Camera"
            case contacts = "Contacts"
            case finish =   "Congratulations"
        }
        
        enum Caption: String {
            case mic =      "Allgram requires access to your microphone"
            case camera =   "Allgram requires access to your camera"
            case contacts = "Allgram requires access to your contacts"
            case finish =   "You have successfully configured the application"
        }
        
        enum Description: String {
            case start =    "We will now introduce you to the basic features of allgram"
            case mic =      "You will be able to make calls and record voice messages"
            case camera =   "You will be able to add photos to your club posts, chat messages and make video calls"
            case contacts = "You will be able to reach people from your contacts list"
        }
        
        enum AccessTabImage: String {
            case mic =      "onboardingMicrophone"
            case camera =   "onboardingCamera"
            case contacts = "onboardingContacts"
        }
    }
}

struct IntroView2_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView(showIntro: .constant(true))
            OnboardingView(showIntro: .constant(true))
                .preferredColorScheme(.dark)
        }
    }
}



