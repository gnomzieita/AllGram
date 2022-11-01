//
//  OnboardingAccessTabView.swift
//  AllGram
//
//  Created by Eugene Ned on 02.08.2022.
//

import SwiftUI

struct OnboardingAccessTabView: View {
    
    let imageName: String
    let pageTitle: String
    let pageCaption: String
    let pageDescription: String
    
    var body: some View {
        VStack {
            Image(imageName)
                .padding(.top)
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
            Text(pageDescription)
                .font(.subheadline)
                .kerning(0.25)
                .padding([.horizontal, .bottom])
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(0.6)
        }
    }
}

//struct OnboardingAccessTabView_Previews: PreviewProvider {
//    static var previews: some View {
//        OnboardingAccessTabView()
//    }
//}
