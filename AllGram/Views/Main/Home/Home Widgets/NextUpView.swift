//
//  NextUpView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 17.12.2021.
//

import SwiftUI

// MARK: - Next Up Item

typealias NextUpItem = (text: String, color: Color, onTap: (() -> ())?)

struct NextUpListItemView: View {
    
    let text: String
    let color: Color
    let onTap: (() -> ())?
    
    init(text: String, color: Color, onTap: (() -> ())?) {
        self.text = text
        self.color = color
        self.onTap = onTap
    }
    
    init(_ item: NextUpItem) {
        self.init(text: item.text, color: item.color, onTap: item.onTap)
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 0) {
                Circle()
                    .foregroundColor(color)
                    .frame(width: Constants.circleRadius * 2)
                    .frame(height: Constants.circleRadius * 2)
                Text(text)
                    .lineLimit(1)
                    .foregroundColor(.gray)
                    .font(.system(size: Constants.fontSize))
                    .padding(.horizontal)
                Spacer()
            }
        }
    }
    
    struct Constants {
        static let circleRadius: CGFloat = 4
        static let fontSize: CGFloat = 12
    }
    
}

extension NextUpListItemView: Equatable {
    static func == (lhs: NextUpListItemView, rhs: NextUpListItemView) -> Bool {
        return lhs.text == rhs.text
    }
}

//struct NextUpListItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            NextUpListItemView(text: "Andrew telow", color: .purple, onTap: nil)
//                .preferredColorScheme(.dark)
//                .frame(maxHeight: 30)
//            NextUpListItemView(text: "abarkhatov", color: .yellow, onTap: nil)
//                .preferredColorScheme(.light)
//                .frame(maxHeight: 30)
//        }
//        .previewLayout(.sizeThatFits)
//    }
//}

// MARK: - Next Up List

struct NextUpListView: View {
    
    let title: String
    let items: [NextUpItem]
    let tapHandler: () -> Void
    
    init(title: String, items: [NextUpItem] = [], tapHandler: @escaping () -> Void = {}) {
        self.title = title
        self.items = items
        self.tapHandler = tapHandler
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .foregroundColor(.primary)
                .font(.system(size: Constants.fontSize))
                .padding(.top)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading) {
                    ForEach(items, id: \.text) { item in
                        NextUpListItemView(item)
                            .equatable()
                    }
                    Spacer()
                }
                .padding(.horizontal, Constants.hPadding)
                .padding(.vertical, Constants.vPadding)
            }
        }
        .onTapGesture { tapHandler() }
    }
    
    struct Constants {
        static let fontSize: CGFloat = 14
        static let hPadding: CGFloat = 8
        static let vPadding: CGFloat = 4
    }
    
}

//struct NextUpListView_Previews: PreviewProvider {
//    static var chats: [NextUpItem] = [
//        ("Dick Renner", .purple, nil),
//        ("Team A", .yellow, nil),
//        ("Team B", .yellow, nil),
//        ("Team C", .yellow, nil),
//        ("Mommy", .yellow, nil),
//        ("Daddy", .yellow, nil),
//        ("BFF", .yellow, nil),
//        ("Other BFF", .yellow, nil),
//        ("Who", .yellow, nil)
//    ]
//    static var previews: some View {
//        Group {
//            NextUpListView(title: "Chats", items: chats)
//                .preferredColorScheme(.dark)
//                .frame(width: 200, height: 150)
//            NextUpListView(title: "Clubs", items: [("My Personal Club", .red, nil)])
//                .preferredColorScheme(.light)
//                .frame(width: 200, height: 150)
//        }
//        .previewLayout(.sizeThatFits)
//    }
//}

// MARK: - Next Up Widget

struct NextUpView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    let chats: [NextUpItem]
    let clubs: [NextUpItem]
    
    var tapOnChats: () -> Void
    var tapOnClubs: () -> Void
    
    var body: some View {
        VStack {
            // Widget
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Chats
                    NextUpListView(title: "Chats", items: chats, tapHandler: tapOnChats)
                        .frame(width: geometry.size.width / 2 - Constants.listOffset)
                    // Line
                    Rectangle()
                        .foregroundColor(.gray)
                        .frame(width: Constants.lineWidth)
                        .padding(.vertical, Constants.linePadding)
                    // Clubs
                    NextUpListView(title: "Clubs", items: clubs, tapHandler: tapOnClubs)
                        .frame(width: geometry.size.width / 2 - Constants.listOffset)
                }
                .background(
                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                        .foregroundColor(Color("bgColor"))
                        .shadow(radius: 2)
                )
            }
            // Title
            Text("Next Up")
                .foregroundColor(.white)
                .font(.system(size: Constants.fontSize))
                .shadow(radius: 2)
        }
    }
    
    struct Constants {
        static let cornerRadius: CGFloat = 16
        static let fontSize: CGFloat = 14
        static let lineWidth: CGFloat = 1
        static let linePadding: CGFloat = 8
        static var listOffset: CGFloat {
            return (linePadding + lineWidth) / 2
        }
    }
    
}
