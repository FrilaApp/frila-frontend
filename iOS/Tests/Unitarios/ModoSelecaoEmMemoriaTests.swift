import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// Relógio que o teste avança: a seleção fecha 24 horas antes do início (RN24).
private final class RelogioDeTeste: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(para instante: Date) { trava.withLock { _agora = instante } }
}

private let hora: TimeInterval = 3_600

/// Uma vaga de seleção publicada pela casa da fixture, com candidatos de outras contas.
private struct Cena {
    let api: ApiClienteEmMemoria
    let relogio: RelogioDeTeste
    let agora: Date
    let vagaID: UUID
    let inicio: Date
    /// As candidaturas dos outros profissionais, por ordem de chegada.
    let candidaturas: [UUID]

    static let ana = perfil(1, "Ana Cunha")
    static let bruno = perfil(2, "Bruno Tavares")
    static let carla = perfil(3, "Carla Menezes")
    static let diego = perfil(4, "Diego Rocha")

    static func perfil(_ numero: Int, _ nome: String) -> PerfilPublico {
        PerfilPublico(
            id: UUID(uuidString: "81000000-0000-0000-0000-00000000000\(numero)")!, tipo: .profissional, nome: nome, funcoes: ["Garçom"],
            reputacao: Reputacao(positivas: numero, total: numero + 1, taxaComparecimento: 0.5, turnosConsiderados: 4, turnosRealizados: 2)
        )
    }

    /// Publica a vaga para daqui a `emHoras` e recebe uma candidatura de cada profissional, com um
    /// minuto entre elas.
    static func montar(
        posicoes: Int = 1, emHoras: Double = 72, candidatos: [PerfilPublico] = [ana, bruno, carla, diego],
        cenario: ApiClienteEmMemoria.Cenario = .sucesso
    ) async throws -> Cena {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(cenario: cenario, relogio: relogio)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let funcao = try #require(try await api.funcoes().first)
        let inicio = agora.addingTimeInterval(emHoras * hora)
        let vagaID = try await api.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)),
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: posicoes, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", modo: .selecao, chave: UUID()
        )).vagaID
        var candidaturas: [UUID] = []
        for (indice, candidato) in candidatos.enumerated() {
            relogio.avancar(para: agora.addingTimeInterval(TimeInterval(indice + 1) * 60))
            candidaturas.append(try await api.receberCandidatura(vagaID: vagaID, de: candidato))
        }
        return Cena(api: api, relogio: relogio, agora: agora, vagaID: vagaID, inicio: inicio, candidaturas: candidaturas)
    }

    func vagaNoPainel() async throws -> VagaNoPainel {
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let periodo = try Periodo(inicio: agora.addingTimeInterval(-hora), fim: agora.addingTimeInterval(240 * hora))
        return try #require(try await api.painelEstabelecimento(id: casa.id, periodo: periodo).vagas.first { $0.vaga.id == vagaID })
    }

    func estadoDaVaga() async throws -> EstadoVaga { try await api.detalheDaVaga(id: vagaID).estado }

    /// O instante em que a seleção fecha: 24 horas antes do início.
    var fechamento: Date { inicio.addingTimeInterval(-24 * hora) }
}

/// O dublê segue `escolher_candidato`, `candidatos_da_vaga`, `retirar_candidatura`,
/// `minhas_candidaturas` e o fechamento automático do backend (`20260929234100_modo_selecao.sql`,
/// contrato 0.2.24). O que ele não modela está no README, em "Cenários simulados".
@Suite("Dublê: modo seleção (#10, contrato 0.2.24)")
struct ModoSelecaoEmMemoriaTests {
    // MARK: Candidatos

    @Test("Os candidatos pendentes vêm por ordem de chegada, com perfil e reputação, e o painel conta os mesmos")
    func candidatosDaVaga() async throws {
        let cena = try await Cena.montar()
        let candidatos = try await cena.api.candidatosDaVaga(id: cena.vagaID)

        #expect(candidatos.map(\.candidaturaID) == cena.candidaturas)
        #expect(candidatos.map(\.profissional) == [Cena.ana, Cena.bruno, Cena.carla, Cena.diego])
        #expect(candidatos.map(\.criadaEm) == candidatos.map(\.criadaEm).sorted())
        #expect(try await cena.vagaNoPainel().candidatosPendentes == 4)
        // O perfil público de cada candidato abre pelo id que veio na lista.
        #expect(try await cena.api.perfilPublico(id: Cena.carla.id) == Cena.carla)
    }

    @Test("O candidato que a casa bloqueou continua na lista, mas sai da conta do painel, como no backend")
    func candidatoBloqueado() async throws {
        let api = ApiClienteEmMemoria(cenario: .selecaoComCandidatos)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let vaga = try #require(try await api.vagasAbertas().first)
        let periodo = try Periodo(inicio: Date().addingTimeInterval(-hora), fim: Date().addingTimeInterval(240 * hora))
        let candidatos = try await api.candidatosDaVaga(id: vaga.id)
        #expect(try await api.painelEstabelecimento(id: casa.id, periodo: periodo).vagas.first?.candidatosPendentes == 4)

        _ = try await api.bloquear(Alvo(candidatos[1].profissional))

        // `candidatos_da_vaga` não filtra bloqueio; `candidatos_pendentes` do painel filtra.
        #expect(try await api.candidatosDaVaga(id: vaga.id) == candidatos)
        #expect(try await api.painelEstabelecimento(id: casa.id, periodo: periodo).vagas.first?.candidatosPendentes == 3)
    }

    @Test("A posição aberta tem o mesmo id a cada leitura do painel, e a escolha confirma numa delas")
    func idDaPosicaoEstavel() async throws {
        let cena = try await Cena.montar(posicoes: 2)
        let abertas = try await cena.vagaNoPainel().posicoes.filter { $0.estado == .aberta }.map(\.id)
        #expect(abertas.count == 2)
        #expect(try await cena.vagaNoPainel().posicoes.map(\.id) == abertas)

        let confirmacao = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])

        #expect(abertas.contains(confirmacao.posicaoID))
        let depois = try await cena.vagaNoPainel().posicoes
        #expect(Set(depois.map(\.id)) == Set(abertas))
        #expect(depois.first { $0.estado == .confirmada }?.id == confirmacao.posicaoID)
    }

    @Test("Vaga que não existe é 404, e a seleção não expõe os candidatos da conta em minhas candidaturas")
    func candidatosDeVagaQueNaoExiste() async throws {
        let cena = try await Cena.montar()
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { _ = try await cena.api.candidatosDaVaga(id: UUID()) }
        #expect(try await cena.api.minhasCandidaturas().isEmpty)
    }

    // MARK: Critério 1 — escolher confirma só ele e libera os outros

    @Test("Com 4 candidatos e uma posição, escolher um confirma só ele, enche a vaga e recusa os outros três")
    func escolher() async throws {
        let cena = try await Cena.montar()
        let escolhida = cena.candidaturas[1]

        let confirmacao = try await cena.api.escolherCandidato(candidaturaID: escolhida)

        // A casa recebe o contato do profissional escolhido, liberado até 7 dias depois do fim (RN10).
        #expect(confirmacao.contato.nome == Cena.bruno.nome)
        #expect(confirmacao.contato.visivelAte == cena.inicio.addingTimeInterval(4 * hora + 7 * 24 * hora))
        #expect(try await cena.api.contatoDoTurno(id: confirmacao.turnoID) == confirmacao.contato)

        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .preenchida)
        #expect(vaga.candidatosPendentes == 0)
        #expect(vaga.posicoes.count == 1)
        let posicao = try #require(vaga.posicoes.first)
        #expect(posicao.id == confirmacao.posicaoID && posicao.turnoID == confirmacao.turnoID)
        #expect(posicao.estado == .confirmada && posicao.profissional == Cena.bruno)

        // Ninguém mais espera: os outros três foram recusados, e não ficam na lista de candidatos.
        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).isEmpty)
        for outra in cena.candidaturas where outra != escolhida {
            await #expect(throws: ErroDaApi(codigo: .posicaoJaPreenchida)) { _ = try await cena.api.escolherCandidato(candidaturaID: outra) }
        }
        // O turno é do profissional escolhido, e não da conta do dublê.
        #expect(try await cena.api.meusTurnos().isEmpty)
    }

    @Test("Com duas posições, a primeira escolha deixa a vaga publicada e os outros pendentes; a segunda enche e recusa o resto")
    func escolherComDuasPosicoes() async throws {
        let cena = try await Cena.montar(posicoes: 2)

        _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])
        var vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .publicada && vaga.candidatosPendentes == 3)
        #expect(vaga.posicoes.map(\.estado) == [.confirmada, .aberta])
        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).map(\.candidaturaID) == Array(cena.candidaturas.dropFirst()))

        _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[3])
        vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .preenchida && vaga.candidatosPendentes == 0)
        #expect(vaga.posicoes.map(\.profissional) == [Cena.ana, Cena.diego])
        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).isEmpty)
    }

    @Test("Escolher não é idempotente: escolher de novo a mesma candidatura é candidatura_indisponivel, e não o mesmo turno")
    func escolherDeNovo() async throws {
        let cena = try await Cena.montar(posicoes: 2)
        _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])

        await #expect(throws: ErroDaApi(codigo: .candidaturaIndisponivel)) {
            _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])
        }
        // Nada mudou: uma posição confirmada, uma aberta, três esperando.
        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.posicoes.map(\.estado) == [.confirmada, .aberta] && vaga.candidatosPendentes == 3)
        #expect(await cena.api.chamadasAEscolherCandidato == 2)
    }

    // MARK: Critério 4 — duas escolhas para a última posição

    /// A corrida em si é garantia do backend (a trava da vaga em `escolher_candidato`), provada lá.
    /// O dublê é um `actor` e atende uma escolha depois da outra: o que este teste prova é a
    /// resposta que quem chega em segundo recebe, qualquer que seja a ordem.
    @Test("Duas escolhas para a última posição, em qualquer ordem, confirmam só uma; a que chega depois ouve posicao_ja_preenchida")
    func duasEscolhasParaAUltimaPosicao() async throws {
        let cena = try await Cena.montar()
        let api = cena.api
        let (primeira, segunda) = (cena.candidaturas[0], cena.candidaturas[1])

        @Sendable func escolher(_ candidaturaID: UUID) async -> Result<ResultadoConfirmacao, ErroDaApi> {
            do {
                return .success(try await api.escolherCandidato(candidaturaID: candidaturaID))
            } catch {
                return .failure(error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido))
            }
        }
        async let umaEscolha = escolher(primeira)
        async let outraEscolha = escolher(segunda)
        let resultados = await [umaEscolha, outraEscolha]

        let confirmadas = resultados.compactMap { try? $0.get() }
        let recusas = resultados.compactMap { resultado -> ErroDaApi? in
            if case let .failure(erro) = resultado { return erro }
            return nil
        }
        #expect(confirmadas.count == 1)
        #expect(recusas == [ErroDaApi(codigo: .posicaoJaPreenchida)])
        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.posicoes.filter { $0.estado == .confirmada }.map(\.turnoID) == confirmadas.map(\.turnoID))
        #expect(vaga.estado == .preenchida && vaga.candidatosPendentes == 0)
    }

    @Test("Cenário escolha-perde-corrida: a primeira escolha perde, e a releitura mostra quem a outra pessoa confirmou")
    func cenarioDaCorrida() async throws {
        let api = ApiClienteEmMemoria(cenario: .escolhaPerdeCorrida)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let vagaID = try #require(try await api.vagasAbertas().first?.id)
        let candidatos = try await api.candidatosDaVaga(id: vagaID)
        #expect(candidatos.count == 4)

        await #expect(throws: ErroDaApi(codigo: .posicaoJaPreenchida)) {
            _ = try await api.escolherCandidato(candidaturaID: candidatos[0].candidaturaID)
        }

        #expect(try await api.candidatosDaVaga(id: vagaID).isEmpty)
        let agora = Date()
        let painel = try await api.painelEstabelecimento(
            id: casa.id, periodo: try Periodo(inicio: agora.addingTimeInterval(-hora), fim: agora.addingTimeInterval(240 * hora))
        )
        let vaga = try #require(painel.vagas.first)
        #expect(vaga.estado == .preenchida)
        // Quem ficou com a posição foi o candidato da outra escolha, e não o desta.
        #expect(vaga.posicoes.map(\.profissional) == [candidatos[1].profissional])
        // Tentar de novo não confirma ninguém a mais.
        await #expect(throws: ErroDaApi(codigo: .posicaoJaPreenchida)) {
            _ = try await api.escolherCandidato(candidaturaID: candidatos[0].candidaturaID)
        }
    }

    // MARK: Recusas da escolha

    @Test("Candidatura que não existe é sem_permissao; vaga ocultada é vaga_oculta, e a candidatura segue pendente")
    func recusasDaEscolha() async throws {
        let cena = try await Cena.montar()
        await #expect(throws: ErroDaApi(codigo: .semPermissao)) { _ = try await cena.api.escolherCandidato(candidaturaID: UUID()) }

        await cena.api.moderar(vagaID: cena.vagaID, oculta: true)
        await #expect(throws: ErroDaApi(codigo: .vagaOculta)) {
            _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])
        }
        // A lista continua legível pela casa, e a escolha volta a valer quando a Equipe reexibe a vaga.
        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).count == 4)
        await cena.api.moderar(vagaID: cena.vagaID, oculta: false)
        _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])
    }

    @Test("O candidato com turno no mesmo horário, ou suspenso, é inelegivel com o motivo no detalhe", arguments: [
        (ApiClienteEmMemoria.Cenario.inelegivel, "turno_sobreposto"),
        (ApiClienteEmMemoria.Cenario.inelegivelSuspenso, "perfil_suspenso"),
    ])
    func candidatoInelegivel(cenario: ApiClienteEmMemoria.Cenario, detalhe: String) async throws {
        let cena = try await Cena.montar(cenario: cenario)
        await #expect(throws: ErroDaApi(codigo: .inelegivel, detalhes: detalhe)) {
            _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])
        }
        #expect(try await cena.vagaNoPainel().candidatosPendentes == 4)
    }

    // MARK: Critério 2 — fechamento automático 24 h antes

    @Test("A 24 horas do início ninguém mais se candidata nem é escolhido, mesmo antes de o agendador passar")
    func regraDas24HorasNaoDependeDoAgendador() async throws {
        let cena = try await Cena.montar()
        cena.relogio.avancar(para: cena.fechamento)

        await #expect(throws: ErroDaApi(codigo: .vagaEncerrada)) { _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0]) }
        await #expect(throws: ErroDaApi(codigo: .vagaEncerrada)) { _ = try await cena.api.candidatar(vagaID: cena.vagaID) }
        #expect(try await cena.estadoDaVaga() == .publicada)
    }

    @Test("Sem escolha até 24 horas antes, a vaga fecha: encerrada, posição cancelada e todas as candidaturas expiradas")
    func fechamentoSemEscolha() async throws {
        let cena = try await Cena.montar()
        let minha = try await cena.api.candidatar(vagaID: cena.vagaID).candidaturaID

        // Um segundo antes do prazo, o agendador não fecha nada.
        cena.relogio.avancar(para: cena.fechamento.addingTimeInterval(-1))
        #expect(await cena.api.fecharSelecoes() == 0)
        #expect(try await cena.vagaNoPainel().candidatosPendentes == 5)

        cena.relogio.avancar(para: cena.fechamento)
        #expect(await cena.api.fecharSelecoes() == 1)

        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .encerrada)
        #expect(vaga.candidatosPendentes == 0)
        #expect(vaga.posicoes.map(\.estado) == [.cancelada])
        #expect(vaga.posicoes.first?.profissional == nil && vaga.posicoes.first?.turnoID == nil)
        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).isEmpty)
        // O profissional vê a própria candidatura expirada, e não pode mais retirá-la.
        #expect(try await cena.api.minhasCandidaturas().map(\.estado) == [.expirada])
        await #expect(throws: ErroDaApi(codigo: .candidaturaIndisponivel)) { _ = try await cena.api.retirarCandidatura(id: minha) }
        // Fechar de novo não acha mais nada para fechar, e a vaga sai da lista.
        #expect(await cena.api.fecharSelecoes() == 0)
        #expect(try await cena.api.vagasAbertas().isEmpty)
        await #expect(throws: ErroDaApi(codigo: .vagaEncerrada)) { _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0]) }
    }

    @Test("Com uma posição já escolhida, o fechamento cancela a que sobrou, expira os pendentes e a vaga fica preenchida")
    func fechamentoComEscolhaParcial() async throws {
        let cena = try await Cena.montar(posicoes: 2)
        let confirmacao = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[2])

        cena.relogio.avancar(para: cena.fechamento.addingTimeInterval(5 * 60))
        #expect(await cena.api.fecharSelecoes() == 1)

        let vaga = try await cena.vagaNoPainel()
        #expect(vaga.estado == .preenchida && vaga.candidatosPendentes == 0)
        #expect(vaga.posicoes.map(\.estado) == [.confirmada, .cancelada])
        #expect(vaga.posicoes.first?.turnoID == confirmacao.turnoID && vaga.posicoes.first?.profissional == Cena.carla)
    }

    @Test("Cancelar a vaga de seleção expira as candidaturas que esperavam")
    func cancelarVagaExpiraPendentes() async throws {
        let cena = try await Cena.montar()
        _ = try await cena.api.candidatar(vagaID: cena.vagaID)

        _ = try await cena.api.cancelarVaga(id: cena.vagaID, motivo: "O evento foi adiado")

        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).isEmpty)
        #expect(try await cena.api.minhasCandidaturas().map(\.estado) == [.expirada])
    }

    // MARK: O lado do profissional

    @Test("Retirar a candidatura pendente a tira da lista da casa; retirar de novo devolve a mesma; candidatar-se de novo a reativa")
    func retirar() async throws {
        let cena = try await Cena.montar(candidatos: [Cena.ana])
        cena.relogio.avancar(para: cena.agora.addingTimeInterval(2 * hora))
        let pendente = try await cena.api.candidatar(vagaID: cena.vagaID)
        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).map(\.candidaturaID) == [cena.candidaturas[0], pendente.candidaturaID])

        let retirada = try await cena.api.retirarCandidatura(id: pendente.candidaturaID)
        #expect(retirada.id == pendente.candidaturaID && retirada.estado == .retirada && retirada.vaga.id == cena.vagaID)
        #expect(try await cena.api.retirarCandidatura(id: pendente.candidaturaID) == retirada)
        #expect(try await cena.api.candidatosDaVaga(id: cena.vagaID).map(\.candidaturaID) == [cena.candidaturas[0]])
        #expect(try await cena.api.minhasCandidaturas(estado: .pendente).isEmpty)
        #expect(try await cena.api.minhasCandidaturas(estado: .retirada) == [retirada])

        // Candidatar-se de novo é o caminho para desfazer a retirada: a mesma candidatura, com a hora nova.
        cena.relogio.avancar(para: cena.agora.addingTimeInterval(3 * hora))
        #expect(try await cena.api.candidatar(vagaID: cena.vagaID).candidaturaID == pendente.candidaturaID)
        let minhas = try await cena.api.minhasCandidaturas()
        #expect(minhas.map(\.estado) == [.pendente])
        #expect(minhas.first?.criadaEm == cena.agora.addingTimeInterval(3 * hora))
        #expect(await cena.api.chamadasARetirarCandidatura == 2)
    }

    @Test("A candidatura de outro profissional não se retira: é 404, e continua pendente")
    func retirarCandidaturaDeOutro() async throws {
        let cena = try await Cena.montar()
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { _ = try await cena.api.retirarCandidatura(id: cena.candidaturas[0]) }
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { _ = try await cena.api.retirarCandidatura(id: UUID()) }
        #expect(try await cena.vagaNoPainel().candidatosPendentes == 4)
    }

    @Test("Escolhido: a candidatura fica aceita, o turno aparece em Meus turnos com o contato da casa, e não se retira mais")
    func profissionalEscolhido() async throws {
        let cena = try await Cena.montar(candidatos: [Cena.ana, Cena.bruno])
        let minha = try await cena.api.candidatar(vagaID: cena.vagaID).candidaturaID
        #expect(try await cena.api.meusTurnos().isEmpty)

        let confirmacao = try await cena.api.escolherCandidato(candidaturaID: minha)

        let turno = try #require(try await cena.api.meusTurnos().first)
        #expect(turno.id == confirmacao.turnoID && turno.vaga.id == cena.vagaID)
        #expect(turno.contraparte.tipo == .estabelecimento)
        #expect(try await cena.api.contatoDoTurno(id: turno.id).nome == turno.contraparte.nome)
        #expect(try await cena.api.minhasCandidaturas().map(\.estado) == [.aceita])
        await #expect(throws: ErroDaApi(codigo: .candidaturaIndisponivel)) { _ = try await cena.api.retirarCandidatura(id: minha) }
        // Reenviar a candidatura devolve o turno já confirmado, mesmo com a vaga cheia.
        let reenvio = try await cena.api.candidatar(vagaID: cena.vagaID)
        #expect(reenvio.estado == .confirmada && reenvio.candidaturaID == minha && reenvio.turnoID == turno.id)
        #expect(reenvio.contato?.nome == turno.contraparte.nome)
    }

    @Test("Não escolhido: quando a casa enche a vaga com outra pessoa, a candidatura fica recusada, sem turno")
    func profissionalRecusado() async throws {
        let cena = try await Cena.montar(candidatos: [Cena.ana])
        let minha = try await cena.api.candidatar(vagaID: cena.vagaID).candidaturaID

        _ = try await cena.api.escolherCandidato(candidaturaID: cena.candidaturas[0])

        #expect(try await cena.api.minhasCandidaturas().map(\.estado) == [.recusada])
        #expect(try await cena.api.minhasCandidaturas(estado: .pendente).isEmpty)
        #expect(try await cena.api.meusTurnos().isEmpty)
        #expect(try await cena.estadoDaVaga() == .preenchida)
        await #expect(throws: ErroDaApi(codigo: .candidaturaIndisponivel)) { _ = try await cena.api.retirarCandidatura(id: minha) }
        // Para quem chega agora, a vaga cheia é "alguém chegou antes".
        await #expect(throws: ErroDaApi(codigo: .posicaoJaPreenchida)) { _ = try await cena.api.candidatar(vagaID: cena.vagaID) }
    }

    @Test("minhas_candidaturas vem da mais nova para a mais antiga, com a aceita do modo urgência, e filtra por estado")
    func minhasCandidaturas() async throws {
        let cena = try await Cena.montar(candidatos: [])
        let deUrgencia = try #require(try await cena.api.vagasAbertas().first { $0.modo == .urgencia })
        cena.relogio.avancar(para: cena.agora.addingTimeInterval(60))
        let aceita = try await cena.api.candidatar(vagaID: deUrgencia.id)
        cena.relogio.avancar(para: cena.agora.addingTimeInterval(120))
        let pendente = try await cena.api.candidatar(vagaID: cena.vagaID)

        let todas = try await cena.api.minhasCandidaturas()
        #expect(todas.map(\.id) == [pendente.candidaturaID, aceita.candidaturaID])
        #expect(todas.map(\.estado) == [.pendente, .aceita])
        #expect(todas.map(\.vaga.id) == [cena.vagaID, deUrgencia.id])
        #expect(try await cena.api.minhasCandidaturas(estado: .aceita).map(\.id) == [aceita.candidaturaID])
        #expect(try await cena.api.minhasCandidaturas(estado: .expirada).isEmpty)
    }

    // MARK: Cenários do esquema Local

    @Test("Cenário selecao-com-candidatos: conta de contratante, uma posição e os quatro candidatos da fixture")
    func cenarioComCandidatos() async throws {
        let api = ApiClienteEmMemoria(cenario: .selecaoComCandidatos)
        #expect(try await api.minhaConta().perfil == .contratante)
        let vaga = try #require(try await api.vagasAbertas().first)
        #expect(vaga.modo == .selecao && vaga.posicoesAbertas == 1)
        #expect(vaga.periodo.inicio.timeIntervalSinceNow > 24 * hora)

        let candidatos = try await api.candidatosDaVaga(id: vaga.id)
        #expect(candidatos.map(\.profissional.nome) == ["Ana Cunha", "Bruno Tavares", "Carla Menezes", "Diego Rocha"])
        #expect(candidatos.map(\.criadaEm) == candidatos.map(\.criadaEm).sorted())

        let confirmacao = try await api.escolherCandidato(candidaturaID: candidatos[2].candidaturaID)
        #expect(confirmacao.contato.nome == "Carla Menezes")
        #expect(try await api.candidatosDaVaga(id: vaga.id).isEmpty)
    }

    @Test("Cenário selecao-encerrada-sem-escolha: a vaga já fechou sozinha, sem candidato para escolher")
    func cenarioEncerrada() async throws {
        let api = ApiClienteEmMemoria(cenario: .selecaoEncerradaSemEscolha)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let agora = Date()
        let painel = try await api.painelEstabelecimento(
            id: casa.id, periodo: try Periodo(inicio: agora.addingTimeInterval(-hora), fim: agora.addingTimeInterval(240 * hora))
        )
        let vaga = try #require(painel.vagas.first)

        #expect(vaga.modo == .selecao && vaga.estado == .encerrada && vaga.candidatosPendentes == 0)
        #expect(vaga.posicoes.map(\.estado) == [.cancelada])
        #expect(vaga.vaga.periodo.inicio.timeIntervalSince(agora) < 24 * hora)
        #expect(try await api.candidatosDaVaga(id: vaga.vaga.id).isEmpty)
        #expect(try await api.vagasAbertas().isEmpty)
    }

    @Test("Cenários do profissional: vaga-em-selecao deixa a candidatura pendente; candidatura-pendente já começa com ela")
    func cenariosDoProfissional() async throws {
        let semCandidatura = ApiClienteEmMemoria(cenario: .vagaEmSelecao)
        #expect(try await semCandidatura.minhaConta().perfil == .profissional)
        let vaga = try #require(try await semCandidatura.vagasAbertas().first)
        #expect(vaga.modo == .selecao)
        #expect(try await semCandidatura.minhasCandidaturas().isEmpty)
        #expect(try await semCandidatura.candidatar(vagaID: vaga.id).estado == .pendente)

        let comCandidatura = ApiClienteEmMemoria(cenario: .candidaturaPendente)
        let pendentes = try await comCandidatura.minhasCandidaturas(estado: .pendente)
        #expect(pendentes.count == 1)
        let pendente = try #require(pendentes.first)
        #expect(try await comCandidatura.vagasAbertas().map(\.id) == [pendente.vaga.id])
        // Reenviar devolve a mesma, e retirar funciona sobre ela.
        #expect(try await comCandidatura.candidatar(vagaID: pendente.vaga.id).candidaturaID == pendente.id)
        #expect(try await comCandidatura.retirarCandidatura(id: pendente.id).estado == .retirada)
    }

    @Test("A base encaminhadora dos dublês de teste encaminha as quatro RPCs do modo seleção")
    func encaminhador() async throws {
        let base = ApiClienteEmMemoria(cenario: .selecaoComCandidatos)
        let api: any ApiCliente = ApiClienteEncaminhador(base: base)
        let vaga = try #require(try await api.vagasAbertas().first)

        let candidatos = try await api.candidatosDaVaga(id: vaga.id)
        _ = try await api.escolherCandidato(candidaturaID: try #require(candidatos.first).candidaturaID)
        #expect(await base.chamadasAEscolherCandidato == 1)
        #expect(try await api.minhasCandidaturas(estado: nil).isEmpty)
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { _ = try await api.retirarCandidatura(id: UUID()) }
        #expect(await base.chamadasARetirarCandidatura == 1)
    }
}
