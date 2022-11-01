//
//  ReactionListView.swift
//  AllGram
//
//  Created by Alex Pirog on 27.06.2022.
//

import SwiftUI

struct ReactionListItemView: View {
    let reaction: Reaction

    private var sendTime: String {
        Formatter.string(
            for: reaction.timestamp,
            dateStyle: .short,
            timeStyle: .short
        )
    }

    var body: some View {
        HStack {
            Text(reaction.reaction)
            Text(reaction.sender.dropAllgramSuffix)
            Spacer()
            Text(sendTime)
                .font(.footnote)
        }
    }
}

// MARK: -

struct ReactionListView: View {
    let reactions: [Reaction]
    
    init(_ reactions: [Reaction]) {
        self.reactions = reactions
    }
    
    var body: some View {
        List {
            ForEach(reactions) { reaction in
                ReactionListItemView(reaction: reaction)
            }
        }
        .padding(.top, 1)
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitle("Reactions", displayMode: .inline)
    }
}
