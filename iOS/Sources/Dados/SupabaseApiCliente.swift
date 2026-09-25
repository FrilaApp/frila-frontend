import Foundation
import FrilaDominio
import Supabase

public final class SupabaseApiCliente: ApiCliente, @unchecked Sendable {
    private let cliente: SupabaseClient
    private let decodificador = ContratoAPI.decodificador()
    private let telemetria: any TelemetryReporter

    public init(url: URL, chavePublicavel: String, telemetria: any TelemetryReporter = TelemetryNula()) {
        let options = SupabaseClientOptions(
            db: .init(decoder: ContratoAPI.decodificador()),
            auth: .init(autoRefreshToken: true, emitLocalSessionAsInitialSession: true)
        )
        cliente = SupabaseClient(supabaseURL: url, supabaseKey: chavePublicavel, options: options)
        self.telemetria = telemetria
    }

    // MARK: Entrada

    public func solicitarCodigo(email: String) async throws {
        do {
            try await cliente.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "com.frila.org.app://login-callback")
            )
        } catch {
            throw mapear(error)
        }
    }

    public func verificarCodigo(email: String, codigo: String) async throws {
        do {
            _ = try await cliente.auth.verifyOTP(email: email, token: codigo, type: .email)
        } catch {
            throw mapear(error)
        }
    }

    /// Conclui no aparelho os links de autenticação enviados pelo Supabase. O mesmo cliente
    /// continua aceitando códigos de seis dígitos quando o template do projeto os utiliza.
    public func processarRetornoDeAutenticacao(url: URL) async throws {
        do {
            _ = try await cliente.auth.session(from: url)
        } catch {
            throw mapear(error)
        }
    }

    public func entrarDemonstracao(email: String, codigo: String) async throws {
        do {
            let sessao: ContratoAPI.SessaoDTO = try await cliente.functions.invoke(
                "entrar-demonstracao",
                options: FunctionInvokeOptions(body: ContratoAPI.EntrarDemonstracao(email: email, codigo: codigo)),
                decoder: decodificador
            )
            _ = try await cliente.auth.setSession(accessToken: sessao.accessToken, refreshToken: sessao.refreshToken)
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
        do {
            let resposta: [ContratoAPI.FuncaoDTO] = try await cliente
                .from("funcao")
                .select("id,nome,categoria")
                .eq("ativo", value: true)
                .execute()
                .value
            return resposta.map { $0.dominio() }
        } catch {
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

    // MARK: Aplicativo e dispositivo

    public func configuracaoDoApp() async throws -> ConfiguracaoApp {
        struct Params: Encodable { let plataforma = "ios" }
        let resposta: ContratoAPI.ConfiguracaoDoAppDTO = try await rpc("configuracao_do_app", params: Params())
        return resposta.dominio()
    }

    public func removerDispositivo(tokenFCM: String) async throws {
        struct Params: Encodable { let token_fcm: String }
        let _: ContratoAPI.RemocaoDTO = try await rpc("remover_dispositivo", params: Params(token_fcm: tokenFCM))
    }

    public func sair(tokenFCM: String?) async {
        if let tokenFCM { try? await removerDispositivo(tokenFCM: tokenFCM) }
        try? await cliente.auth.signOut()
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
        do {
            return try await cliente.rpc(nome, params: params).execute().value
        } catch {
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
}

private struct SemParametros: Encodable {}
