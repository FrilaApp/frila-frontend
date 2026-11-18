import FrilaDominio
import SwiftUI

private typealias Textos = TextosDoProfissional.Candidatura

/// Candidatar-me, no rodapé do detalhe da vaga (#105). O botão fica em conferência enquanto a chamada está em voo.
/// Resultados com tela própria vão pelo roteador; não encontrada e falha ficam aqui, com nova tentativa.
/// Na vaga de seleção em que a conta já tem candidatura pendente (#10), o lugar do botão é da
/// candidatura enviada, com Retirar candidatura.
/// No rodapé do detalhe (DESIGN.md, "Rodapé fixo"), o valor só aparece quando a rolagem chega ao fim: antes disso o
/// rodapé mostra só o botão, para o valor do cartão não ficar escondido embaixo dele.
public struct AreaDeCandidatura: View {
    @State private var viewModel: CandidaturaViewModel
    /// A pessoa acabou de retirar a candidatura nesta tela: o botão volta, com o aviso.
    @State private var retirouAgora = false
    /// Presente quando a área está presa ao rodapé do detalhe: o aviso vai para cima do botão, no rodapé.
    @Environment(AvisosDoDetalhe.self) private var quadro: AvisosDoDetalhe?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let api: (any ApiCliente)?
    private let candidatar: (CandidaturaViewModel) async -> Void

    public init(vaga: Vaga, api: any ApiCliente, candidatar: @escaping (CandidaturaViewModel) async -> Void) {
        _viewModel = State(initialValue: CandidaturaViewModel(vaga: vaga, api: api))
        self.api = api
        self.candidatar = candidatar
    }

    init(viewModel: CandidaturaViewModel, candidatar: @escaping (CandidaturaViewModel) async -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.api = nil
        self.candidatar = candidatar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if let candidaturaID = viewModel.candidaturaPendente {
                CandidaturaEnviada(candidaturaID: candidaturaID, api: api, compacta: true) {
                    viewModel.candidaturaRetirada()
                    retirouAgora = true
                }
                .id(candidaturaID)
            } else {
                // A retirada vem antes do botão, e a falha depois dele, como já era.
                if quadro == nil, let aviso, aviso.id == Self.idDaRetirada {
                    MensagemJuntoAoBotao(verbatim: aviso.texto).accessibilityIdentifier(aviso.id)
                }

                // O valor ocupa o mesmo lugar nos dois estados do rodapé: se a linha sumisse, o rodapé encolheria e
                // o fim da rolagem mudaria de lugar a cada troca.
                let mostraPreco = quadro?.noFim ?? true
                precoView
                    .opacity(mostraPreco ? 1 : 0)
                    .accessibilityHidden(!mostraPreco)
                botaoView

                if quadro == nil, let aviso, aviso.id != Self.idDaRetirada {
                    MensagemJuntoAoBotao(verbatim: aviso.texto).accessibilityIdentifier(aviso.id)
                }
            }
        }
        .task { await viewModel.conferirCandidatura() }
        .onChange(of: aviso, initial: true) { _, novo in quadro?.publicar(novo, de: Self.donoDosAvisos) }
        .onChange(of: viewModel.candidaturaPendente != nil, initial: true) { _, enviada in quadro?.candidaturaEnviada = enviada }
        .onDisappear {
            quadro?.publicar(nil, de: Self.donoDosAvisos)
            quadro?.candidaturaEnviada = false
        }
    }

    @ViewBuilder
    private var precoView: some View {
        if dynamicTypeSize.isAccessibilitySize {
            precoEmColuna
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.bloco) {
                    valorDoRodape
                    Spacer(minLength: 0)
                    apoioDoRodape
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: true, vertical: true)
                }
                precoEmColuna
            }
        }
    }

    private var valorDoRodape: some View {
        let formatador = FormatadorFrila()
        return Text(verbatim: formatador.dinheiro(viewModel.vaga.valor))
            .font(FrilaTipo.valorDoRodape)
            .foregroundStyle(FrilaCor.texto)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(Text(verbatim: formatador.dinheiroFalado(viewModel.vaga.valor)))
            .accessibilityIdentifier("candidatura-valor")
    }

    private var apoioDoRodape: some View {
        Text(verbatim: apoioPreco)
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var precoEmColuna: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            valorDoRodape
            apoioDoRodape.multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var apoioPreco: String {
        FormatoDataVaga.apoioPreco(viewModel.vaga.periodo.inicio)
    }

    /// O único botão laranja da tela. Enquanto a chamada roda ou a candidatura é conferida, fica em conferência: no
    /// lugar, com o rótulo do que está acontecendo, sem indicador girando.
    private var botaoView: some View {
        let emConferencia = viewModel.enviando || viewModel.conferindo
        return BotaoPrimario(verbatim: tituloDoBotao, carregando: emConferencia) {
            Task { await candidatar(viewModel) }
        }
        .accessibilityIdentifier("candidatar")
        .accessibilityHint(viewModel.enviando ? Textos.enviando : "")
    }

    private var tituloDoBotao: String {
        if viewModel.enviando {
            return viewModel.vaga.modoEfetivo(em: .now) == .urgencia
                ? TextosDoProfissional.Detalhe.confirmando
                : Textos.enviando
        }
        if viewModel.conferindo {
            return Textos.verificandoCandidatura
        }
        return viewModel.vaga.modoEfetivo(em: .now) == .urgencia
            ? TextosDoProfissional.Detalhe.aceitarTurno
            : TextosDoProfissional.Detalhe.candidatar
    }

    private static let idDaRetirada = "candidatura-retirada"
    private static let donoDosAvisos = "candidatar"

    /// O aviso que acompanha o botão: a falha da candidatura, ou a retirada que acabou de acontecer.
    private var aviso: AvisosDoDetalhe.Aviso? {
        guard viewModel.candidaturaPendente == nil else { return nil }
        if case let .concluida(resultado) = viewModel.estado, let texto = Self.mensagemNoDetalhe(resultado) {
            let emVoo = resultado == .outraEmAndamento
            return .init(id: emVoo ? "candidatura-em-voo" : "candidatura-falha", texto: texto, tom: emVoo ? .alerta : .erro)
        }
        if retirouAgora, viewModel.estado == .ocioso {
            return .init(id: Self.idDaRetirada, texto: TextosDaCandidaturaEmSelecao.retiradaNoDetalhe, tom: .informativo)
        }
        return nil
    }

    /// Resultados que ficam no detalhe, como aviso. Os outros têm tela própria.
    static func mensagemNoDetalhe(_ resultado: ResultadoDaCandidatura) -> String? {
        switch resultado {
        case .naoEncontrada: Textos.naoEncontrada
        case let .falha(erro) where erro.codigo == .semRede: Textos.semConexao
        case .falha: Textos.falha
        case .outraEmAndamento: Textos.outraEmAndamento
        default: nil
        }
    }
}

/// Tela própria de cada resultado da candidatura (#105). O título da tela e o que aconteceu vêm primeiro; a vaga, num
/// cartão; "Ver outras vagas perto de você" fica no rodapé fixo, que é a saída de todo resultado (no resultado de
/// função diferente, o primário é "Ajustar minhas funções").
public struct TelaResultadoDaCandidatura: View {
    private let vaga: Vaga
    private let resultado: ResultadoDaCandidatura
    private let api: (any ApiCliente)?
    private let verCandidaturas: (() -> Void)?
    private let voltarParaLista: () -> Void
    private let sair: () -> Void
    private let ajustarFuncoes: (() -> Void)?
    @State private var contestacaoModel: ContaSuspensaViewModel?

    /// `api` e `verCandidaturas` servem à candidatura pendente da vaga de seleção (#10): a retirada
    /// e o caminho para a aba em que ela fica.
    public init(
        vaga: Vaga, resultado: ResultadoDaCandidatura, api: (any ApiCliente)? = nil, verCandidaturas: (() -> Void)? = nil,
        ajustarFuncoes: (() -> Void)? = nil, sair: @escaping () -> Void = {}, voltarParaLista: @escaping () -> Void
    ) {
        self.vaga = vaga
        self.resultado = resultado
        self.api = api
        self.verCandidaturas = verCandidaturas
        self.voltarParaLista = voltarParaLista
        self.sair = sair
        self.ajustarFuncoes = ajustarFuncoes
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) { conteudo }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.item)
                .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(Text(verbatim: titulo))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: voltarParaLista) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(FrilaCor.texto)
                }
                .accessibilityLabel(Text(verbatim: Textos.voltarParaLista))
                .accessibilityIdentifier("voltar-para-lista-navegacao")
            }
        }
        .rodapeAncorado { rodape }
        .onAppear { AccessibilityNotification.Announcement(titulo).post() }
        .sheet(item: $contestacaoModel) { contestacaoModel in
            if let api {
                TelaContaSuspensa(viewModel: contestacaoModel, api: api)
            }
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch resultado {
        case .confirmada:
            tituloDaTela(Textos.confirmadoTitulo, id: "resultado-confirmada")
            resumoDaVaga(comQuemRecebe: true)
        case let .pendente(candidaturaID):
            CandidaturaEnviada(candidaturaID: candidaturaID, api: api)
            resumoDaVaga(comQuemRecebe: false)
            if let verCandidaturas {
                BotaoSecundario(verbatim: TextosDaCandidaturaEmSelecao.verCandidaturas, acao: verCandidaturas)
                    .accessibilityIdentifier("ver-minhas-candidaturas")
            }
        case .vagaPreenchida:
            mensagem(
                Textos.estaVagaJaFoiPreenchida,
                vaga.modoEfetivo(em: .now) == .selecao ? TextosDaCandidaturaEmSelecao.preenchidaEmSelecao : Textos.preenchidaUrgenciaMensagem,
                id: "resultado-vaga-preenchida"
            )
            vagaOriginal
        case .vagaEncerrada:
            mensagem(
                Textos.estaVagaFoiEncerrada,
                Textos.encerradaMensagem,
                id: "resultado-vaga-encerrada"
            )
            vagaOriginal
        case .inelegivel(.turnoSobreposto):
            // Só o que o backend confirmou: há conflito de horário. Sem apontar um turno específico.
            mensagem(Textos.sobrepostoTitulo, Textos.sobrepostoMensagem, id: "resultado-turno-sobreposto")
        case .inelegivel(.funcaoIncompativel):
            mensagem(Textos.funcaoTitulo, Textos.funcaoMensagem, id: "resultado-funcao-incompativel")
        case .inelegivel(.outro):
            mensagem(Textos.inelegivelTitulo, Textos.inelegivelMensagem, id: "resultado-inelegivel")
        case .contaSuspensa:
            mensagem(Textos.suspensaTitulo, Textos.suspensaMensagem, id: "resultado-conta-suspensa")
            if let api {
                BotaoSecundario(verbatim: Textos.contestar) {
                    contestacaoModel = ContaSuspensaViewModel(
                        api: api,
                        aoReativar: {
                            contestacaoModel = nil
                            voltarParaLista()
                        },
                        sair: sair
                    )
                }
                .accessibilityIdentifier("contestar")
            }
        case .naoEncontrada, .falha, .outraEmAndamento:
            // Esses ficam no detalhe; se chegarem aqui, a pessoa volta para a lista.
            EmptyView()
        }
    }

    /// O rodapé fixo: o primário é o caminho para a frente. Só o resultado "função diferente" tem outro (ajustar as
    /// funções), e aí a volta para a lista fica logo abaixo, em secundário.
    @ViewBuilder
    private var rodape: some View {
        if case .inelegivel(.funcaoIncompativel) = resultado, let ajustarFuncoes {
            BotaoPrimario(verbatim: Textos.ajustarFuncoes, acao: ajustarFuncoes)
                .accessibilityIdentifier("ajustar-minhas-funcoes")
            BotaoSecundario(verbatim: Textos.voltarParaLista, acao: voltarParaLista)
                .accessibilityIdentifier("voltar-para-lista")
        } else {
            BotaoPrimario(verbatim: Textos.voltarParaLista, acao: voltarParaLista)
                .accessibilityIdentifier("voltar-para-lista")
        }
    }

    private func tituloDaTela(_ texto: String, id: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(id)
    }

    /// A vaga a que o resultado se refere: função e casa, quando, onde, quem recebe (no turno confirmado) e o valor.
    /// O contato de quem recebe não é lido nem mostrado; check-in, cancelamento e avaliação são do "Meu turno".
    private func resumoDaVaga(comQuemRecebe: Bool) -> some View {
        let formatador = FormatadorFrila()
        return VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: "\(vaga.funcao.nome), \(vaga.estabelecimento.nome)")
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
            LinhaDeQuandoDaVaga(periodo: vaga.periodo)
            FrilaLinhaDeDado(icone: "mappin.and.ellipse") {
                Text(verbatim: vaga.local)
            }
            if comQuemRecebe {
                FrilaLinhaDeDado(icone: "person") {
                    Text(verbatim: "\(TextosDoProfissional.Detalhe.quemRecebe): \(vaga.responsavelLocal)")
                }
            }
            Text(verbatim: formatador.dinheiro(vaga.valor))
                .font(FrilaTipo.valorEmDestaque)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityLabel(Text(verbatim: formatador.dinheiroFalado(vaga.valor, por: "pessoa")))
                .padding(.top, FrilaEspaco.item)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    /// "Vaga original": o que a pessoa tentou pegar, numa lista de dados, com a casa acima da função.
    private var vagaOriginal: some View {
        let formatador = FormatadorFrila()
        return VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: Textos.vagaOriginal)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                Text(verbatim: vaga.estabelecimento.nome)
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                FrilaLinhaDeDado(icone: "briefcase") {
                    Text(verbatim: vaga.funcao.nome)
                }
                LinhaDeQuandoDaVaga(periodo: vaga.periodo)
                FrilaLinhaDeDado(icone: "mappin.and.ellipse") {
                    Text(verbatim: vaga.local)
                }
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.item) {
                    Text(verbatim: formatador.dinheiro(vaga.valor))
                        .font(FrilaTipo.valorEmDestaque)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityLabel(Text(verbatim: formatador.dinheiroFalado(vaga.valor)))
                    Text(verbatim: TextosDoProfissional.Detalhe.porPessoa)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .padding(.top, FrilaEspaco.item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
    }

    /// O resultado em palavras: o título da tela e, abaixo, o que aconteceu. Sem ícone e sem cor de problema.
    private func mensagem(_ titulo: String, _ texto: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: titulo)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: texto)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private var titulo: String {
        switch resultado {
        case .confirmada: Textos.confirmadoTitulo
        case .pendente: TextosDaCandidaturaEmSelecao.enviadaTitulo
        case .vagaPreenchida: Textos.preenchidaTitulo
        case .vagaEncerrada: Textos.encerradaTitulo
        case .inelegivel(.turnoSobreposto): Textos.sobrepostoTitulo
        case .inelegivel(.funcaoIncompativel): Textos.funcaoTitulo
        case .inelegivel(.outro): Textos.inelegivelTitulo
        case .contaSuspensa: Textos.suspensaTitulo
        case .naoEncontrada: Textos.naoEncontrada
        case .falha: Textos.falha
        case .outraEmAndamento: Textos.outraEmAndamento
        }
    }
}
