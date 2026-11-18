import FrilaDominio
import SwiftUI

/// Trocar de casa, para quem cuida de mais de uma: a lista é a de `meus_estabelecimentos`, lida de novo a cada abertura, com a
/// casa em uso marcada. Escolher só diz ao app de qual casa falar agora; não há chamada de troca.
public struct TelaTrocarDeCasa: View {
    @State private var modelo: TrocarDeCasaViewModel
    private let casaEmUso: UUID?
    private let aoEscolher: (UUID) -> Void

    public init(modelo: TrocarDeCasaViewModel, casaEmUso: UUID?, aoEscolher: @escaping (UUID) -> Void) {
        _modelo = State(initialValue: modelo)
        self.casaEmUso = casaEmUso
        self.aoEscolher = aoEscolher
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosDaEquipeDaCasa.trocarTitulo)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: TextosDaEquipeDaCasa.trocarExplicacao)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                switch modelo.estado {
                case .carregando:
                    EstadoCarregando()
                case .erro:
                    EstadoErro(verbatim: TextosDaEquipeDaCasa.trocarFalha) { Task { await modelo.carregar() } }
                        .accessibilityIdentifier("trocar-casa-erro")
                case let .conteudo(casas):
                    FrilaGrupoDeLinhas(linhasComIcone: false) {
                        ForEach(casas) { casa in
                            FrilaLinhaDeOpcao(titulo: casa.nome, subtitulo: casa.papel.rotuloDaEquipe, remate: .marcada(casa.id == casaEmUso)) {
                                aoEscolher(casa.id)
                            }
                            .accessibilityIdentifier("trocar-casa-\(casa.id.uuidString.lowercased())")
                        }
                    }
                    .accessibilityIdentifier("trocar-casa-lista")
                }
            }
            .padding(.horizontal, FrilaEspaco.bloco)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.horizontal)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text(verbatim: TextosDaEquipeDaCasa.trocarTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await modelo.carregar() }
        .accessibilityIdentifier("tela-trocar-de-casa")
    }
}
