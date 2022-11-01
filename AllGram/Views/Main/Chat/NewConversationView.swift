import SwiftUI
import MatrixSDK
import Kingfisher

enum FocusedFieldNewConversation : Int {
    case searchField, roomNameField
}

struct NewConversationContainerView: View {
    @ObservedObject private var authViewModel = AuthViewModel.shared
    @Binding var createdRoomId: ObjectIdentifier?
    
    var body: some View {
        NewConversationView(createdRoomId: $createdRoomId, session: authViewModel.session)
    }
}

private struct NewConversationView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var editMode = EditMode.inactive
    
    @State var focusIndex : FocusedFieldNewConversation?
    
    @StateObject var newConversationVM: NewConversationViewModel
    
    @Binding var createdRoomId: ObjectIdentifier?
    let session: MXSession
    
    init(createdRoomId: Binding<ObjectIdentifier?>, session: MXSession?) {
        self._createdRoomId = createdRoomId
        self.session = session!
        self._newConversationVM = StateObject(wrappedValue: NewConversationViewModel(session: session!))
    }
    
    private var usersFooter: some View {
        Text("Enter username to search")
    }
    
    private var content: some View {
        VStack {
            Form {
                Section(footer: usersFooter) {
                    HStack {
                        TextField(L10n.NewConversation.usernamePlaceholder,
                                  text: $newConversationVM.searchString)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                            .simultaneousGesture(TapGesture().onEnded {
                                self.focusIndex = .searchField
                                editMode = .inactive
                            } )


                        Button(action: addUser) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(nil == newConversationVM.foundUser)
                    }

                    ScrollView {
                        LazyVStack {
                            ForEach(newConversationVM.searchResult) { item in
                                userInfoView(item)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    .background(bkColor(item: item))
                                    .opacity(newConversationVM.isEligible(itemId: item.id) ? 1 : 0.5)
                                    .onAppear {
                                        newConversationVM.noteIsVisible(item: item)
                                    }
                                    .onTapGesture {
                                        if newConversationVM.isEligible(itemId: item.id) {
                                            if newConversationVM.searchString != item.shortUserId {
                                                newConversationVM.searchString = item.shortUserId
                                            }
                                        }
                                    }
                            }
                            if newConversationVM.isBusy {
                                ProgressView()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .gesture(TapGesture().onEnded({
                    if newConversationVM.isKeyboardShown {
                        hideKeyboard()
                    }
                }), including: .all)

                if newConversationVM.users.count > 1 {
                    VStack {
                        TextField(L10n.NewConversation.roomName, text: $newConversationVM.roomName)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                            .simultaneousGesture(TapGesture().onEnded( { self.focusIndex = .roomNameField } ))

                        Toggle(L10n.NewConversation.publicRoom, isOn: $newConversationVM.isPublic)
                            .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                            .ignoresSafeArea(.keyboard, edges: .all)
                    }
                }


                Section(header:
                            Text("Creating chat with members:")
                            .opacity(newConversationVM.users.isEmpty ? 0 : 1)
                ) {
                    
                        ForEach(newConversationVM.users) { item in
                            userInfoView(item)
                        }
                        .onDelete{ indexSet in
                            newConversationVM.users.remove(atOffsets: indexSet)
                        }
                        .allowsHitTesting(true)
                        .frame(maxHeight: 120)
                }
                .ignoresSafeArea(.keyboard, edges: .all)
            }
            
            if !newConversationVM.isKeyboardShown {
                HStack {
                    Button {
                        newConversationVM.createRoom { id in
                            createdRoomId = id
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        Text(verbatim: L10n.NewConversation.createRoom)
                    }
                    .frame(width: 100, height: 40, alignment: .center)
                    .foregroundColor(Color("ButtonFgColor"))
                    .background(Color("ButtonBkColor"))
                    .clipShape(Capsule())
                    .disabled(newConversationVM.isLackingDataForRoomCreation())
                    .opacity(newConversationVM.isLackingDataForRoomCreation() ? 0.5 : 1)

                    Spacer()
                    ProgressView()
                        .opacity(newConversationVM.isWaiting ? 1.0 : 0.0)
                }
                .padding(20)
                .alert(item: $newConversationVM.errorMessage) { errorMessage in
                    Alert(title: Text(verbatim: L10n.NewConversation.alertFailed),
                          message: Text(errorMessage))
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            content
                .environment(\.editMode, $editMode)
                .onChange(of: newConversationVM.users.count) { count in
                    editMode = count > 1 ? editMode : .inactive
                }
                .disabled(newConversationVM.isWaiting)
                .navigationTitle(newConversationVM.users.count > 1 ? L10n.NewConversation.titleRoom : L10n.NewConversation.titleChat)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.NewConversation.cancel) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
    
    func userInfoView(_ item: UserInfo) -> some View {
        HStack {
            if let avatarURL = item.avatarURL {
                KFImage(avatarURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 25, height: 25)
                    .mask(Circle())
            } else {
                Image(systemName: "person.circle")
                    .frame(width: 25, height: 25)
            }
            
            Text(item.displayName)
            Text("(\(item.shortUserId))")
        }
    }
    
    private func bkColor(item: UserInfo) -> Color {
        if newConversationVM.foundUser?.id == item.id {
            return Color("highlightedBkColor")
        }
        return .clear
    }
    
    private func addUser() {
        newConversationVM.addUser()
        newConversationVM.searchString = ""
        hideKeyboard()
    }
}

struct NewConversationView_Previews: PreviewProvider {
    static var previews: some View {
        NewConversationView(createdRoomId: .constant(nil), session: nil)
            .preferredColorScheme(.light)
    }
}
