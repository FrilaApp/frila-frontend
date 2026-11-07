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
    static let copiar = String(localized: "Copiar", bundle: bundleApresentacao)
    static let editar = String(localized: "Editar", bundle: bundleApresentacao)
    static let copiado = String(localized: "Copiado", bundle: bundleApresentacao)
    static let contaEDados = String(localized: "Conta e dados", bundle: bundleApresentacao)
    static let sairOuExcluir = String(localized: "Sair ou excluir conta", bundle: bundleApresentacao)
    static let explicacaoSair = String(localized: "Encerra a sessão neste aparelho. Você pode entrar de novo quando quiser.", bundle: bundleApresentacao)
    static let explicacaoExcluir = String(localized: "Encerra a conta de forma permanente e não dá para desfazer. Antes de confirmar, você vê o que acontece com seus dados e turnos.", bundle: bundleApresentacao)
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
    private let gravarContato: (@Sendable (AlteracaoDeContato) async throws -> Conta)?

    /// Só há edição de contato quando o cliente a atende; senão a interface nem a oferece.
    public var podeEditarContato: Bool { gravarContato != nil }

    public init(api: any ApiCliente) {
        carregarConta = { try await api.minhaConta() }
        carregarPerfil = { try await api.meuPerfilProfissional() }
        carregarPublico = { try await api.perfilPublico(id: $0) }
        if api.suportaEdicaoDeContato {
            gravarContato = { alteracao in try await api.atualizarContato(alteracao) }
        } else {
            gravarContato = nil
        }
    }

    public init(conta: @escaping @Sendable () async throws -> Conta,
                perfil: @escaping @Sendable () async throws -> PerfilProfissional,
                publico: @escaping @Sendable (UUID) async throws -> PerfilPublico,
                gravarContato: (@Sendable (AlteracaoDeContato) async throws -> Conta)? = nil) {
        carregarConta = conta; carregarPerfil = perfil; carregarPublico = publico
        self.gravarContato = gravarContato
    }

    /// Grava e só então troca a conta mostrada. Falhou: a conta segue como estava, sem estado de erro.
    @discardableResult
    public func atualizarContato(_ alteracao: AlteracaoDeContato) async -> Bool {
        guard let gravarContato else { return false }
        do {
            conta = try await gravarContato(alteracao)
            return true
        } catch { return false }
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

    public var body: some View {
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
    public var body: some View {
        Rectangle()
            .fill(FrilaCor.divisoria)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Lista aberta do Hi-Fi, delimitada por fios e sem cartões aninhados.
struct GrupoDeLinhas<Conteudo: View>: View {
    private let conteudo: Conteudo

    init(@ViewBuilder conteudo: () -> Conteudo) {
        self.conteudo = conteudo()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DivisoriaDeLinha()
            conteudo
            DivisoriaDeLinha()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Contorno destrutivo para "Excluir conta"; o toque abre a tela de confirmação.
struct BotaoDeExclusaoDeConta: View {
    public var body: some View {
        Text(verbatim: TextosPerfilConta.excluir).capsulaDestrutiva()
    }
}

/// Superfície única de um grupo da Conta: fundo de superfície, raio de cartão e fio de contorno, sem sombra.
/// As linhas de dentro seguem independentes; o container não é um botão.
private struct ContainerDaConta<Conteudo: View>: View {
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
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
    }
}

/// Perfil do profissional (#18), com cabeçalho editorial e lista aberta do Hi-Fi.
public struct TelaMeuPerfilProfissional: View {
    @State private var despachoModel: PorQueReceboVagasViewModel
    @State private var model: MeuPerfilProfissionalViewModel
    @State private var exportarModel: ExportarDadosViewModel
    private let api: any ApiCliente
    private let sair: () -> Void
    public let enderecos: EnderecosOficiais
    @State private var mostrarExplicacao = false
    @State private var mostrarAjuda = false
    @State private var copiaDeContato = CopiaDeContato()
    @State private var edicao = EdicaoDeContato()

    public init(api: any ApiCliente, enderecos: EnderecosOficiais = .padrao, sair: @escaping () -> Void) {
        self.api = api
        self.enderecos = enderecos
        self.sair = sair
        _despachoModel = State(initialValue: PorQueReceboVagasViewModel(api: api))
        _model = State(initialValue: MeuPerfilProfissionalViewModel(api: api))
        _exportarModel = State(initialValue: ExportarDadosViewModel(api: api))
    }

    public var body: some View {
        conteudoDaTela
    }

    private var perfilCarregado: Bool {
        !model.carregando && model.mensagemErro == nil && model.conta != nil && model.perfil != nil
    }

    private var conteudoDaTela: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                if model.carregando {
                    EstadoCarregando()
                } else if let erro = model.mensagemErro {
                    EstadoErro(verbatim: erro) { Task { await model.carregar() } }
                } else if let conta = model.conta, let perfil = model.perfil {
                    identidade(conta)
                    historico
                    configuracao(perfil)
                }

                Button { mostrarAjuda = true } label: {
                    RotuloDeLinha(TextosPerfilConta.ajuda)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("perfil-ajuda")

                LinhaDeAparencia()

                contaEDados

                #if FRILA_BETA
                SeloBeta()
                #endif
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.medio)
            .padding(.bottom, FrilaEspaco.grande)
        }
        .background(FrilaCor.fundo)
        .frilaKeyboardDismissScope()
        .navigationTitle(Text(verbatim: TextosPerfilConta.meuPerfil))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.carregar() }
        .sheet(isPresented: $mostrarExplicacao) { explicacao }
        .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil(enderecos: enderecos) }
        .sensoryFeedback(.success, trigger: copiaDeContato.copias)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.35), trigger: copiaDeContato.aberturas)
        .onDisappear {
            copiaDeContato.limpar()
            edicao.cancelar()
        }
    }

    private func contato(_ titulo: String, _ valor: String, id: String, campo: CampoDeContato) -> some View {
        ContatoCopiavel(
            titulo: titulo, valor: valor, id: id, campo: campo, copia: copiaDeContato,
            acoes: model.podeEditarContato ? [.copiar, .editar] : [.copiar],
            edicao: edicao,
            aoAcionar: { acao in
                if acao == .editar { edicao.iniciar(campo, valor: valor) }
            },
            aoConfirmarEdicao: confirmarEdicao
        )
    }

    /// Return confirma. Valor inválido não faz nada e segue editando; igual ao atual só fecha; novo grava.
    private func confirmarEdicao() {
        guard let campo = edicao.campo, !edicao.salvando, let conta = model.conta,
              let novo = EdicaoDeContato.normalizar(campo, edicao.rascunho) else { return }
        guard novo != (campo == .telefone ? conta.telefone : conta.email) else { return edicao.encerrar() }
        edicao.comecarASalvar()
        Task {
            await model.atualizarContato(AlteracaoDeContato(
                telefone: campo == .telefone ? novo : nil,
                email: campo == .email ? novo : nil
            ))
            edicao.encerrar()
        }
    }

    /// Seção que reúne dados e conta. Sair e Excluir conta ficam um passo adiante, de propósito: ações
    /// irreversíveis não devem ser acionadas por exploração na raiz da Conta.
    private var contaEDados: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPerfilConta.contaEDados)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            ContainerDaConta {
                if perfilCarregado {
                    ItemExportarDados(viewModel: exportarModel, identificador: "perfil-exportar-dados")
                    DivisoriaDeLinha()
                }
                NavigationLink {
                    TelaSairOuExcluirConta(api: api, sair: sair)
                } label: {
                    RotuloDeLinha(TextosPerfilConta.sairOuExcluir)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("perfil-sair-ou-excluir")
            }
        }
    }

    private func identidade(_ conta: Conta) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: conta.nome)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // Áreas de toque encostadas: nenhuma faixa morta entre os dois contatos.
            VStack(alignment: .leading, spacing: 0) {
                contato(TextosPerfilConta.telefone, conta.telefone, id: "perfil-telefone", campo: .telefone)
                contato(TextosPerfilConta.email, conta.email, id: "perfil-email", campo: .email)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historico: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Seu histórico", bundle: bundleApresentacao)
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            ContainerDaConta {
                if let reputacao = model.perfilPublico?.reputacao {
                    SeloReputacao(reputacao)
                        .padding(.vertical, FrilaEspaco.medio)
                    DivisoriaDeLinha()
                }
                NavigationLink { TelaHistoricoDeTurnos(api: api) } label: {
                    RotuloDeLinha(TextosHistoricoDeTurnos.titulo)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("perfil-historico-turnos")
            }
        }
    }

    private func configuracao(_ perfil: PerfilProfissional) -> some View {
        ContainerDaConta {
            NavigationLink { TelaPerfilProfissional(api: api, modo: .edicao) } label: {
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    HStack(spacing: FrilaEspaco.pequeno) {
                        Text(verbatim: TextosPerfilConta.funcoesHorarios)
                            .font(FrilaTipo.tituloDoCartao)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: FrilaEspaco.pequeno)
                        Image(systemName: "chevron.right")
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                        let funcoes = perfil.funcoes.map(\.nome).joined(separator: ", ")
                        Text(verbatim: funcoes.isEmpty ? TextosPerfilConta.naoInformado : funcoes)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .accessibilityIdentifier("perfil-funcoes-valor")
                        Text(verbatim: perfil.disponibilidades.isEmpty
                             ? TextosPerfilConta.naoInformado
                             : String(localized: "\(perfil.disponibilidades.count) horários cadastrados", bundle: bundleApresentacao))
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityIdentifier("perfil-horarios-valor")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, FrilaEspaco.medio)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("perfil-funcoes-horarios")

            DivisoriaDeLinha()

            NavigationLink {
                TelaApresentacaoERegioes(api: api)
            } label: {
                RotuloDeLinha(TextosApresentacaoERegioes.titulo)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("perfil-apresentacao-regioes")

            DivisoriaDeLinha()

            Button { mostrarExplicacao = true } label: {
                RotuloDeLinha(TextosPerfilConta.porQueRecebo)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("perfil-por-que-recebo")
        }
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

/// Passo adicional entre a Conta e as ações irreversíveis. Cada ação diz o que faz antes do toque;
/// a confirmação de saída e o fluxo de exclusão seguem como estavam.
struct TelaSairOuExcluirConta: View {
    @State private var mostrarConfirmacaoDeSaida = false
    private let api: any ApiCliente
    private let sair: () -> Void

    init(api: any ApiCliente, sair: @escaping () -> Void) {
        self.api = api
        self.sair = sair
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.enorme) {
                VStack(alignment: .leading, spacing: 0) {
                    Button { mostrarConfirmacaoDeSaida = true } label: {
                        RotuloDeLinha(TextosPerfilConta.sair)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("perfil-sair")
                    Text(verbatim: TextosPerfilConta.explicacaoSair)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 0) {
                    NavigationLink {
                        TelaExclusaoDeConta(
                            viewModel: ExclusaoDeContaViewModel(api: api, aoConcluir: sair)
                        )
                    } label: {
                        HStack(spacing: FrilaEspaco.pequeno) {
                            Text(verbatim: TextosPerfilConta.excluir)
                                .font(FrilaTipo.corpo)
                            Spacer(minLength: FrilaEspaco.pequeno)
                            Image(systemName: "chevron.right")
                                .font(FrilaTipo.meta.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(FrilaCor.perigo)
                        .padding(.vertical, FrilaEspaco.minimo)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("perfil-excluir-conta")
                    Text(verbatim: TextosPerfilConta.explicacaoExcluir)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.medio)
            .padding(.bottom, FrilaEspaco.grande)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.sairOuExcluir))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $mostrarConfirmacaoDeSaida) { confirmacaoDeSaida }
    }

    /// Mesmo padrão da exclusão de conta: título rolável e ações fixas, Cancelar primeiro.
    private var confirmacaoDeSaida: some View {
        ScrollView {
            Text("Sair da conta?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FrilaEspaco.medio)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FrilaEspaco.pequeno) {
                BotaoSecundario(verbatim: String(localized: "Cancelar", bundle: bundleApresentacao)) {
                    mostrarConfirmacaoDeSaida = false
                }
                .accessibilityIdentifier("botao-cancelar-saida-dialogo")
                Button(role: .destructive) {
                    mostrarConfirmacaoDeSaida = false
                    sair()
                } label: {
                    Text("Sair", bundle: bundleApresentacao)
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, FrilaEspaco.pequeno)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .background(FrilaCor.perigo, in: Capsule())
                .accessibilityIdentifier("botao-confirmar-saida-dialogo")
            }
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}
/// Perfil do estabelecimento (#18), com a mesma lista aberta do perfil do profissional.
public struct TelaPerfilEstabelecimento: View {
    @State private var mostrarConfirmacaoDeSaida = false
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
        conteudoDaTela
            .sheet(isPresented: $mostrarConfirmacaoDeSaida) { confirmacaoDeSaida }
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
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
                        GrupoDeLinhas {
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
                                .padding(.vertical, FrilaEspaco.pequeno)
                                DivisoriaDeLinha()
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
                            .padding(.vertical, FrilaEspaco.pequeno)
                        }
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, FrilaEspaco.medio)
                } else {
                    ContentUnavailableView {
                        Label {
                            Text(verbatim: TextosPerfilConta.vazio)
                        } icon: {
                            Image(systemName: "building.2")
                        }
                    }
                }
                GrupoDeLinhas {
                    if !model.carregando, model.mensagemErro == nil, let estabelecimento = model.estabelecimento {
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
                    }
                    LinhaDeAparencia()
                    DivisoriaDeLinha()
                    Button(role: .destructive) { mostrarConfirmacaoDeSaida = true } label: {
                        RotuloDeLinha(TextosPerfilConta.sair)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("estabelecimento-sair")
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

                #if FRILA_BETA
                SeloBeta()
                #endif
            }.padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.perfilEstabelecimento))
        .navigationBarTitleDisplayMode(.inline).task { await model.carregar() }
        .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil(enderecos: enderecos) }
    }

    /// Mesmo padrão da exclusão de conta: título rolável e ações fixas, Cancelar primeiro.
    private var confirmacaoDeSaida: some View {
        ScrollView {
            Text("Sair da conta?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FrilaEspaco.medio)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FrilaEspaco.pequeno) {
                BotaoSecundario(verbatim: String(localized: "Cancelar", bundle: bundleApresentacao)) {
                    mostrarConfirmacaoDeSaida = false
                }
                .accessibilityIdentifier("botao-cancelar-saida-dialogo")
                Button(role: .destructive) {
                    mostrarConfirmacaoDeSaida = false
                    sair()
                } label: {
                    Text("Sair", bundle: bundleApresentacao)
                        .font(FrilaTipo.botao)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, FrilaEspaco.pequeno)
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .background(FrilaCor.perigo, in: Capsule())
                .accessibilityIdentifier("botao-confirmar-saida-dialogo")
            }
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}


public struct TelaAjudaPerfil: View {
    @Environment(\.dismiss) private var dismiss
    public let enderecos: EnderecosOficiais

    public init(enderecos: EnderecosOficiais = .padrao) {
        self.enderecos = enderecos
    }

    public var body: some View {
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
            .listStyle(.plain)
            .listRowBackground(FrilaCor.fundo)
            .listRowSeparatorTint(FrilaCor.divisoria)
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
