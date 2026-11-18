import FrilaDominio
import SwiftUI

/// A escala de evento a partir de Minhas vagas. Lê o cadastro da casa (endereço, região e ponto, que valem para todas as
/// vagas da escala) pelo mesmo `PublicacaoDaCasaViewModel` da publicação de uma vaga, e abre a tela da escala.
struct DestinoDePublicarEscala: View {
    private let api: any ApiCliente
    private let modelo: PublicacaoDaCasaViewModel
    private let aoConcluir: () -> Void
    private let aoCancelar: () -> Void

    init(api: any ApiCliente, modelo: PublicacaoDaCasaViewModel, aoConcluir: @escaping () -> Void, aoCancelar: @escaping () -> Void) {
        self.api = api
        self.modelo = modelo
        self.aoConcluir = aoConcluir
        self.aoCancelar = aoCancelar
    }

    var body: some View {
        Group {
            switch modelo.estado {
            case .carregando:
                saida { EstadoCarregando() }
            case let .pronta(estabelecimento, _):
                EscalaDaCasa(api: api, estabelecimento: estabelecimento, aoConcluir: aoConcluir, aoCancelar: aoCancelar)
            case let .erro(mensagem):
                saida {
                    EstadoErro(verbatim: mensagem) { Task { await modelo.carregar() } }
                        .accessibilityIdentifier("publicar-escala-erro")
                }
            }
        }
        .task { await modelo.carregar() }
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

/// Guarda o `PublicarEscalaViewModel` desta abertura: a tela relê o cadastro sem perder o que a pessoa já preencheu.
private struct EscalaDaCasa: View {
    @State private var modelo: PublicarEscalaViewModel
    private let aoConcluir: () -> Void
    private let aoCancelar: () -> Void

    init(api: any ApiCliente, estabelecimento: Estabelecimento, aoConcluir: @escaping () -> Void, aoCancelar: @escaping () -> Void) {
        _modelo = State(initialValue: PublicarEscalaViewModel(api: api, estabelecimento: estabelecimento))
        self.aoConcluir = aoConcluir
        self.aoCancelar = aoCancelar
    }

    var body: some View {
        TelaPublicarEscala(modelo: modelo, aoConcluir: aoConcluir, aoCancelar: aoCancelar)
    }
}
