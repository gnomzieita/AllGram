//
//  ToolbarModifier.swift
//  AllGram
//
//  Created by Alex Pirog on 28.06.2022.
//

import SwiftUI

/// Adds provided view as toolbar with `.principal` placement.
/// Also forces `.white` color as foreground and accent
//struct ToolbarModifier<V>: ViewModifier where V: View {
//    let toolbarItem: V
//
//    init(@ViewBuilder toolbarBuilder: () -> V) {
//        self.toolbarItem = toolbarBuilder()
//    }
//
//    func body(content: Content) -> some View {
//        content.toolbar {
//            ToolbarItem(placement: .principal) {
//                toolbarItem
//                    .foregroundColor(.white)
//                    .accentColor(.white)
//            }
//        }
//    }
//}

/// Try to fix out toolbar on iOS 16
struct FixToolbarModifier<L: View, T: View>: ViewModifier {
    let title: String
    let leadingItem: L
    let trailingItem: T
    
    init(title: String, @ViewBuilder leadingBuilder: () -> L, @ViewBuilder trailingBuilder: () -> T) {
        self.title = title
        self.leadingItem = leadingBuilder()
        self.trailingItem = trailingBuilder()
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingItem
                        .foregroundColor(.white)
                        .accentColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingItem
                        .foregroundColor(.white)
                        .accentColor(.white)
                }
            }
            .navigationTitle(title)
    }
}

extension View {
    func ourToolbar<L, T>(title: String, leading: L, trailing: T) -> some View where L: View, T: View {
        self.modifier(
            FixToolbarModifier(
                title: title,
                leadingBuilder: {
                    leading
                },
                trailingBuilder: {
                    trailing
                }
            )
//            ToolbarModifier {
//                HStack(spacing: 0) {
//                    leading
//                    Spacer()
//                    trailing
//                }
//                .overlay(
//                    Text(verbatim: title).bold()
//                )
//            }
        )
    }
    
    func ourToolbar<L, T>(leading: L, trailing: T) -> some View where L: View, T: View {
        self.modifier(
            FixToolbarModifier(
                title: "",
                leadingBuilder: {
                    leading
                },
                trailingBuilder: {
                    trailing
                }
            )
//            ToolbarModifier {
//                HStack(spacing: 0) {
//                    leading
//                    Spacer()
//                    trailing
//                }
//            }
        )
    }
    
    func ourToolbar<L>(leading: L) -> some View where L: View {
        self.modifier(
            FixToolbarModifier(
                title: "",
                leadingBuilder: {
                    leading
                },
                trailingBuilder: {
                    EmptyView()
                }
            )
//            ToolbarModifier {
//                HStack(spacing: 0) {
//                    leading
//                    Spacer()
//                }
//            }
        )
    }
    
    func ourToolbar<T>(trailing: T) -> some View where T: View {
        self.modifier(
            FixToolbarModifier(
                title: "",
                leadingBuilder: {
                    EmptyView()
                },
                trailingBuilder: {
                    trailing
                }
            )
//            ToolbarModifier {
//                HStack(spacing: 0) {
//                    Spacer()
//                    trailing
//                }
//            }
        )
    }
    
    func ourToolbar(title: String) -> some View {
        self.modifier(
            FixToolbarModifier(
                title: title,
                leadingBuilder: {
                    EmptyView()
                },
                trailingBuilder: {
                    EmptyView()
                }
            )
//            ToolbarModifier {
//                HStack(spacing: 0) {
//                    Text(verbatim: title).bold()
//                    Spacer()
//                }
//            }
        )
    }
}

struct ToolbarImage: View {
    let type: ItemType
    
    init(_ type: ItemType) {
        self.type = type
    }
    
    var body: some View {
        switch type {
        case .menuBurger:
            Image("bars-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
        case .search:
            Image("search-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
        case .menuDots:
            Image("ellipsis-v-solid")
                .renderingMode(.template)
                .resizable().scaledToFill() // Fill
                .frame(width: 24, height: 24)
        case .videoCall:
            Image("video-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
        case .regularCall:
            Image("phone-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
        }
    }
    
    enum ItemType {
        case menuBurger
        case search
        case menuDots
        case videoCall
        case regularCall
    }
}
