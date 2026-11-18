import FrilaDominio
import SwiftUI

/// A escala de evento da casa (contrato 0.2.96): um evento e de 1 a 10 vagas, publicadas de uma vez, tudo ou nada.
/// Entra por "Publicar escala do evento", ao lado do publicar vaga em Minhas vagas, e não troca o fluxo da vaga única.
/// O botão e a mensagem da ação ficam no rodapé ancorado (D-DS-09), no sistema do Fabrício.
public struct TelaPublicarEscala: View {
    private enum Foco: Hashable {
        case nome
        case responsavel
    }

    @State private var modelo: PublicarEscalaViewModel
    @State private var escolhendoFuncaoDe: UUID?
    @FocusState private var foco: Foco?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    // MARK: Formulário

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                cabecalho
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
                    .submitLabel(.next)
                    .onSubmit { foco = .responsavel }
                    .accessibilityIdentifier("escala-nome")
            }

            campo(rotulo: nil, erro: modelo.erros.evento[.data], id: "escala-erro-data") {
                linhaDeSeletor(TextosDaEscala.data) { seletorDoDia }
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

            campo(rotulo: TextosDaEscala.responsavel, erro: modelo.erros.evento[.responsavel], id: "escala-erro-responsavel") {
                CampoFrila(verbatim: TextosDaEscala.responsavelExemplo, texto: $modelo.responsavelLocal, emFoco: foco == .responsavel)
                    .accessibilityLabel(Text(verbatim: TextosDaEscala.responsavel))
                    .focused($foco, equals: .responsavel)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { foco = nil }
                    .accessibilityIdentifier("escala-responsavel")
            }

            FrilaGrupoDeLinhas(verbatim: TextosDaEscala.inclusos, linhasComIcone: false) {
                interruptor(TextosPublicarVaga.refeicao, ligado: $modelo.refeicao, id: "escala-refeicao")
                interruptor(TextosPublicarVaga.transporte, ligado: $modelo.transporte, id: "escala-transporte")
                interruptor(TextosPublicarVaga.material, ligado: $modelo.materialProprio, id: "escala-material")
            }
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

    private var rodape: some View {
        VStack(spacing: FrilaEspaco.item) {
            if modelo.funcoesIndisponiveis {
                MensagemJuntoAoBotao(verbatim: TextosDaEscala.funcoesIndisponiveis)
                    .accessibilityIdentifier("escala-funcoes-indisponiveis")
                BotaoSecundario(verbatim: TextosDaEscala.tentarNovamente) { Task { await modelo.carregarFuncoes() } }
                    .accessibilityIdentifier("escala-recarregar-funcoes")
            }
            if let geral = modelo.erros.geral {
                MensagemJuntoAoBotao(verbatim: geral)
                    .accessibilityIdentifier("escala-mensagem")
            }
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
