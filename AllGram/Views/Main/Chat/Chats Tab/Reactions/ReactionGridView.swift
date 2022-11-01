//
//  ReactionGridView.swift
//  AllGram
//
//  Created by Alex Pirog on 27.06.2022.
//

import SwiftUI

struct ReactionGridItemView: View {
    let emoji: String
    let count: Int
    let addedByUser: Bool
    let textColor: Color
    let backColor: Color
    let userColor: Color

    init(emoji: String, count: Int, addedByUser: Bool, textColor: Color, backColor: Color, userColor: Color) {
        self.emoji = emoji
        self.count = count
        self.addedByUser = addedByUser
        self.textColor = textColor
        self.backColor = backColor
        self.userColor = userColor
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                Text(emoji)
                Text("\(count)")
            }
            .font(.footnote)
            .lineLimit(1)
            .foregroundColor(textColor)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(backView)
            .overlay(overlayView)
        }
    }
    
    @ViewBuilder
    private var backView: some View {
        Capsule().fill(backColor.opacity(addedByUser ? 0.3 : 0.7))
    }
    
    @ViewBuilder
    private var overlayView: some View {
        if addedByUser {
            Capsule().strokeBorder(userColor, lineWidth: 2)
        } else {
            EmptyView()
        }
    }
}

// MARK: -

struct ReactionGridView: View {
    @Environment(\.userId) var userId
    
    let reactions: [Reaction]
    let groups: [ReactionGroup]
    
    // Size configuration
    let widthLimit: CGFloat
    let alignment: HorizontalAlignment
    
    // Color configuration
    let textColor: Color
    let backColor: Color
    let userColor: Color
    
    let reactionTapHandler: (ReactionGroup) -> Void
    
    var rows: Int {
        let dCount = Double(groups.count)
        let dColumns = Double(columns)
        let dRows = dCount / dColumns
        return max(1, Int(dRows.rounded(.up)))
    }
    var columns: Int {
        let columnSpace = Constants.reactionWidth + Constants.reactionSpacing
        let columnsLimit = max(1, Int(widthLimit / columnSpace))
        return min(groups.count, columnsLimit)
    }
    
    @State private var showReactionDetails = false
    
    init(reactions: [Reaction], widthLimit: CGFloat, alignment: HorizontalAlignment, textColor: Color, backColor: Color, userColor: Color, reactionTapHandler: @escaping (ReactionGroup) -> Void) {
        self.reactions = reactions
        self.groups = reactions.groupReactions()
        self.reactionTapHandler = reactionTapHandler
        // Configuration
        self.widthLimit = widthLimit
        self.alignment = alignment
        self.textColor = textColor
        self.backColor = backColor
        self.userColor = userColor
    }
    
    init(groups: [ReactionGroup], widthLimit: CGFloat, alignment: HorizontalAlignment, textColor: Color, backColor: Color, userColor: Color, reactionTapHandler: @escaping (ReactionGroup) -> Void) {
        self.reactions = groups.toReactions()
        self.groups = groups
        self.reactionTapHandler = reactionTapHandler
        // Configuration
        self.widthLimit = widthLimit
        self.alignment = alignment
        self.textColor = textColor
        self.backColor = backColor
        self.userColor = userColor
    }
    
    var body: some View {
        GridVStack(rows: rows, columns: columns, vAlignment: alignment, vSpacing: Constants.reactionSpacing, hSpacing: Constants.reactionSpacing) { r, c in
            let index = c + (r * columns)
            if index < groups.count {
                let group = groups[index]
                ReactionGridItemView(
                    emoji: group.reaction,
                    count: group.count,
                    addedByUser: group.containsReaction(from: userId),
                    textColor: textColor,
                    backColor: backColor,
                    userColor: userColor
                )
                    .frame(width: Constants.reactionWidth)
                    .frame(height: Constants.reactionHeight)
                    .onTapGesture {
                        reactionTapHandler(group)
                    }
            } else {
                EmptyView()
            }
        }
        .onLongPressGesture {
            showReactionDetails = true
        }
        .sheet(isPresented: $showReactionDetails) {
            NavigationView {
                ReactionListView(reactions)
            }
        }
    }
    
    struct Constants {
        // TODO: What size for grid item to expect?
        static let reactionWidth: CGFloat = 60
        static let reactionHeight: CGFloat = 32
        static let reactionSpacing: CGFloat = 6
    }
}

// MARK: -

extension Array where Element: Hashable {
    /// Returns an array with all duplicate elements removed
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
    /// Removes all duplicate elements
    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
