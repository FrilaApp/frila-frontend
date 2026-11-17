import FrilaDominio
import SwiftUI

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício.
// Só componentes nativos, sem estilo novo e sem componente novo do design system. O texto abaixo também é
// provisório (sem decisão jurídica nova): o contrato 0.2.90 só diz que a busca pede o aceite e o repete depois.

/// O que a busca de profissionais mostra no estado `termosPendentes` (contrato 0.2.90): pede o aceite dos Termos
/// de Uso atualizados, chama `aceitar_termos` e repete a busca com os mesmos filtros. Erro no aceite: aviso, e a
/// busca continua bloqueada.
public struct TelaAceiteDeTermosProvisoria: View {
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
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Text("Para continuar, leia e aceite os Termos de Uso e a Política de Privacidade.", bundle: bundleApresentacao)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("aceite-termos-titulo")

            Link(destination: termosDeUso) {
                Text("Ler os Termos de Uso", bundle: bundleApresentacao)
                    .frame(minHeight: 44, alignment: .leading)
            }
            // Na linha do Form da busca, só o próprio link abre os Termos (sem estilo, a linha inteira abriria).
            .buttonStyle(.borderless)
            .accessibilityIdentifier("aceite-termos-link")

            // O aceite grava a versão 2026-11-16, que cobre os Termos 1.2 E a Política 1.3: a pessoa vê os dois.
            Link(destination: politicaDePrivacidade) {
                Text("Política de privacidade", bundle: bundleApresentacao)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("aceite-politica-link")

            if erroNoAceite {
                Text("Não foi possível registrar o aceite. Tente de novo.", bundle: bundleApresentacao)
                    .font(.footnote)
                    .foregroundStyle(FrilaCor.perigo)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("aceite-termos-erro")
            }

            Button(action: aceitar) {
                Group {
                    if aceitando {
                        ProgressView()
                            .accessibilityLabel(Text("Carregando", bundle: bundleApresentacao))
                    } else {
                        Text("Aceitar", bundle: bundleApresentacao)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(aceitando)
            .accessibilityIdentifier("aceite-termos-aceitar")
        }
    }
}
