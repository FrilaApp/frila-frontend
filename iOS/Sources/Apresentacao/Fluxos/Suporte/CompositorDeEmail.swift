import SwiftUI
import UIKit
#if canImport(MessageUI)
import MessageUI

/// Representable para apresentar o compositor nativo de e-mail do iOS (MFMailComposeViewController).
public struct CompositorDeEmailNativo: UIViewControllerRepresentable {
    public let destinatarios: [String]
    public let assunto: String
    public let corpo: String
    public let aoConcluir: (@Sendable (Result<MFMailComposeResult, any Error>) -> Void)?

    public init(
        destinatarios: [String],
        assunto: String,
        corpo: String,
        aoConcluir: (@Sendable (Result<MFMailComposeResult, any Error>) -> Void)? = nil
    ) {
        self.destinatarios = destinatarios
        self.assunto = assunto
        self.corpo = corpo
        self.aoConcluir = aoConcluir
    }

    public static var podeEnviarEmail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(aoConcluir: aoConcluir)
    }

    public func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let compositor = MFMailComposeViewController()
        compositor.mailComposeDelegate = context.coordinator
        compositor.setToRecipients(destinatarios)
        compositor.setSubject(assunto)
        compositor.setMessageBody(corpo, isHTML: false)
        return compositor
    }

    public func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    public final class Coordinator: NSObject, MFMailComposeViewControllerDelegate, Sendable {
        private let aoConcluir: (@Sendable (Result<MFMailComposeResult, any Error>) -> Void)?

        init(aoConcluir: (@Sendable (Result<MFMailComposeResult, any Error>) -> Void)?) {
            self.aoConcluir = aoConcluir
            super.init()
        }

        public func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: (any Error)?
        ) {
            controller.dismiss(animated: true) { [aoConcluir] in
                if let error {
                    aoConcluir?(.failure(error))
                } else {
                    aoConcluir?(.success(result))
                }
            }
        }
    }
}
#else
public struct CompositorDeEmailNativo: View {
    public static var podeEnviarEmail: Bool { false }
    public init(
        destinatarios: [String],
        assunto: String,
        corpo: String,
        aoConcluir: (@Sendable (Result<Void, any Error>) -> Void)? = nil
    ) {}
    public var body: some View {
        EmptyView()
    }
}
#endif
