//
//  MyClubsView.swift
//  AllGram
//
//  Created by Igor Antonchenko on 03.02.2022.
//

import SwiftUI
import Kingfisher
import MapKit

struct MyClubsView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @ObservedObject var viewModel: MyClubsViewModel
    
    @State private var showCreateClub = false
    
    var body: some View {
        ZStack {
            // Navigation
            VStack {
                NavigationLink(
                    destination: createdClubDestination,
                    isActive: $goToCreatedClubFeed
                ) {
                    EmptyView()
                }
            }
            // Content
            ZStack {
                VStack(spacing: 0) {
                    if authViewModel.sessionVM?.clubsCreatedByUser.isEmpty == true {
                        Spacer()
                        Spacer()
                        Spacer()
                        VStack(spacing: 18) {
                            Text("Clubs")
                                .bold()
                                .font(.title)
                            Text("Your clubs will be displayed here.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        Spacer()
                    } else {
                        myClubsList
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .simultaneousGesture(animationGesture)
                // Button over content
                FloatingButton(type: .newClub, controller: animationController) {
                    showCreateClub = true
                }
                .sheet(isPresented: $showCreateClub) {
                    AddClubView(
                        session: authViewModel.session,
                        successHandler: { id in
                            viewModel.getRoomInfo()
                            createdClubRoomId = id
                            goToCreatedClubFeed = true
                        },
                        failureHandler: { error in
                            viewModel.getRoomInfo()
                            failureText = error.localizedDescription
                            showingFailure = true
                        }
                    )
                }
            }
            // Alerts
            if showingFailure { failureAlert }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(title: "My Clubs")
    }
    
    private var myClubsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(authViewModel.sessionVM?.clubsCreatedByUser ?? [], id: \.id) { room in
                    NavigationLink(destination: NewClubFeedView(room: room)) {
                        MyClubItemsView(myClubInfo: MyClubInfo(room: room), createdDate: viewModel.getCreatedDate(roomID: room.summary.roomId))
                    }
                }
            }
        }
        .padding(.top, 1)
    }
    
    // MARK: - Animation Button
    
    /// Controls animation of FloatingButton
    private let animationController = FloatingButtonController()
    
    /// DragGesture for animation FloatingButton on ScrollView dragging
    private var animationGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                animationController.delayOnDrag()
            }
    }
    
    // MARK: - Handle Created Club
    
    @State private var createdClubRoomId: String?
    @State private var goToCreatedClubFeed = false
    
    private var createdClubDestination: some View {
        ZStack {
            if let newId = createdClubRoomId, let room = authViewModel.sessionVM?.clubRooms.first(where: { $0.room.roomId == newId }) {
                NewClubFeedView(room: room)
            } else {
                Text("No such club...")
            }
        }
    }
    
    // MARK: - Failure
    
    @State private var showingFailure = false
    @State private var failureText: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: "Failed to create new club." + (failureText == nil ? "" : "\n\(failureText!)"), shown: $showingFailure)
        }
    }
    
}

//struct MyClubsView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            MyClubsView()
//                .colorScheme(.light)
//                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
//            MyClubsView()
//                .colorScheme(.dark)
//                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
//        }
//    }
//}


