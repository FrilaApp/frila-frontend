import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

/// O que a rede pode fazer com a retirada e com as leituras, por cima do dublê em memória.
private final class ApiDoCandidato: ApiClienteEncaminhador, @unchecked Sendable {
    enum Retirada {
        /// Vai para o dublê.
        case normal
        /// Não sai do aparelho: o dublê nem é chamado.
        case semRede
        /// O servidor retira, mas a resposta se perde no caminho.
        case respostaPerdida
        case falha(ErroDaApi)
    }

    private let trava = NSLock()
    private var _retirada = Retirada.normal
    private var _falhaNasCandidaturas: ErroDaApi?
    private var _retiradasEnviadas = 0
    private var _leiturasDeCandidaturas = 0

    var retirada: Retirada {
        get { trava.withLock { _retirada } }
        set { trava.withLock { _retirada = newValue } }
    }

    var falhaNasCandidaturas: ErroDaApi? {
        get { trava.withLock { _falhaNasCandidaturas } }
        set { trava.withLock { _falhaNasCandidaturas = newValue } }
    }

    /// Quantas retiradas a tela mandou, cheguem ou não ao servidor.
    var retiradasEnviadas: Int { trava.withLock { _retiradasEnviadas } }
    var leiturasDeCandidaturas: Int { trava.withLock { _leiturasDeCandidaturas } }

    override func retirarCandidatura(id: UUID) async throws -> Candidatura {
        trava.withLock { _retiradasEnviadas += 1 }
        switch retirada {
        case .normal:
            return try await base.retirarCandidatura(id: id)
        case .semRede:
            throw ErroDaApi(codigo: .semRede)
        case .respostaPerdida:
            _ = try await base.retirarCandidatura(id: id)
            throw ErroDaApi(codigo: .desconhecido, codigoOriginal: "NSURLErrorNetworkConnectionLost")
        case let .falha(erro):
            throw erro
        }
    }

    override func minhasCandidaturas(estado: EstadoCandidatura?) async throws -> [Candidatura] {
        trava.withLock { _leiturasDeCandidaturas += 1 }
        if let falha = falhaNasCandidaturas { throw falha }
        return try await base.minhasCandidaturas(estado: estado)
    }
}

/// A conta de profissional de um cenário do dublê, com a vaga de seleção dele.
@MainActor
private struct Cena {
    let base: ApiClienteEmMemoria
    let api: ApiDoCandidato
    let vaga: Vaga

    /// `vaga.json` do dublê: os cenários do modo seleção a transformam em vaga de seleção.
    nonisolated static let vagaID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    /// `candidatura-selecao.json`: a candidatura que a conta já tem nos cenários `candidatura-*`.
    nonisolated static let candidaturaID = UUID(uuidString: "6F1C2A4E-2B7D-4C5E-9A1F-3D2E1C0B9A88")!

    init(_ cenario: ApiClienteEmMemoria.Cenario) async throws {
        base = ApiClienteEmMemoria(cenario: cenario)
        api = ApiDoCandidato(base: base)
        vaga = try await base.detalheDaVaga(id: Self.vagaID)
    }

    func candidatura() -> CandidaturaViewModel { CandidaturaViewModel(vaga: vaga, api: api) }
    func retirada(_ id: UUID = Cena.candidaturaID) -> RetirarCandidaturaViewModel { RetirarCandidaturaViewModel(candidaturaID: id, api: api) }
    func lista() -> MinhasCandidaturasViewModel { MinhasCandidaturasViewModel(api: api) }

    func estadoNoServidor(_ id: UUID = Cena.candidaturaID) async throws -> EstadoCandidatura? {
        try await base.minhasCandidaturas().first { $0.id == id }?.estado
    }
}

private typealias Textos = TextosDaCandidaturaEmSelecao

/// Conta as leituras que um view model manda.
private final class Contador: @unchecked Sendable {
    private let trava = NSLock()
    private var _total = 0
    var total: Int { trava.withLock { _total } }
    func proxima() -> Int { trava.withLock { _total += 1; return _total } }
}

@MainActor
@Suite("Candidatura em vaga de seleção: enviada, retirada e a aba Candidaturas (#10)")
struct CandidaturaEmSelecaoTests {
    // MARK: Candidatura enviada

    @Test("Candidatar-se a vaga de seleção deixa a candidatura pendente: tela própria, sem turno nem contato")
    func candidatarEmSelecao() async throws {
        let cena = try await Cena(.vagaEmSelecao)
        let vm = cena.candidatura()
        await vm.conferirCandidatura()
        #expect(vm.candidaturaPendente == nil)

        await vm.candidatar()

        guard case let .concluida(.pendente(candidaturaID)) = vm.estado else { Issue.record("esperado pendente: \(vm.estado)"); return }
        #expect(vm.candidaturaPendente == candidaturaID)
        #expect(try await cena.estadoNoServidor(candidaturaID) == .pendente)
        #expect(try await cena.base.meusTurnos().isEmpty)
    }

    @Test("O detalhe da vaga em que a conta já se candidatou mostra a candidatura enviada, achada em minhas candidaturas")
    func detalheComCandidaturaPendente() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let vm = cena.candidatura()

        await vm.conferirCandidatura()

        #expect(vm.candidaturaPendente == Cena.candidaturaID)
        #expect(!vm.conferindo)
        #expect(await cena.base.chamadasACandidatar == 0)
    }

    @Test("Vaga de urgência não consulta minhas candidaturas: lá não existe candidatura pendente")
    func urgenciaNaoConfere() async throws {
        let base = ApiClienteEmMemoria()
        let api = ApiDoCandidato(base: base)
        let aberta = try #require(try await base.vagasAbertas().first)
        let vm = CandidaturaViewModel(vaga: try await base.detalheDaVaga(id: aberta.id), api: api)

        await vm.conferirCandidatura()

        #expect(vm.candidaturaPendente == nil)
        #expect(api.leiturasDeCandidaturas == 0)
    }

    @Test("Se a conferência falha, o botão volta, e candidatar-se de novo devolve a mesma candidatura pendente")
    func conferenciaQueFalha() async throws {
        let cena = try await Cena(.candidaturaPendente)
        cena.api.falhaNasCandidaturas = ErroDaApi(codigo: .semRede)
        let vm = cena.candidatura()

        await vm.conferirCandidatura()
        #expect(vm.candidaturaPendente == nil && !vm.conferindo)

        await vm.candidatar()
        #expect(vm.estado == .concluida(.pendente(candidaturaID: Cena.candidaturaID)))
        #expect(try await cena.base.minhasCandidaturas().count == 1)
    }

    // MARK: Retirar

    @Test("Retirar pede confirmação: sem o toque no alerta nada é enviado; confirmado, a candidatura fica retirada")
    func retirarComConfirmacao() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let vm = cena.retirada()

        vm.pedirRetirada()
        #expect(vm.confirmando)
        #expect(cena.api.retiradasEnviadas == 0)
        // Cancelar no alerta só fecha a pergunta.
        vm.confirmando = false
        #expect(vm.estado == .pendente)
        #expect(try await cena.estadoNoServidor() == .pendente)

        vm.pedirRetirada()
        await vm.retirar()

        #expect(vm.estado == .retirada && vm.falha == nil && !vm.confirmando)
        #expect(cena.api.retiradasEnviadas == 1)
        #expect(try await cena.estadoNoServidor() == .retirada)
        // Retirada, a candidatura não volta a ser retirada nem pede outra confirmação.
        vm.pedirRetirada()
        #expect(!vm.confirmando)
    }

    @Test("Depois de retirar no detalhe, o botão volta, e candidatar-se de novo reativa a mesma candidatura")
    func candidatarDeNovoDepoisDeRetirar() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let detalhe = cena.candidatura()
        await detalhe.conferirCandidatura()
        let retirada = cena.retirada()
        retirada.pedirRetirada()
        await retirada.retirar()

        detalhe.candidaturaRetirada()
        #expect(detalhe.candidaturaPendente == nil && detalhe.estado == .ocioso)
        // Uma conferência que tinha saído antes da retirada não traz a candidatura de volta.
        await detalhe.conferirCandidatura()
        #expect(detalhe.candidaturaPendente == nil)

        await detalhe.candidatar()
        #expect(detalhe.estado == .concluida(.pendente(candidaturaID: Cena.candidaturaID)))
        #expect(try await cena.estadoNoServidor() == .pendente)
    }

    @Test("Sem rede, a retirada não sai do aparelho nem fica em fila: é mensagem, e tentar de novo funciona")
    func retirarSemRede() async throws {
        let cena = try await Cena(.candidaturaPendente)
        cena.api.retirada = .semRede
        let vm = cena.retirada()

        vm.pedirRetirada()
        await vm.retirar()

        #expect(vm.estado == .pendente && vm.falha == .semConexao)
        #expect(Textos.falha(.semConexao) == "Sem conexão. A candidatura não foi retirada; tente de novo quando a internet voltar.")
        #expect(await cena.base.chamadasARetirarCandidatura == 0)
        #expect(try await cena.estadoNoServidor() == .pendente)

        cena.api.retirada = .normal
        vm.pedirRetirada()
        await vm.retirar()
        #expect(vm.estado == .retirada && vm.falha == nil)
    }

    @Test("Resposta perdida depois de o servidor retirar: a tela pede nova tentativa, e ela dá certo porque retirar de novo devolve a mesma")
    func respostaPerdida() async throws {
        let cena = try await Cena(.candidaturaPendente)
        cena.api.retirada = .respostaPerdida
        let vm = cena.retirada()

        vm.pedirRetirada()
        await vm.retirar()
        #expect(vm.estado == .pendente)
        #expect(vm.falha == .api(ErroDaApi(codigo: .desconhecido, codigoOriginal: "NSURLErrorNetworkConnectionLost")))
        #expect(try await cena.estadoNoServidor() == .retirada)

        cena.api.retirada = .normal
        vm.pedirRetirada()
        await vm.retirar()
        #expect(vm.estado == .retirada && vm.falha == nil)
        #expect(cena.api.retiradasEnviadas == 2)
    }

    @Test("Um segundo toque com a retirada em voo não envia outra")
    func toqueDuplo() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let base = cena.base
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let vm = RetirarCandidaturaViewModel(
            candidaturaID: Cena.candidaturaID,
            retirar: { id in
                avisarChegada.yield()
                for await _ in liberar { break }
                return try await base.retirarCandidatura(id: id)
            },
            minhasCandidaturas: { try await base.minhasCandidaturas() }
        )

        let primeiro = Task { await vm.retirar() }
        for await _ in chegou { break }
        #expect(vm.retirando)
        await vm.retirar()
        vm.pedirRetirada()
        #expect(vm.retirando && !vm.confirmando)
        sinal.yield()
        await primeiro.value

        #expect(vm.estado == .retirada)
        #expect(await base.chamadasARetirarCandidatura == 1)
    }

    @Test("Candidatura que já teve resposta não se retira: o 409 vira a explicação do que aconteceu, e o botão some", arguments: [
        (ApiClienteEmMemoria.Cenario.candidaturaEscolhida, EstadoCandidatura.aceita, "A sua candidatura foi escolhida, e não dá mais para retirá-la. O turno está em Meus turnos."),
        (.candidaturaRecusada, .recusada, "O estabelecimento escolheu outra pessoa. Não há mais candidatura para retirar."),
        (.candidaturaExpirada, .expirada, "A vaga foi encerrada ou cancelada. Não há mais candidatura para retirar."),
    ])
    func candidaturaJaRespondida(cenario: ApiClienteEmMemoria.Cenario, estado: EstadoCandidatura, texto: String) async throws {
        let cena = try await Cena(cenario)
        let vm = cena.retirada()

        vm.pedirRetirada()
        await vm.retirar()

        #expect(vm.estado == .indisponivel)
        #expect(vm.falha == .jaRespondida(estado))
        #expect(Textos.falha(.jaRespondida(estado)) == texto)
        #expect(try await cena.estadoNoServidor() == estado)
        // Sem botão: o pedido de retirada não abre mais o alerta.
        vm.pedirRetirada()
        #expect(!vm.confirmando)
    }

    @Test("Se a releitura depois do 409 falha, a tela diz só que a candidatura já teve resposta")
    func jaRespondidaSemReleitura() async throws {
        let cena = try await Cena(.candidaturaRecusada)
        cena.api.falhaNasCandidaturas = ErroDaApi(codigo: .semRede)
        let vm = cena.retirada()

        vm.pedirRetirada()
        await vm.retirar()

        #expect(vm.estado == .indisponivel && vm.falha == .jaRespondida(nil))
        #expect(Textos.falha(.jaRespondida(nil)) == "Esta candidatura já teve resposta e não pode mais ser retirada. Veja a situação em Candidaturas.")
    }

    @Test("Candidatura que não é da conta é 404: a tela diz que não a encontrou; outra falha deixa tentar de novo")
    func outrasFalhas() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let deOutraConta = cena.retirada(UUID())
        deOutraConta.pedirRetirada()
        await deOutraConta.retirar()
        #expect(deOutraConta.estado == .indisponivel && deOutraConta.falha == .naoEncontrada)

        let erro = ErroDaApi(codigo: .limiteExcedido)
        cena.api.retirada = .falha(erro)
        let vm = cena.retirada()
        vm.pedirRetirada()
        await vm.retirar()
        #expect(vm.estado == .pendente && vm.falha == .api(erro))
        #expect(Textos.falha(.api(erro)) == "Não foi possível retirar a candidatura. Tente de novo.")
    }

    @Test("Cenário retirar-sem-rede: a candidatura está pendente, e a retirada não sai do aparelho")
    func cenarioRetirarSemRede() async throws {
        let cena = try await Cena(.retirarSemRede)
        let vm = cena.retirada()

        vm.pedirRetirada()
        await vm.retirar()

        #expect(vm.estado == .pendente && vm.falha == .semConexao)
        #expect(try await cena.estadoNoServidor() == .pendente)
    }

    // MARK: Aba Candidaturas

    @Test("A aba separa as candidaturas que esperam resposta das que já tiveram desfecho, na ordem do servidor")
    func listaDeCandidaturas() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let vm = cena.lista()
        #expect(vm.estado == .ociosa)

        await vm.carregar()

        #expect(vm.pendentes.map(\.id) == [Cena.candidaturaID])
        #expect(vm.pendentes.first?.vaga.id == Cena.vagaID)
        #expect(vm.anteriores.isEmpty)

        // A retirada feita em outra tela aparece na releitura, já entre as anteriores.
        _ = try await cena.base.retirarCandidatura(id: Cena.candidaturaID)
        await vm.atualizar()
        #expect(vm.pendentes.isEmpty)
        #expect(vm.anteriores.map(\.estado) == [.retirada])
    }

    @Test("O desfecho de cada candidatura aparece na aba: confirmada, recusada ou seleção encerrada", arguments: [
        (ApiClienteEmMemoria.Cenario.candidaturaEscolhida, EstadoCandidatura.aceita, "Confirmada: o turno está em Meus turnos"),
        (.candidaturaRecusada, .recusada, "O estabelecimento escolheu outra pessoa"),
        (.candidaturaExpirada, .expirada, "A vaga foi encerrada ou cancelada antes de a sua candidatura ser escolhida"),
    ])
    func desfechoNaLista(cenario: ApiClienteEmMemoria.Cenario, estado: EstadoCandidatura, texto: String) async throws {
        let cena = try await Cena(cenario)
        let vm = cena.lista()

        await vm.carregar()

        #expect(vm.pendentes.isEmpty)
        #expect(vm.anteriores.map(\.estado) == [estado])
        #expect(Textos.estado(estado) == texto)
    }

    @Test("Conta sem candidatura carrega vazia, e não como falha")
    func listaVazia() async throws {
        let vm = MinhasCandidaturasViewModel(api: ApiClienteEmMemoria(cenario: .vagaEmSelecao))
        await vm.carregar()
        #expect(vm.estado == .carregadas([]))
    }

    @Test("Sem rede a aba diz que está sem conexão; outra falha é erro; tentar de novo recupera")
    func falhasDaLista() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let vm = cena.lista()

        cena.api.falhaNasCandidaturas = ErroDaApi(codigo: .semRede)
        await vm.carregar()
        #expect(vm.estado == .semConexao)

        cena.api.falhaNasCandidaturas = ErroDaApi(codigo: .desconhecido)
        await vm.carregar()
        #expect(vm.estado == .falha)

        cena.api.falhaNasCandidaturas = nil
        await vm.carregar()
        #expect(vm.candidaturas.count == 1 && !vm.desatualizada)
    }

    @Test("Com candidaturas na tela, a releitura que falha não as apaga: avisa que podem estar desatualizadas")
    func releituraQueFalha() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let vm = cena.lista()
        await vm.carregar()

        cena.api.falhaNasCandidaturas = ErroDaApi(codigo: .semRede)
        await vm.atualizar()
        #expect(vm.candidaturas.count == 1 && vm.desatualizada)

        cena.api.falhaNasCandidaturas = nil
        await vm.atualizar()
        #expect(vm.candidaturas.count == 1 && !vm.desatualizada)
    }

    @Test("Leitura cancelada com a tela saindo não prende a aba em carregando: volta ao início, e a próxima abertura carrega")
    func leituraCancelada() async throws {
        let base = ApiClienteEmMemoria(cenario: .candidaturaPendente)
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let contador = Contador()
        let vm = MinhasCandidaturasViewModel(buscar: {
            if contador.proxima() == 1 {
                // A primeira leitura é a que a tela cancela: a rede responde com o cancelamento.
                avisarChegada.yield()
                for await _ in liberar { break }
                throw CancellationError()
            }
            return try await base.minhasCandidaturas()
        })

        let leitura = Task { await vm.carregar() }
        for await _ in chegou { break }
        #expect(vm.estado == .carregando)
        leitura.cancel()
        sinal.yield()
        await leitura.value

        #expect(vm.estado == .ociosa)
        await vm.carregar()
        #expect(vm.candidaturas.count == 1)
    }

    @Test("Na primeira abertura a aba lê uma vez só, mesmo com a tela carregando e a troca de aba pedindo a releitura ao mesmo tempo")
    func leituraUnicaNaPrimeiraAbertura() async throws {
        let cena = try await Cena(.candidaturaPendente)
        let vm = cena.lista()

        // Antes da primeira leitura, a releitura não lê: quem carrega é a tela.
        await vm.atualizar()
        #expect(vm.estado == .ociosa && cena.api.leiturasDeCandidaturas == 0)

        async let daTela: Void = vm.carregar()
        async let daTrocaDeAba: Void = vm.atualizar()
        async let outraDaTela: Void = vm.carregar()
        _ = await (daTela, daTrocaDeAba, outraDaTela)

        #expect(vm.candidaturas.count == 1)
        #expect(cena.api.leiturasDeCandidaturas == 1)
    }

    @Test("Releitura pedida com outra em voo não abre uma segunda chamada ao mesmo tempo, mas a lista é lida de novo quando a primeira volta")
    func releituraComOutraEmVoo() async throws {
        let base = ApiClienteEmMemoria(cenario: .candidaturaPendente)
        let (liberar, sinal) = AsyncStream<Void>.makeStream()
        let (chegou, avisarChegada) = AsyncStream<Void>.makeStream()
        let contador = Contador()
        let vm = MinhasCandidaturasViewModel(buscar: {
            let leitura = contador.proxima()
            // A segunda leitura sai antes da retirada e só volta depois dela, com a lista velha.
            let lista = try await base.minhasCandidaturas()
            if leitura == 2 {
                avisarChegada.yield()
                for await _ in liberar { break }
            }
            return lista
        })
        await vm.carregar()

        let primeira = Task { await vm.atualizar() }
        for await _ in chegou { break }
        _ = try await base.retirarCandidatura(id: Cena.candidaturaID)
        await vm.atualizar()
        #expect(contador.total == 2, "com uma leitura em voo, a outra não sai ao mesmo tempo")
        sinal.yield()
        await primeira.value

        #expect(contador.total == 3)
        #expect(vm.pendentes.isEmpty && vm.anteriores.map(\.estado) == [.retirada])
    }

    // MARK: O que a pessoa vê quando a vaga não está mais disponível

    @Test("Vaga indisponível: a candidatura recusada ou expirada explica o que houve; sem ela, vale o estado da vaga")
    func textosDaVagaIndisponivel() {
        let recusada = TelaVagaIndisponivel.textos(motivo: .preenchida, candidatura: .recusada, modo: .selecao)
        #expect(recusada.titulo == "O estabelecimento escolheu outra pessoa")
        #expect(recusada.mensagem == "A vaga foi preenchida, e a sua candidatura não foi escolhida.")

        let expirada = TelaVagaIndisponivel.textos(motivo: .encerrada, candidatura: .expirada, modo: .selecao)
        #expect(expirada.titulo == "A seleção desta vaga foi encerrada")
        #expect(expirada.mensagem == "A vaga fechou sem que a sua candidatura fosse escolhida.")

        // Sem candidatura da conta: o texto da urgência não vale para a vaga em que a casa escolhe.
        let selecaoCheia = TelaVagaIndisponivel.textos(motivo: .preenchida, candidatura: nil, modo: .selecao)
        #expect(selecaoCheia.titulo == TextosDoProfissional.Candidatura.preenchidaTitulo)
        #expect(selecaoCheia.mensagem == "O estabelecimento já escolheu quem vai trabalhar nesta vaga.")
        let urgenciaCheia = TelaVagaIndisponivel.textos(motivo: .preenchida, candidatura: nil, modo: .urgencia)
        #expect(urgenciaCheia.mensagem == TextosDoProfissional.Candidatura.preenchidaMensagem)

        // A candidatura que esperava também expira quando a casa cancela a vaga: a tela diz que foi isso.
        let cancelada = TelaVagaIndisponivel.textos(motivo: .encerrada, candidatura: .expirada, modo: .selecao, vagaCancelada: true)
        #expect(cancelada.titulo == "O estabelecimento cancelou esta vaga")
        #expect(cancelada.mensagem == "A sua candidatura foi encerrada junto com a vaga.")
        // A recusada continua recusada, e sem candidatura a vaga cancelada lê o texto de sempre.
        #expect(TelaVagaIndisponivel.textos(motivo: .encerrada, candidatura: .recusada, modo: .selecao, vagaCancelada: true).titulo == recusada.titulo)
        #expect(TelaVagaIndisponivel.textos(motivo: .encerrada, candidatura: nil, modo: .selecao, vagaCancelada: true).mensagem == TextosDoProfissional.Candidatura.encerradaMensagem)

        // A retirada não muda o que a tela diz da vaga, e a tela não diz que foi a pessoa: o servidor
        // também passa a `retirada` a candidatura da casa que foi suspensa ou excluída.
        #expect(Textos.estado(.retirada) == "Candidatura retirada")
        let retirada = TelaVagaIndisponivel.textos(motivo: .encerrada, candidatura: .retirada, modo: .selecao)
        #expect(retirada.titulo == TextosDoProfissional.Candidatura.encerradaTitulo)
        #expect(retirada.mensagem == TextosDoProfissional.Candidatura.encerradaMensagem)
        let semVaga = TelaVagaIndisponivel.textos(motivo: .naoEncontrada, candidatura: nil, modo: nil)
        #expect(semVaga.mensagem == TextosDoProfissional.Candidatura.naoEncontrada)
    }

    // MARK: Vaga indisponível: candidatura antes do turno

    @Test("A candidatura recusada ou expirada vem antes do turno: um turno antigo da conta na mesma vaga não toma o lugar da explicação", arguments: [
        EstadoCandidatura.recusada, .expirada,
    ])
    func candidaturaAntesDoTurno(estado: EstadoCandidatura) async throws {
        // O turno cancelado continua em `meus_turnos`: aqui, um turno da conta na mesma vaga.
        let turno = try #require(try await ApiClienteEmMemoria(cenario: .candidaturaEscolhida).meusTurnos().first)
        let candidatura = Candidatura(id: Cena.candidaturaID, vaga: turno.vaga, estado: estado, criadaEm: .now)

        let busca = BuscaDaVagaDoAviso.decidir(vagaID: turno.vaga.id, candidaturas: [candidatura], turnos: [turno])

        #expect(busca == .semTurno(candidatura: estado))
    }

    @Test("Com candidatura aceita, pendente ou retirada, sem candidatura ou sem conseguir lê-las, o turno da conta na vaga é o destino", arguments: [
        EstadoCandidatura.aceita, .pendente, .retirada, nil,
    ])
    func turnoDaConta(estado: EstadoCandidatura?) async throws {
        let turno = try #require(try await ApiClienteEmMemoria(cenario: .candidaturaEscolhida).meusTurnos().first)
        let candidaturas = estado.map { [Candidatura(id: Cena.candidaturaID, vaga: turno.vaga, estado: $0, criadaEm: .now)] }

        #expect(BuscaDaVagaDoAviso.decidir(vagaID: turno.vaga.id, candidaturas: candidaturas, turnos: [turno]) == .achou(turno))
        #expect(BuscaDaVagaDoAviso.decidir(vagaID: turno.vaga.id, candidaturas: [], turnos: [turno]) == .achou(turno))
        // Sem turno, ou sem conseguir ler os turnos, a tela fica com o que sabe da candidatura.
        #expect(BuscaDaVagaDoAviso.decidir(vagaID: turno.vaga.id, candidaturas: candidaturas, turnos: []) == .semTurno(candidatura: estado))
        #expect(BuscaDaVagaDoAviso.decidir(vagaID: turno.vaga.id, candidaturas: candidaturas, turnos: nil) == .semTurno(candidatura: estado))
        // A candidatura e o turno de outra vaga não entram na decisão.
        #expect(BuscaDaVagaDoAviso.decidir(vagaID: UUID(), candidaturas: candidaturas, turnos: [turno]) == .semTurno(candidatura: nil))
    }

    @Test("A busca lê as candidaturas e os turnos da conta: escolhida abre o turno; recusada e expirada, a explicação; leitura que falha não vira explicação errada")
    func buscaNaApi() async throws {
        let escolhida = try await Cena(.candidaturaEscolhida)
        let turno = try #require(try await escolhida.base.meusTurnos().first)
        #expect(await BuscaDaVagaDoAviso.procurar(vagaID: Cena.vagaID, api: escolhida.api, repositorio: escolhida.api) == .achou(turno))

        let recusada = try await Cena(.candidaturaRecusada)
        #expect(await BuscaDaVagaDoAviso.procurar(vagaID: Cena.vagaID, api: recusada.api, repositorio: recusada.api) == .semTurno(candidatura: .recusada))
        let expirada = try await Cena(.candidaturaExpirada)
        #expect(await BuscaDaVagaDoAviso.procurar(vagaID: Cena.vagaID, api: expirada.api, repositorio: expirada.api) == .semTurno(candidatura: .expirada))

        // Sem ler as candidaturas, a tela não inventa desfecho: fica com o estado da vaga.
        recusada.api.falhaNasCandidaturas = ErroDaApi(codigo: .semRede)
        #expect(await BuscaDaVagaDoAviso.procurar(vagaID: Cena.vagaID, api: recusada.api, repositorio: recusada.api) == .semTurno(candidatura: nil))
    }

    @Test("Ver minhas candidaturas leva à aba, com a pilha de Vagas limpa")
    func abrirCandidaturas() {
        let roteador = RoteadorDoProfissional()
        roteador.caminho = [.detalhe(vagaID: Cena.vagaID)]

        roteador.abrirCandidaturas()

        #expect(roteador.aba == .candidaturas && roteador.caminho.isEmpty)
    }

    // MARK: Textos

    @Test("Todo texto da candidatura em seleção está no catálogo pt-BR")
    func textosNoCatalogo() throws {
        struct Catalogo: Decodable { let strings: [String: Entrada] }
        struct Entrada: Decodable {}
        let raiz = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalogo = try JSONDecoder().decode(Catalogo.self, from: Data(contentsOf: raiz.appending(path: "Resources/Localizable.xcstrings")))
        // Lê os literais do código, e não uma lista copiada: texto novo sem entrada no catálogo falha aqui.
        let fonte = try String(contentsOf: raiz.appending(path: "Sources/Apresentacao/Fluxos/Profissional/CandidaturaEmSelecao.swift"), encoding: .utf8)
        let literal = #/String\(localized: "([^"]+)", bundle: bundleApresentacao\)/#
        let textos = fonte.matches(of: literal).map { String($0.output.1) }

        #expect(textos.count >= 38, "nenhum texto encontrado")
        #expect(textos.filter { catalogo.strings[$0] == nil }.isEmpty)
    }
}
