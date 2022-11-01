//
//  Spinner.swift
//  AllGram
//
//  Created by Alex Pirog on 06.07.2022.
//

import SwiftUI

/// Simple `ProgressView` of circular style with custom tint color
struct Spinner: View {
    let color: Color
    
    init(_ color: Color = Color.gray) {
        self.color = color
    }
    
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: color))
    }
}
