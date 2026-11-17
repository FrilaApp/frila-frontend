import Foundation
import FrilaDominio
import Observation

/// O que a folha provisória de chamada da busca pede à casa: valor total, horário, responsável e recado.
/// Vale o mesmo para cada profissional selecionado. As regras são as da chamada direta (2 h de antecedência,
/// turno de 2 a 16 h). O Fabrício redesenha a folha; este estado fica.
@MainActor @Observable
public final class RascunhoDaChamadaDaBusca: Identifiable {
    public var inicio: Date
    public var fim: Date
    public var valorTexto = ""
    public var totalConfirmado = false
    public var responsavel: String
    public var recado = ""

    private let agora: @Sendable () -> Date

    static let antecedenciaMinima: TimeInterval = 2 * 3600
    static let duracaoMinima: TimeInterval = 2 * 3600
    static let duracaoMaxima: TimeInterval = 16 * 3600
    static let tamanhoDoRecado = 300

    /// O horário vem do filtro da busca, quando houver; sem ele, amanhã no mesmo horário por 4 h.
    public init(horario: Periodo?, responsavel: String, agora: @escaping @Sendable () -> Date = Date.init) {
        self.agora = agora
        let inicioPadrao = horario?.inicio ?? agora().addingTimeInterval(24 * 3600)
        inicio = inicioPadrao
        fim = horario?.fim ?? inicioPadrao.addingTimeInterval(4 * 3600)
        self.responsavel = responsavel
    }

    /// Valor em centavos, ou `nil` se o texto não é um valor em reais ("180" ou "180,50").
    public var valorCentavos: Int? {
        guard let centavos = (try? ServicoEmEdicao.centavos(valorTexto)) ?? nil, centavos > 0 else { return nil }
        return centavos
    }

    /// O primeiro motivo que impede o envio.
    public var oQueFalta: String? {
        if valorCentavos == nil { return TextosChamadaDireta.faltaValor }
        if !totalConfirmado { return TextosChamadaDireta.faltaConfirmarTotal }
        if responsavel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return TextosChamadaDireta.faltaResponsavel }
        if inicio.timeIntervalSince(agora()) < Self.antecedenciaMinima { return TextosChamadaDireta.faltaAntecedencia }
        if !(Self.duracaoMinima...Self.duracaoMaxima).contains(fim.timeIntervalSince(inicio)) { return TextosChamadaDireta.faltaDuracao }
        if recado.count > Self.tamanhoDoRecado { return TextosChamadaDireta.recadoLongo }
        return nil
    }

    public var podeEnviar: Bool { oQueFalta == nil }

    /// O trabalho que cada chamada leva (a chave de cada profissional entra em `chamar`). `nil` se algo falta.
    public func trabalho(casa: Estabelecimento, funcaoID: UUID) -> PublicacaoVaga? {
        guard podeEnviar, let centavos = valorCentavos, let periodo = try? Periodo(inicio: inicio, fim: fim) else { return nil }
        return PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcaoID, periodo: periodo, local: casa.endereco,
            regiaoAdministrativa: casa.regiaoAdministrativa, ponto: casa.ponto, valor: Dinheiro(centavos: centavos),
            posicoes: 1, inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: responsavel.trimmingCharacters(in: .whitespacesAndNewlines), modo: .urgencia, chave: UUID()
        )
    }

    public var recadoOuNada: String? { recado.isEmpty ? nil : recado }
}
