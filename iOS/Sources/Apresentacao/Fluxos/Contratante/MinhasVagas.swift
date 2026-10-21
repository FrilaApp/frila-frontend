import FrilaDominio
import Observation
import SwiftUI

private final class MarcadorMinhasVagas: NSObject {}
private let bundleMinhasVagas = Bundle(for: MarcadorMinhasVagas.self)

private enum TextosMinhasVagas {
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
    static let verContato = String(localized: "Ver contato liberado", bundle: bundleMinhasVagas)
    static let contatoExpirado = String(localized: "O prazo para ver este contato terminou.", bundle: bundleMinhasVagas)
    static let contatoFalhou = String(localized: "Não foi possível carregar o contato. Tente novamente.", bundle: bundleMinhasVagas)
    static let ligar = String(localized: "Ligar", bundle: bundleMinhasVagas)
    static let whatsApp = String(localized: "WhatsApp", bundle: bundleMinhasVagas)
    static let periodo = String(localized: "%@ – %@", bundle: bundleMinhasVagas)
    static let periodoMesmoDia = String(localized: "%@, %@ – %@", bundle: bundleMinhasVagas)
    static let publicarVaga = String(localized: "Publicar vaga", bundle: bundleMinhasVagas)
    static let republicar = String(localized: "Publicar de novo", bundle: bundleMinhasVagas)
    static let detalhesPublicados = String(localized: "DETALHES PUBLICADOS", bundle: bundleMinhasVagas)
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
    static let vagaCancelada = String(localized: "Vaga cancelada", bundle: bundleMinhasVagas)
    static let vagaCanceladaCorpo = String(localized: "Ela saiu da lista e não é mais enviada aos profissionais.", bundle: bundleMinhasVagas)
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
            erro = TextosMinhasVagas.falha
        }
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
    @ScaledMetric(relativeTo: .body) private var larguraDoIcone: CGFloat = 24
    @State private var bloqueios = BloqueiosDaSessao()
    @State private var viewModel: MinhasVagasViewModel
    @State private var acompanhamento: AcompanhamentoViewModel
    @State private var roteador: RoteadorDoContratante
    @State private var vagaParaRepublicar: VagaNoPainel?
    @State private var republicacaoConcluida = false
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let publicarVaga: (() -> Void)?
    private let sair: (() -> Void)?
    private let abrirPerfil: (() -> Void)?
    private let formatador = FormatadorFrila()

    /// O roteador vem de fora quando um aviso do push precisa abrir a vaga ou o turno (#8).
    /// `publicarVaga` abre a publicação de uma vaga nova; sem ele, a entrada não aparece.
    public init(
        viewModel: MinhasVagasViewModel,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        roteador: RoteadorDoContratante? = nil,
        publicarVaga: (() -> Void)? = nil,
        sair: (() -> Void)? = nil,
        abrirPerfil: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _acompanhamento = State(initialValue: AcompanhamentoViewModel(
            api: api, estabelecimentoID: viewModel.estabelecimentoID, fila: fila, aoMudar: { await viewModel.carregar() }
        ))
        _roteador = State(initialValue: roteador ?? RoteadorDoContratante())
        self.api = api
        self.fila = fila
        self.publicarVaga = publicarVaga
        self.sair = sair
        self.abrirPerfil = abrirPerfil
    }

    public var body: some View {
        @Bindable var roteador = roteador
        NavigationStack(path: $roteador.caminho) {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    // O título grande é o da barra; o nome do estabelecimento fica abaixo em resumo/texto.
                    Text(verbatim: viewModel.nomeEstabelecimento)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)

                    if republicacaoConcluida {
                        AvisoFrila(verbatim: TextosRepublicarVaga.sucesso, tom: .informativo)
                            .accessibilityIdentifier("aviso-sucesso-republicacao")
                    }

                    AvisoDePermissaoDePush(perfil: .contratante)

                    if let erro = viewModel.erro {
                        if viewModel.vagas.isEmpty {
                            EstadoErro(verbatim: erro) {
                                Task { await viewModel.carregar() }
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(FrilaCor.texto)
                                Text(verbatim: erro)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                            }
                            .padding(FrilaEspaco.medio)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso))
                            .overlay(
                                RoundedRectangle(cornerRadius: FrilaRaio.aviso)
                                    .stroke(FrilaCor.texto, lineWidth: 1)
                            )

                            BotaoSecundario(verbatim: TextosMinhasVagas.tentarNovamente) {
                                Task { await viewModel.carregar() }
                            }
                        }
                    } else if viewModel.carregando && viewModel.vagas.isEmpty {
                        EstadoCarregando()
                    } else if viewModel.vagas.isEmpty {
                        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                                Text(verbatim: TextosMinhasVagas.vaziaTitulo)
                                    .font(FrilaTipo.tituloDoCartao)
                                    .foregroundStyle(FrilaCor.texto)
                                Text(verbatim: TextosMinhasVagas.vaziaMensagem)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                            }
                            if let publicarVaga {
                                BotaoPrimario(verbatim: TextosMinhasVagas.publicarVaga, acao: publicarVaga)
                                    .accessibilityIdentifier("publicar-vaga-entrada")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartaoFrila()
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("estado-vazio-minhas-vagas")
                    } else {
                        PendenciasDoContratante(viewModel: acompanhamento) { roteador.caminho.append(.turno(turnoID: $0)) }
                        ForEach(SecaoMinhasVagas.allCases) { secao in
                            let itens = viewModel.vagas(na: secao)
                            if !itens.isEmpty {
                                conteudoSecao(secao: secao, itens: itens)
                            }
                        }
                    }
                }
                .padding(FrilaEspaco.medio)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .refreshable { await carregar() }
            .navigationTitle(Text(verbatim: TextosMinhasVagas.titulo))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let sair {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: sair) {
                            Text("Sair", bundle: bundleApresentacao)
                        }
                        .accessibilityIdentifier("sair-fluxo-contratante")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let abrirPerfil {
                        Button(action: abrirPerfil) {
                            Label(String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao), systemImage: "person.crop.circle")
                        }
                        .accessibilityLabel(String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao))
                        .accessibilityIdentifier("abrir-perfil-estabelecimento")
                    }
                    if let publicarVaga, !viewModel.vagas.isEmpty {
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
                    DestinoDaVagaDoContratante(viewModel: viewModel, acompanhamento: acompanhamento, vagaID: vagaID, api: api, fila: fila)
                case let .turno(turnoID):
                    TelaTurnoDoContratante(viewModel: acompanhamento, turnoID: turnoID, api: api)
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

    private func carregar() async {
        await viewModel.carregar()
        await acompanhamento.carregar()
    }

    @ViewBuilder
    private func conteudoSecao(secao: SecaoMinhasVagas, itens: [VagaNoPainel]) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: secao.titulo)
                .font(FrilaTipo.tituloDoCartao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            // Lazy apenas nas encerradas: o painel traz as vagas de um ano (±365 dias).
            // As seções ativas têm poucas vagas e usam VStack para o Dynamic Type escalar sem recriar células.
            if secao == .encerradas {
                LazyVStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                    ForEach(itens, id: \.vaga.id) { vaga in
                        itemVaga(vaga, secao: secao)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                    ForEach(itens, id: \.vaga.id) { vaga in
                        itemVaga(vaga, secao: secao)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemVaga(_ vaga: VagaNoPainel, secao: SecaoMinhasVagas) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            NavigationLink(value: RotaDoContratante.vaga(vaga.vaga.id)) { cartao(vaga, secao: secao) }
                .buttonStyle(.plain)
                .accessibilityHint(Text(verbatim: TextosMinhasVagas.verDetalhes))
                .accessibilityIdentifier("vaga-contratante-\(vaga.vaga.id)")
            if secao == .encerradas {
                BotaoPublicarDeNovo { vagaParaRepublicar = vaga }
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
    }

    private func cartao(_ vaga: VagaNoPainel, secao: SecaoMinhasVagas) -> some View {
        let confirmadas = viewModel.confirmadas(vaga)
        let total = vaga.posicoes.count
        let layoutAlerta = (secao == .emAlerta && dynamicTypeSize.isAccessibilitySize)
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FrilaEspaco.minimo))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            layoutAlerta {
                Text(verbatim: vaga.vaga.funcao).font(FrilaTipo.resumo)
                    .foregroundStyle(FrilaCor.texto)
                if secao != .emAlerta {
                    Spacer(minLength: FrilaEspaco.pequeno)
                }
                if secao == .emAlerta {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: FrilaEspaco.pequeno)
                    }
                    let tempo = String(format: TextosMinhasVagas.alertaComeca, viewModel.tempoAteInicio(vaga))
                    Label { Text(verbatim: tempo) } icon: { Image(systemName: "exclamationmark.triangle") }
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityIdentifier("tempo-alerta-\(vaga.vaga.id)")
                }
            }
            LinhaDeVaga(icone: "calendar", texto: periodo(vaga.vaga.periodo))
            LinhaDeVaga(icone: "mappin.and.ellipse", texto: vaga.vaga.local)
            LinhaDeVaga(icone: "banknote", texto: formatador.dinheiro(vaga.vaga.valor), numerico: true)
            BarraProgressoPosicoes(posicoes: vaga.posicoes)
            Text(verbatim: textoConfirmadas(confirmadas: confirmadas, total: total))
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
            if confirmadas > 0 {
                let nomes = nomesConfirmados(vaga)
                if !nomes.isEmpty {
                    Text(verbatim: nomes)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.leading, larguraDoIcone + FrilaEspaco.pequeno)
                }
            }
            RotuloDaSelecao(vaga: vaga)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                .strokeBorder(secao == .emAlerta ? FrilaCor.texto : FrilaCor.divisoria, lineWidth: secao == .emAlerta ? 2 : 1)
        )
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

/// Linha de dados da vaga: ícone em coluna de largura fixa e texto de apoio, como nos cartões do MidFi.
private struct LinhaDeVaga: View {
    @ScaledMetric(relativeTo: .body) private var larguraDoIcone: CGFloat = 24
    let icone: String
    let texto: String
    var numerico = false
    var destaque = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(width: larguraDoIcone)
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .font(fonte)
                .foregroundStyle(destaque ? FrilaCor.texto : FrilaCor.textoSecundario)
        }
    }

    private var fonte: Font {
        let base = destaque ? FrilaTipo.meta.weight(.semibold) : FrilaTipo.meta
        return numerico ? base.monospacedDigit() : base
    }
}

/// Barra horizontal de 4 pt com um segmento por posição.
private struct BarraProgressoPosicoes: View {
    let posicoes: [PosicaoNoPainel]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(posicoes) { posicao in
                let confirmada = posicao.estado == .confirmada || posicao.estado == .cumprida
                RoundedRectangle(cornerRadius: 2)
                    .fill(confirmada ? FrilaCor.texto : FrilaCor.controle)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Linha de detalhe publicado na tela de detalhe da vaga.
private struct LinhaDetalhePublicado: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rotulo: String
    let valor: String
    var comDivisoria: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: FrilaEspaco.minimo))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: FrilaEspaco.compacto))
            layout {
                Text(verbatim: rotulo)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: FrilaEspaco.pequeno)
                }
                Text(verbatim: valor)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .padding(.trailing, FrilaEspaco.medio)

            if comDivisoria {
                Divider()
                    .overlay(FrilaCor.divisoria)
            }
        }
    }
}

/// Primeiro cartão na tela de detalhe com a barra e o estado da vaga.
private struct CartaoEstadoVaga: View {
    let vaga: VagaNoPainel

    var body: some View {
        let (titulo, corpo) = textosEstado
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            BarraProgressoPosicoes(posicoes: vaga.posicoes)
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: titulo)
                    .font(FrilaTipo.resumo)
                    .foregroundStyle(FrilaCor.texto)
                if let corpo {
                    Text(verbatim: corpo)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    private var textosEstado: (String, String?) {
        let total = vaga.posicoes.count
        let confirmadas = vaga.posicoes.filter { $0.estado == .confirmada || $0.estado == .cumprida }.count

        if vaga.estado == .cancelada {
            return (TextosMinhasVagas.vagaCancelada, TextosMinhasVagas.vagaCanceladaCorpo)
        }
        if vaga.estado == .encerrada {
            return (TextosMinhasVagas.encerradaNinguemAceitou, nil)
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

/// Botão "Publicar de novo" em pílula escura, como o botão principal do MidFi, com alvo de 44 pt.
private struct BotaoPublicarDeNovo: View {
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: FrilaEspaco.pequeno) {
                Image(systemName: "arrow.clockwise")
                    .accessibilityHidden(true)
                Text(verbatim: TextosMinhasVagas.republicar)
            }
            .font(FrilaTipo.meta.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.pequeno)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrilaCor.sobrePrimaria)
        .background(FrilaCor.primaria, in: Capsule())
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
                roteador: roteador
            )
        } else if acompanhamento.falhouAoCarregar {
            // Sem leitura que tenha dado certo, não dá para dizer que a vaga não existe.
            VStack(spacing: FrilaEspaco.medio) {
                AvisoFrila(verbatim: TextosDoAcompanhamento.falhaAoCarregarVaga, tom: .erro)
                BotaoSecundario("Tentar novamente") {
                    Task {
                        await viewModel.carregar()
                        await acompanhamento.carregar()
                    }
                }
                .accessibilityIdentifier("tentar-de-novo-vaga")
            }
            .padding(FrilaEspaco.medio)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("vaga-contratante-falha-ao-carregar")
        } else if acompanhamento.painel == nil {
            EstadoCarregando()
        } else {
            AvisoFrila(verbatim: TextosDoAcompanhamento.vagaNaoEncontrada, tom: .informativo)
                .padding(FrilaEspaco.medio)
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
    private var roteadorEfetivo: RoteadorDoContratante? {
        roteador ?? roteadorDoAmbiente
    }
    @State private var contatos: [UUID: Contato] = [:]
    @State private var carregandoContato: Set<UUID> = []
    @State private var errosContato: [UUID: String] = [:]
    @State private var perfilSelecionado: PerfilPublico?
    @State private var vagaParaRepublicar: VagaNoPainel?
    @State private var republicacaoConcluida = false
    @State private var cancelamento: CancelamentoViewModel?
    @State private var ultimoContatoAberto: [UUID: Date] = [:]
    private let formatador = FormatadorFrila()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if republicacaoConcluida {
                    AvisoFrila(verbatim: TextosRepublicarVaga.sucesso, tom: .informativo)
                        .accessibilityIdentifier("aviso-sucesso-republicacao")
                }
                if let acompanhamento {
                    AvisosDoAcompanhamento(viewModel: acompanhamento)
                    ForEach(acompanhamento.recusasDaFila.filter { $0.tipo == .cancelamentoVaga && $0.vagaID == vaga.vaga.id }) { recusa in
                        AvisoFrila(verbatim: TextosDaFila.texto(recusa), tom: .informativo)
                            .accessibilityIdentifier("aviso-acao-recusada-\(recusa.tipo.rawValue)")
                        BotaoSecundario("Fechar") { Task { await acompanhamento.fecharAvisoDaFila(id: recusa.id) } }
                            .accessibilityIdentifier("fechar-aviso-acao-recusada-\(recusa.tipo.rawValue)")
                    }
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: vaga.vaga.funcao)
                        .font(FrilaTipo.tituloGrande)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("funcao-vaga-detalhe-\(vaga.vaga.id)")
                    Text(verbatim: periodo(vaga.vaga.periodo))
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                CartaoEstadoVaga(vaga: vaga)

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: TextosMinhasVagas.detalhesPublicados)
                        .font(FrilaTipo.microRotulo)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.horizontal, FrilaEspaco.medio)

                    VStack(spacing: 0) {
                        LinhaDetalhePublicado(
                            rotulo: TextosMinhasVagas.posicoes,
                            valor: "\(vaga.posicoes.count)",
                            comDivisoria: true
                        )
                        LinhaDetalhePublicado(
                            rotulo: TextosMinhasVagas.valorPorPessoa,
                            valor: formatador.dinheiro(vaga.vaga.valor),
                            comDivisoria: true
                        )
                        LinhaDetalhePublicado(
                            rotulo: TextosMinhasVagas.local,
                            valor: vaga.vaga.local,
                            comDivisoria: false
                        )
                    }
                    .padding(.leading, FrilaEspaco.medio)
                    .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                            .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
                    )
                }

                if podeRepublicar() {
                    BotaoPublicarDeNovo { vagaParaRepublicar = vaga }
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
                    BotaoDeCancelamento(titulo: TextosDoCancelamento.tituloVaga) { cancelamento = acompanhamento.criarCancelamento(da: vaga) }
                        .accessibilityIdentifier("cancelar-vaga-\(vaga.vaga.id)")
                }

                if vaga.modo == .selecao {
                    SecaoDeCandidatos(vaga: vaga, api: api, relerVaga: relerVaga) { perfilSelecionado = $0 }
                }

                Text(verbatim: TextosMinhasVagas.posicoes).font(FrilaTipo.tituloDoCartao).foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)
                ForEach(vaga.posicoes) { posicao in
                    let bloqueado = posicao.profissional.map { bloqueios.contem($0) } ?? false
                    if bloqueado && posicao.estado != .confirmada && posicao.estado != .cumprida {
                        Text(verbatim: TextosDaSeguranca.indisponivel)
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityIdentifier("posicao-bloqueada-\(posicao.id)")
                    } else {
                        cartaoPosicao(posicao, bloqueado: bloqueado)
                    }
                }
            }
            .padding(FrilaEspaco.medio)
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
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            if bloqueado {
                Text(verbatim: TextosDaSeguranca.voceBloqueouProfissional)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("etiqueta-bloqueio-\(posicao.id)")
            }
            if posicao.estado == .confirmada || posicao.estado == .cumprida {
                Text(verbatim: posicao.profissional?.nome ?? TextosMinhasVagas.profissionaisConfirmados)
                    .font(FrilaTipo.resumo)
                if let perfil = posicao.profissional, !bloqueado {
                    Button { perfilSelecionado = perfil } label: {
                        Text(verbatim: TextosMinhasVagas.perfil)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("perfil-publico-\(posicao.id)")
                }
                if let turnoID = posicao.turnoID {
                    NavigationLink(value: RotaDoContratante.turno(turnoID: turnoID)) {
                        Text(verbatim: TextosDoAcompanhamento.acompanharTurno)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("acompanhar-turno-\(turnoID)")
                }
                if let contato = contatos[posicao.id], contato.estaVisivel(em: .now), let turnoID = posicao.turnoID {
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                        Text(verbatim: "\(contato.nome) · \(contato.telefone)")
                            .font(FrilaTipo.meta)
                        let telefone = contato.telefone.filter { $0.isNumber || $0 == "+" }
                        if let telefoneURL = URL(string: "tel:\(telefone)") {
                            Link(destination: telefoneURL) {
                                Label { Text(verbatim: TextosMinhasVagas.ligar) } icon: { Image(systemName: "phone") }
                                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                            }
                        }
                        if let whatsappURL = URLComponents(url: contato.whatsappURL, resolvingAgainstBaseURL: false)?.url {
                            Link(destination: whatsappURL) {
                                Label { Text(verbatim: TextosMinhasVagas.whatsApp) } icon: { Image(systemName: "message") }
                                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                let agora = Date()
                                if let ultimo = ultimoContatoAberto[turnoID], agora.timeIntervalSince(ultimo) < 5.0 {
                                    return
                                }
                                ultimoContatoAberto[turnoID] = agora
                                Task { _ = await RegistradorDeTelemetria(api: api).registrar(.contatoAberto, turnoID: turnoID) }
                            })
                        }
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("contato-liberado-\(turnoID)")
                } else if contatos[posicao.id] != nil {
                    AvisoFrila(verbatim: TextosMinhasVagas.contatoExpirado, tom: .informativo)
                } else if let erro = errosContato[posicao.id] {
                    AvisoFrila(verbatim: erro, tom: .erro)
                } else if posicao.turnoID != nil {
                    Button {
                        Task { await carregarContato(posicao) }
                    } label: {
                        if carregandoContato.contains(posicao.id) {
                            ProgressView().frame(minHeight: FrilaMetrica.alvoMinimo)
                        } else {
                            Text(verbatim: TextosMinhasVagas.verContato).frame(minHeight: FrilaMetrica.alvoMinimo)
                        }
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .disabled(carregandoContato.contains(posicao.id))
                    .accessibilityIdentifier("ver-contato-\(posicao.id)")
                }
                let turno = TurnoAcompanhado(vaga: vaga.vaga, posicao: posicao)
                if let acompanhamento, acompanhamento.podeCancelar(turno) {
                    BotaoDeCancelamento(titulo: TextosDoCancelamento.tituloPosicao) { cancelamento = acompanhamento.criarCancelamento(de: turno) }
                        .accessibilityIdentifier("cancelar-posicao-\(posicao.id)")
                }
            } else if posicao.estado == .aberta {
                Text(verbatim: TextosMinhasVagas.posicaoAberta).font(FrilaTipo.resumo)
            } else if posicao.estado == .cancelada, let nome = posicao.profissional?.nome {
                // Cancelada ou reaberta por atraso: a posição guarda de quem era (RN12).
                Text(verbatim: nome).font(FrilaTipo.resumo)
                Text(verbatim: TextosDoAcompanhamento.cancelada).font(FrilaTipo.meta).foregroundStyle(FrilaCor.textoSecundario)
                if let turnoID = posicao.turnoID {
                    NavigationLink(value: RotaDoContratante.turno(turnoID: turnoID)) {
                        Text(verbatim: TextosDoAcompanhamento.acompanharTurno)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("acompanhar-turno-\(turnoID)")
                }
            } else if posicao.estado == .cancelada, vaga.modo == .selecao {
                // A seleção fechou 24 h antes do início com esta posição ainda aberta (RN24), ou a
                // casa cancelou a vaga: o texto diz qual das duas.
                Text(verbatim: TextosDosCandidatos.posicaoCancelada(vaga: vaga.estado)).font(FrilaTipo.resumo)
            } else {
                Text(verbatim: TextosMinhasVagas.encerradas).font(FrilaTipo.resumo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }

    @MainActor private func carregarContato(_ posicao: PosicaoNoPainel) async {
        guard let turnoID = posicao.turnoID else { return }
        carregandoContato.insert(posicao.id)
        defer { carregandoContato.remove(posicao.id) }
        do {
            let contato = try await api.contatoDoTurno(id: turnoID)
            guard contato.estaVisivel(em: .now) else {
                contatos[posicao.id] = contato
                return
            }
            contatos[posicao.id] = contato
            errosContato[posicao.id] = nil
        } catch let erro as ErroDaApi where erro.codigo == .contatoExpirado {
            errosContato[posicao.id] = TextosMinhasVagas.contatoExpirado
        } catch {
            errosContato[posicao.id] = TextosMinhasVagas.contatoFalhou
        }
    }

    private func periodo(_ periodo: Periodo) -> String {
        textoPeriodo(periodo)
    }
}
