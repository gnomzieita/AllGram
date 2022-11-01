//
//  BlurView.swift
//  AllGram
//
//  Created by Admin on 18.08.2021.
//

import Foundation
import SwiftUI

struct BlurView: UIViewRepresentable {
    typealias UIViewType = UIVisualEffectView
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIViewType {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
}
