//
//  View+gestures.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 11.02.2022.
//

import SwiftUI

extension View {
    func onTouchDownGesture(callback: @escaping (DragGesture.Value) -> Void) -> some View {
        modifier(OnTouchDownGestureModifier(callback: callback))
    }
    func onTouchUpGesture(callback: @escaping (DragGesture.Value) -> Void) -> some View {
        modifier(OnTouchUpGestureModifier(callback: callback))
    }
}

private struct OnTouchDownGestureModifier: ViewModifier {
    let callback: (DragGesture.Value) -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                                    .onChanged { gesture in
                self.callback(gesture)
            })
    }
}

private struct OnTouchUpGestureModifier: ViewModifier {
    let callback: (DragGesture.Value) -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                                    .onEnded { gesture in
                self.callback(gesture)
            })
    }
}
