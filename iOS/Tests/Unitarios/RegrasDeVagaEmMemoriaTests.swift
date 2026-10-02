import Foundation
import FrilaDados
import FrilaDominio
import Testing

/// Relógio que o teste avança: as regras da 0.2.19, da 0.2.24 e da 0.2.25 dependem do instante.
private final class RelogioDeTeste: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(para instante: Date) { trava.withLock { _agora = instante } }
}

/// O dublê segue as regras de vaga que o contrato ganhou da 0.2.19 à 0.2.25, com as recusas de
/// `candidatar` na ordem do backend (`20260929234100_modo_selecao.sql`). O que ele não modela está
/// no README, em "Cenários simulados".
@Suite("Dublê: vagas do contrato 0.2.19 a 0.2.25")
struct RegrasDeVagaEmMemoriaTests {
    private static let hora: TimeInterval = 3_600
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)

    /// Publica, pela casa da fixture, uma vaga que começa `horas` depois do relógio.
    private func publicar(
        _ api: ApiClienteEmMemoria, emHoras horas: Double, relogio: RelogioDeTeste, modo: ModoPreenchimento = .urgencia,
        posicoes: Int = 1, regiao: String = "Plano Piloto"
    ) async throws -> UUID {
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let funcao = try #require(try await api.funcoes().first)
        let inicio = relogio.agora.addingTimeInterval(horas * Self.hora)
        return try await api.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * Self.hora)),
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: regiao,
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: posicoes, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", modo: modo, chave: UUID()
        )).vagaID
    }

    private func painel(_ api: ApiClienteEmMemoria, vagaID: UUID) async throws -> VagaNoPainel {
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let periodo = try Periodo(inicio: agora.addingTimeInterval(-Self.hora), fim: agora.addingTimeInterval(120 * Self.hora))
        return try #require(try await api.painelEstabelecimento(id: casa.id, periodo: periodo).vagas.first { $0.vaga.id == vagaID })
    }

    // MARK: 0.2.20 — região administrativa

    @Test("Sem região administrativa, o cadastro e a publicação são recusados como campo obrigatório (0.2.20)")
    func regiaoObrigatoria() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(cenario: .primeiroAcesso, relogio: relogio)
        let ponto = try Coordenada(latitude: -15.8121, longitude: -47.8997)
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "regiao_administrativa")) {
            try await api.cadastrarEstabelecimento(CadastroEstabelecimento(
                nome: "Casa", documento: "11222333000181", tipo: .evento, endereco: "SCS", regiaoAdministrativa: "  ", ponto: ponto
            ))
        }
        let comEstabelecimento = ApiClienteEmMemoria(cenario: .contratante, relogio: relogio)
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "regiao_administrativa")) {
            _ = try await publicar(comEstabelecimento, emHoras: 48, relogio: relogio, regiao: "")
        }
    }

    @Test("A região informada na publicação chega à lista, ao detalhe, ao turno e ao painel (0.2.20)")
    func regiaoAcompanhaAVaga() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(relogio: relogio)
        let vagaID = try await publicar(api, emHoras: 48, relogio: relogio, regiao: "Águas Claras")

        #expect(try await api.vagasAbertas().first { $0.id == vagaID }?.regiaoAdministrativa == "Águas Claras")
        #expect(try await api.detalheDaVaga(id: vagaID).regiaoAdministrativa == "Águas Claras")
        _ = try await api.candidatar(vagaID: vagaID)
        #expect(try await api.meusTurnos().first?.vaga.regiaoAdministrativa == "Águas Claras")
        #expect(try await painel(api, vagaID: vagaID).vaga.regiaoAdministrativa == "Águas Claras")
    }

    // MARK: 0.2.19 — vaga que já começou

    @Test("Vaga que já começou sai da lista e recusa candidatura, mas o detalhe continua abrindo (0.2.19)")
    func vagaQueJaComecou() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(relogio: relogio)
        let vagaID = try await publicar(api, emHoras: 2, relogio: relogio, posicoes: 2)
        #expect(try await api.vagasAbertas().contains { $0.id == vagaID })

        // O instante do início é o mesmo em que a lista a esconde e `candidatar` passa a recusar.
        relogio.avancar(para: agora.addingTimeInterval(2 * Self.hora))

        #expect(try await api.vagasAbertas().contains { $0.id == vagaID } == false)
        await #expect(throws: ErroDaApi(codigo: .vagaEncerrada)) { try await api.candidatar(vagaID: vagaID) }
        // Não vira 404: o toque numa notificação antiga abre a vaga, com o estado real e nada para pegar.
        let detalhe = try await api.detalheDaVaga(id: vagaID)
        #expect(detalhe.estado == .publicada)
        #expect(detalhe.posicoesAbertas == 0)
    }

    // MARK: 0.2.23 — vaga ocultada pela moderação

    @Test("Vaga ocultada some da lista e não se republica, mas abre com oculta para quem já está nela (0.2.23)")
    func vagaOcultaParaQuemEstaNela() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(relogio: relogio)
        let vagaID = try await publicar(api, emHoras: 48, relogio: relogio, posicoes: 2)
        let turnoID = try #require(try await api.candidatar(vagaID: vagaID).turnoID)

        await api.moderar(vagaID: vagaID, oculta: true)

        #expect(try await api.vagasAbertas().contains { $0.id == vagaID } == false)
        // Ocultar não cancela: o estado é o do ciclo de vida, e o turno confirmado segue confirmado.
        let detalhe = try await api.detalheDaVaga(id: vagaID)
        #expect(detalhe.oculta)
        #expect(detalhe.estado == .publicada)
        #expect(try await api.meusTurnos().map(\.id) == [turnoID])
        // A casa vê "oculta pela Equipe" no painel, e republicar não contorna a moderação.
        let noPainel = try await painel(api, vagaID: vagaID)
        #expect(noPainel.oculta)
        #expect(noPainel.estado == .publicada)
        let outroDia = agora.addingTimeInterval(72 * Self.hora)
        await #expect(throws: ErroDaApi(codigo: .vagaOculta)) {
            try await api.republicarVaga(id: vagaID, periodo: try Periodo(inicio: outroDia, fim: outroDia.addingTimeInterval(4 * Self.hora)), chave: UUID())
        }

        // Reexibida pela Equipe, volta à vitrine sem ter mudado de estado.
        await api.moderar(vagaID: vagaID, oculta: false)
        #expect(try await api.vagasAbertas().contains { $0.id == vagaID })
        #expect(try await api.detalheDaVaga(id: vagaID).oculta == false)
    }

    @Test("Para quem não está na vaga ocultada, detalhe e candidatura respondem o 404 da vaga escondida (0.2.23)")
    func vagaOcultaParaOsDemais() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(relogio: relogio)
        let vagaID = try await publicar(api, emHoras: 48, relogio: relogio)

        await api.moderar(vagaID: vagaID, oculta: true)

        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await api.detalheDaVaga(id: vagaID) }
        await #expect(throws: ErroDaApi(codigo: .naoEncontrado)) { try await api.candidatar(vagaID: vagaID) }
    }

    // MARK: 0.2.24 — modo seleção

    @Test("Modo seleção: publicar exige mais de 24 h, e a candidatura fica pendente até a escolha (0.2.24)")
    func modoSelecao() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(relogio: relogio)
        // Com 24 horas ou menos, a vaga de seleção nasceria fechada (RN24).
        await #expect(throws: ErroDaApi(codigo: .selecaoSemAntecedencia)) {
            _ = try await publicar(api, emHoras: 24, relogio: relogio, modo: .selecao)
        }
        let vagaID = try await publicar(api, emHoras: 25, relogio: relogio, modo: .selecao)

        let candidatura = try await api.candidatar(vagaID: vagaID)
        #expect(candidatura.estado == .pendente)
        #expect(candidatura.posicaoID == nil && candidatura.turnoID == nil && candidatura.contato == nil)
        #expect(try await api.meusTurnos().isEmpty)
        // Reenviar devolve a mesma candidatura pendente, e a casa a vê no painel.
        #expect(try await api.candidatar(vagaID: vagaID) == candidatura)
        #expect(try await painel(api, vagaID: vagaID).candidatosPendentes == 1)

        // A 24 horas do início a vaga de seleção não aceita mais candidatura.
        relogio.avancar(para: agora.addingTimeInterval(Self.hora))
        await #expect(throws: ErroDaApi(codigo: .vagaEncerrada)) { try await api.candidatar(vagaID: vagaID) }
    }

    // MARK: 0.2.25 — estou a caminho

    @Test("Estou a caminho vale a partir de 3 h antes do início, e repetir devolve o primeiro aviso (0.2.25)")
    func aCaminho() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(relogio: relogio)
        let vagaID = try await publicar(api, emHoras: 4, relogio: relogio)
        let inicio = agora.addingTimeInterval(4 * Self.hora)
        let turnoID = try #require(try await api.candidatar(vagaID: vagaID).turnoID)

        relogio.avancar(para: inicio.addingTimeInterval(-3 * Self.hora - 1))
        await #expect(throws: ErroDaApi(codigo: .aCaminhoForaDaJanela)) { try await api.avisarACaminho(turnoID: turnoID) }
        #expect(try await api.meusTurnos().first?.aCaminhoEm == nil)

        // A borda das 3 horas está dentro da janela.
        let naBorda = inicio.addingTimeInterval(-3 * Self.hora)
        relogio.avancar(para: naBorda)
        let aviso = try await api.avisarACaminho(turnoID: turnoID)
        #expect(aviso == ResultadoACaminho(turnoID: turnoID, aCaminhoEm: naBorda))

        // O aviso gravado volta como está, mesmo com a janela já fechada.
        relogio.avancar(para: inicio.addingTimeInterval(Self.hora))
        #expect(try await api.avisarACaminho(turnoID: turnoID) == aviso)
        // O profissional o vê de volta no turno, e a casa, na posição do painel.
        #expect(try await api.meusTurnos().first?.aCaminhoEm == naBorda)
        #expect(try await painel(api, vagaID: vagaID).posicoes.first { $0.turnoID == turnoID }?.aCaminhoEm == naBorda)
    }

    @Test("Estou a caminho é aceito até 15 min depois do início, e só para o turno de quem chama (0.2.25)")
    func aCaminhoNaToleranciaDeAtraso() async throws {
        let relogio = RelogioDeTeste(agora)
        let api = ApiClienteEmMemoria(relogio: relogio)
        let vagaID = try await publicar(api, emHoras: 4, relogio: relogio, posicoes: 2)
        let inicio = agora.addingTimeInterval(4 * Self.hora)
        let noLimite = try #require(try await api.candidatar(vagaID: vagaID).turnoID)
        let atrasado = try #require(try await api.candidatar(vagaID: vagaID).turnoID)

        relogio.avancar(para: inicio.addingTimeInterval(15 * 60))
        #expect(try await api.avisarACaminho(turnoID: noLimite).aCaminhoEm == inicio.addingTimeInterval(15 * 60))

        relogio.avancar(para: inicio.addingTimeInterval(15 * 60 + 1))
        await #expect(throws: ErroDaApi(codigo: .aCaminhoForaDaJanela)) { try await api.avisarACaminho(turnoID: atrasado) }
        // Turno que não existe ou que é de outra pessoa responde igual, como no backend.
        await #expect(throws: ErroDaApi(codigo: .semPermissao)) { try await api.avisarACaminho(turnoID: UUID()) }
    }
}
