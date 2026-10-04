// BAIXA FIDELIDADE DESCARTÁVEL: não é design final (substitui por ora #15/#172).

import FrilaDominio
import Observation
import SwiftUI

/// Abas de navegação principal do profissional (conforme protótipo low-fi).
public enum AbaDoProfissional: Hashable, Sendable {
    case vagas
    case turnos
    /// As candidaturas da conta, com as que esperam a escolha da casa nas vagas de seleção (#10).
    case candidaturas
}

/// Destinos do fluxo de quem procura turno.
public enum RotaDoProfissional: Hashable, Sendable {
    case meuPerfil
    case detalhe(vagaID: UUID)
    case resultado(vaga: Vaga, resultado: ResultadoDaCandidatura)
    case meuTurno(turno: Turno)
    case avaliacao(turnoID: UUID)
    /// A vaga de um aviso (#8): o detalhe, ou a tela de vaga indisponível.
    case vagaDoAviso(vagaID: UUID)
    /// O turno de um aviso (#8), que só traz o id: a tela o procura entre os turnos da conta.
    case turnoDoAviso(turnoID: UUID)
}

/// Destinos da pilha de navegação da aba Candidaturas.
public enum DestinoDaAbaCandidaturas: Hashable, Sendable {
    case vaga(Candidatura)
    case turno(Turno)
}

/// Pilha de navegação do fluxo. É a entrada que a notificação do tipo vaga (S2 #8) vai usar:
/// `abrirVaga` empilha o detalhe, nunca candidata sozinho.
@MainActor @Observable
public final class RoteadorDoProfissional {
    public var caminho: [RotaDoProfissional] = []
    public var aba: AbaDoProfissional = .vagas
    /// Conta os avisos abertos (#8): as listas são relidas a cada um, porque o aviso diz que algo mudou.
    public internal(set) var avisosAbertos = 0
    /// Sobrevive à saída do detalhe enquanto `candidatar` ainda está em voo. O roteador, e não a
    /// view que iniciou a chamada, decide o destino do resultado definitivo.
    var candidaturaEmAndamento: CandidaturaViewModel?

    public init() {}

    public func abrirVaga(id: UUID) {
        aba = .vagas
        caminho = [.detalhe(vagaID: id)]
    }

    public func abrirMeusTurnos() {
        aba = .turnos
    }

    public func abrirAvaliacao(turnoID: UUID) {
        // A rota de avaliação pertence ao NavigationStack que usa `caminho`.
        aba = .vagas
        caminho.append(.avaliacao(turnoID: turnoID))
    }

    public func abrirCandidaturas() {
        caminho = []
        aba = .candidaturas
    }

    public func voltarParaLista() {
        caminho = []
    }

    public func candidatar(viewModel: CandidaturaViewModel) async {
        if let candidaturaEmAndamento, candidaturaEmAndamento !== viewModel, candidaturaEmAndamento.enviando {
            viewModel.indicarOutroEnvioEmAndamento()
            return
        }
        guard !viewModel.enviando else { return }
        candidaturaEmAndamento = viewModel
        defer {
            if candidaturaEmAndamento === viewModel {
                candidaturaEmAndamento = nil
            }
        }
        await viewModel.candidatar()
        guard candidaturaEmAndamento === viewModel,
              case let .concluida(resultado) = viewModel.estado,
              resultado.abreTelaPropria else { return }
        caminho = [.resultado(vaga: viewModel.vaga, resultado: resultado)]
    }
}

/// Lista de vagas -> detalhe (#104) -> candidatura e resultado (#105), e aba Meus turnos (#109).
public struct FluxoDoProfissional<Barra: View>: View {
    @State private var contaID: UUID?
    @State private var recuperandoIdentidade = false
    private let api: any ApiCliente
    private let repositorioTurnos: any TurnoRepositorio
    private let relogio: any Relogio
    private let localizacao: (any LeitorDeLocalizacao)?
    private let fila: (any FilaDeAcoes)?
    @Bindable private var roteador: RoteadorDoProfissional
    @State private var feed: FeedVagasViewModel
    @State private var turnosViewModel: MeusTurnosViewModel
    @State private var candidaturasViewModel: MinhasCandidaturasViewModel
    @State private var caminhoTurnos: [Turno] = []
    /// A pilha da aba Candidaturas: a vaga ou turno aberto por ela fica nela, e o voltar cai na lista.
    @State private var caminhoCandidaturas: [DestinoDaAbaCandidaturas] = []
    private let barra: () -> Barra
    private let sair: () -> Void

    public init(
        api: any ApiCliente,
        contaID: UUID? = nil,
        roteador: RoteadorDoProfissional,
        repositorioTurnos: (any TurnoRepositorio)? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        localizacao: (any LeitorDeLocalizacao)? = nil,
        fila: (any FilaDeAcoes)? = nil,
        sair: @escaping () -> Void = {},
        @ViewBuilder barra: @escaping () -> Barra
    ) {
        self.api = api
        _contaID = State(initialValue: contaID)
        let repo = repositorioTurnos ?? api
        self.repositorioTurnos = repo
        self.relogio = relogio
        self.localizacao = localizacao
        self.fila = fila
        self.roteador = roteador
        _feed = State(initialValue: FeedVagasViewModel(api: api, relogio: relogio))
        _turnosViewModel = State(initialValue: MeusTurnosViewModel(repositorio: repo))
        _candidaturasViewModel = State(initialValue: MinhasCandidaturasViewModel(api: api, repositorioTurnos: repo))
        self.barra = barra
        self.sair = sair
    }

    public var body: some View {
        TabView(selection: $roteador.aba) {
            NavigationStack(path: $roteador.caminho) {
                TelaVagas(viewModel: feed) { roteador.caminho.append(.detalhe(vagaID: $0)) }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                roteador.aba = .turnos
                            } label: {
                                Label(TextosDoProfissional.Turnos.tituloMeusTurnos, systemImage: "calendar")
                            }
                            .accessibilityIdentifier("abrir-meus-turnos")
                        }
                        ToolbarItem(placement: .topBarTrailing) { barra() }
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(value: RotaDoProfissional.meuPerfil) {
                                Image(systemName: "person.crop.circle")
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                            }
                            .accessibilityLabel(String(localized: "Meu perfil", bundle: bundleApresentacao))
                            .accessibilityIdentifier("abrir-meu-perfil")
                        }
                    }
                    .navigationDestination(for: RotaDoProfissional.self) { rota in
                        switch rota {
                        case .meuPerfil:
                            TelaMeuPerfilProfissional(api: api, sair: sair)
                        case let .detalhe(vagaID):
                            DestinoDoDetalhe(vagaID: vagaID, api: api, candidatar: roteador.candidatar)
                        case let .resultado(vaga, resultado):
                            TelaResultadoDaCandidatura(
                                vaga: vaga, resultado: resultado, api: api, verCandidaturas: { roteador.abrirCandidaturas() },
                                sair: sair, voltarParaLista: voltarParaLista
                            )
                        case let .meuTurno(turno):
                            destinoDoMeuTurno(turno)
                        case let .vagaDoAviso(vagaID):
                            DestinoDaVagaDoAviso(
                                vagaID: vagaID, api: api, repositorio: repositorioTurnos,
                                candidatar: roteador.candidatar, voltarParaLista: voltarParaLista
                            ) { destinoDoMeuTurno($0) }
                        case let .turnoDoAviso(turnoID):
                            DestinoDoTurnoDoAviso(turnoID: turnoID, repositorio: repositorioTurnos, verMeusTurnos: { roteador.abrir(.meusTurnos) }) {
                                destinoDoMeuTurno($0)
                            }
                        case let .avaliacao(turnoID):
                            if let contaID {
                                DestinoDaAvaliacaoDoAviso(turnoID: turnoID, contaID: contaID, api: api,
                                                          fila: fila, relogio: relogio, repositorio: repositorioTurnos) {
                                    Task { await turnosViewModel.atualizar() }
                                }
                            } else {
                                EstadoErro(verbatim: TextosDoProfissional.Avaliacao.erroSemRede) {
                                    Task { await recuperarIdentidade() }
                                }
                                .disabled(recuperandoIdentidade)
                                .padding(FrilaEspaco.medio)
                                .navigationTitle(TextosDoProfissional.Avaliacao.titulo)
                                .accessibilityIdentifier("avaliacao-sem-conexao")
                            }
                        }
                    }
            }
            .tabItem {
                Label(TextosDoProfissional.Lista.titulo, systemImage: "briefcase")
            }
            .tag(AbaDoProfissional.vagas)

            NavigationStack(path: $caminhoTurnos) {
                TelaMeusTurnos(viewModel: turnosViewModel) { turno in
                    caminhoTurnos.append(turno)
                }
                .navigationDestination(for: Turno.self) { turno in
                    destinoDoMeuTurno(turno)
                }
            }
            .tabItem {
                Label(TextosDoProfissional.Turnos.tituloMeusTurnos, systemImage: "calendar")
            }
            .tag(AbaDoProfissional.turnos)

            NavigationStack(path: $caminhoCandidaturas) {
                TelaMinhasCandidaturas(viewModel: candidaturasViewModel, abrir: abrirCandidatura)
                    .navigationDestination(for: DestinoDaAbaCandidaturas.self) { destino in
                        switch destino {
                        case let .vaga(candidatura):
                            // A mesma tela do aviso (detalhe com a candidatura enviada, ou a explicação
                            // de por que a vaga não está mais disponível), mas nesta pilha: quem veio
                            // da aba Candidaturas volta para ela.
                            DestinoDaVagaDoAviso(
                                vagaID: candidatura.vaga.id, api: api, repositorio: repositorioTurnos,
                                candidatar: candidatarPelaAbaCandidaturas, voltarParaLista: { caminhoCandidaturas = [] },
                                rotuloDoVoltar: TextosDaCandidaturaEmSelecao.verCandidaturas
                            ) { destinoDoMeuTurno($0) }
                        case let .turno(turno):
                            destinoDoMeuTurno(turno)
                        }
                    }
            }
            .tabItem {
                Label(TextosDaCandidaturaEmSelecao.titulo, systemImage: "paperplane")
            }
            .tag(AbaDoProfissional.candidaturas)
        }
        .environment(feed.bloqueios)
        .onChange(of: feed.bloqueios.alvos) {
            // O servidor também retirou vagas: reinicia os offsets para não pular itens.
            Task { await feed.atualizar() }
        }
        .onChange(of: roteador.avisosAbertos) { atualizarListas() }
        .onChange(of: caminhoCandidaturas) { _, caminho in
            // De volta à lista: a candidatura retirada no detalhe aparece como retirada.
            guard caminho.isEmpty else { return }
            let candidaturas = candidaturasViewModel
            Task { await candidaturas.atualizar() }
        }
        .onChange(of: roteador.aba) { _, aba in
            // A candidatura enviada ou retirada em Vagas aparece na aba assim que a pessoa chega nela.
            guard aba == .candidaturas else { return }
            let candidaturas = candidaturasViewModel
            Task { await candidaturas.atualizar() }
        }
    }
}

extension FluxoDoProfissional {
    private func recuperarIdentidade() async {
        guard !recuperandoIdentidade else { return }
        recuperandoIdentidade = true
        defer { recuperandoIdentidade = false }
        contaID = try? await IdentidadeDaAvaliacao.obter(api: api, cache: fila as? any CacheLocal)
    }

    /// Presença, avaliação ou cancelamento aceito atualiza Meus turnos, que é de onde a tela reabre.
    private func destinoDoMeuTurno(_ turno: Turno) -> some View {
        let turnos = turnosViewModel
        return DestinoDoMeuTurno(turno: turno, api: api, contaID: contaID, relogio: relogio, localizacao: localizacao, fila: fila) {
            Task { await turnos.atualizar() }
        }
    }

    /// "Vaga preenchida" e os outros resultados voltam para a lista (#105 C4), que é atualizada.
    private func voltarParaLista() {
        roteador.voltarParaLista()
        atualizarListas()
    }

    private func atualizarListas() {
        let feed = feed
        let turnos = turnosViewModel
        let candidaturas = candidaturasViewModel
        Task {
            await feed.atualizar()
            await turnos.atualizar()
            await candidaturas.atualizar()
        }
    }

    /// A candidatura confirmada com turno abre o turno pelo turnoID. Sem turno_id (servidor
    /// antigo), vai a Meus turnos. As outras abrem a vaga dentro da própria aba: o detalhe
    /// com a candidatura enviada, ou a tela que diz por que a vaga não está mais disponível.
    private func abrirCandidatura(_ candidatura: Candidatura) {
        switch candidaturasViewModel.destinoAoTocar(em: candidatura) {
        case let .turno(turno):
            caminhoCandidaturas = [.turno(turno)]
        case .meusTurnos:
            roteador.abrirMeusTurnos()
        case .vaga:
            caminhoCandidaturas = [.vaga(candidatura)]
        }
    }

    /// Candidatar-se de novo pela aba Candidaturas (a retirada cuja vaga ainda está aberta). O
    /// resultado com tela própria abre na pilha de Vagas: a aba acompanha, e esta pilha volta ao
    /// início, para "Ver minhas candidaturas" cair na lista.
    private func candidatarPelaAbaCandidaturas(_ viewModel: CandidaturaViewModel) async {
        await roteador.candidatar(viewModel: viewModel)
        guard case let .concluida(resultado) = viewModel.estado, resultado.abreTelaPropria else { return }
        caminhoCandidaturas = []
        roteador.aba = .vagas
    }
}

extension FluxoDoProfissional where Barra == EmptyView {
    public init(
        api: any ApiCliente,
        contaID: UUID? = nil,
        roteador: RoteadorDoProfissional,
        repositorioTurnos: (any TurnoRepositorio)? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        localizacao: (any LeitorDeLocalizacao)? = nil,
        fila: (any FilaDeAcoes)? = nil,
        sair: @escaping () -> Void = {}
    ) {
        self.init(api: api, contaID: contaID, roteador: roteador, repositorioTurnos: repositorioTurnos, relogio: relogio, localizacao: localizacao, fila: fila, sair: sair) { EmptyView() }
    }
}

/// Guarda o view model do detalhe enquanto o destino estiver na pilha.
private struct DestinoDoDetalhe: View {
    @State private var viewModel: DetalheVagaViewModel
    private let api: any ApiCliente
    private let candidatar: (CandidaturaViewModel) async -> Void

    init(vagaID: UUID, api: any ApiCliente, candidatar: @escaping (CandidaturaViewModel) async -> Void) {
        _viewModel = State(initialValue: DetalheVagaViewModel(vagaID: vagaID, api: api))
        self.api = api
        self.candidatar = candidatar
    }

    var body: some View {
        TelaDetalheVaga(viewModel: viewModel) { vaga in
            AreaDeCandidatura(vaga: vaga, api: api, candidatar: candidatar)
        }
    }
}

/// Destino do detalhe do turno (#109).
private struct DestinoDoMeuTurno: View {
    @State private var viewModel: MeuTurnoViewModel

    init(
        turno: Turno,
        api: any ApiCliente,
        contaID: UUID?,
        relogio: any Relogio,
        localizacao: (any LeitorDeLocalizacao)?,
        fila: (any FilaDeAcoes)?,
        aoRegistrar: @escaping @MainActor () -> Void
    ) {
        // Sem leitor de localização (prévias), a tela fica sem a seção de presença.
        let presenca = localizacao.map {
            PresencaDoTurnoViewModel(turno: turno, api: api, localizacao: $0, fila: fila, relogio: relogio, aoRegistrar: aoRegistrar)
        }
        _viewModel = State(initialValue: MeuTurnoViewModel(
            turno: turno, api: api, contaID: contaID, fila: fila, relogio: relogio, presenca: presenca,
            aoAvaliar: aoRegistrar, aoCancelar: aoRegistrar
        ))
    }

    var body: some View {
        TelaMeuTurno(viewModel: viewModel)
    }
}

/// Mantém o formulário enquanto a leitura assíncrona do turno atualiza a tela do aviso.
private struct DestinoDaAvaliacaoDoAviso: View {
    @State private var viewModel: AvaliacaoTurnoViewModel

    init(turnoID: UUID, contaID: UUID, api: any ApiCliente, fila: (any FilaDeAcoes)?,
         relogio: any Relogio, repositorio: any TurnoRepositorio, aoAvaliar: @escaping () -> Void) {
        _viewModel = State(initialValue: AvaliacaoTurnoViewModel(
            turnoID: turnoID, contaID: contaID, api: api, fila: fila, relogio: relogio,
            aoAvaliar: { _ in aoAvaliar() }, repositorioTurnos: repositorio
        ))
    }

    var body: some View { TelaAvaliacao(viewModel: viewModel) }
}
