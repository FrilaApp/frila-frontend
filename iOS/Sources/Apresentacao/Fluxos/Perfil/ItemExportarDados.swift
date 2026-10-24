import FrilaDominio
import SwiftUI
import UIKit

public struct FolhaCompartilhamento: UIViewControllerRepresentable {
    public let url: URL
    public let aoConcluirAtividade: ((_ concluida: Bool) -> Void)?

    public init(url: URL, aoConcluirAtividade: ((_ concluida: Bool) -> Void)? = nil) {
        self.url = url
        self.aoConcluirAtividade = aoConcluirAtividade
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            aoConcluirAtividade?(completed)
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.popoverPresentationController?.sourceView = UIView()
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Linha "Exportar meus dados" (#24), na lista aberta do perfil; abre o compartilhar do iPhone.
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
                if viewModel.estaCarregando {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Text(verbatim: TextosExportarDados.titulo)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: FrilaEspaco.pequeno)
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityIdentifier("progresso-exportar-dados")
                    }
                    .padding(.vertical, FrilaEspaco.minimo)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                    .contentShape(Rectangle())
                } else {
                    RotuloDeLinha(TextosExportarDados.titulo)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.estaCarregando)
            .accessibilityIdentifier(identificador)
            .accessibilityLabel(TextosExportarDados.titulo)
            .accessibilityHint(TextosExportarDados.dicaAcessibilidade)

            Text(verbatim: TextosExportarDados.explicacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, FrilaEspaco.compacto)
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
                FolhaCompartilhamento(url: url) { concluida in
                    viewModel.atividadeCompartilhamentoConcluida(concluida: concluida)
                }
            }
        }
    }
}
