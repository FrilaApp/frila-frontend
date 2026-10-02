// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Segue o protótipo low-fi ("Detalhe da vaga",
// "Vaga preenchida", "Meu turno") e substitui por ora a alta fidelidade do profissional (#15).

import FrilaDominio
import SwiftUI

private typealias Textos = TextosDoProfissional.Candidatura

/// Candidatar-me, no detalhe (#105). O botão fica desabilitado enquanto a chamada está em voo.
/// Resultados com tela própria vão pelo roteador; não encontrada e falha ficam aqui, com nova tentativa.
public struct AreaDeCandidatura: View {
    @State private var viewModel: CandidaturaViewModel
    private let candidatar: (CandidaturaViewModel) async -> Void

    public init(vaga: Vaga, api: any ApiCliente, candidatar: @escaping (CandidaturaViewModel) async -> Void) {
        _viewModel = State(initialValue: CandidaturaViewModel(vaga: vaga, api: api))
        self.candidatar = candidatar
    }

    init(viewModel: CandidaturaViewModel, candidatar: @escaping (CandidaturaViewModel) async -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.candidatar = candidatar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            BotaoPrimario(verbatim: TextosDoProfissional.Detalhe.candidatar, carregando: viewModel.enviando) {
                Task { await candidatar(viewModel) }
            }
            .disabled(viewModel.enviando)
            .accessibilityIdentifier("candidatar")
            .accessibilityHint(viewModel.enviando ? Textos.enviando : "")

            if case let .concluida(resultado) = viewModel.estado, let texto = Self.mensagemNoDetalhe(resultado) {
                AvisoFrila(verbatim: texto, tom: resultado == .outraEmAndamento ? .alerta : .erro)
                    .accessibilityIdentifier(resultado == .outraEmAndamento ? "candidatura-em-voo" : "candidatura-falha")
            }
        }
        .onChange(of: viewModel.estado) { _, novo in
            guard case let .concluida(resultado) = novo else { return }
            if let texto = Self.mensagemNoDetalhe(resultado) {
                AccessibilityNotification.Announcement(texto).post()
            }
        }
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
    private let voltarParaLista: () -> Void

    public init(vaga: Vaga, resultado: ResultadoDaCandidatura, voltarParaLista: @escaping () -> Void) {
        self.vaga = vaga
        self.resultado = resultado
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
        case .vagaPreenchida:
            mensagem(Textos.preenchidaTitulo, Textos.preenchidaMensagem, id: "resultado-vaga-preenchida")
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
