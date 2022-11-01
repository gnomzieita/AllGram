//
//  OutgoingAcceptanceView.swift
//  AllGram
//
//  Created by Vladyslav on 22.11.2021.
//

import SwiftUI
import Kingfisher

struct OutgoingAcceptanceView: View {
    
    let callHandler = CallHandler.shared
    let soundPlayer = SoundPlayer.shared
    
    @State var isRejectedHere = false
    
    var body: some View {
        VStack {
            Text(callerName())
                .font(.largeTitle).bold()
                .padding(.top, Constants.topPadding)
            Text(isVideoCall() ? "Video Call" : "Voice Call")
                .font(.title)
                .foregroundColor(.gray)
            AvatarImageView(callerAvatar(), name: callerName())
                .frame(width: Constants.avatarSize, height: Constants.avatarSize)
            Text("Calling...")
                .font(.title)
                .foregroundColor(.gray)
            Spacer()
            CallButton(type: .endCall, scale: .huge) {
                callHandler.hangup(viewKind: .outgoing)
                isRejectedHere = true
            }
            .padding(.bottom)
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                // Skip in preview
            } else {
//                SoundPlayer.shared.play(name: "ringback", repeat: true, vibrate: false, builtInReceiver: true)
                RingtoneSoundPlayer.shared.startBackgroundMusic()
            }
        }
        .onDisappear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                // Skip in preview
            } else {
                if isConnected() {
                    soundPlayer.stop(deactivatingAudioSession: false)
                } else {
                    let soundName = (isRejectedHere ? "callend" : "busy")
                    soundPlayer.play(name: soundName, repeat: false, vibrate: false, builtInReceiver: true)
                }
            }
        }
    }
    
    struct Constants {
        static let topPadding: CGFloat = 36
        static let avatarSize: CGFloat = 180
    }
    
}

private extension OutgoingAcceptanceView {
    
    var callType: CallViewType { .outgoing }
    
    func callerName() -> String {
        callHandler.callerName(viewKind: callType)
    }
    
    func callerAvatar() -> URL? {
        URL(string: callHandler.callerAvatar(viewKind: callType))
    }
    
    func isVideoCall() -> Bool {
        callHandler.isVideoCall(viewKind: callType)
    }
    
    func isConnected() -> Bool {
        callHandler.isCallConnected()
    }
    
}

struct OutgoingAcceptanceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OutgoingAcceptanceView()
                .navigationTitle("Call Nav Title")
        }
        .colorScheme(.dark)
        .previewDevice("iPhone 11")
        OutgoingAcceptanceView()
            .background(Color.white)
            .colorScheme(.light)
            .previewDevice("iPhone 8 Plus")
    }
}
