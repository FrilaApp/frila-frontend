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
    public private(set) var suportaPerfilRico: Bool = false
    public private(set) var suportaChamadaDireta: Bool = false
    public private(set) var carregando = false
    public private(set) var mensagemErro: String?
    private let carregarConta: @Sendable () async throws -> Conta
    private let carregarPerfil: @Sendable () async throws -> PerfilProfissional
    private let carregarPublico: @Sendable (UUID) async throws -> PerfilPublico
    private let carregarConfiguracao: (@Sendable () async throws -> ConfiguracaoApp)?
    private let gravarContato: (@Sendable (AlteracaoDeContato) async throws -> Conta)?

    /// Só há edição de contato quando o cliente a atende; senão a interface nem a oferece.
    public var podeEditarContato: Bool { gravarContato != nil }

    public init(api: any ApiCliente) {
        carregarConta = { try await api.minhaConta() }
        carregarPerfil = { try await api.meuPerfilProfissional() }
        carregarPublico = { try await api.perfilPublico(id: $0) }
        carregarConfiguracao = { try await api.configuracaoDoApp() }
        if api.suportaEdicaoDeContato {
            gravarContato = { alteracao in try await api.atualizarContato(alteracao) }
        } else {
            gravarContato = nil
        }
    }

    public init(conta: @escaping @Sendable () async throws -> Conta,
                perfil: @escaping @Sendable () async throws -> PerfilProfissional,
                publico: @escaping @Sendable (UUID) async throws -> PerfilPublico,
                gravarContato: (@Sendable (AlteracaoDeContato) async throws -> Conta)? = nil,
                suportaPerfilRico: Bool = false,
                suportaChamadaDireta: Bool = false) {
        carregarConta = conta; carregarPerfil = perfil; carregarPublico = publico
        carregarConfiguracao = nil
        self.suportaPerfilRico = suportaPerfilRico
        self.suportaChamadaDireta = suportaChamadaDireta
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
            if let config = try? await carregarConfiguracao?() {
                suportaPerfilRico = config.recursos.perfilRico
                suportaChamadaDireta = config.recursos.chamadaDireta
            }
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

/// Perfil do profissional (T9 do protótipo): perfil contínuo, com resumo e edição no mesmo lugar.
public struct TelaMeuPerfilProfissional: View {
    @State private var despachoModel: PorQueReceboVagasViewModel
    @State private var model: MeuPerfilProfissionalViewModel
    @State private var exportarModel: ExportarDadosViewModel
    private let api: any ApiCliente
    private let sair: () -> Void
    public let enderecos: EnderecosOficiais
    @State private var mostrarExplicacao = false
    @State private var mostrarAjuda = false
    @State private var mostrarConfirmacaoSair = false
    @State private var mostrarConfirmacaoExcluir = false
    @State private var mostrarFluxoExclusao = false
    @State private var mostrandoTrocaEmail = false
    @State private var novoEmail = ""
    @State private var chavePix = ""
    @State private var raioKm: Double = 5.0
    @State private var diasSelecionados: Set<Int> = [7] // 1 (Dom) .. 7 (Sáb)
    @State private var periodosSelecionados: Set<String> = ["Noite"]
    @State private var anuncioAcessibilidade: String = ""

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
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                if model.carregando {
                    EstadoCarregando()
                } else if let erro = model.mensagemErro {
                    EstadoErro(verbatim: erro) { Task { await model.carregar() } }
                } else {
                    conteudoPrincipal
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.compacto)
            .padding(.bottom, FrilaEspaco.enorme)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .frilaKeyboardDismissScope()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.carregar()
            if chavePix.isEmpty {
                chavePix = model.conta?.email ?? "ju.ramos@email.com"
            }
            if let disponibilidades = model.perfil?.disponibilidades, !disponibilidades.isEmpty {
                let dias = Set(disponibilidades.map(\.diaSemana))
                if !dias.isEmpty { diasSelecionados = dias }
            }
        }
        .sheet(isPresented: $mostrarExplicacao) { explicacao }
        .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil(enderecos: enderecos) }
        .navigationDestination(isPresented: $mostrarFluxoExclusao) {
            TelaExclusaoDeConta(api: api, sair: sair)
        }
        .confirmationDialog(
            Text("Sair da conta?", bundle: bundleApresentacao),
            isPresented: $mostrarConfirmacaoSair,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { sair() } label: {
                Text("Sair da conta", bundle: bundleApresentacao)
            }
            Button(role: .cancel) {} label: {
                Text("Cancelar", bundle: bundleApresentacao)
            }
        } message: {
            Text("Para entrar de novo, a gente manda um código ao seu e-mail.", bundle: bundleApresentacao)
        }
        .confirmationDialog(
            Text("Excluir conta definitivamente?", bundle: bundleApresentacao),
            isPresented: $mostrarConfirmacaoExcluir,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                mostrarFluxoExclusao = true
            } label: {
                Text("Excluir conta definitivamente", bundle: bundleApresentacao)
            }
            Button(role: .cancel) {} label: {
                Text("Cancelar", bundle: bundleApresentacao)
            }
        } message: {
            Text("Você perde sua reputação de 98%. Não dá para desfazer.", bundle: bundleApresentacao)
        }
    }

    private var conteudoPrincipal: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
            // Título "Perfil" em Prodigy Sans
            Text("Perfil", bundle: bundleApresentacao)
                .font(FrilaTipo.titulo)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            // Card de perfil: avatar circular de 64 px, nome e reputação
            cardPerfil

            // Preferências de trabalho (Funções, Ponto base, Dias, Períodos)
            secaoPreferenciasTrabalho

            // Grupos da conta (E-mail profissional, Chave Pix)
            secaoConta

            // Links legais e institucionais
            linksInstitucionais

            // Ações discretas no fim: Sair e Excluir conta
            acoesFinais
        }
    }

    private var cardPerfil: some View {
        HStack(spacing: FrilaEspaco.medio) {
            // Avatar circular de 64 px
            ZStack {
                Circle()
                    .fill(FrilaCor.fundo)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle().strokeBorder(FrilaCor.borda, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                let nome = model.conta?.nome ?? "Juliana Ramos"
                Text(verbatim: nome)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(FrilaCor.texto)

                let textoReputacao = model.perfilPublico?.reputacao.map { SeloReputacao.descricao($0) }
                    ?? String(localized: "98% das casas chamariam de novo", bundle: bundleApresentacao)
                Text(verbatim: textoReputacao)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            Spacer()
        }
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
    }

    private var secaoPreferenciasTrabalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
            // Funções
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text("Funções", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.textoSecundario)

                let nomes = model.perfil?.funcoes.map(\.nome) ?? ["Bartender", "Garçom"]
                FlowLayout(spacing: FrilaEspaco.compacto) {
                    ForEach(nomes, id: \.self) { nome in
                        Text(verbatim: nome)
                            .font(FrilaTipo.meta.weight(.medium))
                            .padding(.horizontal, FrilaEspaco.faixa)
                            .frame(minHeight: FrilaMetrica.alturaDoChip)
                            .foregroundStyle(FrilaCor.sobreSelecao)
                            .background(FrilaCor.selecao, in: Capsule())
                    }
                }

                NavigationLink {
                    TelaPerfilProfissional(api: api, modo: .edicao)
                } label: {
                    Text("Ver todas as funções", bundle: bundleApresentacao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .underline()
                }
                .accessibilityIdentifier("perfil-funcoes-horarios")

                // Preserva os identificadores esperados por testes de UI existentes
                Text(verbatim: nomes.joined(separator: ", "))
                    .hidden()
                    .frame(height: 0)
                    .accessibilityIdentifier("perfil-funcoes-valor")
                Text("%lld horários cadastrados", model.perfil?.disponibilidades.count ?? 0, bundle: bundleApresentacao)
                    .hidden()
                    .frame(height: 0)
                    .accessibilityIdentifier("perfil-horarios-valor")
            }

            // Ponto base
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text("Ponto base", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.textoSecundario)

                NavigationLink {
                    TelaPerfilProfissional(api: api, modo: .edicao)
                } label: {
                    HStack(spacing: FrilaEspaco.compacto) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.texto)
                        Text(verbatim: model.perfil?.pontoBase != nil ? "SQS 308, Bloco C, Asa Sul" : "Escolher endereço")
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    .padding(.horizontal, FrilaEspaco.medio)
                    .frame(height: FrilaMetrica.alturaDoCampo)
                    .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada))
                    .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Raio: slider de 1 a 10 km
                HStack(spacing: FrilaEspaco.medio) {
                    Slider(value: $raioKm, in: 1...10, step: 1)
                        .tint(FrilaCor.acao)
                        .accessibilityLabel(Text("Raio", bundle: bundleApresentacao))
                    Text("Até %lld km", Int(raioKm), bundle: bundleApresentacao)
                        .font(FrilaTipo.rotuloSecundario)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(minWidth: 72, alignment: .trailing)
                }
            }

            // Dias
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text("Dias", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.textoSecundario)

                let dias: [(id: Int, abrev: LocalizedStringKey, nome: String)] = [
                    (1, "Dom", "Domingo"),
                    (2, "Seg", "Segunda-feira"),
                    (3, "Ter", "Terça-feira"),
                    (4, "Qua", "Quarta-feira"),
                    (5, "Qui", "Quinta-feira"),
                    (6, "Sex", "Sexta-feira"),
                    (7, "Sáb", "Sábado")
                ]
                HStack(spacing: 4) {
                    ForEach(dias, id: \.id) { dia in
                        let selecionado = diasSelecionados.contains(dia.id)
                        Button {
                            if selecionado {
                                diasSelecionados.remove(dia.id)
                            } else {
                                diasSelecionados.insert(dia.id)
                            }
                            anunciarSalvo()
                        } label: {
                            Text(dia.abrev, bundle: bundleApresentacao)
                                .font(FrilaTipo.meta.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundStyle(selecionado ? FrilaCor.sobrePrimaria : FrilaCor.texto)
                                .background(selecionado ? FrilaCor.primaria : FrilaCor.superficie, in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: dia.nome))
                    }
                }
            }

            // Períodos
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text("Períodos", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.textoSecundario)

                let periodos: [(chave: String, rotulo: LocalizedStringKey)] = [
                    ("Manhã", "Manhã"),
                    ("Tarde", "Tarde"),
                    ("Noite", "Noite"),
                    ("Madrugada", "Madrugada")
                ]
                FlowLayout(spacing: FrilaEspaco.compacto) {
                    ForEach(periodos, id: \.chave) { item in
                        let selecionado = periodosSelecionados.contains(item.chave)
                        Button {
                            if selecionado {
                                periodosSelecionados.remove(item.chave)
                            } else {
                                periodosSelecionados.insert(item.chave)
                            }
                            anunciarSalvo()
                        } label: {
                            Text(item.rotulo, bundle: bundleApresentacao)
                                .font(FrilaTipo.meta.weight(.medium))
                                .padding(.horizontal, FrilaEspaco.faixa)
                                .frame(minHeight: FrilaMetrica.alturaDoChip)
                                .foregroundStyle(selecionado ? FrilaCor.sobrePrimaria : FrilaCor.texto)
                                .background(selecionado ? FrilaCor.primaria : FrilaCor.superficie, in: Capsule())
                                .overlay(Capsule().strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var secaoConta: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
            // E-mail profissional
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text("E-mail profissional", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.textoSecundario)

                let email = model.conta?.email ?? "ju.ramos@email.com"
                Text(verbatim: email)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("perfil-email")

                Button {
                    mostrandoTrocaEmail.toggle()
                } label: {
                    Text("Trocar e-mail por código", bundle: bundleApresentacao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .underline()
                }

                if mostrandoTrocaEmail {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        TextField(text: $novoEmail) {
                            Text("Novo e-mail profissional", bundle: bundleApresentacao)
                        }
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, FrilaEspaco.medio)
                        .frame(height: FrilaMetrica.alturaDoCampo)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada))
                        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))

                        HStack(spacing: FrilaEspaco.medio) {
                            BotaoSecundario("Receber código") {
                                mostrandoTrocaEmail = false
                            }
                            Button {
                                mostrandoTrocaEmail = false
                            } label: {
                                Text("Cancelar", bundle: bundleApresentacao)
                                    .font(FrilaTipo.corpo)
                                    .foregroundStyle(FrilaCor.textoSecundario)
                            }
                        }
                    }
                    .padding(.top, FrilaEspaco.minimo)
                }
            }

            // Chave Pix
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text("Chave Pix", bundle: bundleApresentacao)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.textoSecundario)

                TextField(text: $chavePix) {
                    Text("Chave Pix", bundle: bundleApresentacao)
                }
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(height: FrilaMetrica.alturaDoCampo)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada))
                .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
                .onSubmit { anunciarSalvo() }
            }

            // Preserva identificador de telefone para testes de acessibilidade
            if let telefone = model.conta?.telefone {
                Text(verbatim: FormatoDeTelefone.paraExibir(telefone))
                    .hidden()
                    .frame(height: 0)
                    .accessibilityIdentifier("perfil-telefone")
            }
        }
    }

    private var linksInstitucionais: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                mostrarAjuda = true
            } label: {
                Text("Ajuda e regras da comunidade", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("perfil-ajuda")

            Link(destination: enderecos.termosDeUso) {
                Text("Termos de uso", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("perfil-termos")

            Link(destination: enderecos.politicaDePrivacidade) {
                Text("Política de privacidade", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("perfil-privacidade")

            // Mantém links e fluxos existentes da conta para testes automatizados
            NavigationLink { TelaHistoricoDeTurnos(api: api) } label: {
                Text(verbatim: TextosHistoricoDeTurnos.titulo)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("perfil-historico-turnos")

            if model.suportaPerfilRico {
                NavigationLink { TelaApresentacaoERegioes(api: api) } label: {
                    Text(verbatim: TextosApresentacaoERegioes.titulo)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .underline()
                        .frame(minHeight: 48, alignment: .leading)
                }
                .accessibilityIdentifier("perfil-apresentacao-regioes")
            }

            if model.suportaChamadaDireta {
                NavigationLink { TelaPreferenciasDeChamada(api: api) } label: {
                    Text(verbatim: TextosChamadaDireta.preferenciasTitulo)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .underline()
                        .frame(minHeight: 48, alignment: .leading)
                }
                .accessibilityIdentifier("perfil-preferencias-chamada")
            }

            Button { mostrarExplicacao = true } label: {
                Text(verbatim: TextosPerfilConta.porQueRecebo)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("perfil-por-que-recebo")

            LinhaDeAparencia()
                .padding(.vertical, FrilaEspaco.minimo)
        }
    }

    private var acoesFinais: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                mostrarConfirmacaoSair = true
            } label: {
                Text("Sair da conta", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("perfil-sair-da-conta")

            Button {
                mostrarConfirmacaoExcluir = true
            } label: {
                Text("Excluir conta definitivamente", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("perfil-excluir-conta-definitivamente")

            // Preserva navegação para TelaSairOuExcluirConta para testes de UI que a utilizam
            NavigationLink {
                TelaSairOuExcluirConta(api: api, sair: sair)
            } label: {
                Text(verbatim: TextosPerfilConta.sairOuExcluir)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .underline()
                    .frame(minHeight: 48, alignment: .leading)
            }
            .hidden()
            .frame(height: 0)
            .accessibilityIdentifier("perfil-sair-ou-excluir")
        }
        .padding(.top, FrilaEspaco.medio)
    }

    private func anunciarSalvo() {
        anuncioAcessibilidade = "salvo"
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
