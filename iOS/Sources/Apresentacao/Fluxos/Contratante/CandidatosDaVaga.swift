// VISUAL PROVISÓRIO: o design de alta fidelidade do modo seleção ainda não chegou (#10). A tela usa
// os componentes que já existem.

import Foundation
import FrilaDominio
import Observation
import SwiftUI

enum TextosDosCandidatos {
    static let titulo = String(localized: "Candidatos", bundle: bundleApresentacao)
    static let explicacao = String(localized: "Você escolhe quem vai trabalhar. A vaga fecha sozinha 24 horas antes do início se ninguém for escolhido.", bundle: bundleApresentacao)
    static let vazioTitulo = String(localized: "Ninguém se candidatou ainda", bundle: bundleApresentacao)
    static let vazioMensagem = String(localized: "Os candidatos aparecem aqui assim que se candidatarem.", bundle: bundleApresentacao)
    static let atualizar = String(localized: "Atualizar candidatos", bundle: bundleApresentacao)
    static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleApresentacao)
    static let falhaAoCarregar = String(localized: "Não foi possível carregar os candidatos. Tente novamente.", bundle: bundleApresentacao)
    static let semConexao = String(localized: "Sem conexão. Os candidatos aparecem quando a internet voltar.", bundle: bundleApresentacao)
    static let desatualizada = String(localized: "Não foi possível atualizar. A lista de candidatos pode estar desatualizada.", bundle: bundleApresentacao)
    static let funcoes = String(localized: "Funções: %@", bundle: bundleApresentacao)
    static let verPerfil = String(localized: "Ver perfil público", bundle: bundleApresentacao)
    static let verPerfilDe = String(localized: "Ver perfil público de %@", bundle: bundleApresentacao)
    static let escolher = String(localized: "Escolher", bundle: bundleApresentacao)
    static let escolherNome = String(localized: "Escolher %@", bundle: bundleApresentacao)
    static let perguntaDaEscolha = String(localized: "Confirmar a escolha?", bundle: bundleApresentacao)
    static let avisoDaEscolha = String(localized: "%@ será confirmado nesta vaga, e vocês passam a ver o contato um do outro.", bundle: bundleApresentacao)
    static let avisoDaUltimaPosicao = String(localized: "%@ será confirmado nesta vaga, e vocês passam a ver o contato um do outro. É a última posição: os outros candidatos serão avisados de que não foram escolhidos.", bundle: bundleApresentacao)
    static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    static let confirmado = String(localized: "%@ foi confirmado. O contato está em Posições.", bundle: bundleApresentacao)
    static let confirmadoEVagaPreenchida = String(localized: "%@ foi confirmado, e a vaga está preenchida. Os outros candidatos foram avisados. O contato está em Posições.", bundle: bundleApresentacao)
    static let posicaoJaPreenchida = String(localized: "Outra pessoa da sua equipe preencheu a última posição antes. Atualizamos a lista.", bundle: bundleApresentacao)
    static let posicaoJaPreenchidaSemAtualizar = String(localized: "Outra pessoa da sua equipe preencheu a última posição antes.", bundle: bundleApresentacao)
    static let candidaturaIndisponivel = String(localized: "A candidatura de %@ não está mais disponível: foi retirada ou expirou. Atualizamos a lista.", bundle: bundleApresentacao)
    static let candidaturaIndisponivelSemAtualizar = String(localized: "A candidatura de %@ não está mais disponível: foi retirada ou expirou.", bundle: bundleApresentacao)
    static let selecaoEncerradaNaEscolha = String(localized: "A seleção desta vaga já fechou. Não dá mais para escolher candidato.", bundle: bundleApresentacao)
    static let turnoSobreposto = String(localized: "%@ foi confirmado em outro turno no mesmo horário. Escolha outro candidato.", bundle: bundleApresentacao)
    static let inelegivel = String(localized: "%@ não pode assumir este turno agora. Escolha outro candidato.", bundle: bundleApresentacao)
    static let escolhaSemConexao = String(localized: "Sem conexão. A escolha não foi enviada. Tente de novo quando a internet voltar.", bundle: bundleApresentacao)
    static let vagaOculta = String(localized: "A Equipe Frila ocultou esta vaga. Você vê os candidatos, mas só pode escolher depois que ela for reexibida.", bundle: bundleApresentacao)
    static let concluida = String(localized: "Seleção concluída. Os profissionais confirmados estão em Posições.", bundle: bundleApresentacao)
    static let fechadaSemEscolha = String(localized: "A seleção fechou 24 horas antes do início sem nenhuma escolha. Os candidatos foram avisados e liberados.", bundle: bundleApresentacao)
    static let encerrada = String(localized: "A seleção desta vaga terminou.", bundle: bundleApresentacao)
    static let posicaoFechada = String(localized: "Posição fechada sem escolha", bundle: bundleApresentacao)
    static let rotuloSelecao = String(localized: "Modo seleção", bundle: bundleApresentacao)
    static let umCandidato = String(localized: "1 candidato aguardando sua escolha", bundle: bundleApresentacao)
    static let variosCandidatos = String(localized: "%d candidatos aguardando sua escolha", bundle: bundleApresentacao)
    static let semCandidatos = String(localized: "nenhum candidato ainda", bundle: bundleApresentacao)
    static let cartaoConcluida = String(localized: "seleção concluída", bundle: bundleApresentacao)
    static let cartaoFechadaSemEscolha = String(localized: "fechou sem escolha", bundle: bundleApresentacao)
    static let cartaoEncerrada = String(localized: "seleção encerrada", bundle: bundleApresentacao)

    /// A posição cancelada sem profissional, em vaga de seleção. Só é "fechada sem escolha" a que o
    /// fechamento das 24 h cancelou (RN24); a da vaga que a casa cancelou é posição cancelada.
    static func posicaoCancelada(vaga estado: EstadoVaga) -> String {
        estado == .cancelada ? TextosDoAcompanhamento.cancelada : posicaoFechada
    }

    static func pendentes(_ quantidade: Int) -> String {
        switch quantidade {
        case 0: semCandidatos
        case 1: umCandidato
        default: String(format: variosCandidatos, quantidade)
        }
    }

    static func resultado(_ resultado: ResultadoDaEscolha) -> String {
        switch resultado {
        case let .confirmado(nome, vagaPreenchida):
            String(format: vagaPreenchida ? confirmadoEVagaPreenchida : confirmado, nome)
        }
    }

    /// Só diz "Atualizamos a lista" quando a releitura depois da recusa deu certo.
    static func falha(_ falha: FalhaDaEscolha, desatualizada: Bool) -> String {
        switch falha {
        case .posicaoJaPreenchida: desatualizada ? posicaoJaPreenchidaSemAtualizar : posicaoJaPreenchida
        case let .candidaturaIndisponivel(nome):
            String(format: desatualizada ? candidaturaIndisponivelSemAtualizar : candidaturaIndisponivel, nome)
        case .selecaoEncerrada: selecaoEncerradaNaEscolha
        case let .turnoSobreposto(nome): String(format: turnoSobreposto, nome)
        case let .inelegivel(nome): String(format: inelegivel, nome)
        case .vagaOculta: vagaOculta
        case .semConexao: escolhaSemConexao
        case let .api(erro): MensagemDoErroAPI.texto(erro)
        }
    }
}

public enum EstadoDosCandidatos: Equatable, Sendable {
    case carregando
    case carregados([Candidato])
    case semConexao
    case falha
}

public enum ResultadoDaEscolha: Equatable, Sendable {
    /// O candidato está confirmado. `vagaPreenchida` diz que era a última posição: a vaga encheu e
    /// quem ainda esperava foi recusado, com aviso.
    case confirmado(nome: String, vagaPreenchida: Bool)
}

public enum FalhaDaEscolha: Equatable, Sendable {
    /// `409 posicao_ja_preenchida`: outra escolha ocupou a última posição antes (RN19).
    case posicaoJaPreenchida
    /// `409 candidatura_indisponivel`: o candidato retirou a candidatura, ou ela expirou. O mesmo
    /// código vem quando ela já foi escolhida, e aí não é falha: o painel mostra o confirmado.
    case candidaturaIndisponivel(nome: String)
    /// `409 vaga_encerrada`: a seleção fechou (24 h antes do início), ou a vaga foi cancelada.
    case selecaoEncerrada
    /// `422 inelegivel/turno_sobreposto`: foi confirmado em outro turno no mesmo horário (RN21).
    case turnoSobreposto(nome: String)
    /// `422 inelegivel` com outro motivo, como `perfil_suspenso` (RN13).
    case inelegivel(nome: String)
    /// `422 vaga_oculta`: a moderação ocultou a vaga; a candidatura segue pendente.
    case vagaOculta
    /// A chamada não saiu do aparelho. A escolha não entra em fila: fica para a pessoa tentar de novo.
    case semConexao
    case api(ErroDaApi)
}

/// Os candidatos de uma vaga em seleção e a escolha (#10, contrato 0.2.24).
///
/// **A escolha não é idempotente e não entra na fila offline.** O contrato responde `409
/// candidatura_indisponivel` a quem escolhe de novo a candidatura já escolhida, e não devolve o
/// mesmo turno. Por isso, sem rede a tela só avisa; e quando a resposta não diz se a escolha valeu
/// (queda no meio da chamada, ou o 409 de uma segunda tentativa), o view model relê os candidatos
/// e o painel e decide pelo que o servidor mostra: se o profissional está confirmado na vaga, a
/// escolha valeu.
@MainActor @Observable
public final class CandidatosDaVagaViewModel {
    public let vagaID: UUID
    public private(set) var estado = EstadoDosCandidatos.carregando
    public private(set) var resultado: ResultadoDaEscolha?
    public private(set) var falha: FalhaDaEscolha?
    /// A candidatura cuja escolha está em voo: enquanto houver uma, nenhuma outra sai.
    public private(set) var escolhendo: UUID?
    /// O candidato cuja escolha espera a confirmação de quem tocou em "Escolher".
    public private(set) var escolhaEmConfirmacao: Candidato?
    /// A última releitura falhou com uma lista já na tela: o que aparece pode estar velho.
    public private(set) var desatualizada = false

    private let buscar: @Sendable (UUID) async throws -> [Candidato]
    private let escolher: @Sendable (UUID) async throws -> ResultadoConfirmacao
    private let relerVaga: @MainActor () async -> VagaNoPainel?
    /// Sobe a cada resposta do servidor a uma escolha: a leitura que saiu antes dela não vale mais.
    private var geracao = 0

    /// `relerVaga` relê o painel e devolve a vaga como o servidor a mostra agora, ou `nil` se a
    /// leitura falhou. É por ela que a lista de posições de Minhas vagas mostra quem foi confirmado.
    public convenience init(vagaID: UUID, api: any ApiCliente, relerVaga: @escaping @MainActor () async -> VagaNoPainel?) {
        self.init(
            vagaID: vagaID,
            buscar: { try await api.candidatosDaVaga(id: $0) },
            escolher: { try await api.escolherCandidato(candidaturaID: $0) },
            relerVaga: relerVaga
        )
    }

    public init(
        vagaID: UUID,
        buscar: @escaping @Sendable (UUID) async throws -> [Candidato],
        escolher: @escaping @Sendable (UUID) async throws -> ResultadoConfirmacao,
        relerVaga: @escaping @MainActor () async -> VagaNoPainel?
    ) {
        self.vagaID = vagaID
        self.buscar = buscar
        self.escolher = escolher
        self.relerVaga = relerVaga
    }

    public var candidatos: [Candidato] {
        if case let .carregados(lista) = estado { return lista }
        return []
    }

    // MARK: Leitura

    public func carregar() async {
        await ler()
    }

    /// Lê os candidatos e só aplica a resposta se nenhuma escolha respondeu enquanto a leitura
    /// estava em voo: a leitura que saiu antes traria de volta quem acabou de ser confirmado.
    @discardableResult
    private func ler() async -> Bool {
        while true {
            let geracaoDaLeitura = geracao
            let temLista = !candidatos.isEmpty
            if case .carregados = estado {} else { estado = .carregando }
            do {
                let lista = try await buscar(vagaID)
                guard geracaoDaLeitura == geracao else { continue }
                estado = .carregados(lista)
                desatualizada = false
                return true
            } catch {
                // A tela cancela a leitura quando sai, ou quando o painel muda e pede outra: não é falha.
                guard !Task.isCancelled else { return false }
                guard geracaoDaLeitura == geracao else { continue }
                if temLista {
                    // Com candidatos na tela, a falha não os apaga: avisa que podem estar velhos.
                    desatualizada = true
                } else {
                    estado = (error as? ErroDaApi)?.codigo == .semRede ? .semConexao : .falha
                }
                return false
            }
        }
    }

    // MARK: Escolha

    /// A escolha confirma o profissional e libera o contato: a tela pergunta antes.
    public func pedirEscolha(_ candidato: Candidato) {
        guard escolhendo == nil, candidatos.contains(where: { $0.id == candidato.id }) else { return }
        escolhaEmConfirmacao = candidato
    }

    public func desistirDaEscolha() {
        escolhaEmConfirmacao = nil
    }

    /// Só escolhe o candidato que passou por `pedirEscolha`. O pedido é lido aqui, na hora do toque,
    /// e não dentro da tarefa: o alerta, ao fechar, chama `desistirDaEscolha` antes de a tarefa
    /// começar. Um segundo toque enquanto a chamada está em voo não envia outra escolha.
    @discardableResult
    public func confirmarEscolha() -> Task<Void, Never>? {
        guard let candidato = escolhaEmConfirmacao else { return nil }
        escolhaEmConfirmacao = nil
        guard escolhendo == nil else { return nil }
        escolhendo = candidato.id
        return Task { await escolherConfirmado(candidato) }
    }

    private func escolherConfirmado(_ candidato: Candidato) async {
        defer { escolhendo = nil }
        resultado = nil
        falha = nil
        let nome = candidato.profissional.nome
        do {
            _ = try await escolher(candidato.candidaturaID)
            geracao += 1
            // O confirmado sai da lista na hora; a releitura traz o resto como o servidor deixou.
            estado = .carregados(candidatos.filter { $0.id != candidato.id })
            let vaga = await reler()
            resultado = .confirmado(nome: nome, vagaPreenchida: vaga?.estado == .preenchida)
        } catch {
            geracao += 1
            await tratar(error as? ErroDaApi ?? ErroDaApi(codigo: .desconhecido), candidato: candidato)
        }
    }

    private func tratar(_ erro: ErroDaApi, candidato: Candidato) async {
        let nome = candidato.profissional.nome
        switch (erro.codigo, erro.detalhes) {
        case (.semRede, _):
            // Não saiu do aparelho: nada mudou no servidor, e não há o que reler.
            falha = .semConexao
        case (.posicaoJaPreenchida, _):
            // Critério 4: a outra escolha valeu. A releitura mostra quem ficou com a posição.
            await reler()
            falha = .posicaoJaPreenchida
        case (.vagaEncerrada, _):
            await reler()
            falha = .selecaoEncerrada
        case (.inelegivel, "turno_sobreposto"):
            falha = .turnoSobreposto(nome: nome)
        case (.inelegivel, _):
            falha = .inelegivel(nome: nome)
        case (.vagaOculta, _):
            await reler()
            falha = .vagaOculta
        case (.candidaturaIndisponivel, _):
            // Retirada ou expirada; ou já escolhida: por outra pessoa da casa um instante antes (a
            // conferência da já aceita vem antes da vaga cheia), ou por esta mesma tela, numa escolha
            // cuja resposta se perdeu. O painel diz qual das duas.
            if await confirmadoNoPainel(candidato) {
                resultado = .confirmado(nome: nome, vagaPreenchida: vagaRelida?.estado == .preenchida)
            } else {
                falha = .candidaturaIndisponivel(nome: nome)
            }
        default:
            // A resposta não diz se a escolha valeu. Antes de dizer que falhou, pergunta ao servidor.
            if await confirmadoNoPainel(candidato) {
                resultado = .confirmado(nome: nome, vagaPreenchida: vagaRelida?.estado == .preenchida)
            } else {
                falha = .api(erro)
            }
        }
    }

    /// A vaga como a última releitura a trouxe; `nil` se a leitura falhou.
    private var vagaRelida: VagaNoPainel?

    /// Relê os candidatos e o painel. Devolve a vaga do painel, ou `nil` se o painel não pôde ser lido.
    @discardableResult
    private func reler() async -> VagaNoPainel? {
        await ler()
        vagaRelida = await relerVaga()
        if vagaRelida == nil { desatualizada = true }
        return vagaRelida
    }

    private func confirmadoNoPainel(_ candidato: Candidato) async -> Bool {
        guard let vaga = await reler() else { return false }
        return vaga.posicoes.contains { posicao in
            (posicao.estado == .confirmada || posicao.estado == .cumprida) && posicao.profissional?.id == candidato.profissional.id
        }
    }
}

/// Em que pé está a seleção de uma vaga, pelo que o painel diz dela. Quem decide é o servidor,
/// nunca o relógio do aparelho.
enum SituacaoDaSelecao: Equatable {
    /// Publicada: a casa pode escolher.
    case aberta
    /// A moderação ocultou a vaga: os candidatos seguem legíveis, e a escolha é recusada (0.2.23).
    case oculta
    /// Todas as posições foram decididas.
    case concluida
    /// Fechou 24 h antes do início sem ninguém escolhido (RN24).
    case fechadaSemEscolha
    /// Cancelada, ou encerrada depois de ter gente confirmada.
    case encerrada

    init(_ vaga: VagaNoPainel) {
        let temConfirmado = vaga.posicoes.contains { $0.estado == .confirmada || $0.estado == .cumprida }
        switch vaga.estado {
        case .publicada: self = vaga.oculta ? .oculta : .aberta
        case .preenchida: self = .concluida
        case .encerrada: self = temConfirmado ? .encerrada : .fechadaSemEscolha
        case .cancelada: self = .encerrada
        }
    }

    /// A lista só é pedida enquanto pode haver candidato pendente.
    var listaCandidatos: Bool { self == .aberta || self == .oculta }
}

/// A seção "Candidatos" do detalhe da vaga em seleção, em Minhas vagas.
struct SecaoDeCandidatos: View {
    @Environment(BloqueiosDaSessao.self) private var bloqueios: BloqueiosDaSessao?
    private let vaga: VagaNoPainel
    private let abrirPerfil: (PerfilPublico) -> Void
    @State private var viewModel: CandidatosDaVagaViewModel

    init(
        vaga: VagaNoPainel,
        api: any ApiCliente,
        relerVaga: @escaping @MainActor () async -> VagaNoPainel?,
        abrirPerfil: @escaping (PerfilPublico) -> Void
    ) {
        self.vaga = vaga
        self.abrirPerfil = abrirPerfil
        _viewModel = State(initialValue: CandidatosDaVagaViewModel(vagaID: vaga.vaga.id, api: api, relerVaga: relerVaga))
    }

    private var estadoVisivel: EstadoDosCandidatos {
        if case let .carregados(candidatos) = viewModel.estado {
            return .carregados(candidatos.filter { bloqueios?.contem($0.profissional) != true })
        }
        return viewModel.estado
    }

    private var situacao: SituacaoDaSelecao { SituacaoDaSelecao(vaga) }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Text(verbatim: TextosDosCandidatos.titulo).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            avisos
            switch situacao {
            case .aberta:
                Text(verbatim: TextosDosCandidatos.explicacao).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
                lista(podeEscolher: true)
            case .oculta:
                AvisoFrila(verbatim: TextosDosCandidatos.vagaOculta, tom: .alerta)
                    .accessibilityIdentifier("selecao-vaga-oculta")
                lista(podeEscolher: false)
            case .concluida:
                AvisoFrila(verbatim: TextosDosCandidatos.concluida, tom: .informativo)
                    .accessibilityIdentifier("selecao-concluida")
            case .fechadaSemEscolha:
                AvisoFrila(verbatim: TextosDosCandidatos.fechadaSemEscolha, tom: .alerta)
                    .accessibilityIdentifier("selecao-fechada-sem-escolha")
            case .encerrada:
                AvisoFrila(verbatim: TextosDosCandidatos.encerrada, tom: .informativo)
                    .accessibilityIdentifier("selecao-encerrada")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidatos-da-vaga")
        // O painel relido (puxar para atualizar, aviso do push) com outra contagem pede a lista de novo.
        .task(id: vaga.candidatosPendentes) {
            if situacao.listaCandidatos { await viewModel.carregar() }
        }
        .modifier(ConfirmacaoDaEscolha(viewModel: viewModel, ultimaPosicao: vaga.posicoes.count { $0.estado == .aberta } == 1))
    }

    /// A recusa `vaga_oculta` faz a tela reler o painel, e a vaga relida já mostra o aviso de vaga
    /// oculta, com o mesmo texto: aí a falha não aparece, para a tela não dizer a mesma coisa duas
    /// vezes. Se a releitura falhou, a situação não mudou, e a falha é o único aviso.
    static func mostraFalha(_ falha: FalhaDaEscolha, situacao: SituacaoDaSelecao) -> Bool {
        !(falha == .vagaOculta && situacao == .oculta)
    }

    /// O que a última escolha deu. Fica acima da lista, que muda de tamanho com a releitura.
    @ViewBuilder private var avisos: some View {
        if let resultado = viewModel.resultado {
            AvisoFrila(verbatim: TextosDosCandidatos.resultado(resultado), tom: .informativo)
                .accessibilityIdentifier("resultado-da-escolha")
        }
        if let falha = viewModel.falha, Self.mostraFalha(falha, situacao: situacao) {
            AvisoFrila(verbatim: TextosDosCandidatos.falha(falha, desatualizada: viewModel.desatualizada), tom: falha == .semConexao ? .alerta : .erro)
                .accessibilityIdentifier("falha-da-escolha")
        }
        if viewModel.desatualizada {
            AvisoFrila(verbatim: TextosDosCandidatos.desatualizada, tom: .alerta)
                .accessibilityIdentifier("candidatos-desatualizados")
        }
    }

    @ViewBuilder private func lista(podeEscolher: Bool) -> some View {
        switch estadoVisivel {
        case .carregando:
            EstadoCarregando()
        case .semConexao:
            AvisoFrila(verbatim: TextosDosCandidatos.semConexao, tom: .alerta)
                .accessibilityIdentifier("candidatos-sem-conexao")
            botaoDeAtualizar(TextosDosCandidatos.tentarNovamente)
        case .falha:
            AvisoFrila(verbatim: TextosDosCandidatos.falhaAoCarregar, tom: .erro)
                .accessibilityIdentifier("candidatos-falha")
            botaoDeAtualizar(TextosDosCandidatos.tentarNovamente)
        case let .carregados(candidatos) where candidatos.isEmpty:
            EstadoVazio(verbatim: TextosDosCandidatos.vazioTitulo, mensagem: TextosDosCandidatos.vazioMensagem)
                .accessibilityIdentifier("candidatos-vazio")
            botaoDeAtualizar(TextosDosCandidatos.atualizar)
        case let .carregados(candidatos):
            ForEach(candidatos) { candidato in
                cartao(candidato, podeEscolher: podeEscolher)
            }
            botaoDeAtualizar(TextosDosCandidatos.atualizar)
        }
    }

    private func botaoDeAtualizar(_ titulo: String) -> some View {
        BotaoSecundario(verbatim: titulo) { Task { await viewModel.carregar() } }
            .accessibilityIdentifier("atualizar-candidatos")
    }

    private func cartao(_ candidato: Candidato, podeEscolher: Bool) -> some View {
        let perfil = candidato.profissional
        return VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: perfil.nome).font(.headline)
                if !perfil.funcoes.isEmpty {
                    Text(verbatim: String(format: TextosDosCandidatos.funcoes, perfil.funcoes.joined(separator: ", ")))
                        .font(.subheadline)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                // Reputação sempre com o denominador (RN08); sem histórico, diz que não há.
                SeloReputacao(perfil.reputacao)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("dados-do-candidato-\(candidato.id)")

            Button { abrirPerfil(perfil) } label: {
                Text(verbatim: TextosDosCandidatos.verPerfil)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(verbatim: String(format: TextosDosCandidatos.verPerfilDe, perfil.nome)))
            .accessibilityIdentifier("perfil-do-candidato-\(candidato.id)")

            if podeEscolher {
                BotaoPrimario(verbatim: TextosDosCandidatos.escolher, carregando: viewModel.escolhendo == candidato.id) {
                    viewModel.pedirEscolha(candidato)
                }
                .disabled(viewModel.escolhendo != nil)
                .accessibilityLabel(Text(verbatim: String(format: TextosDosCandidatos.escolherNome, perfil.nome)))
                .accessibilityIdentifier("escolher-candidato-\(candidato.id)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidato-\(candidato.id)")
    }
}

/// Escolher confirma o profissional, libera o contato e, na última posição, dispensa os outros
/// candidatos: a pergunta vem antes da chamada.
private struct ConfirmacaoDaEscolha: ViewModifier {
    let viewModel: CandidatosDaVagaViewModel
    let ultimaPosicao: Bool

    func body(content: Content) -> some View {
        content.alert(
            Text(verbatim: TextosDosCandidatos.perguntaDaEscolha),
            isPresented: Binding(get: { viewModel.escolhaEmConfirmacao != nil }, set: { if !$0 { viewModel.desistirDaEscolha() } }),
            presenting: viewModel.escolhaEmConfirmacao
        ) { _ in
            Button {
                viewModel.confirmarEscolha()
            } label: {
                Text(verbatim: TextosDosCandidatos.escolher)
            }
            .accessibilityIdentifier("confirmar-escolha-botao")
            Button(role: .cancel) {
                viewModel.desistirDaEscolha()
            } label: {
                Text(verbatim: TextosDosCandidatos.cancelar)
            }
            .accessibilityIdentifier("cancelar-escolha-botao")
        } message: { candidato in
            // O `presenting` guarda o candidato enquanto o alerta fecha: o nome não some no meio.
            Text(verbatim: String(
                format: ultimaPosicao ? TextosDosCandidatos.avisoDaUltimaPosicao : TextosDosCandidatos.avisoDaEscolha,
                candidato.profissional.nome
            ))
        }
    }
}

/// A linha do cartão de Minhas vagas que diz que a vaga é de seleção e quantos candidatos esperam.
struct RotuloDaSelecao: View {
    let vaga: VagaNoPainel

    var body: some View {
        if vaga.modo == .selecao {
            Text(verbatim: "\(TextosDosCandidatos.rotuloSelecao) · \(Self.detalhe(vaga))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FrilaCor.primaria)
        }
    }

    static func detalhe(_ vaga: VagaNoPainel) -> String {
        switch SituacaoDaSelecao(vaga) {
        case .aberta, .oculta: TextosDosCandidatos.pendentes(vaga.candidatosPendentes)
        case .concluida: TextosDosCandidatos.cartaoConcluida
        case .fechadaSemEscolha: TextosDosCandidatos.cartaoFechadaSemEscolha
        case .encerrada: TextosDosCandidatos.cartaoEncerrada
        }
    }
}
