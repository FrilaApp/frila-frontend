// BAIXA FIDELIDADE DESCARTÁVEL: não é design final (#98).
// Interface provisória para cadastro/edição do perfil profissional (funções, ponto base e grade semanal).

import FrilaDominio
import MapKit
import SwiftUI

public struct TelaPerfilProfissional: View {
    @Bindable private var viewModel: PerfilProfissionalViewModel
    @State private var diaNovo: Int = 5 // Sexta-feira padrão
    @State private var inicioNovo: String = "18:00"
    @State private var fimNovo: String = "02:00"
    @State private var erroFormatoJanela: String?
    @Environment(PermissaoDePushModelo.self) private var permissaoDePush: PermissaoDePushModelo?

    public init(viewModel: PerfilProfissionalViewModel) {
        self.viewModel = viewModel
    }

    public init(api: any ApiCliente, modo: PerfilProfissionalViewModel.Modo = .criacao) {
        self.viewModel = PerfilProfissionalViewModel(api: api, modo: modo)
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
                        Task { await viewModel.salvar() }
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
            .font(.title2.bold())
            .foregroundStyle(FrilaCor.texto)
            .accessibilityAddTraits(.isHeader)
    }

    private var secaoFuncoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.secaoFuncoes)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

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
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.pontoBase)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

            HStack(spacing: FrilaEspaco.pequeno) {
                CampoFrila(verbatim: TextosDoProfissional.Perfil.buscarPontoBase, texto: $viewModel.enderecoTexto)
                    .accessibilityIdentifier("campo-ponto-base")
                    .onSubmit { Task { await viewModel.buscarEndereco() } }

                Button {
                    Task { await viewModel.buscarEndereco() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FrilaCor.sobrePrimaria)
                        .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                        .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: TextosDoProfissional.Perfil.buscar))
                .accessibilityIdentifier("botao-buscar-endereco")
            }

            Text(verbatim: TextosDoProfissional.Perfil.dicaPontoBase)
                .font(.footnote)
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: item.name ?? "")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FrilaCor.texto)
                                if let title = item.placemark.title {
                                    Text(verbatim: title)
                                        .font(.caption)
                                        .foregroundStyle(FrilaCor.textoSecundario)
                                }
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sugestao-endereco-\(index)")
                        if index < min(viewModel.sugestoes.count, 5) - 1 {
                            Divider()
                        }
                    }
                }
                .padding(FrilaEspaco.pequeno)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
            }

            if viewModel.pontoBase != nil {
                Label {
                    Text(verbatim: viewModel.descricaoPontoBase ?? TextosDoProfissional.Perfil.pontoBaseSalvo)
                } icon: {
                    Image(systemName: "mappin.circle.fill")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(FrilaCor.sucesso)
                .accessibilityIdentifier("label-ponto-base-selecionado")
            }
        }
        .cartaoFrila()
    }

    private var secaoHorarios: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosDoProfissional.Perfil.secaoHorarios)
                .font(.headline)
                .foregroundStyle(FrilaCor.texto)

            if viewModel.disponibilidades.isEmpty {
                Text(verbatim: TextosDoProfissional.Perfil.nenhumHorario)
                    .font(.footnote)
                    .foregroundStyle(FrilaCor.textoSecundario)
            } else {
                VStack(spacing: FrilaEspaco.minimo) {
                    ForEach(viewModel.disponibilidades, id: \.self) { janela in
                        let formatado = viewModel.formatarJanela(janela)
                        HStack {
                            Text(verbatim: formatado.dia)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FrilaCor.texto)
                            Spacer()
                            Text(verbatim: formatado.horario)
                                .font(.subheadline)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Button {
                                viewModel.removerJanela(janela)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(FrilaCor.perigo)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Remover horário de \(formatado.dia)", bundle: bundleApresentacao))
                            .accessibilityIdentifier("remover-janela-\(janela.diaDaSemana)-\(janela.inicio.contrato)")
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }

            // Bloco de Adicionar Horário
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoProfissional.Perfil.adicionarHorario)
                    .font(.subheadline.bold())
                    .foregroundStyle(FrilaCor.texto)

                Picker(selection: $diaNovo) {
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
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("picker-dia-semana")

                HStack(spacing: FrilaEspaco.pequeno) {
                    CampoFrila(verbatim: TextosDoProfissional.Perfil.inicio, texto: $inicioNovo)
                        .accessibilityIdentifier("campo-hora-inicio")
                    CampoFrila(verbatim: TextosDoProfissional.Perfil.fim, texto: $fimNovo)
                        .accessibilityIdentifier("campo-hora-fim")
                }

                if let erroFormato = erroFormatoJanela {
                    Text(verbatim: erroFormato)
                        .font(.caption)
                        .foregroundStyle(FrilaCor.perigo)
                }

                Button {
                    do {
                        let inicio = try HoraDoDia(inicioNovo.trimmingCharacters(in: .whitespaces))
                        let fim = try HoraDoDia(fimNovo.trimmingCharacters(in: .whitespaces))
                        guard inicio != fim else {
                            erroFormatoJanela = TextosDoProfissional.Perfil.erroJanelaDuracaoZero
                            return
                        }
                        viewModel.adicionarJanela(diaDaSemana: diaNovo, inicio: inicio, fim: fim)
                        erroFormatoJanela = nil
                    } catch {
                        erroFormatoJanela = TextosDoProfissional.Perfil.erroHorarioInvalido
                    }
                } label: {
                    Text(verbatim: TextosDoProfissional.Perfil.adicionar)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, FrilaEspaco.medio)
                        .frame(minHeight: 36)
                        .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
                        .foregroundStyle(FrilaCor.sobrePrimaria)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("botao-adicionar-janela")
            }
            .padding(FrilaEspaco.pequeno)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
        }
        .cartaoFrila()
    }

    private var secaoAviso: some View {
        AvisoFrila(verbatim: TextosDoProfissional.Perfil.avisoFixo, tom: .informativo)
            .accessibilityIdentifier("aviso-fixo-perfil")
    }
}
