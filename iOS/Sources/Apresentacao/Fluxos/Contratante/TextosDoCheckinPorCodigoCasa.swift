import Foundation

/// Textos do fluxo de check-in semiautomático na visão da Casa / Contratante (contrato 0.2.68, direção de 10/11/2026).
/// Sem jargão técnico, priorizando clareza e acessibilidade em pontos. Sem referência a QR code nesta etapa.
public enum TextosDoCheckinPorCodigoCasa {
    public static let titulo = String(localized: "Código de chegada", bundle: bundleApresentacao)
    public static let explicacao = String(
        localized: "Mostre este código de 6 números ao profissional que chegou. Ele digitará no aplicativo para confirmar a presença.",
        bundle: bundleApresentacao
    )
    public static let semCodigoParaEsteCheckin = String(
        localized: "O check-in foi feito longe do local ou há mais de 15 min. Confirme a presença pelo botão abaixo.",
        bundle: bundleApresentacao
    )
    public static let aguardandoChegadaExplicacao = String(
        localized: "Assim que o profissional registrar a chegada no local do turno, o código de 6 dígitos será liberado para exibição.",
        bundle: bundleApresentacao
    )
    public static func validade(_ tempo: String) -> String {
        String(format: String(localized: "Vale por mais %@", bundle: bundleApresentacao), tempo)
    }
    public static let gerandoOutro = String(localized: "O código venceu. Gerando outro…", bundle: bundleApresentacao)
    public static let carregando = String(localized: "Gerando o código…", bundle: bundleApresentacao)
    public static let falhou = String(
        localized: "Não foi possível gerar o código. Confira a conexão e tente novamente.",
        bundle: bundleApresentacao
    )
    public static let tentarDeNovo = String(localized: "Tentar de novo", bundle: bundleApresentacao)
    public static let foraDaJanela = String(
        localized: "Fora da janela de check-in deste turno.",
        bundle: bundleApresentacao
    )
    public static let encerrado = String(
        localized: "O código não vale mais neste turno. Confirme a presença pelo botão de confirmação manual abaixo.",
        bundle: bundleApresentacao
    )
    public static func codigoPorExtenso(_ digitos: String) -> String {
        String(format: String(localized: "Código de chegada: %@", bundle: bundleApresentacao), digitos.map(String.init).joined(separator: " "))
    }
}
