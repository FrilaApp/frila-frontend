import FrilaDominio
import SwiftUI

// O texto abaixo ainda não tem decisão jurídica nova: o contrato 0.2.90 só diz que a busca pede o aceite e o repete
// depois. O desenho é o do sistema do Fabrício, extrapolado para a casa (R6); o nome do tipo ficou, para não mexer no
// projeto e nos testes.

/// O que a busca de profissionais mostra no estado `termosPendentes` (contrato 0.2.90): pede o aceite dos Termos
/// de Uso atualizados, chama `aceitar_termos` e repete a busca com os mesmos filtros. Erro no aceite: mensagem logo
/// acima do botão, e a busca continua bloqueada.
public struct TelaAceiteDeTermosProvisoria: View {
    @Environment(\.openURL) private var abrirEndereco
    private let aceitando: Bool
    private let erroNoAceite: Bool
    private let termosDeUso: URL
    private let politicaDePrivacidade: URL
    private let aceitar: () -> Void

    public init(aceitando: Bool, erroNoAceite: Bool, termosDeUso: URL = EnderecosOficiais.padrao.termosDeUso,
                politicaDePrivacidade: URL = EnderecosOficiais.padrao.politicaDePrivacidade,
                aceitar: @escaping () -> Void) {
        self.aceitando = aceitando
        self.erroNoAceite = erroNoAceite
        self.termosDeUso = termosDeUso
        self.politicaDePrivacidade = politicaDePrivacidade
        self.aceitar = aceitar
    }

    /// A ligação com o ViewModel da busca: o toque em Aceitar vira `aceitarTermosERepetirABusca()`.
    public init(modelo: BuscaDeProfissionaisViewModel) {
        self.init(aceitando: modelo.aceitandoTermos, erroNoAceite: modelo.erroNoAceiteDosTermos) {
            Task { await modelo.aceitarTermosERepetirABusca() }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text("Para continuar, leia e aceite os Termos de Uso e a Política de Privacidade.", bundle: bundleApresentacao)
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("aceite-termos-titulo")

            // Links para as páginas públicas: em tinta, sublinhados, com alvo de 48 pt.
            VStack(alignment: .leading, spacing: 0) {
                Button { abrirEndereco(termosDeUso) } label: {
                    Text("Ler os Termos de Uso", bundle: bundleApresentacao)
                }
                .buttonStyle(.frilaLink)
                .accessibilityAddTraits(.isLink)
                .accessibilityIdentifier("aceite-termos-link")

                // O aceite grava a versão 2026-11-16, que cobre os Termos 1.2 E a Política 1.3: a pessoa vê os dois.
                Button { abrirEndereco(politicaDePrivacidade) } label: {
                    Text("Política de privacidade", bundle: bundleApresentacao)
                }
                .buttonStyle(.frilaLink)
                .accessibilityAddTraits(.isLink)
                .accessibilityIdentifier("aceite-politica-link")
            }

            // O erro da ação fica logo acima do botão que a disparou (D-DS-13): sem vermelho, em tinta.
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                if erroNoAceite {
                    MensagemJuntoAoBotao(verbatim: String(localized: "Não foi possível registrar o aceite. Tente de novo.", bundle: bundleApresentacao))
                        .accessibilityIdentifier("aceite-termos-erro")
                }
                BotaoPrimario("Aceitar", carregando: aceitando) { aceitar() }
                    .accessibilityIdentifier("aceite-termos-aceitar")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
