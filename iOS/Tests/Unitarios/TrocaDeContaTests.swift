import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Privacidade: expurgo de cache, contatos e fila offline na troca de conta (#Prioridade 3)")
struct TrocaDeContaTests {

    private func criarArmazenamentoLocal() throws -> ArmazenamentoSwiftData {
        let container = try PersistenciaFrila.criarContainer(emMemoria: true)
        return ArmazenamentoSwiftData(modelContainer: container)
    }

    private func criarTurno(id: UUID, instante: Date, telefone: String = "+5561999990001") throws -> Turno {
        let inicio = instante.addingTimeInterval(3_600)
        let fim = inicio.addingTimeInterval(3_600)
        let resumo = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Asa Sul", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: fim), valor: Dinheiro(centavos: 12_000)
        )
        let visivelAte = fim.addingTimeInterval(7 * 24 * 3_600)
        let contato = Contato(
            nome: "Bistrô Teste",
            telefone: telefone,
            whatsappURL: URL(string: "https://wa.me/\(telefone.replacingOccurrences(of: "+", with: ""))")!,
            visivelAte: visivelAte
        )
        return Turno(
            id: id, posicaoID: UUID(), vaga: resumo,
            contraparte: PerfilPublico(
                id: UUID(), tipo: .estabelecimento, nome: "Bistrô Teste",
                reputacao: Reputacao(positivas: 1, total: 1, taxaComparecimento: 1, turnosConsiderados: 1, turnosRealizados: 1)
            ),
            contatoVisivelAte: visivelAte, verificacao: .pendente, valorAcordado: resumo.valor, podeAvaliar: false,
            contato: contato
        )
    }

    @Test("Troca de conta: entrar Conta B sem logout expurga dados de A e não envia ações de A como B")
    func trocaDeContaSemSaidaExpurgaDadosENaoEnviaAcoesDeAComoB() async throws {
        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)

        let contaA_ID = UUID()
        let contaB_ID = UUID()

        let contaA = Conta(
            id: contaA_ID, perfil: .profissional, nome: "Usuário A",
            telefone: "+5561999991111", email: "contaA@frila.app",
            nascimento: try DataCivil(ano: 1995, mes: 5, dia: 10), estado: .ativa
        )
        let contaB = Conta(
            id: contaB_ID, perfil: .profissional, nome: "Usuário B",
            telefone: "+5561999992222", email: "contaB@frila.app",
            nascimento: try DataCivil(ano: 1998, mes: 8, dia: 20), estado: .ativa
        )

        let api = ApiClienteMonitoravel(contaInicial: contaA, contasCadastradas: [
            contaA.email: contaA,
            contaB.email: contaB
        ])

        // 1. Aparelho está com Conta A: popula fila offline, turnos, contatos, telemetria e push
        let turnoA = try criarTurno(id: UUID(), instante: instante, telefone: "+5561999990001")
        try await local.salvar(sessao: SessaoUsuario(usuarioID: contaA_ID, perfil: .profissional))
        try await local.salvar(turnos: [turnoA], em: instante)
        if let contatoA = turnoA.contato {
            try await local.salvar(contato: contatoA, doTurno: turnoA.id)
        }

        // Ação pendente de A sem autor explícito (check-in / check-out gerado na tela de presença)
        let acaoCheckinA = AcaoPendente(
            tipo: .checkin, turnoID: turnoA.id, instanteDoToque: instante, chave: UUID(), distanciaMetros: 15
        )
        try await local.enfileirar(acaoCheckinA)

        // Ação pendente de A com autor explícito (avaliação de turno)
        let acaoAvaliacaoA = AcaoPendente(
            tipo: .avaliacao, turnoID: turnoA.id, contaID: contaA_ID, instanteDoToque: instante, chave: UUID(), resposta: true
        )
        try await local.enfileirar(acaoAvaliacaoA)

        // Ação recusada registrada para Conta A
        let acaoRecusadaA = AcaoPendente(tipo: .checkin, turnoID: turnoA.id, contaID: contaA_ID, instanteDoToque: instante, chave: UUID())
        try await local.enfileirar(acaoRecusadaA)
        try await local.recusar(acaoRecusadaA, codigo: .semPermissao)

        // Telemetria pendente de Conta A
        try await local.guardar(RegistroDeEvento(evento: .appAberto, ocorridoEm: instante), em: instante, limite: 50)

        // Push: Conta A vinculada no aparelho
        let relogio = RelogioAjustavel(instante)
        let guardadoPush = ArmazenamentoDoAparelhoEmMemoria()
        let compartilhado = ArmazenamentoDoVinculoCompartilhadoEmMemoria()
        let aparelho = AparelhoDePush(api: api, armazenamento: guardadoPush, vinculoCompartilhado: compartilhado, relogio: relogio)
        await aparelho.receber(token: "token-fcm-compartilhado")
        await aparelho.registrar(para: contaA_ID)

        #expect(guardadoPush.ler()?.vinculo?.contaID == contaA_ID)
        #expect(try await !local.pendentes().isEmpty)
        #expect(try await !local.recusadas().isEmpty)
        #expect(try await !local.turnosValidos(em: instante).isEmpty)
        #expect(try await local.contato(doTurno: turnoA.id, em: instante) != nil)
        #expect(try await !local.eventosPendentes().isEmpty)

        // 2. Agora entra a Conta B (fluxo real de login: verificarCodigo + DestinoDaConta + IdentidadeDaAvaliacao)
        // SEM passar por SaidaDaConta.sair() ou apagarDadosLocais()!
        try await api.verificarCodigo(email: contaB.email, codigo: "123456")
        let destino = try await DestinoDaConta.avaliar(api: api)
        #expect(destino == .profissional)

        // Obtenção da identidade no fluxo de inicialização / avaliação
        let contaIdentificada = try await IdentidadeDaAvaliacao.obter(api: api, cache: local)
        #expect(contaIdentificada == contaB_ID)

        // Sincronização offline e telemetria disparadas ao entrar / reconectar
        let sincronizador = SincronizadorAcoes(fila: local, api: api)
        await sincronizador.sincronizar()

        let telemetria = RegistradorDeTelemetria(api: api, fila: local, relogio: RelogioFixo(agora: instante))
        await telemetria.reenviar()

        let canal = CanalEspiao()
        await aparelho.ligar(para: contaB_ID, canal: canal)

        // 3. AFIRMAÇÕES DE PRIVACIDADE:
        // (a) NADA da Conta A pode ter sido enviado em nome da Conta B para a API
        let checkinsEnviados = api.checkinsRecebidos
        let avaliacoesEnviadas = api.avaliacoesRecebidas
        #expect(checkinsEnviados.isEmpty, "Check-in da Conta A NÃO pode ser enviado em nome da Conta B! Enviados: \(checkinsEnviados)")
        #expect(avaliacoesEnviadas.isEmpty, "Avaliação da Conta A NÃO pode ser enviada em nome da Conta B! Enviadas: \(avaliacoesEnviadas)")

        // (b) NADA da Conta A sobrou no aparelho (expurgo completo do cache, fila e contatos de A)
        let turnosRestantes = try await local.turnosValidos(em: instante)
        #expect(turnosRestantes.isEmpty, "Turnos da Conta A vazaram para a Conta B: \(turnosRestantes)")

        let contatoRestante = try await local.contato(doTurno: turnoA.id, em: instante)
        #expect(contatoRestante == nil, "Contato da contraparte da Conta A vazou para a Conta B: \(String(describing: contatoRestante))")

        let pendentesRestantes = try await local.pendentes()
        #expect(pendentesRestantes.isEmpty, "Ações pendentes da Conta A sobraram na fila da Conta B: \(pendentesRestantes)")

        let recusadasRestantes = try await local.recusadas()
        #expect(recusadasRestantes.isEmpty, "Ações recusadas da Conta A sobraram na fila da Conta B: \(recusadasRestantes)")

        let telemetriaRestante = try await local.eventosPendentes()
        #expect(telemetriaRestante.isEmpty, "Eventos analíticos da Conta A sobraram na fila da Conta B: \(telemetriaRestante)")

        let sessaoRestante = try await local.sessao()
        #expect(sessaoRestante?.usuarioID == contaB_ID, "A sessão local deve ser da Conta B")
        #expect(guardadoPush.ler()?.vinculo?.contaID == contaB_ID, "O vínculo de push deve ser da Conta B")
    }

    @Test("Leitura falha/corrompida de cache.sessao() aciona expurgo preventivo")
    func leituraFalhaOuCorrompidaDeSessaoAcionaExpurgoPreventivo() async throws {
        let local = try criarArmazenamentoLocal()
        let cacheDecorado = CacheComFalhaNaSessao(subjacente: local)
        let instante = Date(timeIntervalSince1970: 1_800_000_000)

        let contaA_ID = UUID()
        let contaB_ID = UUID()

        let turnoA = try criarTurno(id: UUID(), instante: instante, telefone: "+5561999990001")
        try await local.salvar(sessao: SessaoUsuario(usuarioID: contaA_ID, perfil: .profissional))
        try await local.salvar(turnos: [turnoA], em: instante)
        if let contatoA = turnoA.contato {
            try await local.salvar(contato: contatoA, doTurno: turnoA.id)
        }

        let contaB = Conta(
            id: contaB_ID, perfil: .profissional, nome: "Usuário B",
            telefone: "+5561999992222", email: "contaB@frila.app",
            nascimento: try DataCivil(ano: 1998, mes: 8, dia: 20), estado: .ativa
        )

        let api = ApiClienteMonitoravel(contaInicial: contaB, contasCadastradas: [
            contaB.email: contaB
        ])

        // Chamada de IdentidadeDaAvaliacao com cache cuja leitura da sessao() falha/corrompe
        let contaIdentificada = try await IdentidadeDaAvaliacao.obter(api: api, cache: cacheDecorado)
        #expect(contaIdentificada == contaB_ID)
        #expect(cacheDecorado.limpou, "Falha na leitura da sessão deve provocar limpeza defensiva de dados")

        // Os dados antigos de A devem ter sido purgados
        let turnosRestantes = try await local.turnosValidos(em: instante)
        #expect(turnosRestantes.isEmpty, "Turnos da conta anterior devem ter sido purgados")
        let contatoRestante = try await local.contato(doTurno: turnoA.id, em: instante)
        #expect(contatoRestante == nil, "Contato da conta anterior deve ter sido purgado")
    }

    @Test("Sessão anterior nula mas com resíduos no cache aciona expurgo preventivo")
    func sessaoNulaComDadosResiduaisAcionaExpurgoPreventivo() async throws {
        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)

        // Resíduos órfãos (ex: saída incompleta onde apenas a sessão foi apagada, restando turnos/fila)
        let turnoOrfao = try criarTurno(id: UUID(), instante: instante, telefone: "+5561999990001")
        try await local.salvar(turnos: [turnoOrfao], em: instante)
        let acaoPendente = AcaoPendente(tipo: .checkin, turnoID: turnoOrfao.id, instanteDoToque: instante, chave: UUID())
        try await local.enfileirar(acaoPendente)

        let contaB_ID = UUID()
        let contaB = Conta(
            id: contaB_ID, perfil: .profissional, nome: "Usuário B",
            telefone: "+5561999992222", email: "contaB@frila.app",
            nascimento: try DataCivil(ano: 1998, mes: 8, dia: 20), estado: .ativa
        )
        let api = ApiClienteMonitoravel(contaInicial: contaB, contasCadastradas: [
            contaB.email: contaB
        ])

        #expect(try await local.sessao() == nil, "Sessão deve ser nil previamente")
        #expect(try await !local.turnosValidos(em: instante).isEmpty, "Deve conter resíduos")
        #expect(try await !local.pendentes().isEmpty, "Deve conter fila pendente")

        let contaIdentificada = try await IdentidadeDaAvaliacao.obter(api: api, cache: local)
        #expect(contaIdentificada == contaB_ID)

        let turnosApos = try await local.turnosValidos(em: instante)
        #expect(turnosApos.isEmpty, "Turnos órfãos devem ter sido purgados")
        let pendentesApos = try await local.pendentes()
        #expect(pendentesApos.isEmpty, "Ações órfãs devem ter sido purgadas")
    }

    @Test("Mesma conta reentrando preserva fila offline e cache intactos")
    func mesmaContaReentrandoPreservaFilaECache() async throws {
        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)
        let contaA_ID = UUID()

        let contaA = Conta(
            id: contaA_ID, perfil: .profissional, nome: "Usuário A",
            telefone: "+5561999991111", email: "contaA@frila.app",
            nascimento: try DataCivil(ano: 1995, mes: 5, dia: 10), estado: .ativa
        )
        let api = ApiClienteMonitoravel(contaInicial: contaA, contasCadastradas: [contaA.email: contaA])

        let turnoA = try criarTurno(id: UUID(), instante: instante)
        try await local.salvar(sessao: SessaoUsuario(usuarioID: contaA_ID, perfil: .profissional))
        try await local.salvar(turnos: [turnoA], em: instante)
        let acaoPendente = AcaoPendente(tipo: .checkin, turnoID: turnoA.id, instanteDoToque: instante, chave: UUID())
        try await local.enfileirar(acaoPendente)

        let identificada = try await IdentidadeDaAvaliacao.obter(api: api, cache: local)
        #expect(identificada == contaA_ID)

        let turnosRestantes = try await local.turnosValidos(em: instante)
        #expect(!turnosRestantes.isEmpty, "Turnos da mesma conta devem ser preservados")
        let pendentesRestantes = try await local.pendentes()
        #expect(!pendentesRestantes.isEmpty, "Fila offline da mesma conta deve ser preservada")
    }

    @Test("Primeira instalação sem dados e sem sessão prévia não dispara purga")
    func primeiraInstalacaoSemDadosNaoAcionaPurga() async throws {
        let local = try criarArmazenamentoLocal()
        let contaA_ID = UUID()
        let contaA = Conta(
            id: contaA_ID, perfil: .profissional, nome: "Usuário A",
            telefone: "+5561999991111", email: "contaA@frila.app",
            nascimento: try DataCivil(ano: 1995, mes: 5, dia: 10), estado: .ativa
        )
        let api = ApiClienteMonitoravel(contaInicial: contaA, contasCadastradas: [contaA.email: contaA])

        #expect(await local.possuiDadosLocais() == false)
        #expect(try await local.sessao() == nil)

        let identificada = try await IdentidadeDaAvaliacao.obter(api: api, cache: local)
        #expect(identificada == contaA_ID)
        #expect(try await local.sessao()?.usuarioID == contaA_ID)
    }

    @Test("Falha na purga impede gravação da nova sessão no cache e bloqueia login")
    func falhaNaPurgaImpedeGravacaoDeSessaoDeBENaoVaza() async throws {
        let local = try criarArmazenamentoLocal()
        let cacheDecorado = CacheComFalhaNaSessao(subjacente: local)
        cacheDecorado.falharSessao = false
        cacheDecorado.falharLimpeza = true

        let contaA_ID = UUID()
        let contaB_ID = UUID()

        // Conta A previamente gravada
        try await local.salvar(sessao: SessaoUsuario(usuarioID: contaA_ID, perfil: .profissional))

        let contaB = Conta(
            id: contaB_ID, perfil: .profissional, nome: "Usuário B",
            telefone: "+5561999992222", email: "contaB@frila.app",
            nascimento: try DataCivil(ano: 1998, mes: 8, dia: 20), estado: .ativa
        )
        let api = ApiClienteMonitoravel(contaInicial: contaB, contasCadastradas: [contaB.email: contaB])

        // Tentativa de obter identidade de B com falha na purga deve lançar erro
        await #expect(throws: ErroDeLimpezaSimulado.self) {
            _ = try await IdentidadeDaAvaliacao.obter(api: api, cache: cacheDecorado)
        }

        // A sessão de B NÃO pode ter sido gravada no cache
        let sessaoFinal = try await local.sessao()
        #expect(sessaoFinal?.usuarioID != contaB_ID, "Sessão de B não pode ser gravada se a purga falhou")
    }

    @Test("Ordem vs Sincronizador: sincronizador disparado no meio da troca de conta não envia ações de A como B")
    func sincronizadorDisparadoNoMeioDaTrocaNaoEnviaAcoesDeAComoB() async throws {
        let local = try criarArmazenamentoLocal()
        let instante = Date(timeIntervalSince1970: 1_800_000_000)

        let contaA_ID = UUID()
        let contaB_ID = UUID()

        let contaA = Conta(
            id: contaA_ID, perfil: .profissional, nome: "Usuário A",
            telefone: "+5561999991111", email: "contaA@frila.app",
            nascimento: try DataCivil(ano: 1995, mes: 5, dia: 10), estado: .ativa
        )
        let contaB = Conta(
            id: contaB_ID, perfil: .profissional, nome: "Usuário B",
            telefone: "+5561999992222", email: "contaB@frila.app",
            nascimento: try DataCivil(ano: 1998, mes: 8, dia: 20), estado: .ativa
        )

        let api = ApiClienteMonitoravel(contaInicial: contaA, contasCadastradas: [
            contaA.email: contaA,
            contaB.email: contaB
        ])

        // 1. Aparelho está com Conta A no cache e na fila (ação com autor explícito e ação legada sem autor)
        try await local.salvar(sessao: SessaoUsuario(usuarioID: contaA_ID, perfil: .profissional))
        let acaoComAutorA = AcaoPendente(tipo: .checkin, turnoID: UUID(), contaID: contaA_ID, instanteDoToque: instante, chave: UUID())
        try await local.enfileirar(acaoComAutorA)
        let acaoSemAutorA = AcaoPendente(tipo: .checkin, turnoID: UUID(), contaID: nil, instanteDoToque: instante, chave: UUID())
        try await local.enfileirar(acaoSemAutorA)

        // 2. Conta B autentica na API (verificarCodigo), MAS IdentidadeDaAvaliacao AINDA NÃO RODOU
        // Portanto, a API já tem credencial de B, enquanto o banco local ainda tem a sessão de A!
        try await api.verificarCodigo(email: contaB.email, codigo: "123456")
        #expect(try await api.minhaConta().id == contaB_ID)
        #expect(try await local.sessao()?.usuarioID == contaA_ID)

        // 3. Corrida: o sincronizador é disparado neste exato momento (ex.: reconexão de rede)
        let sincronizador = SincronizadorAcoes(fila: local, api: api)
        await sincronizador.sincronizar()

        // 4. Afirmação: NENHUMA ação foi enviada para a API em nome de B!
        #expect(api.checkinsRecebidos.isEmpty, "Nenhuma ação de A pode ser enviada com o token de B no meio da troca!")

        // 5. Agora IdentidadeDaAvaliacao roda e conclui a transição
        let identificada = try await IdentidadeDaAvaliacao.obter(api: api, cache: local)
        #expect(identificada == contaB_ID)

        // 6. Banco limpo para B; nova sincronização continua sem vazar dados de A
        await sincronizador.sincronizar()
        #expect(api.checkinsRecebidos.isEmpty)
        #expect(try await local.pendentes().isEmpty)
    }
}

// MARK: - Dublê de API com monitoramento de chamadas para o teste de privacidade

private final class ApiClienteMonitoravel: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var contaAtual: Conta
    private var contasCadastradas: [String: Conta]
    private var _checkinsRecebidos: [(turnoID: UUID, contaID: UUID)] = []
    private var _avaliacoesRecebidas: [(turnoID: UUID, contaID: UUID)] = []

    init(contaInicial: Conta, contasCadastradas: [String: Conta]) {
        self.contaAtual = contaInicial
        self.contasCadastradas = contasCadastradas
        super.init()
    }

    override func verificarCodigo(email: String, codigo: String) async throws {
        trava.withLock {
            if let conta = contasCadastradas[email] {
                self.contaAtual = conta
            }
        }
        try await super.verificarCodigo(email: email, codigo: codigo)
    }

    override func minhaConta() async throws -> Conta {
        trava.withLock { contaAtual }
    }

    override func situacaoDaConta() async throws -> SituacaoDaConta {
        SituacaoDaConta(estado: .ativa, suspensao: nil)
    }

    override func meuPerfilProfissional() async throws -> PerfilProfissional {
        let conta = try await minhaConta()
        return PerfilProfissional(
            id: UUID(), usuarioID: conta.id, funcoes: [],
            pontoBase: try Coordenada(latitude: -15.793889, longitude: -47.882778),
            disponibilidades: [],
            reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        )
    }

    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        let contaID = try await minhaConta().id
        trava.withLock {
            _checkinsRecebidos.append((turnoID, contaID))
        }
        return ResultadoRegistro(turnoID: turnoID, tipo: .geolocalizado, verificacao: .verificado, registradoEm: registradoEm, distanciaMetros: distanciaMetros)
    }

    override func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        let contaID = try await minhaConta().id
        trava.withLock {
            _avaliacoesRecebidas.append((turnoID, contaID))
        }
        return Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: Date())
    }

    var checkinsRecebidos: [(turnoID: UUID, contaID: UUID)] {
        trava.withLock { _checkinsRecebidos }
    }

    var avaliacoesRecebidas: [(turnoID: UUID, contaID: UUID)] {
        trava.withLock { _avaliacoesRecebidas }
    }
}

private final class CanalEspiao: CanalDePush, @unchecked Sendable {
    private let trava = NSLock()
    private var _limpouEntregues = false
    private var _suspendeuEntrega = false

    var limpouEntregues: Bool { trava.withLock { _limpouEntregues } }
    var suspendeuEntrega: Bool { trava.withLock { _suspendeuEntrega } }

    func ativar() async {}
    func suspenderEntrega() async { trava.withLock { _suspendeuEntrega = true } }
    func limparEntregues() async { trava.withLock { _limpouEntregues = true } }
    func descartarEntregues(antesDe instante: Date) async {}
}

private final class RelogioAjustavel: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var instante: Date
    init(_ instante: Date) { self.instante = instante }
    var agora: Date { trava.withLock { instante } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { instante = instante.addingTimeInterval(segundos) } }
}

private struct ErroDeLeituraSimulado: Error {}
private struct ErroDeLimpezaSimulado: Error, Equatable {}

private final class CacheComFalhaNaSessao: CacheLocal, @unchecked Sendable {
    let subjacente: ArmazenamentoSwiftData
    var falharSessao: Bool = true
    var falharLimpeza: Bool = false
    private let trava = NSLock()
    private var _limpou: Bool = false

    var limpou: Bool {
        trava.withLock { _limpou }
    }

    init(subjacente: ArmazenamentoSwiftData) {
        self.subjacente = subjacente
    }

    func salvar(sessao: SessaoUsuario) async throws {
        try await subjacente.salvar(sessao: sessao)
    }

    func sessao() async throws -> SessaoUsuario? {
        if falharSessao {
            throw ErroDeLeituraSimulado()
        }
        return try await subjacente.sessao()
    }

    func salvar(turnos: [Turno], em instante: Date) async throws {
        try await subjacente.salvar(turnos: turnos, em: instante)
    }

    func turnosValidos(em instante: Date) async throws -> [Turno] {
        try await subjacente.turnosValidos(em: instante)
    }

    func salvar(contato: Contato, doTurno turnoID: UUID) async throws {
        try await subjacente.salvar(contato: contato, doTurno: turnoID)
    }

    func contato(doTurno turnoID: UUID, em instante: Date) async throws -> Contato? {
        try await subjacente.contato(doTurno: turnoID, em: instante)
    }

    func removerContato(doTurno turnoID: UUID) async throws {
        try await subjacente.removerContato(doTurno: turnoID)
    }

    func salvar(funcoes: [Funcao]) async throws {
        try await subjacente.salvar(funcoes: funcoes)
    }

    func funcoes() async throws -> [Funcao] {
        try await subjacente.funcoes()
    }

    func limpar() async throws {
        if falharLimpeza {
            throw ErroDeLimpezaSimulado()
        }
        trava.withLock { _limpou = true }
        try await subjacente.limpar()
    }

    func possuiDadosLocais() async -> Bool {
        await subjacente.possuiDadosLocais()
    }
}
