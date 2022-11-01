//
//  IncomingCallView.swift
//  AllGram
//
//  Created by Wladislaw Derevianko on 05.11.2021.
//

import SwiftUI
import Combine
import MatrixSDK

struct IncomingCallView: View {
	@Binding var isShown : Bool
	@State var isAccepted = false
	@ObservedObject var callHandler = CallHandler.shared
    let call : MXCall
	
	var isVideo : Bool {
		return call.isVideoCall
	}
	var callerName : String {
		return call.callerName ?? "(unknown caller)"
	}
	var roomName : String {
		return call.callSignalingRoom.summary.displayname ?? "(unknown room)"
	}
	func reasonOfEndingCall() -> String {
		let terminated = "Call was terminated"
		if call.endReason == .remoteHangup {
			
			return "Call is discarded"
		}
		return terminated
	}
	
    var body: some View {
//		if isAccepted {
//			callView
//		} else {
			VStack {
				Spacer()
				Text("Call from: \(callerName)")
					.font(.headline)
				if callerName != roomName {
					Text("Room: \(roomName)")
				}
				Text(isVideo ? "video call" : "audio call")
					.padding(.top, 20)
				Spacer()
				HStack {
					Button {
						// isShown = false
						//SoundPlayer.shared.stop(deactivatingAudioSession: true)
						// send reject
						call.hangup(with: .userHangup)
					} label: {
						Image(systemName: "phone.down.fill")
							.font(.largeTitle)
					}
					.frame(width: 70, height: 70)
					.background(Color.red)
					.foregroundColor(.white)
					.clipShape(Circle())
					
					
					Button {
						isAccepted = true
						//SoundPlayer.shared.stop(deactivatingAudioSession: false)
						
						// todo: send the accept event
						//call()?.answer()
					} label: {
						Image(systemName: "phone.fill.arrow.up.right")
							.font(.largeTitle)
					}
					.frame(width: 70, height: 70)
					.background(Color.green)
					.clipShape(Circle())
					
				}
				.font(.headline)
				
				Spacer()
			}
			.onAppear {
				callHandler.isEndOfCall = false
				//SoundPlayer.shared.play(name: "ring", repeat: true, vibrate: true, builtInReceiver: true)
			}
			.fullScreenCover(isPresented: $callHandler.isEndOfCall) {
				ZStack {
					Text(reasonOfEndingCall())
						.frame(width: 200, height: 100, alignment: .center)
						.background(Color(.sRGB, red: 1, green: 0.5, blue: 0.5, opacity: 0.5))
						.onAppear {
							SoundPlayer.shared.play(name: "callend", repeat: false, vibrate: false, builtInReceiver: true)
                            let date0 = Date()
							DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500)) {
                                let dt = -date0.timeIntervalSinceNow
								SoundPlayer.shared.stop(deactivatingAudioSession: true)
                                
								callHandler.isEndOfCall = false
								self.isShown = false
                                print("----- Time shown = \(dt) ------")
							}
						}
					
				}
				.background(BackgroundBlurView(blurStyle: .regular))
			}
//		}
	}
	var callView : some View {
		VStack {
			Text("Call from: \(callerName)")
				.font(.headline)
			Spacer()
			Button("Close") {
                SoundPlayer.shared.stop(deactivatingAudioSession: false)
                call.hangup(with: .userHangup)
                if isShown {
                    isShown = false
                } else {
                    isShown.toggle()
                    isShown = false
                    isAccepted = false
                }
				
            } .font(.headline)
		}
        .onAppear {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print("--- Record permission is granted: \(granted) ----")
            }
        }
        
    }
}

fileprivate struct StatefulPreviewWrapper<Value, Content: View>: View {
	@State var value: Value
	var content: (Binding<Value>) -> Content

	var body: some View {
		content($value)
	}

	init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
		self._value = State(wrappedValue: value)
		self.content = content
	}
}

//struct CallView1_Previews: PreviewProvider {
//    static var previews: some View {
//		StatefulPreviewWrapper(false) {
//			IncomingCallView(isShown: $0)
//		}
//    }
//}
