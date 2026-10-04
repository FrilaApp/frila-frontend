import FrilaDominio
import Observation
import SwiftUI

enum TextosPerfilConta {
    static let meuPerfil = String(localized: "Meu perfil", bundle: bundleApresentacao)
    static let perfilEstabelecimento = String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao)
    static let nome = String(localized: "Nome", bundle: bundleApresentacao)
    static let telefone = String(localized: "Telefone", bundle: bundleApresentacao)
    static let email = String(localized: "E-mail", bundle: bundleApresentacao)
    static let funcoesHorarios = String(localized: "Funções e horários", bundle: bundleApresentacao)
    static let porQueRecebo = String(localized: "Por que recebo vagas", bundle: bundleApresentacao)
    static let explicacaoVagas = String(localized: "Você recebe notificação de vagas da sua função, perto de você, quando o turno inteiro cabe nos horários em que marcou disponibilidade. Todas as vagas do DF aparecem na lista.", bundle: bundleApresentacao)
    static let ajuda = String(localized: "Ajuda", bundle: bundleApresentacao)
    static let suporte = String(localized: "Fale com o suporte", bundle: bundleApresentacao)
    static let prazoSuporte = String(localized: "Respondemos em até 5 dias úteis.", bundle: bundleApresentacao)
    static let termos = String(localized: "Termos de uso", bundle: bundleApresentacao)
    static let privacidade = String(localized: "Política de privacidade", bundle: bundleApresentacao)
    static let licencas = String(localized: "Licenças de terceiros", bundle: bundleApresentacao)
    static let exportar = String(localized: "Exportar meus dados", bundle: bundleApresentacao)
    static let excluir = String(localized: "Excluir conta", bundle: bundleApresentacao)
    static let sair = String(localized: "Sair", bundle: bundleApresentacao)
    static let erro = String(localized: "Não foi possível carregar o perfil.", bundle: bundleApresentacao)
    static let vazio = String(localized: "Nenhum estabelecimento disponível.", bundle: bundleApresentacao)
    static let funcao = String(localized: "Funções", bundle: bundleApresentacao)
    static let horarios = String(localized: "Horários disponíveis", bundle: bundleApresentacao)
    static let tipo = String(localized: "Tipo", bundle: bundleApresentacao)
    static let papel = String(localized: "Seu acesso", bundle: bundleApresentacao)
    static let naoInformado = String(localized: "—", bundle: bundleApresentacao)
    static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
    static let dicaSuporte = String(localized: "Abre o e-mail para enviar mensagem ao suporte", bundle: bundleApresentacao)
    static let linkPendente = String(localized: "Link pendente", bundle: bundleApresentacao)
}

@MainActor @Observable
public final class MeuPerfilProfissionalViewModel {
    public private(set) var conta: Conta?
    public private(set) var perfil: PerfilProfissional?
    public private(set) var perfilPublico: PerfilPublico?
    public private(set) var carregando = false
    public private(set) var mensagemErro: String?
    private let carregarConta: @Sendable () async throws -> Conta
    private let carregarPerfil: @Sendable () async throws -> PerfilProfissional
    private let carregarPublico: @Sendable (UUID) async throws -> PerfilPublico

    public init(api: any ApiCliente) {
        carregarConta = { try await api.minhaConta() }
        carregarPerfil = { try await api.meuPerfilProfissional() }
        carregarPublico = { try await api.perfilPublico(id: $0) }
    }

    public init(conta: @escaping @Sendable () async throws -> Conta,
                perfil: @escaping @Sendable () async throws -> PerfilProfissional,
                publico: @escaping @Sendable (UUID) async throws -> PerfilPublico) {
        carregarConta = conta; carregarPerfil = perfil; carregarPublico = publico
    }

    public func carregar() async {
        carregando = true
        mensagemErro = nil
        defer { carregando = false }
        do {
            let contaNova = try await carregarConta()
            let perfilNovo = try await carregarPerfil()
            let publicoNovo = try await carregarPublico(perfilNovo.id)
            conta = contaNova; perfil = perfilNovo; perfilPublico = publicoNovo
        } catch { mensagemErro = TextosPerfilConta.erro }
    }
}

@MainActor @Observable
public final class PerfilEstabelecimentoViewModel {
    public private(set) var estabelecimento: EstabelecimentoDaConta?
    public private(set) var perfilPublico: PerfilPublico?
    public private(set) var carregando = false
    public private(set) var mensagemErro: String?
    private let carregarEstabelecimentos: @Sendable () async throws -> [EstabelecimentoDaConta]
    private let carregarPublico: @Sendable (UUID) async throws -> PerfilPublico

    public init(api: any ApiCliente) {
        carregarEstabelecimentos = { try await api.meusEstabelecimentos() }
        carregarPublico = { try await api.perfilPublico(id: $0) }
    }

    public init(estabelecimentos: @escaping @Sendable () async throws -> [EstabelecimentoDaConta],
                publico: @escaping @Sendable (UUID) async throws -> PerfilPublico) {
        carregarEstabelecimentos = estabelecimentos; carregarPublico = publico
    }

    public func carregar() async {
        carregando = true; mensagemErro = nil
        defer { carregando = false }
        do {
            guard let primeiro = try await carregarEstabelecimentos().first else { return }
            let publico = try await carregarPublico(primeiro.id)
            estabelecimento = primeiro; perfilPublico = publico
        } catch { mensagemErro = TextosPerfilConta.erro }
    }
}

public struct TelaMeuPerfilProfissional: View {
    @State private var model: MeuPerfilProfissionalViewModel
    @State private var exportarModel: ExportarDadosViewModel
    private let api: any ApiCliente
    private let sair: () -> Void
    public let enderecos: EnderecosOficiais
    @State private var mostrarExplicacao = false
    @State private var mostrarAjuda = false

    public init(api: any ApiCliente, enderecos: EnderecosOficiais = .padrao, sair: @escaping () -> Void) {
        self.api = api
        self.enderecos = enderecos
        self.sair = sair
        _model = State(initialValue: MeuPerfilProfissionalViewModel(api: api))
        _exportarModel = State(initialValue: ExportarDadosViewModel(api: api))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if model.carregando { EstadoCarregando() }
                else if let erro = model.mensagemErro { EstadoErro(verbatim: erro) { Task { await model.carregar() } } }
                else if let conta = model.conta, let perfil = model.perfil {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text(verbatim: conta.nome).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        linha(TextosPerfilConta.telefone, conta.telefone)
                        linha(TextosPerfilConta.email, conta.email)
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                        linha(TextosPerfilConta.funcao, perfil.funcoes.map(\.nome).joined(separator: ", "))
                        linha(TextosPerfilConta.horarios, perfil.disponibilidades.isEmpty ? TextosPerfilConta.naoInformado : String(localized: "\(perfil.disponibilidades.count) horários cadastrados", bundle: bundleApresentacao))
                    }.cartaoFrila()
                    NavigationLink { TelaPerfilProfissional(api: api, modo: .edicao) } label: {
                        Label {
                            Text(verbatim: TextosPerfilConta.funcoesHorarios)
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    }.accessibilityIdentifier("perfil-funcoes-horarios")
                    NavigationLink { TelaHistoricoDeTurnos(api: api) } label: {
                        Label {
                            Text(verbatim: TextosHistoricoDeTurnos.titulo)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    }.accessibilityIdentifier("perfil-historico-turnos")
                    Button { mostrarExplicacao = true } label: {
                        Label {
                            Text(verbatim: TextosPerfilConta.porQueRecebo)
                        } icon: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                    .accessibilityIdentifier("perfil-por-que-recebo")
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    Button { mostrarAjuda = true } label: {
                        Label {
                            Text(verbatim: TextosPerfilConta.ajuda)
                        } icon: {
                            Image(systemName: "lifepreserver")
                        }
                    }
                    .accessibilityIdentifier("perfil-ajuda")
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    placeholders
                    Button(role: .destructive, action: sair) {
                        Label {
                            Text(verbatim: TextosPerfilConta.sair)
                        } icon: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                }
            }.padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.meuPerfil))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.carregar() }
        .sheet(isPresented: $mostrarExplicacao) { explicacao }
        .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil(enderecos: enderecos) }
    }

    private func linha(_ titulo: String, _ valor: String) -> some View {
        LabeledContent {
            Text(verbatim: valor.isEmpty ? TextosPerfilConta.naoInformado : valor)
        } label: {
            Text(verbatim: titulo)
        }
    }

    private var placeholders: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            ItemExportarDados(viewModel: exportarModel, identificador: "perfil-exportar-dados")
            NavigationLink {
                TelaExclusaoDeConta(
                    viewModel: ExclusaoDeContaViewModel(
                        api: api,
                        aoConcluir: sair
                    )
                )
            } label: {
                Label {
                    Text(verbatim: TextosPerfilConta.excluir)
                } icon: {
                    Image(systemName: "person.crop.circle.badge.xmark")
                }
            }
            .accessibilityIdentifier("perfil-excluir-conta")
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
        }
    }

    private var explicacao: some View {
        NavigationStack {
            ScrollView {
                Text(verbatim: TextosPerfilConta.explicacaoVagas)
                    .accessibilityIdentifier("perfil-explicacao-vagas")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(Text(verbatim: TextosPerfilConta.porQueRecebo)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        mostrarExplicacao = false
                    } label: {
                        Text(verbatim: TextosPerfilConta.fechar)
                    }
                    .accessibilityIdentifier("fechar-explicacao-vagas")
                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                }
            }
        }.presentationDetents([.medium, .large])
    }
}

public struct TelaPerfilEstabelecimento: View {
    @State private var model: PerfilEstabelecimentoViewModel
    @State private var exportarModel: ExportarDadosViewModel
    private let api: any ApiCliente
    private let sair: () -> Void
    public let enderecos: EnderecosOficiais
    @State private var mostrarAjuda = false
    public init(api: any ApiCliente, enderecos: EnderecosOficiais = .padrao, sair: @escaping () -> Void) {
        self.api = api
        self.sair = sair
        self.enderecos = enderecos
        _model = State(initialValue: PerfilEstabelecimentoViewModel(api: api))
        _exportarModel = State(initialValue: ExportarDadosViewModel(api: api))
    }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if model.carregando { EstadoCarregando() }
                else if let erro = model.mensagemErro { EstadoErro(verbatim: erro) { Task { await model.carregar() } } }
                else if let estabelecimento = model.estabelecimento {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text(verbatim: estabelecimento.nome).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        if let tipo = estabelecimento.tipo {
                            LabeledContent {
                                Text(verbatim: tipo.descricaoPerfil)
                            } label: {
                                Text(verbatim: TextosPerfilConta.tipo)
                            }
                        }
                        LabeledContent {
                            Text(verbatim: estabelecimento.papel.descricaoPerfil)
                        } label: {
                            Text(verbatim: TextosPerfilConta.papel)
                        }
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                    }.cartaoFrila()
                    NavigationLink { TelaHistoricoDeTurnos(api: api, estabelecimentoID: estabelecimento.id) } label: {
                        Label {
                            Text(verbatim: TextosHistoricoDeTurnos.titulo)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    }
                    .accessibilityIdentifier("estabelecimento-historico-turnos")
                    Button { mostrarAjuda = true } label: {
                        Label {
                            Text(verbatim: TextosPerfilConta.ajuda)
                        } icon: {
                            Image(systemName: "lifepreserver")
                        }
                    }
                    .accessibilityIdentifier("perfil-ajuda")
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    ItemExportarDados(viewModel: exportarModel, identificador: "estabelecimento-exportar-dados")
                    NavigationLink {
                        TelaExclusaoDeConta(
                            viewModel: ExclusaoDeContaViewModel(
                                api: api,
                                aoConcluir: sair
                            )
                        )
                    } label: {
                        Label {
                            Text(verbatim: TextosPerfilConta.excluir)
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.xmark")
                        }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    }
                    .accessibilityIdentifier("estabelecimento-excluir-conta")
                    Button(role: .destructive, action: sair) {
                        Label {
                            Text(verbatim: TextosPerfilConta.sair)
                        } icon: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                } else {
                    ContentUnavailableView {
                        Label {
                            Text(verbatim: TextosPerfilConta.vazio)
                        } icon: {
                            Image(systemName: "building.2")
                        }
                    }
                }
            }.padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.perfilEstabelecimento))
        .navigationBarTitleDisplayMode(.inline).task { await model.carregar() }
        .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil(enderecos: enderecos) }
    }
}

struct TelaAjudaPerfil: View {
    @Environment(\.dismiss) private var dismiss
    let enderecos: EnderecosOficiais

    init(enderecos: EnderecosOficiais = .padrao) {
        self.enderecos = enderecos
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        if let url = enderecos.urlSuporte {
                            Link(destination: url) {
                                HStack {
                                    Text(verbatim: TextosPerfilConta.suporte)
                                        .foregroundStyle(FrilaCor.texto)
                                    Spacer()
                                    Image(systemName: "envelope")
                                        .font(.footnote)
                                        .foregroundStyle(FrilaCor.textoSecundario)
                                }
                                .frame(minHeight: FrilaMetrica.alvoMinimo)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel(Text(verbatim: TextosPerfilConta.suporte))
                            .accessibilityHint(Text(verbatim: TextosPerfilConta.dicaSuporte))
                            .accessibilityAddTraits(.isLink)
                            .accessibilityIdentifier("perfil-suporte")
                        } else {
                            Text(verbatim: TextosPerfilConta.suporte)
                                .frame(minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                                .accessibilityIdentifier("perfil-suporte")
                        }

                        Text(verbatim: enderecos.emailSuporte)
                            .font(.footnote)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("perfil-suporte-email")

                        Text(verbatim: TextosPerfilConta.prazoSuporte)
                            .font(.footnote)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                }

                Link(destination: enderecos.termosDeUso) {
                    HStack {
                        Text(verbatim: TextosPerfilConta.termos)
                            .foregroundStyle(FrilaCor.texto)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(verbatim: TextosPerfilConta.termos))
                .accessibilityAddTraits(.isLink)
                .accessibilityIdentifier("perfil-termos")

                Link(destination: enderecos.politicaDePrivacidade) {
                    HStack {
                        Text(verbatim: TextosPerfilConta.privacidade)
                            .foregroundStyle(FrilaCor.texto)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(verbatim: TextosPerfilConta.privacidade))
                .accessibilityAddTraits(.isLink)
                .accessibilityIdentifier("perfil-privacidade")

                NavigationLink {
                    TelaLicencas()
                } label: {
                    Text(verbatim: TextosPerfilConta.licencas)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("perfil-licencas")
            }
            .navigationTitle(Text(verbatim: TextosPerfilConta.ajuda)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: TextosPerfilConta.fechar)
                    }
                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                }
            }
        }.presentationDetents([.large])
    }
}

private extension TipoEstabelecimento {
    var descricaoPerfil: String {
        switch self {
        case .foodService: String(localized: "Restaurante ou bar", bundle: bundleApresentacao)
        case .evento: String(localized: "Evento", bundle: bundleApresentacao)
        case .varejo: String(localized: "Varejo", bundle: bundleApresentacao)
        case .logistica: String(localized: "Logística", bundle: bundleApresentacao)
        case .servicoDomestico: String(localized: "Serviço doméstico", bundle: bundleApresentacao)
        case .outro: String(localized: "Outro", bundle: bundleApresentacao)
        }
    }
}

private extension PapelMembro {
    var descricaoPerfil: String {
        switch self {
        case .administrador: String(localized: "Administrador", bundle: bundleApresentacao)
        case .operador: String(localized: "Operador", bundle: bundleApresentacao)
        }
    }
}
