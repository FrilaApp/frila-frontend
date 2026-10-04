import Foundation

/// Textos provisórios da tela de histórico (#23): a alta fidelidade da v1.1 ainda não veio.
public enum TextosHistoricoDeTurnos {
    public static let titulo = String(localized: "Histórico de turnos", bundle: bundleApresentacao)
    public static let explicacao = String(
        localized: "Exporte os turnos de um período com data, função, horários registrados, valor acordado e contraparte. O valor é o combinado entre as partes, e não um pagamento feito pelo Frila. Turno não verificado sai marcado.",
        bundle: bundleApresentacao
    )
    public static let periodo = String(localized: "Período", bundle: bundleApresentacao)
    public static let esteMes = String(localized: "Este mês", bundle: bundleApresentacao)
    public static let mesPassado = String(localized: "Mês passado", bundle: bundleApresentacao)
    public static let intervalo = String(localized: "Escolher datas", bundle: bundleApresentacao)
    public static let de = String(localized: "De", bundle: bundleApresentacao)
    public static let ate = String(localized: "Até", bundle: bundleApresentacao)
    public static let periodoInvalido = String(
        localized: "A data inicial precisa ser igual ou anterior à final, e nenhuma pode estar no futuro.",
        bundle: bundleApresentacao
    )
    public static let formato = String(localized: "Formato", bundle: bundleApresentacao)
    public static let exportar = String(localized: "Exportar", bundle: bundleApresentacao)
    public static let dicaExportar = String(
        localized: "Gera o arquivo do período e abre o compartilhamento do sistema.",
        bundle: bundleApresentacao
    )
    public static let gerando = String(localized: "Gerando o arquivo…", bundle: bundleApresentacao)
    public static let semTurnos = String(
        localized: "Nenhum turno nesse período. Nenhum arquivo foi gerado.",
        bundle: bundleApresentacao
    )
    public static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleApresentacao)

    /// "De 01/10/2026 a 31/10/2026", ou "Em 03/10/2026" quando o período é de um dia só.
    public static func resumo(de: String, ate: String) -> String {
        de == ate
            ? String(localized: "Em \(de)", bundle: bundleApresentacao)
            : String(localized: "De \(de) a \(ate)", bundle: bundleApresentacao)
    }
}
