import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// O QR do código de check-in. Carrega exatamente os 6 dígitos e nada mais: é a mesma credencial do código
/// digitado, validada no mesmo ponto (contrato 0.2.68). CoreImage do sistema, sem dependência nova.
enum GeradorDeQRCode {
    static func imagem(para texto: String, escala: CGFloat = 10) -> UIImage? {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"
        guard let saida = filtro.outputImage else { return nil }
        let ampliada = saida.transformed(by: CGAffineTransform(scaleX: escala, y: escala))
        guard let imagem = CIContext().createCGImage(ampliada, from: ampliada.extent) else { return nil }
        return UIImage(cgImage: imagem)
    }

    /// Lê de volta o texto de um QR: os testes conferem que o que sai é o que a câmera vai ler.
    static func texto(de imagem: UIImage) -> String? {
        guard let ci = CIImage(image: imagem),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        else { return nil }
        return (detector.features(in: ci).first as? CIQRCodeFeature)?.messageString
    }
}
