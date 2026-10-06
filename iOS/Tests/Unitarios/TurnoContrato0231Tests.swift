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
        let dto = try #require(try ContratoAPI.decodificador().decode([ContratoAPI.TurnoDTO].self, from: dados).first)
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        reserva.salvar(resposta: false, para: dto.id, contaID: contaID)
        // A leitura nova é posterior à reserva antiga e, portanto, o nulo prevalece.
        let novo = try dto.dominio()
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
        for chave in ["estado", "avaliacao", "avaliacaoInformada", "cancelamento", "avaliacaoLidaEm"] { cache.removeValue(forKey: chave) }
        let restaurado = try JSONDecoder().decode(Turno.self, from: JSONSerialization.data(withJSONObject: cache))
        #expect(restaurado.estado == nil && !restaurado.servidorInformaAvaliacao)
        let avaliado = try turno("turnos-avaliados")
        let copia = try JSONDecoder().decode(Turno.self, from: JSONEncoder().encode(avaliado.com(contato: nil).com(aCaminhoEm: nil)))
        #expect(copia.avaliacao == avaliado.avaliacao)
        #expect(copia.estado == avaliado.estado)
        #expect(copia.servidorInformaAvaliacao)
        #expect(copia.avaliacaoLidaEm == avaliado.avaliacaoLidaEm)
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

    @Test("Reabrir o turno da lista anterior ao voto preserva a resposta aceita")
    func reabrirListaAnteriorAoVoto() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let conta = try await api.minhaConta()
        let inicial = try #require(try await api.meusTurnos().first)
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        var atualizacoesDaLista = 0
        let primeira = MeuTurnoViewModel(turno: inicial, api: api, contaID: conta.id, armazenamentoAvaliacoes: reserva,
                                        aoAvaliar: { atualizacoesDaLista += 1 })
        let form = try #require(primeira.criarAvaliacaoViewModel())
        form.resposta = true
        #expect(await form.salvar())
        #expect(atualizacoesDaLista == 1)
        let segunda = MeuTurnoViewModel(turno: inicial, api: api, contaID: conta.id, armazenamentoAvaliacoes: reserva)
        #expect(segunda.jaAvaliado)
        #expect(segunda.respostaAvaliacao == true)
        let reaberto = try #require(segunda.criarAvaliacaoViewModel())
        await reaberto.carregar()
        #expect(reaberto.jaAvaliado && reaberto.resposta == true)
        #expect(await reaberto.salvar() == false)
        #expect(reserva.resposta(para: inicial.id, contaID: conta.id) == true)
    }

    @Test("Voto sem rede bloqueia o cartão atual e o reaberto, sem duplicar a fila")
    func votoSemRede() async throws {
        let api = ApiSemRedeAoAvaliar()
        let conta = try await api.minhaConta()
        let inicial = try #require(try await api.meusTurnos().first)
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        let fila = FilaDoContrato()
        let primeira = MeuTurnoViewModel(turno: inicial, api: api, contaID: conta.id, fila: fila, armazenamentoAvaliacoes: reserva)
        let form = try #require(primeira.criarAvaliacaoViewModel())
        form.resposta = false
        #expect(await form.salvar())
        #expect(form.enfileiradoOffline)
        #expect(primeira.jaAvaliado && primeira.respostaAvaliacao == false)
        let segunda = MeuTurnoViewModel(turno: inicial, api: api, contaID: conta.id, fila: fila, armazenamentoAvaliacoes: reserva)
        await segunda.carregar()
        #expect(segunda.jaAvaliado && segunda.respostaAvaliacao == false)
        let reaberto = try #require(segunda.criarAvaliacaoViewModel())
        await reaberto.carregar()
        #expect(reaberto.jaAvaliado && reaberto.resposta == false && reaberto.enfileiradoOffline)
        #expect(await reaberto.salvar() == false)
        #expect(try await fila.pendentes().count == 1)
    }

    @Test("Fila deste autor prevalece mesmo sobre uma leitura nula posterior ao voto")
    func filaPrevaleceSobreNuloNovo() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let conta = try await api.minhaConta()
        let inicial = try #require(try await api.meusTurnos().first)
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        reserva.salvar(resposta: false, para: inicial.id, contaID: conta.id)
        let fila = FilaDoContrato()
        try await fila.enfileirar(AcaoPendente(tipo: .avaliacao, turnoID: inicial.id, contaID: conta.id,
                                              instanteDoToque: Date(), chave: UUID(), resposta: false))
        let novo = try #require(try await api.meusTurnos().first)
        let vm = MeuTurnoViewModel(turno: novo, api: api, contaID: conta.id, fila: fila, armazenamentoAvaliacoes: reserva)
        await vm.carregar()
        #expect(vm.jaAvaliado && vm.respostaAvaliacao == false)
        let form = try #require(vm.criarAvaliacaoViewModel())
        await form.carregar()
        #expect(form.jaAvaliado && form.resposta == false && form.enfileiradoOffline)
        let outra = MeuTurnoViewModel(turno: novo, api: api, contaID: UUID(), fila: fila, armazenamentoAvaliacoes: reserva)
        await outra.carregar()
        #expect(!outra.jaAvaliado && outra.respostaAvaliacao == nil)
    }

    @Test("409 preserva a resposta conhecida e não grava a tentativa recusada")
    func conflitoPreservaResposta() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoEncerrado)
        let conta = try await api.minhaConta()
        let inicial = try #require(try await api.meusTurnos().first)
        _ = try await api.avaliar(turnoID: inicial.id, resposta: true)
        let reserva = ArmazenamentoAvaliacoesEmMemoria()
        reserva.salvar(resposta: true, para: inicial.id, contaID: conta.id)
        // Uma leitura posterior nula permite tentar de novo; o servidor recusa o segundo voto.
        let dados = try JSONEncoder().encode(inicial)
        var objeto = try #require(try JSONSerialization.jsonObject(with: dados) as? [String: Any])
        objeto["avaliacaoLidaEm"] = Date().timeIntervalSinceReferenceDate
        let novo = try JSONDecoder().decode(Turno.self, from: JSONSerialization.data(withJSONObject: objeto))
        let form = AvaliacaoTurnoViewModel(turnoID: novo.id, contaID: conta.id, turno: novo, api: api, armazenamento: reserva)
        #expect(!form.jaAvaliado)
        form.resposta = false
        #expect(await form.salvar() == false)
        #expect(form.jaAvaliado && form.resposta == true)
        #expect(reserva.resposta(para: novo.id, contaID: conta.id) == true)
        #expect(form.mensagemDeErro == nil)
        let reaberto = MeuTurnoViewModel(turno: novo, api: api, contaID: conta.id, armazenamentoAvaliacoes: reserva)
        #expect(reaberto.jaAvaliado && reaberto.respostaAvaliacao == true)
    }

    @Test("Aviso carrega a avaliação do servidor sem depender da reserva do aparelho")
    func avisoLeAvaliacaoDoServidor() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoAvaliado)
        let conta = try await api.minhaConta()
        let inicial = try #require(try await api.meusTurnos().first)
        let form = AvaliacaoTurnoViewModel(turnoID: inicial.id, contaID: conta.id, api: api,
                                          armazenamento: ArmazenamentoAvaliacoesEmMemoria(), repositorioTurnos: api)
        await form.carregar()
        #expect(form.turno?.id == inicial.id)
        #expect(form.jaAvaliado && form.resposta == false)
        form.resposta = true
        #expect(await form.salvar() == false)
        #expect(form.resposta == false)
    }

    @Test("Data da reserva persiste por conta e é removida ao sair")
    func instanteDaReservaPersistido() throws {
        let nome = "pr87-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        let id = UUID()
        let antes = Date()
        UserDefaultsArmazenamentoAvaliacoes(defaults: defaults).salvar(resposta: false, para: id, contaID: contaID)
        let reaberto = UserDefaultsArmazenamentoAvaliacoes(defaults: defaults)
        #expect(try #require(reaberto.registradaEm(para: id, contaID: contaID)) >= antes)
        #expect(reaberto.resposta(para: id, contaID: contaID) == false)
        #expect(reaberto.registradaEm(para: id, contaID: UUID()) == nil)
        reaberto.limpar()
        #expect(reaberto.registradaEm(para: id, contaID: contaID) == nil)
        #expect(!reaberto.jaRegistrada(para: id, contaID: contaID))
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

    @Test("Dublê registra a causa da desistência após o início sem check-in, sem devolver o motivo")
    func dubleDesistencia() async throws {
        let relogio = RelogioDeDesistencia(agora)
        let api = ApiClienteEmMemoria(cenario: .turnoConfirmadoPerto, relogio: relogio)
        let inicial = try #require(try await api.meusTurnos().first)
        #expect(inicial.checkin == nil)
        relogio.avancar(para: inicial.vaga.periodo.inicio.addingTimeInterval(60))
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

private final class RelogioDeDesistencia: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var instante: Date
    init(_ instante: Date) { self.instante = instante }
    var agora: Date { trava.withLock { instante } }
    func avancar(para instante: Date) { trava.withLock { self.instante = instante } }
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

private final class ApiSemRedeAoAvaliar: ApiClienteEncaminhador, @unchecked Sendable {
    init() { super.init(base: ApiClienteEmMemoria(cenario: .turnoEncerrado)) }
    override func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        throw ErroDaApi(codigo: .semRede)
    }
}

private actor FilaDoContrato: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    private var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) { itens.append(acao) }
    func pendentes() -> [AcaoPendente] { itens }
    func remover(id: UUID) { itens.removeAll { $0.id == id } }
    func limpar() { itens.removeAll() }
}
