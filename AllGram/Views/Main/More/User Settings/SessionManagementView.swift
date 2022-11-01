//
//  SessionManagementView.swift
//  AllGram
//
//  Created by Eugene Ned on 21.07.2022.
//

import SwiftUI
import MatrixSDK

struct BottomPanelView<Content: View>: View {
    let content: () -> Content
    var showSheet: Binding<Bool>
    
    init(showSheet: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.showSheet = showSheet
    }
    
    var body: some View {
        Rectangle()
            .foregroundColor(.black.opacity(0.25))
            .onTapGesture {
                withAnimation { showSheet.wrappedValue = false }
            }
            .opacity(showSheet.wrappedValue ? 1 : 0)
            .overlay (
                content()
                    .offset(y: showSheet.wrappedValue ? 0 : UIScreen.main.bounds.height)
                , alignment: .bottom
            )
            .edgesIgnoringSafeArea(.bottom)
    }
}

struct DeviceRowView: View {
    var device: MXDevice
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading) {
                Text(device.displayName)
                Text(device.deviceId)
                    .fontWeight(.light)
                    .font(.caption)
            }
            Spacer()
        }
    }
}

struct SessionManagementView: View {
    @StateObject var viewModel = SessionManagementViewModel()
    
    @State private var selectedDevice: MXDevice?
    @State private var showSheet = false
    
    // Handle initial loading without custom alerts
    @State private var initialLoading = false
    @State private var initialError: Error?
    
    var body: some View {
        ZStack {
            // Content
            content.onAppear { doInitialLoad() }
            
            // Bottom Sheet
            bottomPanel
            
            // Custom Alerts
            if showTerminateSessionAlert { terminateSessionAlert }
            if showChangeDeviceNameAlert { changeDeviceNameAlert }
            if showingFailure { failureAlert }
            if showingSuccess { successAlert }
            if showingLoader { loaderAlert }
        }
        .navigationTitle("Session Management")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func doInitialLoad() {
        guard !initialLoading else { return }
        viewModel.getDevicesList { result in
            withAnimation {
                switch result {
                case .success(()):
                    break
                case .failure(let error):
                    initialError = error
                }
                initialLoading = false
            }
        }
    }
    
    private var content: some View {
        VStack {
            if let error = initialError {
                Text("Failed to load devices.\n\(error.localizedDescription)")
                    .foregroundColor(.gray)
                Button {
                    doInitialLoad()
                } label: {
                    Text("Reload")
                        .foregroundColor(.accentColor)
                        .padding()
                }
                Spacer()
            } else if initialLoading {
                Spinner()
                    .padding()
                Text("Loading devices...")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                devicesList
            }
        }
    }
    
    private var devicesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let currentDevice = viewModel.currentDevice {
                    Text("This device")
                        .foregroundColor(.accentColor)
                        .font(.headline)
                        .padding(.vertical)
                    rowForDevice(currentDevice)
                    .padding(.bottom)
                    Divider()
                }
                if !viewModel.devicesList.isEmpty {
                    Text("Other devices")
                        .foregroundColor(.accentColor)
                        .font(.headline)
                        .padding(.vertical)
                    ForEach(viewModel.devicesList, id: \.self) { device in
                        rowForDevice(device)
                    }
                } else {
                    ExpandingHStack {
                        Text("No other devices")
                            .foregroundColor(.gray)
                            .padding(.vertical)
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }
    
    private func rowForDevice(_ device: MXDevice) -> some View {
        Button {
            selectedDevice = device
            withAnimation {
                showSheet.toggle()
            }
        } label: {
            DeviceRowView(device: device)
                .padding(.vertical, 6)
        }
        .foregroundColor(.primary)
    }
    
    // MARK: -
    
    private var bottomPanel: some View {
        BottomPanelView(showSheet: $showSheet) {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text(selectedDevice?.displayName ?? "Unknown name").bold()
                    Text(selectedDevice?.deviceId ?? "Unknown ID")
                }
                .padding(.horizontal)
                Divider()
                VStack(spacing: 0) {
                    if selectedDevice?.deviceId != viewModel.currentDevice?.deviceId {
                        Button(action: {
                            self.showTerminateSessionAlert = true
                            self.showSheet = false
                        }, label: {
                            HStack {
                                Text("Disable this device")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.red)
                        })
                        .padding()
                    }
                    Button(action: {
                        self.showChangeDeviceNameAlert = true
                        self.newDeviceDisplayName = selectedDevice?.displayName ?? ""
                        self.showSheet = false
                    }, label: {
                        HStack {
                            Text("Rename")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.reverseColor)
                    })
                    .padding()
                }
                .padding(.bottom)
            }
            .padding()
            .frame(alignment: .topLeading)
            .background(Color("profileTopBackground"))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Loading Alert
    
    @State private var showingLoader = false
    @State private var loaderInfo: String?
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading", subtitle: loaderInfo, shown: $showingLoader)
        }
    }
    
    // MARK: - Success Alert
    
    @State private var showingSuccess = false
    @State private var successHint: String?
    
    private var successAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingSuccess) {
            InfoAlertView(title: "Success", subtitle: successHint, shown: $showingSuccess)
        }
    }
    
    // MARK: - Failure Alert
    
    @State private var showingFailure = false
    @State private var failureHint: String?
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: failureHint, shown: $showingFailure)
        }
    }
    
    // MARK: - Terminate Session
    
    @State private var showTerminateSessionAlert = false
    @State private var terminateSessionConfirmed = false
    @State private var terminateSessionPassword: String = ""
    
    private var terminateSessionAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showTerminateSessionAlert) {
            ConfirmWithPassAlertView(password: $terminateSessionPassword, success: $terminateSessionConfirmed, shown: $showTerminateSessionAlert)
                .onDisappear() {
                    let password = terminateSessionPassword
                    terminateSessionPassword = ""
                    guard terminateSessionConfirmed,
                          let deviceId = selectedDevice?.deviceId
                    else { return }
                    loaderInfo = "Terminating the session..."
                    withAnimation { showingLoader = true }
                    viewModel.terminateSession(deviceId: deviceId, password: password) { result in
                        selectedDevice = nil
                        switch result {
                        case .success(()):
                            successHint = "Session terminated."
                            withAnimation {
                                showingLoader = false
                                showingSuccess = true
                            }
                        case .failure(let error):
                            failureHint = "Failed to terminate session.\n\(error.localizedDescription)"
                            withAnimation {
                                showingLoader = false
                                showingFailure = true
                            }
                        }
                    }
                }
        }
    }
    
    // MARK: - Change Name
    
    @State private var showChangeDeviceNameAlert = false
    @State private var changeDeviceNameConfirmed = false
    @State private var newDeviceDisplayName = ""
    
    private var changeDeviceNameAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showChangeDeviceNameAlert) {
            TextInputAlertView(title: "Device Display Name", textInput: $newDeviceDisplayName, inputPlaceholder: "Device name", success: $changeDeviceNameConfirmed, shown: $showChangeDeviceNameAlert)
                .onDisappear() {
                    let name = newDeviceDisplayName
                    newDeviceDisplayName = ""
                    guard changeDeviceNameConfirmed,
                          let deviceId = selectedDevice?.deviceId
                    else { return }
                    loaderInfo = "Renaming device..."
                    withAnimation { showingLoader = true }
                    viewModel.renameDevice(name, deviceId: deviceId) { result in
                        selectedDevice = nil
                        switch result {
                        case .success(()):
                            successHint = "Device name changed."
                            withAnimation {
                                showingLoader = false
                                showingSuccess = true
                            }
                        case .failure(let error):
                            failureHint = "Failed to rename device.\n\(error.localizedDescription)"
                            withAnimation {
                                showingLoader = false
                                showingFailure = true
                            }
                        }
                    }
                }
        }
    }
}

