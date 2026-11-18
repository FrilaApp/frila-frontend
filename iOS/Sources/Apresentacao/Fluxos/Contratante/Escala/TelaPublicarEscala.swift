import FrilaDominio
import SwiftUI

/// A escala de evento da casa (contrato 0.2.96): um evento e de 1 a 10 vagas, publicadas de uma vez, tudo ou nada.
/// Entra por "Publicar escala do evento", ao lado do publicar vaga em Minhas vagas, e não troca o fluxo da vaga única.
/// Cada vaga tem o que a vaga avulsa tem (modo, responsável no local, inclusos, traje e observações), como na web e no
/// Android. O botão e a mensagem da ação ficam no rodapé ancorado (D-DS-09), no sistema do Fabrício; em tamanho de
/// acessibilidade a mensagem vai para o alto da rolagem, e a tela rola até ela e move o foco para ela.
public struct TelaPublicarEscala: View {
    private enum Foco: Hashable {
        case nome
        case responsavel(UUID)
        case traje(UUID)
        case observacoes(UUID)
    }

    private static let idDoAviso = "escala-aviso"

    @State private var modelo: PublicarEscalaViewModel
    @State private var escolhendoFuncaoDe: UUID?
    @FocusState private var foco: Foco?
    @AccessibilityFocusState private var focoDoAviso: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    private let aoConcluir: () -> Void
    private let aoCancelar: () -> Void
    private let formatador = FormatadorFrila()

    public init(modelo: PublicarEscalaViewModel, aoConcluir: @escaping () -> Void, aoCancelar: @escaping () -> Void) {
        _modelo = State(initialValue: modelo)
        self.aoConcluir = aoConcluir
        self.aoCancelar = aoCancelar
    }

    public var body: some View {
        NavigationStack {
            Group {
                if modelo.resultado != nil {
                    confirmacao
                } else {
                    formulario
                }
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .toolbar(.hidden, for: .tabBar)
            .navigationTitle(Text(verbatim: TextosDaEscala.titulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if modelo.resultado == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(TextosDaEscala.cancelar, action: aoCancelar)
                            .disabled(modelo.enviando)
                            .accessibilityIdentifier("escala-cancelar")
                    }
                }
            }
        }
        .task { await modelo.carregarFuncoes() }
        .accessibilityIdentifier("tela-publicar-escala")
    }

    private var isDark: Bool { colorScheme == .dark }

    // MARK: Formulário

    private var formulario: some View {
        ScrollViewReader { leitor in
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    cabecalho
                    // Em tamanho de acessibilidade a mensagem junto ao botão ocuparia a tela inteira: vai para a rolagem, no alto.
                    if dynamicTypeSize.isAccessibilitySize {
                        mensagens
                            .id(Self.idDoAviso)
                    }
                    secaoDoEvento
                    secaoDasVagas
                }
                .padding(.horizontal, FrilaEspaco.bloco)
                .padding(.top, FrilaEspaco.item)
                .padding(.bottom, FrilaEspaco.grupo)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(modelo.enviando)
            .rodapeAncorado { rodape }
            // Cada tentativa que termina com mensagem (mesmo repetida): rola até ela e leva o foco de acessibilidade para ela.
            .onChange(of: modelo.avisosDaAcao) {
                foco = nil
                Task { @MainActor in
                    await Task.yield()
                    if dynamicTypeSize.isAccessibilitySize {
                        withAnimation(reduzirMovimento ? nil : .easeOut(duration: 0.25)) {
                            leitor.scrollTo(Self.idDoAviso, anchor: .top)
                        }
                    }
                    focoDoAviso = false
                    await Task.yield()
                    focoDoAviso = true
                }
            }
        }
        .sheet(isPresented: Binding(get: { escolhendoFuncaoDe != nil }, set: { if !$0 { escolhendoFuncaoDe = nil } })) {
            folhaDeFuncao
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosDaEscala.titulo)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: TextosDaEscala.subtitulo)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: O evento

    private var secaoDoEvento: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            titulo(TextosDaEscala.evento)

            campo(rotulo: TextosDaEscala.nome, erro: modelo.erros.evento[.nome], id: "escala-erro-nome") {
                CampoFrila(verbatim: TextosDaEscala.nomeExemplo, texto: $modelo.nome, emFoco: foco == .nome)
                    .accessibilityLabel(Text(verbatim: TextosDaEscala.nome))
                    .focused($foco, equals: .nome)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit { foco = nil }
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier("escala-nome")
            }

            campo(rotulo: nil, erro: modelo.erros.evento[.data], id: "escala-erro-data") {
                linhaDeSeletor(TextosDaEscala.data) { seletorDoDia.disabled(modelo.camposBloqueados) }
            }

            FrilaLinhaDeDado(icone: "mappin.and.ellipse") {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: modelo.estabelecimento.endereco)
                    Text(verbatim: TextosDaEscala.localDoEvento)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("escala-endereco")
        }
    }

    // MARK: As vagas

    private var secaoDasVagas: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            titulo(TextosDaEscala.vagas)
            Text(verbatim: TextosDaEscala.somaDePessoas)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(modelo.vagas.enumerated()), id: \.element.id) { indice, vaga in
                cartaoDaVaga(vaga, indice: indice)
            }

            if modelo.vagas.count < PublicacaoEscala.limiteDeVagas {
                BotaoSecundario(verbatim: TextosDaEscala.adicionar) { modelo.adicionarVaga() }
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier("escala-adicionar-vaga")
            } else {
                Text(verbatim: String(format: TextosDaEscala.limite, PublicacaoEscala.limiteDeVagas))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("escala-limite")
            }

            Text(verbatim: String(format: TextosDaEscala.totalDePessoas, modelo.totalDePessoas))
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("escala-total-de-pessoas")
        }
    }

    private func cartaoDaVaga(_ vaga: VagaDoFormularioDaEscala, indice: Int) -> some View {
        let erros = modelo.erros.vagas[vaga.id] ?? [:]
        return VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: String(format: TextosDaEscala.vagaNumero, indice + 1, modelo.vagas.count))
                .font(FrilaTipo.tituloDoCartao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            campo(rotulo: TextosDaEscala.funcao, erro: erros[.funcao], id: "escala-erro-funcao-\(indice)") {
                Button { escolhendoFuncaoDe = vaga.id } label: {
                    HStack(spacing: FrilaEspaco.item) {
                        let escolhida = modelo.funcao(de: vaga)
                        Text(verbatim: escolhida?.nome ?? TextosDaEscala.escolherFuncao)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(escolhida == nil ? FrilaCor.textoSecundario : FrilaCor.texto)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: FrilaEspaco.item)
                        Image(systemName: "chevron.forward")
                            .font(FrilaTipo.apoio.weight(.semibold))
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityHidden(true)
                    }
                    .caixaDoCampoFrila()
                }
                .buttonStyle(.plain)
                .disabled(modelo.camposBloqueados)
                .accessibilityLabel(Text(verbatim: TextosDaEscala.funcao))
                .accessibilityValue(Text(verbatim: modelo.funcao(de: vaga)?.nome ?? TextosDaEscala.escolherFuncao))
                .accessibilityIdentifier("escala-funcao-\(indice)")
            }

            campo(rotulo: nil, erro: erros[.horario], id: "escala-erro-horario-\(indice)") {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    seletorDeHorario(TextosDaEscala.inicio, id: "escala-inicio-\(indice)",
                                     data: ligacao(vaga.id, \.inicio))
                    seletorDeHorario(TextosDaEscala.fim, id: "escala-fim-\(indice)",
                                     data: ligacao(vaga.id, \.fim))
                }
            }

            modoDaVaga(vaga, indice: indice, erro: erros[.modo])

            campo(rotulo: TextosDaEscala.valor, erro: erros[.valor], id: "escala-erro-valor-\(indice)") {
                // O campo do valor é um UITextField, que não encolhe abaixo do texto: em AX3 ou mais ele passaria da largura do
                // cartão e empurraria a tela para o lado. Ele cresce até AX2; o resto da tela segue até AX5.
                CampoValorVaga(texto: ligacao(vaga.id, \.valorTexto))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .caixaDoCampoFrila()
                    .disabled(modelo.camposBloqueados)
            }

            campo(rotulo: nil, erro: erros[.pessoas], id: "escala-erro-pessoas-\(indice)") {
                seletorDePessoas(vaga, indice: indice)
            }

            campo(rotulo: TextosDaEscala.responsavel, erro: erros[.responsavel], id: "escala-erro-responsavel-\(indice)") {
                CampoFrila(verbatim: TextosDaEscala.responsavelExemplo, texto: ligacao(vaga.id, \.responsavelLocal),
                           emFoco: foco == .responsavel(vaga.id))
                    .accessibilityLabel(Text(verbatim: TextosDaEscala.responsavel))
                    .focused($foco, equals: .responsavel(vaga.id))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { foco = nil }
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier("escala-responsavel-\(indice)")
            }

            FrilaGrupoDeLinhas(verbatim: TextosPublicarVaga.inclusos, linhasComIcone: false) {
                interruptor(TextosPublicarVaga.refeicao, ligado: ligacao(vaga.id, \.refeicao), id: "escala-refeicao-\(indice)")
                interruptor(TextosPublicarVaga.transporte, ligado: ligacao(vaga.id, \.transporte), id: "escala-transporte-\(indice)")
                interruptor(TextosPublicarVaga.material, ligado: ligacao(vaga.id, \.materialProprio), id: "escala-material-\(indice)")
            }

            campo(rotulo: TextosPublicarVaga.traje, erro: erros[.traje], id: "escala-erro-traje-\(indice)") {
                CampoFrila(verbatim: TextosDaEscala.opcional, texto: ligacao(vaga.id, \.traje), emFoco: foco == .traje(vaga.id))
                    .accessibilityLabel(Text(verbatim: TextosPublicarVaga.traje))
                    .focused($foco, equals: .traje(vaga.id))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit { foco = nil }
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier("escala-traje-\(indice)")
            }

            campo(rotulo: TextosPublicarVaga.observacoes, erro: erros[.observacoes], id: "escala-erro-observacoes-\(indice)") {
                CampoFrila(verbatim: TextosDaEscala.opcional, texto: ligacao(vaga.id, \.observacoes), emFoco: foco == .observacoes(vaga.id))
                    .accessibilityLabel(Text(verbatim: TextosPublicarVaga.observacoes))
                    .focused($foco, equals: .observacoes(vaga.id))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit { foco = nil }
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier("escala-observacoes-\(indice)")
            }

            if modelo.podeRemoverVaga {
                Button(TextosDaEscala.remover) { modelo.removerVaga(id: vaga.id) }
                    .buttonStyle(.frilaAcaoDiscreta)
                    .accessibilityIdentifier("escala-remover-\(indice)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("escala-vaga-\(indice)")
    }

    /// O modo da vaga, como no Estúdio de vaga: urgência sempre; seleção só com o início a mais de 24 horas (RN24).
    private func modoDaVaga(_ vaga: VagaDoFormularioDaEscala, indice: Int, erro: String?) -> some View {
        let disponivel = modelo.selecaoDisponivel(vaga)
        var itens = [FrilaSegmentedItem(tag: ModoPreenchimento.urgencia, title: TextosPublicarVaga.modoUrgencia)]
        if disponivel { itens.append(FrilaSegmentedItem(tag: ModoPreenchimento.selecao, title: TextosPublicarVaga.modoSelecao)) }
        return campo(rotulo: TextosPublicarVaga.modo, erro: erro, id: "escala-erro-modo-\(indice)") {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                FrilaSegmentedControl(
                    items: itens,
                    selection: Binding(get: { vaga.modo }, set: { modelo.escolherModo($0, em: vaga.id) }),
                    isDark: isDark,
                    height: FrilaGeometry.buttonHeightStandard
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel(TextosPublicarVaga.modo)
                .accessibilityIdentifier("escala-modo-\(indice)")
                .disabled(modelo.camposBloqueados)

                Text(verbatim: vaga.modo == .selecao ? TextosPublicarVaga.modoSelecaoExplicacao : TextosPublicarVaga.modoUrgenciaExplicacao)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                if !disponivel {
                    Text(verbatim: TextosPublicarVaga.modoSelecaoSoComAntecedencia)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("escala-selecao-indisponivel-\(indice)")
                }
                if let prazo = modelo.prazoDeEscolha(vaga) {
                    Text(verbatim: String(format: TextosPublicarVaga.modoSelecaoPrazo, formatador.dataEHora(prazo)))
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Em AX5 o seletor compacto não encolhe abaixo do texto da data e alarga a tela inteira: lá vai a roleta, que tem largura própria.
    @ViewBuilder
    private var seletorDoDia: some View {
        if dynamicTypeSize.isAccessibilitySize {
            DatePicker(TextosDaEscala.data, selection: $modelo.data, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.wheel)
                .environment(\.timeZone, FormatadorFrila.fuso)
                .accessibilityIdentifier("escala-dia")
        } else {
            DatePicker(TextosDaEscala.data, selection: $modelo.data, displayedComponents: .date)
                .labelsHidden()
                .environment(\.timeZone, FormatadorFrila.fuso)
                .accessibilityIdentifier("escala-dia")
        }
    }

    private func seletorDePessoas(_ vaga: VagaDoFormularioDaEscala, indice: Int) -> some View {
        let texto = vaga.pessoas == 1 ? TextosDaEscala.pessoasValorUma : String(format: TextosDaEscala.pessoasValor, vaga.pessoas)
        let menos = botaoRedondo("minus", rotulo: TextosDaEscala.menosUma, desabilitado: vaga.pessoas <= 1 || modelo.camposBloqueados) {
            modelo.diminuirPessoas(em: vaga.id)
        }
        .accessibilityIdentifier("escala-pessoas-menos-\(indice)")
        let mais = botaoRedondo("plus", rotulo: TextosDaEscala.maisUma,
                                desabilitado: vaga.pessoas >= PublicacaoEscala.limiteDePosicoes || modelo.camposBloqueados) {
            modelo.aumentarPessoas(em: vaga.id)
        }
        .accessibilityIdentifier("escala-pessoas-mais-\(indice)")
        let valor = Text(verbatim: texto)
            .font(FrilaTipo.corpo.monospacedDigit())
            .foregroundStyle(FrilaCor.texto)
            .accessibilityIdentifier("escala-pessoas-\(indice)")
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text(verbatim: TextosDaEscala.pessoas).font(FrilaTipo.rotuloDoCampo).foregroundStyle(FrilaCor.texto)
                    valor.fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: FrilaEspaco.bloco) { menos; mais }
                }
            } else {
                HStack(spacing: FrilaEspaco.bloco) {
                    Text(verbatim: TextosDaEscala.pessoas).font(FrilaTipo.rotuloDoCampo).foregroundStyle(FrilaCor.texto)
                    Spacer(minLength: FrilaEspaco.item)
                    menos
                    valor.frame(minWidth: 72)
                    mais
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func botaoRedondo(_ simbolo: String, rotulo: String, desabilitado: Bool, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Image(systemName: simbolo)
                .font(FrilaTipo.corpo.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .frame(width: FrilaMetrica.alvo, height: FrilaMetrica.alvo)
                .background(FrilaCor.controle, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(EstiloBotaoTatil())
        .opacity(desabilitado ? 0.4 : 1)
        .disabled(desabilitado)
        .accessibilityLabel(Text(verbatim: rotulo))
    }

    @ViewBuilder
    private func seletorDeHorario(_ titulo: String, id: String, data: Binding<Date>) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: titulo).font(FrilaTipo.rotuloDoCampo).foregroundStyle(FrilaCor.texto)
                // Dia e hora em duas roletas: a roleta com os dois não cabe na largura da tela em AX5.
                DatePicker(titulo, selection: data, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .environment(\.timeZone, FormatadorFrila.fuso)
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier(id)
                DatePicker(titulo, selection: data, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .environment(\.timeZone, FormatadorFrila.fuso)
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier("\(id)-hora")
            }
        } else {
            linhaDeSeletor(titulo) {
                DatePicker(titulo, selection: data, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .environment(\.timeZone, FormatadorFrila.fuso)
                    .disabled(modelo.camposBloqueados)
                    .accessibilityIdentifier(id)
            }
        }
    }

    /// Rótulo à esquerda e o seletor à direita; em tamanho de acessibilidade o seletor vai para baixo do rótulo.
    @ViewBuilder
    private func linhaDeSeletor<Seletor: View>(_ titulo: String, @ViewBuilder seletor: () -> Seletor) -> some View {
        let seletor = seletor()
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: titulo).font(FrilaTipo.rotuloDoCampo).foregroundStyle(FrilaCor.texto)
                seletor
            }
        } else {
            HStack(spacing: FrilaEspaco.item) {
                Text(verbatim: titulo).font(FrilaTipo.rotuloDoCampo).foregroundStyle(FrilaCor.texto)
                Spacer(minLength: FrilaEspaco.item)
                seletor
            }
            .frame(minHeight: FrilaMetrica.alvo)
        }
    }

    private func interruptor(_ titulo: String, ligado: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: ligado) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloSecundario)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(modelo.camposBloqueados)
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
        .padding(.vertical, FrilaEspaco.item)
        .frame(minHeight: FrilaMetrica.alvo)
        .accessibilityIdentifier(id)
    }

    // MARK: Peças

    private func titulo(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.secao)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// O rótulo visível acima do campo e, abaixo, o erro dele em tinta (D-DS-13: problema não tem cor).
    private func campo<Conteudo: View>(rotulo: String?, erro: String?, id: String, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if let rotulo {
                Text(verbatim: rotulo)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            conteudo()
                .erroDeCampoFrila(erro)
            if let erro {
                Text(verbatim: erro)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(id)
            }
        }
    }

    private func ligacao<Valor>(_ id: UUID, _ caminho: WritableKeyPath<VagaDoFormularioDaEscala, Valor>) -> Binding<Valor> {
        Binding(
            get: { modelo.vagas.first { $0.id == id }?[keyPath: caminho] ?? VagaDoFormularioDaEscala.referencia[keyPath: caminho] },
            set: { novo in modelo.atualizar(id) { $0[keyPath: caminho] = novo } }
        )
    }

    // MARK: Rodapé

    /// A falha das funções e a mensagem geral da ação: no rodapé, junto ao botão; em AX, no alto da rolagem.
    private var mensagens: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if modelo.funcoesIndisponiveis {
                MensagemJuntoAoBotao(verbatim: TextosDaEscala.funcoesIndisponiveis)
                    .accessibilityIdentifier("escala-funcoes-indisponiveis")
                BotaoSecundario(verbatim: TextosDaEscala.tentarNovamente) { Task { await modelo.carregarFuncoes() } }
                    .accessibilityIdentifier("escala-recarregar-funcoes")
            }
            if let geral = modelo.erros.geral {
                MensagemJuntoAoBotao(verbatim: geral)
                    .accessibilityFocused($focoDoAviso)
                    .accessibilityIdentifier("escala-mensagem")
            }
        }
    }

    private var rodape: some View {
        VStack(spacing: FrilaEspaco.item) {
            if !dynamicTypeSize.isAccessibilitySize { mensagens }
            BotaoPrimario(verbatim: tituloDoBotao, carregando: modelo.enviando) {
                foco = nil
                Task { await modelo.publicar() }
            }
            .accessibilityIdentifier("escala-publicar")
        }
    }

    private var tituloDoBotao: String {
        if modelo.enviando { return TextosDaEscala.publicando }
        return modelo.tentativaIncerta != nil ? TextosDaEscala.tentarDeNovo : TextosDaEscala.publicar
    }

    // MARK: Função

    private var folhaDeFuncao: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    ForEach(categorias) { categoria in
                        FrilaGrupoDeLinhas(verbatim: categoria.nome, linhasComIcone: false) {
                            ForEach(categoria.funcoes) { funcao in
                                FrilaLinhaDeOpcao(titulo: funcao.nome, remate: .marcada(funcao.id == funcaoEscolhida)) {
                                    guard let vagaID = escolhendoFuncaoDe else { return }
                                    modelo.atualizar(vagaID) { $0.funcaoID = funcao.id }
                                    escolhendoFuncaoDe = nil
                                }
                                .accessibilityIdentifier("escala-opcao-funcao-\(funcao.nome)")
                            }
                        }
                    }
                }
                .padding(FrilaEspaco.bloco)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationTitle(Text(verbatim: TextosDaEscala.funcaoTitulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(TextosDaEscala.fechar) { escolhendoFuncaoDe = nil }
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .accessibilityIdentifier("escala-fechar-funcoes")
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .accessibilityIdentifier("escala-folha-de-funcao")
    }

    private var funcaoEscolhida: UUID? {
        modelo.vagas.first { $0.id == escolhendoFuncaoDe }?.funcaoID
    }

    private struct Categoria: Identifiable {
        let nome: String
        let funcoes: [Funcao]
        var id: String { nome }
    }

    private var categorias: [Categoria] {
        var ordem: [String] = []
        var porCategoria: [String: [Funcao]] = [:]
        for funcao in modelo.funcoes {
            if porCategoria[funcao.categoria] == nil { ordem.append(funcao.categoria) }
            porCategoria[funcao.categoria, default: []].append(funcao)
        }
        return ordem.map { Categoria(nome: $0, funcoes: porCategoria[$0] ?? []) }
    }

    // MARK: Escala publicada

    private var confirmacao: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                Text(verbatim: modelo.vagasPublicadas == 1 ? TextosDaEscala.publicadaUma : String(format: TextosDaEscala.publicada, modelo.vagasPublicadas))
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("escala-confirmacao")
                Text(verbatim: modelo.nome.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: formatador.data(modelo.data))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .padding(FrilaEspaco.bloco)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .rodapeAncorado {
            BotaoPrimario(verbatim: TextosDaEscala.verMinhasVagas, acao: aoConcluir)
                .accessibilityIdentifier("escala-ver-minhas-vagas")
        }
    }
}

extension VagaDoFormularioDaEscala {
    /// Só para o valor de partida de uma ligação cuja vaga acabou de sair da lista.
    static let referencia = VagaDoFormularioDaEscala(id: UUID(), funcaoID: nil, inicio: .distantFuture, fim: .distantFuture, valorTexto: "", pessoas: 1)
}
