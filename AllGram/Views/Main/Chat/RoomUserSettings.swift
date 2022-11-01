//
//  RoomUserSettings.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 18.02.2022.
//

import SwiftUI
import Kingfisher

struct RoomUserSettings: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    let room: AllgramRoom
    let hostInfo: MemberInfo?
    let memberInfo: MemberInfo
    
    @State var isUserIgnored = false
    
    init(room: AllgramRoom, host: MemberInfo?, user: MemberInfo) {
        self.room = room
        self.hostInfo = host
        self.memberInfo = user
    }
    
    var roomType: String {
        if room.isClub { return "club" }
        else if room.isChat { return "chat" }
        else { return "room" }
    }
    
    var roleText: String {
        "\(memberInfo.powerLevel.role) in \(room.summary.displayname ?? "Unknown")"
    }
    
    let optionHeight: CGFloat = 42
    
    func sectionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Text(title)
                .foregroundColor(color)
        }
        .frame(height: optionHeight)
    }
    
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .bold()
            .font(.body)
            .foregroundColor(.reverseColor)
    }
        
    var body: some View {
        ZStack {
            VStack {
                VStack(spacing: 8) {
                    AvatarImageView(memberInfo.avatarURL, name: memberInfo.displayname.dropPrefix("@"))
                        .frame(width: 200, height: 200)
                    Text(memberInfo.displayname)
                        .font(.headline)
                    Text(memberInfo.id.dropAllgramSuffix)
                        .font(.subheadline)
                    Text(roleText)
                        .font(.subheadline)
                }
                .padding(.top, 8)
                actionsOnUser
//                ZStack {
//                    //Color.white
//                    VStack(alignment: .leading) {
//                        List {
//                            Text("More")
//                                .bold()
//                            NavigationLink {
//                                Text("destination")
//                            } label: {
//                                Text("Direct message")
//                            }
//
//                            NavigationLink {
//                                Text("destination")
//                            } label: {
//                                Text("Jump to read recipt")
//                            }
//
//                            NavigationLink {
//                                Text("destination")
//                            } label: {
//                                Text("Mention")
//                            }
//
//                            if !(member?.isAdmin ?? false)  {
//                                NavigationLink {
//                                    Text("destination")
//                                } label: {
//                                    Text("Ignore")
//                                        .foregroundColor(.red)
//                                }
//                                .background(Color("glassTint"))
//
//                            }
//                        }
//                        .listStyle(PlainListStyle())
//                        Spacer()
//                    }
//                    .background(Color("bgColor").ignoresSafeArea())
//                    //.padding()
//                }
            }
            if showIgnoreAlert { ignoreAlert }
            if showUnIgnoreAlert { unIgnoreAlert }
            if showSetRoleAlert { setRoleAlert }
            if showConfirmRoleAlert { confirmRoleAlert }
            if showKickAlert { kickAlert }
            if showBanAlert { banAlert }
            if showLoading { loaderAlert }
            if showFailure { failureAlert }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ourToolbar(title: "Settings")
    }
    
    @ViewBuilder
    private var actionsOnUser: some View {
        if let localUser = hostInfo {
            Form {
                // Hide ignore option for now
                Section {
                    sectionButton(isUserIgnored ? "Unignore" : "Ignore", color: .red) {
                        if isUserIgnored {
                            showUnIgnoreAlert = true
                        } else {
                            showIgnoreAlert = true
                        }
                    }
                } header: {
                    sectionHeader("More")
                }
                .onAppear {
                    isUserIgnored = AuthViewModel.shared.session?.isUserIgnored(memberInfo.id) ?? false
                }
                if localUser.hasAdminActions(over: memberInfo) {
                    Section {
                        if localUser.canSetRole(for: memberInfo) {
                            Button {
                                withAnimation { showSetRoleAlert = true }
                            } label: {
                                HStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Role")
                                            .foregroundColor(.reverseColor)
                                        Text(roleText)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image("pen-solid")
                                        .renderingMode(.template)
                                        .resizable().scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(height: optionHeight)
                        }
                        if localUser.canKick(memberInfo) {
                            sectionButton("Kick", color: .red) {
                                showKickAlert = true
                            }
                        }
                        if localUser.canBan(memberInfo) {
                            sectionButton("Ban", color: .red) {
                                showBanAlert = true
                            }
                        }
                    } header: {
                        sectionHeader("Admin Actions")
                    }
                }
            }
            .background(Color.moreBackColor.ignoresSafeArea())
        } else {
            Spacer()
            Text("You are not a member of this \(roomType)")
                .font(.footnote)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    // MARK: Loading
    
    @State private var showLoading = false
    @State private var loadingHint: String?
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: .constant(true)) {
            LoaderAlertView(title: "Loading...", subtitle: loadingHint, shown: .constant(true))
        }
    }
    
    // MARK: - Failure
    
    @State private var showFailure = false
    @State private var failureHint: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showFailure) {
            InfoAlertView(title: "Ops!", subtitle: failureHint, shown: $showFailure)
        }
    }
    
    // MARK: - Custom Alerts
    
    @State private var showIgnoreAlert = false
    @State private var showUnIgnoreAlert = false
    @State private var showSetRoleAlert = false
    @State private var showConfirmRoleAlert = false
    @State private var showKickAlert = false
    @State private var showBanAlert = false
    
    private var ignoreAlert: some View {
        ActionAlert(showAlert: $showIgnoreAlert, title: "Ignore User", text: "Ignoring this user will remove their messages from all chats and clubs you share. You can reverse this action at any time in the general settings.", actionTitle: "Ignore") {
            loadingHint = "Ignoring user"
            showLoading = true
            IgnoringUsersViewModel.shared.ignoreUser(userId: memberInfo.id) { response in
                switch response {
                case .success:
                    isUserIgnored = true
                    showLoading = false
                case .failure(let error):
                    showLoading = false
                    print("Ignoring user error: \(error)")
                }
            }
        }
    }
    
    private var unIgnoreAlert: some View {
        ActionAlert(showAlert: $showUnIgnoreAlert, title: "Unignore User", text: "Show all messages from \(memberInfo.displayname)?", actionTitle: "Unignore") {
            loadingHint = "Unignoring user"
            showLoading = true
            IgnoringUsersViewModel.shared.unIgnoreUser(userId: memberInfo.id) { response in
                switch response {
                case .success:
                    isUserIgnored = false
                    showLoading = false
                case .failure(let error):
                    showLoading = false
                    print("Unignoring user error: \(error)")
                }
            }
        }
    }
    
    private var setRoleAlert: some View {
        RolePickerAlert(showAlert: $showSetRoleAlert, currentRole: memberInfo.powerLevel) { level in
            if hostInfo?.powerLevel == level {
                // Same power level -> need warning (admins)
                withAnimation { showConfirmRoleAlert = true }
            } else {
                // All good -> proceed without warning
                initiateSetRole(for: level)
            }
        }
    }
    
    private var confirmRoleAlert: some View {
        ActionAlert(showAlert: $showConfirmRoleAlert, title: "Set Role", text: "You will not able to undo this change as you are promoting the user to have the same power level as yourself. Are you sure?", actionTitle: "Confirm") {
            initiateSetRole(for: hostInfo!.powerLevel)
        }
    }
    
    private func initiateSetRole(for level: PowerLevel) {
        loadingHint = "Setting new role for user in this \(roomType)."
        withAnimation { showLoading = true }
        room.room.setPowerLevel(ofUser: memberInfo.id, powerLevel: hostInfo!.powerLevel.power) { response in
            withAnimation { showLoading = false }
            switch response {
            case .success():
                break
            case .failure(let error):
                failureHint = "Failed to set role.\n\(error.localizedDescription)"
                withAnimation { showFailure = true }
            }
        }
    }
    
    private var kickAlert: some View {
        ReasonAlert(showAlert: $showKickAlert, title: "Kick User", text: "Kicking user will remove them from this \(roomType). To prevent them from joining again, you should ban them instead.", actionTitle: "Kick") { reason in
            loadingHint = "Kicking user from this \(roomType)."
            withAnimation { showLoading = true }
            room.room.kickUser(memberInfo.id, reason: reason) { response in
                withAnimation { showLoading = false }
                switch response {
                case .success():
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    failureHint = "Failed to kick user.\n\(error.localizedDescription)"
                    withAnimation { showFailure = true }
                }
            }
        }
    }
    
    private var banAlert: some View {
        ReasonAlert(showAlert: $showBanAlert, title: "Ban User", text: "Banning user will kick them from this \(roomType) and prevent from joining again.", actionTitle: "Ban") { reason in
            loadingHint = "Banning user from this \(roomType)."
            withAnimation { showLoading = true }
            room.room.banUser(memberInfo.id, reason: reason) { response in
                withAnimation { showLoading = false }
                switch response {
                case .success():
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    failureHint = "Failed to ban user.\n\(error.localizedDescription)"
                    withAnimation { showFailure = true }
                }
            }
        }
    }
}

struct RolePickerAlert: View {
    @Binding var showAlert: Bool
    let allowTapDismiss: Bool
    let roles: [PowerLevel]
    let actionHandler: (PowerLevel) -> Void
    
    @State var selectedPower: Int
    
    init(showAlert: Binding<Bool>, allowTapDismiss: Bool = true, currentRole: PowerLevel, roles: [PowerLevel] = [.admin, .moderator, .user], actionHandler: @escaping (PowerLevel) -> Void) {
        self._showAlert = showAlert
        self.allowTapDismiss = allowTapDismiss
        self.roles = roles
        self.actionHandler = actionHandler
        self.selectedPower = currentRole.power
    }
    
    var body: some View {
        CustomAlertContainerView(allowTapDismiss: allowTapDismiss, shown: $showAlert) {
            VStack {
                Text("Set Role")
                    .font(.title)
                    .padding(.vertical, 6)
                pickerView
                    .padding(.bottom, 4)
                Divider()
                HStack(spacing: 0) {
                    Button {
                        withAnimation { showAlert = false }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text("Cancel").bold()
                                .foregroundColor(.accentColor)
                        }
                    }
                    Divider()
                    Button {
                        actionHandler(PowerLevel(power: selectedPower))
                        withAnimation { showAlert = false }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text("Apply").bold()
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(height: 32)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(.backColor)
            )
        }
    }
    
    @ViewBuilder
    private var pickerView: some View {
        VStack(spacing: 0) {
            ForEach(roles.map { $0.power }, id: \.self) { item in
                HStack(spacing: 0) {
                    pickerRadioView(item)
                    pickerItemView(item)
                }
                .onTapGesture {
                    withAnimation { selectedPower = item }
                }
            }
        }
    }
    
    @ViewBuilder
    private func pickerItemView(_ power: Int) -> some View {
        ExpandingHStack(contentPosition: .left()) {
            Text(PowerLevel(power: power).role)
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func pickerRadioView(_ power: Int) -> some View {
        let isSelected = power == selectedPower
        let circleSize: CGFloat = 18
        Circle()
            .strokeBorder(isSelected ? Color.accentColor : Color.gray)
            .frame(width: circleSize, height: circleSize)
            .overlay(
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: circleSize / 2, height: circleSize / 2)
            )
            .padding(.all, 8)
    }
}

struct ActionAlert: View {
    @Binding var showAlert: Bool
    let allowTapDismiss: Bool
    let title: String
    let text: String
    let actionTitle: String
    let actionHandler: () -> Void
    
    init(showAlert: Binding<Bool>, allowTapDismiss: Bool = true, title: String, text: String, actionTitle: String, actionHandler: @escaping () -> Void) {
        self._showAlert = showAlert
        self.allowTapDismiss = allowTapDismiss
        self.title = title
        self.text = text
        self.actionTitle = actionTitle
        self.actionHandler = actionHandler
    }
    
    var body: some View {
        CustomAlertContainerView(allowTapDismiss: allowTapDismiss, shown: $showAlert) {
            VStack {
                Text(title)
                    .font(.title)
                    .padding(.vertical, 6)
                Text(text)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
                Divider()
                HStack(spacing: 0) {
                    Button {
                        withAnimation { showAlert = false }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text("Cancel").bold()
                                .foregroundColor(.accentColor)
                        }
                    }
                    Divider()
                    Button {
                        actionHandler()
                        withAnimation { showAlert = false }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text(actionTitle).bold()
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(height: 32)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(.backColor)
            )
        }
    }
}

struct ReasonAlert: View {
    @Binding var showAlert: Bool
    let allowTapDismiss: Bool
    let title: String
    let text: String
    let actionTitle: String
    let actionHandler: (String) -> Void
    
    @State var includeReason = true
    @State var actionReason = ""
    
    init(showAlert: Binding<Bool>, allowTapDismiss: Bool = true, title: String, text: String, actionTitle: String, actionHandler: @escaping (String) -> Void) {
        self._showAlert = showAlert
        self.allowTapDismiss = allowTapDismiss
        self.title = title
        self.text = text
        self.actionTitle = actionTitle
        self.actionHandler = actionHandler
    }
    
    var body: some View {
        CustomAlertContainerView(allowTapDismiss: allowTapDismiss, shown: $showAlert) {
            VStack {
                Text(title)
                    .font(.title)
                    .padding(.vertical, 6)
                Text(text)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Toggle("Include a reason", isOn: $includeReason)
                    .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
                    .padding(.vertical, 4)
                if includeReason {
                    NMultilineTextField(
                        text: $actionReason,
                        lineLimit: 3,
                        onCommit: nil
                    ) {
                        NMultilineTextFieldPlaceholder(text: "Reason")
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.gray.opacity(0.2))
                    )
                    .padding(.bottom, 4)
                }
                Divider()
                HStack(spacing: 0) {
                    Button {
                        withAnimation { showAlert = false }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text("Cancel").bold()
                                .foregroundColor(.accentColor)
                        }
                    }
                    Divider()
                    Button {
                        actionHandler(actionReason)
                        withAnimation { showAlert = false }
                    } label: {
                        ExpandingHStack(contentPosition: .center()) {
                            Text(actionTitle).bold()
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(height: 32)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(.backColor)
            )
        }
    }
}

// MARK: -

//struct RadioPicker<Element, Content>: View where Element: Identifiable, Content: View {
//    @Binding private var selected: Element
//    private let items: [Element]
//    private let viewForItem: (Element) -> Content
//    private let viewForRadio: (Element) -> Content
//
//    init(selected: Binding<Element>, items: [Element], viewForItem: @escaping (Element) -> Content, viewForRadio: @escaping (Element) -> Content) {
//        self.items = items
//        self.viewForItem = viewForItem
//        self.viewForRadio = viewForRadio
//        self._selected = selected
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ForEach(items) { item in
//                HStack(spacing: 0) {
//                    viewForRadio(item)
//                    viewForItem(item)
//                }
//            }
//        }
//    }
//}
