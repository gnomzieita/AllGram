//
//  UISizes.swift
//  AllGram
//
//  Created by Admin on 18.08.2021.
//

import Foundation
import SwiftUI

//public let floatingPanelHeight: CGFloat = 400

//struct TabBarHeighOffsetViewModifier: ViewModifier {
//    let action: (CGFloat) -> Void
//
//    /// This screenSafeArea helps determine the correct tab bar height depending on device version
//    private let screenSafeArea = (UIApplication.shared.windows.first { $0.isKeyWindow }?.safeAreaInsets.bottom ?? 34)
//
//    func body(content: Content) -> some View {
//        GeometryReader { proxy in
//            content
//                .onAppear {
//                    let offset = proxy.safeAreaInsets.bottom - screenSafeArea
//                    action(offset)
//                }
//                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
//                    let offset = proxy.safeAreaInsets.bottom - screenSafeArea
//                    action(offset)
//                }
//        }
//    }
//}
//
//extension View {
//    func tabBarHeightOffset(perform action: @escaping (CGFloat) -> Void) -> some View {
//        modifier(TabBarHeighOffsetViewModifier(action: action))
//    }
//}

// Helper bridge to UIViewController to access enclosing UITabBarController
// and thus its UITabBar
struct TabBarAccessor: UIViewControllerRepresentable {
    var callback: (UITabBar) -> Void
    private let proxyController = ViewController()

    func makeUIViewController(context: UIViewControllerRepresentableContext<TabBarAccessor>) -> UIViewController {
        proxyController.callback = callback
        return proxyController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<TabBarAccessor>) {
    }

    typealias UIViewControllerType = UIViewController

    private class ViewController: UIViewController {
        var callback: (UITabBar) -> Void = { _ in }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if let tabBar = self.tabBarController {
                self.callback(tabBar.tabBar)
            }
        }
    }
}
