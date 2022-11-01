//
//  CallsTabView.swift
//  AllGram
//
//  Created by Alex Pirog on 12.07.2022.
//

import SwiftUI
import MatrixSDK

import Combine

struct CallsTabView: View {
    @Environment(\.userId) private var userId
    
    @ObservedObject var navManager = NavigationManager.shared
    
    @EnvironmentObject var sessionVM: SessionViewModel
    
    @StateObject var viewModel = CallHistoryViewModel()
        
    var body: some View {
        ZStack {
            // Actual Tab
            NavigationView {
                ZStack {
                    // Navigation
                    VStack {
                        NavigationLink(
                            destination: chatDestination,
                            isActive: $showChat
                        ) {
                            EmptyView()
                        }
                    }
                    .onChange(of: selectedChatId) { newValue in
                        withAnimation { showChat = newValue != nil }
                    }
                    .onChange(of: showChat) { newValue in
                        if !newValue && selectedChatId != nil {
                            selectedChatId = nil
                        }
                    }
                    // Content (with tab bar)
                    TabContentView() {
                        content
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .ourToolbar(
                        leading:
                            HStack {
                                Button {
                                    withAnimation { navManager.showProfile = true }
                                } label: {
                                    ToolbarImage(.menuBurger)
                                }
                                Text("Calls").bold()
                            }
                        ,
                        trailing:
                            HStack {
                                Menu {
                                    Button {
                                        viewModel.clearHistory()
                                    } label: {
                                        MoreOptionView(flat: "Clear call history", imageName: "broom-solid")
                                    }
                                } label: {
                                    ToolbarImage(.menuDots)
                                }
                            }
                    )
                }
            }
            .navigationViewStyle(.stack)
        }
    }
    
    @State var showToast = false
    
    private var content: some View {
        ExpandingVStack(contentPosition: .middle(topMinLength: 0, bottomMinLength: 0), spacing: 0) {
            if viewModel.isLoading {
                ExpandingHStack {
                    Spinner()
                }
            } else if viewModel.history.isEmpty {
                ExpandingHStack {
                    Text("Call history is empty")
                        .foregroundColor(.gray)
                        .padding()
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.history, id: \.timestamp) { item in
                            itemView(item)
                                .onTapGesture {
                                    if sessionVM.chatRooms.contains(where: { $0.roomId == item.roomId }) {
                                        withAnimation { showToast = false }
                                        selectedChatId = item.roomId
                                    } else {
                                        withAnimation { showToast = true }
                                    }
                                }
                            Divider()
                        }
                    }
                }
                .toast(message: "It's impossible to enter this chat", isShowing: $showToast, duration: Toast.long)
            }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .onAppear {
            viewModel.reload()
        }
    }
    
    private func itemView(_ item: CallHistoryItem) -> CallItemView {
        return CallItemView(
            chatName: item.displayName ?? "Unknown",
            chatAvatar: sessionVM.realUrl(from: item.avatarURI),
            callDate: item.callDate,
            isVideoCall: item.videoCall,
            isIncoming: item.callerId != userId,
            isMissed: item.missed ?? false
        )
    }
    
    // MARK: Handle selected chat
    
    @State private var selectedChatId: String?
    @State private var showChat = false
    
    @ViewBuilder
    private var chatDestination: some View {
        if let id = selectedChatId,
           let room = sessionVM.chatRooms.first(where: { $0.roomId == id })
        {
            ChatContainerView(room: room) {
                selectedChatId = nil
            }
        } else {
            Text("No such room")
                .onAppear {
                    selectedChatId = nil
                }
        }
    }
}
