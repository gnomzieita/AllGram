//
//  NewStartView.swift
//  AllGram
//
//  Created by Alex Pirog on 14.02.2022.
//

import SwiftUI

struct NewStartView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @StateObject var viewModel = StartChatViewModel(session: AuthViewModel.shared.sessionVM!.session)
    
    @Binding var createdRoomId: String?
    
    init(createdRoomId: Binding<String?>) {
        self._createdRoomId = createdRoomId
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                selectedStack
                inputField
                searchOutputList
            }
            .disabled(viewModel.isCreating)
            if showingLoading { loadingAlert }
            if showingFailure { failureAlert }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            leading:
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    Text("Creating a chat").bold()
                }
            ,
            trailing:
                Button {
                    withAnimation { showingLoading = true }
                    viewModel.createChatRoom() { result in
                        switch result {
                        case .success(let id):
                            // Our is_direct returns wrong result right after
                            // new chat is created, so need to wait and do again
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                if let newRoom = authViewModel.sessionVM?.rooms.first(where: { $0.room.roomId == id }) {
                                    newRoom.checkIsDirectState {
                                        // Update AuthViewModel to get new
                                        // Chats/Clubs rooms separation
                                        authViewModel.sessionVM?.counterOfRoomChanges += 1
                                        presentationMode.wrappedValue.dismiss()
                                        // Also need to wait in order to jump to
                                        // new created chat (without will stuck)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            createdRoomId = id
                                        }
                                    }
                                } else {
                                    withAnimation {
                                        showingLoading = false
                                        failureText = "Missing room by id."
                                        showingFailure = true
                                    }
                                }
                            }
                        case .failure(let error):
                            withAnimation {
                                showingLoading = false
                                failureText = error.localizedDescription
                                showingFailure = true
                            }
                        }
                    }
                } label: {
                    Text("CREATE")
                }
                .disabled(viewModel.selectedToInvite.isEmpty)
                .opacity(viewModel.selectedToInvite.isEmpty ? 0.5 : 1)
        )
    }
    
    // MARK: - Body Parts
    
    private var selectedStack: some View {
        Group {
            if viewModel.selectedToInvite.isEmpty {
                Text("No one selected yet...")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(viewModel.selectedToInvite, id: \.id) { info in
                            InviteSelectedView(name: info.displayName) {
                                withAnimation {
                                    viewModel.deselectFromInvite(info)
                                }
                            }
                            .accentColor(.reverseColor)
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.horizontal, 18)
            }
        }
    }
        
    private var inputField: some View {
        HStack {
            Image("search-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
//            TextField("Search", text: $viewModel.searchString)
//                .autocapitalization(.none)
//                .disableAutocorrection(true)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
            NMultilineTextField(
                text: $viewModel.searchString,
                lineLimit: 1,
                onCommit: { } // Use 'done' button to hide keyboard
            ) {
                NMultilineTextFieldPlaceholder(text: "Search")
            }
            Button(action: { viewModel.searchString = "" }) {
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
    
    private var searchOutputList: some View {
        VStack {
            if viewModel.isBusy {
                Spacer()
                ProgressView()
                    .scaleEffect(2.0)
                Spacer()
            } else if !viewModel.searchResultWithoutSelf.isEmpty {
                HStack {
                    Text("Known Users:")
                    Spacer()
                }
                .padding(.horizontal)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        Divider()
                        ForEach(viewModel.searchResultWithoutSelf, id: \.id) { info in
                            InviteSearchItemView(info: info) {
                                withAnimation {
                                    viewModel.selectForInvite(info)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .accentColor(.reverseColor)
                            Divider()
                        }
                    }
                }
            } else {
                Text(!viewModel.searchString.isEmpty
                     ? "No known users matching this search. Please, try something else."
                     : "Fill out search field")
                    .foregroundColor(.gray)
                Spacer()
            }
        }
    }
    
    // MARK: - Loading Alert
    
    @State private var showingLoading = false
    
    private var loadingAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoading) {
            LoaderAlertView(title: "Creating chat...", subtitle: nil, shown: $showingLoading)
        }
    }
    
    // MARK: - Failure
    
    @State private var showingFailure = false
    @State private var failureText: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: "Failed to create new chat." + (failureText == nil ? "" : "\n\(failureText!)"), shown: $showingFailure)
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let topPadding: CGFloat = 36
        static let avatarSize: CGFloat = 180
    }
    
}

//struct NewStartView_Previews: PreviewProvider {
//    static var previews: some View {
//        NewStartView {
//            NewInviteView()
//                .navigationTitle("Start Nav Title")
//        }
//        .colorScheme(.dark)
//        .previewDevice("iPhone 11")
//        NewStartView()
//            .background(Color.white)
//            .colorScheme(.light)
//            .previewDevice("iPhone 8 Plus")
//    }
//}

