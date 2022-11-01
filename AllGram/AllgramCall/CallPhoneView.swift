//
//  MyDesign.swift
//  AllGram
//
//  Created by Ярослав Шерстюк on 10.09.2021.
//

import SwiftUI
import MatrixSDK

struct CallPhoneView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var showCallView: Bool
    let room: AllgramRoom
	@Binding var hasVideo: Bool
    
    @State var isOutgoing = true
    @State var call : MXCall?
	@ObservedObject var callHandler = CallHandler.shared
    
	@State var isActive = false
	@State var seconds = 0
	private let timer = Timer.publish(every: 1, tolerance: 0.05, on: .main, in: .common).autoconnect()
	
	func reasonOfEndingCall() -> String {
		let terminated = "Call was terminated"
		if let call = self.call {
			if call.endReason == .busy {
				return "Call is declined"
			}
		}
		return terminated
	}
	func timeShow() -> String {
        let s : Int
        if let ms = call?.duration {
            s = Int(bitPattern: ms) / 1000
        } else {
            s = seconds
        }
		let minutes = s / 60
		let remainingSeconds = s - 60 * minutes
		return String(format: "%d:%02d", minutes, remainingSeconds)
	}
	
    var body: some View {
        ZStack {
            Color.gray.edgesIgnoringSafeArea(.all)
            VStack {
                Text("Talk with: " + room.summary.displayname)
                    
                    .bold()
                    .font(.title)
                    .foregroundColor(.white)
                
                Text(timeShow()).padding()
                    .font(.system(size: 25))
                    .foregroundColor(.white)
                    .frame(width: UIScreen.main.bounds.width - 32)
                
				if hasVideo {
					HStack {
						VideoView(isRemote: true)
							.border(Color.yellow)
							.aspectRatio(1.0, contentMode: .fill)
						VideoView(isRemote: false)
							.border(Color.blue)
							.frame(width: selfViewSide(), height: selfViewSide(), alignment: .center)
							.aspectRatio(1.0, contentMode: .fill)
					}
				}
				
                Spacer()
				if callHandler.isOutgoingCallAccepted {
					HStack(spacing: 35) {
						Button(action: {}) {
							VStack {
								Image(systemName: "mic.slash.fill")
									.font(.system(size: 28))
									.frame(width: 40, height: 40)
									.padding()
									.foregroundColor(.white)
									.background(Color.black.opacity(0.08))
									.clipShape(Circle())
								
								Text("mute")
									
									.foregroundColor(.white)
								
							}
						} //btn
						
						Button(action: {}) {
							VStack {
								Image(systemName: "circle.grid.3x3.fill")
									.font(.system(size: 28))
									.frame(width: 40, height: 40)
									.padding()
									.foregroundColor(.white)
									.background(Color.black.opacity(0.08))
									.clipShape(Circle())
								
								Text("keypad")
									
									.foregroundColor(.white)
								
							}
						} //btn
						
						Button(action: {
							//...
						}) {
							VStack {
								Image(systemName: "speaker.1.fill")
									.font(.system(size: 28))
									.frame(width: 40, height: 40)
									.padding()
									.foregroundColor(.white)
									.background(Color.black.opacity(0.08))
									.clipShape(Circle())
								
								Text("audio")
									
									.foregroundColor(.white)
								
							}
						} //btn
						
					} //HStack
					.onAppear {
						// SoundPlayer.shared.stop(deactivatingAudioSession: false)
                        print("----- onAppear CallPhoneView ------")
						isActive = true
					}
				}
                HStack(spacing: 35) {
                    Button(action: {
                        //...
                    }) {
                        VStack {
                            Image(systemName: "plus")
                                .font(.system(size: 28))
                                .frame(width: 40, height: 40)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.08))
                                .clipShape(Circle())
                            
                            
                            Text("add call")
                                .foregroundColor(.white)
                            
                        }
                    } //btn
                    
                    Button(action: {
                        //...
                    }) {
                        VStack {
                            Image(systemName: "questionmark.video.fill")
                                .font(.system(size: 28))
                                .frame(width: 40, height: 40)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.08))
                                .clipShape(Circle())
                            
                            
                            Text("FaceTime")
                                .foregroundColor(.white)
                            
                        }
                    }//btn
                    
                    Button(action: {
                        //...
                    }) {
                        VStack {
                            Image(systemName: "person.circle")
                                .font(.system(size: 28))
                                .frame(width: 40, height: 40)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.08))
                                .clipShape(Circle())
                            
                            Text("contacts")
                                .foregroundColor(.white)
                            
                        }
                    }//btn
                }
                Spacer()
                
                VStack {
                    Button(action: {
                        var needCloseHere = true
                        if let call = self.call {
                            if call.state != .ended {
                                call.hangup(with: .userHangup)
                                needCloseHere = false
                            }
                        }
                        if needCloseHere {
                            if showCallView {
                                showCallView = false
                            } else {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }, label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 28))
                            .frame(width: 40, height: 40)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.red.opacity(0.98))
                            .clipShape(Circle())
                            .rotationEffect(.init(degrees: 135))
                    })
                    
                }
                .padding()
                
            }
        }
		.fullScreenCover(isPresented: $callHandler.isEndOfCall) {
			ZStack {
				Text(reasonOfEndingCall())
					.frame(width: 200, height: 100, alignment: .center)
					.background(Color(.sRGB, white: 1, opacity: 0.5))
					.onAppear {
						// SoundPlayer.shared.play(name: "callend", repeat: true, vibrate: false, builtInReceiver: true)
						DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500)) {
							// SoundPlayer.shared.stop(deactivatingAudioSession: true)
							callHandler.isEndOfCall = false
							
                            showCallView = false
							//self.presentationMode.wrappedValue.dismiss()
						}
					}
				
			}
			.background(BackgroundBlurView(blurStyle: .regular))
		}
        .onAppear {
			if hasVideo {
				CallHandler.shared.setVideoLinker(roomId: room.summary.roomId) { isRemote in
					if isRemote {
						return self.remoteVideoView.theUIView ?? savedRemoteVideoView
					} else {
						return self.selfVideoView.theUIView ?? savedLocalVideoView
					}
				}
			}

            if isOutgoing {
				callHandler.isOutgoingCallAccepted = false
				// SoundPlayer.shared.play(name: "ringback", repeat: true, vibrate: false, builtInReceiver: false)
                let callManager = room.room.mxSession.callManager
                callManager?.placeCall(inRoom: room.room.roomId, withVideo: hasVideo, success: { mxCall in
                    self.call = mxCall
                    callManager?.callKitAdapter?.start(mxCall)
                }, failure: { error in
                    print("ERROR placing call: \(String(describing: error))")
                })
            }
        }
        .onDisappear {
			// SoundPlayer.shared.stop(deactivatingAudioSession: true)
            if let mxCall = call {
				//mxCall.hangup(with: .userHangup)
                //room.room.mxSession.callManager?.callKitAdapter?.end(mxCall)
            }
        }
		.onReceive(timer) { output in
			if isActive {
				seconds += 1
			}
		}
        
    }
	func selfViewSide() -> CGFloat {
		return round(UIScreen.main.bounds.width * 0.25)
	}
    
	// ---
	private struct VideoView : UIViewRepresentable {
		let isRemote: Bool
		@State var theUIView : UIView?
		
		func makeUIView(context: Context) -> UIView {
			let v = UIView()
			if isRemote {
				savedRemoteVideoView = v
			} else {
				savedLocalVideoView = v
			}
			DispatchQueue.main.async {
				// note: it is too late, the initialization of video view aleady has failed
				self.theUIView = v
			}
			return v
		}
		
		func updateUIView(_ uiView: UIView, context: Context) {
		}
		
		typealias UIViewType = UIView
	}
	var selfVideoView = VideoView(isRemote: false)
	var remoteVideoView = VideoView(isRemote: true)
}

/* These two variables are used for a workaround.  The problem is
   how to insert the two UIViews from MatrixSDK (MXCall.selfVideoView and MXCall.remoteVideoView)
   into the view hierarchy of SwiftUI.
   It is impossible to directly extract UIView from UIViewRepresentable, and
   if using DispatchQueue.async, the extraction would be too late for MatrixSDK
 */
fileprivate var savedLocalVideoView : UIView?
fileprivate var savedRemoteVideoView : UIView?

