import SwiftUI

/// Textos do aviso de cobertura (decisão da PO, item A6 do relatório da 0.5.5).
enum TextosDeCobertura {
    /// Cadastro do estabelecimento: o endereço fica fora do DF, mas o cadastro segue.
    static let estabelecimento = String(
        localized: "Este endereço fica fora do Distrito Federal. Você pode concluir o cadastro, mas por enquanto o foco e a cobertura do Frila são só do Distrito Federal.",
        bundle: bundleApresentacao
    )
    /// Ponto base do profissional: o endereço fica fora do DF, mas pode ser salvo.
    static let profissional = String(
        localized: "Este endereço fica fora do Distrito Federal. Você pode salvar, mas por enquanto o foco e a cobertura do Frila são só do Distrito Federal.",
        bundle: bundleApresentacao
    )
    /// Estabelecimento fora do DF: sem Região Administrativa para escolher, o app manda a cidade.
    static let regiaoForaDoDF = String(
        localized: "Fora do Distrito Federal",
        bundle: bundleApresentacao
    )
}

/// Aviso informativo, nunca bloqueante: endereço fora do Distrito Federal (cobertura atual do Frila).
struct AvisoForaDoDF: View {
    let texto: String
    let identificador: String

    var body: some View {
        AvisoFrila(verbatim: texto, tom: .alerta)
            .accessibilityIdentifier(identificador)
    }
}
