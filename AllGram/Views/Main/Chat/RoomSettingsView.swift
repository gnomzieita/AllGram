//
//  RoomSettingsView.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 08.02.2022.
//

import SwiftUI
import Kingfisher
import MatrixSDK
import AVKit

struct RoomSettingsView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    @ObservedObject var room: AllgramRoom
    @StateObject var roomMembersVM: RoomMembersViewModel
    
    @State var isAdmin = false
    
    @State var newAvatar: UIImage?
    @State var name = ""
    @State var topic = ""
    @State var description = ""
    @State private var presentingToast: Bool = false
    let prohibitedSymbols = ["/",":","*","?",">","<","|","\u{005c}","\u{201d}"] // 005c - \ , 201d - "
    
    init(room: AllgramRoom) {
        self.room = room
        self._roomMembersVM = StateObject(wrappedValue: RoomMembersViewModel(room: room))
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        // Top part
                        ZStack {
                            // Avatar image
                            VStack {
                                if let new = newAvatar {
                                    Image(uiImage: new)
                                        .resizable()
                                } else {
                                    KFImage(room.realAvatarURL)
                                        .resizable().scaledToFill()
                                        .frame(width: geometry.size.width,
                                               height: geometry.size.width)
                                        .clipped()
                                        .placeholder(when: true) { ProgressView().scaleEffect(2)
                                        }
                                        .overlay(
                                            prefixAvatar
                                                .opacity(room.realAvatarURL == nil ? 1 : 0)
                                        )
                                }
                            }
                            .onTapGesture {
                                showAttachmentPicker = true
                            }
                            // Clear avatar button
                            VStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        newAvatar = nil
                                    } label: {
                                        Image("times-solid")
                                            .resizable().scaledToFit()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(.black)
                                            .padding(.all, 4)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                    .opacity(newAvatar != nil ? 1 : 0)
                                    .disabled(newAvatar == nil)
                                }
                                Spacer()
                            }
                            .padding()
                            // Users button
                            VStack {
                                Spacer()
                                HStack {
                                    NavigationLink(destination: RoomUsersView(room: self.room)) {
                                        Text("Users: \(room.summary.membersCount.members)")
                                            .foregroundColor(.black)
                                            .padding(5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    Spacer()
                                }
                            }
                            .padding()
                        }
                        .frame(width: geometry.size.width,
                               height: geometry.size.width)
                        // Native selecting tabs
                        Picker("Select Tab", selection: $selectedTab) {
                            ForEach(Tabs.allCases, id: \.self) {
                                Text($0.rawValue.uppercased())
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        // Tab content
                        tabContentView(with: geometry)
                        Spacer()
                    }
                }
            }
            if showingInfo { infoAlert }
        }
        .background(Color("bgColor").ignoresSafeArea())
        .onAppear {
            self.name = room.displayName ?? ""
            self.topic = room.topic ?? ""
            self.description = room.clubDescription ?? ""
            
            // Check if user is ADMIN
            if let me = roomMembersVM.member(with: authViewModel.sessionVM!.myUserId) {
                self.isAdmin = me.powerLevel == .admin
            } else {
                roomMembersVM.loadMembers()
            }
        }
        .actionSheet(isPresented: $showAttachmentPicker) {
            ActionSheet(
                title: Text("Send Media"),
                buttons: pickerOptions
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                sourceType: imagePickerSource,
                restrictToImagesOnly: true,
                onImagePicked: { image in
                    newAvatar = image
                }
            )
        }
        .onChange(of: showImagePicker) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(
            leading:
                Text("Settings").bold()
            ,
            trailing:
                HStack {
                    Button {
                        // Update needed parameters
                        saveRoomAvatarIfNeeded()
                        saveRoomNameIfNeeded()
                        saveRoomTopicIfNeeded()
                        saveRoomDescriptionIfNeeded()
                    } label: {
                        if isSaving {
                            Spinner(.white)
                        } else {
                            Text("Save")
                        }
                    }
                    .opacity(needsSaving ? 1 : 0)
                    .disabled(isSaving)
                }
        )
        .alert(isPresented: $showPermissionAlert) {
            permissionAlertView
        }
    }
    
    @State private var showPermissionAlert = false
    @State private var permissionAlertText = ""
    
    private var permissionAlertView: Alert {
        return Alert(
            title: Text("Access to \(permissionAlertText)"),
            message: Text("Tap Settings and enable \(permissionAlertText)"),
            primaryButton: .default(
                Text("Settings"),
                action: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            ),
            secondaryButton: .cancel()
        )
    }
    
    // MARK: - Tabs
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private enum Tabs: String, CaseIterable {
        case info, media, files
    }
    
    @State private var selectedTab: Tabs = .info
    
    private func tabContentView(with geometry: GeometryProxy) -> some View {
        VStack {
            switch selectedTab {
            case .info:
                infoTab
                
            case .media:
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(room.events().renderableEvents.reversed().filter { event in
                        event.content(valueFor: "msgtype") == kMXMessageTypeImage
                        || event.content(valueFor: "msgtype") == kMXMessageTypeVideo
                    }) { event in
                        let size = geometry.size.width / CGFloat(columns.count)
                        let attachment = ChatMediaAttachment(event: event)
                        NavigationLink {
                            ChatFullscreenMediaView(attachment: attachment)
                        } label: {
                            RoomMediaView(event: event)
                                .frame(width: size, height: size)
                                .clipped()
                        }
                    }
                }
                
            case .files:
                filesTab
            }
        }
    }
    
    private var infoTab: some View {
        VStack(alignment: .leading) {
            Section {
                TextField("Name", text: self.$name)
                    .padding(6)
                    .textFieldStyle(PlainTextFieldStyle())
                    .toast(message: "Such symbols are not allowed: / : * ? > < | \u{005c} \u{201d}",
                           isShowing: $presentingToast,
                           duration: Toast.long)
                    .onChange(of: name, perform: { newValue in
                        for symbol in prohibitedSymbols {
                            if newValue.contains(symbol) {
                                presentingToast.toggle()
                                var clearString = newValue
                                clearString.remove(at: clearString.index(before: clearString.endIndex))
                                name = clearString
                            }
                        }
                    })
                Divider()
                TextField("Topic(optional)", text: $topic)
                    .padding(6)
                    .textFieldStyle(PlainTextFieldStyle())
                if room.isClub {
                    Divider()
                    TextField("Description(optional)", text: $description)
                        .padding(6)
                        .textFieldStyle(PlainTextFieldStyle())
                }
            }
        }
        .padding()
    }
    
    private var filesTab: some View {
        ForEach(room.events().renderableEvents.reversed().filter { event in
            event.content(valueFor: "msgtype") == kMXMessageTypeFile
        }) { event in
            FileView(event: event) { title, subtitle in
                infoAlertTitle = title
                infoAlertSubtitle = subtitle
                showingInfo = true
            }
        }
    }
    
    // MARK: - Prefix Avatar
    
    private var prefixAvatar: some View {
        GeometryReader { geometry in
            Text(verbatim: name.avatarLetters)
                .font(.system(size: geometry.size.height / 3))
                .lineLimit(1)
                .allowsTightening(true)
                .foregroundColor(.white)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(
                    Color.allgramMain//.overlay(gradient)
                )
        }
    }
    
    private var gradient: LinearGradient {
        let color: Color = .white
        let colors = [color.opacity(0.3), color.opacity(0.0)]
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Image Picker
    
    @State private var showAttachmentPicker = false
    @State private var showImagePicker: Bool = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    
    private var pickerOptions: [ActionSheet.Button] {
        var result = [ActionSheet.Button]()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            result.append(
                .default(
                    Text("Camera"),
                    action: {
                        switch PermissionsManager.shared.getAuthStatusFor(.video) {
                        case .notDetermined: // User has not yet been asked for camera access
                            AVCaptureDevice.requestAccess(for: .video) { response in
                                if response {
                                    imagePickerSource = .camera
                                    showImagePicker = true
                                } else {
                                    permissionAlertText = "camera"
                                    showPermissionAlert = true
                                }
                            }
                        case .authorized:
                            withAnimation {
                                imagePickerSource = .camera
                                showImagePicker = true
                            }
                        default:
                            permissionAlertText = "camera"
                            showPermissionAlert = true
                        }
                    }
                )
            )
        }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            result.append(
                .default(
                    Text("Photo Library"),
                    action: {
                        imagePickerSource = .photoLibrary
                        showImagePicker = true
                    }
                )
            )
        }
        result.append(.cancel())
        return result
    }
    
    // MARK: - Saving Changes
    
    @State private var savingAvatar = false
    @State private var savingName = false
    @State private var savingTopic = false
    @State private var savingDescription = false
    
    /// `true` when in process of saving at least one of the properties
    private var isSaving: Bool {
        savingAvatar || savingName || savingTopic || savingDescription
    }
    
    /// `true` when at least one of the properties needs saving
    private var needsSaving: Bool {
        newAvatar != nil || needNameSave || needTopicSave || needDescriptionSave
    }
    
    private func saveRoomAvatarIfNeeded() {
        guard let image = newAvatar, !savingAvatar else { return }
        guard isAdmin else {
            infoAlertTitle = "Warning"
            infoAlertSubtitle = "Only admins can edit the avatar."
            withAnimation { showingInfo = true }
            return
        }
        savingAvatar = true
        room.uploadImage(image) { data in
            if let uri = data?.uri, let url = URL(string: uri) {
                room.room.setAvatar(url: url) { response in
                    switch response {
                    case .success(()):
                        newAvatar = nil
                    case .failure(_):
                        break
                    }
                    savingAvatar = false
                }
            } else {
                savingAvatar = false
            }
        }
    }
    
    private var needNameSave: Bool {
        self.name != room.summary.displayname && self.name.hasContent
    }
    
    private func saveRoomNameIfNeeded() {
        guard needNameSave && !savingName else { return }
        guard isAdmin else {
            infoAlertTitle = "Warning"
            infoAlertSubtitle = "Only admins can edit the name."
            withAnimation { showingInfo = true }
            return
        }
        savingName = true
        room.room.setName(self.name) { _ in
            savingName = false
        }
        //        room.room.state { roomState in
        //            guard let state = roomState else { return }
        //            if state.name == nil && self.name == room.summary.displayname {
        //                // it is a default name of chat, composed from participant names
        //                // it may appear different from the point of view of different participants
        //                return
        //            }
        //            savingName = true
        //            room.room.setName(self.name) { _ in
        //                savingName = false
        //            }
        //        }
    }
    
    private var needTopicSave: Bool {
        self.topic != room.summary.topic && self.topic.hasContent
    }
    
    private func saveRoomTopicIfNeeded() {
        guard needTopicSave && !savingTopic else { return }
        guard isAdmin else {
            infoAlertTitle = "Warning"
            infoAlertSubtitle = "Only admins can edit the topic."
            withAnimation { showingInfo = true }
            return
        }
        savingTopic = true
        room.room.setTopic(self.topic) { _ in
            savingTopic = false
        }
    }
    
    private var needDescriptionSave: Bool {
        self.description != room.clubDescription && self.description.hasContent
    }
    
    private func saveRoomDescriptionIfNeeded() {
        guard needDescriptionSave && !savingDescription else { return }
        guard isAdmin else {
            infoAlertTitle = "Warning"
            infoAlertSubtitle = "Only admins can edit the description."
            withAnimation { showingInfo = true }
            return
        }
        savingDescription = true
        room.setClubDescription(self.description) { _ in
            savingDescription = false
        }
    }
    
    // MARK: - Alerts
    
    @State var showingInfo = false
    @State var infoAlertTitle = ""
    @State var infoAlertSubtitle = ""
    
    private var infoAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingInfo) {
            InfoAlertView(title: infoAlertTitle, subtitle: infoAlertSubtitle, shown: $showingInfo)
        }
    }
}

struct RoomMediaView: View {
    @StateObject var attachment: ChatMediaAttachment
    
    init(event: MXEvent) {
        self._attachment = StateObject(wrappedValue: ChatMediaAttachment(event: event))
    }
    
    init(attachment: ChatMediaAttachment) {
        self._attachment = StateObject(wrappedValue: attachment)
    }
    
    var body: some View {
        switch attachment.event.messageType! {
        case .image:
            if let data = attachment.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
            }
            
        case .video:
            if let data = attachment.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .overlay(PlayImageOverlay(size: 30))
            } else {
                NewFeedMediaPlaceholder(isBusy: !attachment.isReady)
            }
            
        default:
            NewFeedMediaPlaceholder(isBusy: false)
        }
    }
}
