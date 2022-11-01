//
//  JitsiCallView.swift
//  AllGram
//
//  Created by Vladyslav on 20.12.2021.
//

import SwiftUI

struct JitsiCallView: View {
    @ObservedObject var model = JitsiCallModel.shared
    @State var isMicrophoneMute = false
    
    var body: some View {
        if let error = model.problemDescription {
            VStack {
                Spacer()
                Text("\(error)")
                    .font(.title)
                
                Spacer(minLength: 30)
                
                Button("Close") {
                    CallHandler.shared.isShownJitsiCallView = false
                }
                .frame(width: 90, height: 60, alignment: .center)
                .foregroundColor(Color("ButtonFgColor"))
                .background(Color("ButtonBkColor"))
                .clipShape(Capsule())
                
                Spacer()
            }.onAppear(){
                CallHandler.shared.isShownJitsiCallView = false
            }
        } else {
            AdaptedJitsiView(model: JitsiCallModel.shared)
        }
    }
}

final class AdaptedJitsiView : UIViewRepresentable {
    let model : JitsiCallModel
    init(model: JitsiCallModel) {
        self.model = model
    }
    func makeUIView(context: Context) -> UIView {
        return model.getView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
    
    typealias UIViewType = UIView
}


struct JitsiCallView_Previews: PreviewProvider {
    static var previews: some View {
        JitsiCallView()
    }
}
