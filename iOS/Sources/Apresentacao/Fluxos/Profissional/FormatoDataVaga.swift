import Foundation
import FrilaDominio

/// Data e hora das vagas, sempre no fuso de São Paulo, sem depender do fuso do aparelho.
enum FormatoDataVaga {
    static var calendario: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = FormatadorFrila.fuso
        cal.locale = FormatadorFrila.locale
        return cal
    }

    private static func formato(_ padrao: String, _ data: Date) -> String {
        let formatador = DateFormatter()
        formatador.calendar = calendario
        formatador.timeZone = calendario.timeZone
        formatador.locale = FormatadorFrila.locale
        formatador.dateFormat = padrao
        return formatador.string(from: data)
    }

    static func hora(_ data: Date) -> String {
        formato(calendario.component(.minute, from: data) == 0 ? "HH'h'" : "HH'h'mm", data)
    }

    static func diaMes(_ data: Date) -> String {
        let semana = formato("EEE", data).replacingOccurrences(of: ".", with: "")
        return "\(semana). \(formato("dd/MM", data))"
    }

    static func quando(_ data: Date, agora: Date = .now) -> String {
        let dia = diaMes(data)
        if calendario.isDate(data, inSameDayAs: agora) {
            return String(format: String(localized: "Hoje, %@", bundle: bundleApresentacao), dia)
        }
        let amanha = calendario.date(byAdding: .day, value: 1, to: agora)!
        if calendario.isDate(data, inSameDayAs: amanha) {
            return String(format: String(localized: "Amanhã, %@", bundle: bundleApresentacao), dia)
        }
        return dia
    }

    static func janela(_ periodo: Periodo, quebraDeLinha: Bool = false) -> String {
        let horas = TextosDoProfissional.Detalhe.intervaloHorario(inicio: hora(periodo.inicio), fim: hora(periodo.fim))
        guard !calendario.isDate(periodo.inicio, inSameDayAs: periodo.fim) else { return horas }
        let fim = TextosDoProfissional.Detalhe.horarioTermina(diaMes(periodo.fim))
        return quebraDeLinha ? "\(horas)\n\(fim)" : TextosDoProfissional.Lista.dataEJanela(horas, fim)
    }

    static func cartao(_ periodo: Periodo, agora: Date = .now) -> String {
        TextosDoProfissional.Lista.dataEJanela(quando(periodo.inicio, agora: agora), janela(periodo))
    }

    static func apoioPreco(_ inicio: Date, agora: Date = .now) -> String {
        let cal = calendario
        let dia = cal.isDate(inicio, inSameDayAs: agora) ? TextosDoProfissional.Lista.hoje
            : cal.isDate(inicio, inSameDayAs: cal.date(byAdding: .day, value: 1, to: agora)!)
                ? TextosDoProfissional.Lista.amanha : diaMes(inicio)
        return TextosDoProfissional.Detalhe.apoioPreco(dia: dia.lowercased(), hora: hora(inicio))
    }

    static func modoEfetivo(modo: ModoPreenchimento, posicoesAbertas: Int, inicio: Date, agora: Date) -> ModoPreenchimento {
        // Pós-condição de vagas_abertas: só publicadas. Backend/main 8d19626,
        // 20260929230000_operacao_equipe_frila.sql:452; nenhuma redefinição posterior nesse snapshot.
        RegraDaSelecao.reposicaoEmUrgencia(modo: modo, estado: .publicada,
            posicoesAbertas: posicoesAbertas, inicio: inicio, agora: agora) ? .urgencia : modo
    }
}
