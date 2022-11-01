//
//  NewInviteView.swift
//  AllGram
//
//  Created by Alex Pirog on 11.02.2022.
//

import SwiftUI

struct NewInviteView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject var viewModel: InviteUserViewModel
    
    var headerOfView: String = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                selectedStack
                inputField
                searchOutputList
            }
            .disabled(viewModel.processingState == .inviting)
            if viewModel.processingState == .inviting { loadingAlert }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            leading:
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text(headerOfView).bold()
                }
            ,
            trailing:
                Button(action: { viewModel.inviteSelected() }) {
                    Text("INVITE")
                }
                .disabled(viewModel.selectedToInvite.isEmpty || viewModel.processingState == .inviting)
                .opacity(viewModel.selectedToInvite.isEmpty ? 0.5 : 1)
        )
        .onChange(of: viewModel.processingState) { newValue in
            if newValue == .none { //.timeoutOfDisplayingSuccess {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // MARK: - Body Parts
    
    private var selectedStack: some View {
        Group {
            if viewModel.allSelected.isEmpty {
                Text("No one selected yet...")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(viewModel.allSelected, id: \.id) { info in
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
                    Text("Users found:")
                    Spacer()
                }
                .padding(.horizontal)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResultWithoutSelf, id: \.id) { info in
                            VStack(spacing: 0) {
                                InviteSearchItemView(info: info) {
                                    withAnimation {
                                        viewModel.selectForInvite(info)
                                    }
                                }
                                .padding(.vertical, 6)
                                .accentColor(.reverseColor)
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
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
    
    private var loadingAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: .constant(true)) {
            LoaderAlertView(title: "Inviting...", subtitle: nil, shown: .constant(true))
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let topPadding: CGFloat = 36
        static let avatarSize: CGFloat = 180
    }
    
}

//struct NewInviteView_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            NewInviteView()
//                .navigationTitle("Invite Nav Title")
//        }
//        .colorScheme(.dark)
//        .previewDevice("iPhone 11")
//        NewInviteView()
//            .background(Color.white)
//            .colorScheme(.light)
//            .previewDevice("iPhone 8 Plus")
//    }
//}

