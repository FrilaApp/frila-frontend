import FrilaDominio
import SwiftUI

public struct TelaApresentacaoERegioes: View {
    @State private var viewModel: ApresentacaoERegioesViewModel
    private let aoSalvar: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    public init(viewModel: ApresentacaoERegioesViewModel, aoSalvar: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.aoSalvar = aoSalvar
    }

    public init(api: any ApiCliente, aoSalvar: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: ApresentacaoERegioesViewModel(api: api))
        self.aoSalvar = aoSalvar
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                if viewModel.carregando {
                    EstadoCarregando()
                        .padding(.top, FrilaEspaco.enorme)
                } else {
                    if let erroGeral = viewModel.erroGeral {
                        avisoErroGeral(erroGeral)
                    }

                    secaoSobreMim
                    secaoExperiencia
                    secaoOndeTrabalhei
                    secaoCursos
                    secaoIdiomas
                    secaoRegioes
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tela-apresentacao-regioes")
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.compacto)
            .padding(.bottom, FrilaEspaco.grande)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .frilaKeyboardDismissScope()
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosApresentacaoERegioes.titulo))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.carregar()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !viewModel.carregando {
                barraInferior
                    .background(.regularMaterial)
            }
        }
    }

    // MARK: - Seção Sobre Mim

    private var secaoSobreMim: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.sobreMimTitulo,
                dica: TextosApresentacaoERegioes.sobreMimDica
            )

            ZStack(alignment: .topLeading) {
                if viewModel.sobreMim.isEmpty {
                    Text(verbatim: TextosApresentacaoERegioes.sobreMimPrompt)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.horizontal, FrilaEspaco.medio)
                        .padding(.vertical, FrilaEspaco.medio)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.sobreMim)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .scrollContentBackground(.hidden)
                    .padding(FrilaEspaco.pequeno)
                    .frame(minHeight: 120)
            }
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                    .strokeBorder(viewModel.erroSobreMim != nil ? FrilaCor.perigo : FrilaCor.bordaDoCampo, lineWidth: 1.5)
            )
            .accessibilityIdentifier("campo-sobre-mim")

            HStack {
                Spacer()
                Text(verbatim: "\(viewModel.sobreMim.count)/\(ApresentacaoERegioesViewModel.limiteSobreMim)")
                    .font(FrilaTipo.nota)
                    .foregroundStyle(viewModel.sobreMim.count > ApresentacaoERegioesViewModel.limiteSobreMim ? FrilaCor.perigo : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-sobre-mim")
            }

            if let erro = viewModel.erroSobreMim {
                avisoErroCampo(erro)
                    .accessibilityIdentifier("aviso-erro-sobre-mim")
            }
        }
    }

    // MARK: - Seção Experiência

    private var secaoExperiencia: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.experienciaTitulo,
                dica: TextosApresentacaoERegioes.experienciaDica
            )

            FrilaFlowLayout(horizontalSpacing: FrilaEspaco.pequeno, verticalSpacing: FrilaEspaco.pequeno) {
                ForEach(ExperienciaFaixa.allCases, id: \.self) { faixa in
                    let selecionada = viewModel.experienciaFaixa == faixa
                    Button {
                        if selecionada {
                            viewModel.experienciaFaixa = nil
                        } else {
                            viewModel.experienciaFaixa = faixa
                        }
                    } label: {
                        Text(verbatim: TextosApresentacaoERegioes.textoExperiencia(faixa))
                            .font(FrilaTipo.meta)
                            .padding(.horizontal, FrilaEspaco.medio)
                            .padding(.vertical, FrilaEspaco.pequeno)
                            .foregroundStyle(selecionada ? FrilaCor.sobreSelecao : FrilaCor.texto)
                            .background(selecionada ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
                            .overlay(Capsule().strokeBorder(selecionada ? FrilaCor.selecao : FrilaCor.borda, lineWidth: 1))
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("faixa-\(faixa.rawValue)")
                }
            }
        }
    }

    // MARK: - Seção Onde Já Trabalhei

    private var secaoOndeTrabalhei: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.ondeTrabalheiTitulo,
                dica: TextosApresentacaoERegioes.ondeTrabalheiDica
            )

            ZStack(alignment: .topLeading) {
                if viewModel.ondeTrabalhei.isEmpty {
                    Text(verbatim: TextosApresentacaoERegioes.ondeTrabalheiPrompt)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.horizontal, FrilaEspaco.medio)
                        .padding(.vertical, FrilaEspaco.medio)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.ondeTrabalhei)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .scrollContentBackground(.hidden)
                    .padding(FrilaEspaco.pequeno)
                    .frame(minHeight: 100)
            }
            .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                    .strokeBorder(viewModel.erroOndeTrabalhei != nil ? FrilaCor.perigo : FrilaCor.bordaDoCampo, lineWidth: 1.5)
            )
            .accessibilityIdentifier("campo-onde-trabalhei")

            HStack {
                Spacer()
                Text(verbatim: "\(viewModel.ondeTrabalhei.count)/\(ApresentacaoERegioesViewModel.limiteOndeTrabalhei)")
                    .font(FrilaTipo.nota)
                    .foregroundStyle(viewModel.ondeTrabalhei.count > ApresentacaoERegioesViewModel.limiteOndeTrabalhei ? FrilaCor.perigo : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-onde-trabalhei")
            }

            if let erro = viewModel.erroOndeTrabalhei {
                avisoErroCampo(erro)
                    .accessibilityIdentifier("aviso-erro-onde-trabalhei")
            }
        }
    }

    // MARK: - Seção Cursos

    private var secaoCursos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.cursosTitulo,
                dica: TextosApresentacaoERegioes.cursosDica
            )

            ForEach(Array(viewModel.cursos.enumerated()), id: \.offset) { indice, curso in
                HStack(spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: curso)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button {
                        viewModel.removerCurso(em: indice)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(FrilaTipo.meta)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .frame(width: FrilaMetrica.alvoMinimo, height: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityLabel(Text(verbatim: TextosApresentacaoERegioes.removerCurso))
                    .accessibilityIdentifier("remover-curso-\(indice)")
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.vertical, FrilaEspaco.fio)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
            }

            if viewModel.cursos.count < ApresentacaoERegioesViewModel.limiteMaxCursos {
                HStack(spacing: FrilaEspaco.pequeno) {
                    TextField(
                        TextosApresentacaoERegioes.cursoPrompt,
                        text: $viewModel.novoCursoTexto
                    )
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .padding(.horizontal, FrilaEspaco.medio)
                    .frame(minHeight: FrilaMetrica.alturaDoCampo)
                    .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous).strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1))
                    .accessibilityIdentifier("campo-novo-curso")

                    Button {
                        viewModel.adicionarCurso()
                    } label: {
                        Text(verbatim: TextosApresentacaoERegioes.adicionarCurso)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.sobrePrimaria)
                            .padding(.horizontal, FrilaEspaco.medio)
                            .frame(minHeight: FrilaMetrica.alturaDoCampo)
                            .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("botao-adicionar-curso")
                }
            }

            if let erro = viewModel.erroCursos {
                avisoErroCampo(erro)
                    .accessibilityIdentifier("aviso-erro-cursos")
            }
        }
    }

    // MARK: - Seção Idiomas

    private var secaoIdiomas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.idiomasTitulo,
                dica: TextosApresentacaoERegioes.idiomasDica
            )

            FrilaFlowLayout(horizontalSpacing: FrilaEspaco.pequeno, verticalSpacing: FrilaEspaco.pequeno) {
                ForEach(Idioma.allCases, id: \.self) { idioma in
                    let selecionado = viewModel.idiomasSelecionados.contains(idioma)
                    Button {
                        viewModel.alternarIdioma(idioma)
                    } label: {
                        Text(verbatim: TextosApresentacaoERegioes.textoIdioma(idioma))
                            .font(FrilaTipo.meta)
                            .padding(.horizontal, FrilaEspaco.medio)
                            .padding(.vertical, FrilaEspaco.pequeno)
                            .foregroundStyle(selecionado ? FrilaCor.sobreSelecao : FrilaCor.texto)
                            .background(selecionado ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
                            .overlay(Capsule().strokeBorder(selecionado ? FrilaCor.selecao : FrilaCor.borda, lineWidth: 1))
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("idioma-\(idioma.rawValue)")
                }
            }
        }
    }

    // MARK: - Seção Regiões Atendidas

    private var secaoRegioes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.regioesTitulo,
                dica: TextosApresentacaoERegioes.regioesDica
            )

            // Esclarecimento sobre ponto base (Critério 5)
            HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                Image(systemName: "info.circle.fill")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.marca)
                    .accessibilityHidden(true)
                Text(verbatim: TextosApresentacaoERegioes.avisoPontoBase)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("aviso-ponto-base")

            // Opção: Todo o DF
            Toggle(isOn: $viewModel.atendeTodoDF) {
                Text(verbatim: TextosApresentacaoERegioes.todoODF)
                    .font(FrilaTipo.tituloDoCartao)
                    .foregroundStyle(FrilaCor.texto)
            }
            .tint(FrilaCor.selecao)
            .padding(FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous).strokeBorder(FrilaCor.divisoria, lineWidth: 1))
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .accessibilityIdentifier("toggle-todo-df")

            if !viewModel.atendeTodoDF {
                FrilaFlowLayout(horizontalSpacing: FrilaEspaco.pequeno, verticalSpacing: FrilaEspaco.pequeno) {
                    ForEach(viewModel.regioesDisponiveis) { regiao in
                        let selecionada = viewModel.regioesSelecionadas.contains(regiao.id)
                        Button {
                            viewModel.alternarRegiao(id: regiao.id)
                        } label: {
                            Text(verbatim: "\(regiao.numero) · \(regiao.nome)")
                                .font(FrilaTipo.meta)
                                .padding(.horizontal, FrilaEspaco.medio)
                                .padding(.vertical, FrilaEspaco.pequeno)
                                .foregroundStyle(selecionada ? FrilaCor.sobreSelecao : FrilaCor.texto)
                                .background(selecionada ? FrilaCor.selecao : FrilaCor.superficie, in: Capsule())
                                .overlay(Capsule().strokeBorder(selecionada ? FrilaCor.selecao : FrilaCor.borda, lineWidth: 1))
                                .frame(minHeight: FrilaMetrica.alvoMinimo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("regiao-\(regiao.id)")
                    }
                }
            }

            if let erro = viewModel.erroRegioes {
                avisoErroCampo(erro)
                    .accessibilityIdentifier("aviso-erro-regioes")
            }
        }
    }

    // MARK: - Barra Inferior

    private var barraInferior: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            BotaoPrimario(verbatim: TextosApresentacaoERegioes.salvar, carregando: viewModel.salvando) {
                Task {
                    if await viewModel.salvar() {
                        aoSalvar()
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("botao-salvar-apresentacao")
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Componentes de Apoio

    private func cabecalhoSecao(titulo: String, dica: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: titulo)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: dica)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func avisoErroCampo(_ erro: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.perigo)
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
                .strokeBorder(FrilaCor.perigo, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
    }

    private func avisoErroGeral(_ erro: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "wifi.exclamationmark")
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.perigo)
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
                .strokeBorder(FrilaCor.perigo, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aviso-erro-geral")
    }
}
