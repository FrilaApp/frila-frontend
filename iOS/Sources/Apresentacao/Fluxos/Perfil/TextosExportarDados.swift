import Foundation

public enum TextosExportarDados {
    public static let titulo = String(localized: "Exportar meus dados", bundle: bundleApresentacao)
    public static let explicacao = String(
        localized: "Gera um arquivo JSON com seus dados cadastrais, turnos, avaliações e dispositivos registrados, conforme a LGPD.",
        bundle: bundleApresentacao
    )
    public static let dicaAcessibilidade = String(
        localized: "Exporta seus dados pessoais em formato JSON e abre o compartilhamento do sistema.",
        bundle: bundleApresentacao
    )
    public static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleApresentacao)
}
