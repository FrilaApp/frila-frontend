import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// Espia o `versao_app` que o aparelho manda ao registrar o token (I5d).
private final class ApiQueGuardaVersao: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var _versoes: [String?] = []
    var versoes: [String?] { trava.withLock { _versoes } }
    override func registrarDispositivo(tokenFCM: String, versaoApp: String?) async throws -> Dispositivo {
        trava.withLock { _versoes.append(versaoApp) }
        return try await base.registrarDispositivo(tokenFCM: tokenFCM, versaoApp: versaoApp)
    }
}

/// Os achados da varredura final da 1.1 (`orquestracao/retornos/varredura-final-1-1.md`): A1, a
/// denúncia da foto com `midia_id` (0.2.54, CD-M07, CD-RF12), e A6, os testes que faltavam (RN29,
/// "Chamar de novo" e o registro de `versao_app`).
@Suite("Varredura final da 1.1: denúncia da foto, RN29, Chamar de novo e versao_app")
@MainActor
struct VarreduraFinal11Tests {
    /// Os perfis de `candidatos.json` (as candidaturas são as `70000000-…`).
    private let bruno = UUID(uuidString: "80000000-0000-0000-0000-000000000002")!
    private let carla = UUID(uuidString: "80000000-0000-0000-0000-000000000003")!
    private let profissionalID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!
    private let vagaDaCasa = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!

    // MARK: A1: denúncia da foto

    @Test("A denúncia da foto manda midia_id; a do perfil não manda o campo")
    func corpoDaDenuncia() throws {
        let alvo = Alvo(tipo: .profissional, id: bruno)
        let foto = ApiClienteEmMemoria.fotoDoCandidatoID
        let daFoto = Denuncia(alvo: alvo, motivo: .outro, relato: "A foto mostra uma chave Pix.", chave: UUID(), midiaID: foto)
        let corpo = try ContratoTests.objeto(ContratoAPI.Denunciar(daFoto))
        #expect((corpo["midia_id"] as? String)?.lowercased() == foto.uuidString.lowercased())

        let doPerfil = Denuncia(alvo: alvo, motivo: .outro, relato: "A foto mostra uma chave Pix.", chave: UUID())
        #expect(try ContratoTests.objeto(ContratoAPI.Denunciar(doPerfil))["midia_id"] == nil)
    }

    @Test("Com a foto no perfil, marcar 'sobre a foto' manda o foto_id que a tela mostrou")
    func denunciaAFotoDoPerfil() async throws {
        let api = ApiClienteEmMemoria(cenario: .denunciaDeFoto)
        #expect(try await api.configuracaoDoApp().recursos.fotoDePerfil, "o foto_id só vem com o recurso ligado (0.2.54)")
        let perfil = try await api.perfilPublico(id: bruno)
        #expect(perfil.fotoID == ApiClienteEmMemoria.fotoDoCandidatoID)

        let model = SegurancaViewModel(perfil: perfil, api: api, bloqueios: BloqueiosDaSessao())
        #expect(model.podeDenunciarFoto)
        model.relato = "A foto mostra uma chave Pix."
        model.sobreAFoto = true
        await model.denunciar()

        #expect(model.protocolo != nil)
        let recebida = try #require(await api.denunciasRecebidas.last)
        #expect(recebida.midiaID == ApiClienteEmMemoria.fotoDoCandidatoID)
        #expect(recebida.alvo == Alvo(perfil))
    }

    @Test("Sem marcar a foto, a denúncia continua sobre o perfil, sem midia_id")
    func semMarcarNaoMandaAFoto() async throws {
        let api = ApiClienteEmMemoria(cenario: .denunciaDeFoto)
        let model = SegurancaViewModel(perfil: try await api.perfilPublico(id: bruno), api: api, bloqueios: BloqueiosDaSessao())
        model.relato = "Comportamento agressivo no turno."
        await model.denunciar()

        #expect(model.protocolo != nil)
        #expect(try #require(await api.denunciasRecebidas.last).midiaID == nil)
    }

    @Test("Sem foto no perfil não há foto para denunciar, nem marcando")
    func perfilSemFoto() async throws {
        let api = ApiClienteEmMemoria(cenario: .denunciaDeFoto)
        let perfil = try await api.perfilPublico(id: carla)
        #expect(perfil.fotoID == nil)

        let model = SegurancaViewModel(perfil: perfil, api: api, bloqueios: BloqueiosDaSessao())
        #expect(!model.podeDenunciarFoto)
        model.relato = "Comportamento agressivo no turno."
        model.sobreAFoto = true
        await model.denunciar()
        #expect(try #require(await api.denunciasRecebidas.last).midiaID == nil)
    }

    @Test("Marcar a foto depois de uma tentativa sem ela começa outra denúncia, com outra chave")
    func marcarAFotoTrocaAChave() async throws {
        let api = ApiQueFalhaUmaVez(base: ApiClienteEmMemoria(cenario: .denunciaDeFoto))
        let model = SegurancaViewModel(perfil: try await api.perfilPublico(id: bruno), api: api, bloqueios: BloqueiosDaSessao())
        model.relato = "A foto mostra uma chave Pix."
        await model.denunciar()
        #expect(model.protocolo == nil, "a primeira resposta se perdeu")

        model.sobreAFoto = true
        await model.denunciar()
        let enviadas = api.enviadas
        #expect(enviadas.count == 2)
        #expect(enviadas[0].midiaID == nil)
        #expect(enviadas[1].midiaID == ApiClienteEmMemoria.fotoDoCandidatoID)
        #expect(enviadas[0].chave != enviadas[1].chave, "corpo diferente nunca reusa a chave")
    }

    @Test("O dublê recusa midia_id que não é a foto do alvo: 422 campo_invalido com midia_id")
    func midiaDeOutroPerfil() async throws {
        let api = ApiClienteEmMemoria(cenario: .denunciaDeFoto)
        let denuncia = Denuncia(alvo: Alvo(tipo: .profissional, id: carla), motivo: .outro,
                                relato: "A foto mostra uma chave Pix.", chave: UUID(), midiaID: ApiClienteEmMemoria.fotoDoCandidatoID)
        do {
            _ = try await api.denunciar(denuncia)
            Issue.record("a foto de outra pessoa devia ser recusada")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .campoInvalido)
            #expect(erro.detalhes == "midia_id")
        }
        #expect(await api.denunciasRecebidas.isEmpty)
    }

    // MARK: A6: RN29

    private func formulario(_ api: ApiClienteEmMemoria, vagaID: UUID? = nil) async throws -> ChamadaDiretaViewModel {
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let model = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID, estabelecimentoID: casa.id, vagaID: vagaID)
        await model.carregar()
        return model
    }

    @Test("RN29: valor zero ou negativo não deixa enviar a chamada, e nada vai ao servidor", arguments: [0, -1, -18_000])
    func valorNaoPositivo(valor: Int) async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let model = try await formulario(api)
        let perfil = try await api.perfilPublico(id: profissionalID)
        model.funcaoID = try #require(model.funcoes.first { perfil.funcoes.contains($0.nome) }).id
        model.responsavel = "Gerente João"
        model.valorCentavos = valor
        model.totalConfirmado = true

        #expect(!model.podeEnviar)
        await model.enviar()
        #expect(model.resultado == nil)
        #expect(await api.pedidosChamadaRecebidos.isEmpty)

        model.valorCentavos = 18_000
        model.totalConfirmado = true
        #expect(model.podeEnviar, "com valor positivo e o total confirmado, o mesmo formulário envia")
    }

    @Test("RN29: o dublê recusa a chamada de valor zero com 422 campo_invalido, como o backend")
    func dubleRecusaValorZero() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let model = try await formulario(api)
        let perfil = try await api.perfilPublico(id: profissionalID)
        model.funcaoID = try #require(model.funcoes.first { perfil.funcoes.contains($0.nome) }).id
        model.responsavel = "Gerente João"
        model.valorCentavos = 18_000
        model.totalConfirmado = true
        await model.enviar()
        let valido = try #require(await api.pedidosChamadaRecebidos.last)

        let t = valido.trabalho
        let zerado = PedidoChamada(profissionalID: valido.profissionalID, trabalho: PublicacaoVaga(
            estabelecimentoID: t.estabelecimentoID, funcaoID: t.funcaoID, periodo: t.periodo, local: t.local,
            regiaoAdministrativa: t.regiaoAdministrativa, ponto: t.ponto, valor: Dinheiro(centavos: 0), posicoes: 1,
            inclusos: t.inclusos, responsavelLocal: t.responsavelLocal, modo: .urgencia, chave: UUID()))
        do {
            _ = try await api.chamarProfissional(zerado)
            Issue.record("valor zero devia ser recusado")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .campoInvalido)
        }
    }

    // MARK: A6: Chamar de novo (CD-RF07)

    @Test("Chamar de novo a partir de um turno traz a função, o valor e o responsável da vaga, e pede confirmar o total de novo")
    func chamarDeNovoPreencheComAVaga() async throws {
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let vaga = try await api.detalheDaVaga(id: vagaDaCasa)
        let model = try await formulario(api, vagaID: vaga.id)

        #expect(model.recursoHabilitado)
        #expect(model.funcaoID == vaga.funcao.id)
        #expect(model.valorCentavos == vaga.valor.centavos)
        #expect(model.local == vaga.local)
        #expect(model.responsavel == (vaga.responsavelLocal ?? model.responsavel))
        #expect(!model.totalConfirmado, "o total é confirmado a cada chamada")
        #expect(!model.podeEnviar)

        model.totalConfirmado = true
        await model.enviar()
        #expect(model.resultado != nil)
        let pedido = try #require(await api.pedidosChamadaRecebidos.last)
        #expect(pedido.profissionalID == profissionalID)
        #expect(pedido.trabalho.valor == vaga.valor)
        #expect(pedido.trabalho.funcaoID == vaga.funcao.id)
    }

    // MARK: A6: versao_app (I5d)

    @Test("O registro do token manda versao_app com a versão do app, e o corpo segue o contrato")
    func registroMandaVersaoDoApp() async throws {
        let api = ApiQueGuardaVersao()
        let aparelho = AparelhoDePush(api: api, armazenamento: ArmazenamentoDoAparelhoEmMemoria(),
                                      vinculoCompartilhado: ArmazenamentoDoVinculoCompartilhadoEmMemoria(),
                                      relogio: RelogioFixo(agora: Date(timeIntervalSince1970: 1_790_000_000)))
        let contaID = try await api.minhaConta().id
        _ = await aparelho.receber(token: "token-fcm-de-exemplo-0001")
        _ = await aparelho.registrar(para: contaID)

        let versaoDoApp = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(api.versoes.last == .some(versaoDoApp))

        let corpo = try ContratoTests.objeto(ContratoAPI.RegistrarDispositivo(tokenFCM: "token-fcm-de-exemplo-0001", versaoApp: "1.1.0"))
        #expect(corpo["versao_app"] as? String == "1.1.0")
        #expect(corpo["plataforma"] as? String == "ios")
        let semVersao = try ContratoTests.objeto(ContratoAPI.RegistrarDispositivo(tokenFCM: "token-fcm-de-exemplo-0001"))
        #expect(semVersao["versao_app"] == nil)
    }
}

/// Perde a primeira resposta de `denunciar`, como uma queda de rede depois do envio.
private final class ApiQueFalhaUmaVez: ApiClienteEncaminhador, @unchecked Sendable {
    private let trava = NSLock()
    private var _enviadas: [Denuncia] = []
    var enviadas: [Denuncia] { trava.withLock { _enviadas } }
    override func denunciar(_ denuncia: Denuncia) async throws -> Protocolo {
        let numero = trava.withLock { _enviadas.append(denuncia); return _enviadas.count }
        if numero == 1 { throw ErroDaApi(codigo: .semRede) }
        return try await base.denunciar(denuncia)
    }
}
