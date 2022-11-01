//
//  PulsatingLogo.swift
//  AllGram
//
//  Created by Eugene Ned on 29.07.2022.
//

import SwiftUI

struct PulsatingLogo: View {
    
    @State var animation = false
    private var logoSize: CGFloat {
        UIScreen.main.bounds.width / 2.5
    }
    
    var body: some View {
        ZStack {
            Circle()
                .frame(width: logoSize, height: logoSize)
                .foregroundColor(Color("mainColor"))
                .scaleEffect(animation ? 4 : 1)
                .opacity(animation ? 0 : 0.6)
                .animation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: false))
            Circle()
                .frame(width: logoSize, height: logoSize)
                .foregroundColor(Color("mainColor"))
                .scaleEffect(animation ? 3 : 1)
                .opacity(animation ? 0 : 0.7)
                .animation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: false).delay(0.5))
            Circle()
                .frame(width: logoSize, height: logoSize)
                .foregroundColor(Color("mainColor"))
                .scaleEffect(animation ? 2 : 1)
                .opacity(animation ? 0 : 0.8)
                .animation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: false).delay(1))
            Image("logo")
                .resizable()
                .frame(width: logoSize, height: logoSize)
                .scaleEffect(animation ? 1.2 : 1)
                .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true))
                .shadow(radius: 35)
                .onAppear {
                    withAnimation {
                        self.animation = true
                    }
                }
        }
    }
}

struct PulsatingLogo_Previews: PreviewProvider {
    static var previews: some View {
        PulsatingLogo()
    }
}
