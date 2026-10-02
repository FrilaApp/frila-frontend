import FrilaDominio
import SwiftUI
import UIKit

public struct FolhaCompartilhamento: UIViewControllerRepresentable {
    public let url: URL
    public let aoConcluir: (() -> Void)?

    public init(url: URL, aoConcluir: (() -> Void)? = nil) {
        self.url = url
        self.aoConcluir = aoConcluir
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            aoConcluir?()
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.popoverPresentationController?.sourceView = UIView()
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct ItemExportarDados: View {
    @Bindable private var viewModel: ExportarDadosViewModel
    private let identificador: String

    public init(viewModel: ExportarDadosViewModel, identificador: String) {
        self.viewModel = viewModel
        self.identificador = identificador
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Button {
                Task { await viewModel.exportarDados() }
            } label: {
                HStack(spacing: FrilaEspaco.pequeno) {
                    Label {
                        Text(verbatim: TextosExportarDados.titulo)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    if viewModel.estaCarregando {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityIdentifier("progresso-exportar-dados")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                .contentShape(Rectangle())
            }
            .disabled(viewModel.estaCarregando)
            .accessibilityIdentifier(identificador)
            .accessibilityLabel(TextosExportarDados.titulo)
            .accessibilityHint(TextosExportarDados.dicaAcessibilidade)

            Text(verbatim: TextosExportarDados.explicacao)
                .font(.caption)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(identificador)-explicacao")

            if let erro = viewModel.mensagemErro {
                AvisoFrila(verbatim: erro, tom: .erro)
                    .accessibilityIdentifier("aviso-erro-exportar-dados")
                    .padding(.top, FrilaEspaco.minimo)
            }
        }
        .sheet(isPresented: $viewModel.mostrarFolhaCompartilhamento, onDismiss: {
            viewModel.folhaCompartilhamentoFechada()
        }) {
            if let url = viewModel.arquivoParaCompartilhar {
                FolhaCompartilhamento(url: url) {
                    viewModel.folhaCompartilhamentoFechada()
                }
            }
        }
    }
}
