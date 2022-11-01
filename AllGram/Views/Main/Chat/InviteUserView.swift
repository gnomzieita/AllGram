//
//  InviteUserView.swift
//  AllGram
//
//  Created by Vladyslav on 23.12.2021.
//

import SwiftUI
import Kingfisher

struct _InviteUserView: View {
    @ObservedObject var model : InviteUserViewModel
    var show : Binding<Bool>
    @State var selectedItemID : String?
    
    @State var editMode = EditMode.active
    
    init(room: AllgramRoom, model: InviteUserViewModel, show: Binding<Bool>) {
        self.model = model //InviteUserViewModel(room: room)
        self.show = show
    }
    
    var body: some View {
        VStack {
            Text(roomTitle())
                .font(.title)
            Spacer()
            
            switch model.processingState {
            case .none:
                searchGroupView
            case .inviting:
                ProgressView()
            case .failed:
                Text("Failed to invite userId: (\(findSelectedItem()?.userId ?? "<unknown>"))")
            case .doneSuccessfully, .timeoutOfDisplayingSuccess:
                Text("Invited user with ID: (\(findSelectedItem()?.userId ?? "<unknown>"))")
            }

            Spacer()
            
            if let item = findSelectedItem() {
                HStack {
                    Text("Selected: ")
                    self.userInfoView(item)
                }
            }
                    
                    
            HStack {
                Button(titleOfCloseButton()) {
                    show.wrappedValue = false
                }
                .frame(width: 100, height: 40, alignment: .center)
                .foregroundColor(Color("ButtonFgColor"))
                .background(Color("ButtonBkColor"))
                .clipShape(Capsule())
                
                if model.processingState == .none || model.processingState == .inviting {
                    EmptyView()
                    
                    Button("Invite") {
                        inviteSelectedUser()
                    }
                    .disabled(checkInviteIsDisabled())
                    .frame(width: 100, height: 40, alignment: .center)
                    .foregroundColor(Color("ButtonFgColor"))
                    .background(Color("ButtonBkColor"))
                    .opacity(Double(opacityOfInviteButton()))
                    .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .onTapGesture {
            endEditing()
        }
        .onAppear {
            model.reset()
        }
        .onDisappear {
            model.stop()
        }
        .onChange(of: model.processingState) { newValue in
            if newValue == .timeoutOfDisplayingSuccess {
                self.show.wrappedValue = false
            }
        }
    }
    
    var searchGroupView : some View {
        VStack {
            HStack {
                Text("Search: ")
                    .padding(.trailing, 20)
                
//                TextField("Search", text: $model.searchString)
//                    .autocapitalization(.none)
//                    .disableAutocorrection(true)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
                NMultilineTextField(
                    text: $model.searchString,
                    lineLimit: 1,
                    onCommit: { } // Use 'done' button to hide keyboard
                ) {
                    NMultilineTextFieldPlaceholder(text: "Search")
                }
            }
            .padding(30)
            
            if !model.searchResult.isEmpty {
                Text("Shown below is display name, and (userID)")
            }
            
            List(selection: $selectedItemID) {
                ForEach(model.searchResult) { item in
                    userInfoView(item)
                        .onAppear {
                            model.noteIsVisible(item: item)
                        }
                }
                if model.isBusy {
                    ProgressView()
                }
            }
            .frame(minWidth: nil, idealWidth: nil, maxWidth: nil, minHeight: 150, idealHeight: nil, maxHeight: nil, alignment: .center)
            .environment(\.editMode, $editMode)
        }
        .onChange(of: model.isBusy) { isBusy in
            if isBusy { return }
            if let oldID = selectedItemID {
                if !model.searchResult.contains(where: { $0.id == oldID }) {
                    selectedItemID = nil
                }
            }
        }
        .onChange(of: model.searchString) { str in
            if str.isEmpty {
                selectedItemID = nil
            }
        }
    }
}

private extension _InviteUserView {
    
    func roomTitle() -> String {
        return "Room: " + model.room.summary.displayname
    }
    
    func titleOfCloseButton() -> String {
        switch model.processingState {
        case .doneSuccessfully: return "Close"
        default: return "Cancel"
        }
    }
    
    func checkInviteIsDisabled() -> Bool {
        if model.processingState == .none, let item = findSelectedItem() {
            return model.isRoomMember(item: item)
        }
        return true
    }
    func opacityOfInviteButton() -> CGFloat {
        return checkInviteIsDisabled() ? 0.5 : 1
    }
    
    func userInfoView(_ item: UserInfo) -> some View {
        HStack {
            if let avatarURL = item.avatarURL {
                AvatarImageView(avatarURL, name: item.displayName)
                    .frame(width: 25, height: 25)
            } else {
                Image(systemName: "person.circle")
                    .frame(width: 25, height: 25)
            }
            
            Text(item.displayName)
            Text("(\(item.shortUserId))")
            if model.isRoomMember(item: item) {
                Text("- room member")
            }
        }
    }
    
    func findSelectedItem() -> UserInfo? {
        return model.findItem(itemId: selectedItemID)
    }
    
    func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
    
    func inviteSelectedUser() {
        guard let item = findSelectedItem() else { return }
        model.inviteNewRoomMember(item: item)
    }
}

//struct InviteUserView_Previews: PreviewProvider {
//    static var previews: some View {
//        InviteUserView()
//    }
//}
