//
//  ProxyScrollView.swift
//  AllGram
//
//  Created by Alex Pirog on 29.07.2022.
//

import SwiftUI

struct LazyVScrollList<Element, Content, TOP, BOT>: View where Element: Identifiable & Equatable, Content: View, TOP: View, BOT: View {
    private let items: [Element]
    private let viewForItem: (Element) -> Content
    
    // Out of scrolling, just optional views before and after items
    private let topView: TOP
    private let botView: BOT
    
    // Used to track what items views are in appeared state (on screen or near)
    @State private var topItemIndex: Int?
    @State private var bottomItemIndex: Int?
    
    // Set to scroll to a given element (middle)
    @Binding var scrollToItem: Element?
    
    // Toggle to scroll to the first element (top)
    @Binding var scrollToFirst: Bool
    
    // Toggle to scroll to the last element (bottom)
    @Binding var scrollToLast: Bool
    
    // Configuration
    let showsIndicators: Bool
    let animateScrolling: Bool
    let spacing: CGFloat?
    
    init(
        _ items: [Element],
        scrollToItem: Binding<Element?> = .constant(nil),
        scrollToFirst: Binding<Bool> = .constant(false),
        scrollToLast: Binding<Bool> = .constant(false),
        showsIndicators: Bool = false,
        animateScrolling: Bool = true,
        spacing: CGFloat? = nil,
        viewForItem: @escaping (Element) -> Content,
        @ViewBuilder topViewBuilder: () -> TOP,
        @ViewBuilder botViewBuilder: () -> BOT
    ) {
        self.items = items.reversed()
        self._scrollToItem = scrollToItem
        self._scrollToFirst = scrollToFirst
        self._scrollToLast = scrollToLast
        self.showsIndicators = showsIndicators
        self.animateScrolling = animateScrolling
        self.spacing = spacing
        self.viewForItem = viewForItem
        self.topView = topViewBuilder()
        self.botView = botViewBuilder()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: showsIndicators) {
                topView
                LazyVStack(spacing: spacing) {
                    ForEach(items) { item in
                        self.viewForItem(item)
                            .id(item.id)
                            .onAppear {
                                let index = items.firstIndex(where: { $0.id == item.id })!
                                if let oldTop = topItemIndex {
                                    if oldTop > index {
                                        topItemIndex = index
                                    }
                                } else {
                                    topItemIndex = index
                                }
                                if let oldBottom = bottomItemIndex {
                                    if oldBottom < index {
                                        bottomItemIndex = index
                                    }
                                } else {
                                    bottomItemIndex = index
                                }
                            }
                            .onDisappear {
                                let index = items.firstIndex(where: { $0.id == item.id })!
                                if topItemIndex == index {
                                    topItemIndex = index + 1
                                }
                                if bottomItemIndex == index {
                                    bottomItemIndex = index - 1
                                }
                            }
                    }
                    botView
                }
            }
            .overlay(
                Rectangle()
                    .ignoresSafeArea()
                    .foregroundColor(.reverseColor.opacity(0.2))
                    .overlay(
                        Spinner().scaleEffect(2)
                    )
                    .opacity(isLazyScrolling ? 1 : 0)
            )
            .onChange(of: scrollToItem) { item in
                guard let id = item?.id else { return }
                lazyScroll(proxy, to: id)
            }
            .onChange(of: scrollToFirst) { _ in
                guard let id = items.first?.id else { return }
                lazyScroll(proxy, to: id)
            }
            .onChange(of: scrollToLast) { _ in
                guard let id = items.last?.id else { return }
                lazyScroll(proxy, to: id)
            }
            .onChange(of: topItemIndex) { _ in
                guard let top = topItemIndex, let bot = bottomItemIndex else { return }
                //print("[P] items: 0 - \(items.count - 1) | on screen \(top) - \(bot)")
            }
            .onChange(of: bottomItemIndex) { _ in
                guard let top = topItemIndex, let bot = bottomItemIndex else { return }
                //print("[P] items: 0 - \(items.count - 1) | on screen \(top) - \(bot)")
            }
        }
    }
    
    @State private var isLazyScrolling = false
    
    private func lazyScroll(_ proxy: ScrollViewProxy, to id: Element.ID) {
        let allIds = items.map { $0.id }
        guard let topIndex = topItemIndex,
              let bottomIndex = bottomItemIndex,
              let requestedIndex = allIds.firstIndex(of: id)
        else { return }
        withAnimation { isLazyScrolling = true }
        if requestedIndex > bottomIndex {
            // Not on screen, requested id is downwards
            // Do small scroll and try again after short delay
            scroll(proxy, to: allIds[bottomIndex + 1], anchor: .top)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                lazyScroll(proxy, to: id)
            }
        } else if requestedIndex < topIndex {
            // Not on screen, requested id is upwards
            // Do small scroll and try again after short delay
            scroll(proxy, to: allIds[topIndex - 1], anchor: .bottom)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                lazyScroll(proxy, to: id)
            }
        } else {
            // On screen or near, so just scroll to it
            scroll(proxy, to: id, anchor: .center)
            withAnimation { isLazyScrolling = false }
        }
    }
    
    private func scroll(_ proxy: ScrollViewProxy, to id: Element.ID, anchor: UnitPoint? = nil) {
        if animateScrolling {
            withAnimation { proxy.scrollTo(id, anchor: anchor) }
        } else {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}
