//
//  ClubNews.swift
//  AllGram
//
//  Created by Igor Antonchenko on 02.02.2022.
//

import SwiftUI

struct ClubNews: View {
    var body: some View {
        
        VStack {
            
            HStack {
                Image("Clubs")
                    .frame(width: 30, height: 30)
                    .background(Color.green)
                    .clipShape(Circle())
                
                Text("Media Tester")
                Spacer()
                
                Button {
                } label: {
                    Image("ellipsis-v-solid")
                        .frame(width: 30, height: 30, alignment: .trailing)
                }
            }
            .padding(.trailing, 10)
            .padding(.leading, 10)
            .padding(.top, 10)
            
            
            
            ZStack {
                Color.gray
                
                HStack {
                    
                }
                .frame(height: 200, alignment: .center)
            }
            
            
            
            HStack(spacing: 50) {
                Button {
                } label: {
                    Image("like")
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.gray)
                }
                
                Button {
                } label: {
                    Image("Comment")
                        .frame(width: 30, height: 30, alignment: .center)
                }
                Spacer()
                
            }
            .padding(.leading, 20)
            
            Spacer()
        }
        .frame(height: 300)
       
        
    }
       
}

struct ClubNews_Previews: PreviewProvider {
    static var previews: some View {
        ClubNews()
    }
}
