import FrilaDominio
import MapKit
import SwiftUI

/// Cadastro e edição do perfil profissional (#98): funções, ponto base e grade semanal, nos quadros
/// "MeuPerfil", "Disponibilidade" e "EditarDisponibilidade" do MidFi do Fabrício.
public struct TelaPerfilProfissional: View {
    @State private var viewModel: PerfilProfissionalViewModel
    private let aoSalvar: () -> Void
    @State private var infoDeHorariosAberta = false
    @State private var rascunhoDeHorarioIncompleto = false
    /// Pedido, vindo do editor de horários, para rolar até ele quando abre e o botão fixo o cobriria.
    @State private var pedidoDeRolagem: String?
    @State private var avisoDeRascunhoDeHorario = false
    @State private var abrirServicos = false
    @State private var abrirApresentacao = false
    @FocusState private var focoNoPontoBase: Bool
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(PermissaoDePushModelo.self) private var permissaoDePush: PermissaoDePushModelo?

    public init(viewModel: PerfilProfissionalViewModel, aoSalvar: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.aoSalvar = aoSalvar
    }

    public init(api: any ApiCliente, modo: PerfilProfissionalViewModel.Modo = .criacao, aoSalvar: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: PerfilProfissionalViewModel(api: api, modo: modo))
        self.aoSalvar = aoSalvar
    }

    private var temFormulario: Bool {
        #if DEBUG
        if let estado = estadoCapturaDebug {
            return estado != "carga-erro"
        }
        #endif
        return !viewModel.carregando && (viewModel.mensagemDeErro == nil || !viewModel.funcoesDisponiveis.isEmpty)
    }

    public var body: some View {
        ScrollViewReader { leitor in
            corpoComRolagem
                .onChange(of: pedidoDeRolagem) { _, id in
                    guard let id else { return }
                    withAnimation(FrilaMovimento.animacao(FrilaMotion.horarioExpandir, reduzir: FrilaMovimentoReduzido.ativo)) {
                        leitor.scrollTo(id, anchor: .bottom)
                    }
                    pedidoDeRolagem = nil
                }
        }
    }

    private var corpoComRolagem: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                conteudoDoCorpo
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tela-perfil-profissional")
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .frilaKeyboardDismissScope()
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Perfil.titulo))
        .tituloGrandeForaDeAX()
        .navigationDestination(isPresented: $abrirServicos) {
            TelaEditarServicos(modelo: viewModel.editorDeServicos())
        }
        .navigationDestination(isPresented: $abrirApresentacao) {
            TelaApresentacaoERegioes(api: viewModel.apiCliente)
        }
        .task {
            #if DEBUG
            if estadoCapturaDebug != nil {
                aplicarEstadoCapturaSeNecessario()
                return
            }
            #endif
            await viewModel.carregar()
        }
        .onChange(of: viewModel.sucesso) { _, salvou in
            if salvou { Task { await permissaoDePush?.oferecer() } }
        }
        .rodapeAncoradoDoPerfilSe(temFormulario) {
            rodapeDoPerfil
        }
        .onAppear {
            #if DEBUG
            aplicarEstadoCapturaSeNecessario()
            #endif
        }
        #if DEBUG
        .onChange(of: viewModel.carregando) { _, carregando in
            if !carregando {
                aplicarEstadoCapturaSeNecessario()
            }
        }
        #endif
    }

    @ViewBuilder
    private var conteudoDoCorpo: some View {
        #if DEBUG
        if let estado = estadoCapturaDebug {
            if estado == "carga-erro" {
                estadoErroCarga(TextosDoProfissional.Perfil.erroCarregarTela)
            } else {
                formularioViews
            }
        } else {
            conteudoProducao
        }
        #else
        conteudoProducao
        #endif
    }

    @ViewBuilder
    private var conteudoProducao: some View {
        if viewModel.carregando {
            EstadoCarregando()
                .padding(.top, FrilaEspaco.secao)
        } else if viewModel.mensagemDeErro != nil && viewModel.funcoesDisponiveis.isEmpty {
            estadoErroCarga(viewModel.mensagemDeErro ?? "")
        } else {
            formularioViews
        }
    }

    @ViewBuilder
    private var formularioViews: some View {
        secaoFuncoes
        if viewModel.modo == .edicao && viewModel.suportaPerfilRico {
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                FrilaLinhaDeOpcao(
                    titulo: String(localized: "Editar serviços", bundle: bundleApresentacao),
                    subtitulo: String(localized: "Valores, unidade de preço e o que está incluído", bundle: bundleApresentacao),
                    remate: .navega
                ) { abrirServicos = true }
                .accessibilityIdentifier("editar-servicos")

                FrilaLinhaDeOpcao(
                    titulo: TextosApresentacaoERegioes.editarApresentacao,
                    subtitulo: TextosApresentacaoERegioes.linkApresentacaoSubtitulo,
                    remate: .navega
                ) { abrirApresentacao = true }
                .accessibilityIdentifier("link-editar-apresentacao")
            }
        }
        secaoPontoBase
        secaoHorarios
    }

    // MARK: - Estado de erro de carga

    /// O mesmo desenho do `EstadoErro` (fato em corpo, dica em apoio, "tentar de novo" em botão secundário), com os
    /// identificadores que a tela já tinha: o aviso do erro e o botão que carrega de novo.
    private func estadoErroCarga(_ erro: String) -> some View {
        VStack(spacing: FrilaEspaco.item) {
            Text(verbatim: TextosDoProfissional.Perfil.erroCarregarTela)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: erro)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("aviso-erro-perfil")
            BotaoSecundario(verbatim: TextosDoProfissional.Perfil.tentarDeNovo) {
                Task { await viewModel.carregar() }
            }
            .accessibilityIdentifier("perfil-tentar-carregar")
            .padding(.top, FrilaEspaco.item)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, FrilaEspaco.respiro)
    }

    // MARK: - Subviews do formulário

    /// Sem título de seção: "Escolher funções" e "2 funções selecionadas" já dizem o que o bloco é, e a
    /// tela se chama "Funções e horários".
    private var secaoFuncoes: some View {
        SecaoDeFuncoes(
            funcoes: funcoesExibidas,
            selecionadas: viewModel.funcoesSelecionadas,
            alternar: { viewModel.alternarFuncao($0) }
        )
    }

    private var funcoesExibidas: [Funcao] {
        #if DEBUG
        if !viewModel.funcoesDisponiveis.isEmpty {
            return viewModel.funcoesDisponiveis
        }
        if estadoCapturaDebug != nil {
            return [
                Funcao(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão"),
                Funcao(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, nome: "Bartender", categoria: "Bar"),
                Funcao(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, nome: "Cozinheiro", categoria: "Cozinha"),
                Funcao(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, nome: "Cumim", categoria: "Salão"),
                Funcao(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, nome: "Recepcionista", categoria: "Salão")
            ]
        }
        #endif
        return viewModel.funcoesDisponiveis
    }

    /// Nome de seção: 600 de 15 pt em `textoSecundario`, frase normal (DESIGN.md, "Rótulo de grupo").
    private func rotuloDeSecao(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.rotuloDeGrupo)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var secaoPontoBase: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            rotuloDeSecao(TextosDoProfissional.Perfil.pontoBase)
                .accessibilityIdentifier("titulo-secao-ponto-base")

            FrilaSearchBar(
                texto: $viewModel.enderecoTexto,
                foco: $focoNoPontoBase,
                icone: "mappin",
                rotulo: TextosDoProfissional.Perfil.buscarPontoBase,
                idDoCampo: "perfil_ponto_base",
                identificador: "campo-ponto-base",
                submitLabel: .search,
                acao: FrilaSearchBarAcao(
                    icone: "magnifyingglass",
                    rotulo: TextosDoProfissional.Perfil.buscar,
                    identificador: "botao-buscar-endereco",
                    carregando: viewModel.carregandoBusca
                ) {
                    Task { await viewModel.buscarEndereco() }
                },
                aoEnviar: { Task { await viewModel.buscarEndereco() } }
            )

            if !viewModel.sugestoes.isEmpty {
                FrilaGrupoDeLinhas {
                    ForEach(Array(viewModel.sugestoes.prefix(5).enumerated()), id: \.offset) { index, item in
                        FrilaLinhaDeOpcao(icone: "mappin", titulo: item.name ?? "", subtitulo: item.placemark.title, remate: .nenhum) {
                            viewModel.selecionarSugestao(item)
                        }
                        .accessibilityIdentifier("sugestao-endereco-\(index)")
                    }
                }
            }

            if viewModel.pontoBase != nil {
                FrilaLinhaDeDado(icone: "checkmark") {
                    Text(verbatim: TextosDoProfissional.Perfil.pontoBaseSalvo)
                }
                .accessibilityIdentifier("label-ponto-base-selecionado")
            }

            if viewModel.pontoBaseForaDoDF {
                AvisoForaDoDF(texto: TextosDeCobertura.profissional, identificador: "aviso-ponto-base-fora-do-df")
            }

            // A ajuda fica junto do campo: proximidade diz que ela explica o campo e não o bloco seguinte.
            Text(verbatim: TextosDoProfissional.Perfil.dicaPontoBase)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var secaoHorarios: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            HStack(spacing: FrilaEspaco.item) {
                rotuloDeSecao(TextosDoProfissional.Perfil.secaoHorarios)
                    .accessibilityIdentifier("titulo-secao-horarios")
                Spacer(minLength: FrilaEspaco.item)
                botaoDeInfoDosHorarios
            }

            // O aviso não abre a tela: aparece quando a pessoa pede, no botão de informação do título.
            if infoDeHorariosAberta {
                infoDosHorarios
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            SecaoDeHorarios(
                viewModel: viewModel,
                rascunhoIncompleto: $rascunhoDeHorarioIncompleto,
                avisoDeRascunho: $avisoDeRascunhoDeHorario,
                pedidoDeRolagem: $pedidoDeRolagem
            )
        }
    }

    private var botaoDeInfoDosHorarios: some View {
        Button {
            let animacao = infoDeHorariosAberta ? FrilaMotion.disclosureCollapse : FrilaMotion.disclosureExpand
            withAnimation(FrilaMovimento.animacao(animacao, reduzir: reduzirMovimento)) {
                infoDeHorariosAberta.toggle()
            }
        } label: {
            Image(systemName: infoDeHorariosAberta ? "info.circle.fill" : "info.circle")
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(width: FrilaMetrica.alvo, height: FrilaMetrica.alvo)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.sobreOsHorarios))
        .accessibilityIdentifier("botao-info-horarios")
    }

    private var infoDosHorarios: some View {
        AvisoFrila(verbatim: TextosDoProfissional.Perfil.avisoFixo, tom: .informativo)
            .accessibilityIdentifier("info-horarios")
    }

    // MARK: - Rodapé ancorado

    /// Erro ou resultado da ação logo acima do botão (D-DS-13: problema não tem cor) e o botão primário, o único laranja.
    @ViewBuilder
    private var rodapeDoPerfil: some View {
        #if DEBUG
        if let erro = viewModel.mensagemDeErro, (!viewModel.funcoesDisponiveis.isEmpty || estadoCapturaDebug != nil) {
            MensagemJuntoAoBotao(verbatim: erro)
                .accessibilityIdentifier("aviso-erro-perfil")
        }
        #else
        if let erro = viewModel.mensagemDeErro, !viewModel.funcoesDisponiveis.isEmpty {
            MensagemJuntoAoBotao(verbatim: erro)
                .accessibilityIdentifier("aviso-erro-perfil")
        }
        #endif

        if viewModel.sucesso {
            MensagemJuntoAoBotao(verbatim: TextosDoProfissional.Perfil.perfilSalvoComSucesso)
                .accessibilityIdentifier("aviso-sucesso-perfil")
        }

        BotaoPrimario(
            verbatim: viewModel.modo == .criacao
                ? TextosDoProfissional.Perfil.salvarCriacao
                : TextosDoProfissional.Perfil.salvarEdicao,
            carregando: viewModel.salvando
        ) {
            // Um horário com só um dos lados escolhido nunca é gravado por conta própria: a pessoa completa ou descarta.
            if rascunhoDeHorarioIncompleto {
                avisoDeRascunhoDeHorario = true
                return
            }
            Task {
                if await viewModel.salvar() { aoSalvar() }
            }
        }
        .accessibilityIdentifier("botao-salvar-perfil")
    }

    // MARK: - Anexo B: Horário Curto

    private func horarioCurto(_ janela: JanelaDeDisponibilidade) -> String {
        let base = String(localized: "\(horaCurta(janela.inicio)) às \(horaCurta(janela.fim))", bundle: bundleApresentacao)
        guard janela.atravessaMeiaNoite else { return base }
        let indiceDiaSeguinte = (janela.diaDaSemana + 1) % 7
        let sufixoDia: String
        if (0..<TextosDoProfissional.Perfil.noDiaSeguinte.count).contains(indiceDiaSeguinte) {
            sufixoDia = TextosDoProfissional.Perfil.noDiaSeguinte[indiceDiaSeguinte]
        } else {
            sufixoDia = TextosDoProfissional.Perfil.diaSeguinte
        }
        return "\(base) \(sufixoDia)"
    }

    private func horaCurta(_ hora: HoraDoDia) -> String {
        hora.minuto == 0
            ? String(format: "%02dh", hora.hora)
            : String(format: "%02dh%02d", hora.hora, hora.minuto)
    }

    // MARK: - Ganchos DEBUG

    #if DEBUG
    private var estadoCapturaDebug: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let indice = args.firstIndex(of: "-FRILA_CAPTURA"),
              indice + 1 < args.count else { return nil }
        return args[indice + 1]
    }

    private func aplicarEstadoCapturaSeNecessario() {
        guard let estado = estadoCapturaDebug else { return }
        switch estado {
        case "normal", "vazio":
            if let primeira = funcoesExibidas.first {
                viewModel.funcoesSelecionadas = [primeira.id]
            }
            viewModel.mensagemDeErro = nil
        case "horarios":
            if let primeira = funcoesExibidas.first {
                viewModel.funcoesSelecionadas = [primeira.id]
            }
            if let coord = try? Coordenada(latitude: -15.8267, longitude: -47.9218) {
                viewModel.definirPontoBase(coord, nome: "Guará II, Brasília - DF")
            }
            if let inicio = try? HoraDoDia(hora: 18, minuto: 0),
               let fim = try? HoraDoDia(hora: 2, minuto: 0) {
                viewModel.adicionarJanela(diaDaSemana: 5, inicio: inicio, fim: fim)
                viewModel.adicionarJanela(diaDaSemana: 6, inicio: inicio, fim: fim)
            }
            viewModel.mensagemDeErro = nil
        case "erro":
            if let primeira = funcoesExibidas.first {
                viewModel.funcoesSelecionadas = [primeira.id]
            }
            viewModel.mensagemDeErro = TextosDoProfissional.Perfil.erroSemPontoBase
        case "carga-erro":
            viewModel.mensagemDeErro = TextosDoProfissional.Perfil.erroCarregarTela
        default:
            break
        }
    }
    #endif
}

// MARK: - Rodapé ancorado condicional

extension View {
    /// O rodapé só existe quando há formulário; sem ele (carregando ou erro de carga), a tela não ancora nada.
    @ViewBuilder
    func rodapeAncoradoDoPerfilSe<Conteudo: View>(_ ativo: Bool, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        if ativo {
            rodapeAncorado(conteudo)
        } else {
            self
        }
    }
}
