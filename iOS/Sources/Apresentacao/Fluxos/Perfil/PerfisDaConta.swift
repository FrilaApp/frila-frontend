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
    static let senha = String(localized: "Senha da conta", bundle: bundleApresentacao)
    static let sairOuExcluir = String(localized: "Sair ou excluir conta", bundle: bundleApresentacao)
    static let explicacaoSair = String(localized: "Encerra a sessão neste aparelho. Você pode entrar de novo quando quiser.", bundle: bundleApresentacao)
    static let explicacaoExcluir = String(localized: "Encerra a conta de forma permanente e não dá para desfazer. Antes de confirmar, você vê o que acontece com seus dados e turnos.", bundle: bundleApresentacao)
    static let erro = String(localized: "Não foi possível carregar o perfil.", bundle: bundleApresentacao)
    static let vazio = String(localized: "Nenhum estabelecimento disponível.", bundle: bundleApresentacao)
    static let vazioDica = String(localized: "Se isso não parece certo, fale com o suporte em Ajuda.", bundle: bundleApresentacao)
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

    /// Cada chamada de `carregar` tem a sua geração. A tela chama de novo ao trocar de casa (`.task(id:)`) e a resposta da casa
    /// anterior ainda pode chegar depois: só a chamada mais nova, e não cancelada, grava no modelo, e só ela desliga o `carregando`.
    private var geracao = 0
    private var ultimaPreferida: UUID?

    /// `preferida` é a casa que a conta escolheu em "Trocar de casa"; sem ela, ou se a conta já não é membro dela, vale a primeira.
    /// Trocar de casa limpa o que era da anterior antes de ler a nova: nada de uma casa aparece na outra.
    public func carregar(preferindo preferida: UUID? = nil) async {
        geracao += 1
        let minha = geracao
        func vale() -> Bool { minha == geracao && !Task.isCancelled }
        ultimaPreferida = preferida
        carregando = true; mensagemErro = nil
        if let preferida, estabelecimento?.id != preferida { estabelecimento = nil; perfilPublico = nil }
        defer { if minha == geracao { carregando = false } }
        do {
            let todas = try await carregarEstabelecimentos()
            guard vale() else { return }
            guard let escolhida = todas.first(where: { $0.id == preferida }) ?? todas.first else {
                estabelecimento = nil; perfilPublico = nil
                return
            }
            let publico = try await carregarPublico(escolhida.id)
            guard vale() else { return }
            estabelecimento = escolhida; perfilPublico = publico
        } catch { if vale() { mensagemErro = TextosPerfilConta.erro } }
    }

    /// "Tentar de novo" relê a casa que a última leitura pedia, e não a primeira da lista.
    public func tentarDeNovo() async { await carregar(preferindo: ultimaPreferida) }
}

/// Linha de lista de tela que ainda não passou para o `FrilaGrupoDeLinhas`: texto à esquerda e seta em `textoSecundario`,
/// com 48 pt de altura mínima. A Conta já não a usa; `ItemExportarDados` (R7) e `MinhasVagas` (R5) ainda usam.
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

/// Divisória entre as linhas de um grupo aberto (telas que ainda não passaram para o `FrilaGrupoDeLinhas`).
struct DivisoriaDeLinha: View {
    public var body: some View {
        Rectangle()
            .fill(FrilaCor.divisoria)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Lista aberta entre fios, sem cartão. A Conta usa o `FrilaGrupoDeLinhas`; esta ficou para `TelaAparencia` (R7).
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

/// Linha de leitura de um grupo: o nome à esquerda e o valor, em `textoSecundario`, à direita. Com texto grande, o valor
/// desce para baixo do nome.
private struct LinhaDeValorDaConta: View {
    let titulo: String
    let valor: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: FrilaEspaco.item) {
                nome
                Spacer(minLength: FrilaEspaco.item)
                detalhe
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                nome
                detalhe
            }
        }
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
        .padding(.vertical, FrilaEspaco.item)
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var nome: some View {
        Text(verbatim: titulo)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var detalhe: some View {
        Text(verbatim: valor)
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// O destino de cada linha da Conta do profissional que abre outra tela (um por vez, no `navigationDestination(item:)`).
private enum DestinoDoPerfil: Hashable {
    case historico, apresentacao, preferenciasDeChamada, aparencia, bloqueios, senha
}

/// O mesmo, na Conta do estabelecimento.
private enum DestinoDoEstabelecimento: Hashable {
    case historico, equipeDeConfianca, bloqueios, aparencia, senha
}

/// A confirmação de saída, a mesma nas duas Contas: título rolável e ações ancoradas, Cancelar primeiro.
/// "Sair" é o botão primário: é o compromisso da folha e o único laranja dela.
private struct FolhaDeConfirmacaoDeSaida: View {
    let cancelar: () -> Void
    let confirmar: () -> Void

    var body: some View {
        ScrollView {
            Text("Sair da conta?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FrilaEspaco.grupo)
        }
        .rodapeAncorado {
            BotaoSecundario(verbatim: String(localized: "Cancelar", bundle: bundleApresentacao), acao: cancelar)
                .accessibilityIdentifier("botao-cancelar-saida-dialogo")
            BotaoPrimario(verbatim: TextosPerfilConta.sair, acao: confirmar)
                .accessibilityIdentifier("botao-confirmar-saida-dialogo")
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}

/// Perfil do profissional (#18): nome e contatos, foto, histórico, o que alimenta as vagas e o menu da conta, em grupos de
/// linhas sobre o fundo. Sem laranja: a raiz da Conta é de leitura e de escolha.
public struct TelaMeuPerfilProfissional: View {
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var despachoModel: PorQueReceboVagasViewModel
    @State private var model: MeuPerfilProfissionalViewModel
    @State private var exportarModel: ExportarDadosViewModel
    private let api: any ApiCliente
    private let sair: () -> Void
    public let enderecos: EnderecosOficiais
    @State private var mostrarExplicacao = false
    @State private var mostrarAjuda = false
    @State private var destino: DestinoDoPerfil?
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
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if model.carregando {
                    EstadoCarregando()
                } else if let erro = model.mensagemErro {
                    EstadoErro(verbatim: erro) { Task { await model.carregar() } }
                } else if let conta = model.conta, let perfil = model.perfil {
                    identidade(conta)
                    SecaoFotoDePerfil(api: api)
                    historico
                    configuracao(perfil)
                }

                menuDaConta

                // Ação de risco: discreta, no fim, uma por linha. A tela de trás diz o que cada uma faz.
                NavigationLink {
                    TelaSairOuExcluirConta(api: api, sair: sair)
                } label: {
                    Text(verbatim: TextosPerfilConta.sairOuExcluir)
                }
                .buttonStyle(.frilaAcaoDiscreta)
                .accessibilityIdentifier("perfil-sair-ou-excluir")

                #if FRILA_BETA
                SeloBeta()
                #endif
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.secao)
        }
        .background(FrilaCor.fundo)
        .frilaKeyboardDismissScope()
        .navigationTitle(Text(verbatim: TextosPerfilConta.meuPerfil))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $destino) { destino in
            telaDo(destino)
        }
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

    @ViewBuilder
    private func telaDo(_ destino: DestinoDoPerfil) -> some View {
        switch destino {
        case .historico:
            TelaHistoricoDeTurnos(api: api)
        case .apresentacao:
            TelaApresentacaoERegioes(api: api)
        case .preferenciasDeChamada:
            TelaPreferenciasDeChamada(api: api)
        case .aparencia:
            TelaAparencia()
        case .bloqueios:
            TelaBloqueios(api: api, bloqueiosDaSessao: bloqueiosDaSessao)
        case .senha:
            TelaDefinirSenha(api: api)
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
            aoConfirmarEdicao: confirmarEdicao,
            sangria: FrilaEspaco.item
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

    /// Ajuda, aparência e dados da conta. Sair e Excluir conta ficam um passo adiante, de propósito: ações
    /// irreversíveis não devem ser acionadas por exploração na raiz da Conta.
    private var menuDaConta: some View {
        FrilaGrupoDeLinhas(verbatim: TextosPerfilConta.contaEDados, linhasComIcone: false) {
            FrilaLinhaDeOpcao(titulo: TextosPerfilConta.ajuda, remate: .navega) { mostrarAjuda = true }
                .accessibilityIdentifier("perfil-ajuda")
            FrilaLinhaDeOpcao(titulo: TextosAparencia.titulo, remate: .navega) { destino = .aparencia }
                .accessibilityIdentifier("perfil-aparencia")
            FrilaLinhaDeOpcao(titulo: TextosPerfilConta.senha, remate: .navega) { destino = .senha }
                .accessibilityIdentifier("perfil-definir-senha")
            if perfilCarregado {
                FrilaLinhaDeOpcao(titulo: TextosBloqueios.titulo, remate: .navega) { destino = .bloqueios }
                    .accessibilityIdentifier("perfil-bloqueios")
                // A linha é da `ItemExportarDados` (R7), que ainda desenha com margem zero: o respiro lateral vem daqui.
                ItemExportarDados(viewModel: exportarModel, identificador: "perfil-exportar-dados")
                    .padding(.horizontal, FrilaMedidaDeLinha.margem)
            }
        }
    }

    private func identidade(_ conta: Conta) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: conta.nome)
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // Áreas de toque encostadas: nenhuma faixa morta entre os dois contatos. A área passa 8 pt para cada lado (sangria).
            VStack(alignment: .leading, spacing: 0) {
                contato(TextosPerfilConta.telefone, FormatoDeTelefone.paraExibir(conta.telefone), id: "perfil-telefone", campo: .telefone)
                contato(TextosPerfilConta.email, conta.email, id: "perfil-email", campo: .email)
            }
            .padding(.horizontal, -FrilaEspaco.item)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historico: some View {
        FrilaGrupoDeLinhas(verbatim: String(localized: "Seu histórico", bundle: bundleApresentacao), linhasComIcone: false) {
            if let reputacao = model.perfilPublico?.reputacao {
                SeloReputacao(reputacao)
                    .padding(.horizontal, FrilaMedidaDeLinha.margem)
                    .padding(.vertical, FrilaEspaco.bloco)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            FrilaLinhaDeOpcao(titulo: TextosHistoricoDeTurnos.titulo, remate: .navega) { destino = .historico }
                .accessibilityIdentifier("perfil-historico-turnos")
        }
    }

    private func configuracao(_ perfil: PerfilProfissional) -> some View {
        FrilaGrupoDeLinhas(linhasComIcone: false) {
            // O resumo (funções e horários) são dois textos com identificador próprio, então a linha é a do próprio
            // NavigationLink, com o mesmo toque e a mesma seta das outras.
            NavigationLink { TelaPerfilProfissional(api: api, modo: .edicao) } label: {
                HStack(alignment: .top, spacing: FrilaEspaco.item) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                        Text(verbatim: TextosPerfilConta.funcoesHorarios)
                            .font(FrilaTipo.rotuloSecundario)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                        let funcoes = perfil.funcoes.map(\.nome).joined(separator: ", ")
                        Text(verbatim: funcoes.isEmpty ? TextosPerfilConta.naoInformado : funcoes)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("perfil-funcoes-valor")
                        Text(verbatim: perfil.disponibilidades.isEmpty
                             ? TextosPerfilConta.naoInformado
                             : String(localized: "\(perfil.disponibilidades.count) horários cadastrados", bundle: bundleApresentacao))
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("perfil-horarios-valor")
                    }
                    Spacer(minLength: FrilaEspaco.item)
                    Image(systemName: "chevron.forward")
                        .font(FrilaTipo.apoio.weight(.semibold))
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.top, FrilaEspaco.junto)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, FrilaMedidaDeLinha.margem)
                .padding(.vertical, FrilaEspaco.item)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloDeLinhaTocavel())
            .accessibilityIdentifier("perfil-funcoes-horarios")

            if model.suportaPerfilRico {
                FrilaLinhaDeOpcao(titulo: TextosApresentacaoERegioes.titulo, remate: .navega) { destino = .apresentacao }
                    .accessibilityIdentifier("perfil-apresentacao-regioes")
            }

            if model.suportaChamadaDireta {
                FrilaLinhaDeOpcao(titulo: TextosChamadaDireta.preferenciasTitulo, remate: .navega) { destino = .preferenciasDeChamada }
                    .accessibilityIdentifier("perfil-preferencias-chamada")
            }

            FrilaLinhaDeOpcao(titulo: TextosPerfilConta.porQueRecebo, remate: .navega) { mostrarExplicacao = true }
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
            VStack(alignment: .leading, spacing: FrilaEspaco.secao) {
                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    Button { mostrarConfirmacaoDeSaida = true } label: {
                        Text(verbatim: TextosPerfilConta.sair)
                    }
                    .buttonStyle(.frilaAcaoDiscreta)
                    .accessibilityIdentifier("perfil-sair")
                    Text(verbatim: TextosPerfilConta.explicacaoSair)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    NavigationLink {
                        TelaExclusaoDeConta(
                            viewModel: ExclusaoDeContaViewModel(api: api, aoConcluir: sair)
                        )
                    } label: {
                        Text(verbatim: TextosPerfilConta.excluir)
                    }
                    .buttonStyle(.frilaAcaoDiscreta)
                    .accessibilityIdentifier("perfil-excluir-conta")
                    Text(verbatim: TextosPerfilConta.explicacaoExcluir)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.sairOuExcluir))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $mostrarConfirmacaoDeSaida) {
            FolhaDeConfirmacaoDeSaida(
                cancelar: { mostrarConfirmacaoDeSaida = false },
                confirmar: {
                    mostrarConfirmacaoDeSaida = false
                    sair()
                }
            )
        }
    }
}

/// Perfil do estabelecimento (#18): o mesmo sistema do perfil do profissional, com o que a casa tem (histórico, equipe,
/// bloqueios), e Sair e Excluir conta como ações discretas no fim. Sem desenho do Fabrício: extrapolado.
public struct TelaPerfilEstabelecimento: View {
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @State private var mostrarConfirmacaoDeSaida = false
    @State private var model: PerfilEstabelecimentoViewModel
    @State private var exportarModel: ExportarDadosViewModel
    private let api: any ApiCliente
    private let sair: () -> Void
    public let enderecos: EnderecosOficiais
    @State private var mostrarAjuda = false
    @State private var destino: DestinoDoEstabelecimento?
    private let casaEscolhida: UUID?
    private let entradasDaCasa: ((EstabelecimentoDaConta?) -> AnyView)?
    /// `casaEscolhida`: a casa de "Trocar de casa" (a tela relê quando ela muda). `entradasDaCasa` põe no topo da lista as linhas
    /// da equipe da casa, do convite e da troca de casa; recebe a casa que a tela mostra (`nil` enquanto a conta não tem uma).
    public init(api: any ApiCliente, enderecos: EnderecosOficiais = .padrao, casaEscolhida: UUID? = nil,
                entradasDaCasa: ((EstabelecimentoDaConta?) -> AnyView)? = nil, sair: @escaping () -> Void) {
        self.api = api
        self.sair = sair
        self.enderecos = enderecos
        self.casaEscolhida = casaEscolhida
        self.entradasDaCasa = entradasDaCasa
        _model = State(initialValue: PerfilEstabelecimentoViewModel(api: api))
        _exportarModel = State(initialValue: ExportarDadosViewModel(api: api))
    }
    public var body: some View {
        conteudoDaTela
            .sheet(isPresented: $mostrarConfirmacaoDeSaida) {
                FolhaDeConfirmacaoDeSaida(
                    cancelar: { mostrarConfirmacaoDeSaida = false },
                    confirmar: {
                        mostrarConfirmacaoDeSaida = false
                        sair()
                    }
                )
            }
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if model.carregando { EstadoCarregando() }
                else if let erro = model.mensagemErro { EstadoErro(verbatim: erro) { Task { await model.tentarDeNovo() } } }
                else if let estabelecimento = model.estabelecimento {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        Text(verbatim: estabelecimento.nome)
                            .font(FrilaTipo.nome)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        FrilaGrupoDeLinhas(linhasComIcone: false) {
                            if let tipo = estabelecimento.tipo {
                                LinhaDeValorDaConta(titulo: TextosPerfilConta.tipo, valor: tipo.descricaoPerfil)
                            }
                            LinhaDeValorDaConta(titulo: TextosPerfilConta.papel, valor: estabelecimento.papel.descricaoPerfil)
                        }
                        if let reputacao = model.perfilPublico?.reputacao { SeloReputacao(reputacao) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    EstadoVazio(verbatim: TextosPerfilConta.vazio, mensagem: TextosPerfilConta.vazioDica)
                }

                FrilaGrupoDeLinhas(linhasComIcone: false) {
                    // As linhas da casa não dependem de o perfil ter carregado: um 404 dele (bloqueio) não as esconde.
                    if !model.carregando, let entradasDaCasa {
                        entradasDaCasa(model.estabelecimento)
                    }
                    if !model.carregando, model.mensagemErro == nil, model.estabelecimento != nil {
                        FrilaLinhaDeOpcao(titulo: TextosHistoricoDeTurnos.titulo, remate: .navega) {
                            destino = .historico
                        }
                        .accessibilityIdentifier("estabelecimento-historico-turnos")
                        FrilaLinhaDeOpcao(titulo: TextosEquipeDeConfianca.titulo, remate: .navega) {
                            destino = .equipeDeConfianca
                        }
                        .accessibilityIdentifier("estabelecimento-equipe-de-confianca")
                        FrilaLinhaDeOpcao(titulo: TextosBloqueios.titulo, remate: .navega) { destino = .bloqueios }
                            .accessibilityIdentifier("estabelecimento-bloqueios")
                        FrilaLinhaDeOpcao(titulo: TextosPerfilConta.ajuda, remate: .navega) { mostrarAjuda = true }
                            .accessibilityIdentifier("perfil-ajuda")
                        // A linha é da `ItemExportarDados` (R7), que ainda desenha com margem zero: o respiro lateral vem daqui.
                        ItemExportarDados(viewModel: exportarModel, identificador: "estabelecimento-exportar-dados")
                            .padding(.horizontal, FrilaMedidaDeLinha.margem)
                    }
                    FrilaLinhaDeOpcao(titulo: TextosAparencia.titulo, remate: .navega) { destino = .aparencia }
                        .accessibilityIdentifier("perfil-aparencia")
                    FrilaLinhaDeOpcao(titulo: TextosPerfilConta.senha, remate: .navega) { destino = .senha }
                        .accessibilityIdentifier("estabelecimento-definir-senha")
                }

                // Ações de risco: discretas, no fim, uma por linha.
                VStack(alignment: .leading, spacing: 0) {
                    Button { mostrarConfirmacaoDeSaida = true } label: {
                        Text(verbatim: TextosPerfilConta.sair)
                    }
                    .buttonStyle(.frilaAcaoDiscreta)
                    .accessibilityIdentifier("estabelecimento-sair")
                    NavigationLink {
                        TelaExclusaoDeConta(
                            viewModel: ExclusaoDeContaViewModel(
                                api: api,
                                aoConcluir: sair
                            )
                        )
                    } label: {
                        Text(verbatim: TextosPerfilConta.excluir)
                    }
                    .buttonStyle(.frilaAcaoDiscreta)
                    .accessibilityIdentifier("estabelecimento-excluir-conta")
                }

                #if FRILA_BETA
                SeloBeta()
                #endif
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.secao)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.perfilEstabelecimento))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $destino) { destino in
            telaDo(destino)
        }
        .task(id: casaEscolhida) { await model.carregar(preferindo: casaEscolhida) }
        .sheet(isPresented: $mostrarAjuda) { TelaAjudaPerfil(enderecos: enderecos) }
    }

    @ViewBuilder
    private func telaDo(_ destino: DestinoDoEstabelecimento) -> some View {
        switch destino {
        case .historico:
            if let estabelecimento = model.estabelecimento {
                TelaHistoricoDeTurnos(api: api, estabelecimentoID: estabelecimento.id)
            }
        case .equipeDeConfianca:
            if let estabelecimento = model.estabelecimento {
                TelaEquipeDeConfianca(api: api, estabelecimentoID: estabelecimento.id)
            }
        case .bloqueios:
            TelaBloqueios(api: api, bloqueiosDaSessao: bloqueiosDaSessao)
        case .aparencia:
            TelaAparencia()
        case .senha:
            TelaDefinirSenha(api: api)
        }
    }
}


public struct TelaAjudaPerfil: View {
    @Environment(\.dismiss) private var dismiss
    @State private var abrirLicencas = false
    public let enderecos: EnderecosOficiais

    public init(enderecos: EnderecosOficiais = .padrao) {
        self.enderecos = enderecos
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                FrilaGrupoDeLinhas(linhasComIcone: false) {
                    suporte
                    linkExterno(TextosPerfilConta.termos, destino: enderecos.termosDeUso)
                        .accessibilityIdentifier("perfil-termos")
                    linkExterno(TextosPerfilConta.privacidade, destino: enderecos.politicaDePrivacidade)
                        .accessibilityIdentifier("perfil-privacidade")
                    FrilaLinhaDeOpcao(titulo: TextosPerfilConta.licencas, remate: .navega) { abrirLicencas = true }
                        .accessibilityIdentifier("perfil-licencas")
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.bloco)
                .padding(.bottom, FrilaEspaco.grupo)
            }
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosPerfilConta.ajuda)).navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $abrirLicencas) { TelaLicencas() }
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

    /// "Fale com o suporte", o e-mail e o prazo: um bloco só, na primeira linha.
    private var suporte: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            if let url = enderecos.urlSuporte {
                Link(destination: url) {
                    HStack {
                        Text(verbatim: TextosPerfilConta.suporte)
                            .font(FrilaTipo.rotuloSecundario)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: FrilaEspaco.item)
                        Image(systemName: "envelope")
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(verbatim: TextosPerfilConta.suporte))
                .accessibilityHint(Text(verbatim: TextosPerfilConta.dicaSuporte))
                .accessibilityAddTraits(.isLink)
                .accessibilityIdentifier("perfil-suporte")
            } else {
                Text(verbatim: TextosPerfilConta.suporte)
                    .font(FrilaTipo.rotuloSecundario)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: FrilaMetrica.alvo, alignment: .leading)
                    .accessibilityIdentifier("perfil-suporte")
            }

            Text(verbatim: enderecos.emailSuporte)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
                .contentShape(Rectangle())
                .textSelection(.enabled)
                .accessibilityLabel(Text(verbatim: "\(TextosPerfilConta.email): \(enderecos.emailSuporte)"))
                .accessibilityIdentifier("perfil-suporte-email")

            Text(verbatim: TextosPerfilConta.prazoSuporte)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, FrilaEspaco.item)
        }
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
    }

    private func linkExterno(_ titulo: String, destino: URL) -> some View {
        Link(destination: destino) {
            HStack {
                Text(verbatim: titulo)
                    .font(FrilaTipo.rotuloSecundario)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FrilaEspaco.item)
                Image(systemName: "arrow.up.right")
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaMedidaDeLinha.margem)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(verbatim: titulo))
        .accessibilityAddTraits(.isLink)
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
