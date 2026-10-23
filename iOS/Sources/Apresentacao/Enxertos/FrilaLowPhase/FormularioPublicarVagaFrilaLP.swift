import Foundation
import FrilaDominio
import Observation

/// Estado do formulário "Nova vaga" do enxerto FrilaLowPhase.
///
/// Tudo o que vai ao servidor mora no `PublicarVagaViewModel` do app (mesmos campos, mesma
/// validação, mesma fila). Aqui ficam só o dia e a janela de horário no formato da origem
/// (chips Hoje/Amanhã/Outra data e relógio em passos de 15 min), convertidos em `inicio`/`fim`.
@MainActor @Observable
public final class FormularioPublicarVagaFrilaLP {
    /// Janela de Desfazer antes de a vaga ir aos profissionais (origem: `undoWindowSeconds`).
    public static let janelaDeDesfazerSegundos = 5
    /// Mesma faixa que o `PublicarVagaViewModel.validar()` aceita.
    public static let faixaDePosicoes = 1...200

    public let vaga: PublicarVagaViewModel
    public private(set) var dia: FrilaLPShiftDayChoice
    public var janela: FrilaLPShiftWindow {
        didSet { aplicarHorario() }
    }

    private let agora: @Sendable () -> Date
    private let calendario: Calendar
    /// Referência de "hoje" fixada na abertura, como na origem.
    private let abertura: Date

    public init(
        vaga: PublicarVagaViewModel,
        agora: @escaping @Sendable () -> Date = Date.init,
        calendario: Calendar = FrilaLPShiftCalendar.brasilia
    ) {
        self.vaga = vaga
        self.agora = agora
        self.calendario = calendario
        abertura = agora()
        // Padrão da origem: 18h às 02h, hoje; amanhã se o início de hoje já passou.
        janela = FrilaLPShiftWindow(start: FrilaLPShiftClock(hour: 18), end: FrilaLPShiftClock(hour: 2))
        dia = .today
        if dataDeInicio(dia: .today) <= abertura { dia = .tomorrow }
        aplicarHorario()
    }

    // MARK: Campos ligados ao view model

    public var funcaoSelecionada: Funcao? {
        vaga.funcoes.first { $0.id == vaga.funcaoID }
    }

    public var posicoes: Int {
        get { Int(vaga.posicoesTexto) ?? Self.faixaDePosicoes.lowerBound }
        set { vaga.posicoesTexto = String(newValue) }
    }

    public var valorCentavos: Int {
        get { vaga.valorCentavos }
        set { vaga.valorTexto = newValue > 0 ? String(newValue) : "" }
    }

    public var totalCentavos: Int { posicoes * valorCentavos }

    // MARK: Dia

    public var diaDoTurno: Date {
        switch dia {
        case .today: calendario.startOfDay(for: abertura)
        case .tomorrow: FrilaLPShiftCalendar.date(byAddingDays: 1, to: abertura, calendar: calendario)
        case .other(let data): calendario.startOfDay(for: data)
        }
    }

    public func escolher(_ escolha: FrilaLPShiftDayChoice) {
        dia = escolha
        aplicarHorario()
    }

    /// Data vinda do calendário "Outra data": hoje e amanhã voltam para os chips.
    public func escolherData(_ data: Date) {
        switch FrilaLPShiftCalendar.dayOffset(of: data, from: abertura, calendar: calendario) {
        case 0: escolher(.today)
        case 1: escolher(.tomorrow)
        default: escolher(.other(calendario.startOfDay(for: data)))
        }
    }

    private func dataDeInicio(dia escolha: FrilaLPShiftDayChoice) -> Date {
        let base: Date
        switch escolha {
        case .today: base = calendario.startOfDay(for: abertura)
        case .tomorrow: base = FrilaLPShiftCalendar.date(byAddingDays: 1, to: abertura, calendar: calendario)
        case .other(let data): base = calendario.startOfDay(for: data)
        }
        return calendario.date(byAdding: .minute, value: janela.start.minutes, to: base) ?? base
    }

    private func aplicarHorario() {
        let inicio = dataDeInicio(dia: dia)
        vaga.inicio = inicio
        // Janela inválida (início igual ao fim) chega ao view model como fim == início, e ele recusa.
        vaga.fim = janela.isValid ? inicio.addingTimeInterval(TimeInterval(janela.durationMinutes * 60)) : inicio
    }

    // MARK: Textos da barra fixa

    /// Primeiro problema que impede publicar, com o texto da origem. Cada um espelha uma regra
    /// que o `PublicarVagaViewModel.validar()` já aplica (valor, fim depois do início, início no futuro).
    public var bloqueio: String? {
        if valorCentavos <= 0 { return String(localized: "Informe o valor por posição.", bundle: bundleApresentacao) }
        if !janela.isValid { return String(localized: "O fim precisa ser diferente do início.", bundle: bundleApresentacao) }
        if vaga.inicio <= agora() {
            return String(localized: "Esse início já passou. Escolha outro horário ou outra data.", bundle: bundleApresentacao)
        }
        return nil
    }

    /// Erro devolvido pelo view model depois de validar ou de tentar publicar.
    public var erroDaPublicacao: String? {
        let ordem: [CampoPublicacaoVaga] = [.estabelecimento, .funcao, .posicoes, .valor, .inicio, .fim, .local, .ponto, .responsavel, .modo]
        if let campo = ordem.first(where: { vaga.erros[$0] != nil }), let texto = vaga.erros[campo] { return texto }
        return vaga.mensagemErro
    }

    /// "2 posições de R$ 140".
    public var detalhamento: String {
        String(localized: "\(rotuloDePosicoes) de \(FrilaLPMoney.total(cents: valorCentavos))", bundle: bundleApresentacao)
    }

    private var rotuloDePosicoes: String {
        posicoes == 1
            ? String(localized: "1 posição", bundle: bundleApresentacao)
            : String(localized: "\(posicoes) posições", bundle: bundleApresentacao)
    }

    /// "Garçom, 2 posições, hoje, sex 25/09, 18h às 02h". O app não tem o plural da função,
    /// por isso a contagem vem depois do nome (a origem diz "2 Garçons").
    public var resumo: String {
        let data = FrilaLPShiftCalendar.compact(diaDoTurno, calendar: calendario)
        let parteDoDia: String
        switch FrilaLPShiftCalendar.dayOffset(of: diaDoTurno, from: abertura, calendar: calendario) {
        case 0: parteDoDia = String(localized: "hoje, \(data)", bundle: bundleApresentacao)
        case 1: parteDoDia = String(localized: "amanhã, \(data)", bundle: bundleApresentacao)
        default: parteDoDia = data
        }
        let partes = [funcaoSelecionada?.nome, rotuloDePosicoes, parteDoDia, janela.rangeLabel].compactMap { $0 }
        return partes.joined(separator: ", ")
    }

    /// "Termina no dia seguinte: sáb 26/09, às 02:00."
    public var notaDeVirada: String? {
        guard janela.isValid, janela.crossesMidnight else { return nil }
        let diaSeguinte = FrilaLPShiftCalendar.compact(
            FrilaLPShiftCalendar.date(byAddingDays: 1, to: diaDoTurno, calendar: calendario),
            calendar: calendario
        )
        return String(localized: "Termina no dia seguinte: \(diaSeguinte), às \(janela.end.fieldLabel).", bundle: bundleApresentacao)
    }

    /// "Hoje, sex 25/09".
    public var rotuloDeHoje: String {
        String(localized: "Hoje, \(FrilaLPShiftCalendar.compact(abertura, calendar: calendario))", bundle: bundleApresentacao)
    }

    public var rotuloDeOutraData: String {
        if case .other(let data) = dia { return FrilaLPShiftCalendar.compact(data, calendar: calendario) }
        return String(localized: "Outra data", bundle: bundleApresentacao)
    }

    public var outraDataEscolhida: Bool {
        if case .other = dia { return true }
        return false
    }

    // MARK: Envio

    /// Confere tudo antes de abrir os 5 s de Desfazer: as regras da origem e a validação do app.
    public func podeComecarEnvio() -> Bool {
        guard bloqueio == nil else { return false }
        return vaga.validar()
    }

    /// Fim da janela de Desfazer: publica pelo mesmo caminho do app. Devolve se a vaga foi aceita.
    @discardableResult
    public func publicar() async -> Bool {
        await vaga.publicar()
        return vaga.resultado != nil
    }
}
