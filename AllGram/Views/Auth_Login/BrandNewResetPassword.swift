//
//  BrandNewResetPassword.swift
//  AllGram
//
//  Created by Eugene Ned on 01.09.2022.
//

import SwiftUI

struct BrandNewResetPassword: View {
    @Environment(\.presentationMode) var presentationMode
    
    let data: AuthViewModel.ForgotPasswordData
    
    @State private var resetDone = false
    @State private var checking = false
    
    @State private var errorAlert: ErrorAlert?
    
    var body: some View {
        VStack {
            VStack {
                textInfoView
            }
            .alert(isPresented: $showWarningAlert) {
                warningAlert
            }
            VStack {
                infoPanelView
            }
            .alert(item: $errorAlert) { alert in
                Alert(title: Text("Failed to verify the email address"),
                      message: Text("Only after you have successfully followed the link from the email sent to you, click on the \"I have verified my email address\" button."),
                      dismissButton: .cancel(Text("Okay")))
            }
        }
        .navigationBarBackButtonHidden(true)
        .ourToolbar(leading: navigationBackButton)
    }
    
    var navigationBackButton : some View {
        Button(action: {
            showWarningAlert = true
        }) {
            Image(systemName: "chevron.left")
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
        }
    }
    
    @State private var showWarningAlert = false
    @State private var warningAlertText = ""
    
    private var warningAlert: Alert {
        Alert(
            title: Text("Warning!"),
            message: Text("Your password is not yet changed.\nStop the password change process?"),
            primaryButton: .default(
                Text("Okay"),
                action: {
                    presentationMode.wrappedValue.dismiss()
                }),
            secondaryButton: .cancel()
        )
    }
    
    private var textInfoView: some View {
        VStack(alignment: .leading) {
            Text(resetDone ? "Success!" : "Check your inbox")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
            
            Text(resetDone ? "**Your password has been reset.**" : "Open the email we successfully sent to \n**\(data.email)** \nand follow the link in it.")
                .font(.title3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(.black)
        
    }
    
    private var resetButton: some View {
        Button(action: {
            if resetDone { presentationMode.wrappedValue.dismiss() } else {
                checking = true
                AuthViewModel.shared.resetPassword(data) { result in
                    withAnimation {
                        checking = false
                        switch result {
                        case .success:
                            resetDone = true
                        case .failure(let error):
                            errorAlert = error
                        }
                    }
                }
            }
        }) {
            Text(resetDone ? "Back to Sign In" : "I have verified my email address")
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sameHeight)
        .background(Color.allgramMain)
        .cornerRadius(Constants.cornerRadius)
        .padding([.horizontal, .bottom],Constants.fieldsPadding)
        .disabled(checking)
    }
    
    private var infoPanelView: some View {
        VStack {
            HStack(alignment: .top) {
                Image("exclamation-circle-solid")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color.orange.opacity(0.9))
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                Text(resetDone ? "You have been logged out of all sessions and will no longer receive push notifications. To re-enable notifications, sign in again on each device" : "Only after you have successfully followed the link from the email sent to you, click on this button")
                    .multilineTextAlignment(.leading)
            }
            .padding(Constants.fieldsPadding)
            .foregroundColor(.black)
            resetButton
        }
        .background(Color.orange.opacity(0.2))
        .cornerRadius(Constants.panelCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.panelCornerRadius)
                .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
        static let iconPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 8
        static let panelCornerRadius: CGFloat = 12
        static let sameHeight: CGFloat = 56
        static let fieldsPadding: CGFloat = 16
        
        static let infoBottomPadding: CGFloat = 24
        static let infoHorizontalPadding: CGFloat = 4
    }
}

struct BrandNewResetPassword_Previews: PreviewProvider {
    static var previews: some View {
        BrandNewResetPassword(data: (sid: "", secret: "", email: "test@gmail.com", newPassword: ""))
    }
}
