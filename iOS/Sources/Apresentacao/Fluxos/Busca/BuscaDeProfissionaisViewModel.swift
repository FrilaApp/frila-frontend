import Foundation
import FrilaDominio
import Observation

/// O pedaço da API que a busca usa. `ApiCliente` já cumpre; o teste entrega um dublê pequeno.
public protocol FonteDaBuscaDeProfissionais: Sendable {
    func configuracaoDoApp() async throws -> ConfiguracaoApp
    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais
    func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada
    /// 0.2.90: o aceite dos Termos que a busca pede com `termos_pendentes`.
    func aceitarTermos(versao: String) async throws -> AceiteDeTermos
    /// 0.2.95: as leituras com que a casa vê os termos da vaga que o `409 trabalho_ja_aberto` apontou.
    func minhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> [ChamadaResumo]
    func detalheChamada(id: UUID) async throws -> ChamadaDetalhe
}

public extension FonteDaBuscaDeProfissionais {
    /// Fonte sem as leituras (dublê que não simula o 409 da 0.2.95): a leitura dos termos falha, e o 409 vira o erro
    /// genérico, sem repetir. A fonte real é `FonteDaBuscaPelaApi`, que lê pela API.
    func minhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> [ChamadaResumo] {
        throw ErroDaApi(codigo: .naoEncontrado)
    }

    func detalheChamada(id: UUID) async throws -> ChamadaDetalhe { throw ErroDaApi(codigo: .naoEncontrado) }
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
    public func aceitarTermos(versao: String) async throws -> AceiteDeTermos { try await api.aceitarTermos(versao: versao) }
    public func minhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> [ChamadaResumo] {
        try await api.minhasChamadas(estado: estado, cursor: cursor, limite: limite)
    }
    public func detalheChamada(id: UUID) async throws -> ChamadaDetalhe { try await api.detalheChamada(id: id) }
}

/// Os termos da vaga direta que o `409 trabalho_ja_aberto` apontou (0.2.95): o valor vem do item de `minhas_chamadas`
/// e os inclusos do `detalhe_chamada` dele. A chamada que entra nessa vaga vai com estes termos, e não com os digitados.
public struct TermosDaVagaAberta: Equatable, Sendable {
    public let vagaID: UUID
    public let valor: Dinheiro
    public let inclusos: Inclusos

    public init(vagaID: UUID, valor: Dinheiro, inclusos: Inclusos) {
        self.vagaID = vagaID
        self.valor = valor
        self.inclusos = inclusos
    }
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
    /// 0.2.95: a casa já tem o trabalho aberto numa vaga com valor ou inclusos diferentes dos digitados. Não sai até
    /// `confirmarTermosDaVagaAberta()`; aí vai pelo `vaga_id` dela, com os termos dela.
    case pedeConfirmacaoDosTermos(TermosDaVagaAberta)
}

/// A vaga aberta tem termos diferentes: o que a confirmação da casa precisa para mandar quem ficou esperando.
private struct ConfirmacaoDosTermos {
    let termos: TermosDaVagaAberta
    let recusado: PedidoChamada
    let trabalho: PublicacaoVaga
    let recado: String?
}

/// Lançado por `enviar` quando os termos da vaga aberta não batem com os digitados (0.2.95).
private struct TermosDiferentesDaVagaAberta: Error {
    let termos: TermosDaVagaAberta
    let recusado: PedidoChamada
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

extension PublicarVagaViewModel {
    /// A publicação normal abre já com o serviço e o horário da busca vazia (CD-RN35). A região da busca não
    /// entra: a vaga leva a região do estabelecimento (contrato 0.2.20). Sem rascunho nada muda.
    public func preencher(com rascunho: RascunhoDeVagaDaBusca?) {
        guard let rascunho else { return }
        funcaoID = rascunho.funcaoID
        if let horario = rascunho.horario {
            inicio = horario.inicio
            fim = horario.fim
        }
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
        /// O servidor recusou a busca com `termos_pendentes` (0.2.90): a tela pede o aceite dos Termos e, depois dele,
        /// `aceitarTermosERepetirABusca()` repete a busca com os mesmos filtros. Sem aceite, a busca continua bloqueada.
        case termosPendentes
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
    /// `aceitar_termos` em andamento.
    public private(set) var aceitandoTermos = false
    /// O aceite falhou: a tela mostra o aviso e o botão Aceitar segue disponível. A busca continua bloqueada.
    public private(set) var erroNoAceiteDosTermos = false

    private var proximoCursor: String?
    private var filtroDaBusca: FiltroBuscaProfissionais?
    /// Os filtros da busca que o servidor recusou por `termos_pendentes`: a busca repetida depois do aceite usa estes.
    private var filtroDaBuscaPendenteDeTermos: FiltroBuscaProfissionais?
    private let versaoDosTermos: String
    private var recursoConfirmado = false
    private var tentativas: [UUID: PedidoChamada] = [:]
    /// As vagas diretas desta tela, uma por trabalho (comparado sem a chave): a 1ª chamada que deu certo pelo
    /// trabalho criou a vaga (ou o `409 trabalho_ja_aberto` apontou a que já existia, 0.2.95); as seguintes para o
    /// mesmo trabalho entram nela pelo `vaga_id`, inclusive depois de outra busca. Trabalho novo começa outra.
    /// DINHEIRO: nova busca não zera (a vaga é do trabalho, não da busca).
    private var vagasDosTrabalhos: [(trabalho: PublicacaoVaga, id: UUID)] = []
    /// Quem terminou a última tentativa sem resposta definitiva: a chamada pode ter sido criada. Nova busca não
    /// apaga nem eles nem a tentativa (a chave) deles: só a mesma chave descobre o que o servidor fez.
    private var incertos: Set<UUID> = []
    /// 0.2.95: a vaga aberta do trabalho tem termos diferentes dos digitados. Nada do trabalho sai até a casa confirmar.
    private var confirmacaoDosTermos: ConfirmacaoDosTermos?
    /// O trabalho e o recado do 1º envio de cada serviço buscado (`filtroDaBusca.funcaoID`). DINHEIRO: depois dele, todo
    /// reenvio desse serviço (Tentar de novo, Chamar selecionados de novo, J7) repete ESTE trabalho, sem folha nova: um
    /// trabalho diferente (horário que muda a cada abertura, outro valor) faria quem ainda não foi chamado abrir uma 2ª
    /// vaga. Outro serviço é outro trabalho: abre a folha e guarda o seu.
    private var enviadosPorServico: [UUID: (trabalho: PublicacaoVaga, recado: String?)] = [:]
    private let estabelecimentoID: UUID
    private let fonte: any FonteDaBuscaDeProfissionais
    /// O prazo de cada `await` de rede; o teste injeta um menor.
    private let prazo: Duration

    /// `versaoDosTermos`: a versão que a tela de aceite exibe e que `aceitar_termos` recebe.
    public init(fonte: any FonteDaBuscaDeProfissionais, estabelecimentoID: UUID, prazo: Duration = .seconds(15),
                versaoDosTermos: String = VersaoDosTermos.vigente) {
        self.fonte = fonte
        self.estabelecimentoID = estabelecimentoID
        self.prazo = prazo
        self.versaoDosTermos = versaoDosTermos
    }

    public convenience init(api: any ApiCliente, estabelecimentoID: UUID, prazo: Duration = .seconds(15),
                            versaoDosTermos: String = VersaoDosTermos.vigente) {
        self.init(fonte: BuscaDeProfissionaisViewModel.fonte(api: api), estabelecimentoID: estabelecimentoID, prazo: prazo,
                  versaoDosTermos: versaoDosTermos)
    }

    /// A fonte pela API. Só no DEBUG, para o UI test: `-FRILA_BUSCA_RESPOSTA_PERDIDA` perde a 1ª resposta de chamada.
    private static func fonte(api: any ApiCliente) -> any FonteDaBuscaDeProfissionais {
        let fonte = FonteDaBuscaPelaApi(api: api)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FRILA_BUSCA_RESPOSTA_PERDIDA") {
            return FonteDaBuscaComRespostaPerdida(base: fonte)
        }
        #endif
        return fonte
    }

    public var podeBuscar: Bool {
        funcaoID != nil && estado != .carregando && !carregandoMais && !enviando && !aceitandoTermos && !travadoPeloIncerto
    }

    /// DINHEIRO: um pedido que levou o trabalho terminou incerto, e a vaga pode já existir no servidor. Até ele se
    /// resolver no "Tentar de novo" (`chamar`), a seleção não muda e não há busca nova nem página seguinte: trocar
    /// a pessoa ou buscar de novo mandaria o trabalho completo com outra chave e abriria uma 2ª vaga.
    public var travadoPeloIncerto: Bool {
        incertos.contains { tentativas[$0]?.trabalho != nil }
    }

    public var temMais: Bool { proximoCursor != nil && resultados.count < FiltroBuscaProfissionais.maximoDeResultados }

    /// "Publicar para todos" só existe com a busca vazia.
    public var rascunhoParaPublicarParaTodos: RascunhoDeVagaDaBusca? {
        guard estado == .vazio, let filtro = filtroDaBusca else { return nil }
        return RascunhoDeVagaDaBusca(estabelecimentoID: filtro.estabelecimentoID, funcaoID: filtro.funcaoID,
                                     regiaoID: filtro.regiaoID, horario: filtro.horario)
    }

    // MARK: - Busca

    /// A primeira página com os filtros de agora. Zera a seleção e o resultado anterior, mas guarda as vagas por
    /// trabalho e os incertos com as suas chaves. Bloqueada enquanto `travadoPeloIncerto`.
    public func buscar() async {
        guard let funcaoID, podeBuscar else { return }
        let filtro = FiltroBuscaProfissionais(estabelecimentoID: estabelecimentoID, funcaoID: funcaoID,
                                              regiaoID: regiaoID, horario: horario)
        estado = .carregando
        erroAoCarregarMais = nil
        do {
            let fonte = fonte
            let prazo = prazo
            let jaConfirmado = recursoConfirmado
            let pagina = try await PrazoDaAbertura.esperar(prazo) { () -> PaginaBuscaProfissionais? in
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
            filtroDaBuscaPendenteDeTermos = nil
            erroNoAceiteDosTermos = false
            selecionados = []
            resultadosDaChamada = [:]
            confirmacaoDosTermos = nil
            // Fica só a tentativa de quem está incerto (a chave que resolve o que o servidor fez).
            tentativas = tentativas.filter { incertos.contains($0.key) }
            resultados = Self.semRepetidos(pagina.itens, jaTem: [])
            proximoCursor = Self.cursorSeguinte(pagina, total: resultados.count)
            estado = resultados.isEmpty ? .vazio : .resultados
        } catch {
            limparResultados()
            estado = Self.estado(para: error)
            if estado == .termosPendentes { filtroDaBuscaPendenteDeTermos = filtro }
        }
    }

    /// A pessoa aceitou os Termos na tela provisória: chama `aceitar_termos` com a versão exibida e, com o aceite em
    /// vigor, repete a busca com os mesmos filtros que o servidor recusou. Se o aceite falha (`prazo`, sem rede,
    /// recusa), o estado continua `termosPendentes`, com `erroNoAceiteDosTermos`, e nenhuma busca sai. Repetir o aceite
    /// é seguro: o servidor devolve o que já existe para a mesma versão.
    public func aceitarTermosERepetirABusca() async {
        guard estado == .termosPendentes, !aceitandoTermos, let filtro = filtroDaBuscaPendenteDeTermos else { return }
        aceitandoTermos = true
        erroNoAceiteDosTermos = false
        do {
            let fonte = fonte
            let versao = versaoDosTermos
            _ = try await PrazoDaAbertura.esperar(prazo) { try await fonte.aceitarTermos(versao: versao) }
        } catch {
            aceitandoTermos = false
            erroNoAceiteDosTermos = true
            return
        }
        aceitandoTermos = false
        funcaoID = filtro.funcaoID
        regiaoID = filtro.regiaoID
        horario = filtro.horario
        await buscar()
    }

    /// A página seguinte, com o mesmo filtro da busca. Para no fim ou em 200 resultados.
    public func carregarMais() async {
        guard estado == .resultados, !carregandoMais, !enviando, !travadoPeloIncerto, temMais, let filtro = filtroDaBusca,
              let cursor = proximoCursor else { return }
        carregandoMais = true
        erroAoCarregarMais = nil
        defer { carregandoMais = false }
        let faltam = FiltroBuscaProfissionais.maximoDeResultados - resultados.count
        let limite = min(FiltroBuscaProfissionais.limiteDaPagina, faltam)
        do {
            let fonte = fonte
            let pagina = try await PrazoDaAbertura.esperar(prazo) {
                try await fonte.buscarProfissionais(filtro, cursor: cursor, limite: limite)
            }
            let novos = Self.semRepetidos(pagina.itens, jaTem: Set(resultados.map(\.id)))
            resultados += novos.prefix(faltam)
            proximoCursor = Self.cursorSeguinte(pagina, total: resultados.count)
        } catch let erro as ErroDaApi where erro.codigo == .cursorInvalido {
            // Cursor de outra busca ou de outro dia: refaz a primeira página (contrato 0.2.88).
            await refazerPrimeiraPaginaDaBusca(filtro)
        } catch let erro as ErroDaApi where erro.codigo == .limiteExcedido || erro.recursoDesligado || erro.termosPendentes {
            recusarSemPagina(erro, filtro: filtro)
        } catch {
            erroAoCarregarMais = TextosBuscaDeProfissionais.erroAoCarregarMais
        }
    }

    /// `cursor_invalido` no meio do uso: relê a primeira página com o filtro DA BUSCA (não com o que a tela
    /// edita) e troca só a lista e o cursor. Os filtros em edição, as chamadas já enviadas e o J7 pendente ficam.
    /// Quem já foi chamado continua na lista (o servidor o tira, porque a chamada está aberta) para a tela
    /// seguir mostrando o resultado dele.
    private func refazerPrimeiraPaginaDaBusca(_ filtro: FiltroBuscaProfissionais) async {
        do {
            let fonte = fonte
            let pagina = try await PrazoDaAbertura.esperar(prazo) {
                try await fonte.buscarProfissionais(filtro, cursor: nil, limite: FiltroBuscaProfissionais.limiteDaPagina)
            }
            let chamados = resultados.filter { resultadosDaChamada[$0.id] != nil }
            let novos = Self.semRepetidos(pagina.itens, jaTem: Set(chamados.map(\.id)))
            resultados = Array((chamados + novos).prefix(FiltroBuscaProfissionais.maximoDeResultados))
            let presentes = Set(resultados.map(\.id))
            selecionados = selecionados.filter { presentes.contains($0) }
            proximoCursor = Self.cursorSeguinte(pagina, total: resultados.count)
            estado = resultados.isEmpty ? .vazio : .resultados
        } catch let erro as ErroDaApi where erro.codigo == .limiteExcedido || erro.recursoDesligado || erro.termosPendentes {
            recusarSemPagina(erro, filtro: filtro)
        } catch {
            erroAoCarregarMais = TextosBuscaDeProfissionais.erroAoCarregarMais
        }
    }

    /// A página seguinte (ou a releitura do `cursor_invalido`) foi recusada por limite, chave desligada ou
    /// `termos_pendentes`. Com `termos_pendentes` a lista sai e a busca guarda o filtro para repetir depois do aceite.
    private func recusarSemPagina(_ erro: ErroDaApi, filtro: FiltroBuscaProfissionais) {
        estado = Self.estado(para: erro)
        if estado == .termosPendentes {
            limparResultados()
            filtroDaBuscaPendenteDeTermos = filtro
        }
    }

    private func limparResultados() {
        resultados = []
        proximoCursor = nil
        selecionados = []
        confirmacaoDosTermos = nil
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
        // Antes do `switch`: `termos_pendentes` chega como `sem_permissao` e não é a mensagem de permissão.
        if api.termosPendentes { return .termosPendentes }
        switch api.codigo {
        case .limiteExcedido: return .erro(TextosBuscaDeProfissionais.limiteDeBuscas)
        case .contaSuspensa: return .erro(TextosBuscaDeProfissionais.contaSuspensa)
        case .semPermissao:
            return .erro(api.detalhes == CodigoErroAPI.contaSuspensa.rawValue
                         ? TextosBuscaDeProfissionais.contaSuspensa : TextosBuscaDeProfissionais.semPermissao)
        default: return .erro(TextosBuscaDeProfissionais.erro)
        }
    }

    // MARK: - Seleção

    public func estaSelecionado(_ id: UUID) -> Bool { selecionados.contains(id) }

    /// Marca ou desmarca. O 4º não entra: devolve `false` e liga o aviso. Com `travadoPeloIncerto` ou `enviando`, nada
    /// muda (devolve `false`): quem está incerto ou com o pedido em voo continua marcado e vai primeiro no "Tentar de
    /// novo". DINHEIRO: desmarcado, ele sairia da rodada e a outra pessoa levaria o trabalho completo (2ª vaga).
    @discardableResult
    public func alternarSelecao(_ id: UUID) -> Bool {
        guard !travadoPeloIncerto, !enviando else { return false }
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

    /// Com termos da vaga aberta para confirmar (0.2.95), nada sai antes de `confirmarTermosDaVagaAberta()`.
    public var podeChamar: Bool {
        !selecionados.isEmpty && !enviando && estado == .resultados && confirmacaoDosTermos == nil
    }

    /// 0.2.95: os termos da vaga já aberta que a tela provisória mostra para a casa confirmar; `nil` sem pendência.
    public var termosParaConfirmar: TermosDaVagaAberta? { confirmacaoDosTermos?.termos }

    /// A folha dos termos da vaga aberta fica na tela enquanto há termos para confirmar. Fechar a folha sem escolher
    /// (arrastar para baixo) vale como Cancelar: nada sai.
    public var mostrarTermosDaVagaAberta: Bool {
        get { confirmacaoDosTermos != nil }
        set { if !newValue { cancelarTermosDaVagaAberta() } }
    }

    /// O serviço da busca feita (o da lista na tela), e não o do seletor (`funcaoID`), que pode mudar sem Buscar. A folha
    /// monta o trabalho com este.
    public var funcaoDaBusca: UUID? { filtroDaBusca?.funcaoID }

    /// O trabalho e o recado do 1º envio do serviço da busca feita; `nil` se esse serviço ainda não teve envio.
    public var trabalhoEnviado: PublicacaoVaga? { funcaoDaBusca.flatMap { enviadosPorServico[$0]?.trabalho } }
    public var recadoEnviado: String? { funcaoDaBusca.flatMap { enviadosPorServico[$0]?.recado } }

    /// O serviço da busca feita já teve envio: o próximo é um reenvio do mesmo trabalho (`reenviar`), não uma folha nova.
    public var temEnvioRegistrado: Bool { trabalhoEnviado != nil }

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
    /// a próxima vira a 1ª. Cada profissional leva a sua chave; o reenvio (erro ou J7) usa a mesma chave. Se a casa
    /// já tem o trabalho aberto (`409 trabalho_ja_aberto`, 0.2.95), a pessoa vai pelo `vaga_id` dele (`enviar`).
    ///
    /// DINHEIRO: se o pedido que leva o trabalho termina incerto (prazo de 15 s, sem rede, resposta ilegível,
    /// desconhecido), o servidor pode ter criado a vaga e a resposta se perdido. Promover o próximo abriria outra vaga
    /// para o mesmo trabalho. A rodada para: os restantes ficam `.naoEnviada`. No reenvio, esse pedido vai primeiro, com
    /// a mesma chave (o servidor devolve a chamada já criada, com o `vaga_id`), e só depois os outros. A confirmação J7
    /// também espera esse pedido: ela só vale para quem a recebeu, e quem ficou incerto vai sem ela.
    public func chamar(trabalho: PublicacaoVaga, recado: String? = nil, confirmoRecorrencia: Bool = false,
                       chave: () -> UUID = UUID.init) async {
        guard podeChamar, let servico = funcaoDaBusca else { return }
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
        if enviadosPorServico[servico] == nil {
            enviadosPorServico[servico] = (trabalho, recado)
        }
        enviando = true
        defer { enviando = false }
        for (posicao, id) in alvos.enumerated() {
            let pedido = pedidoDaVez(para: id, trabalho: trabalho, recado: recado, chave: chave,
                                     confirmando: confirmoRecorrencia && pendentes.contains(id))
            tentativas[id] = pedido
            do {
                let chamada = try await enviar(pedido, digitado: pedido.trabalho ?? trabalho, chave: chave)
                resultadosDaChamada[id] = .enviada(chamada)
                incertos.remove(id)
                if let enviado = pedido.trabalho, vagaReutilizavel(para: enviado) == nil {
                    vagasDosTrabalhos.append((enviado.comChave(Self.semChave), chamada.vagaID))
                }
            } catch let recusa as ErroDaApi where recusa.codigo == .recorrenciaNaoConfirmada {
                resultadosDaChamada[id] = .pedeConfirmacaoDeRecorrencia
                incertos.remove(id)
            } catch let diferentes as TermosDiferentesDaVagaAberta {
                // 0.2.95: a vaga aberta tem outros termos. Ninguém do trabalho sai antes de a casa confirmar: este e os
                // próximos esperam (quem espera a confirmação J7 continua esperando). O 409 não gastou a chave nem criou
                // nada, então a tentativa deste sai, e a confirmação manda cada um com chave nova.
                confirmacaoDosTermos = ConfirmacaoDosTermos(termos: diferentes.termos, recusado: diferentes.recusado,
                                                            trabalho: trabalho, recado: recado)
                tentativas[id] = nil
                incertos.remove(id)
                resultadosDaChamada[id] = .pedeConfirmacaoDosTermos(diferentes.termos)
                for resto in alvos.dropFirst(posicao + 1) where resultadosDaChamada[resto] != .pedeConfirmacaoDeRecorrencia {
                    resultadosDaChamada[resto] = .pedeConfirmacaoDosTermos(diferentes.termos)
                }
                break
            } catch {
                resultadosDaChamada[id] = .erro(Self.mensagemDaChamada(error))
                guard Self.resultadoIncerto(error) else {
                    incertos.remove(id)
                    continue
                }
                incertos.insert(id)
                // O último pedido que saiu: depois do `409 trabalho_ja_aberto`, é o do `vaga_id`, que não abre vaga.
                guard tentativas[id]?.trabalho != nil else { continue }
                // Quem espera a confirmação J7 continua esperando; os demais nem saem.
                for resto in alvos.dropFirst(posicao + 1) where resultadosDaChamada[resto] != .pedeConfirmacaoDeRecorrencia {
                    resultadosDaChamada[resto] = .naoEnviada
                }
                break
            }
        }
        mostrarJ7 = resultadosDaChamada.values.contains(.pedeConfirmacaoDeRecorrencia)
    }

    /// Reenvia com o trabalho e o recado do 1º envio do serviço da busca feita (nunca um novo). Sem envio desse serviço
    /// não faz nada: o 1º envio de cada serviço passa pela folha de chamada e por `chamar(trabalho:)`.
    public func reenviar(confirmoRecorrencia: Bool = false, chave: () -> UUID = UUID.init) async {
        guard let trabalho = trabalhoEnviado else { return }
        await chamar(trabalho: trabalho, recado: recadoEnviado, confirmoRecorrencia: confirmoRecorrencia, chave: chave)
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

    /// Manda o pedido com o `prazo`. 0.2.95: `409 trabalho_ja_aberto` diz que a casa já tem este trabalho aberto
    /// numa vaga direta, e nada foi criado. A chamada só pode entrar nela, com os termos dela: o app lê o valor e os
    /// inclusos da vaga (`lerTermos`). Iguais aos de `digitado`, o `vaga_id` de `details` passa a ser a vaga do trabalho
    /// e o mesmo profissional vai de novo por ele, num pedido novo com chave nova, como a 2ª e a 3ª chamadas. Diferentes,
    /// nada se repete: lança `TermosDiferentesDaVagaAberta` e a casa decide. Leitura que falha e 409 sem `vaga_id` seguem
    /// a recusa, que vira o erro genérico. Uma vez só: se o pedido pelo `vaga_id` também for recusado, a recusa segue.
    private func enviar(_ pedido: PedidoChamada, digitado: PublicacaoVaga, chave: () -> UUID) async throws -> Chamada {
        do {
            return try await enviarComPrazo(pedido)
        } catch let recusa as ErroDaApi {
            guard let vagaAberta = recusa.vagaDoTrabalhoAberto,
                  let termos = try? await lerTermos(daVaga: vagaAberta) else { throw recusa }
            guard termos.valor == digitado.valor, termos.inclusos == digitado.inclusos else {
                throw TermosDiferentesDaVagaAberta(termos: termos, recusado: pedido)
            }
            guardarVaga(vagaAberta, doTrabalhoDe: pedido)
            let pelaVaga = PedidoChamada(profissionalID: pedido.profissionalID, vagaID: vagaAberta,
                                         estabelecimentoID: pedido.estabelecimentoID, chave: chave(),
                                         recado: pedido.recado, confirmoRecorrencia: pedido.confirmoRecorrencia)
            tentativas[pedido.profissionalID] = pelaVaga
            return try await enviarComPrazo(pelaVaga)
        }
    }

    private func enviarComPrazo(_ pedido: PedidoChamada) async throws -> Chamada {
        let fonte = fonte
        return try await PrazoDaAbertura.esperar(prazo) { try await fonte.chamarProfissional(pedido) }
    }

    /// Os termos da vaga aberta como a casa os lê (0.2.95, e não por `detalhe_vaga`): o valor no item `aberta` de
    /// `minhas_chamadas` com esse `vaga_id` (o trabalho aberto sempre tem um, e a casa tem no máximo 10 abertas, RN34) e
    /// os inclusos no `detalhe_chamada` dele. O mesmo `prazo` para as duas leituras; sem o item, falha.
    private func lerTermos(daVaga vagaID: UUID) async throws -> TermosDaVagaAberta {
        let fonte = fonte
        return try await PrazoDaAbertura.esperar(prazo) {
            let abertas = try await fonte.minhasChamadas(estado: .aberta, cursor: nil, limite: nil)
            guard let chamada = abertas.first(where: { $0.vagaID == vagaID }) else { throw ErroDaApi(codigo: .naoEncontrado) }
            let detalhe = try await fonte.detalheChamada(id: chamada.id)
            return TermosDaVagaAberta(vagaID: vagaID, valor: Dinheiro(centavos: chamada.valorCentavos),
                                      inclusos: Inclusos(refeicao: detalhe.incluiRefeicao, transporte: detalhe.incluiTransporte,
                                                         exigeMaterialProprio: detalhe.exigeMaterialProprio))
        }
    }

    /// A casa confirmou os termos da vaga aberta (0.2.95): ela vira a vaga do trabalho, e quem esperava sai por ela, cada
    /// um num pedido novo com chave nova, com os termos dela.
    public func confirmarTermosDaVagaAberta(chave: () -> UUID = UUID.init) async {
        guard let pendente = confirmacaoDosTermos, !enviando else { return }
        confirmacaoDosTermos = nil
        guardarVaga(pendente.termos.vagaID, doTrabalhoDe: pendente.recusado)
        soltarQuemEsperava(pendente.termos)
        await chamar(trabalho: pendente.trabalho, recado: pendente.recado, chave: chave)
    }

    /// A casa não quis os termos da vaga aberta: nada sai, e quem esperava volta a ficar sem resultado.
    public func cancelarTermosDaVagaAberta() {
        guard let pendente = confirmacaoDosTermos else { return }
        confirmacaoDosTermos = nil
        soltarQuemEsperava(pendente.termos)
    }

    private func soltarQuemEsperava(_ termos: TermosDaVagaAberta) {
        for id in resultadosDaChamada.filter({ $0.value == .pedeConfirmacaoDosTermos(termos) }).keys {
            resultadosDaChamada[id] = nil
        }
    }

    /// A vaga que o `409 trabalho_ja_aberto` apontou vira a vaga do trabalho nesta tela: entra no lugar da que a tela
    /// conhecia (pedido pelo `vaga_id`) ou como a primeira (pedido pelo trabalho). Os próximos entram direto nela.
    private func guardarVaga(_ vagaID: UUID, doTrabalhoDe pedido: PedidoChamada) {
        if let enviado = pedido.trabalho {
            let semChave = enviado.comChave(Self.semChave)
            vagasDosTrabalhos.removeAll { $0.trabalho == semChave }
            vagasDosTrabalhos.append((semChave, vagaID))
        } else if let conhecida = pedido.vagaID, let indice = vagasDosTrabalhos.firstIndex(where: { $0.id == conhecida }) {
            vagasDosTrabalhos[indice].id = vagaID
        }
    }

    /// A vaga direta que esta tela já criou para o mesmo trabalho (sem contar a chave), em qualquer busca, se existe.
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
