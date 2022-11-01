//
//  QRScannerView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 22.12.2021.
//

import SwiftUI
import CodeScanner

struct QRScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scannedUserId: String?
    @State private var showingScanResult = false
    
    let simulatedLink = "https://allgram.me/#/@nick01:allgram.me"
    
    var body: some View {
        NavigationView {
            ZStack {
                GeometryReader { geometry in
                    CodeScannerView(
                        codeTypes: [.qr],
                        scanMode: .continuous,
                        scanInterval: 1.0,
                        showViewfinder: false,
                        simulatedData: simulatedLink,
                        shouldVibrateOnSuccess: true,
                        completion: handleScan
                    )
                    QRWindowView(size: geometry.size)
                }
                .onTapGesture {
                    withAnimation() { showingScanResult = false }
                }
                if showingScanResult {
                    VStack {
                        Spacer()
                        QRResultView(userId: scannedUserId!, show: $showingScanResult)
                            .onDisappear {
                                presentationMode.wrappedValue.dismiss()
                            }
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationBarTitle("Scan QR", displayMode: .inline)
            .navigationBarTitleDisplayMode(.inline)
            .ourToolbar(
                title: "Scan QR",
                leading:
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Close")
                    }
                ,
                trailing:
                    EmptyView()
            )
            .onAppear {
                // Simulate selecting QR for simulator
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    scannedUserId = simulatedLink.components(separatedBy: "/#/").last!
                    withAnimation { showingScanResult = true }
                }
            }
        }
    }
    
    // MARK: - QR Code Scanning
        
    @StateObject var idHandler = BrandNewDigitalIDHandler(accessToken: AuthViewModel.shared.session!.credentials!.accessToken!)
    
    private func handleScan(_ result: Result<ScanResult, ScanError>) {
        guard !showingScanResult else { return }
        switch result {
        case .success(let scanResult):
            if scanResult.string.contains("https://allgram.me/#/"), let userId = scanResult.string.components(separatedBy: "/#/").last {
                scannedUserId = userId
                withAnimation { showingScanResult = true }
            } else {
                let token = scanResult.string
                idHandler.onInvalidToken = {
                    withAnimation {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                idHandler.onTokenConfirmed = {
                    withAnimation {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                idHandler.sendConfirm(token: token)
            }

        case .failure(_):
            break

        }
    }
    
}

struct QRScannerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QRScannerView()
                .colorScheme(.dark)
            QRScannerView()
                .colorScheme(.light)
        }
    }
}
