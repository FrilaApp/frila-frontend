import FrilaDominio
import Observation
import SwiftUI

private enum TextosPerfilConta {
    static let meuPerfil = String(localized: "Meu perfil", bundle: bundleApresentacao)
    static let perfilEstabelecimento = String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao)
    static let nome = String(localized: "Nome", bundle: bundleApresentacao)
    static let telefone = String(localized: "Telefone", bundle: bundleApresentacao)
    static let email = String(localized: "E-mail", bundle: bundleApresentacao)
    static let funcoesHorarios = String(localized: "Funções e horários", bundle: bundleApresentacao)
    static let porQueRecebo = String(localized: "Por que recebo vagas", bundle: bundleApresentacao)
    static let explicacaoVagas = String(localized: "Você recebe notificação de vagas da sua função, perto de você, nos horários em que marcou disponibilidade. Todas as vagas do DF aparecem na lista.", bundle: bundleApresentacao)
    static let ajuda = String(localized: "Ajuda", bundle: bundleApresentacao)
    static let suporte = String(localized: "Fale com o suporte", bundle: bundleApresentacao)
    static let prazoSuporte = String(localized: "Respondemos em até 5 dias úteis.", bundle: bundleApresentacao)
    static let termos = String(localized: "Termos de uso", bundle: bundleApresentacao)
    static let privacidade = String(localized: "Política de privacidade", bundle: bundleApresentacao)
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
    static let horariosCadastrados = String(localized: "%lld horários cadastrados", bundle: bundleApresentacao)
    static let todoExportacao = String(localized: "Disponível no cartão #219", bundle: bundleApresentacao)
    static let todoExclusao = String(localized: "Disponível no cartão #50", bundle: bundleApresentacao)
    static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
    static let suportePendente = String(localized: "Endereço de suporte pendente", bundle: bundleApresentacao)
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
    private let api: any ApiCliente
    private let sair: () -> Void
    @State private var mostrarExplicacao = false
    @State private var mostrarAjuda = false

    public init(api: any ApiCliente, sair: @escaping () -> Void) {
        self.api = api; self.sair = sair
        _model = State(initialValue: MeuPerfilProfissionalViewModel(api: api))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if model.carregando { EstadoCarregando() }
                else if let erro = model.mensagemErro { EstadoErro(LocalizedStringKey(erro)) { Task { await model.carregar() } } }
                else if let conta = model.conta, let perfil = model.perfil {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text(conta.nome).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        linha(TextosPerfilConta.telefone, conta.telefone)
                        linha(TextosPerfilConta.email, conta.email)
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                        linha(TextosPerfilConta.funcao, perfil.funcoes.map(\.nome).joined(separator: ", "))
                        linha(TextosPerfilConta.horarios, perfil.disponibilidades.isEmpty ? TextosPerfilConta.naoInformado : String(localized: "\(perfil.disponibilidades.count) horários cadastrados", bundle: bundleApresentacao))
                    }.cartaoFrila()
                    NavigationLink { TelaPerfilProfissional(api: api, modo: .edicao) } label: {
                        Label(TextosPerfilConta.funcoesHorarios, systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    }.accessibilityIdentifier("perfil-funcoes-horarios")
                    Button { mostrarExplicacao = true } label: { Label(TextosPerfilConta.porQueRecebo, systemImage: "questionmark.circle") }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    Button { mostrarAjuda = true } label: { Label(TextosPerfilConta.ajuda, systemImage: "lifepreserver") }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    placeholders
                    Button(role: .destructive, action: sair) { Label(TextosPerfilConta.sair, systemImage: "rectangle.portrait.and.arrow.right") }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                }
            }.padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosPerfilConta.meuPerfil)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.carregar() }
        .sheet(isPresented: $mostrarExplicacao) { explicacao }
        .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil() }
    }

    private func linha(_ titulo: String, _ valor: String) -> some View {
        LabeledContent(titulo, value: valor.isEmpty ? TextosPerfilConta.naoInformado : valor)
    }

    private var placeholders: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Button {} label: { Label(TextosPerfilConta.exportar, systemImage: "square.and.arrow.up") }
                .disabled(true).accessibilityHint(TextosPerfilConta.todoExportacao)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
            Button {} label: { Label(TextosPerfilConta.excluir, systemImage: "person.crop.circle.badge.xmark") }
                .disabled(true).accessibilityHint(TextosPerfilConta.todoExclusao)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
        }
    }

    private var explicacao: some View {
        NavigationStack { ScrollView { Text(TextosPerfilConta.explicacaoVagas).frame(maxWidth: .infinity, alignment: .leading).padding() }
            .navigationTitle(TextosPerfilConta.porQueRecebo).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(TextosPerfilConta.fechar) { mostrarExplicacao = false }.frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo) } }
        }.presentationDetents([.medium, .large])
    }
}

public struct TelaPerfilEstabelecimento: View {
    @State private var model: PerfilEstabelecimentoViewModel
    private let sair: () -> Void
    @State private var mostrarAjuda = false
    public init(api: any ApiCliente, sair: @escaping () -> Void) {
        self.sair = sair; _model = State(initialValue: PerfilEstabelecimentoViewModel(api: api))
    }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if model.carregando { EstadoCarregando() }
                else if let erro = model.mensagemErro { EstadoErro(LocalizedStringKey(erro)) { Task { await model.carregar() } } }
                else if let estabelecimento = model.estabelecimento {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text(estabelecimento.nome).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        if let tipo = estabelecimento.tipo { LabeledContent(TextosPerfilConta.tipo, value: tipo.descricaoPerfil) }
                        LabeledContent(TextosPerfilConta.papel, value: estabelecimento.papel.descricaoPerfil)
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                    }.cartaoFrila()
                    Button { mostrarAjuda = true } label: { Label(TextosPerfilConta.ajuda, systemImage: "lifepreserver") }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    Button {} label: { Label(TextosPerfilConta.exportar, systemImage: "square.and.arrow.up") }
                        .disabled(true).accessibilityHint(TextosPerfilConta.todoExportacao).frame(minHeight: FrilaMetrica.alvoMinimo)
                    Button {} label: { Label(TextosPerfilConta.excluir, systemImage: "person.crop.circle.badge.xmark") }
                        .disabled(true).accessibilityHint(TextosPerfilConta.todoExclusao).frame(minHeight: FrilaMetrica.alvoMinimo)
                    Button(role: .destructive, action: sair) { Label(TextosPerfilConta.sair, systemImage: "rectangle.portrait.and.arrow.right") }
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                } else { ContentUnavailableView(TextosPerfilConta.vazio, systemImage: "building.2") }
            }.padding(FrilaEspaco.medio)
        }.background(FrilaCor.fundo).navigationTitle(TextosPerfilConta.perfilEstabelecimento)
            .navigationBarTitleDisplayMode(.inline).task { await model.carregar() }
            .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil() }
    }
}

private struct TelaAjudaPerfil: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                // TODO: inserir o endereço oficial de suporte quando o produto publicar o canal.
                LabeledContent(TextosPerfilConta.suporte, value: TextosPerfilConta.suportePendente)
                Text(TextosPerfilConta.prazoSuporte)
                // TODO: ligar às páginas oficiais de termos e privacidade.
                LabeledContent(TextosPerfilConta.termos, value: TextosPerfilConta.linkPendente)
                LabeledContent(TextosPerfilConta.privacidade, value: TextosPerfilConta.linkPendente)
            }.navigationTitle(TextosPerfilConta.ajuda).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(TextosPerfilConta.fechar) { dismiss() }.frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo) } }
        }.presentationDetents([.medium, .large])
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
