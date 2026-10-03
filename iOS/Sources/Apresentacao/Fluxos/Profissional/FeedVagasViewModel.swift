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
    /// Cada carga ganha um número; resposta de uma carga antiga (filtro trocado no meio) é descartada.
    private var geracao = 0
    private var carregandoMais = false

    public convenience init(api: any ApiCliente, relogio: any Relogio = RelogioDoSistema()) {
        self.init(
            buscarVagas: { try await api.vagasAbertas($0) },
            buscarFuncoes: { try await api.funcoes() },
            relogio: relogio
        )
    }

    public init(
        buscarVagas: @escaping @Sendable (FiltroVagas) async throws -> [VagaNaLista],
        buscarFuncoes: @escaping @Sendable () async throws -> [Funcao],
        relogio: any Relogio = RelogioDoSistema(),
        tamanhoDaPagina: Int = 30
    ) {
        self.buscarVagas = buscarVagas
        self.buscarFuncoes = buscarFuncoes
        self.relogio = relogio
        self.tamanhoDaPagina = tamanhoDaPagina
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

    /// Primeira carga ou recarga depois de trocar filtro.
    public func carregar() async {
        geracao += 1
        let minha = geracao
        estado = .carregando
        await buscar(geracao: minha)
        if funcoes.isEmpty, let lista = try? await buscarFuncoes() { funcoes = lista }
    }

    /// Puxar para atualizar: mantém a lista na tela enquanto busca.
    public func atualizar() async {
        geracao += 1
        let minha = geracao
        if case .carregada = estado {} else { estado = .carregando }
        await buscar(geracao: minha)
    }

    /// Próxima página, pedida quando o último cartão aparece.
    public func carregarMais() async {
        guard haMaisPaginas, !carregandoMais, case let .carregada(atuais) = estadoRecebido else { return }
        carregandoMais = true
        defer { carregandoMais = false }
        let minha = geracao
        do {
            let pagina = try await buscarVagas(filtro(deslocamento: atuais.count))
            guard minha == geracao else { return }
            var vistos = Set<UUID>()
            let unicas = (atuais + pagina).filter { vistos.insert($0.id).inserted }
            estado = .carregada(unicas)
            haMaisPaginas = pagina.count == tamanhoDaPagina
        } catch {
            // A falha da página seguinte não apaga o que já está na tela; a próxima rolagem tenta de novo.
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

    private func buscar(geracao minha: Int) async {
        do {
            let vagas = try await buscarVagas(filtro())
            guard minha == geracao else { return }
            estado = .carregada(vagas)
            haMaisPaginas = vagas.count == tamanhoDaPagina
        } catch {
            guard minha == geracao else { return }
            estado = .falha(FalhaDaLista(error))
            haMaisPaginas = false
        }
    }
}
