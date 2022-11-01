import SwiftUI
import AVKit

/// Allows to pick images and videos from users gallery, albums
struct ImagePicker: UIViewControllerRepresentable {
    typealias ImageHandler = (_ image: UIImage) -> Void
    typealias VideoHandler = (_ url: URL, _ thumbnail: UIImage?) -> Void
    
    @Environment(\.presentationMode) private var presentationMode
    
    let sourceType: UIImagePickerController.SourceType
    let restrictToImagesOnly: Bool
    let allowDefaultEditing: Bool
    let createVideoThumbnail: Bool
    
    let onImagePicked: ImageHandler
    let onVideoPicked: VideoHandler
    
    init(sourceType: UIImagePickerController.SourceType,
         restrictToImagesOnly: Bool = false,
         allowDefaultEditing: Bool = true,
         createVideoThumbnail: Bool = true,
         onImagePicked: ImageHandler? = nil,
         onVideoPicked: VideoHandler? = nil
    ) {
        self.sourceType = sourceType
        self.restrictToImagesOnly = restrictToImagesOnly
        self.allowDefaultEditing = allowDefaultEditing
        self.createVideoThumbnail = createVideoThumbnail
        self.onImagePicked = onImagePicked ?? { _ in }
        self.onVideoPicked = onVideoPicked ?? { _, _ in }
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        
        @Binding private var presentationMode: PresentationMode
        private let sourceType: UIImagePickerController.SourceType
        private let restrictToImagesOnly: Bool
        private let allowDefaultEditing: Bool
        private let createVideoThumbnail: Bool
        private let onImagePicked: (UIImage) -> Void
        private let onVideoPicked: (URL) -> Void
        
        init(presentationMode: Binding<PresentationMode>,
             sourceType: UIImagePickerController.SourceType,
             restrictToImagesOnly: Bool,
             allowDefaultEditing: Bool,
             createVideoThumbnail: Bool,
             onImagePicked: @escaping (UIImage) -> Void,
             onVideoPicked: @escaping (URL) -> Void
        ) {
            _presentationMode = presentationMode
            self.sourceType = sourceType
            self.restrictToImagesOnly = restrictToImagesOnly
            self.allowDefaultEditing = allowDefaultEditing
            self.createVideoThumbnail = createVideoThumbnail
            self.onImagePicked = onImagePicked
            self.onVideoPicked = onVideoPicked
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onImagePicked(uiImage)
            } else if let videoURL = info[.mediaURL] as? URL {
                onVideoPicked(videoURL)
            }
            presentationMode.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            presentationMode.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(
            presentationMode: presentationMode,
            sourceType: sourceType,
            restrictToImagesOnly: restrictToImagesOnly,
            allowDefaultEditing: allowDefaultEditing,
            createVideoThumbnail: createVideoThumbnail,
            onImagePicked: { image in
                onImagePicked(image)
            },
            onVideoPicked: { url in
                var thumbnail: UIImage?
                if createVideoThumbnail {
                    do {
                        let asset = AVURLAsset(url: url, options: nil)
                        let imgGenerator = AVAssetImageGenerator(asset: asset)
                        imgGenerator.appliesPreferredTrackTransform = true
                        let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
                        thumbnail = UIImage(cgImage: cgImage)
                    } catch  {
                        
                    }
                }
                onVideoPicked(url, thumbnail)
            }
        )
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.allowsEditing = allowDefaultEditing
        picker.sourceType = sourceType
        // Accepts only images by default
        if !restrictToImagesOnly {
            picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: sourceType) ?? []
        }
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) { }
}
