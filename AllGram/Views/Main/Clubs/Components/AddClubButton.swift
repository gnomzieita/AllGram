//
//  AddClubButton.swift
//  AllGram
//
//  Created by Igor Antonchenko on 02.02.2022.
//

import SwiftUI
import MatrixSDK

struct AddClubButton: View {
    
    @ObservedObject var authViewModel = AuthViewModel.shared

    @State private var buttonIsPressed: Bool = false
    
    var body: some View {
        VStack{
            Spacer()
            HStack{
                Spacer()
                Button {
                    self.buttonIsPressed.toggle()
                } label: {
                    ZStack{
                        Circle()
                            .fill(Color.pink)
                        GeometryReader{ geometry in
                            VStack{
                                Spacer()
                                HStack{
                                    Spacer()
                                    Image("comment-medical-solid")
                                        .renderingMode(.template)
                                        .resizable()
                                        .foregroundColor(.white)
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width / 2, height: geometry.size.height / 2)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }
                }
                //  .frame(width: self.showNewConversationBtn ? 50 : 0, height: self.showNewConversationBtn ? 50 : 0)
                .frame(width: 50, height: 50)
                .padding()
            }
        }
        .sheet(isPresented: $buttonIsPressed) {
            AddClubView(session: authViewModel.session)
        }
    }
}

//struct AddClubButton_Previews: PreviewProvider {
//    static var previews: some View {
//        AddClubButton()
//    }
//}
