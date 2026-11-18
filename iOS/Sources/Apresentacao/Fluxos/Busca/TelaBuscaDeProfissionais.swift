import FrilaDominio
import SwiftUI

/// Busca de profissionais (CD-B01 a CD-B11): filtros, lista, seleção de até 3, chamar e "Publicar para todos".
/// Atrás da chave `buscaProfissionais`.
///
/// Desenho (R6): o Fabrício não desenhou o lado da casa; a tela segue o que ele desenhou para escolher (T2, a lista de
/// vagas): rótulo visível acima de cada campo, cartões em `superficie`, estado vazio sem ícone e, ancorado embaixo,
/// o único botão laranja, "Chamar selecionados". "Buscar" e a lista de resultados não levam laranja.
public struct TelaBuscaDeProfissionais: View {
    /// Vem de fora: vive enquanto a busca existir (não só enquanto a folha está aberta), para um envio incerto
    /// continuar travado mesmo se a tela for fechada e aberta de novo.
    private let viewModel: BuscaDeProfissionaisViewModel
    @State private var funcoes: [Funcao] = []
    @State private var regioes: [RegiaoAdministrativa] = []
    @State private var casa: Estabelecimento?
    @State private var catalogoCarregado = false
    @State private var catalogoComErro = false
    @State private var usarHorario = false
    @State private var inicio: Date
    @State private var fim: Date
    @State private var rascunhoDaChamada: RascunhoDaChamadaDaBusca?
    @State private var bloqueiosLocais = BloqueiosDaSessao()
    @Environment(BloqueiosDaSessao.self) private var bloqueiosDaSessao: BloqueiosDaSessao?
    @Environment(\.dismiss) private var fechar
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto

    private let api: any ApiCliente
    private let estabelecimentoID: UUID
    private let aoPublicarParaTodos: (RascunhoDeVagaDaBusca) -> Void
    private var bloqueios: BloqueiosDaSessao { bloqueiosDaSessao ?? bloqueiosLocais }

    // O fato e a dica do estado vazio, no desenho do estado vazio (o texto antigo era uma frase só).
    private static let semResultadoFato = String(localized: "Nenhum profissional encontrado com esses filtros.", bundle: bundleApresentacao)
    private static let semResultadoDica = String(localized: "Você pode publicar a vaga para todos.", bundle: bundleApresentacao)

    public init(viewModel: BuscaDeProfissionaisViewModel, api: any ApiCliente, estabelecimentoID: UUID,
                aoPublicarParaTodos: @escaping (RascunhoDeVagaDaBusca) -> Void) {
        self.viewModel = viewModel
        let amanha = Date.now.addingTimeInterval(24 * 3600)
        _inicio = State(initialValue: amanha)
        _fim = State(initialValue: amanha.addingTimeInterval(4 * 3600))
        self.api = api
        self.estabelecimentoID = estabelecimentoID
        self.aoPublicarParaTodos = aoPublicarParaTodos
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                filtros
                if catalogoComErro && !catalogoCarregado { catalogoIndisponivel }
                if viewModel.enviando {
                    // Envio em curso: a seleção fica parada até a resposta (ou o prazo) chegar.
                    Text(verbatim: TextosBuscaDeProfissionais.enviando)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("busca-enviando")
                }
                if viewModel.travadoPeloIncerto { envioIncerto }
                situacao
                if let aviso = viewModel.avisoDeLimiteDeSelecao {
                    AvisoFrila(verbatim: aviso, tom: .informativo)
                        .accessibilityIdentifier("busca-aviso-limite")
                }
                if !viewModel.resultados.isEmpty { lista }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosBuscaDeProfissionais.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // Fechar e arrastar ficam livres mesmo com envio em curso ou incerto (ninguém fica preso offline): a guarda
                // segura o ViewModel, e reabrir mostra o envio ou o pendente com o mesmo trabalho e as mesmas chaves.
                Button { fechar() } label: { Text(verbatim: TextosBuscaDeProfissionais.fechar) }
                    .accessibilityIdentifier("busca-fechar")
            }
        }
        .rodapeAncoradoSe(!viewModel.resultados.isEmpty) { rodapeDaLista }
        .task { await carregarCatalogo() }
        .sheet(item: $rascunhoDaChamada) { rascunho in
            FolhaDeChamadaDaBusca(rascunho: rascunho, fechar: { rascunhoDaChamada = nil }, enviar: { Task { await enviarChamadas() } })
        }
        .alert(Text(verbatim: TextosChamadaDireta.j7Titulo), isPresented: $viewModel.mostrarJ7) {
            Button(role: .cancel) { viewModel.mostrarJ7 = false } label: { Text(verbatim: TextosBuscaDeProfissionais.fechar) }
            Button { Task { await reenviarComJ7() } } label: { Text(verbatim: TextosChamadaDireta.j7Confirmar) }
                .accessibilityIdentifier("busca-j7-confirmar")
        } message: { Text(verbatim: TextosChamadaDireta.j7Mensagem) }
        .sheet(isPresented: $viewModel.mostrarTermosDaVagaAberta) {
            // 0.2.95: a vaga já aberta do trabalho tem outros termos. Só sai com Confirmar; fechar a folha é Cancelar.
            if let folha = TelaTermosDaVagaAbertaProvisoria(modelo: viewModel) {
                ScrollView { folha }
                    .background(FrilaCor.fundo)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(FrilaRaio.folha)
            }
        }
    }

    // MARK: Filtros

    private var filtros: some View {
        @Bindable var viewModel = viewModel
        return VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: TextosBuscaDeProfissionais.filtros)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            campoDeEscolha(TextosBuscaDeProfissionais.servico) {
                Picker(selection: $viewModel.funcaoID) {
                    Text(verbatim: TextosBuscaDeProfissionais.escolhaOServico).tag(UUID?.none)
                    ForEach(funcoes) { funcao in Text(verbatim: funcao.nome).tag(UUID?.some(funcao.id)) }
                } label: { Text(verbatim: TextosBuscaDeProfissionais.servico) }
                    .accessibilityIdentifier("busca-servico")
            }
            campoDeEscolha(TextosBuscaDeProfissionais.regiao) {
                Picker(selection: $viewModel.regiaoID) {
                    Text(verbatim: TextosBuscaDeProfissionais.regiaoDoEstabelecimento).tag(Int?.none)
                    ForEach(regioes) { regiao in Text(verbatim: regiao.nome).tag(Int?.some(regiao.id)) }
                } label: { Text(verbatim: TextosBuscaDeProfissionais.regiao) }
                    .accessibilityIdentifier("busca-regiao")
            }
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                Toggle(isOn: $usarHorario) {
                    Text(verbatim: TextosBuscaDeProfissionais.buscarPorHorario).font(FrilaTipo.corpo)
                }
                .accessibilityIdentifier("busca-usar-horario")
                .modifier(LinhaDeControleDaCasa())
                if usarHorario {
                    DatePicker(selection: $inicio, in: Date.now...) {
                        Text(verbatim: TextosBuscaDeProfissionais.inicio).font(FrilaTipo.corpo)
                    }
                    .accessibilityIdentifier("busca-inicio")
                    .modifier(LinhaDeControleDaCasa())
                    DatePicker(selection: $fim, in: inicio...) {
                        Text(verbatim: TextosBuscaDeProfissionais.termino).font(FrilaTipo.corpo)
                    }
                    .accessibilityIdentifier("busca-fim")
                    .modifier(LinhaDeControleDaCasa())
                }
            }
            BotaoSecundario(verbatim: TextosBuscaDeProfissionais.buscar) { Task { await buscar() } }
                .disabled(!viewModel.podeBuscar)
                .accessibilityIdentifier("buscar-profissionais")
        }
    }

    /// Escolha única por menu do sistema, na caixa do campo, com o rótulo visível acima.
    private func campoDeEscolha<Conteudo: View>(_ nome: String, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: nome)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityHidden(true)
            conteudo()
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(FrilaCor.texto)
                .frame(maxWidth: .infinity, alignment: .leading)
                .caixaDoCampoFrila()
        }
    }

    // MARK: Avisos que travam a busca

    private var catalogoIndisponivel: some View {
        // O erro da ação fica logo acima do botão que a repete (D-DS-13).
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            MensagemJuntoAoBotao(verbatim: TextosBuscaDeProfissionais.catalogoIndisponivel)
                .accessibilityIdentifier("busca-catalogo-erro")
            BotaoSecundario(verbatim: TextosBuscaDeProfissionais.tentarDeNovo) { Task { await carregarCatalogo() } }
                .accessibilityIdentifier("busca-catalogo-tentar-de-novo")
        }
    }

    private var envioIncerto: some View {
        // Um envio que levou o trabalho ficou incerto: nada de busca nova nem de trocar a seleção até resolver.
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            MensagemJuntoAoBotao(verbatim: TextosBuscaDeProfissionais.envioIncerto)
                .accessibilityIdentifier("busca-envio-incerto")
            BotaoSecundario(verbatim: TextosBuscaDeProfissionais.tentarDeNovo) { chamarSelecionados() }
                .disabled(!podeChamarAgora)
                .accessibilityIdentifier("busca-tentar-de-novo")
        }
    }

    // MARK: Estados

    @ViewBuilder
    private var situacao: some View {
        switch viewModel.estado {
        case .ocioso, .resultados:
            EmptyView()
        case .carregando:
            Text(verbatim: TextosBuscaDeProfissionais.buscando)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(maxWidth: .infinity)
                .padding(.top, FrilaEspaco.bloco)
        case .vazio:
            VStack(spacing: 0) {
                EstadoVazio(verbatim: Self.semResultadoFato, mensagem: Self.semResultadoDica)
                    .accessibilityIdentifier("busca-vazia")
                if let rascunho = viewModel.rascunhoParaPublicarParaTodos {
                    BotaoSecundario(verbatim: TextosChamadaDireta.publicarParaTodos) { aoPublicarParaTodos(rascunho) }
                        // Largura do rótulo; com texto grande, a largura toda, para o rótulo quebrar em vez de vazar.
                        .fixedSize(horizontal: !tamanhoDoTexto.isAccessibilitySize, vertical: false)
                        .accessibilityIdentifier("publicar-para-todos-busca")
                }
            }
            .frame(maxWidth: .infinity)
        case .indisponivel:
            AvisoFrila(verbatim: TextosBuscaDeProfissionais.indisponivel, tom: .informativo)
                .accessibilityIdentifier("busca-indisponivel")
        case .termosPendentes:
            // `termos_pendentes` (0.2.90): aceitar repete a busca com os mesmos filtros; sem aceite, segue bloqueada.
            TelaAceiteDeTermosProvisoria(modelo: viewModel)
                .cartaoFrila()
        case let .erro(mensagem):
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                MensagemJuntoAoBotao(verbatim: mensagem)
                    .accessibilityIdentifier("busca-erro")
                BotaoSecundario(verbatim: TextosBuscaDeProfissionais.tentarDeNovo) { Task { await buscar() } }
                    .disabled(!viewModel.podeBuscar)
            }
        }
    }

    // MARK: Lista

    private var lista: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosBuscaDeProfissionais.profissionais)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                ForEach(viewModel.resultados) { cartao in linha(cartao) }
            }
            if viewModel.temMais {
                // O marcador do fim da lista só nasce quando chega perto da tela: é ele que pede a página seguinte.
                LazyVStack {
                    Color.clear.frame(height: 1)
                        .onAppear { Task { await viewModel.carregarMais() } }
                        .accessibilityHidden(true)
                }
            }
            if viewModel.carregandoMais {
                Text(verbatim: TextosBuscaDeProfissionais.buscando)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(maxWidth: .infinity)
            }
            if let erro = viewModel.erroAoCarregarMais {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    MensagemJuntoAoBotao(verbatim: erro)
                    BotaoSecundario(verbatim: TextosBuscaDeProfissionais.carregarMais) { Task { await viewModel.carregarMais() } }
                }
            }
        }
    }

    /// O botão laranja da tela: chamar as pessoas escolhidas. A contagem fica logo acima dele.
    @ViewBuilder
    private var rodapeDaLista: some View {
        Text(verbatim: TextosBuscaDeProfissionais.selecionados(viewModel.selecionados.count))
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.textoSecundario)
            .frame(maxWidth: .infinity, alignment: .leading)
        BotaoPrimario(verbatim: TextosBuscaDeProfissionais.chamarSelecionados, carregando: viewModel.enviando) { chamarSelecionados() }
            .disabled(!podeChamarAgora)
            .accessibilityIdentifier("chamar-selecionados")
    }

    /// Um resultado num cartão: a marca de seleção à esquerda, o cartão que abre o perfil e, embaixo, o resultado da
    /// chamada a essa pessoa. Escolhido, o cartão ganha o fio de 2 pt em tinta (além do check, que não depende de cor).
    private func linha(_ cartao: CartaoProfissional) -> some View {
        let selecionado = viewModel.estaSelecionado(cartao.id)
        let forma = RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
        return VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            HStack(alignment: .top, spacing: FrilaEspaco.item) {
                Button { viewModel.alternarSelecao(cartao.id) } label: {
                    Image(systemName: selecionado ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(selecionado ? FrilaCor.texto : FrilaCor.bordaDoCampo)
                        .frame(minWidth: FrilaMetrica.alvo, minHeight: FrilaMetrica.alvo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.travadoPeloIncerto || viewModel.enviando)
                .accessibilityLabel(Text(verbatim: selecionado ? TextosBuscaDeProfissionais.desmarcar(cartao.nome)
                                                                 : TextosBuscaDeProfissionais.selecionar(cartao.nome)))
                .accessibilityIdentifier("selecionar-profissional-\(cartao.id)")
                NavigationLink {
                    TelaPerfilPublico(perfil: Self.perfilResumido(cartao), api: api, bloqueios: bloqueios)
                        .navigationTitle(Text(verbatim: cartao.nome))
                } label: {
                    CartaoDaBuscaProvisorio(cartao: cartao)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("perfil-profissional-\(cartao.id)")
            }
            if let resultado = viewModel.resultadosDaChamada[cartao.id] {
                Text(verbatim: Self.texto(resultado))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("resultado-chamada-\(cartao.id)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .overlay { if selecionado { forma.strokeBorder(FrilaCor.texto, lineWidth: 2) } }
    }

    /// Só o necessário para abrir o perfil; a tela do perfil lê o resto pelo id.
    private static func perfilResumido(_ cartao: CartaoProfissional) -> PerfilPublico {
        PerfilPublico(id: cartao.id, tipo: .profissional, nome: cartao.nome, funcoes: [cartao.servico.funcao.nome],
                      reputacao: cartao.reputacao)
    }

    private static func texto(_ resultado: ResultadoDaChamadaDaBusca) -> String {
        switch resultado {
        case .enviada: TextosBuscaDeProfissionais.resultadoEnviada
        case .pedeConfirmacaoDeRecorrencia: TextosBuscaDeProfissionais.resultadoPedeConfirmacao
        case let .erro(mensagem): mensagem
        case .naoEnviada: TextosBuscaDeProfissionais.resultadoNaoEnviada
        case let .pedeConfirmacaoDosTermos(termos):
            // 0.2.95: espera a casa confirmar os termos da vaga já aberta (a folha abaixo).
            String(localized: "Esta chamada vai com os termos da vaga já aberta: \(TelaTermosDaVagaAbertaProvisoria.linha(termos))",
                   bundle: bundleApresentacao)
        }
    }

    // MARK: Ações

    private func carregarCatalogo() async {
        guard !catalogoCarregado else { return }
        let api = api
        let id = estabelecimentoID
        catalogoComErro = false
        guard let dados = try? await PrazoDaAbertura.esperar(.seconds(15), {
            (try await api.funcoes(), try await api.regioesAdministrativas(), try await api.meuEstabelecimento(id: id))
        }) else {
            // Sem o catálogo o Buscar não liga: mostra o erro e deixa tentar de novo.
            catalogoComErro = true
            return
        }
        funcoes = dados.0
        regioes = dados.1.filter { $0.ativo != false }
        casa = dados.2
        if viewModel.funcaoID == nil { viewModel.funcaoID = funcoes.first?.id }
        catalogoCarregado = true
    }

    private func buscar() async {
        viewModel.horario = usarHorario ? try? Periodo(inicio: inicio, fim: fim) : nil
        await viewModel.buscar()
    }

    /// Pode chamar agora: com envio registrado o reenvio não precisa da casa nem da folha.
    private var podeChamarAgora: Bool {
        viewModel.podeChamar && (viewModel.temEnvioRegistrado || casa != nil)
    }

    /// 1º envio do serviço buscado: abre a folha. Depois dele (pendente ou feito), reenvia o MESMO trabalho direto, sem
    /// folha nova: uma folha nova traria outro horário (agora + 24 h) e o servidor abriria uma 2ª vaga para quem ainda não
    /// foi chamado. Outro serviço é outro trabalho e abre a sua folha.
    private func chamarSelecionados() {
        if viewModel.temEnvioRegistrado {
            Task { await viewModel.reenviar() }
        } else {
            abrirChamada()
        }
    }

    private func abrirChamada() {
        guard let casa else { return }
        rascunhoDaChamada = RascunhoDaChamadaDaBusca(horario: usarHorario ? try? Periodo(inicio: inicio, fim: fim) : nil,
                                                      responsavel: casa.nome)
    }

    /// O trabalho leva o serviço da busca feita (o da lista), e não o do seletor, que pode ter mudado sem Buscar.
    private func enviarChamadas() async {
        guard let rascunho = rascunhoDaChamada, let casa, let funcaoID = viewModel.funcaoDaBusca,
              let trabalho = rascunho.trabalho(casa: casa, funcaoID: funcaoID) else { return }
        rascunhoDaChamada = nil
        await viewModel.chamar(trabalho: trabalho, recado: rascunho.recadoOuNada)
    }

    private func reenviarComJ7() async {
        await viewModel.reenviar(confirmoRecorrencia: true)
    }
}

/// A folha "Chamar profissionais" da busca: valor total, horário, responsável e recado, iguais para cada pessoa escolhida.
/// O que falta e o botão laranja "Enviar chamadas" ficam ancorados embaixo.
private struct FolhaDeChamadaDaBusca: View {
    private enum Campo: Hashable { case valor, responsavel, recado }

    @Bindable var rascunho: RascunhoDaChamadaDaBusca
    let fechar: () -> Void
    let enviar: () -> Void
    @FocusState private var campoEmFoco: Campo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    Text(verbatim: TextosBuscaDeProfissionais.folhaExplicacao)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    campo(TextosChamadaDireta.valor) {
                        CampoFrila(verbatim: TextosChamadaDireta.valor, texto: $rascunho.valorTexto, emFoco: campoEmFoco == .valor)
                            .focused($campoEmFoco, equals: .valor)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("busca-valor-total")
                    }
                    FrilaGrupoDeLinhas(linhasComIcone: false) {
                        Toggle(isOn: $rascunho.totalConfirmado) {
                            Text(verbatim: TextosChamadaDireta.total).font(FrilaTipo.corpo)
                        }
                        .accessibilityIdentifier("busca-confirmo-total")
                        .modifier(LinhaDeControleDaCasa())
                    }
                    FrilaGrupoDeLinhas(linhasComIcone: false) {
                        DatePicker(selection: $rascunho.inicio) {
                            Text(verbatim: TextosBuscaDeProfissionais.inicio).font(FrilaTipo.corpo)
                        }
                        .modifier(LinhaDeControleDaCasa())
                        DatePicker(selection: $rascunho.fim) {
                            Text(verbatim: TextosBuscaDeProfissionais.termino).font(FrilaTipo.corpo)
                        }
                        .modifier(LinhaDeControleDaCasa())
                    }
                    campo(TextosChamadaDireta.responsavel) {
                        CampoFrila(verbatim: TextosChamadaDireta.responsavel, texto: $rascunho.responsavel,
                                   emFoco: campoEmFoco == .responsavel)
                            .focused($campoEmFoco, equals: .responsavel)
                            .accessibilityIdentifier("busca-responsavel")
                    }
                    campo(TextosChamadaDireta.recado) {
                        TextField(text: $rascunho.recado, axis: .vertical) { Text(verbatim: TextosChamadaDireta.recado) }
                            .textFieldStyle(.plain)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .lineLimit(3...6)
                            .focused($campoEmFoco, equals: .recado)
                            .caixaDoCampoFrila(emFoco: campoEmFoco == .recado)
                    }
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.item)
                .padding(.bottom, FrilaEspaco.grupo)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosBuscaDeProfissionais.folhaTitulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { fechar() } label: { Text(verbatim: TextosBuscaDeProfissionais.fechar) }
                }
            }
            .rodapeAncorado {
                if let falta = rascunho.oQueFalta {
                    Text(verbatim: falta)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                BotaoPrimario(verbatim: TextosBuscaDeProfissionais.enviarChamadas) { enviar() }
                    .disabled(!rascunho.podeEnviar)
                    .accessibilityIdentifier("busca-enviar-chamadas")
            }
        }
    }

    /// O rótulo visível acima do campo, em rótulo de grupo.
    private func campo<Conteudo: View>(_ rotulo: String, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: rotulo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            conteudo()
        }
    }
}
