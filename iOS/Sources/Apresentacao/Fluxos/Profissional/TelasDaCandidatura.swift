// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Segue o protótipo low-fi ("Detalhe da vaga",
// "Vaga preenchida", "Meu turno") e substitui por ora a alta fidelidade do profissional (#15).

import FrilaDominio
import SwiftUI

private typealias Textos = TextosDoProfissional.Candidatura

/// Candidatar-me, no detalhe (#105). O botão fica desabilitado enquanto a chamada está em voo.
/// Resultados com tela própria vão para `concluir`; não encontrada e falha ficam aqui, com nova tentativa.
public struct AreaDeCandidatura: View {
    @State private var viewModel: CandidaturaViewModel
    private let concluir: (ResultadoDaCandidatura) -> Void

    public init(vaga: Vaga, api: any ApiCliente, concluir: @escaping (ResultadoDaCandidatura) -> Void) {
        _viewModel = State(initialValue: CandidaturaViewModel(vaga: vaga, api: api))
        self.concluir = concluir
    }

    init(viewModel: CandidaturaViewModel, concluir: @escaping (ResultadoDaCandidatura) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.concluir = concluir
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            BotaoPrimario(LocalizedStringKey(TextosDoProfissional.Detalhe.candidatar), carregando: viewModel.enviando) {
                Task { await viewModel.candidatar() }
            }
            .disabled(viewModel.enviando)
            .accessibilityIdentifier("candidatar")
            .accessibilityHint(viewModel.enviando ? Textos.enviando : "")

            if case let .concluida(resultado) = viewModel.estado, let texto = Self.mensagemNoDetalhe(resultado) {
                AvisoFrila(LocalizedStringKey(texto), tom: .erro)
                    .accessibilityIdentifier("candidatura-falha")
            }
        }
        .onChange(of: viewModel.estado) { _, novo in
            guard case let .concluida(resultado) = novo else { return }
            if Self.mensagemNoDetalhe(resultado) == nil {
                concluir(resultado)
                viewModel.recomecar()
            } else {
                AccessibilityNotification.Announcement(Self.mensagemNoDetalhe(resultado) ?? "").post()
            }
        }
    }

    /// Resultados que ficam no detalhe, como aviso. Os outros têm tela própria.
    static func mensagemNoDetalhe(_ resultado: ResultadoDaCandidatura) -> String? {
        switch resultado {
        case .naoEncontrada: Textos.naoEncontrada
        case let .falha(erro) where erro.codigo == .semRede: Textos.semConexao
        case .falha: Textos.falha
        default: nil
        }
    }
}

/// Tela própria de cada resultado da candidatura (#105).
public struct TelaResultadoDaCandidatura: View {
    private let vaga: Vaga
    private let resultado: ResultadoDaCandidatura
    private let voltarParaLista: () -> Void
    private let abrirTurno: (Turno) -> Void

    public init(vaga: Vaga, resultado: ResultadoDaCandidatura, voltarParaLista: @escaping () -> Void, abrirTurno: @escaping (Turno) -> Void) {
        self.vaga = vaga
        self.resultado = resultado
        self.voltarParaLista = voltarParaLista
        self.abrirTurno = abrirTurno
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) { conteudo }
                .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AccessibilityNotification.Announcement(titulo).post() }
    }

    @ViewBuilder
    private var conteudo: some View {
        switch resultado {
        case let .confirmada(_, contato):
            TurnoConfirmado(vaga: vaga, contato: contato)
        case .vagaPreenchida:
            mensagem(Textos.preenchidaTitulo, Textos.preenchidaMensagem, id: "resultado-vaga-preenchida")
            voltar
        case .vagaEncerrada:
            mensagem(Textos.encerradaTitulo, Textos.encerradaMensagem, id: "resultado-vaga-encerrada")
            voltar
        case let .inelegivel(.turnoSobreposto(conflito)):
            mensagem(Textos.sobrepostoTitulo, conflito == nil ? Textos.sobrepostoSemTurno : Textos.sobrepostoMensagem,
                     id: "resultado-turno-sobreposto")
            if let conflito {
                ResumoDoTurno(turno: conflito)
                BotaoPrimario(LocalizedStringKey(Textos.verMeuTurno)) { abrirTurno(conflito) }
                    .accessibilityIdentifier("ver-meu-turno")
            }
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
            BotaoSecundario(LocalizedStringKey(Textos.contestar)) {}
                .disabled(true)
                .accessibilityHint(Textos.contestarEmBreve)
                .accessibilityIdentifier("contestar")
            Text(Textos.contestarEmBreve).font(.footnote).foregroundStyle(FrilaCor.textoSecundario)
            voltar
        case .naoEncontrada, .falha:
            // Esses ficam no detalhe; se chegarem aqui, a pessoa volta para a lista.
            voltar
        }
    }

    private var voltar: some View {
        BotaoSecundario(LocalizedStringKey(Textos.voltarParaLista), acao: voltarParaLista)
            .accessibilityIdentifier("voltar-para-lista")
    }

    private func mensagem(_ titulo: String, _ texto: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(titulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(texto).font(.body).foregroundStyle(FrilaCor.textoSecundario)
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
        Text(Textos.confirmadoTitulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("resultado-confirmada")
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text("\(vaga.funcao.nome) · \(vaga.estabelecimento.nome)").font(.headline)
            Text("\(formatador.intervalo(vaga.periodo)) · \(formatador.dinheiro(vaga.valor))")
            Text("\(vaga.local) · \(TextosDoProfissional.Detalhe.quemRecebe.lowercased()): \(vaga.responsavelLocal)")
                .font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)

        if let contato {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(Textos.contato).font(.footnote.weight(.semibold)).foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityAddTraits(.isHeader)
                Text("\(contato.nome) · \(contato.telefone)").font(.body.weight(.semibold))
                Link(Textos.abrirWhatsApp, destination: contato.whatsappURL)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                Text(Textos.contatoLiberado).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
            .accessibilityIdentifier("contato-do-turno")
        }
    }
}

/// Resumo do turno que a pessoa já tem (o conflito do turno sobreposto).
struct ResumoDoTurno: View {
    let turno: Turno

    var body: some View {
        let formatador = FormatadorFrila()
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text("\(turno.vaga.funcao) · \(turno.contraparte.nome)").font(.headline)
            Text("\(formatador.intervalo(turno.vaga.periodo)) · \(formatador.dinheiro(turno.valorAcordado))")
            Text(turno.vaga.local).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }
}

/// O turno que a pessoa já tem, aberto pelo link do turno sobreposto: stub do #109, só leitura.
public struct TelaTurnoExistente: View {
    private let turno: Turno

    public init(turno: Turno) { self.turno = turno }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(Textos.meusTurnosTitulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                ResumoDoTurno(turno: turno)
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tela-turno-existente")
    }
}
