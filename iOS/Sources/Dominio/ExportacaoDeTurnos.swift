import Foundation

/// Formato do arquivo de `/exportar-turnos` (RF22).
public enum FormatoExportacao: String, Codable, CaseIterable, Sendable {
    case csv
    case pdf
}

public enum ErroPeriodoDeExportacao: Error, Equatable, Sendable {
    case inicioDepoisDoFim
}

/// Os dias de São Paulo que o relatório de turnos cobre, do primeiro ao último, inteiros (cartão
/// #23, UC13). Quem escolhe o período pensa em dias do calendário, e o contrato pede `Instante` em
/// UTC: `inicio` é a meia-noite do primeiro dia e `fim`, 23:59:59.999 do último, no fuso de São
/// Paulo, qualquer que seja o fuso do aparelho.
public struct PeriodoDeExportacao: Equatable, Sendable {
    public let de: DataCivil
    public let ate: DataCivil

    public init(de: DataCivil, ate: DataCivil) throws(ErroPeriodoDeExportacao) {
        guard de <= ate else { throw .inicioDepoisDoFim }
        self.de = de
        self.ate = ate
    }

    /// 00:00:00.000 de `de` em São Paulo.
    public var inicio: Date { Self.inicioDoDia(de) }

    /// 23:59:59.999 de `ate` em São Paulo: um milissegundo antes da meia-noite do dia seguinte.
    public var fim: Date {
        let calendario = Self.calendario
        let dia = Self.inicioDoDia(ate)
        let seguinte = calendario.date(byAdding: .day, value: 1, to: dia) ?? dia.addingTimeInterval(24 * 3600)
        return seguinte.addingTimeInterval(-0.001)
    }

    /// A janela usa instantes, como o servidor: no máximo 30 dias de 24 horas.
    public var excedeLimite: Bool { fim.timeIntervalSince(inicio) > 30 * 24 * 3600 }

    /// Do dia 1 do mês de `hoje` até `hoje`: o mês corrente ainda não terminou.
    public static func esteMes(hoje: DataCivil) -> PeriodoDeExportacao {
        PeriodoDeExportacao(primeiroDia: (try? DataCivil(ano: hoje.ano, mes: hoje.mes, dia: 1)) ?? hoje, ultimoDia: hoje)
    }

    /// Do dia 1 ao último dia do mês anterior ao de `hoje`.
    public static func mesPassado(hoje: DataCivil) -> PeriodoDeExportacao {
        let ano = hoje.mes == 1 ? hoje.ano - 1 : hoje.ano
        let mes = hoje.mes == 1 ? 12 : hoje.mes - 1
        let dias = calendario.date(from: DateComponents(year: ano, month: mes, day: 1))
            .flatMap { calendario.range(of: .day, in: .month, for: $0)?.count } ?? 28
        // Dia 1 e último dia de um mês que existe: as duas datas são válidas e estão em ordem.
        guard let primeiro = try? DataCivil(ano: ano, mes: mes, dia: 1),
              let ultimo = try? DataCivil(ano: ano, mes: mes, dia: dias) else { return esteMes(hoje: hoje) }
        return PeriodoDeExportacao(primeiroDia: primeiro, ultimoDia: ultimo)
    }

    private init(primeiroDia: DataCivil, ultimoDia: DataCivil) {
        de = primeiroDia
        ate = ultimoDia
    }

    private static var calendario: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = FormatadorFrila.fuso
        return calendario
    }

    private static func inicioDoDia(_ dia: DataCivil) -> Date {
        let componentes = DateComponents(year: dia.ano, month: dia.mes, day: dia.dia)
        // `startOfDay` cobre o dia que já começou depois da meia-noite, como no horário de verão antigo.
        let data = calendario.date(from: componentes) ?? .distantPast
        return calendario.startOfDay(for: data)
    }
}

/// Corpo de `POST /exportar-turnos`. Sem `estabelecimentoID`, valem os turnos de quem chama como
/// profissional; o contratante manda o do estabelecimento dele.
public struct PedidoExportacaoTurnos: Equatable, Sendable {
    public let periodo: PeriodoDeExportacao?
    public let de: Date?
    public let ate: Date?
    public let formato: FormatoExportacao
    public let estabelecimentoID: UUID?

    public init(periodo: PeriodoDeExportacao, formato: FormatoExportacao, estabelecimentoID: UUID? = nil) {
        self.periodo = periodo
        de = periodo.inicio
        ate = periodo.fim
        self.formato = formato
        self.estabelecimentoID = estabelecimentoID
    }

    /// Cada ponta pode ser omitida: o servidor usa agora para `ate` e 15 dias antes de `ate` para `de`.
    public init(de: Date? = nil, ate: Date? = nil, formato: FormatoExportacao, estabelecimentoID: UUID? = nil) {
        periodo = nil
        self.de = de
        self.ate = ate
        self.formato = formato
        self.estabelecimentoID = estabelecimentoID
    }

    public func instantes(agora: Date) -> (de: Date, ate: Date) {
        let fim = ate ?? agora
        return (de ?? fim.addingTimeInterval(-15 * 24 * 3600), fim)
    }
}

/// O 200 traz o arquivo no corpo; o 204 diz que o período não tem turnos, e nenhum arquivo vazio é
/// gerado (UC13, 1a).
public enum ResultadoExportacaoTurnos: Equatable, Sendable {
    case arquivo(Data)
    case semTurnos
}
