import Foundation

extension DataCivil {
    /// O dia civil de São Paulo em que o instante cai, que é o que o filtro `data` de `vagas_abertas`
    /// espera (o servidor compara no fuso America/Sao_Paulo). Às 22:30 em São Paulo já é o dia
    /// seguinte em UTC, e mandar o dia de UTC mostraria as vagas de amanhã a quem pediu as de hoje.
    /// Não depende do fuso do aparelho.
    public static func deSaoPaulo(_ instante: Date) -> DataCivil? {
        let dia = FormatadorFrila().diaDeSaoPaulo(instante)
        guard let ano = dia.year, let mes = dia.month, let numero = dia.day else { return nil }
        return try? DataCivil(ano: ano, mes: mes, dia: numero)
    }

    /// O dia de São Paulo `dias` depois do dia em que o instante cai.
    public static func deSaoPaulo(_ instante: Date, somandoDias dias: Int) -> DataCivil? {
        var calendario = Calendar(identifier: .gregorian)
        guard let fuso = TimeZone(identifier: "America/Sao_Paulo") else { return nil }
        calendario.timeZone = fuso
        guard let deslocado = calendario.date(byAdding: .day, value: dias, to: instante) else { return nil }
        return deSaoPaulo(deslocado)
    }
}
