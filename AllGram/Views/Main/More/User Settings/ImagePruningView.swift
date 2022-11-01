//
//  ImagePruningView.swift
//  AllGram
//
//  Created by Derevyanko Vladyslav on 06.01.2022.
//

import SwiftUI
import Combine
import MatrixSDK

struct ImagePruningView: View {
    @Binding var uiImage : UIImage?
    @Environment(\.presentationMode) var presentationMode
    var mxSession: MXSession?
    
    @ObservedObject private var model = ImagePruningModel.shared
    
    var body: some View {
        VStack {
            Text("Move around and pinch the image to fit into the cropping circle")
            
            if nil != uiImage {
                imageArea
                    .frame(minHeight: 300)
            }
   
			HStack {
				Button("Cancel") {
					presentationMode.wrappedValue.dismiss()
				}
				.frame(height: 50, alignment: .center)
				.padding(.horizontal, 25)
				.foregroundColor(Color("ButtonFgColor"))
				.background(Color("ButtonBkColor"))
				.clipShape(Capsule())
				
                ZStack {
                    let progress = model.uploadingProgress
                    
                    Button("Upload") {
                        guard let image = uiImage, let session = mxSession else {
                            return
                        }
                        model.uploadScaledImage(image: image, session: session)
                    }
                    .disabled(progress.isStarted())
                    .frame(height: 50, alignment: .center)
                    .padding(.horizontal, 25)
                    .foregroundColor(Color("ButtonFgColor"))
                    .background(Color("ButtonBkColor"))
                    .clipShape(Capsule())
                    .opacity(progress.isStarted() ? 0.5 : 1)
                    
                    if progress.isBusy() {
                        ProgressView()
                    } else if case .error(let err) = progress, let error = err {
                        Text("Failure: \(error)")
                    }
                }
			}
        }
        .onAppear {
            model.resetModel()
        }
        .onReceive(model.$uploadingProgress) { newValue in
            if case .done = newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private var imageArea : some View {
		GeometryReader { geomProxy in
			let sz = geomProxy.size
			ZStack {
				VStack {
					let imgSize = model.currentImageSize(in: sz, rawImgSize: uiImage?.size)
					Image(uiImage: uiImage!)
						.resizable()
						.scaledToFit()
						.frame(width: imgSize.width, height: imgSize.height, alignment: .center)
						.offset(model.offset)
				}
				.frame(width: sz.width, height: sz.height, alignment: .center)
 
				Rectangle()
					.foregroundColor(Color(.sRGB, white: 0.5, opacity: 0.6))
					.mask(RoundHole(radius: model.holeRadius(in: sz))
							.fill(style: FillStyle(eoFill: true, antialiased: true)))
			}
        }
		.gesture(SimultaneousGesture(magnifG, dragG))
    }
    
	var magnifG : some Gesture {
		MagnificationGesture(minimumScaleDelta: 0.001)
			.onChanged { k in
				model.adjustScale(multiplier: k)
			}
			.onEnded { _ in
				model.resetScaling()
			}
	}
	var dragG : some Gesture {
		DragGesture()
			.onChanged { dragValue in
				model.adjustOffset(translation: dragValue.translation)
			}
			.onEnded { dragValue in
				model.resetTranslation()
			}
	}
}

fileprivate struct RoundHole : Shape {
	let radius : CGFloat
	func path(in rect: CGRect) -> Path {
		var path = Path(rect)
		let boundingRect = CGRect(x: rect.midX - radius, y: rect.midY - radius,
								  width: 2 * radius, height: 2 * radius)
		path.addEllipse(in: boundingRect, transform: .identity)
		return path
	}
}

