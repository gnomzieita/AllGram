//
//  CreateMeetingView.swift
//  AllGram
//
//  Created by Eugene Ned on 20.09.2022.
//

import SwiftUI

struct CreateMeetingView: View {
    @Environment(\.presentationMode) var presentationMode
    
    private var filledCorrectly: Bool {
        newMeetingVM.meetingName.hasContent && !newMeetingVM.users.isEmpty
    }
    
    @FocusState private var focusedField: OurTextFieldFocus?
    
    @StateObject private var newMeetingVM = NewMeetingViewModel(session: AuthViewModel.shared.session!)
    
    let forInstant: Bool // false for scheduled meeting creating
    
    init(forInstant: Bool) {
        self.forInstant = forInstant
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    nameField
                    participantsPicker
                    if !forInstant {
                        datePicker
                        Divider()
                        timePicker
                        Divider()
                        repeatPicker
                        Divider()
                        descriptionField
                    }
                    Spacer()
                }
                .padding(Constants.fieldsPadding)
                .disabled(newMeetingVM.savingInProgress)
            }
            .background(backImage, alignment: .top)
            .alert(isPresented: $showAlert) {
                genericAlert!
            }
            .navigationBarTitleDisplayMode(.inline)
            .ourToolbar(
                leading:
                    HStack {
                        navigationBackButton
                        VStack(alignment: .leading) {
                            Text("Create a meeting").bold()
                                .foregroundColor(.white)
                            Text(forInstant ? "Instant" : "Scheduled")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                ,
                trailing:
                    createButton
            )
        }
    }
    
    // MARK: - Title
    
    let nameConfig = OurTextFieldConfiguration.createMeetingName
    
    private var nameField: some View {
        OurTextField(rowInput: $newMeetingVM.meetingName, isValid: true, focus: $focusedField, config: nameConfig) {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Text("\(newMeetingVM.meetingName.count)/30")
                        .font(.caption)
                        .foregroundColor(newMeetingVM.meetingName.count == 30 ? .red : .textMedium)
                }
            }
        }
        .padding(.bottom, Constants.fieldsPadding)
    }
    
    // MARK: - Participants
    
    private var participantsPicker: some View {
        NavigationLink(destination: AddParticipantsView(newMeetingVM: newMeetingVM)) {
            HStack(spacing: 0) {
                Image("user-plus-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(Color.textMedium)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .padding(.trailing, Constants.imagePadding)
                Text("Add participants").bold()
                    .foregroundColor(Color.textHigh)
                Spacer()
                Text("\(newMeetingVM.users.count)")
                    .foregroundColor(Color.textMedium)
                Image("angle-right-solid")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(Color.textMedium)
                    .frame(width: Constants.trailingImageSize, height: Constants.trailingImageSize)
                    .padding(.leading, Constants.imagePadding)
            }
            .padding(.bottom, Constants.fieldsPadding)
        }
    }
    
    // MARK: - Date
    
    @State private var showsDatePicker = false
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()
    
    private var datePicker: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Date").bold()
                    .foregroundColor(Color.textHigh)
                Spacer()
                Text("\(dateFormatter.string(from: newMeetingVM.meetingDate))")
                    .foregroundColor(Color.textMedium)
            }
            .onTapGesture {
                withAnimation { showsDatePicker.toggle() }
            }
            
            DatePicker("", selection: $newMeetingVM.meetingDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .accentColor(.pink)
                .background(Color("newMeetingBackground"))
                .border(Color.reverseColor.opacity(0.06))
                .cornerRadius(4)
                .opacity(showsDatePicker ? 1 : 0)
                .frame(height: showsDatePicker ? nil : 1)
                .clipped()
        }
    }
    
    // MARK: - Time
    
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    
    let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()
    
    private var timePicker: some View {
        VStack(spacing: 16) {
            Toggle(isOn: $newMeetingVM.allDay.animation()) {
                HStack(spacing: 0) {
                    Image("history-solid")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .foregroundColor(Color.textMedium)
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                        .padding(.trailing, Constants.imagePadding)
                    Text("All day").bold()
                        .foregroundColor(Color.textHigh)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
            
            if !newMeetingVM.allDay {
                VStack(spacing: 20) {
                    // Start time & picker
                    HStack {
                        Text("Start time").bold()
                            .foregroundColor(Color.reverseColor)
                        Spacer()
                        Text("\(timeFormatter.string(from: newMeetingVM.startTime))")
                            .foregroundColor(Color.textMedium)
                    }
                    .onTapGesture {
                        withAnimation { showStartTimePicker.toggle() }
                    }
                    
                    if showStartTimePicker {
                        DatePicker("", selection: $newMeetingVM.startTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .disabled(newMeetingVM.savingInProgress)
                            .accentColor(Color.allgramMain)
                            .background(Color("newMeetingBackground"))
                            .border(Color.reverseColor.opacity(0.06))
                            .cornerRadius(4)
                            .padding(.leading, -(Constants.iconSize + Constants.imagePadding))
                    }
                    // End time & picker
                    HStack {
                        Text("End time").bold()
                            .foregroundColor(Color.reverseColor)
                        Spacer()
                        Text("\(timeFormatter.string(from: newMeetingVM.endTime))")
                            .foregroundColor(Color.textMedium)
                    }
                    .onTapGesture {
                        withAnimation { showEndTimePicker.toggle() }
                    }
                    
                    if showEndTimePicker {
                        DatePicker("", selection: $newMeetingVM.endTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .disabled(newMeetingVM.savingInProgress)
                            .accentColor(Color.allgramMain)
                            .background(Color("newMeetingBackground"))
                            .border(Color.reverseColor.opacity(0.06))
                            .cornerRadius(4)
                            .padding(.leading, -(Constants.iconSize + Constants.imagePadding))
                    }
                }
                .padding(.leading, Constants.iconSize + Constants.imagePadding)
            }
        }
    }
    
    // MARK: - Repeat
    
    private var repeatPicker: some View {
        HStack(spacing: 0) {
            Image("history-solid")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .foregroundColor(Color.textMedium)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .padding(.trailing, Constants.imagePadding)
            Text("Repeat").bold()
                .foregroundColor(Color.textHigh)
            Spacer()
            Picker("", selection: $newMeetingVM.repeatOption) {
                ForEach(MeetingFrequency.allCases, id: \.self) { option in
                    Button {
                        withAnimation { newMeetingVM.repeatOption = option }
                    } label: {
                        Text(option.rawValue.capitalized)
                            .fontWeight(newMeetingVM.repeatOption == option ? .bold : .regular)
                            .foregroundColor(Color.textMedium)
                    }
                }
            }
            .pickerStyle(.menu)
            .accentColor(Color.textMedium)
        }
    }
    
    // MARK: - Description
    
    @State private var meetingDescription = ""
    
    let descriptionConfig = OurTextFieldConfiguration.createMeetingDescription
    
    private var descriptionField: some View {
        OurTextField(rowInput: $meetingDescription, isValid: true, focus: $focusedField, config: descriptionConfig) {
            EmptyView()
        }
        .padding(.top, Constants.fieldsPadding)
    }
    
    // MARK: - Alert
    
    @State private var showAlert = false
    @State private var genericAlert: Alert?
    
    func generateAlertWith(title: String, subtitle: String, isError: Bool) -> Alert {
        if isError {
            return Alert(
                title: Text(title),
                message: Text(subtitle),
                dismissButton: .default(Text("Got it"))
            )
        } else {
            return Alert(
                title: Text(title),
                message: Text(subtitle),
                primaryButton: .default(Text("Discard"), action: {
                    presentationMode.wrappedValue.dismiss()
                }),
                secondaryButton: .cancel(Text("Keep editing").bold())
            )
        }
    }
    
    // MARK: - Navigation
    
    private var navigationBackButton: some View {
        Button {
            genericAlert = generateAlertWith(title: "Warning", subtitle: "Are you sure you want to discard this event?", isError: false)
            showAlert = true
        } label: {
            Image("times-solid")
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder private var createButton: some View {
        if newMeetingVM.savingInProgress {
            ProgressView()
                .tint(.white)
        } else {
            Button {
                newMeetingVM.createMeeting(instant: forInstant) { result in
                    switch result {
                    case .success(_):
                        self.presentationMode.projectedValue.wrappedValue.dismiss()
                        
                    case .failure(let error):
                        genericAlert = generateAlertWith(title: "Error", subtitle: error.localizedDescription, isError: true)
                        showAlert = true
                    }
                }
            } label: {
                Text("Create").bold()
                    .foregroundColor(.white.opacity(filledCorrectly ? 1 : 0.4))
            }
        }
    }
    
    // MARK: - Background image
    
    @ViewBuilder
    private var backImage: some View {
        if SettingsManager.homeBackgroundImageName == nil,
           let customImage = SettingsManager.getSavedHomeBackgroundImage() {
            Image(uiImage: customImage)
                .resizable().scaledToFill()
                .frame(width: UIScreen.main.bounds.width)
                .ignoresSafeArea()
        } else {
            Image(SettingsManager.homeBackgroundImageName!)
                .resizable().scaledToFill()
                .frame(width: UIScreen.main.bounds.width)
                .ignoresSafeArea()
        }
    }
    
    // MARK: -
    
    struct Constants {
        static let cornerRadius: CGFloat = 8
        static var sameHeight: CGFloat { OurTextFieldConstants.inputHeight }
        static let fieldsPadding: CGFloat = 16
        static let signInButtonsPadding: CGFloat = 4
        static let iconSize: CGFloat = 30
        static let imagePadding: CGFloat = 13
        static let trailingImageSize: CGFloat = 15
    }
}

struct NewScheduledMeeting_Previews: PreviewProvider {
    static var previews: some View {
        CreateMeetingView(forInstant: false)
    }
}
