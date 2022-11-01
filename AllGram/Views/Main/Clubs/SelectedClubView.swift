//
//  SelectedClubView.swift
//  AllGram
//
//  Created by Igor Antonchenko on 08.02.2022.
//

import SwiftUI

struct SelectedClubView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @State private var commentString: String = ""
    
    var body: some View {
        VStack {
            HStack {
                Image("Artboard8")
                    .resizable().scaledToFit()
                    .clipShape(Circle())
                    .frame(width: 54, height: 54)
                Text("Data interchange")
                    .font(.body.weight(.bold))
                Spacer()
            }
            .padding(.leading, 20)
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    HStack {
                        Text("Andrew  16.34")
                            .font(.body.weight(.bold))
                            .padding(.leading,15)
                        Spacer()
                    }
                    Image("Artboard9")
                        .resizable().scaledToFit()
                        .cornerRadius(15)
                        .frame(height: 191)
                    
                    HStack {
                        Spacer()
                        Text("1 w")
                            .padding(.trailing, 20)
                    }
                }
            }
            HStack {
                Image("microphone-solid")
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                
                TextField("Add a comment", text: $commentString)
                
                Image("paper-plane")
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
            }
            .padding()
            
        }
        //.navigationTitle("Data interchange")
        
    }
}

struct SelectedClubView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SelectedClubView()
                .colorScheme( .light )
                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
            SelectedClubView()
                .colorScheme( .dark )
                .previewDevice(PreviewDevice(rawValue:  "iPhone XS"))
        }
    }
}
