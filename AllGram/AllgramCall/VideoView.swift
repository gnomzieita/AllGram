//
//  VideoView.swift
//  AllGram
//
//  Created by Alex Pirog on 10.02.2022.
//

import SwiftUI

/// Basic UIView that gets video content from CallHandler automatically
struct VideoView : UIViewRepresentable {
    
    let isRemote : Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.clipsToBounds = true
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        CallHandler.shared.setCallsVideoView(uiView, isRemote: isRemote)
    }
    
    typealias UIViewType = UIView
    
}
