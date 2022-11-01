//
//  ChatCellView.swift
//  AllGrammDev
//
//  Created by Ярослав Шерстюк on 03.09.2021.
//

import SwiftUI
import MatrixSDK
import Kingfisher

struct ChatCellView: View {
    
    var body: some View {
        
        HStack {
            Image ("avatarUser")
                .resizable()
                .frame(width: 54, height: 54)
                .aspectRatio(contentMode: .fit)
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text("Name")
                    .fontWeight(.medium)
                    .font(Font.custom("Roboto", size: 18))
                Text("Hi. How are you? Do you have time for a…")
                    .fontWeight(.regular)
                    .font(Font.custom("Roboto", size: 16))
                    .foregroundColor(.gray)
            }
            HStack {
                Image(systemName: "phone.fill")
                Image(systemName: "ellipsis.bubble.fill")
                Image(systemName: "1.circle.fill")
            }
            .foregroundColor(.gray)
        }
        .overlay(
            Text("Jan, 12")
                .fontWeight(.regular)
                .font(Font.custom("Roboto", size: 12))
                .foregroundColor(.gray)
            , alignment: .topTrailing
        )
    }
}

struct ChatCellView_Previews: PreviewProvider {
    static var previews: some View {
        ChatCellView()
    }
}
