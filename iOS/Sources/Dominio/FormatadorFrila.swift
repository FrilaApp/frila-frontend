import Foundation

public struct FormatadorFrila: Sendable {
    public static let locale = Locale(identifier: "pt_BR")
    public static let fuso = TimeZone(identifier: "America/Sao_Paulo")!

    public init() {}

    public func dinheiro(_ valor: Dinheiro) -> String {
        let decimal = Decimal(valor.centavos) / 100
        return decimal.formatted(
            .currency(code: "BRL")
                .locale(Self.locale)
                .precision(.fractionLength(2))
        )
    }

    public func distancia(_ km: Double) -> String {
        km.formatted(.number.precision(.fractionLength(0...1)).locale(Self.locale)) + " km"
    }

    public func intervalo(_ periodo: Periodo) -> String {
        let calendario = Calendar(identifier: .gregorian).configuradoParaSaoPaulo
        let inicio = componentesDaData(periodo.inicio, calendario: calendario)
        let fim = componentesDaData(periodo.fim, calendario: calendario)
        return "\(inicio.dia) \(inicio.hora) – \(fim.dia) \(fim.hora)"
    }

    /// Hora e minuto no fuso de São Paulo, como em `intervalo`.
    public func hora(_ instante: Date) -> String {
        componentesDaData(instante, calendario: Calendar(identifier: .gregorian).configuradoParaSaoPaulo).hora
    }

    /// Data formatada no padrão brasileiro (dd/MM/yyyy).
    public func data(_ civil: DataCivil) -> String {
        String(format: "%02d/%02d/%04d", civil.dia, civil.mes, civil.ano)
    }

    /// Data formatada no padrão brasileiro (dd/MM/yyyy) no fuso de São Paulo.
    public func data(_ instante: Date) -> String {
        let formatador = DateFormatter()
        formatador.locale = Self.locale
        formatador.timeZone = Self.fuso
        formatador.dateFormat = "dd/MM/yyyy"
        return formatador.string(from: instante)
    }

    /// Data e hora no fuso de São Paulo, ex.: "08/10/2026 às 15:00".
    public func dataEHora(_ instante: Date) -> String {
        let formatador = DateFormatter()
        formatador.locale = Self.locale
        formatador.timeZone = Self.fuso
        formatador.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return formatador.string(from: instante)
    }

    public func diaDeSaoPaulo(_ instante: Date) -> DateComponents {
        Calendar(identifier: .gregorian).configuradoParaSaoPaulo.dateComponents(
            [.year, .month, .day],
            from: instante
        )
    }

    public func janelaParaContrato(_ janela: JanelaDeDisponibilidade) -> (diaSemana: Int, inicio: String, fim: String) {
        (janela.diaDaSemana, janela.inicio.contrato, janela.fim.contrato)
    }

    private func componentesDaData(_ data: Date, calendario: Calendar) -> (dia: String, hora: String) {
        let indice = calendario.component(.weekday, from: data) - 1
        let dias = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
        let formatador = DateFormatter()
        formatador.locale = Self.locale
        formatador.timeZone = Self.fuso
        formatador.dateFormat = "HH:mm"
        let hora = formatador.string(from: data)
        return (dias[indice], hora)
    }
}

private extension Calendar {
    var configuradoParaSaoPaulo: Calendar {
        var copia = self
        copia.locale = FormatadorFrila.locale
        copia.timeZone = FormatadorFrila.fuso
        return copia
    }
}
