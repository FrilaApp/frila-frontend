import FrilaDominio
import SwiftUI

private typealias Textos = TextosDoProfissional.Candidatura

/// Candidatar-me, no rodapé do quadro "Vaga" do MidFi do Fabrício (#105). O botão fica desabilitado enquanto a chamada está em voo.
/// Resultados com tela própria vão pelo roteador; não encontrada e falha ficam aqui, com nova tentativa.
/// Na vaga de seleção em que a conta já tem candidatura pendente (#10), o lugar do botão é da
/// candidatura enviada, com Retirar candidatura.
public struct AreaDeCandidatura: View {
    @State private var viewModel: CandidaturaViewModel
    /// A pessoa acabou de retirar a candidatura nesta tela: o botão volta, com o aviso.
    @State private var retirouAgora = false
    /// Presente quando a área está presa ao rodapé do detalhe: o aviso vai para a rolagem.
    @Environment(AvisosDoDetalhe.self) private var quadro: AvisosDoDetalhe?
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
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            if let candidaturaID = viewModel.candidaturaPendente {
                CandidaturaEnviada(candidaturaID: candidaturaID, api: api, compacta: true) {
                    viewModel.candidaturaRetirada()
                    retirouAgora = true
                }
                .id(candidaturaID)
            } else {
                // A retirada vem antes do botão, e a falha depois dele, como já era.
                if quadro == nil, let aviso, aviso.id == Self.idDaRetirada {
                    avisoLocal(aviso).accessibilityIdentifier(aviso.id)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: FrilaEspaco.medio) {
                        precoView
                        Spacer(minLength: FrilaEspaco.medio)
                        botaoView
                            .frame(minWidth: 160)
                    }
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        precoView
                        botaoView
                            .frame(maxWidth: .infinity)
                    }
                }

                if quadro == nil, let aviso, aviso.id != Self.idDaRetirada {
                    avisoLocal(aviso).accessibilityIdentifier(aviso.id)
                }
            }
        }
        .task { await viewModel.conferirCandidatura() }
        .onChange(of: aviso, initial: true) { _, novo in quadro?.publicar(novo, de: Self.donoDosAvisos) }
        .onDisappear { quadro?.publicar(nil, de: Self.donoDosAvisos) }
    }

    private var precoView: some View {
        let formatador = FormatadorFrila()
        return VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: formatador.dinheiro(viewModel.vaga.valor))
                .font(FrilaTipo.preco)
                .monospacedDigit()
                .foregroundStyle(FrilaCor.texto)
            Text(verbatim: TextosDoProfissional.Detalhe.porPessoa)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .accessibilityElement(children: .combine)
    }

    private var botaoView: some View {
        let desabilitado = viewModel.enviando || viewModel.conferindo
        return Button {
            Task { await candidatar(viewModel) }
        } label: {
            HStack(spacing: FrilaEspaco.pequeno) {
                if desabilitado {
                    ProgressView()
                        .tint(FrilaCor.textoSecundario)
                }
                Text(verbatim: tituloDoBotao)
                    .font(FrilaTipo.botao)
                    .lineLimit(1)
            }
            .padding(.horizontal, FrilaEspaco.grande)
            .frame(minHeight: FrilaMetrica.alturaDoCampo)
            .foregroundStyle(desabilitado ? FrilaCor.textoSecundario : FrilaCor.sobrePrimaria)
            .background(desabilitado ? FrilaCor.controle : FrilaCor.primaria, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.tatil)
        .disabled(desabilitado)
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

    private func avisoLocal(_ aviso: AvisosDoDetalhe.Aviso) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            Text(verbatim: aviso.texto)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
        }
        .padding(FrilaEspaco.medio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                .strokeBorder(aviso.tom == .erro ? FrilaCor.texto : Color.clear, lineWidth: 2)
        )
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

/// Tela própria de cada resultado da candidatura (#105), nos quadros "Vaga", "Preenchida" e "MeuTurno" do MidFi do Fabrício.
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
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) { conteudo }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.vertical, FrilaEspaco.grande)
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
        .modifier(BarraInferiorDoResultado(ativo: temRodapeFixo) {
            BotaoPrimario(verbatim: Textos.voltarParaLista, acao: voltarParaLista)
                .accessibilityIdentifier("voltar-para-lista")
        })
        .onAppear { AccessibilityNotification.Announcement(titulo).post() }
        .sheet(item: $contestacaoModel) { contestacaoModel in
            if let api {
                TelaContaSuspensa(viewModel: contestacaoModel, api: api)
            }
        }
    }

    private var temRodapeFixo: Bool {
        switch resultado {
        case .vagaPreenchida, .vagaEncerrada:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch resultado {
        case let .confirmada(_, contato):
            TurnoConfirmado(vaga: vaga, contato: contato)
            voltar
        case let .pendente(candidaturaID):
            CandidaturaEnviada(candidaturaID: candidaturaID, api: api)
            resumoDaVaga
            if let verCandidaturas {
                BotaoSecundario(verbatim: TextosDaCandidaturaEmSelecao.verCandidaturas, acao: verCandidaturas)
                    .accessibilityIdentifier("ver-minhas-candidaturas")
            }
            voltar
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
            voltar
        case .inelegivel(.funcaoIncompativel):
            mensagem(Textos.funcaoTitulo, Textos.funcaoMensagem, id: "resultado-funcao-incompativel")
            if let ajustarFuncoes {
                BotaoPrimario(verbatim: Textos.ajustarFuncoes, acao: ajustarFuncoes)
                    .accessibilityIdentifier("ajustar-minhas-funcoes")
            }
            voltar
        case .inelegivel(.outro):
            mensagem(Textos.inelegivelTitulo, Textos.inelegivelMensagem, id: "resultado-inelegivel")
            voltar
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
            voltar
        case .naoEncontrada, .falha, .outraEmAndamento:
            // Esses ficam no detalhe; se chegarem aqui, a pessoa volta para a lista.
            voltar
        }
    }

    private var voltar: some View {
        BotaoSecundario(verbatim: Textos.voltarParaLista, acao: voltarParaLista)
            .accessibilityIdentifier("voltar-para-lista")
    }

    private var vagaOriginal: some View {
        let formatador = FormatadorFrila()
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: Textos.vagaOriginal)
                .font(FrilaTipo.microRotulo)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: vaga.funcao.nome)
                        .font(FrilaTipo.resumo)
                        .foregroundStyle(FrilaCor.texto)
                    Text(verbatim: vaga.estabelecimento.nome)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                HStack(spacing: FrilaEspaco.minimo) {
                    Image(systemName: "clock")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityHidden(true)
                    Text(verbatim: formatador.intervalo(vaga.periodo))
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                HStack(spacing: FrilaEspaco.minimo) {
                    Image(systemName: "mappin")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityHidden(true)
                    Text(verbatim: vaga.local)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                HStack(spacing: FrilaEspaco.minimo) {
                    Text(verbatim: formatador.dinheiro(vaga.valor))
                        .monospacedDigit()
                    Text(verbatim: TextosDoProfissional.Detalhe.porPessoa)
                }
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityElement(children: .combine)
        }
    }

    /// A vaga a que a candidatura pendente se refere. Sem contato: ele só existe depois da escolha (RN10).
    private var resumoDaVaga: some View {
        let formatador = FormatadorFrila()
        return VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: "\(vaga.funcao.nome) · \(vaga.estabelecimento.nome)")
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.texto)
            Text(verbatim: "\(formatador.intervalo(vaga.periodo)) · \(formatador.dinheiro(vaga.valor))")
                .font(FrilaTipo.meta)
                .monospacedDigit()
                .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }

    private func mensagem(_ titulo: String, _ texto: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo)
                .font(FrilaTipo.tituloGrande)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: texto).font(FrilaTipo.corpo).foregroundStyle(FrilaCor.textoSecundario)
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

private struct BarraInferiorDoResultado<Rodape: View>: ViewModifier {
    let ativo: Bool
    @ViewBuilder let rodape: () -> Rodape

    func body(content: Content) -> some View {
        if ativo {
            if #available(iOS 26, *) {
                content.safeAreaBar(edge: .bottom) {
                    rodape()
                        .padding(.horizontal, FrilaEspaco.medio)
                        .padding(.vertical, FrilaEspaco.compacto)
                }
            } else {
                content.safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(FrilaCor.divisoria)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                        rodape()
                            .padding(.horizontal, FrilaEspaco.medio)
                            .padding(.vertical, FrilaEspaco.compacto)
                    }
                    .background(.regularMaterial)
                }
            }
        } else {
            content
        }
    }
}

/// "Meu turno" logo depois da confirmação: stub do #109, só com os dados da vaga e o contato que a
/// confirmação devolveu (RN10). Check-in, cancelamento e avaliação são de outros cartões.
private struct TurnoConfirmado: View {
    let vaga: Vaga
    let contato: Contato?

    var body: some View {
        let formatador = FormatadorFrila()
        Text(verbatim: Textos.confirmadoTitulo)
            .font(FrilaTipo.tituloGrande)
            .foregroundStyle(FrilaCor.texto)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FrilaEspaco.minimo)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("resultado-confirmada")
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: "\(vaga.funcao.nome) · \(vaga.estabelecimento.nome)")
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.texto)
            Text(verbatim: "\(formatador.intervalo(vaga.periodo)) · \(formatador.dinheiro(vaga.valor))")
                .font(FrilaTipo.meta)
                .monospacedDigit()
                .foregroundStyle(FrilaCor.texto)
            Text(verbatim: "\(vaga.local) · \(TextosDoProfissional.Detalhe.quemRecebe.lowercased()): \(vaga.responsavelLocal)")
                .font(FrilaTipo.meta).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)

        if let contato {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: Textos.contato)
                    .font(FrilaTipo.microRotulo)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: "\(contato.nome) · \(contato.telefone)")
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.texto)
                Link(destination: contato.whatsappURL) {
                    Text(verbatim: Textos.abrirWhatsApp)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .frame(minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                }
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
                .accessibilityIdentifier("contato-do-turno")

                Text(verbatim: Textos.contatoLiberado).font(FrilaTipo.nota).foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
    }
}
