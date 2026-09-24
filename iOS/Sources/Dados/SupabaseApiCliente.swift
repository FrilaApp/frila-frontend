import Foundation
import FrilaDominio
import Supabase

public final class SupabaseApiCliente: ApiCliente, @unchecked Sendable {
    private let cliente: SupabaseClient
    private let telemetria: any TelemetryReporter
    private let codificadorISO = ISO8601DateFormatter()

    public init(url: URL, chavePublicavel: String, telemetria: any TelemetryReporter = TelemetryNula()) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let options = SupabaseClientOptions(
            db: .init(decoder: decoder),
            auth: .init(autoRefreshToken: true, emitLocalSessionAsInitialSession: true)
        )
        cliente = SupabaseClient(supabaseURL: url, supabaseKey: chavePublicavel, options: options)
        self.telemetria = telemetria
    }

    public func solicitarCodigo(email: String) async throws {
        do {
            try await cliente.auth.signInWithOTP(email: email)
        } catch {
            throw mapear(error)
        }
    }

    public func verificarCodigo(email: String, codigo: String) async throws -> SessaoUsuario {
        do {
            let resposta = try await cliente.auth.verifyOTP(email: email, token: codigo, type: .email)
            guard let valor = resposta.user.userMetadata["perfil"]?.stringValue,
                  let perfil = PerfilConta(rawValue: valor) else {
                throw ErroDaApi(codigo: .campoObrigatorio, detalhes: "perfil")
            }
            return SessaoUsuario(usuarioID: resposta.user.id, perfil: perfil)
        } catch let erro as ErroDaApi {
            throw erro
        } catch {
            throw mapear(error)
        }
    }

    public func criarConta(_ cadastro: CadastroConta) async throws -> SessaoUsuario {
        let nascimento = cadastro.nascimento.formatted(.iso8601.year().month().day())
        let params = ContratoAPI.CriarConta(
            perfil: cadastro.perfil.rawValue,
            nome: cadastro.nome,
            telefone: cadastro.telefone,
            nascimento: nascimento,
            versaoTermos: cadastro.versaoTermos,
            aceitouEm: codificadorISO.string(from: cadastro.aceitouEm)
        )
        let usuario: ContratoAPI.Usuario = try await rpc("criar_conta", params: params)
        return SessaoUsuario(usuarioID: usuario.id, perfil: usuario.perfil)
    }

    public func funcoes() async throws -> [Funcao] {
        do {
            let resposta: [ContratoAPI.FuncaoDTO] = try await cliente.from("funcao").select().execute().value
            return resposta.map { $0.dominio() }
        } catch { throw mapear(error) }
    }

    public func cadastrarEstabelecimento(_ estabelecimento: Estabelecimento) async throws -> Estabelecimento {
        struct Params: Encodable {
            let nome: String; let documento: String; let tipo: TipoEstabelecimento; let endereco: String; let ponto: ContratoAPI.CoordenadaDTO
        }
        let resposta: ContratoAPI.EstabelecimentoDTO = try await rpc(
            "cadastrar_estabelecimento",
            params: Params(nome: estabelecimento.nome, documento: estabelecimento.documento, tipo: estabelecimento.tipo, endereco: estabelecimento.endereco, ponto: .init(estabelecimento.ponto))
        )
        return try resposta.dominio()
    }

    public func meusEstabelecimentos() async throws -> [Estabelecimento] {
        let resposta: [ContratoAPI.EstabelecimentoDTO] = try await rpc("meus_estabelecimentos", params: SemParametros())
        return try resposta.map { try $0.dominio() }
    }

    public func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada {
        let params = ContratoAPI.PublicarVaga(
            estabelecimentoID: publicacao.estabelecimentoID,
            funcaoID: publicacao.funcaoID,
            inicioEm: codificadorISO.string(from: publicacao.periodo.inicio),
            fimEm: codificadorISO.string(from: publicacao.periodo.fim),
            local: publicacao.local,
            ponto: .init(publicacao.ponto),
            valorCentavos: publicacao.valor.centavos,
            posicoes: publicacao.posicoes,
            incluiRefeicao: publicacao.inclusos.refeicao,
            incluiTransporte: publicacao.inclusos.transporte,
            exigeMaterialProprio: publicacao.inclusos.exigeMaterialProprio,
            responsavelLocal: publicacao.responsavelLocal,
            modo: publicacao.modo,
            chave: publicacao.chave
        )
        let resposta: ContratoAPI.VagaPublicadaDTO = try await rpc("publicar_vaga", params: params)
        return resposta.dominio()
    }

    public func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        let params = ContratoAPI.RepublicarVaga(
            vagaID: id,
            inicioEm: codificadorISO.string(from: periodo.inicio),
            fimEm: codificadorISO.string(from: periodo.fim),
            chave: chave
        )
        let resposta: ContratoAPI.VagaPublicadaDTO = try await rpc("republicar_vaga", params: params)
        return resposta.dominio()
    }

    public func vagasAbertas() async throws -> [Vaga] {
        let resposta: [ContratoAPI.VagaDTO] = try await rpc("vagas_abertas", params: SemParametros())
        return try resposta.map { try $0.dominio() }
    }

    public func detalheDaVaga(id: UUID) async throws -> Vaga {
        let resposta: ContratoAPI.VagaDTO = try await rpc("detalhe_vaga", params: ContratoAPI.ID("vaga_id", id))
        return try resposta.dominio()
    }

    public func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura {
        let resposta: ContratoAPI.CandidaturaDTO = try await rpc("candidatar", params: ContratoAPI.ID("vaga_id", vagaID))
        return resposta.dominio()
    }

    public func meusTurnos() async throws -> [Turno] {
        // O DTO final depende da adição `contato_visivel_ate` do contrato 0.2.1.
        throw ErroDaApi(codigo: .respostaInvalida, detalhes: "contrato_0.2.1_pendente")
    }

    public func contatoDoTurno(id: UUID) async throws -> Contato {
        let resposta: ContratoAPI.ContatoDTO = try await rpc("contato_do_turno", params: ContratoAPI.ID("turno_id", id))
        return resposta.dominio()
    }

    public func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, chave: UUID) async throws {
        let params = ContratoAPI.RegistroPresenca(
            turnoID: turnoID,
            distanciaMetros: distanciaMetros,
            registradoEm: codificadorISO.string(from: registradoEm),
            chave: chave
        )
        let _: RespostaVazia = try await rpc("fazer_checkin", params: params)
    }

    public func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, chave: UUID) async throws {
        let params = ContratoAPI.RegistroPresenca(
            turnoID: turnoID,
            distanciaMetros: distanciaMetros,
            registradoEm: codificadorISO.string(from: registradoEm),
            chave: chave
        )
        let _: RespostaVazia = try await rpc("fazer_checkout", params: params)
    }

    public func avaliar(turnoID: UUID, resposta: Bool, chave: UUID) async throws -> Avaliacao {
        let valor: ContratoAPI.AvaliacaoDTO = try await rpc(
            "avaliar",
            params: ContratoAPI.Avaliar(turnoID: turnoID, resposta: resposta, chave: chave)
        )
        return valor.dominio()
    }

    public func configuracaoDoApp() async throws -> ConfiguracaoApp {
        let resposta: ContratoAPI.ConfiguracaoDTO = try await rpc("configuracao_do_app", params: SemParametros())
        return resposta.dominio()
    }

    public func removerDispositivo(tokenFCM: String) async throws {
        struct Params: Encodable { let token_fcm: String }
        let _: RespostaVazia = try await rpc("remover_dispositivo", params: Params(token_fcm: tokenFCM))
    }

    public func sair(tokenFCM: String?) async {
        if let tokenFCM { try? await removerDispositivo(tokenFCM: tokenFCM) }
        try? await cliente.auth.signOut()
    }

    private func rpc<Resposta: Decodable, Parametros: Encodable>(
        _ nome: String,
        params: Parametros
    ) async throws -> Resposta {
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

    private func mapear(_ error: Error) -> ErroDaApi {
        if let postgrest = error as? PostgrestError {
            return DecodificadorErroAPI.mapear(codigo: postgrest.code, detalhes: postgrest.details)
        }
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return ErroDaApi(codigo: .semRede)
        }
        return ErroDaApi(codigo: .desconhecido, codigoOriginal: String(reflecting: type(of: error)))
    }
}

private struct SemParametros: Encodable {}
private struct RespostaVazia: Decodable {}
