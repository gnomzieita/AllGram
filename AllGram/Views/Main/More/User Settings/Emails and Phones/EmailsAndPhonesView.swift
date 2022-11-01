//
//  EmailsAndPhonesView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 31.12.2021.
//

import SwiftUI

struct EmailsAndPhonesView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    enum AddState {
        case none
        case email
        case phone
    }
    
    @ObservedObject var viewModel: EmailsAndPhonesViewModel
    
    @State private var addState = AddState.none
    
    var body: some View {
        ZStack {
            if viewModel.isReloading {
                // Loading
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("mainColor")))
                    .scaleEffect(Constants.spinnerScale)
            } else {
                // Content
                ScrollView {
                    VStack(spacing: Constants.spacing) {
                        emails.padding(.horizontal)
                            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                            .foregroundColor(.moreItemColor))
                        phones.padding(.horizontal)
                            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                            .foregroundColor(.moreItemColor))
                        Spacer()
                    }
                    .padding(Constants.padding)
                }
            }
            if showingDeleteAlert { deleteAlert }
            if showingFailure { failureAlert }
            if showingLoader { loaderAlert }
        }
        .background(Color.moreBackColor.ignoresSafeArea())
        .navigationBarTitle("Email & Phone")
        .onAppear() {
            viewModel.reloadData() { success in
                if !success {
                    failureInfo = "Loading of email addresses and phone numbers unsuccessful"
                    showingFailure = true
                }
            }
        }
        .onDisappear() {
            // Reset alerts
            deletingElement = nil
            showingDeleteAlert = false
            failureInfo = ""
            showingFailure = false
            loaderInfo = ""
            showingLoader = false
        }
    }
    
    // MARK: - Delete
    
    @State private var deletingElement: EmailPhone? = nil
    @State private var showingDeleteAlert = false
    
    private var deleteAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingDeleteAlert) {
            ConfirmAlertView(
                title: "Confirm Deletion",
                subtitle: "Are you sure you want to delete \(deletingElement?.text ?? "nil")?",
                shown: $showingDeleteAlert
            ) { confirmed in
                withAnimation {
                    guard let data = deletingElement else { return }
                    if confirmed {
                        loaderInfo = "Deleting \(data.text)..."
                        showingLoader = true
                        viewModel.removeValid(data.text, of: data.type) { result in
                            showingLoader = false
                            switch result {
                            case .success(_): break
                            case .failure(let error):
                                failureInfo = error.problemDescription(for: data.text)
                                showingFailure = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Failure
    
    @State private var failureInfo = ""
    @State private var showingFailure = false
    
    private var failureAlert: some View {
        CustomAlertContainerView(allowTapDismiss: true, shown: $showingFailure) {
            InfoAlertView(title: "Failed", subtitle: failureInfo, shown: $showingFailure)
        }
    }
    
    // MARK: - Loading
    
    @State private var loaderInfo = ""
    @State private var showingLoader = false
    
    private var loaderAlert: some View {
        CustomAlertContainerView(allowTapDismiss: false, shown: $showingLoader) {
            LoaderAlertView(title: "Loading...", subtitle: loaderInfo, shown: $showingLoader)
        }
    }
    
    // MARK: - Emails
    
    private var emails: some View {
        EmailPhoneSectionView(
            type: .emails, content: viewModel.emails, addState: $addState,
            addHandler: { item in
                withAnimation {
                    loaderInfo = "Requesting validation for \(item.text)..."
                    showingLoader = true
                    viewModel.requestValidation(for: item.text, of: .email) { result in
                        showingLoader = false
                        switch result {
                        case .success(_):
                            addState = .none
                        case .failure(let error):
                            failureInfo = error.problemDescription(for: item.text)
                            showingFailure = true
                        }
                    }
                }
            },
            deleteHandler: { item in
                withAnimation {
                    deletingElement = item
                    showingDeleteAlert = true
                }
            },
            cancelHandler: { item in
                withAnimation {
                    loaderInfo = "Cancelling validation for \(item.text)..."
                    showingLoader = true
                    viewModel.cancelValidation(for: item.text, of: .email) { result in
                        showingLoader = false
                        switch result {
                        case .success(_): break
                        case .failure(let error):
                            failureInfo = error.problemDescription(for: item.text)
                            showingFailure = true
                        }
                    }
                }
            },
            continueHandler: { item, _ in
                withAnimation {
                    loaderInfo = "Confirming validation for \(item.text)..."
                    showingLoader = true
                    viewModel.confirmValidation(for: item.text, of: .email) { result in
                        showingLoader = false
                        switch result {
                        case .success(_): break
                        case .failure(let error):
                            failureInfo = error.problemDescription(for: item.text)
                            showingFailure = true
                        }
                    }
                }
            }
        )
    }
    
    // MARK: - Phones
    
    private var phones: some View {
        EmailPhoneSectionView(
            type: .phones, content: viewModel.phones, addState: $addState,
            addHandler: { item in
                withAnimation {
                    loaderInfo = "Requesting validation for \(item.text)..."
                    showingLoader = true
                    viewModel.requestValidation(for: item.text, of: .phone) { result in
                        showingLoader = false
                        switch result {
                        case .success(_):
                            addState = .none
                        case .failure(let error):
                            failureInfo = error.problemDescription(for: item.text)
                            showingFailure = true
                        }
                    }
                }
            },
            deleteHandler: { item in
                withAnimation {
                    deletingElement = item
                    showingDeleteAlert = true
                }
            },
            cancelHandler: { item in
                withAnimation {
                    loaderInfo = "Cancelling validation for \(item.text)..."
                    showingLoader = true
                    viewModel.cancelValidation(for: item.text, of: .phone) { result in
                        showingLoader = false
                        switch result {
                        case .success(_): break
                        case .failure(let error):
                            failureInfo = error.problemDescription(for: item.text)
                            showingFailure = true
                        }
                    }
                }
            },
            continueHandler: { item, code in
                withAnimation {
                    loaderInfo = "Confirming validation for \(item.text)..."
                    showingLoader = true
                    viewModel.confirmValidation(for: item.text, of: .phone, with: code) { result in
                        showingLoader = false
                        switch result {
                        case .success(_): break
                        case .failure(let error):
                            failureInfo = error.problemDescription(for: item.text)
                            showingFailure = true
                        }
                    }
                }
            }
        )
    }
    
    // MARK: -
    
    enum Constants {
        static let spacing: CGFloat = 40
        static let padding: CGFloat = 20
        static let cornerRadius: CGFloat = 16
        static let spinnerScale: CGFloat = 2
    }
    
}

struct EmailsAndPhonesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                EmailsAndPhonesView(viewModel: EmailsAndPhonesViewModel(authViewModel: AuthViewModel.shared))
            }
            .colorScheme(.dark)
//            NavigationView {
            EmailsAndPhonesView(viewModel: EmailsAndPhonesViewModel(authViewModel: AuthViewModel.shared))
//            }
            .colorScheme(.light)
        }
    }
}
