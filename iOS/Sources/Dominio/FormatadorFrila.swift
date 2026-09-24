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

    public func intervalo(_ periodo: Periodo) -> String {
        let calendario = Calendar(identifier: .gregorian).configuradoParaSaoPaulo
        let inicio = componentesDaData(periodo.inicio, calendario: calendario)
        let fim = componentesDaData(periodo.fim, calendario: calendario)
        return "\(inicio.dia) \(inicio.hora) – \(fim.dia) \(fim.hora)"
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
