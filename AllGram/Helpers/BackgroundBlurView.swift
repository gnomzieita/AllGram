//
//  BackgroundBlurView.swift
//  AllGram
//
//  Created by Wladislaw Derevianko on 10.11.2021.
//

import SwiftUI

struct BackgroundBlurView: UIViewRepresentable {
    var effect: UIBlurEffect.Style
    var color: UIColor
    
	func makeUIView(context: Context) -> UIVisualEffectView {
		return  UIVisualEffectView()
	}

	func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: self.effect)
        uiView.contentView.backgroundColor = color
    }
}
