//
//  PullToRefresh.swift
//  AllGram
//
//  Created by Alex Pirog on 31.08.2022.
//

import SwiftUI

/*
 // Example:
 ScrollView {
     PullToRefresh(coordinateSpaceName: "pullToRefresh") {
         // Do the refresh
     }
    // Scrollable content
 }
 .coordinateSpace(name: "pullToRefresh")
 */

struct PullToRefresh: View {
    let coordinateSpaceName: String
    let onRefresh: () -> Void
    
    @State var needRefresh = false
    
    private let refreshHeight: CGFloat = 30
    
    var body: some View {
        GeometryReader { geo in
            if (geo.frame(in: .named(coordinateSpaceName)).midY > refreshHeight) {
                Spacer()
                    .onAppear {
                        withAnimation { needRefresh = true }
                    }
            } else if (geo.frame(in: .named(coordinateSpaceName)).maxY < 0) {
                Spacer()
                    .onAppear {
                        if needRefresh {
                            withAnimation { needRefresh = false }
                            onRefresh()
                        }
                    }
            }
            HStack(alignment: .bottom) {
                Spacer()
                if needRefresh {
                    ProgressView()
                }
                else {
                    Text("Pull to refresh")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .frame(height: refreshHeight)
        }
        .padding(.top, -refreshHeight)
    }
}
