// VISUAL PROVISÓRIO: o design de alta fidelidade do modo seleção ainda não chegou (#10). As telas
// usam os componentes que já existem, e os textos são provisórios.

import Foundation
import FrilaDominio
import Observation
import SwiftUI

enum TextosDaCandidaturaEmSelecao {
    // Candidatura enviada e retirada
    static let enviadaTitulo = String(localized: "Candidatura enviada", bundle: bundleApresentacao)
    static let enviadaMensagem = String(localized: "O estabelecimento escolhe entre os candidatos, até 24 horas antes do início do turno. O Frila avisa você quando houver resposta.", bundle: bundleApresentacao)
    static let enviadaContato = String(localized: "Seu telefone e WhatsApp só são mostrados ao estabelecimento se a sua candidatura for escolhida.", bundle: bundleApresentacao)
    static let avisoRN10 = String(localized: "Se a sua candidatura for escolhida, seu telefone e WhatsApp serão mostrados ao %@ para combinar o turno.", bundle: bundleApresentacao)
    static let retirar = String(localized: "Retirar candidatura", bundle: bundleApresentacao)
    static let retirando = String(localized: "Retirando candidatura…", bundle: bundleApresentacao)
    static let perguntaDaRetirada = String(localized: "Retirar a candidatura?", bundle: bundleApresentacao)
    static let avisoDaRetirada = String(localized: "Você deixa de concorrer a esta vaga. Enquanto ela aceitar candidaturas, dá para se candidatar de novo.", bundle: bundleApresentacao)
    static let confirmarRetirada = String(localized: "Retirar", bundle: bundleApresentacao)
    static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    static let retiradaTitulo = String(localized: "Candidatura retirada", bundle: bundleApresentacao)
    static let retiradaMensagem = String(localized: "Você não concorre mais a esta vaga.", bundle: bundleApresentacao)
    static let retiradaNoDetalhe = String(localized: "Candidatura retirada. Enquanto a vaga aceitar candidaturas, você pode se candidatar de novo.", bundle: bundleApresentacao)
    static let retiradaSemConexao = String(localized: "Sem conexão. A candidatura não foi retirada; tente de novo quando a internet voltar.", bundle: bundleApresentacao)
    static let retiradaFalha = String(localized: "Não foi possível retirar a candidatura. Tente de novo.", bundle: bundleApresentacao)
    static let retiradaNaoEncontrada = String(localized: "Não encontramos esta candidatura nesta conta.", bundle: bundleApresentacao)
    static let jaEscolhida = String(localized: "A sua candidatura foi escolhida, e não dá mais para retirá-la. O turno está em Meus turnos.", bundle: bundleApresentacao)
    static let jaRecusada = String(localized: "O estabelecimento escolheu outra pessoa. Não há mais candidatura para retirar.", bundle: bundleApresentacao)
    static let jaExpirada = String(localized: "A vaga foi encerrada ou cancelada. Não há mais candidatura para retirar.", bundle: bundleApresentacao)
    static let jaRespondida = String(localized: "Esta candidatura já teve resposta e não pode mais ser retirada. Veja a situação em Candidaturas.", bundle: bundleApresentacao)
    static let verCandidaturas = String(localized: "Ver minhas candidaturas", bundle: bundleApresentacao)

    // Aba Candidaturas
    static let titulo = String(localized: "Candidaturas", bundle: bundleApresentacao)
    static let aguardando = String(localized: "Aguardando resposta", bundle: bundleApresentacao)
    static let anteriores = String(localized: "Anteriores", bundle: bundleApresentacao)
    static let vazioTitulo = String(localized: "Nenhuma candidatura", bundle: bundleApresentacao)
    static let vazioMensagem = String(localized: "As vagas a que você se candidatar aparecem aqui.", bundle: bundleApresentacao)
    static let erroAoCarregar = String(localized: "Não foi possível carregar as candidaturas.", bundle: bundleApresentacao)
    static let desatualizada = String(localized: "Não foi possível atualizar. A lista de candidaturas pode estar desatualizada.", bundle: bundleApresentacao)
    static let abreAVaga = String(localized: "Abre a vaga", bundle: bundleApresentacao)
    static let abreMeusTurnos = String(localized: "Abre Meus turnos", bundle: bundleApresentacao)
    static let estadoPendente = String(localized: "Aguardando a escolha do estabelecimento", bundle: bundleApresentacao)
    static let estadoAceita = String(localized: "Confirmada: o turno está em Meus turnos", bundle: bundleApresentacao)
    static let estadoRecusada = String(localized: "O estabelecimento escolheu outra pessoa", bundle: bundleApresentacao)
    /// Neutro de propósito: o servidor também passa a `retirada` a candidatura pendente da casa
    /// que foi suspensa ou excluída, e aí não foi a pessoa que a retirou.
    static let estadoRetirada = String(localized: "Candidatura retirada", bundle: bundleApresentacao)
    /// `expirada` é a seleção que fechou sozinha e também a vaga que a casa cancelou; `VagaResumo`
    /// não traz o estado da vaga, e a aba não tem como dizer qual das duas.
    static let estadoExpirada = String(localized: "A vaga foi encerrada ou cancelada antes de a sua candidatura ser escolhida", bundle: bundleApresentacao)

    // Vaga indisponível, para quem tinha candidatura nela (avisos `candidatura_recusada` e `selecao_encerrada`)
    static let recusadaTitulo = String(localized: "O estabelecimento escolheu outra pessoa", bundle: bundleApresentacao)
    static let recusadaMensagem = String(localized: "A vaga foi preenchida, e a sua candidatura não foi escolhida.", bundle: bundleApresentacao)
    static let expiradaTitulo = String(localized: "A seleção desta vaga foi encerrada", bundle: bundleApresentacao)
    static let expiradaMensagem = String(localized: "A vaga fechou sem que a sua candidatura fosse escolhida.", bundle: bundleApresentacao)
    static let canceladaTitulo = String(localized: "O estabelecimento cancelou esta vaga", bundle: bundleApresentacao)
    static let canceladaMensagem = String(localized: "A sua candidatura foi encerrada junto com a vaga.", bundle: bundleApresentacao)
    static let preenchidaEmSelecao = String(localized: "O estabelecimento já escolheu quem vai trabalhar nesta vaga.", bundle: bundleApresentacao)

    static func estado(_ estado: EstadoCandidatura) -> String {
        switch estado {
        case .pendente: estadoPendente
        case .aceita: estadoAceita
        case .recusada: estadoRecusada
        case .retirada: estadoRetirada
        case .expirada: estadoExpirada
        }
    }

    static func falha(_ falha: FalhaDaRetirada) -> String {
        switch falha {
        case .semConexao: retiradaSemConexao
        case .jaRespondida(.aceita): jaEscolhida
        case .jaRespondida(.recusada): jaRecusada
        case .jaRespondida(.expirada): jaExpirada
        case .jaRespondida: jaRespondida
        case .naoEncontrada: retiradaNaoEncontrada
        case .api: retiradaFalha
        }
    }
}

// MARK: - Retirar candidatura

public enum EstadoDaRetirada: Equatable, Sendable {
    /// A candidatura espera a escolha da casa, e pode ser retirada.
    case pendente
    case retirando
    case retirada
    /// O servidor disse que não há mais o que retirar: a tela tira o botão.
    case indisponivel
}

public enum FalhaDaRetirada: Equatable, Sendable {
    /// A chamada não saiu do aparelho. A retirada não entra em fila: fica para a pessoa tentar de novo.
    case semConexao
    /// `409 candidatura_indisponivel`: escolhida, recusada ou expirada. O estado é o que
    /// `minhas_candidaturas` diz dela agora; `nil` se a releitura falhou.
    case jaRespondida(EstadoCandidatura?)
    /// `404`: a candidatura não é desta conta.
    case naoEncontrada
    case api(ErroDaApi)
}

/// Retirar candidatura (#10, contrato 0.2.24). Pede confirmação antes de enviar.
///
/// **A retirada não entra na fila offline.** O contrato a faz idempotente (retirar de novo devolve
/// a mesma), mas a fila a enviaria depois, quando a casa já pode ter escolhido a pessoa: ela
/// acreditaria que saiu e teria um turno. Sem rede é mensagem, e tentar de novo é seguro.
@MainActor @Observable
public final class RetirarCandidaturaViewModel {
    public let candidaturaID: UUID
    public private(set) var estado = EstadoDaRetirada.pendente
    public private(set) var falha: FalhaDaRetirada?
    /// A pessoa tocou em "Retirar candidatura" e ainda não confirmou no alerta.
    public var confirmando = false

    private let enviar: @Sendable (UUID) async throws -> Candidatura
    private let minhasCandidaturas: @Sendable () async throws -> [Candidatura]

    public convenience init(candidaturaID: UUID, api: any ApiCliente) {
        self.init(
            candidaturaID: candidaturaID,
            retirar: { try await api.retirarCandidatura(id: $0) },
            minhasCandidaturas: { try await api.minhasCandidaturas() }
        )
    }

    public init(
        candidaturaID: UUID,
        retirar: @escaping @Sendable (UUID) async throws -> Candidatura,
        minhasCandidaturas: @escaping @Sendable () async throws -> [Candidatura]
    ) {
        self.candidaturaID = candidaturaID
        self.enviar = retirar
        self.minhasCandidaturas = minhasCandidaturas
    }

    public var retirando: Bool { estado == .retirando }

    public func pedirRetirada() {
        guard estado == .pendente else { return }
        confirmando = true
    }

    /// O toque em "Retirar" no alerta. Um segundo toque com a chamada em voo não envia outra.
    public func retirar() async {
        confirmando = false
        guard estado == .pendente else { return }
        estado = .retirando
        falha = nil
        do {
            let candidatura = try await enviar(candidaturaID)
            if candidatura.estado == .retirada {
                estado = .retirada
            } else {
                // O contrato só devolve a retirada; qualquer outro estado é a resposta que a casa já deu.
                estado = .indisponivel
                falha = .jaRespondida(candidatura.estado)
            }
        } catch let erro as ErroDaApi {
            await tratar(erro)
        } catch {
            estado = .pendente
            falha = .api(ErroDaApi(codigo: .desconhecido, codigoOriginal: String(reflecting: type(of: error))))
        }
    }

    private func tratar(_ erro: ErroDaApi) async {
        switch erro.codigo {
        case .semRede:
            estado = .pendente
            falha = .semConexao
        case .candidaturaIndisponivel:
            // Escolhida, recusada ou expirada: a lista da conta diz qual das três.
            let atual = try? await minhasCandidaturas().first { $0.id == candidaturaID }
            estado = .indisponivel
            falha = .jaRespondida(atual?.estado == .pendente ? nil : atual?.estado)
        case .naoEncontrado:
            estado = .indisponivel
            falha = .naoEncontrada
        default:
            estado = .pendente
            falha = .api(erro)
        }
    }
}

/// "Candidatura enviada": a candidatura pendente numa vaga de seleção, com Retirar candidatura.
/// Sem `api` (prévias), mostra só a situação.
struct CandidaturaEnviada: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Presente quando a candidatura está presa ao rodapé do detalhe: a falha vai para a rolagem.
    @Environment(AvisosDoDetalhe.self) private var quadro: AvisosDoDetalhe?
    @State private var viewModel: RetirarCandidaturaViewModel?
    private let compacta: Bool
    private let aoRetirar: () -> Void

    /// `compacta` é a forma do detalhe da vaga, que nos tamanhos de acessibilidade fica presa ao
    /// rodapé: lá a explicação longa não aparece, para sobrar tela para a vaga.
    init(candidaturaID: UUID, api: (any ApiCliente)?, compacta: Bool = false, aoRetirar: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: api.map { RetirarCandidaturaViewModel(candidaturaID: candidaturaID, api: $0) })
        self.compacta = compacta
        self.aoRetirar = aoRetirar
    }

    init(viewModel: RetirarCandidaturaViewModel, compacta: Bool = false, aoRetirar: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.compacta = compacta
        self.aoRetirar = aoRetirar
    }

    private typealias Textos = TextosDaCandidaturaEmSelecao

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            if viewModel?.estado == .retirada {
                situacao(Textos.retiradaTitulo, [Textos.retiradaMensagem], id: "candidatura-retirada")
            } else {
                // Depois do 409 a candidatura já teve resposta: a tela não diz mais "enviada".
                if viewModel?.estado != .indisponivel {
                    situacao(Textos.enviadaTitulo, explicacao, id: "candidatura-enviada")
                }
                if let viewModel {
                    if quadro == nil, let aviso = avisoDaFalha {
                        AvisoFrila(verbatim: aviso.texto, tom: aviso.tom).accessibilityIdentifier(aviso.id)
                    }
                    if viewModel.estado != .indisponivel {
                        BotaoSecundario(verbatim: Textos.retirar) { viewModel.pedirRetirada() }
                            .disabled(viewModel.retirando)
                            .accessibilityHint(viewModel.retirando ? Textos.retirando : "")
                            .accessibilityIdentifier("retirar-candidatura")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ConfirmacaoDaRetirada(viewModel: viewModel))
        .onChange(of: viewModel?.estado) { _, novo in
            guard novo == .retirada else { return }
            AccessibilityNotification.Announcement(Textos.retiradaTitulo).post()
            aoRetirar()
        }
        .onChange(of: viewModel?.falha) { _, nova in
            if let nova { AccessibilityNotification.Announcement(Textos.falha(nova)).post() }
        }
        .onChange(of: avisoDaFalha, initial: true) { _, novo in quadro?.publicar(novo, de: Self.donoDosAvisos) }
        .onDisappear { quadro?.publicar(nil, de: Self.donoDosAvisos) }
    }

    private static let donoDosAvisos = "retirar"

    private var avisoDaFalha: AvisosDoDetalhe.Aviso? {
        guard let falha = viewModel?.falha, viewModel?.estado != .retirada else { return nil }
        return .init(id: "retirada-falha", texto: Textos.falha(falha), tom: falha == .semConexao ? .alerta : .erro)
    }

    private var explicacao: [String] {
        compacta && dynamicTypeSize.isAccessibilitySize ? [] : [Textos.enviadaMensagem, Textos.enviadaContato]
    }

    private func situacao(_ titulo: String, _ paragrafos: [String], id: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: titulo).font(compacta ? .headline : .title2.bold()).accessibilityAddTraits(.isHeader)
            ForEach(paragrafos, id: \.self) { paragrafo in
                Text(verbatim: paragrafo).font(compacta ? .subheadline : .body).foregroundStyle(FrilaCor.textoSecundario)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

private struct ConfirmacaoDaRetirada: ViewModifier {
    let viewModel: RetirarCandidaturaViewModel?

    func body(content: Content) -> some View {
        content.alert(
            Text(verbatim: TextosDaCandidaturaEmSelecao.perguntaDaRetirada),
            isPresented: Binding(get: { viewModel?.confirmando ?? false }, set: { viewModel?.confirmando = $0 })
        ) {
            Button(role: .destructive) {
                Task { await viewModel?.retirar() }
            } label: {
                Text(verbatim: TextosDaCandidaturaEmSelecao.confirmarRetirada)
            }
            Button(role: .cancel) {} label: {
                Text(verbatim: TextosDaCandidaturaEmSelecao.cancelar)
            }
        } message: {
            Text(verbatim: TextosDaCandidaturaEmSelecao.avisoDaRetirada)
        }
    }
}

// MARK: - Minhas candidaturas

public enum EstadoDasCandidaturas: Equatable, Sendable {
    case ociosa
    case carregando
    case carregadas([Candidatura])
    case semConexao
    case falha
}

/// A aba Candidaturas de quem trabalha (#10): o que `minhas_candidaturas` devolve, da mais nova
/// para a mais antiga, com as que esperam resposta em primeiro lugar.
@MainActor @Observable
public final class MinhasCandidaturasViewModel {
    public private(set) var estado = EstadoDasCandidaturas.ociosa
    /// A última releitura falhou com uma lista já na tela: o que aparece pode estar velho.
    public private(set) var desatualizada = false
    private let buscar: @Sendable () async throws -> [Candidatura]

    public convenience init(api: any ApiCliente) {
        self.init(buscar: { try await api.minhasCandidaturas() })
    }

    public init(buscar: @escaping @Sendable () async throws -> [Candidatura]) {
        self.buscar = buscar
    }

    public var candidaturas: [Candidatura] {
        if case let .carregadas(lista) = estado { return lista }
        return []
    }

    /// As que esperam a escolha da casa, na ordem em que o servidor as devolve.
    public var pendentes: [Candidatura] { candidaturas.filter { $0.estado == .pendente } }
    /// As que já tiveram desfecho: confirmada, recusada, retirada ou expirada.
    public var anteriores: [Candidatura] { candidaturas.filter { $0.estado != .pendente } }

    /// Uma leitura por vez. O pedido que chega com outra em voo não abre uma segunda chamada.
    private var lendo = false
    /// Uma releitura foi pedida com outra em voo: a que está em voo pode ter saído antes da
    /// mudança que motivou o pedido, então a lista é lida de novo quando ela voltar.
    private var releituraPedida = false

    /// A primeira leitura, e a nova tentativa depois de uma falha. Com uma leitura já em voo não
    /// faz nada: ela traz o que há.
    public func carregar() async {
        guard !lendo else { return }
        await ler()
    }

    /// Releitura com a lista na tela: se falha, a lista fica e a tela avisa que pode estar velha.
    /// Antes da primeira leitura não lê: quem carrega é a tela, quando aparece.
    public func atualizar() async {
        switch estado {
        case .ociosa, .carregando:
            return
        case .carregadas, .semConexao, .falha:
            guard !lendo else {
                releituraPedida = true
                return
            }
            await ler()
        }
    }

    private func ler() async {
        lendo = true
        defer { lendo = false }
        repeat {
            releituraPedida = false
            if case .carregadas = estado {} else { estado = .carregando }
            do {
                estado = .carregadas(try await buscar())
                desatualizada = false
            } catch {
                if Task.isCancelled {
                    // A tela cancela a leitura quando sai: não é falha. O estado não pode ficar em
                    // "carregando", ou nenhuma leitura sairia mais: volta ao início, e a tela
                    // carrega de novo quando reaparecer.
                    if estado == .carregando { estado = .ociosa }
                    return
                }
                if case .carregadas = estado {
                    desatualizada = true
                } else {
                    estado = (error as? ErroDaApi)?.codigo == .semRede ? .semConexao : .falha
                }
            }
        } while releituraPedida && !Task.isCancelled
    }
}

/// A aba Candidaturas. O toque numa candidatura leva à vaga dela, ou a Meus turnos se foi confirmada.
public struct TelaMinhasCandidaturas: View {
    @Bindable private var viewModel: MinhasCandidaturasViewModel
    private let abrir: (Candidatura) -> Void

    public init(viewModel: MinhasCandidaturasViewModel, abrir: @escaping (Candidatura) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    private typealias Textos = TextosDaCandidaturaEmSelecao

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) { conteudo }
                .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: Textos.titulo))
        .refreshable { await viewModel.atualizar() }
        .task { if viewModel.estado == .ociosa { await viewModel.carregar() } }
        .accessibilityIdentifier("tela-minhas-candidaturas")
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .ociosa, .carregando:
            EstadoCarregando()
        case .carregadas:
            if viewModel.desatualizada {
                AvisoFrila(verbatim: Textos.desatualizada, tom: .alerta)
                    .accessibilityIdentifier("candidaturas-desatualizadas")
            }
            if viewModel.candidaturas.isEmpty {
                EstadoVazio(verbatim: Textos.vazioTitulo, mensagem: Textos.vazioMensagem)
                    .accessibilityIdentifier("candidaturas-vazio")
            } else {
                secao(Textos.aguardando, viewModel.pendentes)
                secao(Textos.anteriores, viewModel.anteriores)
            }
        case .semConexao:
            AvisoFrila(verbatim: TextosDoProfissional.Lista.semConexaoMensagem, tom: .alerta)
                .accessibilityIdentifier("candidaturas-sem-conexao")
            BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
        case .falha:
            EstadoErro(verbatim: Textos.erroAoCarregar) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("candidaturas-erro")
        }
    }

    @ViewBuilder
    private func secao(_ titulo: String, _ candidaturas: [Candidatura]) -> some View {
        if !candidaturas.isEmpty {
            Text(verbatim: titulo).font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(candidaturas) { candidatura in
                Button { abrir(candidatura) } label: { CartaoDaCandidatura(candidatura: candidatura) }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.medio))
                    .accessibilityIdentifier("candidatura-\(candidatura.id.uuidString)")
                    .accessibilityHint(candidatura.estado == .aceita ? Textos.abreMeusTurnos : Textos.abreAVaga)
            }
        }
    }
}

struct CartaoDaCandidatura: View {
    let candidatura: Candidatura
    private let formatador = FormatadorFrila()

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    funcao
                    Spacer()
                    valor
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    funcao
                    valor
                }
            }
            Label {
                Text(verbatim: formatador.intervalo(candidatura.vaga.periodo))
            } icon: {
                Image(systemName: "calendar")
            }
            Label {
                Text(verbatim: candidatura.vaga.local)
            } icon: {
                Image(systemName: "mappin.and.ellipse")
            }
            Label {
                Text(verbatim: TextosDaCandidaturaEmSelecao.estado(candidatura.estado)).fontWeight(.semibold)
            } icon: {
                Image(systemName: icone)
            }
            .foregroundStyle(candidatura.estado == .pendente || candidatura.estado == .aceita ? FrilaCor.texto : FrilaCor.textoSecundario)
        }
        .font(.subheadline)
        .foregroundStyle(FrilaCor.texto)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }

    private var funcao: some View { Text(verbatim: candidatura.vaga.funcao).font(.headline) }

    private var valor: some View {
        Text(verbatim: formatador.dinheiro(candidatura.vaga.valor)).font(.headline).foregroundStyle(FrilaCor.primaria)
    }

    private var icone: String {
        switch candidatura.estado {
        case .pendente: "hourglass"
        case .aceita: "checkmark.circle"
        case .recusada, .expirada: "xmark.circle"
        case .retirada: "arrow.uturn.backward.circle"
        }
    }
}
