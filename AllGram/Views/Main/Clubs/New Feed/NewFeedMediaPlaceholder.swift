//
//  NewFeedMediaPlaceholder.swift
//  AllGram
//
//  Created by Alex Pirog on 23.09.2022.
//

import SwiftUI

struct NewFeedMediaPlaceholder: View {
    let isBusy: Bool
    
    var body: some View {
        Color.gray.opacity(0.1)
            .overlay(overlayView)
    }
    
    @ViewBuilder
    private var overlayView: some View {
        if isBusy {
            Spinner()
        } else {
            Image("exclamation-triangle-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
        }
    }
}
