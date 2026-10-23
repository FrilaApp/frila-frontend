import FrilaDominio
import SwiftUI

/// Entrada do enxerto do estúdio (só DEBUG, `-FRILA_ENXERTO_LOWPHASE_ESTUDIO`): carrega as funções
/// do servidor e abre o `FrilaLPEJobCreationStudioView` com a publicação do app.
struct TelaEstudioFrilaLPE: View {
    @State private var formulario: FormularioEstudioFrilaLPE
    @State private var catalogoPronto = false
    private let aoPublicar: () -> Void
    private let aoCancelar: () -> Void

    init(api: any ApiCliente, fila: any FilaDeAcoes, estabelecimento: Estabelecimento, aoPublicar: @escaping () -> Void, aoCancelar: @escaping () -> Void) {
        _formulario = State(initialValue: FormularioEstudioFrilaLPE(vaga: PublicarVagaViewModel(api: api, fila: fila, estabelecimento: estabelecimento)))
        self.aoPublicar = aoPublicar
        self.aoCancelar = aoCancelar
    }

    var body: some View {
        Group {
            if catalogoPronto {
                FrilaLPEJobCreationStudioView(
                    initialDraft: formulario.rascunhoInicial,
                    onPublish: { _ in aoPublicar() },
                    onDismiss: aoCancelar,
                    publicar: { await formulario.publicar($0) }
                )
            } else if let erro = formulario.vaga.mensagemErro {
                EstadoErro(verbatim: erro) { Task { await carregar() } }
            } else {
                ProgressView()
            }
        }
        .task { await carregar() }
    }

    private func carregar() async {
        await formulario.vaga.restaurarPublicacaoPendente()
        await formulario.vaga.carregarFuncoes()
        guard !formulario.vaga.funcoes.isEmpty else { return }
        formulario.usarFuncoesNoCatalogo()
        catalogoPronto = true
    }
}
