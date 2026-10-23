import FrilaDominio
import Foundation
import Observation

/// Liga o rascunho do estúdio do FrilaLowPhase ao `PublicarVagaViewModel`: a validação, a fila e o
/// envio são os do app. Campo do rascunho que o contrato não tem não chega ao envio (README).
@MainActor @Observable
final class FormularioEstudioFrilaLPE {
    let vaga: PublicarVagaViewModel
    private let agora: @Sendable () -> Date

    init(vaga: PublicarVagaViewModel, agora: @escaping @Sendable () -> Date = Date.init) {
        self.vaga = vaga
        self.agora = agora
    }

    /// Rascunho vazio da origem, com o que o app já sabe: a casa, o endereço dela e o valor por turno.
    var rascunhoInicial: FrilaLPEJobCreationDraft {
        var rascunho = FrilaLPEJobCreationDraft.blank
        rascunho.client = vaga.estabelecimento?.nome ?? ""
        rascunho.address = vaga.local
        rascunho.paymentMode = .perShift
        return rascunho
    }

    /// As roletas de função passam a mostrar as funções do servidor, agrupadas pela categoria.
    func usarFuncoesNoCatalogo() {
        var categorias: [(nome: String, funcoes: [FrilaLPERole])] = []
        for funcao in vaga.funcoes {
            let papel = FrilaLPERole(id: funcao.id.uuidString, name: funcao.nome)
            if let indice = categorias.firstIndex(where: { $0.nome == funcao.categoria }) {
                categorias[indice].funcoes.append(papel)
            } else {
                categorias.append((funcao.categoria, [papel]))
            }
        }
        FrilaLPERoleCatalog.usar(categorias: categorias)
    }

    /// Copia o rascunho para os campos do contrato.
    func aplicar(_ rascunho: FrilaLPEJobCreationDraft) {
        let nome = FrilaLPERoleCatalog.fold(rascunho.role)
        vaga.funcaoID = rascunho.roleOrigin == .custom ? nil : vaga.funcoes.first { FrilaLPERoleCatalog.fold($0.nome) == nome }?.id
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

    /// Data e horários do estúdio no fuso de Brasília; fim igual ou antes do início vira o dia seguinte.
    func periodo(de rascunho: FrilaLPEJobCreationDraft) -> (inicio: Date, fim: Date)? {
        let calendario = FrilaLPEShiftCalendar.brasilia
        guard let dia = FrilaLPEJobShiftFormat.parseDate(rascunho.shiftDate, now: agora(), calendar: calendario),
              let comeco = FrilaLPEJobShiftFormat.parseClock(rascunho.startTime),
              let termino = FrilaLPEJobShiftFormat.parseClock(rascunho.endTime),
              let inicio = calendario.date(byAdding: .minute, value: comeco.minutes, to: dia)
        else { return nil }
        let dias = FrilaLPEJobShiftFormat.endsNextDay(start: rascunho.startTime, end: rascunho.endTime) ? 1 : 0
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

    /// Nil quando a vaga foi publicada; senão, a mensagem para o contratante.
    func publicar(_ rascunho: FrilaLPEJobCreationDraft) async -> String? {
        guard rascunho.paymentMode == .perShift else { return Self.semValorPorHora }
        aplicar(rascunho)
        guard vaga.validar() else { return erroDaPublicacao ?? Self.naoPublicou }
        await vaga.publicar()
        if vaga.resultado != nil { return nil }
        return erroDaPublicacao ?? Self.naoPublicou
    }

    static let semValorPorHora = String(localized: "O app publica o valor por turno. Troque Por hora por Por turno.", table: "FrilaLPEEstudio", bundle: bundleApresentacao)
    static let naoPublicou = String(localized: "Não deu para publicar a vaga. Tente de novo.", table: "FrilaLPEEstudio", bundle: bundleApresentacao)
}
