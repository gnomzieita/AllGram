//
//  MyQRCodeView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 21.12.2021.
//

import SwiftUI
import Kingfisher
import CoreImage.CIFilterBuiltins

struct QRCodeOptionView: View {
    let imageName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 0) {
            Image(imageName)
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.trailing, 12)
            VStack(alignment: .leading) {
                Text(title).bold()
                Text(subtitle).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

struct MyQRCodeView: View {
    @EnvironmentObject var backupVM: NewKeyBackupViewModel

    var userId: String { AuthViewModel.shared.session!.myUser.userId! }
    var displayName: String { AuthViewModel.shared.session!.myUser.displayname! }    
    
    @ObservedObject var sessionVM = (AuthViewModel.shared.sessionVM)!
    
    init() { }
    
    @State private var showingQRScanner = false
    @State private var showingShare = false
    
    private var urlString: String {
        // example: https://allgram.me/#/@nick01:allgram.me
        return "https://allgram.me/#/\(userId)"
    }
    
    private var shareActivities: [AnyObject] {
        let activities: [AnyObject] = [
            "You are invited to join allgram by \(displayName)" as AnyObject,
            UIImage(named: "logo") as AnyObject,
            URL(string: urlString)! as AnyObject
        ]
        return activities
    }
    
    var body: some View {
        VStack {
            Form {
                ZStack {
                    Image(uiImage: generateQRImage(with: urlString))
                        .interpolation(.none)
                        .resizable().scaledToFit()
                        .padding(.vertical, Constants.qrPadding)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.generalPadding)
                                .foregroundColor(.white)
                        )
                    AvatarImageView(sessionVM.userAvatarURL, name: displayName)
                        .frame(width: Constants.photoSize, height: Constants.photoSize)
                        .overlay(Circle().stroke(Color.white, lineWidth: 6))
                }
                .listRowBackground(Color.white)
                
                Section {
                    HStack {
                        Text("User ID: \(userId.dropAllgramSuffix)")
                        Spacer()
                    }

                    let epVM = EmailsAndPhonesViewModel(authViewModel: AuthViewModel.shared)
                    NavigationLink(
                        destination: EmailsAndPhonesView(viewModel: epVM),
                        label: {
                            QRCodeOptionView(
                                imageName: "envelope-solid",
                                title: "Emails and Phone Numbers",
                                subtitle: "Change or edit your contact info"
                            )
                                .accentColor(.reverseColor)
                        }
                    )

                    NavigationLink(
                        destination: ManageBackupView(backupVM),
                        label: {
                            QRCodeOptionView(
                                imageName: "key-solid",
                                title: "Encryption Key Management",
                                subtitle: "Create a key or recover a session"
                            )
                                .accentColor(.reverseColor)
                        }
                    )
                    
                    NavigationLink(
                        destination: SessionManagementView(),
                        label: {
                            QRCodeOptionView(
                                imageName: "link-solid",
                                title: "Session Management",
                                subtitle: "Manage your linked devices"
                            )
                                .accentColor(.reverseColor)
                        }
                    )
                }
            }
        }
        .navigationBarTitle("Digital ID", displayMode: .inline)
        .background(Color.moreBackColor.ignoresSafeArea())
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let photoSize: CGFloat = 80
        static let logoSize: CGFloat = 36
        static let qrPadding: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 8
        static let generalPadding: CGFloat = 24
        static let backPadding: CGFloat = 26
    }
    
    // MARK: - Generating QR Image
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    private func generateQRImage(with content: String) -> UIImage {
        let data = Data(content.utf8)
        filter.setValue(data, forKey: "inputMessage")
        if let qrCodeImage = filter.outputImage {
            if let qrCodeCGImage = context.createCGImage(qrCodeImage, from: qrCodeImage.extent){
                return UIImage(cgImage: qrCodeCGImage)
            }
        }
        return UIImage(solidColor: .black, size: CGSize(width: 200, height: 200))
    }
}


//struct MyQRCodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            NavigationView {
//                MyQRCodeView()
//            }
//            .colorScheme(.dark)
////            NavigationView {
//                MyQRCodeView()
////            }
//            .colorScheme(.light)
//        }
//    }
//}
