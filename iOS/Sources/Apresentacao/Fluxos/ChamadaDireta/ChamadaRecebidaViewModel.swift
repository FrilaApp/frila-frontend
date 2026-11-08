import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class ChamadaRecebidaViewModel {
    public let chamadaID: UUID
    public private(set) var detalhe: ChamadaDetalhe?
    public private(set) var resultado: ResultadoChamada?
    public private(set) var carregando = false
    public private(set) var respondendo = false
    public private(set) var erro: String?
    public private(set) var mensagemConcorrencia: String?
    public var mostrarRecusa = false
    public var motivoSelecionado: MotivoRecusaChamada?

    private let api: any ApiCliente
    private let agora: @Sendable () -> Date
    private let formatador = FormatadorFrila()

    public init(chamadaID: UUID, api: any ApiCliente, agora: @escaping @Sendable () -> Date = Date.init) {
        self.chamadaID = chamadaID
        self.api = api
        self.agora = agora
    }

    public var podeResponder: Bool {
        guard let detalhe else { return false }
        return detalhe.estado == .aberta && resultado == nil && mensagemConcorrencia == nil && !respondendo && !carregando
    }

    public var valorFormatado: String {
        guard let detalhe else { return "" }
        return formatador.dinheiro(Dinheiro(centavos: detalhe.valorCentavos))
    }

    public var intervaloFormatado: String {
        guard let detalhe else { return "" }
        let inicio = formatador.dataEHora(detalhe.inicioEm)
        let horaFim = formatador.hora(detalhe.fimEm)
        return "\(inicio) até \(horaFim)"
    }

    public var expiraEmFormatado: String {
        guard let detalhe else { return "" }
        return "\(TextosChamadaDireta.responderAte) \(formatador.hora(detalhe.expiraEm))"
    }

    public func carregar() async {
        guard !carregando else { return }
        carregando = true
        erro = nil
        defer { carregando = false }

        do {
            let info = try await api.detalheChamada(id: chamadaID)
            detalhe = info
            if info.estado == .encerrada || info.estado == .aceita {
                mensagemConcorrencia = TextosChamadaDireta.chamadaEncerradaAviso
            } else if info.estado == .expirada || (info.estado == .aberta && agora() >= info.expiraEm) {
                mensagemConcorrencia = TextosChamadaDireta.chamadaExpiradaAviso
            } else if info.estado == .cancelada {
                mensagemConcorrencia = TextosChamadaDireta.chamadaCanceladaAviso
            }
        } catch let apiErro as ErroDaApi {
            if apiErro.recursoDesligado {
                erro = TextosChamadaDireta.desligado
            } else if apiErro.codigo == .semRede {
                erro = TextosChamadaDireta.erro
            } else {
                erro = TextosChamadaDireta.indisponivel
            }
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    public func aceitar() async {
        if let detalhe, detalhe.estado == .aberta && agora() >= detalhe.expiraEm {
            mensagemConcorrencia = TextosChamadaDireta.chamadaExpiradaAviso
            return
        }
        guard podeResponder else { return }
        respondendo = true
        erro = nil
        defer { respondendo = false }

        do {
            let res = try await api.responderChamada(id: chamadaID, resposta: .aceitar, motivoRecusa: nil)
            resultado = res
            // Atualiza detalhe localmente para refletir aceite
            if let atual = detalhe {
                detalhe = ChamadaDetalhe(
                    id: atual.id, vagaID: atual.vagaID, profissionalID: atual.profissionalID,
                    estabelecimentoID: atual.estabelecimentoID, estado: .aceita,
                    recado: atual.recado, motivoRecusa: nil, expiraEm: atual.expiraEm,
                    respondidaEm: agora(), criadaEm: atual.criadaEm, funcao: atual.funcao,
                    inicioEm: atual.inicioEm, fimEm: atual.fimEm, valorCentavos: atual.valorCentavos,
                    outraParte: atual.outraParte, tipoEstabelecimento: atual.tipoEstabelecimento,
                    contaNova: atual.contaNova, regiaoAdministrativa: atual.regiaoAdministrativa,
                    distanciaFaixa: atual.distanciaFaixa, incluiRefeicao: atual.incluiRefeicao,
                    incluiTransporte: atual.incluiTransporte, exigeMaterialProprio: atual.exigeMaterialProprio,
                    local: res.local, ponto: res.ponto, responsavelLocal: res.responsavelLocal,
                    turnoID: res.turnoID
                )
            }
        } catch let apiErro as ErroDaApi {
            tratarErroAoResponder(apiErro)
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    public func recusar() async {
        if let detalhe, detalhe.estado == .aberta && agora() >= detalhe.expiraEm {
            mensagemConcorrencia = TextosChamadaDireta.chamadaExpiradaAviso
            return
        }
        guard podeResponder else { return }
        respondendo = true
        erro = nil
        defer { respondendo = false }

        do {
            let res = try await api.responderChamada(id: chamadaID, resposta: .recusar, motivoRecusa: motivoSelecionado)
            resultado = res
            mostrarRecusa = false
            if let atual = detalhe {
                detalhe = ChamadaDetalhe(
                    id: atual.id, vagaID: atual.vagaID, profissionalID: atual.profissionalID,
                    estabelecimentoID: atual.estabelecimentoID, estado: .recusada,
                    recado: atual.recado, motivoRecusa: motivoSelecionado, expiraEm: atual.expiraEm,
                    respondidaEm: agora(), criadaEm: atual.criadaEm, funcao: atual.funcao,
                    inicioEm: atual.inicioEm, fimEm: atual.fimEm, valorCentavos: atual.valorCentavos,
                    outraParte: atual.outraParte, tipoEstabelecimento: atual.tipoEstabelecimento,
                    contaNova: atual.contaNova, regiaoAdministrativa: atual.regiaoAdministrativa,
                    distanciaFaixa: atual.distanciaFaixa, incluiRefeicao: atual.incluiRefeicao,
                    incluiTransporte: atual.incluiTransporte, exigeMaterialProprio: atual.exigeMaterialProprio
                )
            }
        } catch let apiErro as ErroDaApi {
            tratarErroAoResponder(apiErro)
        } catch {
            erro = TextosChamadaDireta.erro
        }
    }

    private func tratarErroAoResponder(_ apiErro: ErroDaApi) {
        if apiErro.codigo == .chamadaIndisponivel || apiErro.codigo == .posicaoJaPreenchida || apiErro.codigo == .vagaEncerrada {
            if apiErro.detalhes == "expirada" {
                mensagemConcorrencia = TextosChamadaDireta.chamadaExpiradaAviso
            } else if apiErro.detalhes == "cancelada" {
                mensagemConcorrencia = TextosChamadaDireta.chamadaCanceladaAviso
            } else {
                mensagemConcorrencia = TextosChamadaDireta.chamadaEncerradaAviso
            }
        } else if apiErro.recursoDesligado {
            erro = TextosChamadaDireta.desligado
        } else if apiErro.codigo == .semRede {
            erro = TextosChamadaDireta.erro
        } else {
            erro = TextosChamadaDireta.indisponivel
        }
    }
}
