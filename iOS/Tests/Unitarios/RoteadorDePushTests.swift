@testable import FrilaApresentacao
@testable import FrilaDados
import Foundation
import FrilaDominio
import Testing

private enum IDs {
    static let vaga = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    static let turno = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
    static let posicao = "50000000-0000-0000-0000-000000000001"
    static let casa = "30000000-0000-0000-0000-000000000001"
    static let conta = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let outraConta = UUID(uuidString: "10000000-0000-0000-0000-0000000000ff")!
}

private let desde = Date(timeIntervalSince1970: 1_790_000_000)
private let depois = desde.addingTimeInterval(60)

private func conta(_ fluxo: FluxoDaConta, vinculo: VinculoDoAparelho? = VinculoDoAparelho(contaID: IDs.conta, desde: desde)) -> ContaNoAparelho {
    ContaNoAparelho(contaID: IDs.conta, fluxo: fluxo, vinculo: vinculo)
}

/// Um tipo de aviso, com o payload que o backend grava para ele e a tela que abre em cada perfil.
/// Os payloads foram conferidos nas migrações do frila-backend (`origin/develop`, 6d96d88): cada
/// emissão passa por `privado.notificar`, que só aceita `vaga_id`, `posicao_id`, `turno_id`,
/// `estabelecimento_id` e `reaberta`, e acrescenta o `tipo`.
struct CasoDoAviso: Sendable, CustomTestStringConvertible {
    let tipo: String
    var payload: [String: String] = [:]
    var profissional: DestinoDoProfissional?
    var contratante: AvisoDoContratante?
    var daConta = false

    var testDescription: String { payload.count > 1 ? "\(tipo) com \(payload.keys.sorted().joined(separator: ", "))" : tipo }

    static let vagaID = ["vaga_id": IDs.vaga.uuidString.lowercased()]
    static let turnoID = ["turno_id": IDs.turno.uuidString.lowercased()]
    static let turnoEVaga = turnoID.merging(vagaID) { a, _ in a }

    static let todos: [CasoDoAviso] = [
        CasoDoAviso(tipo: "vaga", payload: vagaID, profissional: .vaga(IDs.vaga)),
        CasoDoAviso(tipo: "vaga", payload: vagaID.merging(["reaberta": "true"]) { a, _ in a }, profissional: .vaga(IDs.vaga)),
        CasoDoAviso(tipo: "vagas_agrupadas", profissional: .vagas),
        CasoDoAviso(tipo: "vaga_sem_elegiveis", payload: vagaID, contratante: .vaga(vagaID: IDs.vaga)),
        CasoDoAviso(tipo: "confirmacao", payload: turnoEVaga, profissional: .turno(IDs.turno), contratante: .turno(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "lembrete_24h", payload: turnoID, profissional: .turno(IDs.turno), contratante: .turno(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "lembrete_24h", payload: turnoID.merging(["estabelecimento_id": IDs.casa]) { a, _ in a },
             profissional: .turno(IDs.turno), contratante: .turno(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "lembrete_3h", payload: turnoID, profissional: .turno(IDs.turno), contratante: .turno(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "inicio_sem_checkin", payload: turnoID, profissional: .turno(IDs.turno)),
        CasoDoAviso(tipo: "atraso_15min", payload: turnoID.merging(["posicao_id": IDs.posicao]) { a, _ in a }, contratante: .atraso(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "fim_sem_checkout", payload: turnoID, profissional: .turno(IDs.turno), contratante: .turno(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "vaga_vazia", payload: vagaID.merging(["posicao_id": IDs.posicao]) { a, _ in a }, contratante: .vagaVazia(vagaID: IDs.vaga)),
        CasoDoAviso(tipo: "checkin", payload: turnoEVaga, contratante: .turno(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "checkin_manual_pendente", payload: turnoEVaga, contratante: .checkinManualPendente(turnoID: IDs.turno)),
        // Quem tinha a posição: o payload traz a posição, a vaga e `reaberta`, e nunca o turno.
        CasoDoAviso(tipo: "cancelamento", payload: vagaID.merging(["posicao_id": IDs.posicao, "reaberta": "false"]) { a, _ in a },
             profissional: .meusTurnos, contratante: .vaga(vagaID: IDs.vaga)),
        // O candidato de uma vaga recolhida (conta excluída ou suspensa): sem posição.
        CasoDoAviso(tipo: "cancelamento", payload: vagaID.merging(["reaberta": "false"]) { a, _ in a },
             profissional: .vaga(IDs.vaga), contratante: .vaga(vagaID: IDs.vaga)),
        CasoDoAviso(tipo: "avaliacao_disponivel", payload: turnoID, profissional: .avaliacao(turnoID: IDs.turno), contratante: .turno(turnoID: IDs.turno)),
        CasoDoAviso(tipo: "suspensao", daConta: true),
        CasoDoAviso(tipo: "reativacao", daConta: true),
        CasoDoAviso(tipo: "candidatura_recusada", payload: vagaID, profissional: .vaga(IDs.vaga)),
        CasoDoAviso(tipo: "selecao_encerrada", payload: vagaID, profissional: .vaga(IDs.vaga), contratante: .vaga(vagaID: IDs.vaga)),
    ]

    /// O `userInfo` como chega do APNs: os campos de `data` na raiz, ao lado do `aps` e das chaves do FCM.
    var userInfo: [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Frila", "body": "Aviso"], "sound": "default"],
            "gcm.message_id": "1790000000000000",
            "google.c.a.e": "1",
            "tipo": tipo,
        ]
        payload.forEach { info[$0.key] = $0.value }
        return info
    }
}

@Suite("Push: a tela que cada tipo de aviso abre (#8)")
struct DestinoDeCadaTipoTests {
    @Test("A tabela cobre os dezoito tipos do backend, e o app não conhece nenhum a mais")
    func cobertura() {
        let doBackend: Set<String> = [
            "vaga", "vagas_agrupadas", "vaga_sem_elegiveis", "confirmacao", "lembrete_24h", "lembrete_3h",
            "inicio_sem_checkin", "atraso_15min", "fim_sem_checkout", "vaga_vazia", "checkin", "checkin_manual_pendente",
            "cancelamento", "avaliacao_disponivel", "suspensao", "reativacao", "candidatura_recusada", "selecao_encerrada",
        ]
        #expect(Set(TipoDeAviso.allCases.map(\.rawValue)) == doBackend)
        #expect(Set(CasoDoAviso.todos.map(\.tipo)) == doBackend)
    }

    @Test("Para quem trabalha", arguments: CasoDoAviso.todos)
    func profissional(caso: CasoDoAviso) {
        let decisao = RoteadorDePush.decidir(payload: caso.userInfo, entregueEm: depois, conta: conta(.profissional))
        if caso.daConta {
            #expect(decisao == .abrir(.situacaoDaConta))
        } else if let destino = caso.profissional {
            #expect(decisao == .abrir(.profissional(destino)))
        } else {
            #expect(decisao == .ignorar(.semDestino))
        }
    }

    @Test("Para quem contrata", arguments: CasoDoAviso.todos)
    func contratante(caso: CasoDoAviso) {
        let decisao = RoteadorDePush.decidir(payload: caso.userInfo, entregueEm: depois, conta: conta(.contratante))
        if caso.daConta {
            #expect(decisao == .abrir(.situacaoDaConta))
        } else if let destino = caso.contratante {
            #expect(decisao == .abrir(.contratante(destino)))
        } else {
            #expect(decisao == .ignorar(.semDestino))
        }
    }

    @Test("Conta sem fluxo montado só abre o aviso que é da conta", arguments: CasoDoAviso.todos)
    func semFluxo(caso: CasoDoAviso) {
        let decisao = RoteadorDePush.decidir(payload: caso.userInfo, entregueEm: depois, conta: conta(.nenhum))
        #expect(decisao == (caso.daConta ? .abrir(.situacaoDaConta) : .ignorar(.semDestino)))
    }

    @Test("Sem o id de que a tela precisa, ou com id que não é UUID, o aviso não abre nada", arguments: [
        ("vaga", [:]), ("vaga", ["vaga_id": "não é uuid"]), ("confirmacao", ["vaga_id": "40000000-0000-0000-0000-000000000001"]),
        ("avaliacao_disponivel", [:]), ("cancelamento", [:]), ("checkin", [:]), ("vaga_vazia", ["posicao_id": "50000000-0000-0000-0000-000000000001"]),
    ] as [(String, [String: String])])
    func semId(tipo: String, payload: [String: String]) {
        let userInfo = payload.merging(["tipo": tipo]) { a, _ in a }
        #expect(RoteadorDePush.decidir(payload: userInfo, entregueEm: depois, conta: conta(.profissional)) == .ignorar(.semDestino))
        #expect(RoteadorDePush.decidir(payload: userInfo, entregueEm: depois, conta: conta(.contratante)) == .ignorar(.semDestino))
    }

    @Test("Payload sem tipo, com tipo desconhecido ou com tipo que não é texto não é um aviso")
    func payloadInvalido() {
        let payloads: [[AnyHashable: Any]] = [
            [:], ["aps": ["alert": "Oi"]], ["tipo": "tipo_que_nao_existe", "vaga_id": IDs.vaga.uuidString], ["tipo": 7],
        ]
        for payload in payloads {
            #expect(AvisoDePush(payload: payload) == nil)
            #expect(RoteadorDePush.decidir(payload: payload, entregueEm: depois, conta: conta(.profissional)) == .ignorar(.payloadInvalido))
        }
    }

    @Test("O aviso lido devolve os mesmos campos que o servidor mandou")
    func idaEVolta() throws {
        let aviso = try #require(AvisoDePush(payload: ["tipo": "atraso_15min", "turno_id": IDs.turno.uuidString, "posicao_id": IDs.posicao]))
        #expect(aviso == AvisoDePush(tipo: .atraso15min, turnoID: IDs.turno, posicaoID: UUID(uuidString: IDs.posicao)))
        #expect(aviso.payload == ["tipo": "atraso_15min", "turno_id": IDs.turno.uuidString.lowercased(), "posicao_id": IDs.posicao])
    }
}

@Suite("Push: o aviso só abre para a conta que está no aparelho (#8, #162)")
struct ContaDoPushTests {
    private let vaga: [AnyHashable: Any] = ["tipo": "vaga", "vaga_id": IDs.vaga.uuidString]

    @Test("Sem sessão, nada abre")
    func semSessao() {
        #expect(RoteadorDePush.decidir(payload: vaga, entregueEm: depois, conta: nil) == .ignorar(.semSessao))
    }

    @Test("Sem o servidor ter confirmado o aparelho para a conta, nada abre")
    func semVinculo() {
        let decisao = RoteadorDePush.decidir(payload: vaga, entregueEm: depois, conta: conta(.profissional, vinculo: nil))
        #expect(decisao == .ignorar(.deOutraConta))
    }

    @Test("Aparelho ainda entregue a outra conta: o aviso é dela, e não abre para quem está na tela")
    func vinculoDeOutraConta() {
        let deOutra = VinculoDoAparelho(contaID: IDs.outraConta, desde: desde)
        let decisao = RoteadorDePush.decidir(payload: vaga, entregueEm: depois, conta: conta(.profissional, vinculo: deOutra))
        #expect(decisao == .ignorar(.deOutraConta))
    }

    @Test("Aviso entregue antes de o aparelho ser da conta era de quem estava antes, e não abre")
    func entregueAntes() {
        let antes = desde.addingTimeInterval(-1)
        #expect(RoteadorDePush.decidir(payload: vaga, entregueEm: antes, conta: conta(.profissional)) == .ignorar(.deOutraConta))
        // Até o aviso que é da conta: a suspensão de quem estava antes não reavalia quem está agora.
        #expect(RoteadorDePush.decidir(payload: ["tipo": "suspensao"], entregueEm: antes, conta: conta(.profissional)) == .ignorar(.deOutraConta))
        #expect(RoteadorDePush.decidir(payload: vaga, entregueEm: desde, conta: conta(.profissional)) == .abrir(.profissional(.vaga(IDs.vaga))))
    }
}

@MainActor
@Suite("Push: o ponto único manda para o roteador certo e não deixa rastro quando ignora (#8)")
struct RoteadorDePushTests {
    private let profissional = RoteadorDoProfissional()
    private let contratante = RoteadorDoContratante()
    private let roteador: RoteadorDePush

    init() {
        roteador = RoteadorDePush(profissional: profissional, contratante: contratante)
    }

    private func payload(_ tipo: String, _ ids: [String: String] = [:]) -> [AnyHashable: Any] {
        ids.merging(["tipo": tipo]) { a, _ in a }
    }

    private var nadaAbriu: Bool {
        profissional.caminho.isEmpty && profissional.aba == .vagas && profissional.avisosAbertos == 0
            && contratante.caminho.isEmpty && contratante.avisosAbertos == 0 && roteador.reavaliacoesDaConta == 0
    }

    @Test("Cada destino de quem trabalha vira aba e pilha, substituindo o que estava aberto", arguments: [
        (DestinoDoProfissional.vaga(IDs.vaga), AbaDoProfissional.vagas, [RotaDoProfissional.vagaDoAviso(vagaID: IDs.vaga)]),
        (.vagas, .vagas, []),
        (.turno(IDs.turno), .vagas, [.turnoDoAviso(turnoID: IDs.turno)]),
        (.meusTurnos, .turnos, []),
        (.avaliacao(turnoID: IDs.turno), .vagas, [.avaliacao(turnoID: IDs.turno)]),
    ] as [(DestinoDoProfissional, AbaDoProfissional, [RotaDoProfissional])])
    func destinosDoProfissional(destino: DestinoDoProfissional, aba: AbaDoProfissional, caminho: [RotaDoProfissional]) {
        profissional.aba = .turnos
        profissional.caminho = [.meuPerfil, .detalhe(vagaID: UUID())]

        profissional.abrir(destino)

        #expect(profissional.aba == aba)
        #expect(profissional.caminho == caminho)
        #expect(profissional.avisosAbertos == 1)
    }

    @Test("O toque de quem trabalha abre a vaga no roteador do profissional, e só nele")
    func tocarComoProfissional() {
        roteador.contaAtiva(conta(.profissional))

        let decisao = roteador.tocar(payload: payload("vaga", ["vaga_id": IDs.vaga.uuidString]), entregueEm: depois)

        #expect(decisao == .abrir(.profissional(.vaga(IDs.vaga))))
        #expect(profissional.caminho == [.vagaDoAviso(vagaID: IDs.vaga)])
        #expect(contratante.caminho.isEmpty && contratante.avisosAbertos == 0)
    }

    @Test("O toque de quem contrata abre o turno no roteador do contratante, e só nele")
    func tocarComoContratante() {
        roteador.contaAtiva(conta(.contratante))

        let decisao = roteador.tocar(payload: payload("checkin_manual_pendente", ["turno_id": IDs.turno.uuidString]), entregueEm: depois)

        #expect(decisao == .abrir(.contratante(.checkinManualPendente(turnoID: IDs.turno))))
        #expect(contratante.caminho == [.turno(turnoID: IDs.turno)])
        #expect(contratante.avisosAbertos == 1)
        #expect(profissional.caminho.isEmpty && profissional.avisosAbertos == 0)
    }

    @Test("Suspensão e reativação pedem a reavaliação da conta, sem mexer em nenhuma pilha", arguments: ["suspensao", "reativacao"])
    func situacaoDaConta(tipo: String) {
        roteador.contaAtiva(conta(.profissional))
        profissional.caminho = [.meuPerfil]

        #expect(roteador.tocar(payload: payload(tipo), entregueEm: depois) == .abrir(.situacaoDaConta))
        #expect(roteador.reavaliacoesDaConta == 1)
        #expect(profissional.caminho == [.meuPerfil])
    }

    @Test("Push de outra conta não abre nada: nem pilha, nem aba, nem releitura", arguments: [
        ("vaga", ["vaga_id": "40000000-0000-0000-0000-000000000001"]),
        ("confirmacao", ["turno_id": "60000000-0000-0000-0000-000000000001"]),
        ("suspensao", [:]),
    ] as [(String, [String: String])])
    func deOutraConta(tipo: String, ids: [String: String]) {
        // Quem está na tela entrou depois: o aparelho só passou a ser dela em `desde`.
        roteador.contaAtiva(conta(.profissional))

        let decisao = roteador.tocar(payload: payload(tipo, ids), entregueEm: desde.addingTimeInterval(-3_600))

        #expect(decisao == .ignorar(.deOutraConta))
        #expect(nadaAbriu)
    }

    @Test("Aviso do outro perfil não abre nada")
    func doOutroPerfil() {
        roteador.contaAtiva(conta(.profissional))
        #expect(roteador.tocar(payload: payload("vaga_vazia", ["vaga_id": IDs.vaga.uuidString]), entregueEm: depois) == .ignorar(.semDestino))
        #expect(nadaAbriu)
    }

    @Test("App aberto pelo toque: a decisão espera a conta ser conhecida e abre quando ela chega")
    func toquePendente() {
        #expect(roteador.tocar(payload: payload("vaga", ["vaga_id": IDs.vaga.uuidString]), entregueEm: depois) == nil)
        #expect(nadaAbriu)
        #expect(roteador.ultimaDecisao == nil)

        roteador.contaAtiva(conta(.profissional))

        #expect(roteador.ultimaDecisao == .abrir(.profissional(.vaga(IDs.vaga))))
        #expect(profissional.caminho == [.vagaDoAviso(vagaID: IDs.vaga)])

        // O toque foi consumido: a conta informada de novo não o reabre.
        profissional.voltarParaLista()
        roteador.contaAtiva(conta(.profissional))
        #expect(profissional.caminho.isEmpty)
    }

    @Test("App aberto pelo toque sem sessão: o toque é descartado e não reaparece depois de uma entrada")
    func toquePendenteSemSessao() {
        roteador.tocar(payload: payload("vaga", ["vaga_id": IDs.vaga.uuidString]), entregueEm: depois)

        roteador.semSessao()
        #expect(roteador.ultimaDecisao == .ignorar(.semSessao))

        roteador.contaAtiva(conta(.profissional))
        #expect(nadaAbriu)
    }

    @Test("Toque pendente de antes da entrada não abre para quem entrou")
    func toquePendenteDeOutraConta() {
        roteador.tocar(payload: payload("vaga", ["vaga_id": IDs.vaga.uuidString]), entregueEm: desde.addingTimeInterval(-60))

        // Primeiro o vínculo guardado, que ainda não existe; depois o que o servidor confirmou.
        roteador.contaAtiva(conta(.profissional, vinculo: nil))
        roteador.contaAtiva(conta(.profissional))

        #expect(roteador.ultimaDecisao == .ignorar(.deOutraConta))
        #expect(nadaAbriu)
    }

    @Test("Depois da saída, o toque não abre nada até outra conta entrar")
    func depoisDaSaida() {
        roteador.contaAtiva(conta(.profissional))
        roteador.semSessao()

        #expect(roteador.tocar(payload: payload("vaga", ["vaga_id": IDs.vaga.uuidString]), entregueEm: depois) == .ignorar(.semSessao))
        #expect(nadaAbriu)
    }

    @Test("Com o app aberto, só é mostrada a notificação da conta que está na tela")
    func mostradaComOAppAberto() {
        // Abertura a frio: a conta ainda não é conhecida.
        #expect(!roteador.eDaContaAtiva(entregueEm: depois))

        roteador.contaAtiva(conta(.profissional, vinculo: nil))
        #expect(!roteador.eDaContaAtiva(entregueEm: depois))

        roteador.contaAtiva(conta(.profissional, vinculo: VinculoDoAparelho(contaID: IDs.outraConta, desde: desde)))
        #expect(!roteador.eDaContaAtiva(entregueEm: depois))

        roteador.contaAtiva(conta(.profissional))
        #expect(roteador.eDaContaAtiva(entregueEm: desde))
        #expect(roteador.eDaContaAtiva(entregueEm: depois))
        #expect(!roteador.eDaContaAtiva(entregueEm: desde.addingTimeInterval(-1)))

        // A conta sem fluxo montado também vê a notificação dela: o toque é que não tem destino.
        roteador.contaAtiva(conta(.nenhum))
        #expect(roteador.eDaContaAtiva(entregueEm: depois))

        roteador.semSessao()
        #expect(!roteador.eDaContaAtiva(entregueEm: depois))
        #expect(nadaAbriu)
    }
}

// MARK: - Telas de destino

private func vaga(estado: String, abertas: Int) throws -> Vaga {
    var objeto = try #require(JSONSerialization.jsonObject(with: FixturesDoContrato.dados("vaga")) as? [String: Any])
    objeto["estado"] = estado
    objeto["posicoes_abertas"] = abertas
    let dados = try JSONSerialization.data(withJSONObject: objeto)
    return try ContratoAPI.decodificador().decode(ContratoAPI.VagaDTO.self, from: dados).dominio()
}

private struct TurnosQueFalham: TurnoRepositorio {
    let erro: any Error
    func meusTurnos() async throws -> [Turno] { throw erro }
}

@Suite("Push: a vaga e o turno do aviso (#8)")
struct DestinosDoAvisoTests {
    @Test("Vaga publicada com posição aberta abre o detalhe; carregando e falha não são indisponibilidade")
    func disponivel() throws {
        #expect(IndisponibilidadeDaVaga(.carregado(try vaga(estado: "publicada", abertas: 1))) == nil)
        #expect(IndisponibilidadeDaVaga(.carregando) == nil)
        #expect(IndisponibilidadeDaVaga(.falha(.semConexao)) == nil)
    }

    @Test("Vaga que não dá mais para pegar abre a tela de vaga indisponível, com o motivo")
    func indisponivel() throws {
        #expect(IndisponibilidadeDaVaga(.carregado(try vaga(estado: "preenchida", abertas: 0))) == .preenchida)
        // Publicada sem posição aberta é a vaga cujo início já passou (contrato 0.2.19).
        #expect(IndisponibilidadeDaVaga(.carregado(try vaga(estado: "publicada", abertas: 0))) == .encerrada)
        #expect(IndisponibilidadeDaVaga(.carregado(try vaga(estado: "cancelada", abertas: 0))) == .encerrada)
        #expect(IndisponibilidadeDaVaga(.carregado(try vaga(estado: "encerrada", abertas: 0))) == .encerrada)
        #expect(IndisponibilidadeDaVaga(.naoEncontrada) == .naoEncontrada)
    }

    @Test("O turno do aviso é procurado entre os turnos da conta: o de outra conta não é encontrado")
    func turnoDoAviso() async throws {
        let api = ApiClienteEmMemoria()
        let vaga = try #require(try await api.vagasAbertas().first)
        let turnoID = try #require(try await api.candidatar(vagaID: vaga.id).turnoID)

        let meu = await BuscaDoTurnoDoAviso.procurar(turnoID, em: api)
        guard case let .achou(turno) = meu else {
            Issue.record("o turno da conta não foi encontrado")
            return
        }
        #expect(turno.id == turnoID)
        #expect(await BuscaDoTurnoDoAviso.procurar(UUID(), em: api) == .naoEncontrado)
    }

    @Test("Falha ao ler os turnos não vira turno não encontrado")
    func turnoSemLeitura() async {
        let semRede = TurnosQueFalham(erro: ErroDaApi(codigo: .semRede))
        #expect(await BuscaDoTurnoDoAviso.procurar(IDs.turno, em: semRede) == .semConexao)
        let outro = TurnosQueFalham(erro: ErroDaApi(codigo: .desconhecido))
        #expect(await BuscaDoTurnoDoAviso.procurar(IDs.turno, em: outro) == .falha)
    }

    @Test("Todo texto provisório do push está no catálogo pt-BR")
    func textosNoCatalogo() throws {
        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fonte = try String(contentsOf: raiz.appending(path: "Sources/Apresentacao/Fluxos/Push/TextosDoPush.swift"), encoding: .utf8)
        let literais = fonte.matches(of: /String\(localized: "([^"]+)", bundle: bundleApresentacao\)/).map { String($0.output.1) }
        #expect(literais.count >= 4, "os textos do push não foram encontrados na fonte")

        let catalogo = try JSONSerialization.jsonObject(
            with: Data(contentsOf: raiz.appending(path: "Resources/Localizable.xcstrings"))
        ) as? [String: Any]
        let chaves = try #require(catalogo?["strings"] as? [String: Any])
        let fora = literais.filter { chaves[$0] == nil }
        #expect(fora.isEmpty, "textos fora do catálogo: \(fora)")
    }
}
