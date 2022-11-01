//
//  ProgressView.swift
//  AllGram
//
//  Created by Admin on 17.08.2021.
//

import SwiftUI

struct LoaderView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    let cancellable: Bool
    let info: String
    let cancelAction: ActionHandler?
    private var logoSize: CGFloat {
        UIScreen.main.bounds.width / 3
    }
    
    typealias ActionHandler = () -> Void
    
    init(cancellable: Bool = false, info: String = "", cancelAction: ActionHandler? = nil) {
        self.cancellable = cancellable
        self.info = info
        self.cancelAction = cancelAction
    }
    
    var body: some View {
        ZStack {
            logoView
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        .edgesIgnoringSafeArea([.top, .bottom])
        .background(Color.backColor.opacity(1))
        .overlay(
            VStack {
                if info != "" {
                    Text(info)
                        .foregroundColor(.gray)
                        .padding(30)
                }
                Spinner(Color("AccentColor"))
                    .scaleEffect(2)
                    .padding(.all, 12)
                
                if cancellable {
                    Button(action: {
                        if let handler = cancelAction { handler() }
                        else { presentationMode.wrappedValue.dismiss() }
                    }) {
                        Text("Cancel").bold()
                            .foregroundColor(Color("AccentColor"))
                    }
                } else {
                    Text("Please, wait")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 60)
            , alignment: .bottom
        )
    }
    
    @State var showLogo = false
    
    private var logoView: some View {
        ZStack {
            Circle()
                .frame(width: logoSize * 5.4, height: logoSize * 5.4)
                .foregroundColor(Color("circlesColor"))
                .opacity(0.05)
                .scaleEffect(showLogo ? 1 : 0)
                .animation(Animation.easeInOut(duration: 0.5).delay(0.2))
            Circle()
                .frame(width: logoSize * 3.5, height: logoSize * 3.5)
                .foregroundColor(Color("circlesColor"))
                .opacity(0.1)
                .scaleEffect(showLogo ? 1 : 0)
                .animation(Animation.easeInOut(duration: 0.5).delay(0.15))
            Circle()
                .frame(width: logoSize * 2.3, height: logoSize * 2.3)
                .foregroundColor(Color("circlesColor"))
                .opacity(0.15)
                .scaleEffect(showLogo ? 1 : 0)
                .animation(Animation.easeInOut(duration: 0.5).delay(0.1))
            Image("logo")
                .resizable()
                .frame(width: logoSize, height: logoSize)
                .scaleEffect(showLogo ? 1 : 0)
                .animation(Animation.easeInOut(duration: 0.5))
        }
        .onAppear {
            showLogo = true
        }
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoaderView(cancellable: true, info: "")
                    .colorScheme(.dark)
            LoaderView(cancellable: false, info: "Uncacellable info text that can be very-very long and take multiple lines")
                    .colorScheme(.light)
            LoaderView()
        }
    }
}
