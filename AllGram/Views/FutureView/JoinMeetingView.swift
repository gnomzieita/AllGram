//
//  JoinMeetingView.swift
//  AllGram
//
//  Created by Ярослав Шерстюк on 14.09.2021.
//

import SwiftUI
import Combine
import MatrixSDK

// Model
struct JoinModel: Identifiable {
    var id = UUID()
    var roomID: ObjectIdentifier?
    var name = ""
    var startTitle = ""
    
}

// ViewModel
class JoinViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    @Published var currentDateTime: Date
    @Published var meetings = [MeetingInfo]()
    @Published var isLoadingMeetings = false
    
    let session: MXSession
    
    init(session: MXSession) {
        self.session = session
        currentDateTime = Date()
        updateMeetings()
        NotificationCenter.default.addObserver(forName: .roomIsMeetingStateChanged, object: nil, queue: .main) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.updateMeetings()
            }
        }
    }
    
    func updateMeetings() {
        let startDate = Calendar.current.startOfDay(for: currentDateTime)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)
        guard let endDate = endDate else {
            withAnimation {
                meetings = []
            }
            return
        }
        guard let accessToken = session.credentials.accessToken else { return }
        isLoadingMeetings = true
        NewApiManager.shared.getMeetings(startDate: startDate, endDate: endDate, accessToken: accessToken)
            .sink { [weak self] completion in

                self?.isLoadingMeetings = false
            } receiveValue: { [weak self] meetings in
                guard let self = self else { return }
                let maxStartDateTime = Calendar.current.date(byAdding: .minute, value: 30, to: self.currentDateTime)
                guard let maxStartDateTime = maxStartDateTime else {
                    self.meetings = []
                    return
                }
                self.meetings = meetings.filter {
                    return $0.startDate <= maxStartDateTime || $0.endDate >= self.currentDateTime
                }
            }.store(in: &cancellables)
    }
}


struct JoinMeetingView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    @ObservedObject var vm: JoinViewModel
    @Environment(\.presentationMode) var presentationMode
    var onNeedOpenRoom: ((_ roomID: String) -> Void)?
    
    init(session: MXSession, onNeedOpenRoom: ((_ roomID: String) -> Void)? = nil) {
        self.vm = JoinViewModel(session: session)
        self.onNeedOpenRoom = onNeedOpenRoom
    }
    
    var body: some View {
        NavigationView {
            VStack{
                if vm.meetings.count == 0 {
                    Text("The meeting list is now empty")
                } else {
                    ScrollView(.vertical) {
                        ForEach(vm.meetings) { meeting in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(meeting.summary)")
                                        .font(.headline)
                                        .fontWeight(.regular)
                                        .foregroundColor(.primary)
                                    Text((vm.currentDateTime > meeting.startDate ? "Meeting started" : "Meeting will start") + " \(Formatter.string(forRelativeDate: meeting.startDate) ?? "")")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button {
                                    if let room = authViewModel.sessionVM?.rooms.first(where: { $0.roomId == meeting.roomID }) {
                                        authViewModel.sessionVM?.join(to: room.room)
                                        presentationMode.projectedValue.wrappedValue.dismiss()
                                        onNeedOpenRoom?(room.room.roomId)
                                    }
                                } label: {
                                    Text("Join")
                                        .frame(height: 28)
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                }
                                .background(Color.allgramMain)
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                }
            }
            .onAppear {
                vm.updateMeetings()
            }
            .navigationBarTitle("Join Meeting", displayMode: .inline)
            .ourToolbar(
                leading:
                    Button(action: {
                        self.presentationMode.projectedValue.wrappedValue.dismiss()
                    }, label: {
                        Text("Cancel")
                    }),
                trailing:
                    HStack {
                        if vm.isLoadingMeetings {
                            ProgressView()
                        }
                    }
            )
        }
    }
}

