//
//  SearchClubsView.swift
//  AllGram
//
//  Created by Igor Antonchenko on 31.01.2022.
//

import SwiftUI

struct SearchClubsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var viewModel: SearcherForClubs
    
    var body: some View {
        ZStack {
            // Navigation
            VStack {
                NavigationLink(
                    destination: selectedClubDestination,
                    isActive: $showSelectedClub
                ) {
                    EmptyView()
                }
            }
            // Content
            VStack(spacing: 0) {
                inputField
                searchOutputList
            }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(title: "Search")
        .onAppear {
            viewModel.searchString = ""
        }
        .onChange(of: selectedClubId) { value in
            withAnimation { showSelectedClub = value != nil }
        }
        .onChange(of: showSelectedClub) { value in
            guard !value && selectedClubId != nil else { return }
            selectedClubId = nil
        }
    }
        
    private var inputField: some View {
        HStack {
            Image("search-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
            NMultilineTextField(
                text: $viewModel.searchString,
                lineLimit: 1,
                onCommit: { } // Use 'done' button to hide keyboard
            ) {
                NMultilineTextFieldPlaceholder(text: "Search")
            }
            Button(action: {
                withAnimation {
                    viewModel.searchString = ""
                }
            }) {
                Image("times-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical)
        .accentColor(.reverseColor)
    }
    
    @State private var joiningIds = [String]()
    
    private func joinState(for info: ClubInfo) -> SearchClubItemView.JoinState {
        if info.isMember == true {
            return .joined
        } else if joiningIds.contains(info.roomId) {
            return .joining
        } else {
            return .notJoined
        }
    }
    
    private var searchOutputList: some View {
        VStack {
            if viewModel.isBusy {
                Spacer()
                ProgressView()
                    .scaleEffect(2.0)
                Spacer()
            } else if !viewModel.searchResult.isEmpty {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.searchResult, id: \.id) { info in
                            SearchClubItemView(
                                joinState(for: info),
                                clubName: info.name,
                                avatarURL: info.avatarURL
                            ) { state in
                                switch state {
                                case .notJoined:
                                    joiningIds.append(info.roomId)
                                    viewModel.joinClub(info) { _ in
                                        if let i = joiningIds.firstIndex(of: info.roomId) {
                                            joiningIds.remove(at: i)
                                        }
                                    }
                                case .joining:
                                    break
                                case .joined:
                                    selectedClubId = info.roomId
                                }
                            }
                            .background(
                                Color.green.opacity(0.001)
                                    .onTapGesture {
                                        if info.isMember == true {
                                            selectedClubId = info.roomId
                                        }
                                    }
                            )
                            .padding(.horizontal, 18)
                            Divider()
                        }
                    }
                }
            } else {
                Text(!viewModel.searchString.isEmpty
                     ? "No results"
                     : "Fill out search field")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                Spacer()
            }
        }
        .onAppear {
            viewModel.resetSearch()
        }
    }
    
    // MARK: - Handle Selected Club
    
    @State private var selectedClubId: String?
    @State private var showSelectedClub = false
    
    private var selectedClubDestination: some View {
        ZStack {
            if let clubRoom = viewModel.getAllgramRoom(for: selectedClubId) {
                NewClubFeedView(room: clubRoom)
            } else {
                Text("No room for club")
                    .onAppear {
                        selectedClubId = nil
                    }
            }
        }
    }
        
}

//struct SearchClubsView_Previews: PreviewProvider {
//    static var previews: some View {
//        
//        Group {
//            SearchClubsView()
//                .colorScheme(.light)
//                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
//            SearchClubsView()
//                .colorScheme(.dark)
//                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
//        }
//    }
//}
