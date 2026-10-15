import FrilaDominio
import Foundation
import Observation

/// Por que a lista não pôde ser mostrada. Vazia não é falha: é `carregada([])`.
public enum FalhaDaLista: Equatable, Sendable {
    case semConexao
    /// Sem coordenada e sem ponto base no perfil, o servidor responde `422 campo_obrigatorio/latitude`.
    case semPontoDeReferencia
    case perfilIncompativel
    case erro(ErroDaApi)

    init(_ erro: Error) {
        guard let erro = erro as? ErroDaApi else { self = .erro(ErroDaApi(codigo: .desconhecido)); return }
        switch (erro.codigo, erro.detalhes) {
        case (.semRede, _): self = .semConexao
        case (.campoObrigatorio, "latitude"): self = .semPontoDeReferencia
        case (.perfilIncompativel, _): self = .perfilIncompativel
        default: self = .erro(erro)
        }
    }
}

public enum EstadoDaLista: Equatable, Sendable {
    case ociosa
    case carregando
    case carregada([VagaNaLista])
    case falha(FalhaDaLista)
}

public enum FiltroDeData: Hashable, Sendable, CaseIterable {
    case qualquer, hoje, amanha
}

public enum FiltroDeDistancia: Hashable, Sendable {
    case qualquer
    case ate(km: Int)

    public static let opcoes: [FiltroDeDistancia] = [.qualquer, .ate(km: 5), .ate(km: 10), .ate(km: 15)]
}

/// Lista de vagas abertas do DF (#104): mais próximas primeiro, com os filtros de função, data e
/// distância. A ordem é do servidor; o app não reordena.
@MainActor @Observable
public final class FeedVagasViewModel {
    public let bloqueios = BloqueiosDaSessao()
    private var estadoRecebido: EstadoDaLista = .ociosa
    public private(set) var estado: EstadoDaLista {
        get {
            if case let .carregada(vagas) = estadoRecebido { return .carregada(bloqueios.filtrar(vagas)) }
            return estadoRecebido
        }
        set { estadoRecebido = newValue }
    }
    public private(set) var funcoes: [Funcao] = []
    public private(set) var funcaoID: UUID?
    public private(set) var data: FiltroDeData = .qualquer
    public private(set) var distancia: FiltroDeDistancia = .qualquer
    public private(set) var haMaisPaginas = false

    private let buscarVagas: @Sendable (FiltroVagas) async throws -> [VagaNaLista]
    private let buscarFuncoes: @Sendable () async throws -> [Funcao]
    private let relogio: any Relogio
    private let tamanhoDaPagina: Int
    private let telemetria: RegistradorDeTelemetria?
    private var vagasVistasNaSessao: Set<UUID> = []
    /// Cada carga ganha um número; resposta de uma carga antiga (filtro trocado no meio) é descartada.
    private var geracao = 0
    private var carregandoMais = false
    private var tarefaDaCarga: Task<Void, Never>?
    private var tarefaDaPagina: Task<[VagaNaLista], Error>?
    private var aguardandoPrimeiraPagina = false
    /// Última primeira página por filtro: aparece na hora e é trocada quando a rede responde.
    private let cache: CacheDeLeituras?

    public convenience init(
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        telemetria: RegistradorDeTelemetria? = nil
    ) {
        self.init(
            buscarVagas: { try await api.vagasAbertas($0) },
            buscarFuncoes: { try await api.funcoes() },
            relogio: relogio,
            telemetria: telemetria ?? RegistradorDeTelemetria(api: api),
            cache: .compartilhado
        )
    }

    public init(
        buscarVagas: @escaping @Sendable (FiltroVagas) async throws -> [VagaNaLista],
        buscarFuncoes: @escaping @Sendable () async throws -> [Funcao],
        relogio: any Relogio = RelogioDoSistema(),
        tamanhoDaPagina: Int = 30,
        telemetria: RegistradorDeTelemetria? = nil,
        cache: CacheDeLeituras? = nil
    ) {
        self.cache = cache
        self.buscarVagas = buscarVagas
        self.buscarFuncoes = buscarFuncoes
        self.relogio = relogio
        self.tamanhoDaPagina = tamanhoDaPagina
        self.telemetria = telemetria
    }

    /// Registra a visualização de um cartão de vaga no feed (apenas uma vez por sessão por vaga).
    public func registrarVagaVista(id: UUID) async {
        guard !vagasVistasNaSessao.contains(id) else { return }
        vagasVistasNaSessao.insert(id)
        await telemetria?.registrar(.vagaVista, vagaID: id)
    }

    /// O filtro que vai para `vagas_abertas`. Sem referência: o servidor usa o ponto base do perfil.
    public func filtro(deslocamento: Int = 0) -> FiltroVagas {
        let dia: DataCivil? = switch data {
        case .qualquer: nil
        case .hoje: DataCivil.deSaoPaulo(relogio.agora)
        case .amanha: DataCivil.deSaoPaulo(relogio.agora, somandoDias: 1)
        }
        let km: Double? = switch distancia {
        case .qualquer: nil
        case let .ate(km): Double(km)
        }
        return FiltroVagas(funcaoID: funcaoID, data: dia, distanciaMaximaKm: km, limite: tamanhoDaPagina, deslocamento: deslocamento)
    }

    /// Primeira carga ou recarga depois de trocar filtro. Um pedido novo cancela o que estava em voo
    /// (a resposta velha nunca sobrescreve a nova) e a busca de funções corre junto com a de vagas.
    public func carregar() async {
        let minha = iniciarCarga()
        let guardada = cache?.lista(chave: chaveDoFiltro())
        if let guardada {
            estado = .carregada(guardada)
            haMaisPaginas = guardada.count == tamanhoDaPagina
        } else {
            estado = .carregando
        }
        await executar { [self] in
            let precisaDeFuncoes = funcoes.isEmpty
            async let lista = buscarFuncoesSeFaltam(precisaDeFuncoes)
            await buscar(geracao: minha, mantendoGuardada: guardada != nil)
            if let lista = await lista, !Task.isCancelled { funcoes = lista }
        }
        soltarSeInterrompida(geracao: minha)
    }

    /// Puxar para atualizar: mantém a lista na tela enquanto busca.
    public func atualizar() async {
        let minha = iniciarCarga()
        if case .carregada = estado {} else { estado = .carregando }
        await executar { [self] in await buscar(geracao: minha) }
        soltarSeInterrompida(geracao: minha)
    }

    /// Próxima página, pedida quando o último cartão aparece.
    public func carregarMais() async {
        guard haMaisPaginas, !carregandoMais, !aguardandoPrimeiraPagina,
              case let .carregada(atuais) = estadoRecebido else { return }
        carregandoMais = true
        let minha = geracao
        defer { if minha == geracao { carregandoMais = false } }
        let tarefa = Task { [buscarVagas, filtro = filtro(deslocamento: atuais.count)] in try await buscarVagas(filtro) }
        tarefaDaPagina = tarefa
        do {
            let pagina = try await withTaskCancellationHandler { try await tarefa.value } onCancel: { tarefa.cancel() }
            guard minha == geracao, !Task.isCancelled else { return }
            var vistos = Set<UUID>()
            let unicas = (atuais + pagina).filter { vistos.insert($0.id).inserted }
            estado = .carregada(unicas)
            haMaisPaginas = pagina.count == tamanhoDaPagina
        } catch {
            // A falha da página seguinte não apaga o que já está na tela; a próxima rolagem tenta de novo.
        }
    }

    private func buscarFuncoesSeFaltam(_ faltam: Bool) async -> [Funcao]? {
        guard faltam else { return nil }
        return try? await buscarFuncoes()
    }

    /// Cancela o que estiver em voo e abre uma nova geração.
    private func iniciarCarga() -> Int {
        tarefaDaCarga?.cancel()
        tarefaDaPagina?.cancel()
        carregandoMais = false
        geracao += 1
        aguardandoPrimeiraPagina = true
        return geracao
    }

    /// Roda o trabalho numa tarefa guardada, para o próximo pedido poder cancelá-la; se quem chamou
    /// for cancelado (tela saiu), a tarefa também é.
    private func executar(_ trabalho: @escaping @MainActor () async -> Void) async {
        let tarefa = Task { @MainActor in await trabalho() }
        tarefaDaCarga = tarefa
        await withTaskCancellationHandler { await tarefa.value } onCancel: { tarefa.cancel() }
    }

    /// Carga cancelada sem que outra tenha assumido: libera a paginação e a tela em "carregando".
    private func soltarSeInterrompida(geracao minha: Int) {
        guard minha == geracao else { return }
        if Task.isCancelled || tarefaDaCarga?.isCancelled == true { aguardandoPrimeiraPagina = false }
        if estadoRecebido == .carregando {
            aguardandoPrimeiraPagina = false
            estadoRecebido = .ociosa
        }
    }

    public func selecionar(funcao: UUID?) async {
        guard funcao != funcaoID else { return }
        funcaoID = funcao
        await carregar()
    }

    public func selecionar(data: FiltroDeData) async {
        guard data != self.data else { return }
        self.data = data
        await carregar()
    }

    public func selecionar(distancia: FiltroDeDistancia) async {
        guard distancia != self.distancia else { return }
        self.distancia = distancia
        await carregar()
    }

    private func chaveDoFiltro() -> String {
        let f = filtro()
        let dia = f.data.map { "\($0.ano)-\($0.mes)-\($0.dia)" } ?? "-"
        return "\(f.funcaoID?.uuidString ?? "-")|\(dia)|\(f.distanciaMaximaKm.map { String($0) } ?? "-")"
    }

    private func buscar(geracao minha: Int, mantendoGuardada: Bool = false) async {
        guard minha == geracao, !Task.isCancelled else { return }
        defer {
            // A conclusão de uma tarefa antiga não pode liberar a paginação da carga nova.
            if minha == geracao, Task.isCancelled { aguardandoPrimeiraPagina = false }
        }
        let epoca = cache?.epoca
        do {
            let chave = chaveDoFiltro()
            let vagas = try await buscarVagas(filtro())
            guard minha == geracao, !Task.isCancelled else { return }
            aguardandoPrimeiraPagina = false
            estado = .carregada(vagas)
            haMaisPaginas = vagas.count == tamanhoDaPagina
            if let epoca { cache?.guardar(lista: vagas, chave: chave, epoca: epoca) }
        } catch {
            guard minha == geracao, !Task.isCancelled else { return }
            if error is CancellationError {
                aguardandoPrimeiraPagina = false
                return
            }
            // Sem rede, a lista guardada continua na tela em vez de virar erro.
            // A paginação segue bloqueada até uma primeira página atualizada chegar.
            if mantendoGuardada, case .semRede = (error as? ErroDaApi)?.codigo { return }
            aguardandoPrimeiraPagina = false
            estado = .falha(FalhaDaLista(error))
            haMaisPaginas = false
        }
    }
}
