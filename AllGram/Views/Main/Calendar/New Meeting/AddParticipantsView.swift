//
//  AddParticipantsView.swift
//  AllGram
//
//  Created by Eugene Ned on 20.09.2022.
//

import SwiftUI

struct AddParticipantsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var newMeetingVM: NewMeetingViewModel
        
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                searchTopBar
                    .offset(y: showSearchBar ? 0 : -100)
                selectedUsersScrollView
                if showSearchResults {
                    searchResultsView
                } else {
                    Spacer()
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(backImage)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 1, blendDuration: 0.2)) { showSearchBar = true }
        }
        .onTapGesture {
            self.hideKeyboard()
        }
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            leading: Text("Add participants"),
            trailing: applyButton
        )
    }
    
    // MARK: Seacrh results
    
    @State private var showSearchResults = false
    
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            HStack {
                if !newMeetingVM.searchResult.isEmpty {
                    Text("USERS FOUND")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.gray)
                    
                    Spacer()
                    Button{
                        withAnimation { newMeetingVM.users.removeAll() }
                    } label: {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(Color("AccentColor"))
                    }
                }
            }
            .padding([.horizontal, .bottom], Constants.fieldsPadding)
            VStack {
                if newMeetingVM.searchString.isEmpty {
                    Text("Start typing to get results")
                        .foregroundColor(Color.reverseColor)
                        .padding(Constants.fieldsPadding)
                } else if newMeetingVM.searchResult.isEmpty {
                    if newMeetingVM.isBusy {
                        ProgressView()
                            .padding(Constants.fieldsPadding)
                        
                    } else {
                        Text("No user found")
                            .foregroundColor(Color.reverseColor)
                            .padding(Constants.fieldsPadding)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(newMeetingVM.searchResult) { item in
                                userInfoView(item, isItemSelected: newMeetingVM.users.contains(item), isSelecting: true)
                                    .padding(8)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    .onAppear {
                                        newMeetingVM.noteIsVisible(item: item)
                                    }
                                    .onTapGesture {
                                        if let index = newMeetingVM.users.firstIndex(of: item) {
                                            withAnimation { newMeetingVM.users.remove(at: index) }
                                        } else {
                                            withAnimation { newMeetingVM.users.append(item) }
                                        }
                                    }
                                if item != newMeetingVM.searchResult.last {
                                    Divider()
                                }
                            }
                        }
                        .padding(Constants.fieldsPadding)
                        .background(Color("newMeetingBackground"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.reverseColor.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.reverseColor.opacity(0.15), radius: 10)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            .padding([.horizontal, .bottom],Constants.fieldsPadding)
        }
    }
    
    // MAKR: Selected users scroll
    
    @State private var scrolling = false
    
    private var selectedUsersScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(newMeetingVM.users.reversed()) { user in
                    HStack(spacing: 0) {
                        userInfoView(user, isItemSelected: false, isSelecting: false)
                        
                        Button {
                            if let index = newMeetingVM.users.firstIndex(of: user) {
                                withAnimation { newMeetingVM.users.remove(at: index) }
                            }
                        } label: {
                            Image("times-solid")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 18, height: 18)
                                .foregroundColor(Color.reverseColor)
                        }
                    }
                    .padding(8)
                    .background(Color("newMeetingBackground"))
                    .cornerRadius(8)
                    .shadow(color: Color.reverseColor.opacity(0.15), radius: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.reverseColor.opacity(0.12), lineWidth: 1)
                    )
                    .frame(minWidth: 0, maxWidth: UIScreen.main.bounds.width/2)
                }
            }
            .padding(.vertical, Constants.fieldsPadding)
            .padding(.leading, 16)
        }
    }
    
    // MARK: User info row
    
    func userInfoView(_ item: UserInfo, isItemSelected: Bool, isSelecting: Bool) -> some View {
        
        VStack(spacing: 0) {
            HStack {
                if isSelecting {
                    if isItemSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color.allgramMain)
                            .overlay(
                                Image("check-solid")
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.white)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.reverseColor.opacity(0.54), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        //                            .foregroundColor(Color.reverseColor)
                    }
                }
                
                AvatarImageView(item.avatarURL, name: item.displayName)
                    .frame(width: 42, height: 42)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(Color.reverseColor)
                    Text(verbatim: item.userId.dropAllgramSuffix)
                        .font(.subheadline)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
    }
    
    // MARK: Search bar
    
    @State private var showSearchBar = false
    
    private var searchTopBar: some View {
        VStack {
            HStack {
                Image("search-solid")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(Color.reverseColor)
                    .padding([.vertical, .leading], 4)
                TextField("Search by name or ID", text: $newMeetingVM.searchString)
                    .autocapitalization(.none)
                    .tint(Color.reverseColor)
                Button {
                    newMeetingVM.searchString = ""
                } label: {
                    Image("times-circle-solid")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(Color.reverseColor)
                        .padding([.vertical, .trailing], 4)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(Color("newMeetingBackground"))
            )            .cornerRadius(10)
                .padding([.horizontal, .bottom],Constants.fieldsPadding)
        }
        .background(Color.allgramMain)
        .cornerRadius(showSearchBar ? 0 : 10)
        .onDisappear {
            newMeetingVM.searchString = ""
        }
        .onTapGesture {
            withAnimation { showSearchResults = true }
        }
    }
    
    // MARK: Custom navigation elements
    
    private var applyButton : some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("Apply")
                .bold()
                .foregroundColor(.white.opacity(newMeetingVM.users.isEmpty ? 0.38 : 1))
        }
        .disabled(newMeetingVM.users.isEmpty)
    }
    
    // MARK: Adaptive to user settings background image
    
    @ViewBuilder
    private var backImage: some View {
        if SettingsManager.homeBackgroundImageName == nil,
           let customImage = SettingsManager.getSavedHomeBackgroundImage() {
            Image(uiImage: customImage)
                .resizable()
                .edgesIgnoringSafeArea(.bottom)
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        } else {
            Image(SettingsManager.homeBackgroundImageName!)
                .resizable()
                .edgesIgnoringSafeArea(.bottom)
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
    }
    
    // MARK: Constants
    
    struct Constants {
        //        static let cornerRadius: CGFloat = 8
        //        static var sameHeight: CGFloat { OurTextFieldConstants.inputHeight }
        static let fieldsPadding: CGFloat = 16
        //        static let signInButtonsPadding: CGFloat = 4
    }
}
