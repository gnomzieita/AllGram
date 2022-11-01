//
//  InviteSelectedView.swift
//  AllGram
//
//  Created by Alex Pirog on 11.02.2022.
//

import SwiftUI

struct InviteSelectedView: View {
    let name: String
    let deselection: (() -> Void)?
    
    init(name: String, deselection: (() -> Void)? = nil) {
        self.name = name
        self.deselection = deselection
    }
    
    var body: some View {
        Button(action: { deselection?() }) {
            HStack {
                Text(name)
                Image(systemName: "xmark.circle.fill")
                    .resizable().scaledToFit()
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
            }
        }
        .frame(height: Constants.height)
        .padding(.horizontal, Constants.hPadding)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.height / 2)
                .strokeBorder()
                .foregroundColor(.accentColor)
        )
    }
    
    struct Constants {
        static let iconSize: CGFloat = 18
        static let height: CGFloat = 40
        static let hPadding: CGFloat = 12
    }
    
}

struct InviteSelectedView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Dark
            HStack {
                InviteSelectedView(name: "Bob")
                InviteSelectedView(name: "Mark")
                InviteSelectedView(name: "Tom")
            }
            .padding()
            .background(Color.black)
            .colorScheme(.dark)
            // Light
            HStack {
                InviteSelectedView(name: "Bob")
                InviteSelectedView(name: "Mark")
                InviteSelectedView(name: "Tom")
            }
            .padding()
            .background(Color.white)
            .colorScheme(.light)
        }
        .padding()
        .background(Color.gray)
        .previewLayout(.sizeThatFits)
    }
}
