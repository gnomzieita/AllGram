//
//  SecurityRowView.swift
//  AllGram
//
//  Created by Eugene Ned on 01.08.2022.
//

import SwiftUI

struct SecurityRowView: View {
    let imageName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
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

//struct SecurityRowView_Previews: PreviewProvider {
//    static var previews: some View {
//        SecurityRowView()
//    }
//}
