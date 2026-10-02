import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Turno no contrato 0.2.32")
@MainActor
struct TurnoContrato0231Tests {
    private let contaID = UUID()
    private let agora = ContratoAPI.instante("2026-10-11T12:00:00Z")!

    private func turno(_ fixture: String) throws -> Turno {
        try #require(try FixturesDoContrato.carregar(fixture, como: [ContratoAPI.TurnoDTO].self).first).dominio()
    }

    @Test("Turno cancelado não oferece avaliação nem contato, mesmo com presença verificada")
    func canceladoSemAcoes() async throws {
        let contato = try FixturesDoContrato.carregar("contato", como: ContratoAPI.ContatoDTO.self).dominio()
        let cancelado = try turno("turnos-cancelados").com(contato: contato)
        let api = ApiDoTurnoCancelado()
        let leitor = LeitorDeLocalizacaoSimulado(resultado: .failure(.semSinal))
        let presenca = PresencaDoTurnoViewModel(turno: cancelado, api: api, localizacao: leitor)
        let vm = MeuTurnoViewModel(turno: cancelado, api: api, contaID: contaID,
                                  armazenamentoAvaliacoes: ArmazenamentoAvaliacoesEmMemoria(),
                                  relogio: RelogioFixo(agora), presenca: presenca)
        #expect(vm.presenca == nil)
        #expect(!vm.permiteAcoesDoTurno)
        #expect(!vm.podeAvaliar)
        #expect(vm.criarAvaliacaoViewModel() == nil)
        #expect(vm.contato == nil)
        #expect(vm.urlWhatsApp == nil)
        await vm.carregar()
        #expect(vm.contato == nil)
        #expect(api.chamadasContato == 0)
        #expect(await leitor.leituras == 0)
    }

    @Test("Avaliação do servidor prevalece sobre resposta antiga do aparelho")
    func respostaDoServidor() async throws {
        let avaliado = try turno("turnos-avaliados")
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        reserva.salvar(resposta: false, para: avaliado.id, contaID: contaID)
        let vm = MeuTurnoViewModel(turno: avaliado, api: ApiClienteEmMemoria(), contaID: contaID,
                                  armazenamentoAvaliacoes: reserva, relogio: RelogioFixo(agora))
        #expect(vm.jaAvaliado)
        #expect(vm.respostaAvaliacao == true)
        let avaliacao = try #require(vm.criarAvaliacaoViewModel())
        await avaliacao.carregar()
        #expect(avaliacao.jaAvaliado)
        #expect(avaliacao.resposta == true)
        avaliacao.resposta = false
        #expect(avaliacao.resposta == true)
        #expect(await avaliacao.salvar() == false)
    }

    @Test("Decodifica campos ausentes, nulos e preenchidos sem presumir confirmação")
    func decodificacao() throws {
        let anterior = try turno("turnos")
        #expect(anterior.estado == nil)
        #expect(anterior.avaliacao == nil)
        #expect(!anterior.servidorInformaAvaliacao)
        let cancelado = try turno("turnos-cancelados")
        #expect(cancelado.estado == .cancelada)
        #expect(cancelado.avaliacao == nil)
        #expect(cancelado.servidorInformaAvaliacao)
        let avaliado = try turno("turnos-avaliados")
        #expect(avaliado.estado == .cumprida)
        #expect(avaliado.avaliacao?.resposta == true)
        #expect(avaliado.avaliacao?.turnoID == avaliado.id)
    }

    @Test("Estado novo não derruba o turno, e voto Não não vira ausência")
    func enumNovoERespostaNegativa() throws {
        var lista = try #require(try JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos-avaliados")) as? [[String: Any]])
        lista[0]["estado"] = "estado_futuro"
        var voto = try #require(lista[0]["avaliacao"] as? [String: Any])
        voto["resposta"] = false
        lista[0]["avaliacao"] = voto
        let dados = try JSONSerialization.data(withJSONObject: lista)
        let lido = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: dados).first).dominio()
        #expect(lido.estado == nil)
        #expect(lido.avaliacao?.resposta == false)
    }

    @Test("Resposta nula do servidor não usa uma avaliação antiga do aparelho")
    func nuloAutoritativo() async throws {
        var lista = try #require(try JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos-avaliados")) as? [[String: Any]])
        lista[0]["avaliacao"] = NSNull()
        lista[0]["pode_avaliar"] = true
        let dados = try JSONSerialization.data(withJSONObject: lista)
        let novo = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: dados).first).dominio()
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        reserva.salvar(resposta: false, para: novo.id, contaID: contaID)
        let vm = MeuTurnoViewModel(turno: novo, api: ApiClienteEmMemoria(), contaID: contaID,
                                  armazenamentoAvaliacoes: reserva, relogio: RelogioFixo(agora))
        #expect(!vm.jaAvaliado)
        #expect(vm.respostaAvaliacao == nil)
        #expect(vm.podeAvaliar)
        let avaliacao = try #require(vm.criarAvaliacaoViewModel())
        await avaliacao.carregar()
        #expect(!avaliacao.jaAvaliado)
        #expect(avaliacao.resposta == nil)
    }

    @Test("Servidor anterior usa reserva local e cache anterior continua legível")
    func reservaECacheAnterior() async throws {
        let antigo = try turno("turnos")
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        reserva.salvar(resposta: false, para: antigo.id, contaID: contaID)
        let vm = MeuTurnoViewModel(turno: antigo, api: ApiClienteEmMemoria(), contaID: contaID,
                                  armazenamentoAvaliacoes: reserva, relogio: RelogioFixo(agora))
        #expect(vm.jaAvaliado)
        #expect(vm.respostaAvaliacao == false)
        var cache = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(antigo)) as? [String: Any])
        for chave in ["estado", "avaliacao", "avaliacaoInformada", "cancelamento"] { cache.removeValue(forKey: chave) }
        let restaurado = try JSONDecoder().decode(Turno.self, from: JSONSerialization.data(withJSONObject: cache))
        #expect(restaurado.estado == nil && !restaurado.servidorInformaAvaliacao)
        let avaliado = try turno("turnos-avaliados")
        let copia = try JSONDecoder().decode(Turno.self, from: JSONEncoder().encode(avaliado.com(contato: nil).com(aCaminhoEm: nil)))
        #expect(copia.avaliacao == avaliado.avaliacao)
        #expect(copia.estado == avaliado.estado)
        #expect(copia.servidorInformaAvaliacao)
    }

    @Test("Sair limpa a reserva, e entrar de novo recupera a avaliação pelo servidor", arguments: [true, false])
    func novaEntrada(resposta: Bool) async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let conta = try await api.minhaConta()
        let inicial = try #require(try await api.meusTurnos().first)
        #expect(inicial.avaliacao == nil && inicial.servidorInformaAvaliacao)
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        let vm = MeuTurnoViewModel(turno: inicial, api: api, contaID: conta.id, armazenamentoAvaliacoes: reserva)
        let formulario = try #require(vm.criarAvaliacaoViewModel())
        formulario.resposta = resposta
        #expect(await formulario.salvar())
        #expect(vm.respostaAvaliacao == resposta && vm.jaAvaliado)
        let reaberto = try #require(vm.criarAvaliacaoViewModel())
        await reaberto.carregar()
        #expect(reaberto.jaAvaliado && reaberto.resposta == resposta)
        await api.sair(tokenFCM: nil)
        reserva.limpar()
        try await api.verificarCodigo(email: "teste@frila.app", codigo: "123456")
        let lido = try #require(try await api.meusTurnos().first)
        #expect(lido.avaliacao?.resposta == resposta)
        #expect(!lido.podeAvaliar)
        let novaTela = MeuTurnoViewModel(turno: lido, api: api, contaID: conta.id, armazenamentoAvaliacoes: reserva)
        #expect(novaTela.jaAvaliado)
        #expect(novaTela.respostaAvaliacao == resposta)
        let novaAvaliacao = try #require(novaTela.criarAvaliacaoViewModel())
        await novaAvaliacao.carregar()
        #expect(novaAvaliacao.jaAvaliado && novaAvaliacao.resposta == resposta)
    }

    @Test("Dublê mantém o turno cancelado na lista e não oferece avaliação")
    func dubleCancelado() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoCancelado)
        let cancelado = try #require(try await api.meusTurnos().first)
        #expect(cancelado.estado == .cancelada)
        #expect(!cancelado.podeAvaliar)
        #expect(cancelado.avaliacao == nil && cancelado.servidorInformaAvaliacao)
        #expect(cancelado.cancelamento?.causa == .profissional)
        #expect(cancelado.cancelamento?.falta == false)
    }

    @Test("Cancelamento informa causa, falta e data e sobrevive ao cache", arguments: ["turnos-com-cancelamento", "turnos-com-falta"])
    func cancelamentoInformado(fixture: String) throws {
        let lido = try turno(fixture)
        let registro = try #require(lido.cancelamento)
        let comFalta = fixture == "turnos-com-falta"
        #expect(registro.causa == (comFalta ? .reaberturaPorAtraso : .estabelecimento))
        #expect(registro.falta == comFalta)
        #expect(registro.canceladaEm == ContratoAPI.instante("2026-10-09T19:40:00Z"))
        let copia = try JSONDecoder().decode(Turno.self, from: JSONEncoder().encode(lido.com(contato: nil).com(aCaminhoEm: nil)))
        #expect(copia.cancelamento == registro)
        let vm = MeuTurnoViewModel(turno: copia, api: ApiClienteEmMemoria(), contaID: contaID)
        #expect(vm.causaDoCancelamento == (comFalta ? "O estabelecimento reabriu a posição por atraso." : "O estabelecimento cancelou este turno."))
        #expect(vm.faltaNoCancelamento == (comFalta ? "Este cancelamento contou como falta." : "Este cancelamento não contou como falta."))
        #expect(!vm.permiteAcoesDoTurno)
    }

    @Test("Cancelamento ausente ou nulo não afirma causa nem falta", arguments: [false, true])
    func cancelamentoAnterior(nulo: Bool) throws {
        var lista = try #require(try JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos-cancelados")) as? [[String: Any]])
        if nulo { lista[0]["cancelamento"] = NSNull() }
        let lido = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: JSONSerialization.data(withJSONObject: lista)).first).dominio()
        let vm = MeuTurnoViewModel(turno: lido, api: ApiClienteEmMemoria(), contaID: contaID)
        #expect(vm.cancelado)
        #expect(vm.cancelamento == nil)
        #expect(vm.causaDoCancelamento == nil && vm.faltaNoCancelamento == nil)
    }

    @Test("Causa desconhecida vira outro sem texto privado nem inferência sobre a conta")
    func cancelamentoDesconhecido() throws {
        var lista = try #require(try JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos-com-cancelamento")) as? [[String: Any]])
        var registro = try #require(lista[0]["cancelamento"] as? [String: Any])
        registro["causa"] = "causa_futura"
        registro["falta"] = true
        registro["motivo"] = "Texto privado que não deve chegar à apresentação."
        lista[0]["cancelamento"] = registro
        let lido = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: JSONSerialization.data(withJSONObject: lista)).first).dominio()
        #expect(lido.cancelamento?.causa == .outro)
        let vm = MeuTurnoViewModel(turno: lido, api: ApiClienteEmMemoria(), contaID: contaID)
        #expect(vm.causaDoCancelamento == "Cancelamento registrado.")
        #expect(vm.faltaNoCancelamento == "Este cancelamento contou como falta.")
        let cache = String(decoding: try JSONEncoder().encode(lido), as: UTF8.self)
        #expect(!cache.contains("motivo") && !cache.contains("Texto privado"))
    }

    @Test("Fim sem check-in explica o cancelamento e a falta sem afirmar desistência")
    func cancelamentoSemCheckin() throws {
        var lista = try #require(try JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos-com-falta")) as? [[String: Any]])
        var registro = try #require(lista[0]["cancelamento"] as? [String: Any])
        registro["causa"] = "no_show_sem_checkin"
        lista[0]["cancelamento"] = registro
        let lido = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: JSONSerialization.data(withJSONObject: lista)).first).dominio()
        #expect(lido.cancelamento?.causa == .noShowSemCheckin)
        let vm = MeuTurnoViewModel(turno: lido, api: ApiClienteEmMemoria(), contaID: contaID)
        #expect(vm.causaDoCancelamento == "O turno terminou sem check-in.")
        #expect(vm.faltaNoCancelamento == "Este cancelamento contou como falta.")
        #expect(!vm.podeAvaliar)
    }

    @Test("Dublê registra a causa da desistência sem devolver o motivo")
    func dubleDesistencia() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let inicial = try #require(try await api.meusTurnos().first)
        _ = try await api.cancelarPosicao(id: inicial.posicaoID, motivo: "Motivo privado da desistência")
        let lido = try #require(try await api.meusTurnos().first)
        #expect(lido.cancelado)
        #expect(lido.cancelamento?.causa == .profissional)
        #expect(lido.cancelamento?.falta == true)
        #expect(lido.cancelamento?.canceladaEm != nil)
    }

    @Test("Aviso da vaga ignora cancelado e abre outro turno válido da mesma vaga", arguments: [EstadoPosicao.confirmada, .cumprida, nil])
    func avisoProcuraTurnoValido(estado: EstadoPosicao?) throws {
        let cancelado = try turno("turnos-cancelados")
        var lista = try #require(try JSONSerialization.jsonObject(with: FixturesDoContrato.dados("turnos-cancelados")) as? [[String: Any]])
        lista[0]["id"] = UUID().uuidString
        if let estado { lista[0]["estado"] = estado.rawValue } else { lista[0].removeValue(forKey: "estado") }
        let valido = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: JSONSerialization.data(withJSONObject: lista)).first).dominio()
        #expect(valido.vaga.id == cancelado.vaga.id)
        #expect(BuscaDaVagaDoAviso.decidir(vagaID: cancelado.vaga.id, candidaturas: [], turnos: [cancelado, valido]) == .achou(valido))
        #expect(BuscaDaVagaDoAviso.decidir(vagaID: cancelado.vaga.id, candidaturas: [], turnos: [valido, cancelado]) == .achou(valido))
    }

    @Test("Só turno cancelado não abre turno pelo aviso e mantém o estado da candidatura", arguments: [EstadoCandidatura.aceita, .pendente, .retirada, nil])
    func avisoNaoAbreCancelado(estado: EstadoCandidatura?) throws {
        let cancelado = try turno("turnos-cancelados")
        let candidaturas = estado.map { [Candidatura(id: UUID(), vaga: cancelado.vaga, estado: $0, criadaEm: agora)] }
        #expect(BuscaDaVagaDoAviso.decidir(vagaID: cancelado.vaga.id, candidaturas: candidaturas, turnos: [cancelado]) == .semTurno(candidatura: estado))
    }


}

private struct RelogioFixo: Relogio {
    let agora: Date
    init(_ agora: Date) { self.agora = agora }
}

private final class ApiDoTurnoCancelado: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var quantidade = 0
    var chamadasContato: Int { trava.withLock { quantidade } }

    override func contatoDoTurno(id: UUID) async throws -> Contato {
        trava.withLock { quantidade += 1 }
        return try await super.contatoDoTurno(id: id)
    }
}
