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
    @State private var sheetFuncoesAberta = false
    @State private var raioKm: Double = 5.0
    @State private var diasSelecionados: Set<Int> = [6]
    @State private var periodosSelecionados: Set<String> = ["Noite"]

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
        .navigationTitle(viewModel.modo == .criacao ? "" : TextosDoProfissional.Perfil.titulo)
        .navigationBarTitleDisplayMode(viewModel.modo == .criacao ? .inline : .large)
        .sheet(isPresented: $sheetFuncoesAberta) {
            TelaEscolherFuncoes(
                funcoes: funcoesExibidas,
                selecionadas: viewModel.funcoesSelecionadas,
                alternar: { viewModel.alternarFuncao($0) }
            )
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
        if viewModel.modo == .criacao {
            formularioCriacaoT1
        } else {
            secaoFuncoes
            if viewModel.modo == .edicao && viewModel.suportaPerfilRico {
                NavigationLink {
                    TelaEditarServicos(modelo: viewModel.editorDeServicos())
                } label: {
                    // V18: a mesma linha da vizinha "Editar apresentação e regiões", com subtítulo e seta.
                    HStack {
                        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                            Text("Editar serviços", bundle: bundleApresentacao)
                                .font(FrilaTipo.corpo.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)
                            Text("Valores, unidade de preço e o que está incluído", bundle: bundleApresentacao)
                                .font(FrilaTipo.nota)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, FrilaEspaco.pequeno)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editar-servicos")

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
    }

    // MARK: - Formulário Criação T1

    @ViewBuilder
    private var formularioCriacaoT1: some View {
        ilustracaoPlaceholder
        cabecalhoT1
        secaoFuncoesT1
        secaoPontoBaseT1
        secaoDiasT1
        secaoPeriodosT1
    }

    private var ilustracaoPlaceholder: some View {
        RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
            .strokeBorder(FrilaCor.borda, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
            .aspectRatio(171.0 / 56.0, contentMode: .fit)
            .accessibilityHidden(true)
    }

    private var cabecalhoT1: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text("Onde e quando você quer faturar?", bundle: bundleApresentacao)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            Text("Para ver vagas, basta o ponto base. O resto dá para mudar depois, no Perfil.", bundle: bundleApresentacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var funcoesPrincipais: [Funcao] {
        let canonical = ["Bartender", "Garçom", "Auxiliar de cozinha", "Caixa"]
        let encontradas = canonical.compactMap { nome in
            funcoesExibidas.first { $0.nome.localizedCaseInsensitiveCompare(nome) == .orderedSame }
        }
        if !encontradas.isEmpty { return encontradas }
        return Array(funcoesExibidas.prefix(4))
    }

    private var secaoFuncoesT1: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Funções", bundle: bundleApresentacao)
                .font(FrilaTipo.nota.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    ForEach(funcoesPrincipais) { funcao in
                        let selecionada = viewModel.funcoesSelecionadas.contains(funcao.id)
                        Button {
                            viewModel.alternarFuncao(funcao.id)
                        } label: {
                            Text(verbatim: funcao.nome)
                                .font(FrilaTipo.meta.weight(.medium))
                                .padding(.horizontal, FrilaEspaco.faixa)
                                .frame(height: 36)
                                .foregroundStyle(selecionada ? FrilaCor.sobreSelecao : FrilaCor.texto)
                                .background(selecionada ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
                                .overlay(Capsule().strokeBorder(selecionada ? Color.clear : FrilaCor.borda, lineWidth: 1))
                                .animation(FrilaMovimento.animacao(FrilaMovimento.transicaoDeEstado, reduzir: reduzirMovimento), value: selecionada)
                                .frame(minHeight: FrilaMetrica.alvoMinimo)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selecionada ? .isSelected : [])
                    }
                }
            }

            Button {
                sheetFuncoesAberta = true
            } label: {
                Text("Ver todas as funções", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo)
                    .underline()
                    .foregroundStyle(FrilaCor.texto)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("botao-expandir-funcoes")
        }
    }

    private var secaoPontoBaseT1: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.pontoBase)
                .font(FrilaTipo.nota.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.pontoBase))
                .accessibilityAddTraits(.isHeader)
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

            if viewModel.pontoBaseForaDoDF {
                AvisoForaDoDF(texto: TextosDeCobertura.profissional, identificador: "aviso-ponto-base-fora-do-df")
            }

            HStack(spacing: FrilaEspaco.medio) {
                Slider(value: $raioKm, in: 1...10, step: 1)
                    .accessibilityLabel(Text("Raio", bundle: bundleApresentacao))
                    .accessibilityValue(String(localized: "Até \(Int(raioKm)) km", bundle: bundleApresentacao))
                    .accessibilityIdentifier("slider-raio")
                Text("Até \(Int(raioKm)) km", bundle: bundleApresentacao)
                    .font(FrilaTipo.corpo.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .frame(minWidth: 80, alignment: .trailing)
            }
            .padding(.top, FrilaEspaco.minimo)
        }
    }

    private let diasAbreviados = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    private let diasCompletos = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"]

    private var secaoDiasT1: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Dias", bundle: bundleApresentacao)
                .font(FrilaTipo.nota.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<7) { dia in
                        let selecionado = diasSelecionados.contains(dia)
                        Button {
                            if diasSelecionados.contains(dia) {
                                diasSelecionados.remove(dia)
                            } else {
                                diasSelecionados.insert(dia)
                            }
                        } label: {
                            Text(verbatim: diasAbreviados[dia])
                                .font(FrilaTipo.nota.weight(.medium))
                                .frame(width: 44, height: 40)
                                .foregroundStyle(selecionado ? FrilaCor.sobreSelecao : FrilaCor.texto)
                                .background(selecionado ? FrilaCor.selecao : FrilaCor.superficie, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1))
                                .animation(FrilaMovimento.animacao(FrilaMovimento.transicaoDeEstado, reduzir: reduzirMovimento), value: selecionado)
                                .frame(minHeight: FrilaMetrica.alvoMinimo)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: diasCompletos[dia]))
                        .accessibilityAddTraits(selecionado ? .isSelected : [])
                    }
                }
            }
        }
    }

    private let periodosDisponiveis = ["Manhã", "Tarde", "Noite", "Madrugada"]

    private var secaoPeriodosT1: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Períodos", bundle: bundleApresentacao)
                .font(FrilaTipo.nota.weight(.semibold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("titulo-secao-horarios")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FrilaEspaco.pequeno) {
                    ForEach(periodosDisponiveis, id: \.self) { periodo in
                        let selecionado = periodosSelecionados.contains(periodo)
                        Button {
                            if periodosSelecionados.contains(periodo) {
                                periodosSelecionados.remove(periodo)
                            } else {
                                periodosSelecionados.insert(periodo)
                            }
                        } label: {
                            Text(verbatim: periodo)
                                .font(FrilaTipo.meta.weight(.medium))
                                .padding(.horizontal, FrilaEspaco.faixa)
                                .frame(height: 36)
                                .foregroundStyle(selecionado ? FrilaCor.sobreSelecao : FrilaCor.texto)
                                .background(selecionado ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
                                .overlay(Capsule().strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1))
                                .animation(FrilaMovimento.animacao(FrilaMovimento.transicaoDeEstado, reduzir: reduzirMovimento), value: selecionado)
                                .frame(minHeight: FrilaMetrica.alvoMinimo)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selecionado ? .isSelected : [])
                    }
                }
            }
        }
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

            if viewModel.pontoBaseForaDoDF {
                AvisoForaDoDF(texto: TextosDeCobertura.profissional, identificador: "aviso-ponto-base-fora-do-df")
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
                    ? String(localized: "Ver vagas na minha área", bundle: bundleApresentacao)
                    : TextosDoProfissional.Perfil.salvarEdicao,
                carregando: viewModel.salvando
            ) {
                // Um horário com só um dos lados escolhido nunca é gravado por conta própria: a pessoa completa ou descarta.
                if viewModel.modo == .edicao && rascunhoDeHorarioIncompleto {
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
