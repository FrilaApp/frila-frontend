// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. As telas de destino do push seguem o low-fi do
// profissional (#15) até a alta fidelidade chegar.

import FrilaDominio
import SwiftUI

/// Por que a vaga de um aviso não dá mais para pegar. O contrato manda decidir pelo que o servidor
/// diz, e nunca pelo relógio do aparelho: só há candidatura com `publicada` e posição aberta.
public enum IndisponibilidadeDaVaga: Equatable, Sendable {
    case preenchida
    /// Cancelada, encerrada ou com o início já passado.
    case encerrada
    /// `404`: a vaga não existe mais ou não está visível para esta conta.
    case naoEncontrada

    public init?(_ estado: EstadoDoDetalhe) {
        switch estado {
        case let .carregado(vaga) where vaga.estado == .publicada && vaga.posicoesAbertas > 0:
            return nil
        case let .carregado(vaga):
            self = vaga.estado == .preenchida ? .preenchida : .encerrada
        case .naoEncontrada:
            self = .naoEncontrada
        case .carregando, .falha:
            return nil
        }
    }
}

/// A vaga de um aviso (#8). Se ainda dá para pegar, é o detalhe de sempre. Se não dá, é a tela de
/// vaga indisponível, a não ser que a vaga já seja de quem tocou: aí o destino é o turno dela.
struct DestinoDaVagaDoAviso<Conteudo: View>: View {
    private enum Busca: Equatable {
        case pendente
        case achou(Turno)
        case semTurno
    }

    @State private var detalhe: DetalheVagaViewModel
    @State private var busca = Busca.pendente
    private let api: any ApiCliente
    private let repositorio: any TurnoRepositorio
    private let candidatar: (CandidaturaViewModel) async -> Void
    private let voltarParaLista: () -> Void
    private let turno: (Turno) -> Conteudo

    init(
        vagaID: UUID,
        api: any ApiCliente,
        repositorio: any TurnoRepositorio,
        candidatar: @escaping (CandidaturaViewModel) async -> Void,
        voltarParaLista: @escaping () -> Void,
        @ViewBuilder turno: @escaping (Turno) -> Conteudo
    ) {
        _detalhe = State(initialValue: DetalheVagaViewModel(vagaID: vagaID, api: api))
        self.api = api
        self.repositorio = repositorio
        self.candidatar = candidatar
        self.voltarParaLista = voltarParaLista
        self.turno = turno
    }

    var body: some View {
        if let motivo = IndisponibilidadeDaVaga(detalhe.estado) {
            switch busca {
            case .pendente:
                EstadoCarregando()
                    .task { busca = await procurarTurno() }
            case let .achou(meuTurno):
                turno(meuTurno)
            case .semTurno:
                TelaVagaIndisponivel(motivo: motivo, voltarParaLista: voltarParaLista)
            }
        } else {
            TelaDetalheVaga(viewModel: detalhe) { vaga in
                AreaDeCandidatura(vaga: vaga, api: api, candidatar: candidatar)
            }
        }
    }

    /// Sem conseguir ler os turnos, vale o que o servidor disse da vaga.
    private func procurarTurno() async -> Busca {
        guard let turnos = try? await repositorio.ler().turnos,
              let meu = turnos.first(where: { $0.vaga.id == detalhe.vagaID }) else { return .semTurno }
        return .achou(meu)
    }
}

/// A tela própria da vaga que não dá mais para pegar (RN10): diz o que aconteceu e leva de volta à
/// lista. Os textos são os mesmos do resultado da candidatura.
struct TelaVagaIndisponivel: View {
    private typealias Textos = TextosDoProfissional.Candidatura
    let motivo: IndisponibilidadeDaVaga
    let voltarParaLista: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: titulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(verbatim: mensagem).font(.body).foregroundStyle(FrilaCor.textoSecundario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("vaga-indisponivel")

                BotaoSecundario(verbatim: Textos.voltarParaLista, acao: voltarParaLista)
                    .accessibilityIdentifier("voltar-para-lista")
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Detalhe.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AccessibilityNotification.Announcement(titulo).post() }
    }

    private var titulo: String {
        motivo == .preenchida ? Textos.preenchidaTitulo : Textos.encerradaTitulo
    }

    private var mensagem: String {
        switch motivo {
        case .preenchida: Textos.preenchidaMensagem
        case .encerrada: Textos.encerradaMensagem
        case .naoEncontrada: Textos.naoEncontrada
        }
    }
}

/// O que a procura do turno de um aviso deu.
enum BuscaDoTurnoDoAviso: Equatable {
    case carregando
    case achou(Turno)
    case naoEncontrado
    case semConexao
    case falha

    /// Falha de leitura não vira "não encontrado": sem ler, não dá para dizer que o turno não é da conta.
    static func procurar(_ turnoID: UUID, em repositorio: any TurnoRepositorio) async -> BuscaDoTurnoDoAviso {
        do {
            guard let meu = try await repositorio.ler().turnos.first(where: { $0.id == turnoID }) else { return .naoEncontrado }
            return .achou(meu)
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            return .semConexao
        } catch {
            return .falha
        }
    }
}

/// O turno de um aviso (#8). O aviso só traz o id, então o turno é procurado entre os da conta que
/// está no aparelho: o de outra conta nunca aparece, porque não vem na leitura.
struct DestinoDoTurnoDoAviso<Conteudo: View>: View {
    @State private var estado = BuscaDoTurnoDoAviso.carregando
    private let turnoID: UUID
    private let repositorio: any TurnoRepositorio
    private let verMeusTurnos: () -> Void
    private let turno: (Turno) -> Conteudo

    init(
        turnoID: UUID,
        repositorio: any TurnoRepositorio,
        verMeusTurnos: @escaping () -> Void,
        @ViewBuilder turno: @escaping (Turno) -> Conteudo
    ) {
        self.turnoID = turnoID
        self.repositorio = repositorio
        self.verMeusTurnos = verMeusTurnos
        self.turno = turno
    }

    var body: some View {
        switch estado {
        case let .achou(meuTurno):
            turno(meuTurno)
        default:
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) { semTurno }
                    .padding(FrilaEspaco.medio)
            }
            .background(FrilaCor.fundo)
            .navigationTitle(Text(verbatim: TextosDoProfissional.Turnos.tituloMeuTurno))
            .navigationBarTitleDisplayMode(.inline)
            .task { await carregar() }
        }
    }

    @ViewBuilder
    private var semTurno: some View {
        switch estado {
        case .carregando, .achou:
            EstadoCarregando()
        case .naoEncontrado:
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                Text(verbatim: TextosDoPush.Turno.naoEncontradoTitulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(verbatim: TextosDoPush.Turno.naoEncontradoMensagem).font(.body).foregroundStyle(FrilaCor.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("turno-do-aviso-nao-encontrado")
            BotaoSecundario(verbatim: TextosDoPush.Turno.verMeusTurnos, acao: verMeusTurnos)
                .accessibilityIdentifier("ver-meus-turnos")
        case .semConexao:
            AvisoFrila(verbatim: TextosDoProfissional.Lista.semConexaoMensagem, tom: .alerta)
            BotaoSecundario("Tentar novamente") { Task { await carregar() } }
        case .falha:
            EstadoErro(verbatim: TextosDoPush.Turno.falha) { Task { await carregar() } }
        }
    }

    private func carregar() async {
        estado = .carregando
        estado = await BuscaDoTurnoDoAviso.procurar(turnoID, em: repositorio)
    }
}
