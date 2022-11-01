//
//  HelpView.swift
//  AllGram
//
//  Created by Ярослав Шерстюк on 10.09.2021.
//

import SwiftUI

struct HelpView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            //TODO: Add Search bar https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-a-search-bar-to-filter-your-data
            List {
                
                Section(header: Text("Popular")) {
                    ItemView(iconItem: "note.text", textItem: "How to create a club?")
                    ItemView(iconItem: "note.text", textItem: "How to join a meeting?")
                    ItemView(iconItem: "note.text", textItem: "How to record a meeting?")
                    ItemView(iconItem: "note.text", textItem: "How do I activate a digital wallet?")
                    
                }
                
                Section {
                    Button(action: {
                        
                    }, label: {
                        Text("Browse all articles")
                    })
                    
                }
                
                Section(header: Text("Contact us")) {
                    ItemView(iconItem: "headphones", textItem: "Request callback")
                    ItemView(iconItem: "exclamationmark.bubble.fill", textItem: "Send feedback")
                }
            }.listStyle(InsetGroupedListStyle()) // this has been renamed in iOS 14.*, as mentioned by @Elijah Yap
            .environment(\.horizontalSizeClass, .regular)
            
            
            .navigationTitle(Text("Help"))
            .navigationBarTitleDisplayMode(.inline)
            .ourToolbar(
                leading:
                    Button(action: {
                        self.presentationMode.projectedValue.wrappedValue.dismiss()
                    }, label: {
                        Text("Cancel")
                    })
                ,
                trailing:
                    Button(action: {
                        //...
                    }, label: {
                        Image(systemName: "ellipsis").rotationEffect(Angle(degrees: 90))
                    })
            )
            
        }
        
    }
}

struct ItemView: View {
    
    @State var iconItem: String
    @State var textItem: String
    
    var body: some View {
        
        HStack {
            Image(systemName: iconItem)
            Text(textItem)
        }
        
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
