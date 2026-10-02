import Foundation
import FrilaDominio
import Supabase

public final class SupabaseApiCliente: ApiCliente, ObservadorDeSessao, @unchecked Sendable {
    private let cliente: SupabaseClient
    private let decodificador = ContratoAPI.decodificador()
    private let telemetria: any TelemetryReporter
    /// Entrada, demonstração, saída e encerramento por 401 passam por aqui, um de cada vez.
    private let filaDeSessao = FilaDeSessao()

    public convenience init(url: URL, chavePublicavel: String, telemetria: any TelemetryReporter = TelemetryNula()) {
        self.init(url: url, chavePublicavel: chavePublicavel, telemetria: telemetria, sessaoHTTP: .shared)
    }

    /// A sessão HTTP e o armazenamento da sessão só mudam nos testes, que respondem às chamadas
    /// sem rede e guardam a sessão em memória, fora do Keychain.
    init(
        url: URL,
        chavePublicavel: String,
        telemetria: any TelemetryReporter,
        sessaoHTTP: URLSession,
        armazenamentoDaSessao: ArmazenamentoDeSessaoEmMemoria? = nil
    ) {
        // A sessão de autenticação fica no Keychain: é o armazenamento padrão do supabase-swift no iOS.
        let auth: SupabaseClientOptions.AuthOptions = if let armazenamentoDaSessao {
            .init(storage: armazenamentoDaSessao, autoRefreshToken: true, emitLocalSessionAsInitialSession: true)
        } else {
            .init(autoRefreshToken: true, emitLocalSessionAsInitialSession: true)
        }
        let options = SupabaseClientOptions(
            db: .init(decoder: ContratoAPI.decodificador()),
            auth: auth,
            global: .init(session: sessaoHTTP)
        )
        cliente = SupabaseClient(supabaseURL: url, supabaseKey: chavePublicavel, options: options)
        self.telemetria = telemetria
    }

    // MARK: Entrada

    public func solicitarCodigo(email: String) async throws {
        do {
            // O modelo de e-mail do contrato leva só o código de seis dígitos ({{ .Token }}), sem link.
            try await cliente.auth.signInWithOTP(email: email)
        } catch {
            throw mapear(error)
        }
    }

    public func verificarCodigo(email: String, codigo: String) async throws {
        do {
            try await filaDeSessao.executar { [cliente] in
                _ = try await cliente.auth.verifyOTP(email: email, token: codigo, type: .email)
            }
        } catch {
            throw mapear(error)
        }
    }

    public func possuiSessao() async -> Bool {
        // Lê a sessão guardada no Keychain e a renova se o token de acesso venceu.
        (try? await cliente.auth.session) != nil
    }

    public func entrarDemonstracao(email: String, codigo: String) async throws {
        do {
            try await filaDeSessao.executar { [self] in
                let sessaoUsada = cliente.auth.currentSession?.accessToken
                do {
                    let sessao: ContratoAPI.SessaoDTO = try await cliente.functions.invoke(
                        "entrar-demonstracao",
                        options: FunctionInvokeOptions(body: ContratoAPI.EntrarDemonstracao(email: email, codigo: codigo)),
                        decoder: decodificador
                    )
                    _ = try await cliente.auth.setSession(accessToken: sessao.accessToken, refreshToken: sessao.refreshToken)
                } catch {
                    // Já está dentro da fila: encerra aqui mesmo, sem entrar nela de novo.
                    if Self.comprovaSessaoInvalida(error) {
                        _ = await encerrarDentroDaFila(sessaoUsada: sessaoUsada)
                    }
                    throw error
                }
            }
        } catch {
            throw mapear(error)
        }
    }

    // MARK: Conta e perfil

    public func minhaConta() async throws -> Conta {
        let usuario: ContratoAPI.UsuarioDTO = try await rpc("minha_conta")
        return try converter { try usuario.dominio() }
    }

    public func criarConta(_ cadastro: CadastroConta) async throws -> Conta {
        let usuario: ContratoAPI.UsuarioDTO = try await rpc("criar_conta", params: ContratoAPI.CriarConta(cadastro))
        return try converter { try usuario.dominio() }
    }

    public func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional {
        let perfil: ContratoAPI.PerfilProfissionalDTO = try await rpc(
            "criar_perfil_profissional",
            params: ContratoAPI.DadosPerfilProfissionalDTO(dados)
        )
        return try converter { try perfil.dominio() }
    }

    public func meuPerfilProfissional() async throws -> PerfilProfissional {
        let perfil: ContratoAPI.PerfilProfissionalDTO = try await rpc("meu_perfil_profissional")
        return try converter { try perfil.dominio() }
    }

    public func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional {
        let perfil: ContratoAPI.PerfilProfissionalDTO = try await rpc(
            "atualizar_perfil_profissional",
            params: ContratoAPI.AlteracaoPerfilProfissionalDTO(alteracao)
        )
        return try converter { try perfil.dominio() }
    }

    // MARK: Estabelecimento

    public func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento {
        let resposta: ContratoAPI.EstabelecimentoDTO = try await rpc(
            "cadastrar_estabelecimento",
            params: ContratoAPI.CadastroEstabelecimentoDTO(cadastro)
        )
        return try converter { try resposta.dominio() }
    }

    public func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] {
        let resposta: [ContratoAPI.EstabelecimentoDaContaDTO] = try await rpc("meus_estabelecimentos")
        return resposta.map { $0.dominio() }
    }

    public func meuEstabelecimento(id: UUID) async throws -> Estabelecimento {
        let resposta: ContratoAPI.EstabelecimentoDTO = try await rpc(
            "meu_estabelecimento",
            params: ContratoAPI.EstabelecimentoParametros(estabelecimentoID: id)
        )
        return try converter { try resposta.dominio() }
    }

    public func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel {
        let params = ContratoAPI.PainelParametros(
            estabelecimentoID: id,
            de: ContratoAPI.texto(periodo.inicio),
            ate: ContratoAPI.texto(periodo.fim)
        )
        let resposta: ContratoAPI.PainelDTO = try await rpc("painel_estabelecimento", params: params)
        return try converter { try resposta.dominio() }
    }

    // MARK: Catálogo e vagas

    public func funcoes() async throws -> [Funcao] {
        // Leitura de tabela, fora do `rpc()`: o 401 precisa encerrar a sessão do mesmo jeito.
        let sessaoUsada = cliente.auth.currentSession?.accessToken
        do {
            let resposta: [ContratoAPI.FuncaoDTO] = try await cliente
                .from("funcao")
                .select("id,nome,categoria")
                .eq("ativo", value: true)
                .execute()
                .value
            return resposta.map { $0.dominio() }
        } catch {
            if Self.comprovaSessaoInvalida(error) {
                _ = await encerrarPorSessaoInvalida(sessaoUsada: sessaoUsada)
            }
            throw mapear(error)
        }
    }

    public func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada {
        let resposta: ContratoAPI.VagaPublicadaDTO = try await rpc("publicar_vaga", params: ContratoAPI.NovaVaga(publicacao))
        return resposta.dominio()
    }

    public func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        let params = ContratoAPI.RepublicarVaga(
            vagaID: id,
            inicioEm: ContratoAPI.texto(periodo.inicio),
            fimEm: ContratoAPI.texto(periodo.fim),
            chave: chave
        )
        let resposta: ContratoAPI.VagaPublicadaDTO = try await rpc("republicar_vaga", params: params)
        return resposta.dominio()
    }

    public func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] {
        let resposta: [ContratoAPI.VagaNaListaDTO] = try await rpc("vagas_abertas", params: ContratoAPI.FiltroVagasDTO(filtro))
        return try converter { try resposta.map { try $0.dominio() } }
    }

    public func detalheDaVaga(id: UUID) async throws -> Vaga {
        let resposta: ContratoAPI.VagaDTO = try await rpc("detalhe_vaga", params: ContratoAPI.ID("vaga_id", id))
        return try converter { try resposta.dominio() }
    }

    public func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura {
        let resposta: ContratoAPI.CandidaturaDTO = try await rpc("candidatar", params: ContratoAPI.ID("vaga_id", vagaID))
        return resposta.dominio()
    }

    public func perfilPublico(id: UUID) async throws -> PerfilPublico {
        let resposta: ContratoAPI.PerfilPublicoDTO = try await rpc("perfil_publico", params: ContratoAPI.ID("id", id))
        return resposta.dominio()
    }

    // MARK: Turno

    public func meusTurnos() async throws -> [Turno] {
        let resposta: [ContratoAPI.TurnoDTO] = try await rpc("meus_turnos")
        return try converter { try resposta.map { try $0.dominio() } }
    }

    public func contatoDoTurno(id: UUID) async throws -> Contato {
        let resposta: ContratoAPI.ContatoDTO = try await rpc("contato_do_turno", params: ContratoAPI.ID("turno_id", id))
        return resposta.dominio()
    }

    public func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho {
        let resposta: ContratoAPI.ResultadoACaminhoDTO = try await rpc("avisar_a_caminho", params: ContratoAPI.ID("turno_id", turnoID))
        return resposta.dominio()
    }

    public func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try await registrarPresenca("fazer_checkin", turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }

    public func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try await registrarPresenca("fazer_checkout", turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }

    public func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        let valor: ContratoAPI.AvaliacaoDTO = try await rpc("avaliar", params: ContratoAPI.Avaliar(turnoID: turnoID, resposta: resposta))
        return valor.dominio()
    }

    // MARK: Turno do contratante

    public func confirmarCheckinManual(turnoID: UUID) async throws -> ResultadoRegistro {
        let resposta: ContratoAPI.ResultadoRegistroDTO = try await rpc("confirmar_checkin_manual", params: ContratoAPI.ID("turno_id", turnoID))
        return resposta.dominio()
    }

    public func reabrirPorAtraso(posicaoID: UUID) async throws -> ResultadoCancelamento {
        let resposta: ContratoAPI.ResultadoCancelamentoDTO = try await rpc("reabrir_por_atraso", params: ContratoAPI.ID("posicao_id", posicaoID))
        return resposta.dominio()
    }

    // MARK: Cancelamento

    public func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento {
        let resposta: ContratoAPI.ResultadoCancelamentoDTO = try await rpc(
            "cancelar_posicao",
            params: ContratoAPI.CancelarPosicao(posicaoID: id, motivo: motivo)
        )
        return resposta.dominio()
    }

    public func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada {
        let resposta: ContratoAPI.VagaCanceladaDTO = try await rpc("cancelar_vaga", params: ContratoAPI.CancelarVaga(vagaID: id, motivo: motivo))
        return resposta.dominio()
    }

    // MARK: Confiança e direitos

    public func denunciar(_ denuncia: Denuncia) async throws -> Protocolo {
        let resposta: ContratoAPI.ProtocoloDTO = try await rpc("denunciar", params: ContratoAPI.Denunciar(denuncia))
        return try converter { try resposta.dominio() }
    }

    public func bloquear(_ alvo: Alvo) async throws -> Bloqueio {
        let resposta: ContratoAPI.BloqueioDTO = try await rpc("bloquear", params: ContratoAPI.Bloquear(alvo))
        return resposta.dominio()
    }

    public func situacaoDaConta() async throws -> SituacaoDaConta {
        let resposta: ContratoAPI.SituacaoDaContaDTO = try await rpc("situacao_da_conta")
        return try converter { try resposta.dominio() }
    }

    public func contestarSuspensao(relato: String) async throws -> Protocolo {
        let resposta: ContratoAPI.ProtocoloDTO = try await rpc("contestar_suspensao", params: ContratoAPI.ContestarSuspensao(relato: relato))
        return try converter { try resposta.dominio() }
    }

    // MARK: Aplicativo e dispositivo

    public func configuracaoDoApp() async throws -> ConfiguracaoApp {
        struct Params: Encodable { let plataforma = "ios" }
        let resposta: ContratoAPI.ConfiguracaoDoAppDTO = try await rpc("configuracao_do_app", params: Params())
        return resposta.dominio()
    }

    public func registrarDispositivo(tokenFCM: String) async throws -> Dispositivo {
        let resposta: ContratoAPI.DispositivoDTO = try await rpc(
            "registrar_dispositivo",
            params: ContratoAPI.RegistrarDispositivo(tokenFCM: tokenFCM)
        )
        return resposta.dominio()
    }

    public func removerDispositivo(tokenFCM: String) async throws {
        let _: ContratoAPI.RemocaoDTO = try await rpc("remover_dispositivo", params: ContratoAPI.RemoverDispositivo(tokenFCM: tokenFCM))
    }

    public func sair(tokenFCM: String?) async {
        if let tokenFCM { try? await removerDispositivo(tokenFCM: tokenFCM) }
        try? await filaDeSessao.executar { [cliente] in
            try? await cliente.auth.signOut()
        }
    }

    // MARK: Encerramento por sessão inválida (contrato 0.2.18, RF25)

    /// O que aconteceu com a sessão depois de um erro que comprova que ela não vale mais.
    enum ResultadoDoEncerramento: Equatable, Sendable {
        /// Não havia sessão quando a chamada saiu: nada a encerrar.
        case semSessaoNaChamada
        /// A sessão já não estava guardada quando o erro chegou (outro encerramento veio antes).
        case jaEncerrada
        /// Uma entrada nova trocou a sessão enquanto a chamada estava em voo: a nova fica.
        case sessaoTrocada
        /// Depois do `signOut` local, o SDK não devolve mais sessão ao ler o armazenamento.
        /// Não prova remoção persistente: o SDK devolve nil também quando a leitura falha.
        case semSessaoAposEncerrar
        /// O SDK continua devolvendo a sessão: a remoção falhou (o armazenamento engole o erro).
        case sessaoContinuaGuardada
    }

    /// Só o código original prova que a sessão não vale mais: `nao_autenticado` do backend ou
    /// `PGRST301` do PostgREST numa RPC, ou o status 401 de uma Edge Function (o gateway recusa o
    /// JWT; `entrar-demonstracao` nunca responde 401 por conta própria). O `42501` também vira
    /// `.naoAutenticado` para a tela, mas sozinho não encerra: com sessão válida ele é falta de
    /// privilégio (403), e derrubar a sessão aí seria errado.
    static func comprovaSessaoInvalida(_ error: Error) -> Bool {
        if let postgrest = error as? PostgrestError {
            return postgrest.code == "nao_autenticado" || postgrest.code == "PGRST301"
        }
        if case let FunctionsError.httpError(status, _) = error {
            return status == 401
        }
        return false
    }

    func encerrarPorSessaoInvalida(sessaoUsada: String?) async -> ResultadoDoEncerramento {
        (try? await filaDeSessao.executar { [self] in await encerrarDentroDaFila(sessaoUsada: sessaoUsada) })
            ?? .sessaoContinuaGuardada
    }

    /// Chamada só de dentro da fila, que garante que nenhuma entrada termine entre a comparação e o
    /// `signOut`. Uma renovação automática do SDK não passa pela fila (limite conhecido, ver README).
    private func encerrarDentroDaFila(sessaoUsada: String?) async -> ResultadoDoEncerramento {
        guard let sessaoUsada else { return .semSessaoNaChamada }
        guard let atual = cliente.auth.currentSession?.accessToken else { return .jaEncerrada }
        guard atual == sessaoUsada else { return .sessaoTrocada }
        do {
            // No supabase-swift 2.55.2 o escopo local também chama `POST /logout`, depois de remover a
            // sessão e emitir `.signedOut`. Falha nessa chamada não desfaz a remoção; o estado real é
            // conferido abaixo em vez de presumido.
            try await cliente.auth.signOut(scope: .local)
        } catch {}
        return cliente.auth.currentSession == nil ? .semSessaoAposEncerrar : .sessaoContinuaGuardada
    }

    /// Só para os testes: lê o armazenamento sem rede e sem renovar.
    var haSessaoGuardada: Bool { cliente.auth.currentSession != nil }

    /// Repassa só o `.signedOut` do SDK. O evento não prova que o armazenamento apagou a sessão.
    public func encerramentos() -> AsyncStream<Void> { encerramentos(aoFicarPronto: nil) }

    /// O SDK registra o ouvinte dentro de uma `Task` e emite `.initialSession` assim que ele está
    /// registrado; esse primeiro evento é o sinal de pronto que os testes esperam, em vez de `sleep`.
    func encerramentos(aoFicarPronto: (@Sendable () -> Void)?) -> AsyncStream<Void> {
        let eventos = cliente.auth.authStateChanges
        return AsyncStream { continuacao in
            let tarefa = Task {
                for await (evento, _) in eventos {
                    switch evento {
                    case .initialSession: aoFicarPronto?()
                    case .signedOut: continuacao.yield()
                    default: break
                    }
                }
                continuacao.finish()
            }
            continuacao.onTermination = { _ in tarefa.cancel() }
        }
    }

    // MARK: Chamada

    private func registrarPresenca(_ nome: String, turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        let params = ContratoAPI.RegistroDePresenca(
            turnoID: turnoID,
            distanciaMetros: distanciaMetros,
            registradoEm: ContratoAPI.texto(registradoEm)
        )
        let resposta: ContratoAPI.ResultadoRegistroDTO = try await rpc(nome, params: params)
        return resposta.dominio()
    }

    // As leituras que o contrato descreve em GET vão por POST: o PostgREST aceita os dois para
    // qualquer função, e o POST não esbarra na transação somente-leitura do GET.
    private func rpc<Resposta: Decodable>(_ nome: String, params: some Encodable = SemParametros()) async throws -> Resposta {
        let relogio = ContinuousClock()
        let inicio = relogio.now
        // A sessão com que a chamada sai, só em memória e nunca registrada. Serve para um 401 que
        // chegue depois de uma entrada nova não derrubar a sessão nova.
        let sessaoUsada = cliente.auth.currentSession?.accessToken
        do {
            return try await cliente.rpc(nome, params: params).execute().value
        } catch {
            if Self.comprovaSessaoInvalida(error) {
                _ = await encerrarPorSessaoInvalida(sessaoUsada: sessaoUsada)
            }
            let tipado = mapear(error)
            await telemetria.registrarErroDaApi(codigo: tipado.codigoOriginal, rpc: nome, duracao: inicio.duration(to: relogio.now))
            throw tipado
        }
    }

    private func converter<Valor>(_ conversao: () throws -> Valor) throws -> Valor {
        do {
            return try conversao()
        } catch let erro as ErroDeConversao {
            throw ErroDaApi(codigo: .respostaInvalida, detalhes: erro.campo)
        } catch {
            throw ErroDaApi(codigo: .respostaInvalida)
        }
    }

    private func mapear(_ error: Error) -> ErroDaApi {
        if let erro = error as? ErroDaApi { return erro }
        if let auth = error as? AuthError { return Self.mapear(auth) }
        if let postgrest = error as? PostgrestError {
            return DecodificadorErroAPI.mapear(codigo: postgrest.code, detalhes: postgrest.details)
        }
        if case let FunctionsError.httpError(codigo, dados) = error {
            return DecodificadorErroAPI.mapear(statusCode: codigo, dados: dados)
        }
        if error is DecodingError {
            return ErroDaApi(codigo: .respostaInvalida)
        }
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return ErroDaApi(codigo: .semRede)
        }
        return ErroDaApi(codigo: .desconhecido, codigoOriginal: String(reflecting: type(of: error)))
    }

    /// `/otp` e `/verify` falham como `AuthError`, e não como `PostgrestError`. O contrato promete
    /// `429 limite_excedido` no envio e `401 nao_autenticado` na confirmação; o GoTrue responde o
    /// código errado ou vencido com 403 `otp_expired`, que vale o mesmo para a tela. O status HTTP
    /// decide antes do `error_code`, que muda de campo conforme a versão da API do Auth.
    static func mapear(_ auth: AuthError) -> ErroDaApi {
        switch auth {
        case let .api(_, codigoDoAuth, _, resposta):
            let original = codigoDoAuth.rawValue
            switch resposta.statusCode {
            case 429:
                return ErroDaApi(codigo: .limiteExcedido, codigoOriginal: original)
            case 401, 403:
                return ErroDaApi(codigo: .naoAutenticado, codigoOriginal: original)
            case 400 where codigoDoAuth == .validationFailed || original == "email_address_invalid",
                 422 where codigoDoAuth == .validationFailed || original == "email_address_invalid":
                // E-mail que o Auth recusa: a tela aponta o campo, como no 422 das RPCs. O `where`
                // vale só para o padrão em que está escrito, por isso aparece nos dois.
                return ErroDaApi(codigo: .campoInvalido, codigoOriginal: original, detalhes: "email")
            default:
                if codigoDoAuth == .overEmailSendRateLimit || codigoDoAuth == .overRequestRateLimit {
                    return ErroDaApi(codigo: .limiteExcedido, codigoOriginal: original)
                }
                if codigoDoAuth == .otpExpired {
                    return ErroDaApi(codigo: .naoAutenticado, codigoOriginal: original)
                }
                return ErroDaApi(codigo: .desconhecido, codigoOriginal: original)
            }
        case .sessionMissing:
            return ErroDaApi(codigo: .naoAutenticado, codigoOriginal: auth.errorCode.rawValue)
        default:
            return ErroDaApi(codigo: .desconhecido, codigoOriginal: auth.errorCode.rawValue)
        }
    }
}

private struct SemParametros: Encodable {}

/// Fila FIFO para as mutações de sessão iniciadas pelo app. Um `actor` sozinho não serializa: ele
/// é reentrante em cada `await`. Aqui cada operação espera a anterior terminar, e a troca de
/// `ultima` acontece sem `await` no meio, então duas chamadas nunca se intercalam.
///
/// Invariante: uma operação que já está na fila nunca chama `executar` de novo, nem `rpc()` ou
/// `encerrarPorSessaoInvalida`, que entram na fila. Ela esperaria a si mesma para sempre. De dentro
/// da fila, o encerramento é `encerrarDentroDaFila`.
actor FilaDeSessao {
    private var ultima: Task<Void, Never>?

    func executar<Valor: Sendable>(_ operacao: @escaping @Sendable () async throws -> Valor) async throws -> Valor {
        let anterior = ultima
        let tarefa = Task { () async throws -> Valor in
            await anterior?.value
            return try await operacao()
        }
        ultima = Task { _ = try? await tarefa.value }
        return try await tarefa.value
    }
}

/// Armazenamento da sessão em memória, só para os testes (que não podem importar o Supabase nem
/// tocar o Keychain). `falharAoRemover` simula o Keychain recusando a remoção.
final class ArmazenamentoDeSessaoEmMemoria: AuthLocalStorage, @unchecked Sendable {
    private let trava = NSLock()
    private var valores: [String: Data] = [:]
    private let falharAoRemover: Bool

    init(falharAoRemover: Bool = false) {
        self.falharAoRemover = falharAoRemover
    }

    func store(key: String, value: Data) throws {
        trava.withLock { valores[key] = value }
    }

    func retrieve(key: String) throws -> Data? {
        trava.withLock { valores[key] }
    }

    func remove(key: String) throws {
        struct RemocaoRecusada: Error {}
        if falharAoRemover { throw RemocaoRecusada() }
        trava.withLock { valores[key] = nil }
    }
}

// MARK: - Exclusão de Conta (Porta ExclusaoDeContaPorta)

extension SupabaseApiCliente: ExclusaoDeContaPorta {
    public func excluirConta() async throws -> ExclusaoDeConta {
        let relogio = ContinuousClock()
        let inicio = relogio.now
        let sessaoUsada = cliente.auth.currentSession?.accessToken
        do {
            let resposta: DTOExclusaoDeConta = try await cliente.functions.invoke(
                "excluir-conta",
                options: FunctionInvokeOptions(body: RequisicaoExclusaoConta()),
                decoder: decodificador
            )
            return try converter { try resposta.dominio() }
        } catch {
            if Self.comprovaSessaoInvalida(error) {
                _ = await encerrarPorSessaoInvalida(sessaoUsada: sessaoUsada)
            }
            let tipado = mapear(error)
            await telemetria.registrarErroDaApi(codigo: tipado.codigoOriginal, rpc: "excluir-conta", duracao: inicio.duration(to: relogio.now))
            throw tipado
        }
    }
}

