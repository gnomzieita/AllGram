//
//  ImageEditor.swift
//  AllGram
//
//  Created by Alex Pirog on 20.07.2022.
//

import SwiftUI
import Mantis

// Native looking cropping: https://github.com/guoyingtao/Mantis
// Check this one? https://github.com/FluidGroup/Brightroom

struct ImageEditor: UIViewControllerRepresentable {
    typealias Coordinator = ImageEditorCoordinator
    
    let originalImage: UIImage
    let cropHandler: (UIImage) -> Void
    let cancelHandler: () -> Void
    
    func makeCoordinator() -> ImageEditorCoordinator {
        return ImageEditorCoordinator(cropHandler: cropHandler,
                                      cancelHandler: cancelHandler)
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImageEditor>) -> CropViewController {
        let cropVC = Mantis.cropViewController(image: originalImage)
        cropVC.delegate = context.coordinator
        cropVC.modalPresentationStyle = .fullScreen
        return cropVC
    }
}

class ImageEditorCoordinator: NSObject, CropViewControllerDelegate {
    let cropHandler: (UIImage) -> Void
    let cancelHandler: () -> Void
    
    init(cropHandler: @escaping (UIImage) -> Void, cancelHandler: @escaping () -> Void) {
        self.cropHandler = cropHandler
        self.cancelHandler = cancelHandler
    }
    
    // MARK: - CropViewControllerDelegate
    
    func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
        cropHandler(cropped)
    }
    
    func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
        cancelHandler()
    }
    
    // Optional
    func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) { }
    func cropViewControllerDidBeginResize(_ cropViewController: CropViewController) { }
    func cropViewControllerDidEndResize(_ cropViewController: CropViewController, original: UIImage, cropInfo: CropInfo) { }
}
