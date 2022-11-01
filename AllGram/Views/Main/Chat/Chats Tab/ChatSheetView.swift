//
//  ChatSheetView.swift
//  AllGram
//
//  Created by Alex Pirog on 23.05.2022.
//

import SwiftUI

/// Shows details of the selected chat event
struct SheetMessageView: View {
    let senderName: String
    let senderURL: URL?
//    let message: String
    let sentDate: Date
    
    var displayDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: sentDate)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            AvatarImageView(senderURL, name: senderName)
                .frame(width: 60, height: 60)
            VStack(alignment: .leading , spacing: 8) {
                Text(verbatim: senderName)
                    .bold()
                    .font(.footnote)
                    .foregroundColor(.reverseColor)
//                HStack(spacing: 0) {
//                    Text(verbatim: message)
//                        .lineLimit(1)
//                        .font(.footnote)
//                    Spacer()
//                }
                HStack(spacing: 0) {
                    Text(verbatim: displayDate)
                        .font(.footnote)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 10)
    }
}

/// Shows a row of fast reaction options for selected chat event
struct SheetReactionsView: View {
    let emoji = ["👍", "👎", "😄", "🎉", "😕", "❤️", "🚀", "👀"]
    let picked: (String) -> Void
    
    var emojiSize: CGFloat {
        UIScreen.main.bounds.width / CGFloat(emoji.count) - 16 // spacing
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                ForEach(emoji, id: \.self) { emoji in
                    Button {
                        picked(emoji)
                    } label: {
                        Text(emoji).font(.system(size: emojiSize))
                    }
                }
            }
            .padding(.vertical, 8)
            Divider()
        }
    }
}

/// Shows action option for selected chat event
struct SheetActionView: View {
    let title: String
    let imageName: String
    let action: () -> Void
    var body: some View {
        HStack {
            Button(action: { action() }) {
                HStack {
                    Image(imageName)
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(8)
                    Text(title)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

/// Shows report options for selected chat event
struct SheetReportView: View {
    @Binding var showOptions: Bool
    let reportSpam: () -> Void
    let reportInappropriate: () -> Void
    let reportCustom: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation { showOptions.toggle() }
                } label: {
                    HStack {
                        Image("flag-solid")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Report content")
                        Image(systemName: showOptions ? "chevron.down" : "chevron.up")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 12, height: 12)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            if showOptions {
                Group {
                    SheetActionView(title: "It's spam", imageName: "flag-solid") {
                        reportSpam()
                    }
                    SheetActionView(title: "It's inappropriate", imageName: "ban-solid") {
                        reportInappropriate()
                    }
                    SheetActionView(title: "Custom report...", imageName: "paper-plane") {
                        reportCustom()
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
}

