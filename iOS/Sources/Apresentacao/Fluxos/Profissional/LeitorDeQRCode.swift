import AVFoundation
import FrilaDominio
import SwiftUI
import VisionKit

/// A permissão da câmera para ler o QR da casa. Negada, a leitura cai para a digitação, sem bloquear nada.
enum PermissaoDaCamera {
    enum Estado: Equatable {
        case liberada
        case negada
        case naoPerguntada
    }

    static var estado: Estado {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .liberada
        case .notDetermined: .naoPerguntada
        case .denied, .restricted: .negada
        @unknown default: .negada
        }
    }

    /// Pergunta uma vez, só quando a pessoa toca em "Ler o QR".
    static func pedir() async -> Estado {
        guard estado == .naoPerguntada else { return estado }
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return estado
    }
}

/// A câmera lendo um QR (VisionKit, do sistema). Entrega só o texto de um QR com exatamente 6 dígitos:
/// qualquer outro QR é ignorado, e nada sai do aparelho.
struct LeitorDeQRCode: UIViewControllerRepresentable {
    let aoLer: (String) -> Void

    /// `false` no simulador e em aparelho sem câmera ou sem o leitor: a tela só oferece a digitação.
    static var disponivel: Bool { DataScannerViewController.isSupported }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let leitor = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: false,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        leitor.delegate = context.coordinator
        try? leitor.startScanning()
        return leitor
    }

    func updateUIViewController(_ leitor: DataScannerViewController, context: Context) {
        context.coordinator.aoLer = aoLer
    }

    static func dismantleUIViewController(_ leitor: DataScannerViewController, coordinator: Coordinator) {
        leitor.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(aoLer: aoLer) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var aoLer: (String) -> Void
        private var jaLeu = false

        init(aoLer: @escaping (String) -> Void) { self.aoLer = aoLer }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !jaLeu else { return }
            for item in addedItems {
                if case let .barcode(codigo) = item, let texto = codigo.payloadStringValue, ValidacaoDoCodigoViewModel.formatoValido(texto) {
                    jaLeu = true
                    aoLer(texto)
                    return
                }
            }
        }
    }
}
