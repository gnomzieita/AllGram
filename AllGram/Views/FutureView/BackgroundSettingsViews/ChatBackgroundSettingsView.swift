//
//  ChatBackgroundSettingsView.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 11.01.2022.
//

import SwiftUI
import PhotosUI

struct ChatBackgroundSettingsView: View {
    @State var data = DataModel.initialModel
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    @State var selectedImageName: String? = SettingsManager.chatBackgroundImageName {
        didSet{
            SettingsManager.chatBackgroundImageName = selectedImageName
        }
    }
    @State var isShowPicker: Bool = false
    @State var image: Image? = Image("placeholder")
    
    @State var useImageForChatBackground = SettingsManager.useImageForChatBackground {
        didSet {
            SettingsManager.useImageForChatBackground = useImageForChatBackground
        }
    }
    
    var body: some View {
        GeometryReader {
            geometry in
            VStack{
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(data.images) { item in
                            if selectedImageName == item.imageName && useImageForChatBackground{
                                CollectionView(image: item, isSelected: true, onTapAction: {
                                    selectedImageName = nil
                                    useImageForChatBackground = false
                                })
                                    .frame(width: geometry.size.width / CGFloat(columns.count), height: geometry.size.width / CGFloat(columns.count) * 1.5)
                            } else {
                                CollectionView(image: item, isSelected: false, onTapAction: {
                                    selectedImageName = item.imageName
                                    useImageForChatBackground = true
                                })
                                    .frame(width: geometry.size.width / CGFloat(columns.count), height: geometry.size.width / CGFloat(columns.count) * 1.5)
                            }
                            
                        }
                    }
                }
                .padding(.top, 1)
                ExpandingHStack(contentPosition: .left()) {
                    Button {
                        withAnimation { isShowPicker.toggle() }
                    } label: {
                        MoreOptionView(flat: "Select from gallery", imageName: "images-solid")
                            .padding(.horizontal)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color.moreItemColor)
                )
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal)
        .background(Color.moreBackColor.ignoresSafeArea())
        .sheet(isPresented: $isShowPicker) {
            ImagePicker(
                sourceType: .photoLibrary,
                onImagePicked: { image in
                    let nextImageId = (data.images.last?.id ?? -1) + 1
                    data.removeSavedImages()
                    SettingsManager.setChatBackgroundImage(image)
                    if let image = SettingsManager.getSavedChatBackgroundImage(){
                        data.images.append(ImageModel(id: nextImageId, image: image))
                    }
                    selectedImageName = nil
                    useImageForChatBackground = true
                }
            )
        }
        .onChange(of: isShowPicker) { show in
            if show {
                // Set to accent (as app wide color invisible on light scheme)
                UINavigationBar.appearance().tintColor = Color.accentColor.uiColor
            } else {
                // Reset to app wide tint color
                UINavigationBar.appearance().tintColor = .white
            }
        }
        .navigationTitle(Text("Chat Background"))
        .onAppear {
            let nextImageId = (data.images.last?.id ?? -1) + 1
            data.removeSavedImages()
            if let image = SettingsManager.getSavedChatBackgroundImage(){
                data.images.append(ImageModel(id: nextImageId, image: image))
            }
            selectedImageName = SettingsManager.chatBackgroundImageName
        }
    }
}

struct ChatBackgroundSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatBackgroundSettingsView()
    }
}
