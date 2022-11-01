//
//  ChatContainerView.swift
//  AllGram
//
//  Created by Alex Pirog on 04.05.2022.
//

import SwiftUI
import MatrixSDK
import WebKit

extension String {
    static func randomAlphanumeric(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

struct CallConfig: Identifiable {
    enum CallType: String {
        case audio, video
    }
    
    let id: String
    let type: CallType
    let user: String
    let participants: [String]
    
    /// For parameters validation use static `safeCall` method
    init(roomId: String, type: CallType, user: String, participants: [String]) {
        self.id = roomId
        self.type = type
        self.user = user
        self.participants = participants
    }
    
    static func safeCall(_ type: CallType, userId: String, participantsIds: [String]) -> CallConfig? {
        let safeUser = userId.dropAllgramSuffix.dropPrefix("@")
        let safeParticipants = participantsIds
            .map { $0.dropAllgramSuffix.dropPrefix("@") }
            .filter { $0.hasContent }
        guard safeUser.hasContent && !safeParticipants.isEmpty else { return nil }
        return CallConfig(roomId: String.randomAlphanumeric(length: 6), type: type, user: safeUser, participants: safeParticipants)
    }
}
 
struct CallWebView: UIViewRepresentable {
    /*
     https://meet.allgram.com/
     ?room=1q2w3e
     &mesh=true
     &type=audio
     &nickname=nick01
     &participants={
        p:[nick01,abarhatov,banana]
     }
     */
    
    let config: CallConfig
    
    init(_ config: CallConfig) {
        self.config = config
    }
    
    private var request: URLRequest {
        var components = URLComponents(string: "https://meet.allgram.com/")!
        let pString = "{p:[\(config.participants.joined(separator: ","))]}"
        components.queryItems = [
            URLQueryItem(name: "room", value: config.id),
            URLQueryItem(name: "mesh", value: true.description),
            URLQueryItem(name: "type", value: config.type.rawValue),
            URLQueryItem(name: "nickname", value: config.user),
            URLQueryItem(name: "participants", value: pString)
        ]
        let request = URLRequest(url: components.url!)
        // print("[C] resulting url: \(request.url!.absoluteString)")
        return request
    }
 
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // Block scrolling
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
//        webView.requiresUserActionForMediaPlayback = false
//        webView.allowsInlineMediaPlayback = true
        
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        return webView
    }
 
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(request)
    }
}


/// Chat container handling navigation
struct ChatContainerView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var callHandler = CallHandler.shared
    @ObservedObject var room: AllgramRoom
    
    @ObservedObject var membersVM: RoomMembersViewModel
    
    let inviteUserViewModel: InviteUserViewModel
    let inviteVM: ClubInviteViewModel
    
    @State var selectedEvent: MXEvent?
    
    var onBack: (() -> Void)?
    
    init(room: AllgramRoom, onBack: (() -> Void)? = nil) {
        self.room = room
        self.membersVM = RoomMembersViewModel(room: room)
        self.inviteUserViewModel = InviteUserViewModel(room: room)
        self.inviteVM = ClubInviteViewModel(room: room)
        self.onBack = onBack
    }
    
    @State var showSettings = false
    @State var showContentSearch = false
    @State var showInviteParticipant = false
    @State var showInvite = false
    
    @State private var callConfig: CallConfig?
    
    var body: some View {
        ZStack {
            // Navigation
            VStack {
                NavigationLink(
                    destination: RoomSettingsView(room: room),
                    isActive: $showSettings
                ) {
                    EmptyView()
                }
                NavigationLink(
                    destination:
                        ContentSearchView(room: room, selectedEvent: $selectedEvent)
                        .environmentObject(membersVM)
                    , isActive: $showContentSearch
                ) {
                    EmptyView()
                }
                NavigationLink(
                    destination: NewInviteView(viewModel: inviteUserViewModel, headerOfView: "Invite someone to the Chat"),
                    isActive: $showInviteParticipant
                ) {
                    EmptyView()
                }
            }
            // Actual chat
            ChatView(room: room, scrollToEvent: $selectedEvent, onBack: onBack)
                .equatable()
                .onAppear {
                    showInvite = !room.session.isJoined(onRoom: room.room.roomId)
                    room.markAllAsRead()
                    callHandler.determineCallCapability(for: room)
                }
                .environmentObject(room)
                .environmentObject(membersVM)
            // Return to call overlay
            if let id = callHandler.roomId(viewKind: .call) {
                VStack {
                    Button(action: { callHandler.isShownCallView = true }) {
                        HStack {
                            Image("phone-solid")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .frame(width: 24, height: 24)
                            Text(id == room.roomId ? "This call" : "Another call")
                                .font(.subheadline)
                            Spacer()
                            Text("RETURN TO CALL")
                        }
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.allgramMain)
                    Spacer()
                }
            }
            // Cover with Invite screen if needed
            if showInvite {
//                ClubInviteView(vm: inviteVM) { state in
                NewInviteOverlay(vm: inviteVM) { state in
                    switch state {
                    case .rejected:
                        // Rejected invite - exit
                        presentationMode.wrappedValue.dismiss()
                    case .accepted:
                        // Accepted invite - show feed
                        showInvite = false
                    default:
                        // Processing handled inside
                        break
                    }
                }
                    .equatable()
                    .background(Color.backColor)
            }
        }
        .fullScreenCover(
            item: $callConfig,
            onDismiss: {
                callConfig = nil
            },
            content: { config in
                CallWebView(config)
                    .background(Color.black.ignoresSafeArea())
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            leading:
                HStack {
                    AvatarImageView(room.realAvatarURL, name: room.summary.displayname)
                        .frame(width: 32, height: 32)
                    Text(verbatim: room.summary.displayname).bold()
                }
                .onTapGesture {
                    showSettings = true
                }
            ,
            trailing:
                HStack {
                    Button {
                        checkPermissions {
                            CallHandler.shared.makeOutgoingCall(room: room, hasVideo: true)
//                            let myId = AuthViewModel.shared.sessionVM?.myUserId ?? ""
//                            let others = membersVM.filteredMembers.map { $0.id }
//                            guard let config = CallConfig.safeCall(.video, userId: myId, participantsIds: others) else { return }
//                            callConfig = config
                        }
                    } label: {
                        ToolbarImage(.videoCall)
                    }
                    .disabled(callHandler.capability(for: room) == .cannotCall)
                    .opacity(callHandler.capability(for: room) == .jitsiCallInsufficientPower ? 0.5 : 1)
                    Button {
                        checkPermissions {
                            CallHandler.shared.makeOutgoingCall(room: room, hasVideo: false)
//                            let myId = AuthViewModel.shared.sessionVM?.myUserId ?? ""
//                            let others = membersVM.filteredMembers.map { $0.id }
//                            guard let config = CallConfig.safeCall(.audio, userId: myId, participantsIds: others) else { return }
//                            callConfig = config
                        }
                    } label: {
                        ToolbarImage(.regularCall)
                    }
                    .disabled(callHandler.capability(for: room) != .canDirectCall)
                    Menu {
                        Button(action: { showSettings = true }, label: {
                            MoreOptionView(flat: "Settings", imageName: "users-cog-solid")
                        })
                        if room.isMeeting {
                            // Content search for not encrypted meetings
                            Button(action: { showContentSearch = true }, label: {
                                MoreOptionView(flat: "Search", imageName: "search-solid")
                            })
                        }
                        Button(action: { showInviteParticipant = true }, label: {
                            MoreOptionView(flat: "Invite", imageName: "user-plus-solid")
                                .opacity(inviteUserViewModel.canInvite ? 1 : 0.5)
                        })
                        Button(action: {
                            room.room.leave(completion: { _ in })
                            presentationMode.wrappedValue.dismiss()
                        }, label: {
                            MoreOptionView(flat: "Leave", imageName: "sign-out-alt-solid")
                        })
                    } label: {
                        ToolbarImage(.menuDots)
                    }
                }
            // Block when covered by invite
                .opacity(showInvite ? 0 : 1)
                .disabled(showInvite)
        )
        .alert(isPresented: $showPermissionAlert) {
            permissionAlertView
        }
    }
    
    /// Checks microphone and then camera if needed
    private func checkPermissions(completion: @escaping () -> Void) {
        checkMicrophone {
            checkCamera {
                completion()
            }
        }
    }
    
    private func checkCamera(completion: @escaping () -> Void) {
        switch PermissionsManager.shared.getAuthStatusFor(.video) {
        case .notDetermined: // User has not yet been asked for camera access
            AVCaptureDevice.requestAccess(for: .video) { response in
                if response {
                    completion()
                } else {
                    permissionAlertText = "camera"
                    showPermissionAlert = true
                }
            }
        case .authorized:
            completion()
        default:
            permissionAlertText = "camera"
            showPermissionAlert = true
        }
    }
    
    private func checkMicrophone(completion: @escaping () -> Void) {
        switch PermissionsManager.shared.getAuthStatusFor(.audio) {
        case .notDetermined: // User has not yet been asked for camera access
            AVCaptureDevice.requestAccess(for: .audio) { response in
                if response {
                    completion()
                } else {
                    permissionAlertText = "microphone"
                    showPermissionAlert = true
                }
            }
        case .authorized:
            completion()
        default:
            permissionAlertText = "microphone"
            showPermissionAlert = true
        }
    }
    
    @State private var showPermissionAlert = false
    @State private var permissionAlertText = ""
    
    private var permissionAlertView: Alert {
        return Alert(
            title: Text("Access to \(permissionAlertText)"),
            message: Text("Tap Settings and enable \(permissionAlertText)"),
            primaryButton: .default(
                Text("Settings"),
                action: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            ),
            secondaryButton: .cancel()
        )
    }
}
