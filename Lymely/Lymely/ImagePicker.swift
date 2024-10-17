import SwiftUI
import UIKit
import CoreML
import Vision

/// A SwiftUI view that wraps UIImagePickerController to allow users to pick or take photos,
/// and then classifies the selected image using a Core ML model.
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var classificationLabel: String
    @Binding var isCamera: Bool

    /// Creates and returns a coordinator to manage the UIImagePickerController.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Coordinator class to handle the UIImagePickerControllerDelegate methods.
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        /// Called when the user selects an image from the picker.
        /// - Parameters:
        ///   - picker: The image picker controller.
        ///   - info: A dictionary containing the original image.
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                classifyImage(uiImage)
            }
            picker.dismiss(animated: true)
        }

        /// Classifies the given image using the LymeRashClassifier Core ML model.
        /// - Parameter image: The UIImage to be classified.
        func classifyImage(_ image: UIImage) {
            guard let model = try? LymeRashClassifier(configuration: MLModelConfiguration()).model else {
                parent.classificationLabel = "Failed to load model"
                return
            }

            guard let ciImage = CIImage(image: image) else {
                parent.classificationLabel = "Invalid image"
                return
            }

            let request = VNCoreMLRequest(model: try! VNCoreMLModel(for: model)) { [weak self] request, error in
                guard let self = self else { return }

                if let results = request.results as? [VNClassificationObservation],
                   let firstResult = results.first {
                    let confidencePercentage = Int(firstResult.confidence * 100)
                    let classification = firstResult.identifier == "Lyme_Positive" ? "a Lyme disease rash" : "not a Lyme disease rash"

                    DispatchQueue.main.async {
                        self.parent.classificationLabel = "We're \(confidencePercentage)% confident that this is \(classification)."
                    }
                } else {
                    DispatchQueue.main.async {
                        self.parent.classificationLabel = "Could not classify the image."
                    }
                }
            }

            let handler = VNImageRequestHandler(ciImage: ciImage)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    DispatchQueue.main.async {
                        self.parent.classificationLabel = "Error performing classification."
                    }
                }
            }
        }
    }

    /// Creates and returns a UIImagePickerController configured with the appropriate source type.
    /// - Parameter context: The context in which this view controller is created.
    /// - Returns: A configured UIImagePickerController.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = isCamera ? .camera : .photoLibrary
        return picker
    }

    /// Updates the view controller if needed. This method is left empty as the picker doesn't need updating.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
