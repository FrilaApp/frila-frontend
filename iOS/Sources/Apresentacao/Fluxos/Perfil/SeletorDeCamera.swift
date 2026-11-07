import SwiftUI
import UIKit

/// Seletor de câmera do sistema para captura da foto de perfil.
/// Encapsula UIImagePickerController configurado para câmera (preferencialmente frontal).
public struct SeletorDeCamera: UIViewControllerRepresentable {
    public let aoCapturar: (Data) -> Void
    public let aoCancelar: () -> Void

    public init(aoCapturar: @escaping (Data) -> Void, aoCancelar: @escaping () -> Void) {
        self.aoCapturar = aoCapturar
        self.aoCancelar = aoCancelar
    }

    public static var cameraDisponivel: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(aoCapturar: aoCapturar, aoCancelar: aoCancelar)
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            if UIImagePickerController.isCameraDeviceAvailable(.front) {
                picker.cameraDevice = .front
            }
        }
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let aoCapturar: (Data) -> Void
        private let aoCancelar: () -> Void

        init(aoCapturar: @escaping (Data) -> Void, aoCancelar: @escaping () -> Void) {
            self.aoCapturar = aoCapturar
            self.aoCancelar = aoCancelar
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let imagem = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
                  let jpeg = imagem.jpegData(compressionQuality: 0.95) else {
                aoCancelar()
                return
            }
            aoCapturar(jpeg)
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            aoCancelar()
        }
    }
}
