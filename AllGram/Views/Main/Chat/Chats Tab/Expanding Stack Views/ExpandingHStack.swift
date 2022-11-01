//
//  ExpandingHStack.swift
//  AllGram
//
//  Created by Alex Pirog on 09.06.2022.
//

import SwiftUI

/// Acts like a regular `HStack`, but adds `Spacer`s to move the content to a given position
struct ExpandingHStack<Content>: View where Content: View {
    let contentPosition: HorizontalContentPosition
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content
    
    init(
        contentPosition: HorizontalContentPosition = .center(),
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder contentBuilder: () -> Content
    ) {
        self.contentPosition = contentPosition
        self.alignment = alignment
        self.spacing = spacing
        self.content = contentBuilder()
    }
    
    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            if contentPosition.addLeftSpacer {
                Spacer(minLength: contentPosition.leftSpacerMinLength)
            }
            content
            if contentPosition.addRightSpacer {
                Spacer(minLength: contentPosition.rightSpacerMinLength)
            }
        }
    }
}

/// Horizontal content position for `ExpandingHStack` configuration
struct HorizontalContentPosition {
    let addLeftSpacer: Bool
    let addRightSpacer: Bool
    let leftSpacerMinLength: CGFloat?
    let rightSpacerMinLength: CGFloat?
    
    private init(
        addLeftSpacer: Bool = false,
        addRightSpacer: Bool = false,
        leftSpacerMinLength: CGFloat? = nil,
        rightSpacerMinLength: CGFloat? = nil
    ) {
        self.addLeftSpacer = addLeftSpacer
        self.addRightSpacer = addRightSpacer
        self.leftSpacerMinLength = leftSpacerMinLength
        self.rightSpacerMinLength = rightSpacerMinLength
    }
    
    static func left(minLength: CGFloat? = nil) -> HorizontalContentPosition {
        HorizontalContentPosition(
            addRightSpacer: true,
            rightSpacerMinLength: minLength
        )
    }
    
    static func right(minLength: CGFloat? = nil) -> HorizontalContentPosition {
        HorizontalContentPosition(
            addLeftSpacer: true,
            leftSpacerMinLength: minLength
        )
    }
    
    static func center(leftMinLength: CGFloat? = nil, rightMinLength: CGFloat? = nil) -> HorizontalContentPosition {
        HorizontalContentPosition(
            addLeftSpacer: true,
            addRightSpacer: true,
            leftSpacerMinLength: leftMinLength,
            rightSpacerMinLength: rightMinLength
        )
    }
}
