import Foundation
import FrilaDominio
import SwiftUI

/// A escala de evento a partir de Minhas vagas. Lê o cadastro da casa (endereço, região e ponto, que valem para todas as
/// vagas da escala) com prazo e erro com "Tentar de novo", e abre a tela da escala. O modelo da escala vem da
/// `GuardaDaEscala`: cancelar com uma tentativa incerta não perde a chave, e a tela reaberta avisa e reenvia a mesma escala.
struct DestinoDePublicarEscala: View {
    @State private var cadastro: CadastroDaCasaDaEscala
    private let api: any ApiCliente
    private let guarda: GuardaDaEscala
    private let aoConcluir: () -> Void
    private let aoCancelar: () -> Void

    init(
        api: any ApiCliente, estabelecimentoID: UUID, guarda: GuardaDaEscala,
        aoConcluir: @escaping () -> Void, aoCancelar: @escaping () -> Void
    ) {
        _cadastro = State(initialValue: CadastroDaCasaDaEscala(api: api, estabelecimentoID: estabelecimentoID))
        self.api = api
        self.guarda = guarda
        self.aoConcluir = aoConcluir
        self.aoCancelar = aoCancelar
    }

    var body: some View {
        Group {
            switch cadastro.estado {
            case .carregando:
                saida { EstadoCarregando() }
            case let .pronta(estabelecimento):
                EscalaDaCasa(
                    api: api, estabelecimento: estabelecimento, guarda: guarda,
                    aoConcluir: { guarda.aoSair(); aoConcluir() },
                    aoCancelar: { guarda.aoSair(); aoCancelar() }
                )
            case let .erro(mensagem):
                saida {
                    EstadoErro(verbatim: mensagem) { Task { await cadastro.carregar() } }
                        .accessibilityIdentifier("publicar-escala-erro")
                }
            }
        }
        .task { await cadastro.carregar() }
    }

    private func saida<Conteudo: View>(@ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        ScrollView {
            VStack(spacing: FrilaEspaco.medio) {
                conteudo()
                BotaoSecundario(verbatim: TextosDaEscala.voltar, acao: aoCancelar)
                    .accessibilityIdentifier("voltar-para-minhas-vagas")
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
    }
}

/// Pega o `PublicarEscalaViewModel` da guarda: o mesmo de antes, com o rascunho e a chave, se a última tentativa ficou incerta.
private struct EscalaDaCasa: View {
    @State private var modelo: PublicarEscalaViewModel
    private let aoConcluir: () -> Void
    private let aoCancelar: () -> Void

    init(
        api: any ApiCliente, estabelecimento: Estabelecimento, guarda: GuardaDaEscala,
        aoConcluir: @escaping () -> Void, aoCancelar: @escaping () -> Void
    ) {
        _modelo = State(initialValue: guarda.obter { PublicarEscalaViewModel(api: api, estabelecimento: estabelecimento) })
        self.aoConcluir = aoConcluir
        self.aoCancelar = aoCancelar
    }

    var body: some View {
        TelaPublicarEscala(modelo: modelo, aoConcluir: aoConcluir, aoCancelar: aoCancelar)
    }
}
