import Foundation
import FrilaDominio
import Observation

/// O pedaço da API que a busca usa. `ApiCliente` já cumpre; o teste entrega um dublê pequeno.
public protocol FonteDaBuscaDeProfissionais: Sendable {
    func configuracaoDoApp() async throws -> ConfiguracaoApp
    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais
    func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada
}

/// Liga a porta `ApiCliente` à fonte da busca.
public struct FonteDaBuscaPelaApi: FonteDaBuscaDeProfissionais {
    private let api: any ApiCliente
    public init(api: any ApiCliente) { self.api = api }
    public func configuracaoDoApp() async throws -> ConfiguracaoApp { try await api.configuracaoDoApp() }
    public func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
        try await api.buscarProfissionais(filtro, cursor: cursor, limite: limite)
    }
    public func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada { try await api.chamarProfissional(pedido) }
}

/// O que a busca devolveu para um profissional escolhido ao chamar.
public enum ResultadoDaChamadaDaBusca: Equatable, Sendable {
    case enviada(Chamada)
    /// J7: o servidor pediu a confirmação da recorrência; reenvie com `confirmoRecorrencia: true`.
    case pedeConfirmacaoDeRecorrencia
    case erro(String)
    /// Não saiu: o pedido que leva o trabalho terminou incerto (prazo, sem rede, resposta ilegível) e a vaga pode
    /// já existir. Mandar este agora poderia abrir outra vaga para o mesmo trabalho. Sai no reenvio.
    case naoEnviada
}

/// O que a tela de publicar usa para abrir a vaga normal já com o que foi buscado (CD-RN35).
public struct RascunhoDeVagaDaBusca: Equatable, Sendable {
    public let estabelecimentoID: UUID
    public let funcaoID: UUID
    public let regiaoID: Int?
    public let horario: Periodo?

    public init(estabelecimentoID: UUID, funcaoID: UUID, regiaoID: Int? = nil, horario: Periodo? = nil) {
        self.estabelecimentoID = estabelecimentoID
        self.funcaoID = funcaoID
        self.regiaoID = regiaoID
        self.horario = horario
    }
}

@MainActor @Observable
public final class BuscaDeProfissionaisViewModel {
    public enum Estado: Equatable, Sendable {
        case ocioso
        case carregando
        case resultados
        /// A busca terminou sem ninguém: oferece "Publicar para todos".
        case vazio
        /// A chave `buscaProfissionais` está desligada (ou o servidor recusou com `recurso_desligado`).
        case indisponivel
        case erro(String)
    }

    /// Até 3 profissionais por chamada (CD-B09).
    public static let maximoDeSelecionados = 3

    // Filtros: o serviço é obrigatório; região e horário são opcionais.
    public var funcaoID: UUID?
    public var regiaoID: Int?
    public var horario: Periodo?

    public private(set) var estado: Estado = .ocioso
    public private(set) var resultados: [CartaoProfissional] = []
    public private(set) var carregandoMais = false
    public private(set) var erroAoCarregarMais: String?
    public private(set) var selecionados: [UUID] = []
    /// Ligado quando alguém tenta entrar como 4º; a tela mostra o aviso e apaga com `dispensarAvisoDeLimite()`.
    public private(set) var avisoDeLimiteDeSelecao: String?
    public private(set) var enviando = false
    public private(set) var resultadosDaChamada: [UUID: ResultadoDaChamadaDaBusca] = [:]
    public var mostrarJ7 = false

    private var proximoCursor: String?
    private var filtroDaBusca: FiltroBuscaProfissionais?
    private var recursoConfirmado = false
    private var tentativas: [UUID: PedidoChamada] = [:]
    /// As vagas diretas desta busca, uma por trabalho (comparado sem a chave): a 1ª chamada que deu certo pelo
    /// trabalho criou a vaga; as seguintes para o mesmo trabalho entram nela pelo `vaga_id`. Trabalho novo começa
    /// outra; nova busca zera.
    private var vagasDosTrabalhos: [(trabalho: PublicacaoVaga, id: UUID)] = []
    /// Quem terminou a última tentativa sem resposta definitiva: a chamada pode ter sido criada.
    private var incertos: Set<UUID> = []
    private let estabelecimentoID: UUID
    private let fonte: any FonteDaBuscaDeProfissionais

    public init(fonte: any FonteDaBuscaDeProfissionais, estabelecimentoID: UUID) {
        self.fonte = fonte
        self.estabelecimentoID = estabelecimentoID
    }

    public convenience init(api: any ApiCliente, estabelecimentoID: UUID) {
        self.init(fonte: FonteDaBuscaPelaApi(api: api), estabelecimentoID: estabelecimentoID)
    }

    public var podeBuscar: Bool {
        funcaoID != nil && estado != .carregando && !carregandoMais && !enviando
    }

    public var temMais: Bool { proximoCursor != nil && resultados.count < FiltroBuscaProfissionais.maximoDeResultados }

    /// "Publicar para todos" só existe com a busca vazia.
    public var rascunhoParaPublicarParaTodos: RascunhoDeVagaDaBusca? {
        guard estado == .vazio, let filtro = filtroDaBusca else { return nil }
        return RascunhoDeVagaDaBusca(estabelecimentoID: filtro.estabelecimentoID, funcaoID: filtro.funcaoID,
                                     regiaoID: filtro.regiaoID, horario: filtro.horario)
    }

    // MARK: - Busca

    /// A primeira página com os filtros de agora. Zera a seleção e o resultado anterior.
    public func buscar() async {
        guard let funcaoID, podeBuscar else { return }
        let filtro = FiltroBuscaProfissionais(estabelecimentoID: estabelecimentoID, funcaoID: funcaoID,
                                              regiaoID: regiaoID, horario: horario)
        estado = .carregando
        erroAoCarregarMais = nil
        do {
            let fonte = fonte
            let jaConfirmado = recursoConfirmado
            let pagina = try await PrazoDaAbertura.esperar(.seconds(15)) { () -> PaginaBuscaProfissionais? in
                if !jaConfirmado {
                    let configuracao = try await fonte.configuracaoDoApp()
                    guard configuracao.recursos.buscaProfissionais else { return nil }
                }
                return try await fonte.buscarProfissionais(filtro, cursor: nil, limite: FiltroBuscaProfissionais.limiteDaPagina)
            }
            guard let pagina else {
                estado = .indisponivel
                limparResultados()
                return
            }
            recursoConfirmado = true
            filtroDaBusca = filtro
            selecionados = []
            resultadosDaChamada = [:]
            tentativas = [:]
            vagasDosTrabalhos = []
            incertos = []
            resultados = Self.semRepetidos(pagina.itens, jaTem: [])
            proximoCursor = Self.cursorSeguinte(pagina, total: resultados.count)
            estado = resultados.isEmpty ? .vazio : .resultados
        } catch {
            limparResultados()
            estado = Self.estado(para: error)
        }
    }

    /// A página seguinte, com o mesmo filtro da busca. Para no fim ou em 200 resultados.
    public func carregarMais() async {
        guard estado == .resultados, !carregandoMais, !enviando, temMais, let filtro = filtroDaBusca,
              let cursor = proximoCursor else { return }
        carregandoMais = true
        erroAoCarregarMais = nil
        defer { carregandoMais = false }
        let faltam = FiltroBuscaProfissionais.maximoDeResultados - resultados.count
        let limite = min(FiltroBuscaProfissionais.limiteDaPagina, faltam)
        do {
            let fonte = fonte
            let pagina = try await PrazoDaAbertura.esperar(.seconds(15)) {
                try await fonte.buscarProfissionais(filtro, cursor: cursor, limite: limite)
            }
            let novos = Self.semRepetidos(pagina.itens, jaTem: Set(resultados.map(\.id)))
            resultados += novos.prefix(faltam)
            proximoCursor = Self.cursorSeguinte(pagina, total: resultados.count)
        } catch let erro as ErroDaApi where erro.codigo == .cursorInvalido {
            // Cursor de outra busca ou de outro dia: refaz a primeira página (contrato 0.2.88).
            carregandoMais = false
            await refazerAPartirDoFiltroDaBusca(filtro)
        } catch let erro as ErroDaApi where erro.codigo == .limiteExcedido || erro.recursoDesligado {
            estado = Self.estado(para: erro)
        } catch {
            erroAoCarregarMais = TextosBuscaDeProfissionais.erroAoCarregarMais
        }
    }

    private func refazerAPartirDoFiltroDaBusca(_ filtro: FiltroBuscaProfissionais) async {
        funcaoID = filtro.funcaoID
        regiaoID = filtro.regiaoID
        horario = filtro.horario
        estado = .ocioso
        await buscar()
    }

    private func limparResultados() {
        resultados = []
        proximoCursor = nil
        selecionados = []
    }

    private static func cursorSeguinte(_ pagina: PaginaBuscaProfissionais, total: Int) -> String? {
        total >= FiltroBuscaProfissionais.maximoDeResultados ? nil : pagina.proximoCursor
    }

    private static func semRepetidos(_ itens: [CartaoProfissional], jaTem: Set<UUID>) -> [CartaoProfissional] {
        var vistos = jaTem
        return itens.filter { vistos.insert($0.id).inserted }
    }

    private static func estado(para erro: Error) -> Estado {
        guard let api = erro as? ErroDaApi else { return .erro(TextosBuscaDeProfissionais.erro) }
        if api.recursoDesligado { return .indisponivel }
        if api.codigo == .limiteExcedido { return .erro(TextosBuscaDeProfissionais.limiteDeBuscas) }
        return .erro(TextosBuscaDeProfissionais.erro)
    }

    // MARK: - Seleção

    public func estaSelecionado(_ id: UUID) -> Bool { selecionados.contains(id) }

    /// Marca ou desmarca. O 4º não entra: devolve `false` e liga o aviso.
    @discardableResult
    public func alternarSelecao(_ id: UUID) -> Bool {
        if let indice = selecionados.firstIndex(of: id) {
            selecionados.remove(at: indice)
            avisoDeLimiteDeSelecao = nil
            return true
        }
        guard resultados.contains(where: { $0.id == id }) else { return false }
        guard selecionados.count < Self.maximoDeSelecionados else {
            avisoDeLimiteDeSelecao = TextosBuscaDeProfissionais.limiteDeSelecao
            return false
        }
        selecionados.append(id)
        return true
    }

    public func dispensarAvisoDeLimite() { avisoDeLimiteDeSelecao = nil }

    // MARK: - Chamar

    public var podeChamar: Bool { !selecionados.isEmpty && !enviando && estado == .resultados }

    /// Há selecionado com erro ou que nem saiu: `chamar` de novo reenvia só esses, cada um com a chave que já tinha.
    public var podeReenviar: Bool {
        podeChamar && selecionados.contains { id in
            switch resultadosDaChamada[id] {
            case .erro, .naoEnviada: true
            default: false
            }
        }
    }

    /// Cria a chamada para cada selecionado pela `chamarProfissional`, uma de cada vez. A 1ª que der certo leva o
    /// trabalho (com a região da busca) e o servidor cria a vaga direta; as seguintes levam o `vaga_id` dela, para
    /// as até 3 chamadas serem do mesmo trabalho (contrato 0.2.55). Se o servidor recusar a 1ª (erro definitivo ou J7),
    /// a próxima vira a 1ª. Cada profissional leva a sua chave; o reenvio (erro ou J7) usa a mesma chave.
    ///
    /// DINHEIRO: se o pedido que leva o trabalho termina incerto (prazo de 15 s, sem rede, resposta ilegível,
    /// desconhecido), o servidor pode ter criado a vaga e a resposta se perdido. Promover o próximo abriria outra vaga
    /// para o mesmo trabalho. A rodada para: os restantes ficam `.naoEnviada`. No reenvio, esse pedido vai primeiro, com
    /// a mesma chave (o servidor devolve a chamada já criada, com o `vaga_id`), e só depois os outros. A confirmação J7
    /// também espera esse pedido: ela só vale para quem a recebeu, e quem ficou incerto vai sem ela.
    public func chamar(trabalho: PublicacaoVaga, recado: String? = nil, confirmoRecorrencia: Bool = false,
                       chave: () -> UUID = UUID.init) async {
        guard podeChamar else { return }
        let pendentes = selecionados.filter { resultadosDaChamada[$0] == .pedeConfirmacaoDeRecorrencia }
        // A confirmação J7 só vale depois da recusa correspondente.
        guard !confirmoRecorrencia || !pendentes.isEmpty else { return }
        // Quem ficou incerto levando o trabalho resolve a vaga antes de qualquer outro, inclusive na confirmação J7:
        // o confirmado só sai depois, e pelo `vaga_id` se a vaga existir. Se continuar incerto, o confirmado nem sai.
        let primeiros = selecionados.filter { incertos.contains($0) && tentativas[$0]?.trabalho != nil }
        let alvos = primeiros + selecionados.filter { id in
            if case .enviada = resultadosDaChamada[id] { return false }
            return !primeiros.contains(id) && (!confirmoRecorrencia || pendentes.contains(id))
        }
        enviando = true
        defer { enviando = false }
        for (posicao, id) in alvos.enumerated() {
            let pedido = pedidoDaVez(para: id, trabalho: trabalho, recado: recado, chave: chave,
                                     confirmando: confirmoRecorrencia && pendentes.contains(id))
            tentativas[id] = pedido
            do {
                let fonte = fonte
                let chamada = try await PrazoDaAbertura.esperar(.seconds(15)) { try await fonte.chamarProfissional(pedido) }
                resultadosDaChamada[id] = .enviada(chamada)
                incertos.remove(id)
                if let enviado = pedido.trabalho, vagaReutilizavel(para: enviado) == nil {
                    vagasDosTrabalhos.append((enviado.comChave(Self.semChave), chamada.vagaID))
                }
            } catch let recusa as ErroDaApi where recusa.codigo == .recorrenciaNaoConfirmada {
                resultadosDaChamada[id] = .pedeConfirmacaoDeRecorrencia
                incertos.remove(id)
            } catch {
                resultadosDaChamada[id] = .erro(Self.mensagemDaChamada(error))
                guard Self.resultadoIncerto(error) else {
                    incertos.remove(id)
                    continue
                }
                incertos.insert(id)
                guard pedido.trabalho != nil else { continue }
                // Quem espera a confirmação J7 continua esperando; os demais nem saem.
                for resto in alvos.dropFirst(posicao + 1) where resultadosDaChamada[resto] != .pedeConfirmacaoDeRecorrencia {
                    resultadosDaChamada[resto] = .naoEnviada
                }
                break
            }
        }
        mostrarJ7 = resultadosDaChamada.values.contains(.pedeConfirmacaoDeRecorrencia)
    }

    /// O pedido de um selecionado nesta rodada. Quem ainda não tentou leva o `vaga_id` da vaga do trabalho, se
    /// ela já existe, ou o trabalho com uma chave nova. Quem tentou repete a chave; se foi pelo trabalho e a vaga
    /// passou a existir, vai pelo `vaga_id` dela: o servidor só guarda a chave quando cria a chamada e, se o
    /// envio anterior criou (resposta perdida), a mesma chave devolve aquela chamada em vez de abrir outra.
    private func pedidoDaVez(para id: UUID, trabalho: PublicacaoVaga, recado: String?, chave: () -> UUID,
                             confirmando: Bool) -> PedidoChamada {
        let base: PedidoChamada
        if let anterior = tentativas[id] {
            if let antigo = anterior.trabalho, let vagaID = vagaReutilizavel(para: antigo) {
                base = PedidoChamada(profissionalID: id, vagaID: vagaID, estabelecimentoID: antigo.estabelecimentoID,
                                     chave: anterior.chave, recado: anterior.recado)
            } else {
                base = anterior
            }
        } else if let vagaID = vagaReutilizavel(para: trabalho) {
            base = PedidoChamada(profissionalID: id, vagaID: vagaID, estabelecimentoID: trabalho.estabelecimentoID,
                                 chave: chave(), recado: Self.recadoEnviado(recado))
        } else {
            base = PedidoChamada(profissionalID: id, trabalho: trabalho.comChave(chave()), recado: Self.recadoEnviado(recado),
                                 regiaoID: filtroDaBusca?.regiaoID)
        }
        return base.confirmando(confirmando || base.confirmoRecorrencia)
    }

    /// A vaga direta que esta busca já criou para o mesmo trabalho (sem contar a chave), se existe.
    private func vagaReutilizavel(para trabalho: PublicacaoVaga) -> UUID? {
        let semChave = trabalho.comChave(Self.semChave)
        return vagasDosTrabalhos.first { $0.trabalho == semChave }?.id
    }

    /// Sem resposta definitiva do servidor (prazo, sem rede, resposta ilegível, desconhecido): a chamada pode ter
    /// sido criada, e só a mesma chave descobre. Qualquer outra recusa é do servidor e definitiva.
    private static func resultadoIncerto(_ erro: Error) -> Bool {
        guard let api = erro as? ErroDaApi else { return true }
        return [.semRede, .respostaInvalida, .desconhecido].contains(api.codigo)
    }

    private static let semChave = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    private static func recadoEnviado(_ recado: String?) -> String? { recado?.isEmpty == true ? nil : recado }

    private static func mensagemDaChamada(_ erro: Error) -> String {
        switch (erro as? ErroDaApi)?.codigo {
        case .chamadaJaAberta: TextosChamadaDireta.jaAberta
        case .chamadaIndisponivel, .profissionalIndisponivel, .naoEncontrado: TextosChamadaDireta.indisponivel
        case .limiteDeChamadas: TextosChamadaDireta.limite
        case .recursoDesligado: TextosChamadaDireta.desligado
        default: TextosChamadaDireta.erro
        }
    }
}

private extension PublicacaoVaga {
    func comChave(_ chave: UUID) -> PublicacaoVaga {
        PublicacaoVaga(estabelecimentoID: estabelecimentoID, funcaoID: funcaoID, periodo: periodo, local: local,
                       regiaoAdministrativa: regiaoAdministrativa, ponto: ponto, valor: valor, posicoes: posicoes,
                       inclusos: inclusos, responsavelLocal: responsavelLocal, traje: traje, participaRateio: participaRateio,
                       observacoes: observacoes, modo: modo, alertaAntecedenciaMinutos: alertaAntecedenciaMinutos, chave: chave)
    }
}
