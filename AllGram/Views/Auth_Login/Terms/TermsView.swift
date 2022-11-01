//
//  TermsView.swift
//  AllGram
//
//  Created by Admin on 31.08.2021.
//

import SwiftUI
import WebKit
import MatrixSDK

struct TermsView: View {
    @Environment(\.presentationMode) var mode
    @StateObject var termsViewModel = TermsViewModel.shared
    
    var body: some View {
        NavigationView {
            VStack {
                List(termsViewModel.policies.enumerated().map { $0 },
                     id: \.element.url,
                     selection: $termsViewModel.displayedPolicyIndex,
                     rowContent: { index, policy in
                        NavigationLink(
                            destination: Text(policy.url),
                            label: {
                                TermsListItemView(
                                    policy: policy,
                                    policyState: $termsViewModel.policiesStates[index])
                        })
                })
                
                Button(action: {
                    mode.wrappedValue.dismiss()
                }, label: {
                    Text("Accept")
                })
                .disabled(termsViewModel.allPoliciesAccepted)
            }
            .navigationTitle("Policies terms")
        }
    }
}

//struct TermsView_Previews: PreviewProvider {
//    static var previews: some View {
//        TermsView()
//    }
//}
