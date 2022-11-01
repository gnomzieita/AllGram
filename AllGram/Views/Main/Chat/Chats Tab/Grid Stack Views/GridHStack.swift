//
//  GridHStack.swift
//  AllGram
//
//  Created by Alex Pirog on 27.06.2022.
//

import SwiftUI

struct GridHStack<Content: View>: View {
    let rows: Int
    let columns: Int
    let content: (Int, Int) -> Content
    
    // Configuration for VStack and HStack
    let vAlignment: HorizontalAlignment
    let vSpacing: CGFloat?
    let hAlignment: VerticalAlignment
    let hSpacing: CGFloat?
    
    init(rows: Int,
         columns: Int,
         vAlignment: HorizontalAlignment = .center,
         vSpacing: CGFloat? = nil,
         hAlignment: VerticalAlignment = .center,
         hSpacing: CGFloat? = nil,
         @ViewBuilder content: @escaping (Int, Int) -> Content
    ) {
        self.rows = rows
        self.columns = columns
        self.content = content
        // Configuration
        self.vAlignment = vAlignment
        self.vSpacing = vSpacing
        self.hAlignment = hAlignment
        self.hSpacing = hSpacing
    }

    var body: some View {
        HStack(alignment: hAlignment, spacing: hSpacing) {
            ForEach(0 ..< rows, id: \.self) { row in
                VStack(alignment: vAlignment, spacing: vSpacing) {
                    ForEach(0 ..< columns, id: \.self) { column in
                        content(row, column)
                    }
                }
            }
        }
    }
}
