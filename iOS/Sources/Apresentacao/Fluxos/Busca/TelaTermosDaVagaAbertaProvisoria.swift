import FrilaDominio
import SwiftUI

// O texto é o do contrato 0.2.95. O desenho é o do sistema do Fabrício, extrapolado para a casa (R6); o nome do tipo
// ficou, para não mexer no projeto e nos testes.

/// O que a busca mostra quando a casa já tem o trabalho aberto numa vaga com valor ou inclusos diferentes dos digitados
/// (`409 trabalho_ja_aberto`, contrato 0.2.95): a chamada vai com os termos da vaga já aberta e só sai com Confirmar.
/// Cancelar não manda nada.
public struct TelaTermosDaVagaAbertaProvisoria: View {
    private let termos: TermosDaVagaAberta
    private let confirmar: () -> Void
    private let cancelar: () -> Void

    public init(termos: TermosDaVagaAberta, confirmar: @escaping () -> Void, cancelar: @escaping () -> Void) {
        self.termos = termos
        self.confirmar = confirmar
        self.cancelar = cancelar
    }

    /// A ligação com o ViewModel da busca: Confirmar vira `confirmarTermosDaVagaAberta()` e Cancelar,
    /// `cancelarTermosDaVagaAberta()`. `nil` quando não há termos para confirmar.
    public init?(modelo: BuscaDeProfissionaisViewModel) {
        guard let termos = modelo.termosParaConfirmar else { return nil }
        self.init(termos: termos, confirmar: { Task { await modelo.confirmarTermosDaVagaAberta() } },
                  cancelar: { modelo.cancelarTermosDaVagaAberta() })
    }

    /// O valor e os inclusos da vaga, numa linha: "R$ 150,00, Refeição inclusa, sem transporte" (e "Exige material
    /// próprio", quando exige).
    static func linha(_ termos: TermosDaVagaAberta) -> String {
        var partes = [FormatadorFrila().dinheiro(termos.valor), textoDaRefeicaoETransporte(termos.inclusos)]
        if termos.inclusos.exigeMaterialProprio {
            partes.append(String(localized: "Exige material próprio", bundle: bundleApresentacao))
        }
        return partes.joined(separator: ", ")
    }

    private static func textoDaRefeicaoETransporte(_ inclusos: Inclusos) -> String {
        switch (inclusos.refeicao, inclusos.transporte) {
        case (true, true): String(localized: "Refeição e transporte inclusos", bundle: bundleApresentacao)
        case (true, false): String(localized: "Refeição inclusa, sem transporte", bundle: bundleApresentacao)
        case (false, true): String(localized: "Sem refeição, transporte incluso", bundle: bundleApresentacao)
        case (false, false): String(localized: "Sem refeição nem transporte", bundle: bundleApresentacao)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
            Text("Esta chamada vai com os termos da vaga já aberta: \(Self.linha(termos))", bundle: bundleApresentacao)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("termos-vaga-aberta-texto")

            // A chamada só sai com Confirmar (o único laranja da folha); Cancelar não manda nada.
            VStack(spacing: FrilaEspaco.item) {
                BotaoPrimario("Confirmar") { confirmar() }
                    .accessibilityIdentifier("termos-vaga-aberta-confirmar")
                BotaoSecundario("Cancelar") { cancelar() }
                    .accessibilityIdentifier("termos-vaga-aberta-cancelar")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.grupo)
    }
}
