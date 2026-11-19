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
/// A linha é a do grupo da Conta (a mesma `RotuloDeLinha` das vizinhas); o que muda é o que vem junto: enquanto o
/// arquivo é gerado, o rótulo passa a `textoSecundario` e a linha fica desligada (sem indicador girando), a explicação
/// vai em apoio e o erro em `MensagemJuntoAoBotao`, logo abaixo da linha que o provocou.
public struct ItemExportarDados: View {
    @Bindable private var viewModel: ExportarDadosViewModel
    private let identificador: String

    public init(viewModel: ExportarDadosViewModel, identificador: String) {
        self.viewModel = viewModel
        self.identificador = identificador
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Button {
                Task { await viewModel.exportarDados() }
            } label: {
                RotuloDeLinha(TextosExportarDados.titulo)
                    .opacity(viewModel.estaCarregando ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.estaCarregando)
            .accessibilityIdentifier(identificador)
            .accessibilityLabel(TextosExportarDados.titulo)
            .accessibilityHint(TextosExportarDados.dicaAcessibilidade)

            if viewModel.estaCarregando {
                // O "em andamento" do toque: sem indicador girando, a linha esmaece e este elemento mínimo avisa o
                // leitor de tela e os testes de que o arquivo está sendo gerado.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Carregando", bundle: bundleApresentacao))
                    .accessibilityIdentifier("progresso-exportar-dados")
            }

            Text(verbatim: TextosExportarDados.explicacao)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, FrilaEspaco.item)
                .accessibilityIdentifier("\(identificador)-explicacao")

            if let erro = viewModel.mensagemErro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .padding(.bottom, FrilaEspaco.item)
                    .accessibilityIdentifier("aviso-erro-exportar-dados")
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
