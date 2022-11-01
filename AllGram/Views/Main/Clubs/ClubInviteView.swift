//
//  ClubInviteView.swift
//  AllGram
//
//  Created by Alex Pirog on 27.04.2022.
//

import SwiftUI
import Combine
import MatrixSDK

class ClubInviteViewModel: ObservableObject {
    
    enum State {
        case invited // initial
        case joining, accepted // in process -> done
        case leaving, rejected // in process -> done
        case failed // error
    }
    
    @Published private(set) var state: State = .invited
    
    let room: AllgramRoom
    
    init(room: AllgramRoom) {
        self.room = room
//        if let url = inviteUser?.avatarUrl {
//           // https://allgram.me/_matrix/media/r0/identicon/%40telow01%3Aallgram.me
//           // What to do with identicon?!
//           inviteUserAvatarURL = URL(string: url)
//        }
        updateUserAvatar()
    }
    
    deinit {
        cancellable.removeAll()
        clear()
    }
    
    // MARK: - Avatar Hustle
    
    private var updatingAvatar = false
    private var cancellable = Set<AnyCancellable>()
    
    private func updateUserAvatar() {
        guard let id = inviteUserId ?? room.session.myUserId,
              let token = room.session.credentials.accessToken,
              !updatingAvatar && inviteUserAvatarURL == nil
        else { return }
        updatingAvatar = true
        ApiManager.shared.getUserAvatar(userId: id, accessToken: token)
            .sink { [weak self] uri in
                guard let self = self else { return }
                self.inviteUserAvatarURL = self.room.realUrl(from: uri)
                self.updatingAvatar = false
            }.store(in: &cancellable)
    }
    
    // MARK: - Actions
    
    private var operation: MXHTTPOperation?
    private var timer: Timer?
    private let timerInterval: TimeInterval = 3.0
    
    private func clear() {
        operation?.cancel()
        operation = nil
        timer?.invalidate()
        timer = nil
    }
    
    func accept() {
        guard state == .invited || state == .failed else { return }
        clear()
        state = .joining
        operation = room.room.join() { [weak self] response in
            switch response {
            case .success:
                self?.state = .accepted
            case .failure(let error):
                if error.localizedDescription == "Room already joined" {
                    self?.state = .accepted
                } else {
                    self?.state = .failed
                }
            }
            self?.clear()
        }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: false) {
            [weak self] _ in
            self?.state = .invited
            self?.accept()
        }
        timer!.tolerance = timerInterval / 10
    }
    
    func reject() {
        guard state == .invited || state == .failed else { return }
        clear()
        state = .leaving
        operation = room.room.leave() { [weak self] response in
            switch response {
            case .success:
                self?.state = .rejected
            case .failure(_):
                self?.state = .failed
            }
            self?.clear()
        }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: false) {
            [weak self] _ in
            self?.state = .invited
            self?.reject()
        }
        timer!.tolerance = timerInterval / 10
    }
    
    // MARK: - Invite Info
    
    var isInvited: Bool { room.summary.membership == .invite }
    var inviteUserId: String? { room.invitedByUserId }
    var inviteUser: MXUser? { room.session.user(withUserId: inviteUserId ?? "nil") }
    var inviteUserDisplayname: String? { inviteUser?.displayname ?? inviteUserNickname?.dropPrefix("@") }
    var inviteUserNickname: String? { inviteUserId?.dropAllgramSuffix }
    @Published private(set) var inviteUserAvatarURL: URL?
    
}
    
struct ClubInviteView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var viewModel: ClubInviteViewModel
    
    typealias StateChangeHandler = (ClubInviteViewModel.State) -> Void
    
    let onChange: StateChangeHandler
    
    init(vm: ClubInviteViewModel, onChange: @escaping StateChangeHandler = { _ in }) {
        self.viewModel = vm
        self.onChange = onChange
    }
    
    var body: some View {
        ZStack {
            invite
            if showingLoader { loaderAlert }
            if showingFailure { failureAlert }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .onChange(of: viewModel.state) { state in
            showingLoader = false
            showingFailure = false
            switch state {
            case .joining, .leaving:
                showingLoader = true
            case .failed:
                showingFailure = true
            default:
                break
            }
            onChange(state)
        }
    }
    
    var invite: some View {
        VStack {
            Spacer()
            AvatarImageView(viewModel.inviteUserAvatarURL, name: viewModel.inviteUserDisplayname)
                .frame(width: 120, height: 120)
                .padding(.bottom)
            VStack {
                Text(viewModel.inviteUserDisplayname ?? "Unknown")
                Text(viewModel.inviteUserNickname ?? "@none")
                    .foregroundColor(.gray)
            }
            .padding()
            Text("Sent an invite")
                .foregroundColor(.gray)
            HStack {
                Spacer()
                Button(action: {
                    withAnimation { viewModel.reject() }
                }) {
                    Text("Reject")
                }
                .frame(width: 100)
                Button(action: {
                    withAnimation { viewModel.accept() }
                }) {
                    ZStack{
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.allgramMain)
                        Text("ACCEPT")
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 100)
                Spacer()
            }
            .frame(maxHeight: 30)
            .padding()
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Loading
    
    @State private var showingLoader = false
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: nil, shown: $showingLoader)
        }
    }
    
    // MARK: - Failure
    
    @State private var showingFailure = false
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: nil, shown: $showingFailure)
        }
    }
    
}

extension ClubInviteView: Equatable {
    static func == (lhs: ClubInviteView, rhs: ClubInviteView) -> Bool {
        lhs.viewModel.room.room.roomId == rhs.viewModel.room.room.roomId
    }
}
