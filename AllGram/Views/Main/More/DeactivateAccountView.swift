//
//  DeactivateAccountView.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 13.01.2022.
//

import SwiftUI

struct DeactivateAccountView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @State private var securePass = true
    @State var password: String
    @State var filledCorrectly: Bool = false
    var deactivateButtonColor: Color {
        return password.count > 0 ? Color("allgram_main_color") : .gray
    }
    struct Constants {
        static let iconSize: CGFloat = 24
        static let iconPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let tfHeight: CGFloat = 56
        static let hPadding: CGFloat = 36
    }
    
    var body: some View {
        ScrollView {
            VStack {
                Text(nL10n.DeactivateAccount.sorry)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical)
                Text(nL10n.DeactivateAccount.irreversible)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical)
                Text(nL10n.DeactivateAccount.actionDescription)
                    .padding(.bottom)
                    .foregroundColor(Color.gray)
                Text(nL10n.DeactivateAccount.actionRequirement)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(Color.gray)
                ZStack {
                    AdaptiveSecureTextField($securePass, placeholder: "", textInput: $password)
                        .placeholder(when: $password.wrappedValue.isEmpty) {
                            Text(nL10n.DeactivateAccount.passwordPlaceholder)
                                .foregroundColor(.gray)
                        }
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(height: Constants.tfHeight)
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                .stroke(Color.gray, lineWidth: 2)
                        )
                    HStack {
                        Spacer()
                        Button {
                            withAnimation { securePass.toggle() }
                        } label: {
                            Image(systemName: securePass ? "eye.fill" : "eye.slash.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: Constants.iconSize, height: Constants.iconSize)
                                .padding(Constants.iconPadding)
                        }
                        .padding(.trailing, Constants.iconPadding)
                    }
                }
                .padding(.bottom, 16)
                HStack {
                    Spacer()
                    Button {
                        authViewModel.sessionVM?.deactivateAccount(password: password) { result in
                            switch result {
                            case .success(()):
                                authViewModel.loginState = .loggedOut
                                PushNotifications.shared.unsubscribe(model: authViewModel)
                                UserNotifications.shared.unsubscribe()
                            case .failure(_):
                                break
                            }
                        }
                    } label: {
                        Text(nL10n.DeactivateAccount.actionButtonTitle)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .frame(height: 36)
                            .padding(.horizontal, 16)
                    }
                    .background(deactivateButtonColor)
                    .cornerRadius(Constants.cornerRadius)
                    .disabled(!password.hasContent)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationTitle(nL10n.DeactivateAccount.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $authViewModel.errorAlert) { errorForAlert in
            Alert(title: Text(errorForAlert.title), message: Text(errorForAlert.message), dismissButton: .cancel(Text("OK")))
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
}

struct DeactivateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        DeactivateAccountView(password: "")
    }
}
