import FrilaDominio
import Observation
import SwiftUI

private final class MarcadorMinhasVagas: NSObject {}
private let bundleMinhasVagas = Bundle(for: MarcadorMinhasVagas.self)

enum TextosMinhasVagas {
    static let titulo = String(localized: "Minhas vagas", bundle: bundleMinhasVagas)
    static let emAlerta = String(localized: "Precisa de atenção", bundle: bundleMinhasVagas)
    static let hoje = String(localized: "Hoje", bundle: bundleMinhasVagas)
    static let proximas = String(localized: "Próximas", bundle: bundleMinhasVagas)
    static let encerradas = String(localized: "Encerradas", bundle: bundleMinhasVagas)
    static let vaziaTitulo = String(localized: "Nenhuma vaga aberta", bundle: bundleMinhasVagas)
    static let vaziaMensagem = String(localized: "Publique uma vaga e avisamos os profissionais da função perto do local.", bundle: bundleMinhasVagas)
    static let semEstabelecimento = String(localized: "Não encontramos o estabelecimento cadastrado.", bundle: bundleMinhasVagas)
    static let falha = String(localized: "Não foi possível carregar suas vagas. Tente novamente.", bundle: bundleMinhasVagas)
    static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleMinhasVagas)
    static let atualizar = String(localized: "Atualizar vagas", bundle: bundleMinhasVagas)
    static let vagas = String(localized: "%d posições", bundle: bundleMinhasVagas)
    static let confirmadas = String(localized: "%d de %d confirmadas", bundle: bundleMinhasVagas)
    static let confirmadaSingular = String(localized: "%d de 1 confirmada", bundle: bundleMinhasVagas)
    static let aberta = String(localized: "Posição aberta", bundle: bundleMinhasVagas)
    static let alertaComeca = String(localized: "Começa em %@", bundle: bundleMinhasVagas)
    static let horaMinuto = String(localized: "%d h %d min", bundle: bundleMinhasVagas)
    static let apenasMinutos = String(localized: "%d min", bundle: bundleMinhasVagas)
    static let menosDeUmMinuto = String(localized: "Menos de um minuto para começar", bundle: bundleMinhasVagas)
    static let verDetalhes = String(localized: "Ver posições e confirmações", bundle: bundleMinhasVagas)
    static let detalheTitulo = String(localized: "Detalhe da vaga", bundle: bundleMinhasVagas)
    static let posicoes = String(localized: "Posições", bundle: bundleMinhasVagas)
    static let profissionaisConfirmados = String(localized: "Profissionais confirmados", bundle: bundleMinhasVagas)
    static let posicaoAberta = String(localized: "Posição aberta", bundle: bundleMinhasVagas)
    static let perfil = String(localized: "Ver perfil público", bundle: bundleMinhasVagas)
    static let perfilTitulo = String(localized: "Perfil público", bundle: bundleMinhasVagas)
    static let periodo = String(localized: "%@ – %@", bundle: bundleMinhasVagas)
    static let periodoMesmoDia = String(localized: "%@, %@ – %@", bundle: bundleMinhasVagas)
    static let publicarVaga = String(localized: "Publicar vaga", bundle: bundleMinhasVagas)
    static let republicar = String(localized: "Publicar de novo", bundle: bundleMinhasVagas)
    static let detalhesPublicados = String(localized: "DETALHES PUBLICADOS", bundle: bundleMinhasVagas)
    static let detalhesPublicadosTitulo = String(localized: "Detalhes publicados", bundle: bundleMinhasVagas)
    static let valorPorPessoa = String(localized: "Valor por pessoa", bundle: bundleMinhasVagas)
    static let local = String(localized: "Local", bundle: bundleMinhasVagas)
    static let abertaNinguemAceitou = String(localized: "Aberta, ninguém aceitou ainda", bundle: bundleMinhasVagas)
    static let continuaNaLista = String(localized: "A vaga continua na lista até o início do turno.", bundle: bundleMinhasVagas)
    static let posicoesConfirmadasSingular = String(localized: "1 de %d posições confirmada", bundle: bundleMinhasVagas)
    static let posicoesConfirmadasPlural = String(localized: "%d de %d posições confirmadas", bundle: bundleMinhasVagas)
    static let abertasContinuamNaLista = String(localized: "As posições abertas continuam na lista até o início do turno.", bundle: bundleMinhasVagas)
    static let vagaPreenchida = String(localized: "Vaga preenchida", bundle: bundleMinhasVagas)
    static let todasPosicoesConfirmadas = String(localized: "Todas as posições foram confirmadas.", bundle: bundleMinhasVagas)
    static let encerradaNinguemAceitou = String(localized: "Encerrada, ninguém aceitou", bundle: bundleMinhasVagas)
    static let vagaEncerrada = String(localized: "Vaga encerrada", bundle: bundleMinhasVagas)
    static let posicaoPreenchidaDeUma = String(localized: "1 de 1 posição preenchida", bundle: bundleMinhasVagas)
    static let posicoesPreenchidas = String(localized: "%d de %d posições preenchidas", bundle: bundleMinhasVagas)
    static let vagaCancelada = String(localized: "Vaga cancelada", bundle: bundleMinhasVagas)
    static let vagaCanceladaCorpo = String(localized: "Ela saiu da lista e não é mais enviada aos profissionais.", bundle: bundleMinhasVagas)
}

private enum TextosListaMinhasVagas {
    static let carregando = String(localized: "Carregando as vagas.", bundle: bundleMinhasVagas)
    static let erroTitulo = String(localized: "Não foi possível carregar as vagas.", bundle: bundleMinhasVagas)
    static let erroCorpo = String(localized: "Tente de novo.", bundle: bundleMinhasVagas)
    static let tentarDeNovo = String(localized: "Tentar de novo", bundle: bundleMinhasVagas)
    static let tentandoDeNovo = String(localized: "Tentando de novo...", bundle: bundleMinhasVagas)
    static let atualizando = String(localized: "Atualizando as vagas.", bundle: bundleMinhasVagas)
}

private func textoPeriodo(_ periodo: Periodo) -> String {
    var calendario = Calendar(identifier: .gregorian)
    calendario.locale = FormatadorFrila.locale
    calendario.timeZone = FormatadorFrila.fuso

    if calendario.isDate(periodo.inicio, inSameDayAs: periodo.fim) {
        let formatadorData = DateFormatter()
        formatadorData.locale = FormatadorFrila.locale
        formatadorData.timeZone = FormatadorFrila.fuso
        formatadorData.dateFormat = "d 'de' MMM"

        let formatadorHora = DateFormatter()
        formatadorHora.locale = FormatadorFrila.locale
        formatadorHora.timeZone = FormatadorFrila.fuso
        formatadorHora.dateFormat = "HH:mm"

        let data = formatadorData.string(from: periodo.inicio)
        let inicio = formatadorHora.string(from: periodo.inicio)
        let fim = formatadorHora.string(from: periodo.fim)
        return String(format: TextosMinhasVagas.periodoMesmoDia, data, inicio, fim)
    } else {
        let formatador = DateFormatter()
        formatador.locale = FormatadorFrila.locale
        formatador.timeZone = FormatadorFrila.fuso
        formatador.dateStyle = .medium
        formatador.timeStyle = .short
        return String(format: TextosMinhasVagas.periodo, formatador.string(from: periodo.inicio), formatador.string(from: periodo.fim))
    }
}

public enum SecaoMinhasVagas: String, CaseIterable, Identifiable, Sendable {
    case emAlerta
    case hoje
    case proximas
    case encerradas

    public var id: String { rawValue }

    fileprivate var titulo: String {
        switch self {
        case .emAlerta: TextosMinhasVagas.emAlerta
        case .hoje: TextosMinhasVagas.hoje
        case .proximas: TextosMinhasVagas.proximas
        case .encerradas: TextosMinhasVagas.encerradas
        }
    }
}

@MainActor @Observable
public final class MinhasVagasViewModel {
    public static var calendarioSaoPaulo: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendario
    }

    public let estabelecimentoID: UUID
    public let nomeEstabelecimento: String
    public let vagaRecemPublicadaID: UUID?
    public private(set) var vagas: [VagaNoPainel] = []
    public private(set) var carregando = false
    public private(set) var erro: String?

    private let buscarPainel: @Sendable () async throws -> Painel
    private let agora: @Sendable () -> Date
    private let calendario: Calendar

    public init(
        api: any ApiCliente,
        estabelecimento: Estabelecimento,
        vagaRecemPublicadaID: UUID? = nil,
        agora: @escaping @Sendable () -> Date = Date.init,
        calendario: Calendar = MinhasVagasViewModel.calendarioSaoPaulo
    ) {
        self.estabelecimentoID = estabelecimento.id
        self.nomeEstabelecimento = estabelecimento.nome
        self.vagaRecemPublicadaID = vagaRecemPublicadaID
        self.agora = agora
        self.calendario = calendario
        buscarPainel = {
            let instante = agora()
            guard let de = calendario.date(byAdding: .day, value: -365, to: instante),
                  let ate = calendario.date(byAdding: .day, value: 365, to: instante) else {
                throw ErroDaApi(codigo: .campoInvalido)
            }
            return try await api.painelEstabelecimento(
                id: estabelecimento.id,
                periodo: try Periodo(inicio: de, fim: ate)
            )
        }
    }

    public convenience init(
        api: any ApiCliente,
        estabelecimento: EstabelecimentoDaConta,
        vagaRecemPublicadaID: UUID? = nil,
        agora: @escaping @Sendable () -> Date = Date.init,
        calendario: Calendar = MinhasVagasViewModel.calendarioSaoPaulo
    ) {
        self.init(
            api: api,
            estabelecimentoID: estabelecimento.id,
            nomeEstabelecimento: estabelecimento.nome,
            vagaRecemPublicadaID: vagaRecemPublicadaID,
            agora: agora,
            calendario: calendario
        )
    }

    public init(
        api: any ApiCliente,
        estabelecimentoID: UUID,
        nomeEstabelecimento: String,
        vagaRecemPublicadaID: UUID? = nil,
        agora: @escaping @Sendable () -> Date = Date.init,
        calendario: Calendar = MinhasVagasViewModel.calendarioSaoPaulo
    ) {
        self.estabelecimentoID = estabelecimentoID
        self.nomeEstabelecimento = nomeEstabelecimento
        self.vagaRecemPublicadaID = vagaRecemPublicadaID
        self.agora = agora
        self.calendario = calendario
        buscarPainel = {
            let instante = agora()
            guard let de = calendario.date(byAdding: .day, value: -365, to: instante),
                  let ate = calendario.date(byAdding: .day, value: 365, to: instante) else {
                throw ErroDaApi(codigo: .campoInvalido)
            }
            return try await api.painelEstabelecimento(
                id: estabelecimentoID,
                periodo: try Periodo(inicio: de, fim: ate)
            )
        }
    }

    public init(
        estabelecimento: Estabelecimento,
        vagaRecemPublicadaID: UUID? = nil,
        agora: @escaping @Sendable () -> Date = Date.init,
        calendario: Calendar = MinhasVagasViewModel.calendarioSaoPaulo,
        buscarPainel: @escaping @Sendable () async throws -> Painel
    ) {
        self.estabelecimentoID = estabelecimento.id
        self.nomeEstabelecimento = estabelecimento.nome
        self.vagaRecemPublicadaID = vagaRecemPublicadaID
        self.agora = agora
        self.calendario = calendario
        self.buscarPainel = buscarPainel
    }

    public func carregar() async {
        guard !carregando else { return }
        carregando = true
        defer { carregando = false }
        erro = nil
        do {
            let painel = try await buscarPainel()
            guard painel.estabelecimentoID == estabelecimentoID else {
                erro = TextosMinhasVagas.semEstabelecimento
                return
            }
            vagas = painel.vagas
        } catch {
            // Puxar para atualizar cancela a tarefa da leitura: isso não é falha, e a lista boa fica.
            guard !Task.isCancelled else { return }
            erro = TextosMinhasVagas.falha
        }
    }

    /// Uma releitura automática por vez; fica fora de `carregando` para a tela não mostrar o aviso
    /// de "atualizando" nem desabilitar o "tentar de novo".
    private var atualizandoEmSilencio = false

    /// Atualização automática: sem o aviso de carregamento e, se falhar, sem mensagem de erro; a
    /// lista fica como estava. Com uma carga da tela em voo, não faz nada: ela traz o que há.
    public func atualizarEmSilencio() async {
        guard !carregando, !atualizandoEmSilencio else { return }
        atualizandoEmSilencio = true
        defer { atualizandoEmSilencio = false }
        guard let painel = try? await buscarPainel(), !Task.isCancelled, !carregando,
              painel.estabelecimentoID == estabelecimentoID else { return }
        vagas = painel.vagas
        erro = nil
    }

    public func podeRepublicar(_ vaga: VagaNoPainel) -> Bool {
        vaga.estado == .encerrada || vaga.estado == .cancelada || vaga.vaga.periodo.fim <= agora()
    }

    public func vagas(na secao: SecaoMinhasVagas) -> [VagaNoPainel] {
        vagas
            .filter { classificar($0) == secao }
            .sorted {
                if $0.vaga.id == vagaRecemPublicadaID { return true }
                if $1.vaga.id == vagaRecemPublicadaID { return false }
                return $0.vaga.periodo.inicio < $1.vaga.periodo.inicio
            }
    }

    public func classificar(_ vaga: VagaNoPainel) -> SecaoMinhasVagas {
        let instante = agora()
        if vaga.estado == .encerrada || vaga.estado == .cancelada || vaga.vaga.periodo.fim <= instante {
            return .encerradas
        }
        if vaga.alertaVagaVazia { return .emAlerta }
        if calendario.isDate(vaga.vaga.periodo.inicio, inSameDayAs: instante)
            || calendario.isDate(vaga.vaga.periodo.fim, inSameDayAs: instante) {
            return .hoje
        }
        if vaga.vaga.periodo.inicio > instante { return .proximas }
        return .encerradas
    }

    public func confirmadas(_ vaga: VagaNoPainel) -> Int {
        vaga.posicoes.filter { $0.estado == .confirmada || $0.estado == .cumprida }.count
    }

    public func tempoAteInicio(_ vaga: VagaNoPainel) -> String {
        let minutos = max(0, Int(ceil(vaga.vaga.periodo.inicio.timeIntervalSince(agora()) / 60)))
        guard minutos > 0 else { return TextosMinhasVagas.menosDeUmMinuto }
        let horas = minutos / 60
        let resto = minutos % 60
        if horas > 0 { return String(format: TextosMinhasVagas.horaMinuto, horas, resto) }
        return String(format: TextosMinhasVagas.apenasMinutos, minutos)
    }
}

/// Minhas vagas do contratante: seções de vagas em cartões brancos sobre o fundo agrupado, como nos quadros
/// "Acompanhar" e "Preenchida" do MidFi do Fabrício.
public struct TelaMinhasVagas: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var bloqueios = BloqueiosDaSessao()
    @State private var viewModel: MinhasVagasViewModel
    @State private var acompanhamento: AcompanhamentoViewModel
    @State private var roteador: RoteadorDoContratante
    @State private var vagaParaRepublicar: VagaNoPainel?
    @State private var republicacaoConcluida = false
    @State private var executandoTentativa = false
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let publicarVaga: (() -> Void)?
    /// Abre a publicação já preenchida com a busca vazia ("Publicar para todos"). Sem ele, a entrada da busca não aparece.
    private let publicarParaTodosDaBusca: ((RascunhoDeVagaDaBusca) -> Void)?
    private let sair: (() -> Void)?
    private let abrirPerfil: (() -> Void)?
    private let formatador = FormatadorFrila()
    /// A chave `busca_profissionais` do servidor (desligada no Prod).
    @State private var buscaHabilitada = false
    @State private var mostrandoBusca = false
    /// Segura o view model da busca enquanto um envio estiver em curso ou incerto (a folha é recriada a cada abertura).
    /// Vem do `FluxoDoContratante`, acima desta tela: publicar uma vaga tira esta tela da hierarquia, e a trava tem de
    /// voltar com ela (DINHEIRO). Sem ela (entradas de teste), a tela cria a sua.
    @State private var guardaDaBusca: GuardaDaBuscaDeProfissionais

    /// O roteador vem de fora quando um aviso do push precisa abrir a vaga ou o turno (#8).
    /// `publicarVaga` abre a publicação de uma vaga nova; sem ele, a entrada não aparece.
    public init(
        viewModel: MinhasVagasViewModel,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        roteador: RoteadorDoContratante? = nil,
        publicarVaga: (() -> Void)? = nil,
        publicarParaTodosDaBusca: ((RascunhoDeVagaDaBusca) -> Void)? = nil,
        guardaDaBusca: GuardaDaBuscaDeProfissionais? = nil,
        sair: (() -> Void)? = nil,
        abrirPerfil: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _acompanhamento = State(initialValue: AcompanhamentoViewModel(
            api: api, estabelecimentoID: viewModel.estabelecimentoID, fila: fila, aoMudar: { await viewModel.carregar() }
        ))
        _roteador = State(initialValue: roteador ?? RoteadorDoContratante())
        let estabelecimentoID = viewModel.estabelecimentoID
        _guardaDaBusca = State(initialValue: guardaDaBusca ?? GuardaDaBuscaDeProfissionais {
            BuscaDeProfissionaisViewModel(api: api, estabelecimentoID: estabelecimentoID)
        })
        self.api = api
        self.fila = fila
        self.publicarVaga = publicarVaga
        self.publicarParaTodosDaBusca = publicarParaTodosDaBusca
        self.sair = sair
        self.abrirPerfil = abrirPerfil
    }

    public var body: some View {
        conteudoDaTela
            .sheet(isPresented: $mostrandoBusca, onDismiss: { guardaDaBusca.aoFechar() }) {
                if let publicarParaTodosDaBusca, let buscaViewModel = guardaDaBusca.viewModel {
                    NavigationStack {
                        TelaBuscaDeProfissionais(viewModel: buscaViewModel, api: api,
                                                 estabelecimentoID: viewModel.estabelecimentoID) { rascunho in
                            mostrandoBusca = false
                            // A publicação tira esta tela da hierarquia e o onDismiss pode não vir: a guarda (que vive
                            // acima dela) solta aqui a busca resolvida; com envio em curso ou incerto, ela fica.
                            guardaDaBusca.aoFechar()
                            publicarParaTodosDaBusca(rascunho)
                        }
                    }
                    .environment(bloqueios)
                }
            }
            .task {
                guard publicarParaTodosDaBusca != nil else { return }
                buscaHabilitada = (try? await PrazoDaAbertura.esperar(.seconds(15)) {
                    try await api.configuracaoDoApp()
                })?.recursos.buscaProfissionais == true
            }
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        @Bindable var roteador = roteador
        NavigationStack(path: $roteador.caminho) {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    // A raiz abre sem título de página (D-DS-14): o nome da casa é o primeiro elemento. O nome da tela
                    // fica na barra, pequeno, para os testes e para o leitor de tela.
                    Text(verbatim: viewModel.nomeEstabelecimento)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if republicacaoConcluida {
                        AvisoFrila(verbatim: TextosRepublicarVaga.sucesso, tom: .informativo)
                            .accessibilityIdentifier("aviso-sucesso-republicacao")
                    }

                    AvisoDePermissaoDePush(perfil: .contratante)

                    if buscaHabilitada {
                        FrilaGrupoDeLinhas {
                            FrilaLinhaDeOpcao(icone: "magnifyingglass", titulo: TextosBuscaDeProfissionais.titulo, remate: .navega) {
                                _ = guardaDaBusca.aoAbrir()
                                mostrandoBusca = true
                            }
                            .accessibilityIdentifier("encontrar-profissional")
                        }
                    }

                    if viewModel.vagas.isEmpty {
                        if viewModel.erro != nil || executandoTentativa {
                            estadoErroSemDados
                        } else if viewModel.carregando {
                            estadoCarregandoSemDados
                        } else {
                            estadoVazio
                        }
                    } else {
                        if viewModel.carregando {
                            AvisoFrila(verbatim: TextosListaMinhasVagas.atualizando, tom: .informativo)
                        }

                        if let erro = viewModel.erro {
                            AvisoFrila(verbatim: erro, tom: .erro)
                        }

                        if viewModel.erro != nil || executandoTentativa {
                            let ocupado = executandoTentativa || viewModel.carregando
                            BotaoSecundario(
                                verbatim: ocupado ? TextosListaMinhasVagas.tentandoDeNovo : TextosListaMinhasVagas.tentarDeNovo,
                                acao: tentarNovamente
                            )
                            .disabled(ocupado)
                        }

                        PendenciasDoContratante(viewModel: acompanhamento) { roteador.caminho.append(.turno(turnoID: $0)) }

                        ForEach(SecaoMinhasVagas.allCases) { secao in
                            let itens = viewModel.vagas(na: secao)
                            if !itens.isEmpty {
                                conteudoSecao(secao: secao, itens: itens)
                            }
                        }
                    }
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.vertical, FrilaEspaco.bloco)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            // A leitura corre numa tarefa própria: o gesto de puxar cancela a tarefa dele, e isso não pode
            // derrubar a leitura no meio.
            .refreshable { await Task { await carregar() }.value }
            // Volta de uma tela empilhada, volta do segundo plano e push. Na troca de aba o `.task`
            // da pilha também relê; com ele em voo, a releitura em silêncio não sai.
            .atualizacaoAutomatica(.minhasVagas, recarregar: atualizarEmSilencio)
            .navigationTitle(Text(verbatim: TextosMinhasVagas.titulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let publicarVaga, !viewModel.vagas.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: publicarVaga) {
                            Label(TextosMinhasVagas.publicarVaga, systemImage: "plus")
                        }
                        .accessibilityIdentifier("publicar-vaga-entrada")
                    }
                }
            }
            .navigationDestination(for: RotaDoContratante.self) { rota in
                switch rota {
                case let .vaga(vagaID):
                    DestinoDaVagaDoContratante(viewModel: viewModel, acompanhamento: acompanhamento, vagaID: vagaID, api: api, fila: fila, sair: sair)
                case let .turno(turnoID):
                    TelaTurnoDoContratante(viewModel: acompanhamento, turnoID: turnoID, api: api, sair: sair)
                case let .acompanharChamadas(vagaID):
                    TelaAcompanharChamadas(viewModel: AcompanharChamadasViewModel(vagaID: vagaID, api: api)) { novaVagaID in
                        // A vaga aberta para todos é nova: relê o painel antes, ou o destino não a acha.
                        Task {
                            await carregar()
                            roteador.abrirVaga(id: novaVagaID)
                        }
                    }
                }
            }
        }
        .sheet(item: $vagaParaRepublicar) { vaga in
            NavigationStack {
                TelaRepublicarVaga(
                    viewModel: RepublicarVagaViewModel(
                        vagaOriginal: vaga,
                        api: api,
                        fila: fila,
                        aoConcluir: { _ in
                            await carregar()
                            await MainActor.run { republicacaoConcluida = true }
                        }
                    )
                )
            }
        }
        .modifier(ConfirmacaoDeReabertura(viewModel: acompanhamento))
        .environment(bloqueios)
        .environment(roteador)
        .task {
            await carregar()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-FRILA_CAPTURA") {
                let args = ProcessInfo.processInfo.arguments
                if let index = args.firstIndex(of: "-FRILA_CAPTURA"), index + 1 < args.count, args[index + 1] == "vaga-aberta" {
                    if let primeiraAtiva = viewModel.vagas.first(where: { $0.estado != .encerrada && $0.estado != .cancelada }) ?? viewModel.vagas.first {
                        if !roteador.caminho.contains(.vaga(primeiraAtiva.vaga.id)) {
                            roteador.caminho.append(.vaga(primeiraAtiva.vaga.id))
                        }
                    }
                }
            }
            #endif
        }
        // O aviso do push diz que algo mudou na casa: o painel é relido para a tela que ele abre.
        .onChange(of: roteador.avisosAbertos) { Task { await carregar() } }
        .accessibilityIdentifier("minhas-vagas")
    }

    private var estadoCarregandoSemDados: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: TextosListaMinhasVagas.carregando)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            EstadoCarregando()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var estadoErroSemDados: some View {
        let ocupado = executandoTentativa || viewModel.carregando
        return EstadoErro(verbatim: "\(TextosListaMinhasVagas.erroTitulo) \(TextosListaMinhasVagas.erroCorpo)",
                          tentarNovamente: tentarNovamente)
            .disabled(ocupado)
    }

    /// Vazio de primeira vez: o fato, a dica e o próximo passo. O botão fica fora do `EstadoVazio` para guardar o
    /// identificador que os testes usam, e é secundário: a lista e o vazio não decidem nada.
    private var estadoVazio: some View {
        VStack(spacing: 0) {
            EstadoVazio(verbatim: TextosMinhasVagas.vaziaTitulo, mensagem: TextosMinhasVagas.vaziaMensagem)
            if let publicarVaga {
                BotaoSecundario(verbatim: TextosMinhasVagas.publicarVaga, acao: publicarVaga)
                    .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
                    .accessibilityIdentifier("publicar-vaga-entrada")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("estado-vazio-minhas-vagas")
    }

    private func carregar() async {
        await viewModel.carregar()
        await acompanhamento.carregar()
    }

    private func atualizarEmSilencio() async {
        await viewModel.atualizarEmSilencio()
        await acompanhamento.atualizarEmSilencio()
    }

    private func tentarNovamente() {
        guard !executandoTentativa && !viewModel.carregando else { return }
        executandoTentativa = true
        Task {
            defer { executandoTentativa = false }
            await carregar()
        }
    }

    @ViewBuilder
    private func conteudoSecao(secao: SecaoMinhasVagas, itens: [VagaNoPainel]) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: secao.titulo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            // Lazy apenas nas encerradas: o painel traz as vagas de um ano (±365 dias).
            // As seções ativas têm poucas vagas e usam VStack para o Dynamic Type escalar sem recriar células.
            if secao == .encerradas {
                LazyVStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    ForEach(itens, id: \.vaga.id) { vaga in
                        itemVaga(vaga, secao: secao)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    ForEach(itens, id: \.vaga.id) { vaga in
                        itemVaga(vaga, secao: secao)
                    }
                }
            }
        }
    }

    /// Um cartão por vaga. A lista é o primário, então não há laranja: o botão de dentro do cartão é secundário.
    @ViewBuilder
    private func itemVaga(_ vaga: VagaNoPainel, secao: SecaoMinhasVagas) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            NavigationLink(value: RotaDoContratante.vaga(vaga.vaga.id)) {
                cartao(vaga, secao: secao)
                    // O fundo do cartão está fora do link: sem a forma, só o texto e os ícones recebem o toque.
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(verbatim: TextosMinhasVagas.verDetalhes))
            .accessibilityIdentifier("vaga-contratante-\(vaga.vaga.id)")

            if secao == .encerradas {
                BotaoSecundario(verbatim: TextosMinhasVagas.republicar) { vagaParaRepublicar = vaga }
                    .accessibilityIdentifier("republicar-vaga-\(vaga.vaga.id)")
            }

            BotaoRepublicarPosicoesRestantes(
                vagaID: vaga.vaga.id,
                posicoesRestantes: vaga.republicavelEmUrgencia ?? 0,
                api: api,
                podeRepublicar: vaga.podeRepublicarEmUrgencia,
                aoNavegarParaVaga: { roteador.abrirVaga(id: $0) },
                atualizarPainel: { await carregar() },
                idAcessibilidade: "republicar-urgencia-vaga-\(vaga.vaga.id)"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    @ViewBuilder
    private func cartao(_ vaga: VagaNoPainel, secao: SecaoMinhasVagas) -> some View {
        let confirmadas = viewModel.confirmadas(vaga)
        let total = vaga.posicoes.count
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if secao == .emAlerta {
                let tempo = String(format: TextosMinhasVagas.alertaComeca, viewModel.tempoAteInicio(vaga))
                SeloDeStatus(verbatim: tempo, estilo: .contorno, icone: "clock")
                    .accessibilityIdentifier("tempo-alerta-\(vaga.vaga.id)")
            }
            Text(verbatim: vaga.vaga.funcao)
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            FrilaLinhaDeDado(icone: "calendar") { Text(verbatim: periodo(vaga.vaga.periodo)) }
            FrilaLinhaDeDado(icone: "mappin.and.ellipse") { Text(verbatim: vaga.vaga.local) }
            FrilaLinhaDeDado(icone: "banknote") {
                Text(verbatim: formatador.dinheiro(vaga.vaga.valor)).font(FrilaTipo.rotuloSecundario)
            }
            BarraProgressoPosicoes(posicoes: vaga.posicoes)
                .padding(.top, FrilaEspaco.junto)
            Text(verbatim: textoConfirmadas(confirmadas: confirmadas, total: total))
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            if confirmadas > 0 {
                let nomes = nomesConfirmados(vaga)
                if !nomes.isEmpty {
                    Text(verbatim: nomes)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            RotuloDaSelecao(vaga: vaga)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func textoConfirmadas(confirmadas: Int, total: Int) -> String {
        if total == 1 {
            return String(format: TextosMinhasVagas.confirmadaSingular, confirmadas)
        } else {
            return String(format: TextosMinhasVagas.confirmadas, confirmadas, total)
        }
    }

    private func nomesConfirmados(_ vaga: VagaNoPainel) -> String {
        vaga.posicoes.compactMap { posicao in
            if let perfil = posicao.profissional, bloqueios.contem(perfil) { return nil }
            guard posicao.estado == .confirmada || posicao.estado == .cumprida else { return nil }
            return posicao.profissional?.nome
        }.joined(separator: ", ")
    }

    private func periodo(_ periodo: Periodo) -> String {
        textoPeriodo(periodo)
    }
}

/// Barra horizontal de 4 pt com um segmento por posição: tinta nas confirmadas, `borda` nas abertas.
private struct BarraProgressoPosicoes: View {
    let posicoes: [PosicaoNoPainel]

    var body: some View {
        HStack(spacing: FrilaEspaco.junto) {
            ForEach(posicoes) { posicao in
                let confirmada = posicao.estado == .confirmada || posicao.estado == .cumprida
                Capsule()
                    .fill(confirmada ? FrilaCor.texto : FrilaCor.borda)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Primeiro cartão na tela de detalhe com a barra e o estado da vaga (o card de status do turno, sem etapas).
/// Os estados finais viram selo; a vaga aberta diz o fato em texto, porque a frase é longa demais para um selo.
private struct CartaoEstadoVaga: View {
    let vaga: VagaNoPainel

    var body: some View {
        let (titulo, corpo) = textosEstado
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if let selo {
                SeloDeStatus(verbatim: titulo, estilo: selo.estilo, icone: selo.icone)
            } else {
                Text(verbatim: titulo)
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let corpo {
                Text(verbatim: corpo)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BarraProgressoPosicoes(posicoes: vaga.posicoes)
                .padding(.top, FrilaEspaco.junto)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private var textosEstado: (String, String?) { TextosMinhasVagas.estadoDoDetalhe(vaga) }

    private var selo: (estilo: SeloDeStatus.Estilo, icone: String?)? {
        if vaga.estado == .cancelada || vaga.estado == .encerrada { return (.encerrado, nil) }
        if vaga.posicoes.count > 0, vaga.posicoes.allSatisfy({ $0.estado == .confirmada || $0.estado == .cumprida }) {
            return (.destaque, "checkmark")
        }
        return nil
    }
}

extension TextosMinhasVagas {
    /// Título e corpo do cartão de estado no detalhe da vaga.
    static func estadoDoDetalhe(_ vaga: VagaNoPainel) -> (String, String?) {
        let total = vaga.posicoes.count
        let confirmadas = vaga.posicoes.filter { $0.estado == .confirmada || $0.estado == .cumprida }.count

        if vaga.estado == .cancelada {
            return (TextosMinhasVagas.vagaCancelada, TextosMinhasVagas.vagaCanceladaCorpo)
        }
        // O backend encerra toda vaga cujo turno terminou, inclusive a trabalhada (posições cumpridas):
        // "encerrada" não quer dizer que ninguém aceitou (E2E do Prod, 08/11/2026).
        if vaga.estado == .encerrada {
            guard confirmadas > 0 else { return (TextosMinhasVagas.encerradaNinguemAceitou, nil) }
            let corpo = total == 1
                ? TextosMinhasVagas.posicaoPreenchidaDeUma
                : String(format: TextosMinhasVagas.posicoesPreenchidas, confirmadas, total)
            return (TextosMinhasVagas.vagaEncerrada, corpo)
        }
        if confirmadas == total && total > 0 {
            return (TextosMinhasVagas.vagaPreenchida, TextosMinhasVagas.todasPosicoesConfirmadas)
        }
        if confirmadas == 0 {
            return (TextosMinhasVagas.abertaNinguemAceitou, TextosMinhasVagas.continuaNaLista)
        }
        if confirmadas == 1 {
            return (String(format: TextosMinhasVagas.posicoesConfirmadasSingular, total), TextosMinhasVagas.abertasContinuamNaLista)
        }
        return (String(format: TextosMinhasVagas.posicoesConfirmadasPlural, confirmadas, total), TextosMinhasVagas.abertasContinuamNaLista)
    }
}

/// A vaga pelo id, que é o que a lista e o aviso de vaga vazia trazem. Lê o painel do
/// acompanhamento, que já reflete uma confirmação ou reabertura feita agora.
private struct DestinoDaVagaDoContratante: View {
    @Environment(RoteadorDoContratante.self) private var roteador: RoteadorDoContratante?
    let viewModel: MinhasVagasViewModel
    let acompanhamento: AcompanhamentoViewModel
    let vagaID: UUID
    let api: any ApiCliente
    let fila: (any FilaDeAcoes)?
    var sair: (() -> Void)? = nil

    var body: some View {
        if let vaga = acompanhamento.vaga(id: vagaID) ?? viewModel.vagas.first(where: { $0.vaga.id == vagaID }) {
            TelaDetalheVagaContratante(
                vaga: vaga,
                api: api,
                fila: fila,
                confirmado: viewModel.confirmadas(vaga),
                podeRepublicar: { viewModel.podeRepublicar(vaga) },
                acompanhamento: acompanhamento,
                aoRepublicar: {
                    await viewModel.carregar()
                    await acompanhamento.carregar()
                },
                relerVaga: {
                    await viewModel.carregar()
                    await acompanhamento.carregar()
                    return acompanhamento.falhouAoCarregar ? nil : acompanhamento.vaga(id: vagaID)
                },
                roteador: roteador,
                sair: sair
            )
        } else if acompanhamento.falhouAoCarregar {
            // Sem leitura que tenha dado certo, não dá para dizer que a vaga não existe.
            VStack(spacing: FrilaEspaco.bloco) {
                AvisoFrila(verbatim: TextosDoAcompanhamento.falhaAoCarregarVaga, tom: .erro)
                BotaoSecundario("Tentar novamente") {
                    Task {
                        await viewModel.carregar()
                        await acompanhamento.carregar()
                    }
                }
                .accessibilityIdentifier("tentar-de-novo-vaga")
            }
            .padding(FrilaEspaco.grupo)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("vaga-contratante-falha-ao-carregar")
        } else if acompanhamento.painel == nil {
            EstadoCarregando()
        } else {
            AvisoFrila(verbatim: TextosDoAcompanhamento.vagaNaoEncontrada, tom: .informativo)
                .padding(FrilaEspaco.grupo)
                .accessibilityIdentifier("vaga-contratante-nao-encontrada")
        }
    }
}

private struct TelaDetalheVagaContratante: View {
    @Environment(BloqueiosDaSessao.self) private var bloqueios
    @Environment(RoteadorDoContratante.self) private var roteadorDoAmbiente: RoteadorDoContratante?
    let vaga: VagaNoPainel
    let api: any ApiCliente
    let fila: (any FilaDeAcoes)?
    let confirmado: Int
    let podeRepublicar: @MainActor () -> Bool
    /// Quem cancela a vaga ou uma posição (#20); `nil` nas prévias.
    var acompanhamento: AcompanhamentoViewModel? = nil
    var aoRepublicar: (@Sendable () async -> Void)? = nil
    /// Relê o painel depois de uma escolha e devolve a vaga como ficou; `nil` se a leitura falhou (#10).
    var relerVaga: @MainActor () async -> VagaNoPainel? = { nil }
    var roteador: RoteadorDoContratante? = nil
    var sair: (() -> Void)? = nil
    private var roteadorEfetivo: RoteadorDoContratante? {
        roteador ?? roteadorDoAmbiente
    }
    @State private var perfilSelecionado: PerfilPublico?
    @State private var vagaParaRepublicar: VagaNoPainel?
    @State private var republicacaoConcluida = false
    @State private var cancelamento: CancelamentoViewModel?
    /// A chave `chamada_direta` do servidor (RN46), como nas outras entradas da chamada direta.
    @State private var chamadaHabilitada = false
    private let formatador = FormatadorFrila()

    var body: some View {
        conteudoDaTela
            .task {
                chamadaHabilitada = (try? await PrazoDaAbertura.esperar(.seconds(15)) {
                    try await api.configuracaoDoApp()
                })?.recursos.chamadaDireta == true
            }
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if republicacaoConcluida {
                    AvisoFrila(verbatim: TextosRepublicarVaga.sucesso, tom: .informativo)
                        .accessibilityIdentifier("aviso-sucesso-republicacao")
                }
                if let acompanhamento {
                    AvisosDoAcompanhamento(viewModel: acompanhamento, vagaID: vaga.vaga.id)
                    ForEach(acompanhamento.recusasDaFila.filter { $0.tipo == .cancelamentoVaga && $0.vagaID == vaga.vaga.id }) { recusa in
                        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                            AvisoFrila(verbatim: TextosDaFila.texto(recusa), tom: .informativo)
                                .accessibilityIdentifier("aviso-acao-recusada-\(recusa.tipo.rawValue)")
                            BotaoSecundario("Fechar") { Task { await acompanhamento.fecharAvisoDaFila(id: recusa.id) } }
                                .accessibilityIdentifier("fechar-aviso-acao-recusada-\(recusa.tipo.rawValue)")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    Text(verbatim: vaga.vaga.funcao)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("funcao-vaga-detalhe-\(vaga.vaga.id)")
                    Text(verbatim: periodo(vaga.vaga.periodo))
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CartaoEstadoVaga(vaga: vaga)
                // CD-RF09: a vaga direta nasce de uma chamada; daqui a casa acompanha, cancela ou publica
                // para todos quando ninguém aceitou (RN35).
                if vaga.vaga.origem == .chamadaDireta, chamadaHabilitada {
                    // Pela rota da pilha, como o resto de Minhas vagas: o "Ver vaga aberta" troca o caminho.
                    NavigationLink(value: RotaDoContratante.acompanharChamadas(vagaID: vaga.vaga.id)) {
                        RotuloDeLinha(TextosChamadaDireta.acompanharTitulo)
                            .padding(.horizontal, FrilaEspaco.bloco)
                    }
                    .buttonStyle(EstiloDeLinhaTocavel())
                    .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.interno, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: FrilaRaio.interno, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
                    .accessibilityIdentifier("acompanhar-chamadas-\(vaga.vaga.id)")
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text(verbatim: TextosMinhasVagas.detalhesPublicadosTitulo)
                        .font(FrilaTipo.rotuloDeGrupo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        FrilaLinhaDeDado(icone: "person.2") {
                            Text(verbatim: vaga.posicoes.count == 1
                                 ? String(localized: "1 posição", bundle: bundleMinhasVagas)
                                 : String(format: TextosMinhasVagas.vagas, vaga.posicoes.count))
                        }
                        FrilaLinhaDeDado(icone: "banknote") {
                            (Text(verbatim: formatador.dinheiro(vaga.vaga.valor)).font(FrilaTipo.rotuloSecundario)
                             + Text(verbatim: " ")
                             + Text("por pessoa", bundle: bundleApresentacao).foregroundStyle(FrilaCor.textoSecundario))
                        }
                        FrilaLinhaDeDado(icone: "mappin.and.ellipse") { Text(verbatim: vaga.vaga.local) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartaoFrila()
                    .accessibilityElement(children: .combine)
                }

                if vaga.modo == .selecao {
                    SecaoDeCandidatos(vaga: vaga, api: api, relerVaga: relerVaga) { perfilSelecionado = $0 }
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text(verbatim: TextosMinhasVagas.posicoes)
                        .font(FrilaTipo.rotuloDeGrupo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(vaga.posicoes) { posicao in
                        let bloqueado = posicao.profissional.map { bloqueios.contem($0) } ?? false
                        if bloqueado && posicao.estado != .confirmada && posicao.estado != .cumprida {
                            Text(verbatim: TextosDaSeguranca.indisponivel)
                                .font(FrilaTipo.apoio)
                                .foregroundStyle(FrilaCor.textoSecundario)
                                .accessibilityIdentifier("posicao-bloqueada-\(posicao.id)")
                        } else {
                            cartaoPosicao(posicao, bloqueado: bloqueado)
                        }
                    }
                }

                // Republicar é secundário; cancelar é a ação de risco, discreta e no fim da tela.
                VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                    if podeRepublicar() {
                        BotaoSecundario(verbatim: TextosMinhasVagas.republicar) { vagaParaRepublicar = vaga }
                            .accessibilityIdentifier("republicar-detalhe-vaga-\(vaga.vaga.id)")
                    }

                    BotaoRepublicarPosicoesRestantes(
                        vagaID: vaga.vaga.id,
                        posicoesRestantes: vaga.republicavelEmUrgencia ?? 0,
                        api: api,
                        podeRepublicar: vaga.podeRepublicarEmUrgencia,
                        aoNavegarParaVaga: { id in
                            roteadorEfetivo?.abrirVaga(id: id)
                        },
                        atualizarPainel: {
                            _ = await relerVaga()
                        },
                        idAcessibilidade: "republicar-urgencia-detalhe-vaga-\(vaga.vaga.id)"
                    )

                    if let acompanhamento, acompanhamento.podeCancelarVaga(vaga) {
                        Button(role: .destructive) {
                            cancelamento = acompanhamento.criarCancelamento(da: vaga)
                        } label: {
                            Text(verbatim: TextosDoCancelamento.tituloVaga)
                        }
                        .buttonStyle(.frilaAcaoDiscreta)
                        .accessibilityIdentifier("cancelar-vaga-\(vaga.vaga.id)")
                    }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .sheet(item: $vagaParaRepublicar) { vaga in
            NavigationStack {
                TelaRepublicarVaga(
                    viewModel: RepublicarVagaViewModel(
                        vagaOriginal: vaga,
                        api: api,
                        fila: fila,
                        aoConcluir: { _ in
                            await aoRepublicar?()
                            await MainActor.run { republicacaoConcluida = true }
                        }
                    )
                )
            }
        }
        .sheet(item: $cancelamento) { folha in
            FolhaDeCancelamento(viewModel: folha) { cancelamento = nil }
        }
        .navigationTitle(Text(verbatim: TextosMinhasVagas.detalheTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $perfilSelecionado) { perfil in
            TelaPerfilPublico(perfil: perfil, api: api, bloqueios: bloqueios)
        }
        .task { await acompanhamento?.carregarRecusasDaFila() }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await acompanhamento?.carregarRecusasDaFila() }
        }
        .accessibilityIdentifier("detalhe-vaga-contratante")
    }

    @ViewBuilder private func cartaoPosicao(_ posicao: PosicaoNoPainel, bloqueado: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if bloqueado {
                Text(verbatim: TextosDaSeguranca.voceBloqueouProfissional)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("etiqueta-bloqueio-\(posicao.id)")
            }
            if posicao.estado == .confirmada || posicao.estado == .cumprida {
                Text(verbatim: posicao.profissional?.nome ?? TextosMinhasVagas.profissionaisConfirmados)
                    .font(FrilaTipo.nome)
                    .fixedSize(horizontal: false, vertical: true)
                if let perfil = posicao.profissional, !bloqueado {
                    Button { perfilSelecionado = perfil } label: {
                        Text(verbatim: TextosMinhasVagas.perfil)
                    }
                    .buttonStyle(.frilaLink)
                    .accessibilityIdentifier("perfil-publico-\(posicao.id)")
                }
                if let turnoID = posicao.turnoID {
                    NavigationLink(value: RotaDoContratante.turno(turnoID: turnoID)) {
                        Text(verbatim: TextosDoAcompanhamento.acompanharTurno)
                    }
                    .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
                    .accessibilityIdentifier("acompanhar-turno-\(turnoID)")
                }
                let turno = TurnoAcompanhado(vaga: vaga.vaga, posicao: posicao)
                if let acompanhamento, acompanhamento.podeCancelar(turno) {
                    Button(role: .destructive) {
                        cancelamento = acompanhamento.criarCancelamento(de: turno)
                    } label: {
                        Text(verbatim: TextosDoCancelamento.tituloPosicao)
                    }
                    .buttonStyle(.frilaAcaoDiscreta)
                    .accessibilityIdentifier("cancelar-posicao-\(posicao.id)")
                }
            } else if posicao.estado == .aberta {
                Text(verbatim: TextosMinhasVagas.posicaoAberta)
                    .font(FrilaTipo.nome)
                    .fixedSize(horizontal: false, vertical: true)
            } else if posicao.estado == .cancelada, let nome = posicao.profissional?.nome {
                // Cancelada ou reaberta por atraso: a posição guarda de quem era (RN12).
                Text(verbatim: nome)
                    .font(FrilaTipo.nome)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: TextosDoAcompanhamento.cancelada)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                if let turnoID = posicao.turnoID {
                    NavigationLink(value: RotaDoContratante.turno(turnoID: turnoID)) {
                        Text(verbatim: TextosDoAcompanhamento.acompanharTurno)
                    }
                    .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
                    .accessibilityIdentifier("acompanhar-turno-\(turnoID)")
                }
            } else if posicao.estado == .cancelada, vaga.modo == .selecao {
                // A seleção fechou 24 h antes do início com esta posição ainda aberta (RN24), ou a
                // casa cancelou a vaga: o texto diz qual das duas.
                Text(verbatim: TextosDosCandidatos.posicaoCancelada(vaga: vaga.estado))
                    .font(FrilaTipo.nome)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(verbatim: TextosMinhasVagas.encerradas)
                    .font(FrilaTipo.nome)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }

    private func periodo(_ periodo: Periodo) -> String {
        textoPeriodo(periodo)
    }
}
