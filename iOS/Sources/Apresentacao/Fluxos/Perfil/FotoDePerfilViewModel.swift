import Foundation
import FrilaDominio
import Observation

/// A foto de perfil do profissional (contrato 0.2.54, RN37 e RN46): lê o interruptor do servidor e as
/// próprias mídias, leva a foto escolhida pelas verificações do aparelho e pelo envio, e acompanha a
/// decisão da análise automática. Sem pessoa revisando: o app nunca promete revisão humana.
@MainActor @Observable
public final class FotoDePerfilViewModel {
    public enum Etapa: Equatable, Sendable {
        case ocioso, preparando, verificando, enviando
    }

    /// O que a tela diz depois de uma tentativa que não deu certo.
    public enum Aviso: Equatable, Sendable {
        case bloqueadaNoAparelho(MotivoDeBloqueioLocal)
        case imagemInvalida
        case semRede
        case recusadaPeloServidor
        case recursoDesligado
        case expurgada
        case contaSuspensa
        case indisponivelAgora
    }

    /// A mídia mais recente que ainda existe, em qualquer estado menos `removida`.
    public private(set) var midia: Midia?
    /// A foto `aprovada` mais recente: continua à mostra enquanto a nova espera a análise (CD-M13).
    public private(set) var fotoPublicada: Midia?
    public private(set) var recursoLigado = false
    public private(set) var etapa: Etapa = .ocioso
    public private(set) var aviso: Aviso?
    public private(set) var carregando = false
    public private(set) var carregou = false
    public private(set) var falhouAoCarregar = false
    public private(set) var novaAnaliseJaPedida = false
    public let contexto: ContextoDaFotoDePerfil

    private let api: any ApiCliente
    private let ferramentas: FerramentasDaFoto
    private let intervaloDoAcompanhamento: Duration
    private let tentativasDoAcompanhamento: Int

    public init(
        api: any ApiCliente,
        ferramentas: FerramentasDaFoto,
        contexto: ContextoDaFotoDePerfil = .profissional,
        intervaloDoAcompanhamento: Duration = .seconds(5),
        tentativasDoAcompanhamento: Int = 24
    ) {
        self.api = api
        self.ferramentas = ferramentas
        self.contexto = contexto
        self.intervaloDoAcompanhamento = intervaloDoAcompanhamento
        self.tentativasDoAcompanhamento = tentativasDoAcompanhamento
    }

    // MARK: O que a tela mostra

    /// A seção só aparece com o recurso ligado ou com uma foto que ainda se pode remover,
    /// desde que a leitura não tenha falhado.
    public var secaoVisivel: Bool { carregou && !falhouAoCarregar && (recursoLigado || midia != nil) }

    public var enviandoAgora: Bool { etapa != .ocioso }

    /// Escolher, trocar ou tentar outra: só com o recurso ligado e sem envio em curso.
    public var podeEscolherFoto: Bool { recursoLigado && !enviandoAgora }

    public var podePedirNovaAnalise: Bool {
        recursoLigado && !enviandoAgora && !novaAnaliseJaPedida
            && (midia?.estado == .recusada || midia?.estado == .naoPublicada) && midia?.podePedirNovaAnalise == true
    }

    /// Remover vale com o recurso desligado: apagar o próprio dado nunca depende do interruptor.
    public var podeRemover: Bool { midia != nil && !enviandoAgora }

    /// A foto que vai no círculo: a publicada, ou a URL da mídia atual se houver.
    public var urlDaFoto: URL? { fotoPublicada?.url ?? midia?.url }

    public var estaAcompanhando: Bool { midia?.estado == .enviando || midia?.estado == .emAnalise }

    // MARK: Carregar e acompanhar

    public func carregar() async {
        guard !carregando else { return }
        carregando = true
        defer { carregando = false; carregou = true }
        falhouAoCarregar = false
        do {
            // O interruptor falhar não derruba a tela: sem ele o recurso fica desligado (falha fechada).
            recursoLigado = (try? await api.configuracaoDoApp().recursos.fotoDePerfil) ?? false
            aplicar(try await api.minhasMidias())
        } catch {
            falhouAoCarregar = recursoLigado && (midia == nil)
        }
    }

    /// Enquanto a foto está em `enviando` ou `em_analise`, olha de novo a cada poucos segundos, por
    /// um tempo limitado. A análise roda no servidor, em segundo plano, e a resposta não a espera.
    public func acompanhar() async {
        var tentativas = 0
        while estaAcompanhando, tentativas < tentativasDoAcompanhamento, !Task.isCancelled {
            try? await Task.sleep(for: intervaloDoAcompanhamento)
            guard !Task.isCancelled else { return }
            tentativas += 1
            if let midias = try? await api.minhasMidias() { aplicar(midias) }
        }
    }

    // MARK: Enviar

    /// Recorta, converte, confere no aparelho e só então pede a URL e envia. Qualquer falha antes do
    /// envio deixa o servidor sem saber da foto.
    public func enviar(original: Data, recorte: RecorteQuadrado) async {
        guard recursoLigado, !enviandoAgora else { return }
        aviso = nil
        novaAnaliseJaPedida = false
        defer { etapa = .ocioso }

        etapa = .preparando
        let preparador = ferramentas.preparador
        let preparada: FotoPreparada
        do {
            preparada = try await Task.detached(priority: .userInitiated) {
                try preparador.preparar(original: original, recorte: recorte)
            }.value
        } catch {
            aviso = .imagemInvalida
            return
        }

        etapa = .verificando
        if case let .bloqueada(motivo) = await ferramentas.verificador.verificar(jpeg: preparada.jpeg, contexto: contexto) {
            aviso = .bloqueadaNoAparelho(motivo)
            return
        }

        etapa = .enviando
        var pedido: UploadDeMidia?
        do {
            let upload = try await api.solicitarUploadMidia(PedidoDeUploadDeMidia(bytes: preparada.jpeg.count))
            pedido = upload
            try await ferramentas.enviador.enviar(preparada.jpeg, para: upload.uploadURL)
            _ = try await api.confirmarUploadMidia(id: upload.midiaID)
            if let midias = try? await api.minhasMidias() { aplicar(midias) }
        } catch {
            aviso = Self.aviso(para: error)
            // A mídia ficou em `enviando` sem o arquivo: tira do caminho para não travar a tela.
            if let pedido { _ = try? await api.removerMidia(id: pedido.midiaID) }
            if let midias = try? await api.minhasMidias() { aplicar(midias) }
        }
    }

    // MARK: Nova análise e remoção

    public func pedirNovaAnalise() async {
        guard podePedirNovaAnalise, let atual = midia else { return }
        aviso = nil
        do {
            let nova = try await api.pedirNovaAnaliseMidia(id: atual.id)
            novaAnaliseJaPedida = true
            substituir(nova)
        } catch {
            aviso = Self.aviso(para: error)
            if let midias = try? await api.minhasMidias() { aplicar(midias) }
        }
    }

    public func remover() async {
        guard podeRemover, let atual = midia else { return }
        aviso = nil
        do {
            _ = try await api.removerMidia(id: atual.id)
            novaAnaliseJaPedida = false
            aplicar(try await api.minhasMidias())
        } catch {
            aviso = Self.aviso(para: error)
        }
    }

    public func dispensarAviso() { aviso = nil }

    /// Mostra um bloqueio detectado antes do preparo (a foto escolhida não abriu).
    public func registrarImagemInvalida() { aviso = .imagemInvalida }

    // MARK: Estado

    private func aplicar(_ midias: [Midia]) {
        let daConta = midias
            .filter { $0.tipo == .fotoPerfil && $0.estabelecimentoID == nil && $0.estado != .removida }
            .sorted { ($0.enviadaEm ?? .distantPast) > ($1.enviadaEm ?? .distantPast) }
        midia = daConta.first
        fotoPublicada = daConta.first { $0.estado == .aprovada && $0.url != nil }
    }

    private func substituir(_ nova: Midia) {
        if midia?.id == nova.id { midia = nova }
        if nova.estado == .aprovada, nova.url != nil { fotoPublicada = nova }
    }

    nonisolated static func aviso(para erro: Error) -> Aviso {
        guard let erro = erro as? ErroDaApi else { return .indisponivelAgora }
        if erro.recursoDesligado { return .recursoDesligado }
        switch erro.codigo {
        case .semRede: return .semRede
        case .midiaInvalida: return .recusadaPeloServidor
        case .midiaIndisponivel: return erro.detalhes == "expurgada" ? .expurgada : .indisponivelAgora
        case .contaSuspensa: return .contaSuspensa
        case .semPermissao: return erro.detalhes == "conta_suspensa" ? .contaSuspensa : .indisponivelAgora
        default: return .indisponivelAgora
        }
    }
}
