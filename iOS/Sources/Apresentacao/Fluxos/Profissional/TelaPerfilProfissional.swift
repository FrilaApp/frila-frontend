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
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                conteudoDoCorpo
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tela-perfil-profissional")
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.compacto)
            .padding(.bottom, FrilaEspaco.grande)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .frilaKeyboardDismissScope()
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Perfil.titulo))
        .navigationBarTitleDisplayMode(.large)
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
        .barraInferiorFixa(ativa: temFormulario) {
            barraInferiorConteudo
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
                .padding(.top, FrilaEspaco.enorme)
        } else if viewModel.mensagemDeErro != nil && viewModel.funcoesDisponiveis.isEmpty {
            estadoErroCarga(viewModel.mensagemDeErro ?? "")
        } else {
            formularioViews
        }
    }

    @ViewBuilder
    private var formularioViews: some View {
        secaoFuncoes
        if viewModel.modo == .edicao {
            NavigationLink {
                TelaApresentacaoERegioes(api: viewModel.apiCliente)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                        Text(verbatim: TextosApresentacaoERegioes.editarApresentacao)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                        Text(verbatim: TextosApresentacaoERegioes.linkApresentacaoSubtitulo)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .padding(.vertical, FrilaEspaco.pequeno)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("link-editar-apresentacao")
        }
        secaoPontoBase
        secaoHorarios
    }

    // MARK: - Estado de erro de carga

    private func estadoErroCarga(_ erro: String) -> some View {
        VStack(spacing: FrilaEspaco.medio) {
            ZStack {
                Circle()
                    .fill(FrilaCor.controle)
                    .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                Image(systemName: "exclamationmark.triangle")
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityHidden(true)
            }

            Text(verbatim: TextosDoProfissional.Perfil.erroCarregarTela)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: erro)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("aviso-erro-perfil")

            BotaoPrimario(verbatim: TextosDoProfissional.Perfil.tentarDeNovo) {
                Task { await viewModel.carregar() }
            }
            .accessibilityIdentifier("perfil-tentar-carregar")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, FrilaEspaco.enorme)
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

    private var secaoPontoBase: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.pontoBase)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.pontoBase))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("titulo-secao-ponto-base")

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
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
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.sugestoes.prefix(5).enumerated()), id: \.offset) { index, item in
                        Button {
                            viewModel.selecionarSugestao(item)
                        } label: {
                            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                                Text(verbatim: item.name ?? "")
                                    .font(FrilaTipo.meta.weight(.semibold))
                                    .foregroundStyle(FrilaCor.texto)
                                if let title = item.placemark.title {
                                    Text(verbatim: title)
                                        .font(FrilaTipo.nota)
                                        .foregroundStyle(FrilaCor.textoSecundario)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                            .padding(.horizontal, FrilaEspaco.medio)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sugestao-endereco-\(index)")

                        if index < min(viewModel.sugestoes.count, 5) - 1 {
                            Divider()
                                .overlay(FrilaCor.divisoria)
                                .padding(.leading, FrilaEspaco.medio)
                        }
                    }
                }
                .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                        .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1)
                )
            }

            if viewModel.pontoBase != nil {
                Label {
                    Text(verbatim: TextosDoProfissional.Perfil.pontoBaseSalvo)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("label-ponto-base-selecionado")
            }
            }

            // A ajuda fica a 4 pt do campo: proximidade diz que ela explica o campo e não o bloco seguinte.
            Text(verbatim: TextosDoProfissional.Perfil.dicaPontoBase)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var secaoHorarios: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            HStack(spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Perfil.secaoHorarios)
                    .font(FrilaTipo.microRotulo)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.secaoHorarios))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("titulo-secao-horarios")
                Spacer(minLength: FrilaEspaco.pequeno)
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
                .frame(width: 28, height: 28)
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

    // MARK: - Barra inferior fixa

    private var barraInferiorConteudo: some View {
        VStack(spacing: FrilaEspaco.compacto) {
            #if DEBUG
            if let erro = viewModel.mensagemDeErro, (!viewModel.funcoesDisponiveis.isEmpty || estadoCapturaDebug != nil) {
                avisoErroValidacao(erro)
            }
            #else
            if let erro = viewModel.mensagemDeErro, !viewModel.funcoesDisponiveis.isEmpty {
                avisoErroValidacao(erro)
            }
            #endif

            if viewModel.sucesso {
                AvisoFrila(verbatim: TextosDoProfissional.Perfil.perfilSalvoComSucesso, tom: .informativo)
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
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
        .frame(maxWidth: .infinity)
    }

    private func avisoErroValidacao(_ erro: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            Text(verbatim: erro)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                .strokeBorder(FrilaCor.texto, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .modifier(AnunciarAoAparecer(anuncio: .init(texto: erro, tom: .erro)))
        .accessibilityIdentifier("aviso-erro-perfil")
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

// MARK: - Barra inferior fixa

private extension View {
    @ViewBuilder
    func barraInferiorFixa<Content: View>(ativa: Bool, @ViewBuilder conteudo: () -> Content) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) {
                if ativa {
                    conteudo()
                }
            }
        } else {
            if ativa {
                safeAreaInset(edge: .bottom, spacing: 0) {
                    conteudo()
                        .background(.regularMaterial)
                }
            } else {
                self
            }
        }
    }
}
