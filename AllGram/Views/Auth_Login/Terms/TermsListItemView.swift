//
//  TermsListItemView.swift
//  AllGram
//
//  Created by Admin on 01.09.2021.
//

import SwiftUI
import MatrixSDK

struct TermsListItemView: View {
    let policy: MXLoginPolicyData
    @Binding var policyState: Bool
    
    var body: some View {
        Toggle(isOn: $policyState, label: {
            Text(policy.name)
        })
        .toggleStyle(SwitchToggleStyle(tint: Color.allgramMain))
        .padding()
    }
}

//struct TermsListItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        TermsListItemView()
//    }
//}
