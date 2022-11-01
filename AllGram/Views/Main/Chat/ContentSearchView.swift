//
//  ContentSearchView.swift
//  AllGram
//
//  Created by Alex Pirog on 26.07.2022.
//

import SwiftUI
import MatrixSDK

class ContentSearchViewModel: ObservableObject {
    /// All room message events matching search result.
    /// Events are sorted by timestamp and grouped by title (day of the event timestamp)
    @Published private(set) var searchResult = [String: [MXEvent]]()
    @Published private(set) var isSearching = false
    
    private var lastSearchPattern: String?
    private var searchOperation: MXHTTPOperation?
    private var nextBatch: String = ""
    
    var hasMore: Bool { nextBatch.hasContent }
    
    let room: AllgramRoom
    let roomFilter: MXRoomEventFilter
    
    init(room: AllgramRoom) {
        self.room = room
        let filterDictionary: [AnyHashable : Any] = [
            "rooms": [room.roomId]
        ]
        self.roomFilter = MXRoomEventFilter(dictionary: filterDictionary)
    }
    
    // https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-search
    /// Searches messages with provided pattern in this room
    func search(with pattern: String) {
        guard pattern.hasContent && lastSearchPattern != pattern else { return }
        if let old = searchOperation {
            old.cancel()
        }
        //print("[S] start search with pattern: \(pattern)")
        searchResult.removeAll()
        nextBatch = ""
        isSearching = true
        lastSearchPattern = pattern
        searchOperation = AuthViewModel.shared.client!.searchMessages(withPattern: pattern, roomEventFilter: roomFilter, beforeLimit: 0, afterLimit: 0, nextBatch: "") { [weak self] response in
            switch response {
            case .success(let searchResponse):
                //print("[S] search successful with \(searchResponse.count) results")
                // MXSearchRoomEventResults with an array of
                // MXSearchResult with result as MXEvent
                if let matchedEvents = searchResponse.results?.compactMap({ $0.result }) {
                    //print("[S] searched \(matchedEvents.count) in this room")
                    let today = Date()
                    self?.searchResult = Dictionary(grouping: matchedEvents) { event in
                        let addYear = !event.timestamp.isSameYear(as: today)
                        return event.timestamp.chatBubbleDate(addYear: addYear)
                    }
                }
                self?.nextBatch = searchResponse.nextBatch ?? ""
                self?.isSearching = false
            case .failure(let error):
                if let cancelError = error as? URLError, cancelError.code == .cancelled {
                    // We already handled all other variables on cancel
                    //print("[S] search cancelled")
                } else {
                    //print("[S] search failed with error: \(error)")
                    self?.lastSearchPattern = nil
                    self?.isSearching = false
                }
            }
        }
    }
    
    func stopSearch() {
        searchOperation?.cancel()
        searchResult.removeAll()
        nextBatch = ""
        lastSearchPattern = nil
        isSearching = false
        //print("[S] search stopped")
    }
}

struct ContentSearchItemView: View {
    let avatar: URL?
    let sender: String
    let message: String
    let timestamp: Date
    
    var time: String {
        Formatter.string(for: timestamp, timeStyle: .short)
    }
    
    var body: some View {
        HStack {
            AvatarImageView(avatar, name: sender)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(sender)
                        .bold()
                    Spacer()
                    Text(time)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Text(message)
            }
            .font(.subheadline)
            .lineLimit(1)
        }
    }
}

struct ContentSearchView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @EnvironmentObject var membersVM: RoomMembersViewModel
    
    @ObservedObject var viewModel: ContentSearchViewModel
    
    @Binding var selectedEvent: MXEvent?
    
    init(room: AllgramRoom, selectedEvent: Binding<MXEvent?>) {
        self.viewModel = ContentSearchViewModel(room: room)
        _selectedEvent = selectedEvent
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                inputField
                searchOutput
            }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(title: "Search")
    }
    
    @State private var searchText = ""
    
    private var inputField: some View {
        HStack {
            Image("search-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
            NMultilineTextField(
                text: $searchText,
                lineLimit: 1,
                onCommit: { } // Use 'done' button to hide keyboard
            ) {
                NMultilineTextFieldPlaceholder(text: "Search")
            }
            Button {
                withAnimation {
                    searchText = ""
                    viewModel.stopSearch()
                }
            } label: {
                Image("times-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .accentColor(.reverseColor)
        .onChange(of: searchText) { newValue in
            viewModel.search(with: newValue)
        }
    }
    
    private var searchOutput: some View {
        VStack {
            if viewModel.isSearching {
                Spacer()
                ProgressView()
                    .scaleEffect(2.0)
                Spacer()
            } else if !viewModel.searchResult.isEmpty {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        let sortedKeys = Array(viewModel.searchResult.keys).sorted { lhs, rhs in
                            let left = viewModel.searchResult[lhs]!.first!
                            let right = viewModel.searchResult[rhs]!.first!
                            return left.timestamp > right.timestamp
                        }
                        ForEach(sortedKeys, id: \.self) { key in
                            HStack {
                                Text(key).bold()
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                            ForEach(viewModel.searchResult[key]!, id: \.eventId) { event in
                                let member = membersVM.member(with: event.sender)?.member
                                ContentSearchItemView(
                                    avatar: viewModel.room.realUrl(from: member?.avatarUrl),
                                    sender: member?.displayname ?? event.sender,
                                    message: ChatTextMessageView.Model(event: event).message,
                                    timestamp: event.timestamp
                                )
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedEvent = event
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    }
                                Divider()
                            }
                        }
                        if !viewModel.hasMore {
                            Text("No more results")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
            } else {
                Text(searchText.hasContent ? "No results" : "Fill out search field")
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            }
        }
    }
}
