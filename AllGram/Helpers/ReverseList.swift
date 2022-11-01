import SwiftUI

struct IsVisibleKey: PreferenceKey {
    static var defaultValue: Bool = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

struct ReverseList<Element, Content>: View where Element: Identifiable, Content: View {
    private let items: [Element]
    private let viewForItem: (Element) -> Content

    @Binding var hasReachedTop: Bool
    let expectMore: Bool
    let spacing: CGFloat? // Used in LazyVStack
    let animateScrolling: Bool
    
    // Used to scroll to specific element, but lazy stack
    // blocks scrolling to near off-screen elements...
    @Binding var scrollToId: ObjectIdentifier?
    
    // Used to track what items appeared (on screen on near)
    @State private var bottomItemIndex: Int?
    @State private var topItemIndex: Int?
    
    // Toggle to scroll to bottom
    @Binding var scrollToBottom: Bool
    private let bottomScrollId = "BOTTOM_SCROLL"
    
    // Toggle to scroll to top
    @Binding var scrollToTop: Bool
    private let topScrollId = "TOP_SCROLL"

    init(
        _ items: [Element],
        hasReachedTop: Binding<Bool>,
        expectMore: Bool,
        scrollToId: Binding<ObjectIdentifier?> = .constant(nil),
        scrollToBottom: Binding<Bool> = .constant(false),
        scrollToTop: Binding<Bool> = .constant(false),
        animateScrolling: Bool = true,
        spacing: CGFloat? = nil,
        viewForItem: @escaping (Element) -> Content
    ) {
        self.items = items.reversed()
        self._hasReachedTop = hasReachedTop
        self.expectMore = expectMore
        self._scrollToId = scrollToId
        self._scrollToBottom = scrollToBottom
        self._scrollToTop = scrollToTop
        self.animateScrolling = animateScrolling
        self.spacing = spacing
        self.viewForItem = viewForItem
    }

    var body: some View {
        GeometryReader { contentsGeometry in
            ZStack {
                // Scrollable content
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 100, height: 1)
                            .id(bottomScrollId)
                        LazyVStack(spacing: spacing) {
                            ForEach(items) { item in
                                self.viewForItem(item)
                                    .scaleEffect(x: -1.0, y: 1.0)
                                    .rotationEffect(.degrees(180))
                                    .id(item.id)
                                    .onAppear {
                                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                                            // Bottom, closer to `bottomScrollId`
                                            // Downward, index -> zero
                                            if let oldBottom = bottomItemIndex {
                                                if oldBottom > index {
                                                    bottomItemIndex = index
                                                }
                                            } else {
                                                bottomItemIndex = index
                                            }
                                            // Top, closer to `topScrollId`
                                            // Upward, index -> count
                                            if let oldTop = topItemIndex {
                                                if oldTop < index {
                                                    topItemIndex = index
                                                }
                                            } else {
                                                topItemIndex = index
                                            }
                                        }
                                    }
                                    .onDisappear {
                                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                                            // Bottom, closer to `bottomScrollId`
                                            if bottomItemIndex == index {
                                                bottomItemIndex = index + 1
                                            }
                                            // Top, closer to `topScrollId`
                                            if topItemIndex == index {
                                                topItemIndex = index - 1
                                            }
                                        }
                                    }
                            }
                            if expectMore {
                                GeometryReader { topViewGeometry in
                                    let progressPositionY = topViewGeometry.frame(in: .global).minY
                                    let scrollViewFrame = contentsGeometry.frame(in: .global)
                                    let isVisible = (progressPositionY > scrollViewFrame.minY)
                                    HStack {
                                        Spacer()
                                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                                        Spacer()
                                    }
                                    .preference(key: IsVisibleKey.self, value: isVisible)
                                }
                                // FIXME: Frame height shouldn't be hard-coded
                                .frame(height: 40)
                                .onPreferenceChange(IsVisibleKey.self) {
                                    hasReachedTop = (expectMore && $0)
                                }
                            }
                        }
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 100, height: 1)
                            .id(topScrollId)
                    }
                    .scaleEffect(x: -1.0, y: 1.0)
                    .rotationEffect(.degrees(180))
                    .onChange(of: scrollToId) { value in
                        guard let id = value else { return }
                        lazyScroll(proxy, to: id)
                    }
                    .onChange(of: scrollToBottom) { value in
                        scroll(proxy, to: bottomScrollId)
                    }
                    .onChange(of: scrollToTop) { value in
                        scroll(proxy, to: topScrollId)
                    }
//                    .onChange(of: topItemIndex) { _ in
//                        guard let top = topItemIndex, let bot = bottomItemIndex else { return }
//                        print("[P] items: \(items.count) | on screen \(bot) - \(top)")
//                    }
//                    .onChange(of: bottomItemIndex) { _ in
//                        guard let top = topItemIndex, let bot = bottomItemIndex else { return }
//                        print("[P] items: \(items.count) | on screen \(bot) - \(top)")
//                    }
                }
                if isLazyScrolling {
                    Rectangle()
                        .foregroundColor(.reverseColor.opacity(0.15))
                        .overlay(
                            Spinner().scaleEffect(2)
                        )
                }
            }
        }
    }
    
    @State private var isLazyScrolling = false
    
    private func lazyScroll(_ proxy: ScrollViewProxy, to id: ObjectIdentifier) {
        let allIds = items.map { $0.id as! ObjectIdentifier }
        guard let topIndex = topItemIndex,
              let bottomIndex = bottomItemIndex,
              let requestedIndex = allIds.firstIndex(of: id)
        else { return }
        withAnimation { isLazyScrolling = true }
        if requestedIndex < bottomIndex {
            // Not on screen, requested id is upwards
            // Do small scroll and try again after short delay
            //print("[P] lazy scroll - delay to last (top)")
            scroll(proxy, to: allIds[bottomIndex - 1], anchor: .bottom)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                lazyScroll(proxy, to: id)
            }
        } else if requestedIndex > topIndex {
            // Not on screen, requested id is upwards
            // Do small scroll and try again after short delay
            //print("[P] lazy scroll - delay to last (top)")
            scroll(proxy, to: allIds[topIndex + 1], anchor: .top)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                lazyScroll(proxy, to: id)
            }
        } else {
            // On screen on near, so just scroll to it
            //print("[P] lazy scroll - done (center)")
            scroll(proxy, to: id, anchor: .center)
            withAnimation { isLazyScrolling = false }
        }
    }
    
    private func scroll(_ proxy: ScrollViewProxy, to id: ObjectIdentifier, anchor: UnitPoint? = nil) {
        if animateScrolling {
            withAnimation { proxy.scrollTo(id, anchor: anchor) }
        } else {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
    
    private func scroll(_ proxy: ScrollViewProxy, to id: String, anchor: UnitPoint? = nil) {
        if animateScrolling {
            withAnimation { proxy.scrollTo(id, anchor: anchor) }
        } else {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}

struct ReverseList_Previews: PreviewProvider {
    static var previews: some View {
        ReverseList(["1", "2", "3"], hasReachedTop: .constant(false), expectMore: true) {
            Text($0)
        }
    }
}
