//
//  FeedClubsNews.swift
//  AllGram
//
//  Created by Igor Antonchenko on 01.02.2022.
//

import SwiftUI

struct FeedClubsNews: View {
    var body: some View {
        
        ZStack {
            
            Color.gray.opacity(0.3)
            
            VStack(spacing: 20) {
                ForEach(0..<10) {_ in
                    ZStack {
                        Color.white
                        
                        ClubNews()
                            .frame(height: 300)
                    }
                    .frame( height: 300, alignment: .center)
                    .cornerRadius(10)
                }
            }
        }
        
       
    }
}

struct FeedClubsNews_Previews: PreviewProvider {
    static var previews: some View {
        FeedClubsNews()
    }
}
