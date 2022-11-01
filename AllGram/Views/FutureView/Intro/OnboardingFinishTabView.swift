//
//  OnboardingFinishTabView.swift
//  AllGram
//
//  Created by Eugene Ned on 02.08.2022.
//

import SwiftUI

struct OnboardingFinishTabView: View {
    
    @State var showLogo = false
    let pageTitle: String
    let pageCaption: String
    
    var body: some View {
        ZStack {
            PulsatingLogo()
                .scaleEffect(showLogo ? 1 : 0)
                .animation(.spring().speed(0.5))
            VStack {
                Spacer()
                Text(pageTitle)
                    .font(.title2)
                    .bold()
                    .padding()
                Text(pageCaption.uppercased())
                    .font(.subheadline)
                    .bold()
                    .kerning(0.4)
                    .padding([.horizontal, .bottom])
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.6)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            self.showLogo = true
        }
        
    }
}

//struct OnboardingFinishTabView_Previews: PreviewProvider {
//    static var previews: some View {
//        OnboardingFinishTabView()
//    }
//}
