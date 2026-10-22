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
    static let explicacaoVagas = String(localized: "Você recebe notificações de vagas da sua função, a até 15 km do seu ponto base, quando o turno inteiro cabe nos horários em que você marcou disponibilidade. Todas as vagas do DF aparecem na lista.", bundle: bundleApresentacao)
    static let ajuda = String(localized: "Ajuda", bundle: bundleApresentacao)
    static let suporte = String(localized: "Fale com o suporte", bundle: bundleApresentacao)
    static let prazoSuporte = String(localized: "Respondemos o mais breve possível, com triagem em até 5 dias úteis.", bundle: bundleApresentacao)
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

/// Linha de lista do MidFi: texto 17 à esquerda e chevron em `textoSecundario` à direita, com 52 pt de altura mínima.
struct RotuloDeLinha: View {
    private let titulo: String

    init(_ titulo: String) {
        self.titulo = titulo
    }

    var body: some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: FrilaEspaco.pequeno)
            Image(systemName: "chevron.right")
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
        }
        .padding(.vertical, FrilaEspaco.minimo)
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Divisória entre as linhas de um grupo.
struct DivisoriaDeLinha: View {
    var body: some View {
        Rectangle()
            .fill(FrilaCor.divisoria)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Cartão único do MidFi com as linhas da conta: superfície branca, raio 20 contínuo, fio de 1 pt e recuo de 16 pt à esquerda.
struct GrupoDeLinhas<Conteudo: View>: View {
    private let conteudo: Conteudo

    init(@ViewBuilder conteudo: () -> Conteudo) {
        self.conteudo = conteudo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            conteudo
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
    }
}

/// Botão de contorno `perigo` do MidFi para "Excluir conta"; o toque abre a tela de exclusão, que pede a confirmação.
struct BotaoDeExclusaoDeConta: View {
    var body: some View {
        Text(verbatim: TextosPerfilConta.excluir).capsulaDestrutiva()
    }
}

/// Perfil do profissional (#18), no quadro "MeuPerfil" do MidFi do Fabrício: dados no cartão, linhas num cartão único com chevron e "Excluir conta" de contorno.
public struct TelaMeuPerfilProfissional: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var despachoModel: PorQueReceboVagasViewModel
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
        _despachoModel = State(initialValue: PorQueReceboVagasViewModel(api: api))
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
                        Text(verbatim: conta.nome)
                            .font(FrilaTipo.secao)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        linha(TextosPerfilConta.telefone, conta.telefone, id: "perfil-telefone", contato: true)
                        linha(TextosPerfilConta.email, conta.email, id: "perfil-email", contato: true)
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                        linha(TextosPerfilConta.funcao, perfil.funcoes.map(\.nome).joined(separator: ", "), id: "perfil-funcoes")
                        linha(TextosPerfilConta.horarios, perfil.disponibilidades.isEmpty ? TextosPerfilConta.naoInformado : String(localized: "\(perfil.disponibilidades.count) horários cadastrados", bundle: bundleApresentacao), id: "perfil-horarios")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartaoFrila()
                    GrupoDeLinhas {
                        NavigationLink { TelaPerfilProfissional(api: api, modo: .edicao) } label: {
                            RotuloDeLinha(TextosPerfilConta.funcoesHorarios)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("perfil-funcoes-horarios")
                        DivisoriaDeLinha()
                        NavigationLink { TelaHistoricoDeTurnos(api: api) } label: {
                            RotuloDeLinha(TextosHistoricoDeTurnos.titulo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("perfil-historico-turnos")
                        DivisoriaDeLinha()
                        Button { mostrarExplicacao = true } label: {
                            RotuloDeLinha(TextosPerfilConta.porQueRecebo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("perfil-por-que-recebo")
                        DivisoriaDeLinha()
                        Button { mostrarAjuda = true } label: {
                            RotuloDeLinha(TextosPerfilConta.ajuda)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("perfil-ajuda")
                        DivisoriaDeLinha()
                        ItemExportarDados(viewModel: exportarModel, identificador: "perfil-exportar-dados")
                        DivisoriaDeLinha()
                        Button(role: .destructive, action: sair) {
                            RotuloDeLinha(TextosPerfilConta.sair)
                        }
                        .buttonStyle(.plain)
                    }
                    excluirConta
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

    @ViewBuilder
    private func linha(_ titulo: String, _ valor: String, id: String, contato: Bool = false) -> some View {
        let rotulo = Text(verbatim: titulo)
            .font(FrilaTipo.meta)
            .foregroundStyle(FrilaCor.texto)
            .accessibilityIdentifier("\(id)-rotulo")
        let conteudo = Text(verbatim: valor.isEmpty ? TextosPerfilConta.naoInformado : valor)
            .font(FrilaTipo.meta)
            .foregroundStyle(FrilaCor.textoSecundario)
            .accessibilityIdentifier("\(id)-valor")
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                rotulo.fixedSize(horizontal: false, vertical: true)
                if contato {
                    // Contatos longos permanecem inteiros, com o fim acessível por rolagem.
                    ScrollView(.horizontal) {
                        conteudo.fixedSize(horizontal: true, vertical: false)
                            .frame(minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(id)-rolagem")
                } else {
                    conteudo.fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        } else {
            LabeledContent { conteudo } label: { rotulo }
                .accessibilityElement(children: .combine)
        }
    }

    /// "Excluir conta" do MidFi: botão de contorno `perigo` num cartão próprio, longe das linhas comuns.
    private var excluirConta: some View {
        NavigationLink {
            TelaExclusaoDeConta(
                viewModel: ExclusaoDeContaViewModel(
                    api: api,
                    aoConcluir: sair
                )
            )
        } label: {
            BotaoDeExclusaoDeConta()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("perfil-excluir-conta")
    }

    /// A folha "Por que recebo vagas" (RF27, #18): texto aprovado, critérios reais e "Contestar".
    private var explicacao: some View {
        NavigationStack {
            TelaPorQueReceboVagas(viewModel: despachoModel)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        mostrarExplicacao = false
                    } label: {
                        Text(verbatim: TextosPerfilConta.fechar)
                    }
                    .accessibilityShowsLargeContentViewer()
                    .accessibilityIdentifier("fechar-explicacao-vagas")
                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                }
            }
        }.presentationDetents([.large])
    }
}

/// Perfil do estabelecimento (#18), nos quadros "ContaContratante" e "Estabelecimento" do MidFi do Fabrício: mesmas linhas agrupadas do perfil do profissional.
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
                        Text(verbatim: estabelecimento.nome)
                            .font(FrilaTipo.secao)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let tipo = estabelecimento.tipo {
                            LabeledContent {
                                Text(verbatim: tipo.descricaoPerfil)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                            } label: {
                                Text(verbatim: TextosPerfilConta.tipo)
                                    .font(FrilaTipo.meta)
                                    .foregroundStyle(FrilaCor.texto)
                            }
                        }
                        LabeledContent {
                            Text(verbatim: estabelecimento.papel.descricaoPerfil)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        } label: {
                            Text(verbatim: TextosPerfilConta.papel)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                        }
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartaoFrila()
                    GrupoDeLinhas {
                        NavigationLink { TelaHistoricoDeTurnos(api: api, estabelecimentoID: estabelecimento.id) } label: {
                            RotuloDeLinha(TextosHistoricoDeTurnos.titulo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("estabelecimento-historico-turnos")
                        DivisoriaDeLinha()
                        NavigationLink { TelaEquipeDeConfianca(api: api, estabelecimentoID: estabelecimento.id) } label: {
                            RotuloDeLinha(TextosEquipeDeConfianca.titulo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("estabelecimento-equipe-de-confianca")
                        DivisoriaDeLinha()
                        Button { mostrarAjuda = true } label: {
                            RotuloDeLinha(TextosPerfilConta.ajuda)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("perfil-ajuda")
                        DivisoriaDeLinha()
                        ItemExportarDados(viewModel: exportarModel, identificador: "estabelecimento-exportar-dados")
                        DivisoriaDeLinha()
                        Button(role: .destructive, action: sair) {
                            RotuloDeLinha(TextosPerfilConta.sair)
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink {
                        TelaExclusaoDeConta(
                            viewModel: ExclusaoDeContaViewModel(
                                api: api,
                                aoConcluir: sair
                            )
                        )
                    } label: {
                        BotaoDeExclusaoDeConta()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("estabelecimento-excluir-conta")
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
                                        .font(FrilaTipo.corpo)
                                        .foregroundStyle(FrilaCor.texto)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Image(systemName: "envelope")
                                        .font(FrilaTipo.nota)
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
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                                .accessibilityIdentifier("perfil-suporte")
                        }

                        Text(verbatim: enderecos.emailSuporte)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                            .contentShape(Rectangle())
                            .textSelection(.enabled)
                            .accessibilityLabel(Text(verbatim: "\(TextosPerfilConta.email): \(enderecos.emailSuporte)"))
                            .accessibilityIdentifier("perfil-suporte-email")

                        Text(verbatim: TextosPerfilConta.prazoSuporte)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Link(destination: enderecos.termosDeUso) {
                    HStack {
                        Text(verbatim: TextosPerfilConta.termos)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityHidden(true)
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
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityHidden(true)
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
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("perfil-licencas")
            }
            .scrollContentBackground(.hidden)
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosPerfilConta.ajuda)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: TextosPerfilConta.fechar)
                    }
                    .accessibilityShowsLargeContentViewer {
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
