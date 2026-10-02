// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Segue o protótipo low-fi ("Detalhe da vaga",
// "Vaga preenchida", "Meu turno") e substitui por ora a alta fidelidade do profissional (#15).

import FrilaDominio
import SwiftUI

private typealias Textos = TextosDoProfissional.Candidatura

/// Candidatar-me, no detalhe (#105). O botão fica desabilitado enquanto a chamada está em voo.
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
                    AvisoFrila(verbatim: aviso.texto, tom: aviso.tom).accessibilityIdentifier(aviso.id)
                }
                BotaoPrimario(verbatim: TextosDoProfissional.Detalhe.candidatar, carregando: viewModel.enviando) {
                    Task { await candidatar(viewModel) }
                }
                .disabled(viewModel.enviando || viewModel.conferindo)
                .accessibilityIdentifier("candidatar")
                .accessibilityHint(viewModel.enviando ? Textos.enviando : "")

                if quadro == nil, let aviso, aviso.id != Self.idDaRetirada {
                    AvisoFrila(verbatim: aviso.texto, tom: aviso.tom).accessibilityIdentifier(aviso.id)
                }
            }
        }
        .task { await viewModel.conferirCandidatura() }
        .onChange(of: aviso, initial: true) { _, novo in quadro?.publicar(novo, de: Self.donoDosAvisos) }
        .onDisappear { quadro?.publicar(nil, de: Self.donoDosAvisos) }
        .onChange(of: viewModel.estado) { _, novo in
            guard case let .concluida(resultado) = novo else { return }
            if let texto = Self.mensagemNoDetalhe(resultado) {
                AccessibilityNotification.Announcement(texto).post()
            }
        }
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

/// Tela própria de cada resultado da candidatura (#105).
public struct TelaResultadoDaCandidatura: View {
    private let vaga: Vaga
    private let resultado: ResultadoDaCandidatura
    private let api: (any ApiCliente)?
    private let verCandidaturas: (() -> Void)?
    private let voltarParaLista: () -> Void

    /// `api` e `verCandidaturas` servem à candidatura pendente da vaga de seleção (#10): a retirada
    /// e o caminho para a aba em que ela fica.
    public init(
        vaga: Vaga, resultado: ResultadoDaCandidatura, api: (any ApiCliente)? = nil, verCandidaturas: (() -> Void)? = nil,
        voltarParaLista: @escaping () -> Void
    ) {
        self.vaga = vaga
        self.resultado = resultado
        self.api = api
        self.verCandidaturas = verCandidaturas
        self.voltarParaLista = voltarParaLista
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) { conteudo }
                .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: voltarParaLista) {
                    Label {
                        Text(verbatim: Textos.voltarParaLista)
                    } icon: {
                        Image(systemName: "chevron.left")
                    }
                }
                .accessibilityIdentifier("voltar-para-lista-navegacao")
            }
        }
        .onAppear { AccessibilityNotification.Announcement(titulo).post() }
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
            // O texto da urgência ("quem aceita primeiro") não vale para a vaga em que a casa escolhe.
            mensagem(
                Textos.preenchidaTitulo,
                vaga.modo == .selecao ? TextosDaCandidaturaEmSelecao.preenchidaEmSelecao : Textos.preenchidaMensagem,
                id: "resultado-vaga-preenchida"
            )
            voltar
        case .vagaEncerrada:
            mensagem(Textos.encerradaTitulo, Textos.encerradaMensagem, id: "resultado-vaga-encerrada")
            voltar
        case .inelegivel(.turnoSobreposto):
            // Só o que o backend confirmou: há conflito de horário. Sem apontar um turno específico.
            mensagem(Textos.sobrepostoTitulo, Textos.sobrepostoMensagem, id: "resultado-turno-sobreposto")
            voltar
        case .inelegivel(.funcaoIncompativel):
            mensagem(Textos.funcaoTitulo, Textos.funcaoMensagem, id: "resultado-funcao-incompativel")
            voltar
        case .inelegivel(.outro):
            mensagem(Textos.inelegivelTitulo, Textos.inelegivelMensagem, id: "resultado-inelegivel")
            voltar
        case .contaSuspensa:
            mensagem(Textos.suspensaTitulo, Textos.suspensaMensagem, id: "resultado-conta-suspensa")
            // Caminho para contestar: stub desabilitado até o cartão de contestação (S2 #41).
            BotaoSecundario(verbatim: Textos.contestar) {}
                .disabled(true)
                .accessibilityHint(Textos.contestarEmBreve)
                .accessibilityIdentifier("contestar")
            Text(verbatim: Textos.contestarEmBreve).font(.footnote).foregroundStyle(FrilaCor.textoSecundario)
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

    /// A vaga a que a candidatura pendente se refere. Sem contato: ele só existe depois da escolha (RN10).
    private var resumoDaVaga: some View {
        let formatador = FormatadorFrila()
        return VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: "\(vaga.funcao.nome) · \(vaga.estabelecimento.nome)").font(.headline)
            Text(verbatim: "\(formatador.intervalo(vaga.periodo)) · \(formatador.dinheiro(vaga.valor))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }

    private func mensagem(_ titulo: String, _ texto: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(verbatim: texto).font(.body).foregroundStyle(FrilaCor.textoSecundario)
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

/// "Meu turno" logo depois da confirmação: stub do #109, só com os dados da vaga e o contato que a
/// confirmação devolveu (RN10). Check-in, cancelamento e avaliação são de outros cartões.
private struct TurnoConfirmado: View {
    let vaga: Vaga
    let contato: Contato?

    var body: some View {
        let formatador = FormatadorFrila()
        Text(verbatim: Textos.confirmadoTitulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("resultado-confirmada")
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: "\(vaga.funcao.nome) · \(vaga.estabelecimento.nome)").font(.headline)
            Text(verbatim: "\(formatador.intervalo(vaga.periodo)) · \(formatador.dinheiro(vaga.valor))")
            Text(verbatim: "\(vaga.local) · \(TextosDoProfissional.Detalhe.quemRecebe.lowercased()): \(vaga.responsavelLocal)")
                .font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)

        if let contato {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: Textos.contato).font(.footnote.weight(.semibold)).foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: "\(contato.nome) · \(contato.telefone)").font(.body.weight(.semibold))
                Link(destination: contato.whatsappURL) {
                    Text(verbatim: Textos.abrirWhatsApp)
                        .frame(minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                }
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .contentShape(Rectangle())
                .accessibilityIdentifier("contato-do-turno")

                Text(verbatim: Textos.contatoLiberado).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
    }
}
