import FrilaDominio
import MapKit
import SwiftUI

/// Cadastro e edição do perfil profissional (#98): funções, ponto base e grade semanal, nos quadros
/// "MeuPerfil", "Disponibilidade" e "EditarDisponibilidade" do MidFi do Fabrício.
public struct TelaPerfilProfissional: View {
    @State private var viewModel: PerfilProfissionalViewModel
    private let aoSalvar: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                conteudoDoCorpo
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.pequeno)
            .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 140 : FrilaEspaco.grande)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
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
        secaoCabecalho
        secaoFuncoes
        secaoPontoBase
        secaoHorarios
        secaoAviso
    }

    // MARK: - Estado de erro de carga

    private func estadoErroCarga(_ erro: String) -> some View {
        VStack(spacing: FrilaEspaco.medio) {
            ZStack {
                Circle()
                    .fill(FrilaCor.controle)
                    .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityHidden(true)
            }

            Text(verbatim: TextosDoProfissional.Perfil.erroCarregarTela)
                .font(FrilaTipo.tituloDeEstado)
                .foregroundStyle(FrilaCor.texto)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("tela-perfil-profissional")

            Text(verbatim: erro)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
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

    private var secaoCabecalho: some View {
        Text(verbatim: TextosDoProfissional.Perfil.cabecalho)
            .font(FrilaTipo.subtituloDaTela)
            .foregroundStyle(FrilaCor.textoSecundario)
            .accessibilityIdentifier("tela-perfil-profissional")
    }

    private var secaoFuncoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.secaoFuncoes)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.horizontal, FrilaEspaco.medio)
                .accessibilityAddTraits(.isHeader)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 0) {
                        chipsDeFuncoes
                    }
                } else {
                    FluxoDeChips(espaco: FrilaEspaco.pequeno) {
                        chipsDeFuncoes
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.compacto)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                    .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
            )
        }
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

    @ViewBuilder
    private var chipsDeFuncoes: some View {
        ForEach(funcoesExibidas) { funcao in
            FiltroPill(
                verbatim: funcao.nome,
                selecionado: viewModel.funcoesSelecionadas.contains(funcao.id)
            ) {
                viewModel.alternarFuncao(funcao.id)
            }
            .accessibilityIdentifier("pill-funcao-\(funcao.id)")
        }
    }

    private var secaoPontoBase: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.pontoBase)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "mappin")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)

                TextField(
                    text: $viewModel.enderecoTexto,
                    prompt: Text(verbatim: TextosDoProfissional.Perfil.buscarPontoBase).foregroundStyle(FrilaCor.textoSecundario)
                ) {
                    Text(verbatim: TextosDoProfissional.Perfil.pontoBase)
                }
                .textFieldStyle(.plain)
                .font(FrilaTipo.valorDoCampo)
                .foregroundStyle(FrilaCor.texto)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.buscarEndereco() }
                }
                .accessibilityIdentifier("campo-ponto-base")

                Button {
                    Task { await viewModel.buscarEndereco() }
                } label: {
                    Group {
                        if viewModel.carregandoBusca {
                            ProgressView()
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                        }
                    }
                    .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.buscar))
                .accessibilityIdentifier("botao-buscar-endereco")
            }
            .padding(.leading, FrilaEspaco.medio)
            .padding(.trailing, FrilaEspaco.minimo)
            .frame(minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                    .strokeBorder(FrilaCor.borda, lineWidth: 1)
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
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                        .strokeBorder(FrilaCor.borda, lineWidth: 1)
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
                .padding(.horizontal, FrilaEspaco.medio)
                .accessibilityIdentifier("label-ponto-base-selecionado")
            }

            Text(verbatim: TextosDoProfissional.Perfil.dicaPontoBase)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.horizontal, FrilaEspaco.medio)
        }
    }

    private var secaoHorarios: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.secaoHorarios)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.horizontal, FrilaEspaco.medio)
                .accessibilityAddTraits(.isHeader)

            if viewModel.disponibilidades.isEmpty {
                AvisoFrila("**Sem horários disponíveis, você não recebe avisos de vagas.** Você pode definir seus horários depois.", tom: .informativo)
            } else {
                cartaoListaHorarios
            }

            cartaoNovoHorario
        }
    }

    private var cartaoListaHorarios: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.disponibilidades.enumerated()), id: \.element) { index, janela in
                linhaHorario(janela)
                if index < viewModel.disponibilidades.count - 1 {
                    Divider()
                        .overlay(FrilaCor.divisoria)
                }
            }
        }
        .padding(.leading, FrilaEspaco.medio)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
    }

    private func linhaHorario(_ janela: JanelaDeDisponibilidade) -> some View {
        let formatado = viewModel.formatarJanela(janela)
        let diaTexto: String = {
            if (0..<TextosDoProfissional.Perfil.diasCurtos.count).contains(janela.diaDaSemana) {
                return TextosDoProfissional.Perfil.diasCurtos[janela.diaDaSemana]
            }
            return formatado.dia
        }()

        return HStack(spacing: FrilaEspaco.pequeno) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: diaTexto)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                    Text(verbatim: horarioCurto(janela))
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .monospacedDigit()
                }
            } else {
                Text(verbatim: diaTexto)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                Spacer(minLength: FrilaEspaco.pequeno)
                Text(verbatim: horarioCurto(janela))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .monospacedDigit()
            }

            Button {
                viewModel.removerJanela(janela)
            } label: {
                Image(systemName: "trash")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "Remover horário de \(formatado.dia)", bundle: bundleApresentacao))
            .accessibilityIdentifier("remover-janela-\(janela.diaDaSemana)-\(janela.inicio.contrato)")
        }
        .frame(minHeight: FrilaMetrica.alturaDoCampo)
        .padding(.trailing, FrilaEspaco.minimo)
    }

    private var cartaoNovoHorario: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Perfil.diaSemana)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)

                Menu {
                    Picker(selection: $viewModel.diaNovo) {
                        Text(verbatim: TextosDoProfissional.Perfil.domingo).tag(0)
                        Text(verbatim: TextosDoProfissional.Perfil.segunda).tag(1)
                        Text(verbatim: TextosDoProfissional.Perfil.terca).tag(2)
                        Text(verbatim: TextosDoProfissional.Perfil.quarta).tag(3)
                        Text(verbatim: TextosDoProfissional.Perfil.quinta).tag(4)
                        Text(verbatim: TextosDoProfissional.Perfil.sexta).tag(5)
                        Text(verbatim: TextosDoProfissional.Perfil.sabado).tag(6)
                    } label: {
                        Text(verbatim: TextosDoProfissional.Perfil.diaSemana)
                    }
                } label: {
                    HStack {
                        Text(verbatim: PerfilProfissionalViewModel.nomeDoDia(viewModel.diaNovo))
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: FrilaEspaco.minimo)
                        Image(systemName: "chevron.down")
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityHidden(true)
                    }
                    .caixaDoCampoFrila()
                }
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.diaSemana))
                .accessibilityValue(PerfilProfissionalViewModel.nomeDoDia(viewModel.diaNovo))
                .accessibilityIdentifier("picker-dia-semana")
            }

            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: TextosDoProfissional.Perfil.inicio)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                    DatePicker(selection: $viewModel.inicioNovo, displayedComponents: .hourAndMinute) {
                        Text(verbatim: TextosDoProfissional.Perfil.inicio)
                    }
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 248 : 216)
                    .clipped()
                    .clipShape(.rect)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("campo-hora-inicio")
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: TextosDoProfissional.Perfil.fim)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                    DatePicker(selection: $viewModel.fimNovo, displayedComponents: .hourAndMinute) {
                        Text(verbatim: TextosDoProfissional.Perfil.fim)
                    }
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 248 : 216)
                    .clipped()
                    .clipShape(.rect)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("campo-hora-fim")
                }
            }

            BotaoSecundario(verbatim: TextosDoProfissional.Perfil.adicionarHorario) {
                viewModel.adicionarJanelaDoFormulario()
            }
            .accessibilityIdentifier("botao-adicionar-janela")
        }
        .cartaoFrila()
    }

    private var secaoAviso: some View {
        AvisoFrila(verbatim: TextosDoProfissional.Perfil.avisoFixo, tom: .informativo)
            .accessibilityIdentifier("aviso-fixo-perfil")
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
                Task {
                    if await viewModel.salvar() { aoSalvar() }
                }
            }
            .accessibilityIdentifier("botao-salvar-perfil")
        }
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? FrilaEspaco.pequeno : FrilaEspaco.medio)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? FrilaEspaco.minimo : FrilaEspaco.compacto)
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

// MARK: - Anexo A: Fluxo de Chips

private struct FluxoDeChips: Layout {
    var espaco: CGFloat = FrilaEspaco.pequeno

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        posicoes(subviews, largura: proposal.width ?? .infinity).tamanho
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let pontos = posicoes(subviews, largura: bounds.width).pontos
        for (subview, ponto) in zip(subviews, pontos) {
            subview.place(at: CGPoint(x: bounds.minX + ponto.x, y: bounds.minY + ponto.y), proposal: .unspecified)
        }
    }

    private func posicoes(_ subviews: Subviews, largura: CGFloat) -> (pontos: [CGPoint], tamanho: CGSize) {
        var pontos: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var alturaDaLinha: CGFloat = 0
        var larguraUsada: CGFloat = 0
        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x > 0, x + tamanho.width > largura {
                x = 0
                y += alturaDaLinha
                alturaDaLinha = 0
            }
            pontos.append(CGPoint(x: x, y: y))
            alturaDaLinha = max(alturaDaLinha, tamanho.height)
            larguraUsada = max(larguraUsada, x + tamanho.width)
            x += tamanho.width + espaco
        }
        return (pontos, CGSize(width: larguraUsada, height: y + alturaDaLinha))
    }
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
