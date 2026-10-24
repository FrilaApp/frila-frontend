import FrilaDominio
import Foundation
import Observation

/// Liga o rascunho do estúdio do FrilaLowPhase ao `PublicarVagaViewModel`: a validação, a fila e o
/// envio são os do app. Campo do rascunho que o contrato não tem não chega ao envio (README).
@MainActor @Observable
final class FormularioEstudioDeVaga {
    let vaga: PublicarVagaViewModel
    private let agora: @Sendable () -> Date

    init(vaga: PublicarVagaViewModel, agora: @escaping @Sendable () -> Date = Date.init) {
        self.vaga = vaga
        self.agora = agora
    }

    /// Rascunho da origem com o que o app já sabe: a casa, o endereço dela, o valor por turno e o que o
    /// `PublicarVagaViewModel` já guarda (publicação pendente restaurada, pré-preenchimento de teste, o
    /// horário padrão do app). Função só entra quando existe no catálogo do servidor.
    var rascunhoInicial: FrilaJobCreationDraft {
        var rascunho = FrilaJobCreationDraft.blank
        rascunho.client = vaga.estabelecimento?.nome ?? ""
        rascunho.address = vaga.local
        rascunho.paymentMode = .perShift
        if let funcao = vaga.funcoes.first(where: { $0.id == vaga.funcaoID }) {
            rascunho.role = funcao.nome
            rascunho.roleOrigin = .catalog
        }
        let calendario = FrilaShiftCalendar.brasilia
        // Arredonda a data inteira, não só a hora: 23:50 vira 00:00 do dia seguinte e a data acompanha.
        let inicio = Self.arredondar(vaga.inicio, calendario: calendario)
        rascunho.shiftDate = FrilaJobShiftFormat.dateLabel(inicio, calendar: calendario)
        rascunho.startTime = Self.relogio(de: inicio, calendario: calendario).fieldLabel
        rascunho.endTime = Self.relogio(de: Self.arredondar(vaga.fim, calendario: calendario), calendario: calendario).fieldLabel
        if vaga.valorCentavos > 0 { rascunho.payPerPosition = vaga.valorCentavos / 100 }
        if let posicoes = Int(vaga.posicoesTexto), posicoes > 0 { rascunho.positionsCount = posicoes }
        rascunho.mealIncluded = vaga.refeicao
        rascunho.transportIncluded = vaga.transporte
        rascunho.bringOwnMaterial = vaga.materialProprio
        rascunho.contactPerson = vaga.responsavelLocal
        rascunho.dressCode = vaga.traje
        rascunho.recalculateTotalBudget()
        return rascunho
    }

    /// A data no passo da roleta da origem (30 min), arredondada para a opção mais próxima. Quem cruza a
    /// meia-noite muda de dia junto: a hora e a data do turno saem da mesma data arredondada.
    static func arredondar(_ data: Date, calendario: Calendar = FrilaShiftCalendar.brasilia, passo: Int = 30) -> Date {
        let componentes = calendario.dateComponents([.hour, .minute, .second], from: data)
        let segundos = (componentes.hour ?? 0) * 3_600 + (componentes.minute ?? 0) * 60 + (componentes.second ?? 0)
        let passoEmSegundos = passo * 60
        let arredondado = Int((Double(segundos) / Double(passoEmSegundos)).rounded()) * passoEmSegundos
        return calendario.date(byAdding: .second, value: arredondado - segundos, to: data) ?? data
    }

    /// Hora do dia no passo da roleta da origem (30 min), arredondada para a opção mais próxima.
    static func relogio(de data: Date, calendario: Calendar = FrilaShiftCalendar.brasilia, passo: Int = 30) -> FrilaShiftClock {
        let componentes = calendario.dateComponents([.hour, .minute], from: data)
        let minutos = (componentes.hour ?? 0) * 60 + (componentes.minute ?? 0)
        let arredondado = Int((Double(minutos) / Double(passo)).rounded()) * passo
        return FrilaShiftClock(hour: 0, minute: arredondado)
    }

    /// As roletas de função passam a mostrar as funções do servidor, agrupadas pela categoria.
    func usarFuncoesNoCatalogo() {
        var categorias: [(nome: String, funcoes: [FrilaRole])] = []
        for funcao in vaga.funcoes {
            let papel = FrilaRole(id: funcao.id.uuidString, name: funcao.nome)
            if let indice = categorias.firstIndex(where: { $0.nome == funcao.categoria }) {
                categorias[indice].funcoes.append(papel)
            } else {
                categorias.append((funcao.categoria, [papel]))
            }
        }
        FrilaRoleCatalog.usar(categorias: categorias)
    }

    /// Copia o rascunho para os campos do contrato.
    func aplicar(_ rascunho: FrilaJobCreationDraft) {
        let nome = FrilaRoleCatalog.fold(rascunho.role)
        vaga.funcaoID = rascunho.roleOrigin == .custom ? nil : vaga.funcoes.first { FrilaRoleCatalog.fold($0.nome) == nome }?.id
        if let periodo = periodo(de: rascunho) {
            vaga.inicio = periodo.inicio
            vaga.fim = periodo.fim
        }
        vaga.local = rascunho.address.trimmingCharacters(in: .whitespacesAndNewlines)
        vaga.valorTexto = rascunho.payPerPosition > 0 ? String(rascunho.payPerPosition * 100) : ""
        vaga.posicoesTexto = String(rascunho.positionsCount)
        vaga.refeicao = rascunho.mealIncluded
        vaga.transporte = rascunho.transportIncluded
        vaga.materialProprio = rascunho.bringOwnMaterial
        vaga.responsavelLocal = rascunho.contactPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        vaga.traje = rascunho.dressCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A cada toque no rascunho o view model acompanha: é ele quem diz se a seleção ainda cabe no
    /// início escolhido (MS-RF01) e qual é o prazo de escolha (D2).
    func sincronizar(_ rascunho: FrilaJobCreationDraft) {
        aplicar(rascunho)
        vaga.ajustarModoAoInicio()
    }

    /// Data e horários do estúdio no fuso de Brasília; fim igual ou antes do início vira o dia seguinte.
    func periodo(de rascunho: FrilaJobCreationDraft) -> (inicio: Date, fim: Date)? {
        let calendario = FrilaShiftCalendar.brasilia
        guard let dia = FrilaJobShiftFormat.parseDate(rascunho.shiftDate, now: agora(), calendar: calendario),
              let comeco = FrilaJobShiftFormat.parseClock(rascunho.startTime),
              let termino = FrilaJobShiftFormat.parseClock(rascunho.endTime),
              let inicio = calendario.date(byAdding: .minute, value: comeco.minutes, to: dia)
        else { return nil }
        let dias = FrilaJobShiftFormat.endsNextDay(start: rascunho.startTime, end: rascunho.endTime) ? 1 : 0
        guard let diaDoFim = calendario.date(byAdding: .day, value: dias, to: dia),
              let fim = calendario.date(byAdding: .minute, value: termino.minutes, to: diaDoFim)
        else { return nil }
        return (inicio, fim)
    }

    /// Primeiro erro da validação do app, na ordem dos campos do formulário.
    var erroDaPublicacao: String? {
        let ordem: [CampoPublicacaoVaga] = [.estabelecimento, .funcao, .posicoes, .valor, .inicio, .fim, .local, .ponto, .responsavel, .modo]
        return ordem.lazy.compactMap { self.vaga.erros[$0] }.first ?? vaga.mensagemErro
    }

    /// Publica pelo caminho do app. `.queued` é a publicação sem rede: ficou na fila do aparelho e o
    /// aviso do formulário explica; não é erro.
    func publicar(_ rascunho: FrilaJobCreationDraft) async -> FrilaPublishOutcome {
        guard rascunho.paymentMode == .perShift else { return .failed(Self.semValorPorHora) }
        aplicar(rascunho)
        guard vaga.validar() else { return .failed(erroDaPublicacao ?? Self.naoPublicou) }
        await vaga.publicar()
        if vaga.resultado != nil { return .published }
        if vaga.publicacaoPendente != nil, vaga.mensagemErro == nil, vaga.erros.isEmpty { return .queued }
        return .failed(erroDaPublicacao ?? Self.naoPublicou)
    }

    static let semValorPorHora = String(localized: "O app publica o valor por turno. Troque Por hora por Por turno.", table: "Estudio", bundle: bundleApresentacao)
    static let naoPublicou = String(localized: "Não deu para publicar a vaga. Tente de novo.", table: "Estudio", bundle: bundleApresentacao)
}
