//
//  NavigationBar.swift
//  AllGram
//
//  Created by Igor Antonchenko on 01.02.2022.
//

import SwiftUI

struct NavigationBar: View {
    @State private var searchButtonPressed: Bool = false
    var buttonSearchIsHidden: Bool
    var title = ""
    
    
    
    init(buttonSearchIsHidden: Bool, title: String) {
        self.buttonSearchIsHidden = buttonSearchIsHidden
        self.title = title
    }
    
    
    
    var body: some View {
        ZStack {
            Color.allgramMain
            
            HStack {
                Text(title)
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                
                Button {
                    self.searchButtonPressed.toggle()
                } label: {
                    Image("search-solid")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundColor(.white)
                        .padding(.trailing,20)
                    
                }
                .buttonHidden(buttonIsHidden: buttonSearchIsHidden)

            }
            .sheet(isPresented: $searchButtonPressed) {
           
            }
    }
            .frame(height: 70)
            .frame(maxHeight: .infinity, alignment: .top)
            .cornerRadius(20)
            
        
    }
        
}

struct NavigationBar_Previews: PreviewProvider {
    static var previews: some View {
        NavigationBar(buttonSearchIsHidden: false, title: "Clubs")
    }
}



struct ButtonHidden : ViewModifier {
    var buttonIsHidden: Bool
    func body(content: Content) -> some View {
        if buttonIsHidden {
            content
                .hidden()
        } else {
            content
        }
        
    }
}

extension View {
    func buttonHidden(buttonIsHidden: Bool) -> some View {
        modifier(ButtonHidden(buttonIsHidden: buttonIsHidden))
    }
}
