//
//  ExpandingVStack.swift
//  AllGram
//
//  Created by Alex Pirog on 09.06.2022.
//

import SwiftUI

/// Acts like a regular `VStack`, but adds `Spacer`s to move the content to a given position
struct ExpandingVStack<Content>: View where Content: View {
    let contentPosition: VerticalContentPosition
    let alignment: HorizontalAlignment
    let spacing: CGFloat?
    let content: Content
    
    init(
        contentPosition: VerticalContentPosition = .middle(),
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder contentBuilder: () -> Content
    ) {
        self.contentPosition = contentPosition
        self.alignment = alignment
        self.spacing = spacing
        self.content = contentBuilder()
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            if contentPosition.addTopSpacer {
                Spacer(minLength: contentPosition.topSpacerMinLength)
            }
            content
            if contentPosition.addBottomSpacer {
                Spacer(minLength: contentPosition.bottomSpacerMinLength)
            }
        }
    }
}

/// Vertical content position for `ExpandingVStack` configuration
struct VerticalContentPosition {
    let addTopSpacer: Bool
    let addBottomSpacer: Bool
    let topSpacerMinLength: CGFloat?
    let bottomSpacerMinLength: CGFloat?
    
    private init(
        addTopSpacer: Bool = false,
        addBottomSpacer: Bool = false,
        topSpacerMinLength: CGFloat? = nil,
        bottomSpacerMinLength: CGFloat? = nil
    ) {
        self.addTopSpacer = addTopSpacer
        self.addBottomSpacer = addBottomSpacer
        self.topSpacerMinLength = topSpacerMinLength
        self.bottomSpacerMinLength = bottomSpacerMinLength
    }
    
    static func top(minLength: CGFloat? = nil) -> VerticalContentPosition {
        VerticalContentPosition(
            addBottomSpacer: true,
            bottomSpacerMinLength: minLength
        )
    }
    
    static func bottom(minLength: CGFloat? = nil) -> VerticalContentPosition {
        VerticalContentPosition(
            addTopSpacer: true,
            topSpacerMinLength: minLength
        )
    }
    
    static func middle(topMinLength: CGFloat? = nil, bottomMinLength: CGFloat? = nil) -> VerticalContentPosition {
        VerticalContentPosition(
            addTopSpacer: true,
            addBottomSpacer: true,
            topSpacerMinLength: topMinLength,
            bottomSpacerMinLength: bottomMinLength
        )
    }
}
