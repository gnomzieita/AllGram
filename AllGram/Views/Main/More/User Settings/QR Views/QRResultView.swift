//
//  QRResultView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 24.12.2021.
//

import SwiftUI
import Combine
import Kingfisher

class CreateChatViewModel: ObservableObject {
    @Published private(set) var isCreating = false
    
    init() { }
    
    deinit {
        cancellables.removeAll()
    }
    
    func createChatRoom(with ids: [String], completion: @escaping (Result<String, Error>) -> ()) {
        guard let accessToken = AuthViewModel.shared.session?.credentials.accessToken
        else {
            // FIXME: use valid error
            completion(.failure(EmailPhoneError.internal))
            return
        }
        ApiManager.shared.createChatRoom(inviteIDs: ids, accessToken: accessToken)
            .sink { result in
                switch result {
                case .finished: break
                case .failure(let error):
                    self.isCreating = false
                    completion(.failure(error))
                }
            } receiveValue: { response in
                NotificationCenter.default.post(name: .userCreatedRoom, object: nil)
                
                self.isCreating = false
                let roomID = response.roomID
                // We are sure this is a chat
                UserDefaults.group.setStoredType(for: roomID, isChat: true, isMeeting: false, forSure: true)
                // Do the update again to ensure correct states
                let newRoom = AuthViewModel.shared.sessionVM?.rooms.first(where: { $0.roomId == roomID })
                newRoom?.checkIsDirectState()
                newRoom?.checkMeetingState()
                completion(.success(roomID))
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}

struct QRResultView: View {
    @ObservedObject var navManager = NavigationManager.shared
    
    @StateObject var viewModel: AnyUserViewModel
    @StateObject var createVM = CreateChatViewModel()
    
    var showAvatarLoading: Bool {
        !(viewModel.displayName != nil || viewModel.avatarURL != nil)
    }
    
    @Binding var show: Bool
    
    init(userId: String, show: Binding<Bool>) {
        self._viewModel = StateObject(wrappedValue: AnyUserViewModel(userId: userId))
        self._show = show
    }
    
    var body: some View {
        VStack(spacing: Constants.verticalSpacing) {
            AvatarImageView(viewModel.avatarURL, name: viewModel.displayName)
                .frame(width: Constants.photoSize, height: Constants.photoSize)
                .overlay(Spinner().opacity(showAvatarLoading ? 1 : 0))
            VStack {
                if viewModel.isLoadingName {
                    HStack(spacing: 0) {
                        Spinner()
                            .scaleEffect(0.75)
                        Text("Loading...")
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(verbatim: viewModel.displayName ?? "Unknown")
                }
                Text(viewModel.userId.dropAllgramSuffix)
                    .foregroundColor(.gray)
            }
            if createVM.isCreating {
                Spinner(.accentColor)
                    .scaleEffect(2)
                    .padding()
            } else {
                Button {
                    createVM.createChatRoom(with: [viewModel.userId]) { result in
                        switch result {
                        case .success(let roomId):
                            withAnimation { show = false }
                            DispatchQueue.main.async {
                                navManager.chatId = roomId
                                navManager.selectedTab = .chats
                            }
                        case .failure(_):
                            break
                        }
                    }
                } label: {
                    HStack {
                        Image("comment-medical-solid")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .foregroundColor(.backColor)
                        Text("START CHATTING")
                            .foregroundColor(.backColor)
                            .padding()
                    }
                    .padding(.horizontal, Constants.buttonPadding)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.buttonCornerRadius)
                            .foregroundColor(.accentColor)
                    )
                }
            }
        }
        .padding(.vertical, Constants.verticalPadding)
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(
            Rectangle()
                .foregroundColor(.backColor)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let photoSize: CGFloat = 60
        static let verticalSpacing: CGFloat = 16
        static let verticalPadding: CGFloat = 36
        static let buttonCornerRadius: CGFloat = 8
        static let buttonPadding: CGFloat = 24
    }
    
}

//struct QRResultView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            ZStack {
//                Rectangle().foregroundColor(.gray)
//                    .ignoresSafeArea()
//                VStack {
//                    Spacer()
//                    QRResultView(displayName: "Alex Boushman", nickname: "@bush", profilePhotoURL: "nil")
//                }
//            }
//            .colorScheme(.dark)
//            ZStack {
//                Rectangle().foregroundColor(.gray)
//                    .ignoresSafeArea()
//                VStack {
//                    Spacer()
//                    QRResultView(displayName: "Alex Boushman", nickname: "@bush", profilePhotoURL: "nil")
//                }
//            }
//            .colorScheme(.light)
//        }
//    }
//}
