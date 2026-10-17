import FrilaDominio
import MapKit
import SwiftUI

/// Cadastro e edição do perfil profissional (#98): funções, ponto base e grade semanal, nos quadros
/// "MeuPerfil", "Disponibilidade" e "EditarDisponibilidade" do MidFi do Fabrício (cartões brancos com
/// rótulo em caixa alta, campos de 52 pt e botão escuro).
public struct TelaPerfilProfissional: View {
    // `@State`: o modelo vive com a tela. A tela de cima recria este valor a cada redesenho, e sem
    // isso o formulário já carregado seria trocado por um modelo novo, vazio.
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

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if viewModel.carregando {
                    EstadoCarregando()
                } else {
                    secaoCabecalho
                    secaoFuncoes
                    secaoPontoBase
                    secaoHorarios
                    secaoAviso

                    if let erro = viewModel.mensagemDeErro {
                        AvisoFrila(verbatim: erro, tom: .erro)
                            .accessibilityIdentifier("aviso-erro-perfil")

                        if viewModel.funcoesDisponiveis.isEmpty {
                            BotaoSecundario("Tentar novamente") {
                                Task { await viewModel.carregar() }
                            }
                            .accessibilityIdentifier("perfil-tentar-carregar")
                        }
                    }

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
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Perfil.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        // Funções e horários salvos é o momento de explicar a notificação a quem trabalha (#8): é
        // com eles que as vagas passam a chegar.
        .onChange(of: viewModel.sucesso) { _, salvou in
            if salvou { Task { await permissaoDePush?.oferecer() } }
        }
        .accessibilityIdentifier("tela-perfil-profissional")
    }

    // MARK: - Subviews

    private var secaoCabecalho: some View {
        Text(verbatim: TextosDoProfissional.Perfil.cabecalho)
            .font(FrilaTipo.tituloGrande)
            .foregroundStyle(FrilaCor.texto)
            .padding(.horizontal, FrilaEspaco.minimo)
            .accessibilityAddTraits(.isHeader)
    }

    private var secaoFuncoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            Text(verbatim: TextosDoProfissional.Perfil.secaoFuncoes)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: FrilaEspaco.pequeno)],
                spacing: FrilaEspaco.pequeno
            ) {
                ForEach(viewModel.funcoesDisponiveis) { funcao in
                    FiltroPill(
                        verbatim: funcao.nome,
                        selecionado: viewModel.funcoesSelecionadas.contains(funcao.id)
                    ) {
                        viewModel.alternarFuncao(funcao.id)
                    }
                    .accessibilityIdentifier("pill-funcao-\(funcao.id)")
                }
            }
        }
        .cartaoFrila()
    }

    private var secaoPontoBase: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            Text(verbatim: TextosDoProfissional.Perfil.pontoBase)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)

            HStack(spacing: FrilaEspaco.pequeno) {
                CampoFrila(verbatim: TextosDoProfissional.Perfil.buscarPontoBase, texto: $viewModel.enderecoTexto)
                    .accessibilityIdentifier("campo-ponto-base")
                    .onSubmit { Task { await viewModel.buscarEndereco() } }

                Button {
                    Task { await viewModel.buscarEndereco() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FrilaCor.sobrePrimaria)
                        .frame(width: FrilaMetrica.alturaDoCampo, height: FrilaMetrica.alturaDoCampo)
                        .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.buscar))
                .accessibilityIdentifier("botao-buscar-endereco")
            }

            Text(verbatim: TextosDoProfissional.Perfil.dicaPontoBase)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)

            if viewModel.carregandoBusca {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if !viewModel.sugestoes.isEmpty {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
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
                            .padding(.vertical, FrilaEspaco.minimo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sugestao-endereco-\(index)")
                        if index < min(viewModel.sugestoes.count, 5) - 1 {
                            Divider().overlay(FrilaCor.divisoria)
                        }
                    }
                }
                .padding(FrilaEspaco.pequeno)
                .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            }

            if viewModel.pontoBase != nil {
                Label {
                    Text(verbatim: viewModel.descricaoPontoBase ?? TextosDoProfissional.Perfil.pontoBaseSalvo)
                } icon: {
                    Image(systemName: "mappin.circle.fill")
                }
                .font(FrilaTipo.nota.weight(.medium))
                .foregroundStyle(FrilaCor.sucesso)
                .accessibilityIdentifier("label-ponto-base-selecionado")
            }
        }
        .cartaoFrila()
    }

    private var secaoHorarios: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            Text(verbatim: TextosDoProfissional.Perfil.secaoHorarios)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)

            if viewModel.disponibilidades.isEmpty {
                Text(verbatim: TextosDoProfissional.Perfil.nenhumHorario)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            } else {
                VStack(spacing: FrilaEspaco.minimo) {
                    ForEach(viewModel.disponibilidades, id: \.self) { janela in
                        let formatado = viewModel.formatarJanela(janela)
                        let linhaLayout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FrilaEspaco.minimo))
                            : AnyLayout(HStackLayout())
                        linhaLayout {
                            Text(verbatim: formatado.dia)
                                .font(FrilaTipo.meta.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)
                            if !dynamicTypeSize.isAccessibilitySize {
                                Spacer()
                            }
                            HStack {
                                Text(verbatim: formatado.horario)
                                    .font(FrilaTipo.meta)
                                    .monospacedDigit()
                                    .foregroundStyle(FrilaCor.textoSecundario)
                                Spacer()
                                Button {
                                    viewModel.removerJanela(janela)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(FrilaCor.perigo)
                                        .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .accessibilityLabel(String(localized: "Remover horário de \(formatado.dia)", bundle: bundleApresentacao))
                                .accessibilityIdentifier("remover-janela-\(janela.diaDaSemana)-\(janela.inicio.contrato)")
                            }
                        }
                        .padding(.vertical, FrilaEspaco.minimo)
                        Divider().overlay(FrilaCor.divisoria)
                    }
                }
            }

            // Bloco de Adicionar Horário
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Perfil.adicionarHorario)
                    .font(FrilaTipo.rotuloDoCampo)
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
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: FrilaEspaco.minimo)
                        Image(systemName: "chevron.up.chevron.down")
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(TextosDoProfissional.Perfil.diaSemana)
                .accessibilityValue(PerfilProfissionalViewModel.nomeDoDia(viewModel.diaNovo))
                .accessibilityIdentifier("picker-dia-semana")

                HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                        Text(verbatim: TextosDoProfissional.Perfil.inicio)
                            .font(FrilaTipo.rotuloDoCampo)
                            .foregroundStyle(FrilaCor.texto)
                        DatePicker(selection: $viewModel.inicioNovo, displayedComponents: .hourAndMinute) {
                            Text(verbatim: TextosDoProfissional.Perfil.inicio)
                        }
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 248 : 216)
                        .clipShape(.rect)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("campo-hora-inicio")
                    }
                    VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                        Text(verbatim: TextosDoProfissional.Perfil.fim)
                            .font(FrilaTipo.rotuloDoCampo)
                            .foregroundStyle(FrilaCor.texto)
                        DatePicker(selection: $viewModel.fimNovo, displayedComponents: .hourAndMinute) {
                            Text(verbatim: TextosDoProfissional.Perfil.fim)
                        }
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 248 : 216)
                        .clipShape(.rect)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("campo-hora-fim")
                    }
                }

                Button {
                    viewModel.adicionarJanelaDoFormulario()
                } label: {
                    Text(verbatim: TextosDoProfissional.Perfil.adicionar)
                        .font(FrilaTipo.botao)
                        .padding(.horizontal, FrilaEspaco.medio)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: FrilaMetrica.alvoMinimo)
                        .background(FrilaCor.primaria, in: Capsule())
                        .foregroundStyle(FrilaCor.sobrePrimaria)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(TextosDoProfissional.Perfil.adicionarHorario)
                .accessibilityIdentifier("botao-adicionar-janela")
            }
            .padding(FrilaEspaco.compacto)
            .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
        }
        .cartaoFrila()
    }

    private var secaoAviso: some View {
        AvisoFrila(verbatim: TextosDoProfissional.Perfil.avisoFixo, tom: .informativo)
            .accessibilityIdentifier("aviso-fixo-perfil")
    }
}
