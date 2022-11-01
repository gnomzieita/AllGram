//
//  HomeBackgroundSettingsView.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 11.01.2022.
//

import SwiftUI
import PhotosUI

struct ImageModel: Identifiable {
    let id: Int
    let imageName: String?
    let image: UIImage?
    
    init(id: Int, imageName: String){
        self.id = id
        self.imageName = imageName
        self.image = nil
    }
    
    init(id: Int, image: UIImage){
        self.id = id
        self.image = image
        self.imageName = nil
    }
}

struct DataModel {
    var images: [ImageModel] = []
    
    mutating func appendImage(imageModel: ImageModel) {
        self.images = self.images + [imageModel]
    }
    
    mutating func removeSavedImages() {
        images = images.filter{ $0.image == nil }
    }
    
    static let initialModel = DataModel(
        images: [
            .init(id: 211, imageName: "backgroundLogo"),
            .init(id: 212, imageName: "backgroundCircles"),
//            .init(id: 221, imageName: "circles-light"),
//            .init(id: 222, imageName: "circles-dark"),
            .init(id: 999, imageName: "homeBackground"),
            .init(id: 101, imageName: "gradient-background1"),
            .init(id: 102, imageName: "gradient-background2"),
            .init(id: 103, imageName: "gradient-background3"),
            .init(id: 104, imageName: "gradient-background4"),
            .init(id: 105, imageName: "gradient-background5"),
            .init(id: 106, imageName: "gradient-background6"),
        ]
    )
}

struct CollectionView: View {
    let image: ImageModel
    
    @State var isSelected: Bool = false
    
    var onTapAction: (() -> ())?
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                if let imageName = self.image.imageName {
                    Image(imageName)
                        .resizable().scaledToFill()
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                        .clipped()
                } else if let image = self.image.image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .foregroundColor(.gray)
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                }
            }
            .overlay(
                Image(systemName: "checkmark")
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .padding(.all, 6)
                    .background(Color.black.opacity(0.3))
                    .opacity(isSelected ? 1 : 0)
                    .clipShape(Circle())
            )
            .onTapGesture {
                onTapAction?()
            }
        }
    }
}

struct HomeBackgroundSettingsView: View {
    @State var updater: Bool = false
    @State var data = DataModel.initialModel
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    @State var selectedImageName: String? = SettingsManager.homeBackgroundImageName {
        didSet{
            SettingsManager.homeBackgroundImageName = selectedImageName
        }
    }
    @State var isShowPicker: Bool = false
    @State var image: Image? = Image("placeholder")
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(data.images) { item in
                            if selectedImageName == item.imageName || (selectedImageName == nil && item.image != nil){
                                CollectionView(image: item, isSelected: true, onTapAction: {
                                    selectedImageName = item.imageName
                                })
                                    .frame(width: geometry.size.width / CGFloat(columns.count), height: geometry.size.width / CGFloat(columns.count) * 1.5)
                            } else {
                                CollectionView(image: item, isSelected: false, onTapAction: {
                                    selectedImageName = item.imageName
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
                    SettingsManager.setHomeBackgroundImage(image)
                    if let image = SettingsManager.getSavedHomeBackgroundImage(){
                        data.images.append(ImageModel(id: nextImageId, image: image))
                    }
                    selectedImageName = nil
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
        .navigationTitle(Text("Home Background"))
        .onAppear {
            let nextImageId = (data.images.last?.id ?? -1) + 1
            data.removeSavedImages()
            if let image = SettingsManager.getSavedHomeBackgroundImage(){
                data.images.append(ImageModel(id: nextImageId, image: image))
            }
            selectedImageName = SettingsManager.homeBackgroundImageName
        }
    }
}

struct HomeBackgroundSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        HomeBackgroundSettingsView()
    }
}
