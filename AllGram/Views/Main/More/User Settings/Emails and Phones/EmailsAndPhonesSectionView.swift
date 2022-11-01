//
//  EmailsAndPhonesSectionView.swift
//  AllGram
//
//  Created by Alex Pirog on 05.01.2022.
//

import SwiftUI

struct EmailPhoneRowView: View {
    
    let data: EmailPhone
    
    let deleteHandler: EmailPhoneSectionView.ActionHandler?
    let cancelHandler: EmailPhoneSectionView.ActionHandler?
    let continueHandler: EmailPhoneSectionView.CodeActionHandler?
    
    init(data: EmailPhone,
         deleteHandler: EmailPhoneSectionView.ActionHandler? = nil,
         cancelHandler: EmailPhoneSectionView.ActionHandler? = nil,
         continueHandler: EmailPhoneSectionView.CodeActionHandler? = nil
    ) {
        self.data = data
        self.deleteHandler = deleteHandler
        self.cancelHandler = cancelHandler
        self.continueHandler = continueHandler
    }
    
    @State private var code: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(data.text)
                    .padding(.bottom, Constants.miniPadding)
                Spacer()
                if data.isValid {
                    // Deleting valid data
                    Button(action: { deleteHandler?(data) }, label: {
                        Image(systemName: "trash")
                            .resizable().scaledToFit()
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                            .foregroundColor(.accentColor)
                    })
                }
            }
            if let error = data.problem {
                Text(error.problemDescription(for: data.text))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
            if !data.isValid {
                if data.type == .phone {
                    Text("A text message has been sent to \(data.text). Please enter the verification code it contains and click continue.")
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    TextField("Code", text: $code)
                        .textContentType(UITextContentType.oneTimeCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.top, Constants.miniPadding)
                } else {
                    Text("Please, check your email and click on the link it contains. Once this is done, click continue.")
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                HStack {
                    Button(action: { cancelHandler?(data) }) {
                        Text("Cancel")
                            .foregroundColor(.red)
                            .bold().padding(.top)
                    }
                    Spacer()
                    Button(action: { continueHandler?(data, code) }) {
                        Text("Continue")
                            .foregroundColor(.accentColor)
                            .bold().padding(.top)
                    }
                }
            }
        }
        .padding(.vertical, Constants.vPadding)
        .padding(.horizontal)
    }
    
    struct Constants {
        static let miniPadding: CGFloat = 4
        static let vPadding: CGFloat = 8
        static let iconSize: CGFloat = 24
    }
    
}

struct EmailPhoneSectionView: View {
    
    enum SectionType {
        
        case emails
        case phones
        
        var dataType: EmailPhoneType {
            switch self {
            case .emails: return .email
            case .phones: return .phone
            }
        }
        
        var title: String {
            switch self {
            case .emails: return "Email addresses"
            case .phones: return "Phone numbers"
            }
        }
        
        var actionTitle: String {
            switch self {
            case .emails: return "Add email address"
            case .phones: return "Add phone number"
            }
        }
        
        var inputPlaceholder: String {
            switch self {
            case .emails: return "Email"
            case .phones: return "Phone"
            }
        }
        
        var inputType: UITextContentType {
            switch self {
            case .emails: return .emailAddress
            case .phones: return .telephoneNumber
            }
        }
        
        var keyboardType: UIKeyboardType {
            switch self {
            case .emails: return .emailAddress
            case .phones: return .phonePad
            }
        }
        
        var matchingAddState: EmailsAndPhonesView.AddState {
            switch self {
            case .emails: return .email
            case .phones: return .phone
            }
        }
        
    }
    
    let type: SectionType
    let content: [EmailPhone]
    let addState: Binding<EmailsAndPhonesView.AddState>
    let addHandler: ActionHandler?

    let deleteHandler: ActionHandler?
    let cancelHandler: ActionHandler?
    let continueHandler: CodeActionHandler?
    
    init(type: EmailPhoneSectionView.SectionType,
         content: [EmailPhone],
         addState: Binding<EmailsAndPhonesView.AddState>,
         addHandler: EmailPhoneSectionView.ActionHandler? = nil,
         deleteHandler: EmailPhoneSectionView.ActionHandler? = nil,
         cancelHandler: EmailPhoneSectionView.ActionHandler? = nil,
         continueHandler: EmailPhoneSectionView.CodeActionHandler? = nil
    ) {
        self.type = type
        self.content = content
        self.addState = addState
        self.addHandler = addHandler
        self.deleteHandler = deleteHandler
        self.cancelHandler = cancelHandler
        self.continueHandler = continueHandler
    }
    
    @State private var input = ""
    
    typealias ActionHandler = (_ data: EmailPhone) -> Void
    typealias CodeActionHandler = (_ data: EmailPhone, _ code: String?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(type.title)
                    .foregroundColor(.gray)
                    .padding(.vertical)
                Spacer()
            }
            if !content.isEmpty {
                ForEach(content, id: \.self) { data in
                    EmailPhoneRowView(data: data, deleteHandler: deleteHandler, cancelHandler: cancelHandler, continueHandler: continueHandler)
                }
            } else {
                HStack {
                    Text("Nothing added yet").padding()
                    Spacer()
                }
            }
            if addState.wrappedValue == type.matchingAddState {
                Divider()
                if type == .phones {
                    Text("Please use the international format (phone number must start with '+')")
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .padding(.top)
                        .padding(.horizontal)
                }
                TextField(type.inputPlaceholder, text: $input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(type.inputType)
                    .keyboardType(type.keyboardType)
                    .autocapitalization(.none)
                    .padding()
                HStack {
                    Button(action: { withAnimation { addState.wrappedValue = .none } }) {
                        Text("Cancel")
                            .foregroundColor(.red)
                            .bold().padding(.bottom)
                    }
                    Spacer()
                    Button(action: { addHandler?(EmailPhone(type: type.dataType, text: input, isValid: false)) }) {
                        Text("Continue")
                            .foregroundColor(.accentColor)
                            .bold().padding(.bottom)
                    }
                }
                .padding(.horizontal)
            } else if addState.wrappedValue == .none {
                Divider()
                HStack {
                    Spacer()
                    Button(action: { withAnimation { input = ""; addState.wrappedValue = type.matchingAddState } }) {
                        Text(type.actionTitle)
                            .foregroundColor(.accentColor)
                            .bold().padding()
                    }
                    Spacer()
                }
            } else {
                // Adding other type
            }
        }
    }
    
    struct Constants {
        static let iconSize: CGFloat = 24
    }
    
}

struct EmailPhoneSection_Previews: PreviewProvider {
    
    static let previewEmails = [
        EmailPhone(type: .email, text: "111@gmail.com", isValid: true),
        EmailPhone(type: .email, text: "222@gmail.com", isValid: true, problem: .removeValidFailed),
        EmailPhone(type: .email, text: "333@gmail.com", isValid: false),
        EmailPhone(type: .email, text: "444@gmail.com", isValid: false, problem: .confirmValidationNotConfirmed)
    ]
    static let previewPhones = [
        EmailPhone(type: .phone, text: "+38 111 111 22 22", isValid: true),
        EmailPhone(type: .phone, text: "+38 111 111 22 22", isValid: false)
    ]
    
    static var previews: some View {
        Group {
            EmailPhoneSectionView(type: .emails, content: previewEmails, addState: .constant(.none))
                .background(Color.black)
                .colorScheme(.dark)
            EmailPhoneSectionView(type: .phones, content: previewPhones, addState: .constant(.phone))
                .background(Color.white)
                .colorScheme(.light)
        }
        .frame(width: 350)
        .previewLayout(.sizeThatFits)
    }
    
}
