//
//  SwiftUILazyView.swift
//  AllGram
//
//  Created by Vladyslav on 24.12.2021.
//

import SwiftUI

// from internet: https://stackoverflow.com/questions/57594159/swiftui-navigationlink-loads-destination-view-immediately-without-clicking?answertab=votes#tab-top

struct SwiftUILazyView<Content: View>: View {
    let build : () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

