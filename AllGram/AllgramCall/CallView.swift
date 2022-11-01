//
//  CallView.swift
//  AllGram
//
//  Created by Vladyslav on 22.11.2021.
//

import SwiftUI
import Kingfisher

struct CallView: View {
    
    let callHandler = CallHandler.shared
    
    @State var isRejectedHere = false
    
    @State var isMyVideoHidden = false
    @State var isMicrophoneMute = false
    @State var isSpeakerMute = false
    
    @State var seconds : UInt = 0
    
    @State private var showMenuOptions = false
    @State private var outputHelper = SoundPlayer.shared.forcedSpeaker ? "Speaker" : "Phone"
    
    private let timer = Timer.publish(every: 1, tolerance: 0.05, on: .main, in: .common).autoconnect()
    
    private let chatHandler: ((_ roodId: String?) -> Void)?
    
    init(chatHandler: ((_ roodId: String?) -> Void)? = nil) {
        self.chatHandler = chatHandler
    }

    var body: some View {
        ZStack {
            // For Video Calls
            ZStack {
                if isVideoCall() {
                    VideoView(isRemote: true)
                        .border(Color(.sRGB, white: 0.5, opacity: 0.2))
                        .ignoresSafeArea()
                    HStack {
                        Spacer()
                        VStack {
                            VideoView(isRemote: false)
                                .border(Color(.sRGB, white: 0.5, opacity: 0.2))
                                .frame(width: selfViewWidth(), height: selfViewHeight(), alignment: .topTrailing)
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            Spacer()
                        }
                    }
                } else {
                    // Voice handled in VStack
                }
            }
            // For Voice Calls
            VStack {
                if isVideoCall() {
                    // Video handled in ZStack
                } else {
                    Text(callerName())
                        .font(.largeTitle).bold()
                        .padding(.top, Constants.topPadding)
                    Text(isVideoCall() ? "Video Call" : "Voice Call")
                        .font(.title)
                        .foregroundColor(.gray)
                    AvatarImageView(callerAvatar(), name: callerName())
                        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
                    Spacer()
                }
            }
            // Controls
            VStack {
                Spacer()
                Text(timeShow())
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .frame(width: Constants.timerWidth, height: Constants.timerHeight)
                    .background(RoundedRectangle(cornerRadius: Constants.timerHeight / 2)
                                    .foregroundColor(.white))
                    .padding()
                HStack {
                    CallButton(type: .chat, scale: .small) {
                        chatHandler?(roomId())
                    }
                    CallButton(type: .mic(on: !isMicrophoneMute), scale: .medium) {
                        isMicrophoneMute.toggle()
                        callHandler.muteMicrophone(isMicrophoneMute)
                    }
                    .onAppear {
                        // Going back to call and it may be muted previously
                        isMicrophoneMute = callHandler.call?.audioMuted ?? false
                    }
                    if isVideoCall() {
                        CallButton(type: .video(on: !isMyVideoHidden), scale: .medium) {
                            isMyVideoHidden.toggle()
                            callHandler.hideMyVideo(isMyVideoHidden)
                        }
                    }
                    CallButton(type: .endCall, scale: .medium) {
                        callHandler.hangup(viewKind: .call)
                        isRejectedHere = true
                        //conferenceTerminated
                    }
                    CallButton(type: .menu, scale: .small) {
                        withAnimation { showMenuOptions = true }
                    }
                }
            }
            .padding(.bottom)
            // Menu options
            if showMenuOptions {
                VStack(spacing: 0) {
                    Spacer()
                    Divider()
                    VStack {
                        Button(action: {
                            let changed = SoundPlayer.shared.forceOutput(toSpeaker: !SoundPlayer.shared.forcedSpeaker)
                            if changed {
                                outputHelper = SoundPlayer.shared.forcedSpeaker ? "Speaker" : "Phone"
                            }
                        }) {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                    .resizable().scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                VStack(alignment: .leading) {
                                    Text("Select Sound Device (\(SoundPlayer.shared.outputOptions))")
                                        .foregroundColor(.allgramMain)
                                    Text(outputHelper)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Rectangle()
                                    .foregroundColor(.white)
                                    .ignoresSafeArea())
                }
                .background(
                    Rectangle()
                        .foregroundColor(.white.opacity(0.01))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showMenuOptions = false }
                        }
                )
                .transition(.move(edge: .bottom))
                .animation(.default)
            }
        }
        .transition(.asymmetric(insertion: .identity, removal: .slide))
        .animation(.none)
        .onReceive(timer) { output in
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                // Skip in preview
            } else {
                let durationMS = callHandler.callDurationMS(viewKind: .call)
                self.seconds = durationMS / 1000
            }
        }
        .onDisappear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                // Skip in preview
            } else {
                let soundName = (isRejectedHere ? "callend" : "busy")
                SoundPlayer.shared.play(name: soundName, repeat: false, vibrate: false, builtInReceiver: true)
            }
        }
    }
    
    struct Constants {
        static let topPadding: CGFloat = 36
        static let avatarSize: CGFloat = 180
        static let timerHeight: CGFloat = 24
        static let timerWidth: CGFloat = 60
    }
    
}

private extension CallView {
    
    var callType: CallViewType { .call }
    
    func callerName() -> String {
        callHandler.callerName(viewKind: callType)
    }
    
    func callerAvatar() -> URL? {
        URL(string: callHandler.callerAvatar(viewKind: callType))
    }
    
    func roomId() -> String? {
        callHandler.roomId(viewKind: callType)
    }
    
    func roomName() -> String {
        callHandler.roomName(viewKind: callType)
    }
    
    func isVideoCall() -> Bool {
        callHandler.isVideoCall(viewKind: callType)
    }
    
    func isConnected() -> Bool {
        callHandler.isCallConnected()
    }
    
    func timeShow() -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds - 60 * minutes
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    func selfViewWidth() -> CGFloat {
        return round(UIScreen.main.bounds.width * 0.25)
    }
    
    func selfViewHeight() -> CGFloat {
        return round(selfViewWidth() * 1.5)
    }
    
}

struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CallView()
                .navigationTitle("Call Nav Title")
        }
        .colorScheme(.dark)
        .previewDevice("iPhone 11")
        CallView()
            .background(Color.white)
            .colorScheme(.light)
            .previewDevice("iPhone 8 Plus")
    }
}

