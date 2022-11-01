//
//  IncomingSecondCallView.swift
//  AllGram
//
//  Created by Vladyslav on 23.11.2021.
//

import SwiftUI
import Kingfisher

struct IncomingSecondCallView: View {
    
    let callHandler = CallHandler.shared
    
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
                callHandler.hangup(viewKind: .incomingSecond)
            }
            .padding(.bottom)
        }
    }
    
    struct Constants {
        static let topPadding: CGFloat = 36
        static let avatarSize: CGFloat = 180
    }
    
}

private extension IncomingSecondCallView {
    
    var callType: CallViewType { .incomingSecond }
    
    func callerName() -> String {
        callHandler.callerName(viewKind: callType)
    }
    
    func callerAvatar() -> URL? {
        URL(string: callHandler.callerAvatar(viewKind: callType))
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
    
}

struct IncomingSecondCallView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            IncomingSecondCallView()
                .navigationTitle("Call Nav Title")
        }
        .colorScheme(.dark)
        .previewDevice("iPhone 11")
        IncomingSecondCallView()
            .background(Color.white)
            .colorScheme(.light)
            .previewDevice("iPhone 8 Plus")
    }
}
