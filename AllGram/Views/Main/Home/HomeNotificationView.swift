//
//  HomeNotificationView.swift
//  AllGram
//
//  Created by Alex Pirog on 31.08.2022.
//

import SwiftUI

struct HomeNotificationView: View {
    let avatarURL: URL?
    let displayName: String
    let notificationTitle: String
    let notificationSubtitle: String
    let notificationTime: Date
    let actionTitle: String
    let actionHandler: () -> Void
    let deleteHandler: (() -> Void)?
    
    init(
        avatarURL: URL?,
        displayName: String,
        notificationTitle: String,
        notificationSubtitle: String,
        notificationTime: Date,
        actionTitle: String,
        actionHandler: @escaping () -> Void,
        deleteHandler: (() -> Void)? = nil
    ) {
        self.avatarURL = avatarURL
        self.displayName = displayName
        self.notificationTitle = notificationTitle
        self.notificationSubtitle = notificationSubtitle
        self.notificationTime = notificationTime
        self.actionTitle = actionTitle
        self.actionHandler = actionHandler
        self.deleteHandler = deleteHandler
    }
    
    init(_ item: HomeNotificationItem) {
        self.avatarURL = item.avatarURL
        self.displayName = item.displayName
        self.notificationTitle = item.notificationTitle
        self.notificationSubtitle = item.notificationSubtitle
        self.notificationTime = item.notificationTime
        self.actionTitle = item.actionTitle
        self.actionHandler = item.actionHandler
        self.deleteHandler = item.isDeletable ? item.deleteHandler : nil
    }
    
    @State var swipeOffset: CGFloat = 0
    @State var showDelete = false
    
    var body: some View {
        HStack(spacing: 0) {
            AvatarImageView(avatarURL, name: displayName)
                .frame(width: 30, height: 30)
                .padding(6)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notificationTitle)
                        .font(.headline)
                    Circle()
                        .frame(width: 5, height: 5)
                        .foregroundColor(.gray)
                    Text(Formatter.string(forRelativeDate: notificationTime) ?? "??:??")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(notificationSubtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .lineLimit(1)
            Spacer()
            if showDelete {
                Button {
                    showDelete = false
                    deleteHandler?()
                } label: {
                    Text("Delete").bold()
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(6)
                }
            } else {
                Button {
                    actionHandler()
                } label : {
                    Text(actionTitle)
                        .font(.subheadline)
                        .bold()
                        .padding(6)
                }
            }
        }
        .background(Color.red.opacity(0.001))
        .offset(x: swipeOffset, y: 0)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    guard deleteHandler != nil else { return }
                    if gesture.translation.width <= 0 {
                        swipeOffset = gesture.translation.width
                        if !showDelete && swipeOffset < -60 {
                            withAnimation { showDelete = true }
                        }
                    } else if gesture.translation.width > 0 {
                        swipeOffset = gesture.translation.width
                        if showDelete && swipeOffset > 20 {
                            withAnimation { showDelete = false }
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation { swipeOffset = 0 }
                }
        )
    }
}
