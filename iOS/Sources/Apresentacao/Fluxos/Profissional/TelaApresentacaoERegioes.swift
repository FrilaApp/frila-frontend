import FrilaDominio
import SwiftUI

public struct TelaApresentacaoERegioes: View {
    @State private var viewModel: ApresentacaoERegioesViewModel
    private let aoSalvar: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @FocusState private var campoEmFoco: CampoDaApresentacao?

    /// Os campos de texto da tela, para a caixa mostrar o foco (fio de 2 pt em tinta).
    private enum CampoDaApresentacao: Hashable { case sobreMim, ondeTrabalhei, novoCurso }

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
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if viewModel.carregando {
                    EstadoCarregando()
                        .padding(.top, FrilaEspaco.secao)
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
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .frilaKeyboardDismissScope()
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosApresentacaoERegioes.titulo))
        .tituloGrandeForaDeAX()
        .task {
            await viewModel.carregar()
        }
        .rodapeAncoradoDoPerfilSe(!viewModel.carregando) {
            rodape
        }
    }

    // MARK: - Seção Sobre Mim

    private var secaoSobreMim: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.sobreMimTitulo,
                dica: TextosApresentacaoERegioes.sobreMimDica
            )

            campoDeTextoLongo(
                texto: $viewModel.sobreMim,
                prompt: TextosApresentacaoERegioes.sobreMimPrompt,
                alturaMinima: 120,
                campo: .sobreMim,
                comErro: viewModel.erroSobreMim != nil
            )
            .accessibilityIdentifier("campo-sobre-mim")

            contador(
                total: viewModel.sobreMim.count,
                limite: ApresentacaoERegioesViewModel.limiteSobreMim,
                id: "contador-sobre-mim"
            )

            if let erro = viewModel.erroSobreMim {
                avisoErroCampo(erro)
                    .accessibilityIdentifier("aviso-erro-sobre-mim")
            }
        }
    }

    // MARK: - Seção Experiência

    /// Escolha única em formulário é lista com check, não chip (D-DS-18). Tocar na faixa já marcada a desmarca.
    private var secaoExperiencia: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.experienciaTitulo,
                dica: TextosApresentacaoERegioes.experienciaDica
            )

            FrilaGrupoDeLinhas(linhasComIcone: false) {
                ForEach(ExperienciaFaixa.allCases, id: \.self) { faixa in
                    let selecionada = viewModel.experienciaFaixa == faixa
                    FrilaLinhaDeOpcao(titulo: TextosApresentacaoERegioes.textoExperiencia(faixa), remate: .marcada(selecionada)) {
                        viewModel.experienciaFaixa = selecionada ? nil : faixa
                    }
                    .accessibilityIdentifier("faixa-\(faixa.rawValue)")
                }
            }
        }
    }

    // MARK: - Seção Onde Já Trabalhei

    private var secaoOndeTrabalhei: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.ondeTrabalheiTitulo,
                dica: TextosApresentacaoERegioes.ondeTrabalheiDica
            )

            campoDeTextoLongo(
                texto: $viewModel.ondeTrabalhei,
                prompt: TextosApresentacaoERegioes.ondeTrabalheiPrompt,
                alturaMinima: 100,
                campo: .ondeTrabalhei,
                comErro: viewModel.erroOndeTrabalhei != nil
            )
            .accessibilityIdentifier("campo-onde-trabalhei")

            contador(
                total: viewModel.ondeTrabalhei.count,
                limite: ApresentacaoERegioesViewModel.limiteOndeTrabalhei,
                id: "contador-onde-trabalhei"
            )

            if let erro = viewModel.erroOndeTrabalhei {
                avisoErroCampo(erro)
                    .accessibilityIdentifier("aviso-erro-onde-trabalhei")
            }
        }
    }

    // MARK: - Seção Cursos

    private var secaoCursos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.cursosTitulo,
                dica: TextosApresentacaoERegioes.cursosDica
            )

            if !viewModel.cursos.isEmpty {
                FrilaGrupoDeLinhas(linhasComIcone: false) {
                    ForEach(Array(viewModel.cursos.enumerated()), id: \.offset) { indice, curso in
                        HStack(spacing: FrilaEspaco.item) {
                            Text(verbatim: curso)
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                viewModel.removerCurso(em: indice)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(FrilaTipo.apoio.weight(.semibold))
                                    .foregroundStyle(FrilaCor.textoSecundario)
                                    .frame(width: FrilaMetrica.alvo, height: FrilaMetrica.alvo)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: TextosApresentacaoERegioes.removerCurso))
                            .accessibilityIdentifier("remover-curso-\(indice)")
                        }
                        .padding(.leading, FrilaMedidaDeLinha.margem)
                        .padding(.trailing, FrilaEspaco.item)
                        .frame(minHeight: FrilaMetrica.alvo)
                    }
                }
            }

            if viewModel.cursos.count < ApresentacaoERegioesViewModel.limiteMaxCursos {
                CampoFrila(verbatim: TextosApresentacaoERegioes.cursoPrompt, texto: $viewModel.novoCursoTexto, emFoco: campoEmFoco == .novoCurso)
                    .focused($campoEmFoco, equals: .novoCurso)
                    .accessibilityIdentifier("campo-novo-curso")

                BotaoSecundario(verbatim: TextosApresentacaoERegioes.adicionarCurso) {
                    viewModel.adicionarCurso()
                }
                .accessibilityIdentifier("botao-adicionar-curso")
            }

            if let erro = viewModel.erroCursos {
                avisoErroCampo(erro)
                    .accessibilityIdentifier("aviso-erro-cursos")
            }
        }
    }

    // MARK: - Seção Idiomas

    private var secaoIdiomas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.idiomasTitulo,
                dica: TextosApresentacaoERegioes.idiomasDica
            )

            FrilaFlowLayout(horizontalSpacing: FrilaEspaco.item, verticalSpacing: FrilaEspaco.minimo) {
                ForEach(Idioma.allCases, id: \.self) { idioma in
                    FiltroPill(
                        verbatim: TextosApresentacaoERegioes.textoIdioma(idioma),
                        selecionado: viewModel.idiomasSelecionados.contains(idioma)
                    ) {
                        viewModel.alternarIdioma(idioma)
                    }
                    .accessibilityIdentifier("idioma-\(idioma.rawValue)")
                }
            }
        }
    }

    // MARK: - Seção Regiões Atendidas

    private var secaoRegioes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            cabecalhoSecao(
                titulo: TextosApresentacaoERegioes.regioesTitulo,
                dica: TextosApresentacaoERegioes.regioesDica
            )

            // Esclarecimento sobre ponto base (Critério 5)
            AvisoFrila(verbatim: TextosApresentacaoERegioes.avisoPontoBase, tom: .informativo)
                .accessibilityIdentifier("aviso-ponto-base")

            // Opção: Todo o DF
            FrilaGrupoDeLinhas(linhasComIcone: false) {
                Toggle(isOn: $viewModel.atendeTodoDF) {
                    Text(verbatim: TextosApresentacaoERegioes.todoODF)
                        .font(FrilaTipo.rotuloSecundario)
                        .foregroundStyle(FrilaCor.texto)
                }
                .padding(.horizontal, FrilaMedidaDeLinha.margem)
                .padding(.vertical, FrilaEspaco.item)
                .frame(minHeight: FrilaMetrica.alvo)
                .accessibilityIdentifier("toggle-todo-df")
            }

            if !viewModel.atendeTodoDF {
                // Seleção múltipla: chips.
                FrilaFlowLayout(horizontalSpacing: FrilaEspaco.item, verticalSpacing: FrilaEspaco.minimo) {
                    ForEach(viewModel.regioesDisponiveis) { regiao in
                        FiltroPill(
                            verbatim: "\(regiao.numero) · \(regiao.nome)",
                            selecionado: viewModel.regioesSelecionadas.contains(regiao.id)
                        ) {
                            viewModel.alternarRegiao(id: regiao.id)
                        }
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

    // MARK: - Rodapé ancorado

    @ViewBuilder
    private var rodape: some View {
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

    // MARK: - Componentes de Apoio

    /// Nome da seção em rótulo de grupo e a dica em apoio, as duas em `textoSecundario`.
    private func cabecalhoSecao(titulo: String, dica: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: dica)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Campo de várias linhas com a mesma caixa dos campos do sistema: fio em `bordaDoCampo`, e em tinta de 2 pt com foco
    /// ou com erro (problema não tem cor: a mensagem abaixo diz o que corrigir).
    private func campoDeTextoLongo(
        texto: Binding<String>,
        prompt: String,
        alturaMinima: CGFloat,
        campo: CampoDaApresentacao,
        comErro: Bool
    ) -> some View {
        let forma = RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
        let destacado = campoEmFoco == campo || comErro
        return ZStack(alignment: .topLeading) {
            if texto.wrappedValue.isEmpty {
                Text(verbatim: prompt)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .padding(.horizontal, FrilaEspaco.bloco)
                    .padding(.vertical, FrilaEspaco.bloco)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: texto)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .scrollContentBackground(.hidden)
                .focused($campoEmFoco, equals: campo)
                .padding(FrilaEspaco.item)
                .frame(minHeight: alturaMinima)
        }
        .background(FrilaCor.superficieDoCampo, in: forma)
        .overlay(forma.strokeBorder(destacado ? FrilaCor.texto : FrilaCor.bordaDoCampo, lineWidth: destacado ? 2 : 1))
    }

    /// "120/600". Passou do limite: o número fica em tinta e em negrito; o texto do erro é quem explica.
    private func contador(total: Int, limite: Int, id: String) -> some View {
        HStack {
            Spacer()
            Text(verbatim: "\(total)/\(limite)")
                .font(FrilaTipo.legenda.weight(total > limite ? .bold : .regular))
                .foregroundStyle(total > limite ? FrilaCor.texto : FrilaCor.textoSecundario)
                .accessibilityIdentifier(id)
        }
    }

    private func avisoErroCampo(_ erro: String) -> some View {
        AvisoFrila(verbatim: erro, tom: .erro)
    }

    private func avisoErroGeral(_ erro: String) -> some View {
        AvisoFrila(verbatim: erro, tom: .erro)
            .accessibilityIdentifier("aviso-erro-geral")
    }
}
