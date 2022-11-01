//
//  AddClubView.swift
//  AllGram
//
//  Created by Igor Antonchenko on 02.02.2022.
//

import SwiftUI
import MatrixSDK
import Kingfisher

struct AddClubView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let successHandler: (_ roomId: String) -> Void
    let failureHandler: (_ error: Error) -> Void
    
    @StateObject var newClubViewModel: NewClubViewModel
    
    init(session: MXSession?, successHandler: ((_ roomId: String) -> Void)? = nil, failureHandler: ((_ error: Error) -> Void)? = nil) {
        self.successHandler = successHandler ?? { _ in }
        self.failureHandler = failureHandler ?? { _ in }
        self._newClubViewModel = StateObject(wrappedValue: NewClubViewModel(session: session!))
    }
    
    @State private var clubName: String = ""
    @State private var clubTopic: String = ""
    @State private var clubDescription: String = ""
    @State private var privateClub: Bool = false
    @State private var enableEncryption: Bool = false
    @State private var clubAddress: String = ""
    @State private var validAddress: String = ""
    @State private var showToast: Bool = false
    
    // Only letters, digits and underscores
    private let allowedCharacterSet = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "_"))
    
    var body: some View {
        NavigationView {
        ZStack {
            // Content
            content
            // Custom Alerts
            if showingLoader { loaderAlert }
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            title: "New Club",
            leading:
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                    }
                },
            trailing:
                HStack {
                    Button {
                        withAnimation { showingLoader = true }
                        newClubViewModel.save(
                            roomName: clubName,
                            topic: clubTopic,
                            privateClub: privateClub,
                            encrypted: enableEncryption,
                            roomAliasName: validAddress,
                            roomDescription: clubDescription
                        ) { result in
                            withAnimation { showingLoader = false }
                            switch result {
                            case .success(let id):
                                successHandler(id)
                            case .failure(let error):
                                failureHandler(error)
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        Text("Create")
                    }
                }
        )
        }
    }
    
    private var content: some View {
        Form {
            Section {
                HStack {
                    Image("address-book")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: Constants.iconSize,
                               height: Constants.iconSize)
                    Toggle("Create a private club", isOn: $privateClub.animation())
                        .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                }
                .frame(height: Constants.rowHeight)
            } footer: {
                Text("Only invited users will have access to Private clubs, while Public clubs will be open to anyone who wants to join.")
            }
            if privateClub {
                Section {
                    HStack {
                        Image("lock-solid")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: Constants.iconSize,
                                   height: Constants.iconSize)
                        Toggle("Enable encryption", isOn: $enableEncryption)
                            .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                    }
                    .frame(height: Constants.rowHeight)
                } footer: {
                    Text("Encryption will protect the club's content, but will make it impossible for new members to view content added before they join the club.")
                }
            } else {
                Section {
                    HStack {
                        Text("#").bold()
                        TextField("Club address", text: $clubAddress)
                            .onChange(of: clubAddress) { newValue in
                                let emojilessValue = newValue.replaceEmoji(with: " ")
                                let replacedValue = emojilessValue
                                    .replacingOccurrences(of: " ", with: "_")
                                validAddress = replacedValue
                                    .trimmingCharacters(in: allowedCharacterSet.inverted)
                                guard clubAddress != validAddress else { return }
                                clubAddress = validAddress
                                showToast = validAddress != replacedValue
                            }
                    }
                    .frame(height: Constants.rowHeight)
                } footer: {
                    Text("This address can be used to easily find a public club. It can contain only letters and numbers, all white spaces will be replaced by underscores.")
                        .toast(message: "Only letters and numbers are allowed",
                               isShowing: $showToast,
                               duration: Toast.long)
                }
            }
            Section {
                TextField("Club name", text: $clubName)
                    .frame(height: Constants.rowHeight)
                TextField("Club topic (optional)", text: $clubTopic)
                    .frame(height: Constants.rowHeight)
                TextField("Description (optional)", text: $clubDescription)
                    .frame(height: Constants.rowHeight)
            }
        }
        .onTapGesture { hideKeyboard() }
    }
    
    // MARK: - Loading
    
    @State private var showingLoader = false
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: "Creating new club.", shown: $showingLoader)
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let rowHeight: CGFloat = 36
    }
    
}

//struct AddClubView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            AddClubView()
//                .colorScheme(.light)
//                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
//            AddClubView()
//                .colorScheme(.dark)
//                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
//        }
//    }
//}

