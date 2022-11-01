//
//  FloatingButton.swift
//  AllGram
//
//  Created by Alex Pirog on 15.03.2022.
//

import SwiftUI

/// Used to animate show/hide of the button when dragging
class FloatingButtonController: ObservableObject {
    @Published private(set) var show = false
    
    private var showTimer: Timer?
    
    init() {
        delayOnDrag(seconds: 0.5)
    }
    
    deinit {
        showTimer?.invalidate()
        showTimer = nil
    }
    
    func delayOnDrag(seconds: TimeInterval = 1.0) {
        // Hide only when shown
        if show {
            withAnimation { show = false }
        }
        guard seconds > 0 else {
            // Show right away if hidden and 0 time passed
            if !show {
                withAnimation { show = true }
            }
            return
        }
        // Start timer to show again after delay
        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) {
            [weak self] _ in
            // Show only when still hidden
            if self?.show == false {
                withAnimation { self?.show = true }
            }
        }
        // Tolerance for better performance
        showTimer!.tolerance = seconds / 10
    }
    
}

/// Use inside ZStack to get it in the bottom right corner
struct FloatingButton: View {
    typealias ButtonAction = () -> Void
    
    enum ButtonType {
        case newChat
        case newClub
        case newPost
        case newMeeting
        
        var imageName: String {
            switch self {
            case .newChat: return "comment-medical-solid"
            case .newPost, .newClub: return "plus-solid"
            case .newMeeting: return "calendar-plus-solid"
            }
        }
    }
    
    @ObservedObject private var controller: FloatingButtonController
    
    let type: ButtonType
    let action: ButtonAction
    
    init(type: ButtonType, controller: FloatingButtonController, action: @escaping ButtonAction) {
        self.controller = controller
        self.type = type
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                Spacer()
                if controller.show {
                    Button(action: { action() }) {
                        Image(type.imageName)
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: Constants.imageSize, height: Constants.imageSize)
                            .padding(.all, Constants.imagePadding)
                            .background(Circle().foregroundColor(.pink))
                    }
                    .padding(.all, Constants.buttonPadding)
                    .transition(.scale)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15))
        .onAppear {
            guard !controller.show else { return }
            controller.delayOnDrag(seconds: 0.5)
        }
    }
    
    struct Constants {
        static let imageSize: CGFloat = 28
        static let imagePadding: CGFloat = 12
        static let buttonPadding: CGFloat = 16
    }
    
}

struct NewFloatingButtonOption: Identifiable {
    var id: String { return bubbleText }
    
    let iconName: String
    let bubbleText: String
    let action: () -> Void
}

struct NewFloatingButton: View {
    @ObservedObject private var controller: FloatingButtonController
    
    let showIconName: String
    let hideIconName: String
    let options: [NewFloatingButtonOption]
    let shadowContent: Bool
    let addTabBarPadding: Bool
    
    @State private var showOptions = false
    
    init(controller: FloatingButtonController,
         showOptionsIcon: String = "plus-solid",
         hideOptionsIcon: String = "times-solid",
         options: [NewFloatingButtonOption],
         shadowContent: Bool = false,
         addTabBarPadding: Bool = false
    ) {
        self.controller = controller
        self.showIconName = showOptionsIcon
        self.hideIconName = hideOptionsIcon
        self.options = options
        self.shadowContent = shadowContent
        self.addTabBarPadding = addTabBarPadding
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                Spacer()
                // Do not hide on scroll when showing options
                if controller.show || showOptions {
                    VStack(alignment: .trailing, spacing: 24) {
                        if showOptions {
                            optionsStack
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        mainButton
                    }
                }
            }
        }
        .padding(.all, Constants.generalPadding)
        .padding(.bottom, addTabBarPadding ? TabBarView.Constants.tabBarHeight : 0)
        .background(
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .opacity(showOptions && shadowContent ? 1 : 0)
                .onTapGesture {
                    withAnimation { showOptions = false }
                }
        )
        .animation(.easeInOut(duration: 0.15), value: controller.show)
        .onAppear {
            guard !controller.show else { return }
            controller.delayOnDrag(seconds: 0.5)
        }
    }
    
    private var optionsStack: some View {
        VStack(alignment: .trailing, spacing: 16) {
            ForEach(options.indices) { index in
                Button {
                    options[index].action()
                    withAnimation { showOptions = false }
                } label: {
                    HStack(spacing: 16) {
                        Text(options[index].bubbleText)
                            .font(.subheadline)
                            .foregroundColor(.black)
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .shadow(radius: 2)
                            )
                            .transition(.opacity)
                        Image(options[index].iconName)
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: Constants.optionIconSize, height: Constants.optionIconSize)
                            .padding(.all, Constants.optionIconPadding)
                            .background(Circle().foregroundColor(.pink))
                            .transition(.scale)
                    }
                }
            }
        }
        .padding(.trailing, Constants.optionsStackPadding)
    }
    
    private var mainButton: some View {
        Button {
            withAnimation { showOptions.toggle() }
        } label: {
            Image(showOptions ? hideIconName : showIconName)
                .renderingMode(.template)
                .resizable().scaledToFit()
                .foregroundColor(.white)
                .frame(width: Constants.mainIconSize, height: Constants.mainIconSize)
                .padding(.all, Constants.mainIconPadding)
                .background(Circle().foregroundColor(showOptions ? Color("tappedNewMeetingButton") : .pink))
        }
        .transition(.scale)
    }
    
    struct Constants {
        static let mainIconSize: CGFloat = 24
        static let mainIconPadding: CGFloat = 16
        
        static let optionIconSize: CGFloat = 24
        static let optionIconPadding: CGFloat = 8
        
        static var optionsStackPadding: CGFloat {
            let main = mainIconSize + mainIconPadding * 2
            let option = optionIconSize + optionIconPadding * 2
            return (main - option) / 2
        }
        
        static let generalPadding: CGFloat = 16
    }
}

extension NewFloatingButton {
    init(controller: FloatingButtonController,
         regularMeetingHandler: @escaping () -> Void,
         instantMeetingHandler: @escaping () -> Void
    ) {
        let meetingOptions = [
            NewFloatingButtonOption(iconName: "calendar-day-solid", bubbleText: "Scheduled meeting", action: regularMeetingHandler),
            NewFloatingButtonOption(iconName: "calendar-check-solid", bubbleText: "Instant meeting", action: instantMeetingHandler),
        ]
        self.init(controller: controller, showOptionsIcon: "calendar-plus-solid", hideOptionsIcon: "times-solid", options: meetingOptions, shadowContent: true, addTabBarPadding: true)
    }
    
    init(controller: FloatingButtonController,
         scanQRChatHandler: @escaping () -> Void,
         searchChatHandler: @escaping () -> Void
    ) {
        let meetingOptions = [
            NewFloatingButtonOption(iconName: "qrcode-solid", bubbleText: "Create with Digital ID", action: scanQRChatHandler),
            NewFloatingButtonOption(iconName: "user-friends-solid", bubbleText: "Search user by name or ID", action: searchChatHandler),
        ]
        self.init(controller: controller, showOptionsIcon: "plus-solid", hideOptionsIcon: "times-solid", options: meetingOptions, shadowContent: true, addTabBarPadding: true)
    }
}
