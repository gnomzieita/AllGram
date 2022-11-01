//
//  SearchChatView.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 01.02.2022.
//

import SwiftUI

struct SearchChatView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    @State private var searchString: String = ""
    @State private var selectedRoomId: String?
    @State var isRoomSelected: Bool = false
    
    private var filteredRooms: [AllgramRoom] {
        let trimmedSearchString = searchString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearchString.isEmpty {
            return []
        }
        return authViewModel.sessionVM?.chatRooms.filter({ $0.summary.displayname?.contains(trimmedSearchString) ?? false }) ?? []
    }
    
    @State private var isResponding = true
    
    var body: some View {
        ZStack {
            // Navigation
            NavigationLink(isActive: $isRoomSelected) {
                VStack {
                    if let room = filteredRooms.first { $0.roomId == selectedRoomId } {
                        ChatContainerView(room: room) {
                            selectedRoomId = nil
                        }
                    } else {
                        EmptyView()
                            .onAppear {
                                selectedRoomId = nil
                            }
                    }
                }
            } label: {
                EmptyView()
            }
            // Content
            VStack {
                HStack {
                    Image("search-solid")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
//                    TextField("Search here", text: $searchString)
//                        .autocapitalization(.none)
//                        .disableAutocorrection(true)
                    NMultilineTextField(
                        text: $searchString,
                        lineLimit: 1,
                        onCommit: { } // Use 'done' button to hide keyboard
                    ) {
                        NMultilineTextFieldPlaceholder(text: "Search here")
                    }
                }
                .padding()
                List {
                    if filteredRooms.isEmpty {
                        Text("No results")
                        Spacer()
                    } else {
                        ForEach(filteredRooms) { room in
                            ZStack {
                                ChatsItemContainerView(room: room, highlighted: false)
                                // Almost transparent color to handle tap/press
                                // Need this to intercept gestures over the whole row
                                Color.green.opacity(0.0001)
                                    .onTapGesture {
                                        withAnimation { selectedRoomId = room.roomId }
                                    }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        }
                    }
                }
                .padding(.top, 1)
                .listStyle(.sidebar)
            }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(title: "Search")
        .onChange(of: selectedRoomId) { newValue in
            isRoomSelected = newValue != nil
        }
    }
}

struct SearchChatView_Previews: PreviewProvider {
    static var previews: some View {
        SearchChatView(isRoomSelected: false)
    }
}
