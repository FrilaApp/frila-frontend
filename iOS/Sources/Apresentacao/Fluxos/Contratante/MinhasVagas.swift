import FrilaDominio
import Observation
import SwiftUI

private final class MarcadorMinhasVagas: NSObject {}
private let bundleMinhasVagas = Bundle(for: MarcadorMinhasVagas.self)

private enum TextosMinhasVagas {
    static let titulo = String(localized: "Minhas vagas", bundle: bundleMinhasVagas)
    static let emAlerta = String(localized: "Em alerta", bundle: bundleMinhasVagas)
    static let hoje = String(localized: "Hoje", bundle: bundleMinhasVagas)
    static let proximas = String(localized: "Próximas", bundle: bundleMinhasVagas)
    static let encerradas = String(localized: "Encerradas", bundle: bundleMinhasVagas)
    static let vaziaTitulo = String(localized: "Suas vagas aparecem aqui", bundle: bundleMinhasVagas)
    static let vaziaMensagem = String(localized: "Publique sua primeira vaga para acompanhar posições abertas, confirmações e alertas.", bundle: bundleMinhasVagas)
    static let semEstabelecimento = String(localized: "Não encontramos o estabelecimento cadastrado.", bundle: bundleMinhasVagas)
    static let falha = String(localized: "Não foi possível carregar suas vagas. Tente novamente.", bundle: bundleMinhasVagas)
    static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleMinhasVagas)
    static let atualizar = String(localized: "Atualizar vagas", bundle: bundleMinhasVagas)
    static let vagas = String(localized: "%d posições", bundle: bundleMinhasVagas)
    static let confirmadas = String(localized: "%d de %d confirmadas", bundle: bundleMinhasVagas)
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
    static let republicar = String(localized: "Publicar de novo", bundle: bundleMinhasVagas)
}

private func textoPeriodo(_ periodo: Periodo) -> String {
    let formatador = DateFormatter()
    formatador.locale = FormatadorFrila.locale
    formatador.timeZone = FormatadorFrila.fuso
    formatador.dateStyle = .medium
    formatador.timeStyle = .short
    return String(format: TextosMinhasVagas.periodo, formatador.string(from: periodo.inicio), formatador.string(from: periodo.fim))
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

public struct TelaMinhasVagas: View {
    @State private var viewModel: MinhasVagasViewModel
    @State private var acompanhamento: AcompanhamentoViewModel
    @State private var roteador: RoteadorDoContratante
    @State private var vagaParaRepublicar: VagaNoPainel?
    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let formatador = FormatadorFrila()

    /// O roteador vem de fora quando um aviso do push precisa abrir a vaga ou o turno (#8).
    public init(
        viewModel: MinhasVagasViewModel,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        roteador: RoteadorDoContratante? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _acompanhamento = State(initialValue: AcompanhamentoViewModel(
            api: api, estabelecimentoID: viewModel.estabelecimentoID, aoMudar: { await viewModel.carregar() }
        ))
        _roteador = State(initialValue: roteador ?? RoteadorDoContratante())
        self.api = api
        self.fila = fila
    }

    public var body: some View {
        @Bindable var roteador = roteador
        NavigationStack(path: $roteador.caminho) {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    Text(verbatim: TextosMinhasVagas.titulo)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: viewModel.nomeEstabelecimento)
                        .font(.headline)
                        .foregroundStyle(FrilaCor.textoSecundario)

                    AvisoDePermissaoDePush(perfil: .contratante)

                    if let erro = viewModel.erro {
                        AvisoFrila(verbatim: erro, tom: .erro)
                        Button {
                            Task { await viewModel.carregar() }
                        } label: {
                            Text(verbatim: TextosMinhasVagas.tentarNovamente)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                        }
                    } else if viewModel.carregando && viewModel.vagas.isEmpty {
                        ProgressView()
                            .accessibilityLabel(Text(verbatim: TextosMinhasVagas.atualizar))
                    } else if viewModel.vagas.isEmpty {
                        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                            Text(verbatim: TextosMinhasVagas.vaziaTitulo).font(.title3.bold())
                            Text(verbatim: TextosMinhasVagas.vaziaMensagem).foregroundStyle(FrilaCor.textoSecundario)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FrilaEspaco.medio)
                        .cartaoFrila()
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("estado-vazio-minhas-vagas")
                    } else {
                        PendenciasDoContratante(viewModel: acompanhamento) { roteador.caminho.append(.turno(turnoID: $0)) }
                        ForEach(SecaoMinhasVagas.allCases) { secao in
                            let itens = viewModel.vagas(na: secao)
                            if !itens.isEmpty {
                                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                                    Text(verbatim: secao.titulo)
                                        .font(.title3.bold())
                                        .accessibilityAddTraits(.isHeader)
                                    ForEach(itens, id: \.vaga.id) { vaga in
                                        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                                            NavigationLink(value: RotaDoContratante.vaga(vaga.vaga.id)) { cartao(vaga, secao: secao) }
                                                .buttonStyle(.plain)
                                                .accessibilityHint(Text(verbatim: TextosMinhasVagas.verDetalhes))
                                                .accessibilityIdentifier("vaga-contratante-\(vaga.vaga.id)")
                                            if secao == .encerradas {
                                                Button {
                                                    vagaParaRepublicar = vaga
                                                } label: {
                                                    HStack(spacing: FrilaEspaco.pequeno) {
                                                        Image(systemName: "arrow.clockwise")
                                                        Text(verbatim: TextosMinhasVagas.republicar)
                                                    }
                                                    .font(.subheadline.weight(.semibold))
                                                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(FrilaCor.primaria)
                                                .accessibilityIdentifier("republicar-vaga-\(vaga.vaga.id)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(FrilaEspaco.medio)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .refreshable { await carregar() }
            .navigationTitle(Text(verbatim: TextosMinhasVagas.titulo))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: RotaDoContratante.self) { rota in
                switch rota {
                case let .vaga(vagaID):
                    DestinoDaVagaDoContratante(viewModel: viewModel, acompanhamento: acompanhamento, vagaID: vagaID, api: api, fila: fila)
                case let .turno(turnoID):
                    TelaTurnoDoContratante(viewModel: acompanhamento, turnoID: turnoID)
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
                        }
                    )
                )
            }
        }
        .modifier(ConfirmacaoDeReabertura(viewModel: acompanhamento))
        .task { await carregar() }
        // O aviso do push diz que algo mudou na casa: o painel é relido para a tela que ele abre.
        .onChange(of: roteador.avisosAbertos) { Task { await carregar() } }
        .accessibilityIdentifier("minhas-vagas")
    }

    private func carregar() async {
        await viewModel.carregar()
        await acompanhamento.carregar()
    }

    private func cartao(_ vaga: VagaNoPainel, secao: SecaoMinhasVagas) -> some View {
        let confirmadas = viewModel.confirmadas(vaga)
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: vaga.vaga.funcao).font(.headline)
                Spacer(minLength: FrilaEspaco.pequeno)
                if secao == .emAlerta {
                    let tempo = String(format: TextosMinhasVagas.alertaComeca, viewModel.tempoAteInicio(vaga))
                    Label { Text(verbatim: tempo) } icon: { Image(systemName: "clock") }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FrilaCor.perigo)
                        .accessibilityIdentifier("tempo-alerta-\(vaga.vaga.id)")
                }
            }
            Text(verbatim: vaga.vaga.local).font(.subheadline)
            Text(verbatim: periodo(vaga.vaga.periodo)).font(.subheadline)
            Text(verbatim: formatador.dinheiro(vaga.vaga.valor)).font(.subheadline.weight(.semibold))
            Text(verbatim: String(format: TextosMinhasVagas.confirmadas, confirmadas, vaga.posicoes.count))
                .font(.subheadline.weight(.semibold))
            if confirmadas > 0 {
                Text(verbatim: nomesConfirmados(vaga)).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
            }
            Text(verbatim: TextosMinhasVagas.verDetalhes)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FrilaCor.primaria)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }

    private func nomesConfirmados(_ vaga: VagaNoPainel) -> String {
        vaga.posicoes.compactMap { posicao in
            guard posicao.estado == .confirmada || posicao.estado == .cumprida else { return nil }
            return posicao.profissional?.nome
        }.joined(separator: ", ")
    }

    private func periodo(_ periodo: Periodo) -> String {
        textoPeriodo(periodo)
    }
}

/// A vaga pelo id, que é o que a lista e o aviso de vaga vazia trazem. Lê o painel do
/// acompanhamento, que já reflete uma confirmação ou reabertura feita agora.
private struct DestinoDaVagaDoContratante: View {
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
                aoRepublicar: {
                    await viewModel.carregar()
                    await acompanhamento.carregar()
                }
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
    let vaga: VagaNoPainel
    let api: any ApiCliente
    let fila: (any FilaDeAcoes)?
    let confirmado: Int
    var aoRepublicar: (@Sendable () async -> Void)? = nil
    @State private var contatos: [UUID: Contato] = [:]
    @State private var carregandoContato: Set<UUID> = []
    @State private var errosContato: [UUID: String] = [:]
    @State private var perfilSelecionado: PerfilPublico?
    @State private var vagaParaRepublicar: VagaNoPainel?
    private let formatador = FormatadorFrila()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: vaga.vaga.funcao).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: vaga.vaga.local)
                    Text(verbatim: periodo(vaga.vaga.periodo))
                    Text(verbatim: formatador.dinheiro(vaga.vaga.valor))
                    Text(verbatim: String(format: TextosMinhasVagas.confirmadas, confirmado, vaga.posicoes.count))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FrilaEspaco.medio)
                .cartaoFrila()

                if vaga.estado == .encerrada || vaga.estado == .cancelada || vaga.vaga.periodo.fim <= Date() {
                    Button {
                        vagaParaRepublicar = vaga
                    } label: {
                        HStack(spacing: FrilaEspaco.pequeno) {
                            Image(systemName: "arrow.clockwise")
                            Text(verbatim: TextosMinhasVagas.republicar)
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FrilaCor.primaria)
                    .accessibilityIdentifier("republicar-detalhe-vaga-\(vaga.vaga.id)")
                }

                Text(verbatim: TextosMinhasVagas.posicoes).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                ForEach(vaga.posicoes) { posicao in
                    cartaoPosicao(posicao)
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
                        }
                    )
                )
            }
        }
        .navigationTitle(Text(verbatim: TextosMinhasVagas.detalheTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $perfilSelecionado) { perfil in
            TelaPerfilPublicoContratante(perfil: perfil)
        }
        .accessibilityIdentifier("detalhe-vaga-contratante")
    }

    @ViewBuilder private func cartaoPosicao(_ posicao: PosicaoNoPainel) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            if posicao.estado == .confirmada || posicao.estado == .cumprida {
                Text(verbatim: posicao.profissional?.nome ?? TextosMinhasVagas.profissionaisConfirmados)
                    .font(.headline)
                if let perfil = posicao.profissional {
                    Button { perfilSelecionado = perfil } label: {
                        Text(verbatim: TextosMinhasVagas.perfil)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityIdentifier("perfil-publico-\(posicao.id)")
                }
                if let turnoID = posicao.turnoID {
                    NavigationLink(value: RotaDoContratante.turno(turnoID: turnoID)) {
                        Text(verbatim: TextosDoAcompanhamento.acompanharTurno)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityIdentifier("acompanhar-turno-\(turnoID)")
                }
                if let contato = contatos[posicao.id], contato.estaVisivel(em: .now), let turnoID = posicao.turnoID {
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                        Text(verbatim: "\(contato.nome) · \(contato.telefone)")
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
                        }
                    }.accessibilityIdentifier("contato-liberado-\(turnoID)")
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
                    .disabled(carregandoContato.contains(posicao.id))
                    .accessibilityIdentifier("ver-contato-\(posicao.id)")
                }
            } else if posicao.estado == .aberta {
                Text(verbatim: TextosMinhasVagas.posicaoAberta).font(.headline)
            } else if posicao.estado == .cancelada, let nome = posicao.profissional?.nome {
                // Cancelada ou reaberta por atraso: a posição guarda de quem era (RN12).
                Text(verbatim: nome).font(.headline)
                Text(verbatim: TextosDoAcompanhamento.cancelada).foregroundStyle(FrilaCor.textoSecundario)
            } else {
                Text(verbatim: TextosMinhasVagas.encerradas).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
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

private struct TelaPerfilPublicoContratante: View {
    let perfil: PerfilPublico

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: perfil.nome).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                if !perfil.funcoes.isEmpty {
                    Text(verbatim: perfil.funcoes.joined(separator: ", "))
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: TextosMinhasVagas.perfilTitulo).font(.headline)
                    SeloReputacao(perfil.reputacao)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FrilaEspaco.medio)
                .cartaoFrila()
                .accessibilityElement(children: .combine)
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text(verbatim: TextosMinhasVagas.perfilTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("perfil-publico-contratante")
    }
}
