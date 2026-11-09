import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private final class RelogioDoCodigo: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { _agora = _agora.addingTimeInterval(segundos) } }
}

/// O dublê simula uma conta só. O check-in por código tem duas pontas, a casa que gera e o profissional que
/// valida, e os testes trocam a conta do mesmo estado do servidor, como `definirContaParaTeste` faz nos outros.
private extension ApiClienteEmMemoria {
    func trocarParaCasaParaTeste() async { await trocarPerfil(.contratante) }
    func trocarParaProfissionalParaTeste() async { await trocarPerfil(.profissional) }

    private func trocarPerfil(_ perfil: PerfilConta) async {
        guard let atual = try? await minhaConta() else { return }
        definirContaParaTeste(Conta(
            id: atual.id, perfil: perfil, nome: atual.nome, telefone: atual.telefone, email: atual.email,
            nascimento: atual.nascimento, estado: atual.estado
        ))
    }
}

/// O código do erro de uma operação, ou `nil` se ela deu certo. Compara o código tipado, e não o erro
/// inteiro, porque o `details` do envelope de exemplo do dublê não é o ponto destes testes.
private func codigoDoErro<T>(_ bloco: () async throws -> T) async -> CodigoErroAPI? {
    do {
        _ = try await bloco()
        return nil
    } catch let erro as ErroDaApi {
        return erro.codigo
    } catch {
        return .desconhecido
    }
}

private let inicioDoCodigo = Date(timeIntervalSince1970: 1_791_000_000)
private let turnoDoProfissionalNoCodigo = UUID(uuidString: "24000000-0000-0000-0000-000000000001")!
private let turnoDaCasaNoCodigo = UUID(uuidString: "82000000-0000-0000-0000-000000000001")!
private let codigoCerto = ApiClienteEmMemoria.codigosDeExemplo[0]
private let codigoErrado = "000001"

// MARK: Domínio e regras

@Suite("Check-in por código: tipo, erros, sinais e regras")
struct CheckinPorCodigoRegrasTests {
    @Test("TipoRegistro lê codigo; um valor desconhecido de ResultadoRegistro continua manual")
    func tipoDoRegistro() throws {
        func ler(_ tipo: String) throws -> TipoRegistro {
            try JSONDecoder().decode(TipoRegistro.self, from: Data("\"\(tipo)\"".utf8))
        }
        #expect(try ler("codigo") == .codigo)
        #expect(try ler("geolocalizado") == .geolocalizado)
        #expect(try ler("valor_novo") == .manual)
    }

    @Test("os erros novos do contrato têm código tipado, e o bloqueio lê temporario e encerrado")
    func errosNovos() {
        #expect(CodigoErroAPI(rawValue: "codigo_invalido") == .codigoInvalido)
        #expect(CodigoErroAPI(rawValue: "codigo_bloqueado") == .codigoBloqueado)
        let invalido = DecodificadorErroAPI.mapear(codigo: "codigo_invalido", detalhes: nil)
        #expect(invalido.codigo == .codigoInvalido)
        #expect(invalido.bloqueioDoCodigo == nil)
        #expect(DecodificadorErroAPI.mapear(codigo: "codigo_bloqueado", detalhes: "temporario").bloqueioDoCodigo == .temporario)
        #expect(DecodificadorErroAPI.mapear(codigo: "codigo_bloqueado", detalhes: "encerrado").bloqueioDoCodigo == .encerrado)
        #expect(
            DecodificadorErroAPI.mapear(codigo: "codigo_bloqueado", detalhes: nil).bloqueioDoCodigo == .encerrado,
            "sem details conhecido vale o mais restritivo, para o app não prometer nova tentativa"
        )
    }

    @Test("o salto de posição é de 50 m/s, com intervalo mínimo de 1 s, descontando as duas precisões")
    func saltoDePosicao() throws {
        #expect(SaltoDePosicao.velocidadeMaximaMetrosPorSegundo == 50)
        #expect(SaltoDePosicao.intervaloMinimoSegundos == 1)
        let origem = try Coordenada(latitude: -15.8267, longitude: -47.9218)
        let t0 = Date(timeIntervalSince1970: 1_791_000_000)
        // 0,001° de latitude são cerca de 111 m.
        let a111 = try Coordenada(latitude: -15.8277, longitude: -47.9218)
        // 0,01° são cerca de 1.111 m.
        let a1111 = try Coordenada(latitude: -15.8367, longitude: -47.9218)
        func leitura(_ c: Coordenada, _ precisao: Double, _ segundos: TimeInterval) -> (coordenada: Coordenada, precisaoMetros: Double, instante: Date) {
            (c, precisao, t0.addingTimeInterval(segundos))
        }
        #expect(!SaltoDePosicao.houve(de: leitura(origem, 5, 0), para: leitura(a111, 5, 5)), "111 m em 5 s é pouco")
        #expect(SaltoDePosicao.houve(de: leitura(origem, 5, 0), para: leitura(a1111, 5, 5)), "1.111 m em 5 s passa de 250 m")
        #expect(!SaltoDePosicao.houve(de: leitura(origem, 5, 0), para: leitura(a1111, 5, 30)), "1.111 m em 30 s cabem em 1.500 m")
        #expect(!SaltoDePosicao.houve(de: leitura(origem, 5, 0), para: leitura(a1111, 5, 0.9)), "menos de 1 s não conta")
        #expect(SaltoDePosicao.houve(de: leitura(origem, 5, 0), para: leitura(a1111, 5, 1)), "1 s já conta")
        #expect(
            !SaltoDePosicao.houve(de: leitura(origem, 600, 0), para: leitura(a1111, 600, 5)),
            "a imprecisão das duas leituras desconta: 1.111 − 1.200 não é salto"
        )
    }

    @Test("uma leitura só não tem salto nem localização simulada")
    func umaLeituraSo() throws {
        let leitura = LeituraDeLocalizacao(coordenada: try Coordenada(latitude: -15.8, longitude: -47.9), precisaoHorizontalMetros: 20)
        #expect(!leitura.simulada)
        #expect(!leitura.saltoDePosicao)
    }

    @Test("os sinais saem da leitura: simulada, salto e precisão em metros inteiros")
    func sinaisDaLeitura() throws {
        let c = try Coordenada(latitude: -15.8, longitude: -47.9)
        #expect(
            SinaisDoCheckin(leitura: LeituraDeLocalizacao(coordenada: c, precisaoHorizontalMetros: 12.6, simulada: true, saltoDePosicao: false))
                == SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: 13, saltoDePosicao: false)
        )
        #expect(
            SinaisDoCheckin(leitura: LeituraDeLocalizacao(coordenada: c, precisaoHorizontalMetros: 8, simulada: false, saltoDePosicao: true))
                == SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 8, saltoDePosicao: true)
        )
    }

    @Test("precisão que o aparelho não informa sai nula, e nula não é precisão ruim")
    func precisaoNula() throws {
        let c = try Coordenada(latitude: -15.8, longitude: -47.9)
        for invalida in [-1.0, Double.nan, Double.infinity] {
            let sinais = SinaisDoCheckin(leitura: LeituraDeLocalizacao(coordenada: c, precisaoHorizontalMetros: invalida))
            #expect(sinais.precisaoMetros == nil, "\(invalida)")
        }
    }

    @Test("o chegue mais perto segura acima de 100 m, libera até 100 m e sem posição")
    func chegueMaisPerto() {
        #expect(RegraDePresenca.raioDoCodigoMetros == 100)
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigo(distanciaMetros: 0) == .liberado)
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigo(distanciaMetros: 100) == .liberado)
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigo(distanciaMetros: 101) == .chegueMaisPerto(distanciaMetros: 101))
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigo(distanciaMetros: 5_000) == .chegueMaisPerto(distanciaMetros: 5_000))
        #expect(RegraDePresenca.decisaoDoEnvioDoCodigo(distanciaMetros: nil) == .liberado, "sem posição o servidor valida e marca confiança baixa")
    }

    @Test("a chave checkin_por_codigo vem desligada e ausente vale falso")
    func recursos() throws {
        #expect(RecursosDoApp.desligados.checkinPorCodigo == false)
        let sem = try JSONDecoder().decode(RecursosDoApp.self, from: Data(#"{"foto_de_perfil":true}"#.utf8))
        #expect(sem == RecursosDoApp(fotoDePerfil: false, checkinPorCodigo: false), "o JSON de domínio usa as chaves do Swift")
        let guardado = try JSONDecoder().decode(
            RecursosDoApp.self, from: Data(#"{"fotoDePerfil":true,"chamadaDireta":false,"perfilRico":true}"#.utf8)
        )
        #expect(guardado == RecursosDoApp(fotoDePerfil: true, chamadaDireta: false, perfilRico: true, checkinPorCodigo: false))
    }
}

// MARK: O dublê

@Suite("Check-in por código: o dublê segue o contrato 0.2.68")
struct CheckinPorCodigoNoDubleTests {
    private func profissional(_ relogio: RelogioDoCodigo = RelogioDoCodigo(inicioDoCodigo)) -> ApiClienteEmMemoria {
        ApiClienteEmMemoria(cenario: .checkinPorCodigo, relogio: relogio)
    }

    private func casa(_ relogio: RelogioDoCodigo) -> ApiClienteEmMemoria {
        ApiClienteEmMemoria(cenario: .checkinPorCodigoCasa, relogio: relogio)
    }

    /// O profissional e a casa falam com o mesmo estado do servidor, mas o dublê simula uma conta só. Os
    /// testes preparam o check-in pendente na conta da casa (que já nasce pendente) e validam como profissional
    /// trocando a conta, como o `definirContaParaTeste` faz nos outros testes do dublê.
    private func comCheckinPendente(_ relogio: RelogioDoCodigo = RelogioDoCodigo(inicioDoCodigo)) async throws -> ApiClienteEmMemoria {
        let api = profissional(relogio)
        let registro = try await api.fazerCheckin(turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: nil, registradoEm: relogio.agora)
        #expect(registro.verificacao == .pendente)
        return api
    }

    @Test("os dois cenários ligam a chave; o padrão a mantém desligada")
    func chaves() async throws {
        #expect(try await profissional().configuracaoDoApp().recursos.checkinPorCodigo)
        #expect(try await casa(RelogioDoCodigo(inicioDoCodigo)).configuracaoDoApp().recursos.checkinPorCodigo)
        #expect(try await ApiClienteEmMemoria().configuracaoDoApp().recursos.checkinPorCodigo == false)
        #expect(try await profissional().minhaConta().perfil == .profissional)
        #expect(try await casa(RelogioDoCodigo(inicioDoCodigo)).minhaConta().perfil == .contratante)
    }

    // MARK: fazer_checkin com sinais

    @Test("sem sinais, ou sem a chave, o check-in a até 200 m verifica na hora, como hoje")
    func checkinDeHoje() async throws {
        let semSinais = profissional()
        let a = try await semSinais.fazerCheckin(turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: 50, registradoEm: inicioDoCodigo)
        #expect(a.tipo == .geolocalizado && a.verificacao == .verificado && !a.codigoExigido && !a.codigoDisponivel)

        let semChave = profissional()
        await semChave.definirRecursos(.desligados)
        let suspeito = SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: 500, saltoDePosicao: true)
        let b = try await semChave.fazerCheckin(
            turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: 50, registradoEm: inicioDoCodigo, sinais: suspeito
        )
        #expect(b.verificacao == .verificado, "com a chave desligada, `fazer_checkin` ignora os sinais")
        #expect(!b.codigoExigido)
        #expect(await semChave.sinaisDoUltimoCheckin == nil, "e o dublê nem os guarda")
    }

    @Test("cada sinal suspeito, e a faixa de 150 a 200 m, deixa o check-in pendente com codigo_exigido")
    func sinalSuspeito() async throws {
        let casos: [(String, SinaisDoCheckin?, Int?)] = [
            ("localização simulada", SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: 10, saltoDePosicao: false), 50),
            ("salto de posição", SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 10, saltoDePosicao: true), 50),
            ("precisão ruim", SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 101, saltoDePosicao: false), 50),
            ("faixa de 150 a 200 m, sem sinais do aparelho", SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 10, saltoDePosicao: false), 151),
            ("faixa de 150 a 200 m, no limite", SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 10, saltoDePosicao: false), 200),
            ("faixa de 150 a 200 m, app sem sinais", nil, 180)
        ]
        for (nome, sinais, distancia) in casos {
            let api = profissional()
            let registro = try await api.fazerCheckin(
                turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: distancia, registradoEm: inicioDoCodigo, sinais: sinais
            )
            #expect(registro.verificacao == .pendente, "\(nome)")
            #expect(registro.tipo == .manual, "\(nome)")
            #expect(registro.codigoExigido, "\(nome)")
            #expect(registro.codigoDisponivel, "\(nome): a chave está ligada e o caminho, aberto")
            #expect(registro.distanciaMetros == nil, "\(nome): a distância não verificou, e não fica gravada")
        }
    }

    @Test("sem sinal suspeito, a até 150 m o check-in verifica pelo GPS, e precisão nula não é precisão ruim")
    func semSinalSuspeito() async throws {
        let normal = SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 100, saltoDePosicao: false)
        let nula = SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: nil, saltoDePosicao: false)
        for (nome, sinais) in [("precisão no limite de 100 m", normal), ("precisão nula", nula)] {
            let api = profissional()
            let registro = try await api.fazerCheckin(
                turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: 150, registradoEm: inicioDoCodigo, sinais: sinais
            )
            #expect(registro.verificacao == .verificado, "\(nome)")
            #expect(registro.tipo == .geolocalizado, "\(nome)")
            #expect(!registro.codigoExigido, "\(nome)")
            #expect(await api.sinaisDoUltimoCheckin == sinais, "\(nome): o dublê guarda o que chegou")
        }
    }

    @Test("a distância acima de 200 m, ou sem posição, é pendente sem codigo_exigido, e o código fica disponível")
    func semGPS() async throws {
        for distancia: Int? in [nil, 201, 1_000] {
            let api = profissional()
            let registro = try await api.fazerCheckin(
                turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: distancia, registradoEm: inicioDoCodigo,
                sinais: SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 10, saltoDePosicao: false)
            )
            #expect(registro.verificacao == .pendente)
            #expect(!registro.codigoExigido, "o GPS simplesmente não bastou")
            #expect(registro.codigoDisponivel)
        }
    }

    @Test("o reenvio devolve o mesmo registro, com codigo_disponivel do momento")
    func reenvio() async throws {
        let api = try await comCheckinPendente()
        let outra = try await api.fazerCheckin(turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: 10, registradoEm: inicioDoCodigo, sinais: nil)
        #expect(outra.verificacao == .pendente, "o primeiro registro vale")
        #expect(outra.codigoDisponivel)
        await api.definirRecursos(.desligados)
        let semChave = try await api.fazerCheckin(turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: 10, registradoEm: inicioDoCodigo, sinais: nil)
        #expect(!semChave.codigoDisponivel, "desligada a chave, o código deixa de estar disponível")
    }

    // MARK: gerar_codigo_checkin

    @Test("gerar: a casa recebe o código de 6 dígitos, com a validade contada pelo servidor")
    func gerar() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = casa(relogio)
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDaCasaNoCodigo)
        #expect(codigo.turnoID == turnoDaCasaNoCodigo)
        #expect(codigo.codigo == codigoCerto)
        #expect(codigo.codigo.count == 6 && codigo.codigo.allSatisfy(\.isNumber))
        #expect(codigo.segundosRestantes == 300)
        #expect(codigo.expiraEm == inicioDoCodigo.addingTimeInterval(300))
    }

    @Test("gerar dentro da validade devolve o mesmo código, e vencido, um novo")
    func gerarDeNovo() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = casa(relogio)
        let primeiro = try await api.gerarCodigoCheckin(turnoID: turnoDaCasaNoCodigo)
        relogio.avancar(100)
        let mesmo = try await api.gerarCodigoCheckin(turnoID: turnoDaCasaNoCodigo)
        #expect(mesmo.codigo == primeiro.codigo)
        #expect(mesmo.segundosRestantes == 200, "o servidor conta o que resta")
        relogio.avancar(201)
        let novo = try await api.gerarCodigoCheckin(turnoID: turnoDaCasaNoCodigo)
        #expect(novo.codigo != primeiro.codigo)
        #expect(novo.segundosRestantes == 300)
    }

    @Test("gerar: o profissional recebe sem_permissao, e a chave desligada, recurso_desligado sem tocar em dado")
    func gerarRecusas() async throws {
        let doProfissional = await codigoDoErro { try await profissional().gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo) }
        #expect(doProfissional == .semPermissao)
        let semChave = casa(RelogioDoCodigo(inicioDoCodigo))
        await semChave.definirRecursos(.desligados)
        let erro = try await #require(throws: ErroDaApi.self) { try await semChave.gerarCodigoCheckin(turnoID: turnoDaCasaNoCodigo) }
        #expect(erro.recursoDesligado)
    }

    @Test("gerar: turno que não existe é 404, sem check-in é checkin_pendente, e verificado é checkin_ja_confirmado")
    func gerarEstados() async throws {
        let api = casa(RelogioDoCodigo(inicioDoCodigo))
        #expect(await codigoDoErro { try await api.gerarCodigoCheckin(turnoID: UUID()) } == .naoEncontrado)

        let semCheckin = profissional()
        await semCheckin.trocarParaCasaParaTeste()
        #expect(await codigoDoErro { try await semCheckin.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo) } == .checkinPendente)

        _ = try await api.confirmarCheckinManual(turnoID: turnoDaCasaNoCodigo)
        #expect(await codigoDoErro { try await api.gerarCodigoCheckin(turnoID: turnoDaCasaNoCodigo) } == .checkinJaConfirmado)
    }

    // MARK: validar_codigo_checkin

    @Test("validar: código certo, em vigor e a até 100 m verifica pelo código e o consome")
    func validarCerto() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        await api.trocarParaCasaParaTeste()
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo)
        await api.trocarParaProfissionalParaTeste()
        relogio.avancar(30)
        let registro = try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: 100)
        #expect(registro.tipo == .codigo)
        #expect(registro.verificacao == .verificado)
        #expect(registro.distanciaMetros == nil, "a distância da leitura não é gravada")
        #expect(registro.registradoEm == inicioDoCodigo, "registrado_em é a hora do toque no check-in")
        #expect(try await api.meusTurnos().first?.verificacao == .verificado)
        let segunda = await codigoDoErro {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: 10)
        }
        #expect(segunda == .checkinJaConfirmado, "uso único: com a presença verificada, a resposta é checkin_ja_confirmado")
    }

    @Test("validar sem posição valida do mesmo jeito (o servidor marca confiança baixa)")
    func validarSemPosicao() async throws {
        let api = try await comCheckinPendente()
        await api.trocarParaCasaParaTeste()
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo)
        await api.trocarParaProfissionalParaTeste()
        let registro = try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: nil)
        #expect(registro.tipo == .codigo && registro.verificacao == .verificado)
    }

    @Test("validar: acima de 100 m, vencido ou errado é um codigo_invalido só, e cada um conta como tentativa")
    func validarInvalido() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        await api.trocarParaCasaParaTeste()
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo)
        await api.trocarParaProfissionalParaTeste()
        let acima = try await #require(throws: ErroDaApi.self) {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: 101)
        }
        #expect(acima.codigo == .codigoInvalido)
        #expect(acima.detalhes == nil, "um erro só, sem dizer o motivo")
        let errado = try await #require(throws: ErroDaApi.self) {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        #expect(errado == acima, "errado e acima de 100 m respondem o mesmo erro")
        // Com 2 erradas, o código certo ainda vale, e a terceira errada bloqueia.
        let certo = try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: 10)
        #expect(certo.tipo == .codigo)
    }

    @Test("validar vencido é codigo_invalido")
    func validarVencido() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        await api.trocarParaCasaParaTeste()
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo)
        await api.trocarParaProfissionalParaTeste()
        relogio.avancar(301)
        let vencido = await codigoDoErro {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: 10)
        }
        #expect(vencido == .codigoInvalido)
    }

    @Test("a terceira errada já responde bloqueio temporário, e a sexta, encerrado, sem nova espera")
    func bloqueios() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        func errar() async throws -> ErroDaApi {
            try await #require(throws: ErroDaApi.self) {
                try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
            }
        }
        #expect(try await errar().codigo == .codigoInvalido)
        #expect(try await errar().codigo == .codigoInvalido)
        let terceira = try await errar()
        #expect(terceira.bloqueioDoCodigo == .temporario, "3 erradas bloqueiam, e a terceira já responde o bloqueio")

        let durante = try await errar()
        #expect(durante.bloqueioDoCodigo == .temporario, "durante o bloqueio, qualquer leitura responde temporário")
        #expect(await api.chamadasAValidarCodigo == 4)

        relogio.avancar(301)
        #expect(try await errar().codigo == .codigoInvalido, "quarta errada, depois da espera")
        #expect(try await errar().codigo == .codigoInvalido, "quinta errada")
        let sexta = try await errar()
        #expect(sexta.bloqueioDoCodigo == .encerrado, "a sexta fecha o caminho, sem nova espera")
        relogio.avancar(10_000)
        #expect(try await errar().bloqueioDoCodigo == .encerrado, "e nada o reabre")
    }

    @Test("o bloqueio temporário vale mesmo com o código certo, e a casa ainda gera código")
    func bloqueioComCodigoCerto() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        for _ in 0..<3 {
            _ = try? await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        await api.trocarParaCasaParaTeste()
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo)
        await api.trocarParaProfissionalParaTeste()
        let erro = try await #require(throws: ErroDaApi.self) {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: 10)
        }
        #expect(erro.bloqueioDoCodigo == .temporario)
    }

    @Test("o contador é do turno: código novo não o zera")
    func codigoNovoNaoZera() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        for _ in 0..<2 {
            _ = try? await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        relogio.avancar(301)
        await api.trocarParaCasaParaTeste()
        _ = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo)
        await api.trocarParaProfissionalParaTeste()
        let terceira = try await #require(throws: ErroDaApi.self) {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        #expect(terceira.bloqueioDoCodigo == .temporario, "as 2 de antes contam: a terceira errada bloqueia")
    }

    @Test("encerrado o caminho, codigo_disponivel some e a casa não gera mais")
    func caminhoEncerrado() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        for volta in 0..<6 {
            if volta == 3 { relogio.avancar(301) }
            _ = try? await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        let reenvio = try await api.fazerCheckin(turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: nil, registradoEm: inicioDoCodigo, sinais: nil)
        #expect(!reenvio.codigoDisponivel, "o app volta à espera da confirmação manual")
        await api.trocarParaCasaParaTeste()
        let erro = try await #require(throws: ErroDaApi.self) { try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo) }
        #expect(erro.bloqueioDoCodigo == .encerrado)
        // O manual continua valendo: é a rede de segurança (caminho C).
        let confirmado = try await api.confirmarCheckinManual(turnoID: turnoDoProfissionalNoCodigo)
        #expect(confirmado.verificacao == .verificado)
    }

    @Test("validar: código fora do formato é campo_invalido e não conta tentativa")
    func formatoInvalido() async throws {
        let api = try await comCheckinPendente()
        for ruim in ["", "12345", "1234567", "12345a", "١٢٣٤٥٦"] {
            let erro = try await #require(throws: ErroDaApi.self) {
                try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: ruim, distanciaMetros: 10)
            }
            #expect(erro.codigo == .campoInvalido, "\(ruim)")
            #expect(erro.detalhes == "codigo", "\(ruim)")
        }
        // Nenhuma contou: seguem 3 tentativas até o primeiro bloqueio.
        for _ in 0..<2 {
            _ = try? await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        let terceira = try await #require(throws: ErroDaApi.self) {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        #expect(terceira.bloqueioDoCodigo == .temporario)
    }

    @Test("validar: a chave desligada responde recurso_desligado sem contar tentativa; conta de casa, perfil_incompativel")
    func validarRecusas() async throws {
        let api = try await comCheckinPendente()
        await api.definirRecursos(.desligados)
        let erro = try await #require(throws: ErroDaApi.self) {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoCerto, distanciaMetros: 10)
        }
        #expect(erro.recursoDesligado)
        await api.definirRecursos(RecursosDoApp(checkinPorCodigo: true))
        for _ in 0..<2 {
            _ = try? await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        let terceira = try await #require(throws: ErroDaApi.self) {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoErrado, distanciaMetros: 10)
        }
        #expect(terceira.bloqueioDoCodigo == .temporario, "a recusa por chave desligada não gastou tentativa")

        let daCasa = casa(RelogioDoCodigo(inicioDoCodigo))
        #expect(await codigoDoErro { try await daCasa.validarCodigoCheckin(turnoID: turnoDaCasaNoCodigo, codigo: codigoCerto, distanciaMetros: 10) } == .perfilIncompativel)
    }

    @Test("validar: sem check-in é checkin_pendente, e turno que não existe é 404")
    func validarEstados() async throws {
        let api = profissional()
        let semCheckin = await codigoDoErro {
            try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigoCerto, distanciaMetros: 10)
        }
        #expect(semCheckin == .checkinPendente)
        let semTurno = await codigoDoErro { try await api.validarCodigoCheckin(turnoID: UUID(), codigo: codigoCerto, distanciaMetros: 10) }
        #expect(semTurno == .naoEncontrado)
    }

    @Test("a confirmação manual depois do código é checkin_ja_confirmado, e a hora da validação não muda")
    func manualDepoisDoCodigo() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let api = try await comCheckinPendente(relogio)
        await api.trocarParaCasaParaTeste()
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo)
        await api.trocarParaProfissionalParaTeste()
        _ = try await api.validarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo, codigo: codigo.codigo, distanciaMetros: 10)
        await api.trocarParaCasaParaTeste()
        let manual = await codigoDoErro { try await api.confirmarCheckinManual(turnoID: turnoDoProfissionalNoCodigo) }
        #expect(manual == .checkinJaConfirmado)
    }
}

// MARK: A validação no app

@Suite("Check-in por código: a validação do profissional segura o envio e trata cada erro")
@MainActor
struct ValidacaoDoCodigoViewModelTests {
    private func api(_ relogio: RelogioDoCodigo = RelogioDoCodigo(inicioDoCodigo)) async throws -> (ApiClienteEmMemoria, String) {
        let api = ApiClienteEmMemoria(cenario: .checkinPorCodigo, relogio: relogio)
        _ = try await api.fazerCheckin(turnoID: turnoDoProfissionalNoCodigo, distanciaMetros: nil, registradoEm: relogio.agora)
        await api.trocarParaCasaParaTeste()
        let codigo = try await api.gerarCodigoCheckin(turnoID: turnoDoProfissionalNoCodigo).codigo
        await api.trocarParaProfissionalParaTeste()
        return (api, codigo)
    }

    @Test("acima de 100 m não envia o código e a tentativa não é gasta; até 100 m envia")
    func chegueMaisPerto() async throws {
        let (api, codigo) = try await api()
        let modelo = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: api)
        await modelo.validar(codigo: codigo, distanciaMetros: 101)
        #expect(modelo.resultado == .chegueMaisPerto(distanciaMetros: 101))
        #expect(await api.chamadasAValidarCodigo == 0, "nada saiu para o servidor")

        // Três vezes "longe" não bloqueiam: nenhuma gastou tentativa.
        for _ in 0..<3 { await modelo.validar(codigo: codigo, distanciaMetros: 5_000) }
        #expect(await api.chamadasAValidarCodigo == 0)

        await modelo.validar(codigo: codigo, distanciaMetros: 100)
        guard case let .verificado(registro) = modelo.resultado else {
            Issue.record("esperava verificado, veio \(modelo.resultado)")
            return
        }
        #expect(registro.tipo == .codigo)
        #expect(await api.chamadasAValidarCodigo == 1)
    }

    @Test("sem posição o código segue para o servidor")
    func semPosicao() async throws {
        let (api, codigo) = try await api()
        let modelo = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: api)
        await modelo.validar(codigo: codigo, distanciaMetros: nil)
        #expect(await api.chamadasAValidarCodigo == 1)
        if case .verificado = modelo.resultado {} else { Issue.record("esperava verificado, veio \(modelo.resultado)") }
    }

    @Test("fora do formato de 6 dígitos nada é enviado")
    func formato() async throws {
        let (api, _) = try await api()
        let modelo = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: api)
        for ruim in ["", "12345", "1234567", "12 456", "abcdef"] {
            await modelo.validar(codigo: ruim, distanciaMetros: 10)
            #expect(modelo.resultado == .formatoInvalido, "\(ruim)")
        }
        #expect(await api.chamadasAValidarCodigo == 0)
        #expect(ValidacaoDoCodigoViewModel.formatoValido("482913"))
    }

    @Test("o erro do servidor vira o estado certo: inválido, bloqueios, já verificado e chave desligada")
    func erros() async throws {
        let relogio = RelogioDoCodigo(inicioDoCodigo)
        let (api, codigo) = try await api(relogio)
        let modelo = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: api)
        await modelo.validar(codigo: codigoErrado, distanciaMetros: 10)
        #expect(modelo.resultado == .invalido)
        await modelo.validar(codigo: codigoErrado, distanciaMetros: 10)
        await modelo.validar(codigo: codigoErrado, distanciaMetros: 10)
        #expect(modelo.resultado == .bloqueado(.temporario))
        relogio.avancar(301)
        for _ in 0..<2 { await modelo.validar(codigo: codigoErrado, distanciaMetros: 10) }
        #expect(modelo.resultado == .invalido)
        await modelo.validar(codigo: codigoErrado, distanciaMetros: 10)
        #expect(modelo.resultado == .bloqueado(.encerrado))

        let (outra, certo) = try await self.api()
        let modeloDois = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: outra)
        await modeloDois.validar(codigo: certo, distanciaMetros: 10)
        await modeloDois.validar(codigo: certo, distanciaMetros: 10)
        #expect(modeloDois.resultado == .jaVerificado, "outra leitura chegou antes: presença verificada, relê o turno")

        let (desligada, _) = try await self.api()
        await desligada.definirRecursos(.desligados)
        let modeloTres = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: desligada)
        await modeloTres.validar(codigo: codigo, distanciaMetros: 10)
        #expect(modeloTres.resultado == .recursoDesligado)
    }

    @Test("se a resposta se perde, não repete sozinho: uma chamada só e estado para reler o turno")
    func respostaPerdida() async throws {
        for erro in [ErroDaApi(codigo: .semRede), ErroDaApi(codigo: .semRede, codigoOriginal: "timeout")] {
            let api = ApiDeValidacaoQuePerde(erro: erro)
            let modelo = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: api)
            await modelo.validar(codigo: codigoCerto, distanciaMetros: 10)
            #expect(modelo.resultado == .respostaPerdida)
            #expect(api.chamadas == 1, "sem repetição automática (0.2.69)")
        }
        let naoDaApi = ApiDeValidacaoQuePerde(erro: nil)
        let modelo = ValidacaoDoCodigoViewModel(turnoID: turnoDoProfissionalNoCodigo, api: naoDaApi)
        await modelo.validar(codigo: codigoCerto, distanciaMetros: 10)
        #expect(modelo.resultado == .respostaPerdida)
        #expect(naoDaApi.chamadas == 1)
    }
}

private final class ApiDeValidacaoQuePerde: ApiClienteEncaminhador, @unchecked Sendable {
    private struct ErroDeRede: Error {}
    private let erro: ErroDaApi?
    private let trava = NSLock()
    private var _chamadas = 0
    var chamadas: Int { trava.withLock { _chamadas } }

    init(erro: ErroDaApi?) {
        self.erro = erro
        super.init()
    }

    override func validarCodigoCheckin(turnoID: UUID, codigo: String, distanciaMetros: Int?) async throws -> ResultadoRegistro {
        trava.withLock { _chamadas += 1 }
        if let erro { throw erro }
        throw ErroDeRede()
    }
}

// MARK: Os sinais saem do check-in certos

/// Responde o check-in e o check-out sem passar pelo dublê, que não conhece este turno de teste.
private final class ApiDeCheckinFalso: ApiClienteEncaminhador, @unchecked Sendable {
    override func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        ResultadoRegistro(turnoID: turnoID, tipo: .geolocalizado, verificacao: .verificado, registradoEm: registradoEm, distanciaMetros: distanciaMetros)
    }

    override func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        ResultadoRegistro(turnoID: turnoID, tipo: .geolocalizado, verificacao: .verificado, registradoEm: registradoEm, distanciaMetros: distanciaMetros)
    }
}

@Suite("Check-in por código: os sinais saem certos, e só com a chave ligada")
@MainActor
struct SinaisNaPresencaTests {
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)
    private let ponto = try! Coordenada(latitude: -15.8267, longitude: -47.9218)

    private struct RelogioFixo: Relogio { let agora: Date }

    private func turno() throws -> Turno {
        let vaga = VagaResumo(
            id: UUID(), funcao: "Garçom", local: "Bar do Lago", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: agora.addingTimeInterval(-600), fim: agora.addingTimeInterval(4 * 3_600)), valor: Dinheiro(centavos: 15000)
        )
        let reputacao = Reputacao(positivas: 10, total: 10, taxaComparecimento: nil, turnosConsiderados: 10, turnosRealizados: 10)
        return Turno(
            id: UUID(), posicaoID: UUID(), vaga: vaga,
            contraparte: PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: "Bar do Lago", reputacao: reputacao),
            contatoVisivelAte: agora.addingTimeInterval(24 * 3_600), verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false, contato: nil
        )
    }

    /// Uma leitura a 30 m do ponto, com os sinais que o teste quiser.
    private func leitura(simulada: Bool, salto: Bool, precisao: Double = 12) throws -> LeituraDeLocalizacao {
        let perto = try Coordenada(latitude: -15.8269, longitude: -47.9219)
        return LeituraDeLocalizacao(coordenada: perto, precisaoHorizontalMetros: precisao, simulada: simulada, saltoDePosicao: salto)
    }

    private func checkin(
        leitura: LeituraDeLocalizacao, recursos: RecursosDoApp
    ) async throws -> (ApiDeCheckinFalso, PresencaDoTurnoViewModel) {
        let api = ApiDeCheckinFalso()
        let leitor = LeitorDeLocalizacaoSimulado(permissao: .aoUsarPrecisa, resultado: .success(leitura))
        let modelo = PresencaDoTurnoViewModel(
            turno: try turno(), api: api, localizacao: leitor, relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto,
            recursos: { recursos }
        )
        await modelo.iniciar(.checkin)
        return (api, modelo)
    }

    @Test("com a chave ligada e localização simulada, os sinais saem com localizacao_simulada")
    func simulada() async throws {
        let (api, _) = try await checkin(leitura: leitura(simulada: true, salto: false), recursos: RecursosDoApp(checkinPorCodigo: true))
        #expect(api.sinaisDoCheckin == [SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: 12, saltoDePosicao: false)])
    }

    @Test("com a chave ligada e localização real, os sinais saem sem simulação")
    func real() async throws {
        let (api, _) = try await checkin(leitura: leitura(simulada: false, salto: false), recursos: RecursosDoApp(checkinPorCodigo: true))
        #expect(api.sinaisDoCheckin == [SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 12, saltoDePosicao: false)])
    }

    @Test("o salto de posição da leitura vai nos sinais")
    func salto() async throws {
        let (api, _) = try await checkin(leitura: leitura(simulada: false, salto: true), recursos: RecursosDoApp(checkinPorCodigo: true))
        #expect(api.sinaisDoCheckin == [SinaisDoCheckin(localizacaoSimulada: false, precisaoMetros: 12, saltoDePosicao: true)])
    }

    @Test("com a chave desligada, o corpo do check-in é o de hoje: nenhum sinal, nem com localização simulada")
    func chaveDesligada() async throws {
        let (api, modelo) = try await checkin(leitura: leitura(simulada: true, salto: true), recursos: .desligados)
        #expect(api.sinaisDoCheckin == [nil])
        if case .registrado = modelo.checkin {} else { Issue.record("o check-in devia seguir como hoje, veio \(modelo.checkin)") }
    }

    @Test("por padrão, sem injetar os recursos, nenhum sinal sai")
    func padrao() async throws {
        let api = ApiDeCheckinFalso()
        let leitor = LeitorDeLocalizacaoSimulado(permissao: .aoUsarPrecisa, resultado: .success(try leitura(simulada: true, salto: true)))
        let modelo = PresencaDoTurnoViewModel(
            turno: try turno(), api: api, localizacao: leitor, relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto
        )
        await modelo.iniciar(.checkin)
        #expect(api.sinaisDoCheckin == [nil])
    }

    @Test("sem leitura (registro manual) não há sinais, mesmo com a chave ligada")
    func semLeitura() async throws {
        let api = ApiDeCheckinFalso()
        let leitor = LeitorDeLocalizacaoSimulado(permissao: .negada, resultado: .failure(.permissaoNegada))
        let modelo = PresencaDoTurnoViewModel(
            turno: try turno(), api: api, localizacao: leitor, relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto,
            recursos: { RecursosDoApp(checkinPorCodigo: true) }
        )
        await modelo.iniciar(.checkin)
        await modelo.registrarSemGPS()
        #expect(api.sinaisDoCheckin == [nil])
    }

    @Test("o check-out nunca manda sinais")
    func checkout() async throws {
        let api = ApiDeCheckinFalso()
        let leitor = LeitorDeLocalizacaoSimulado(permissao: .aoUsarPrecisa, resultado: .success(try leitura(simulada: true, salto: true)))
        let modelo = PresencaDoTurnoViewModel(
            turno: try turno(), api: api, localizacao: leitor, relogio: RelogioFixo(agora: agora), pontoDaVaga: ponto,
            recursos: { RecursosDoApp(checkinPorCodigo: true) }
        )
        await modelo.iniciar(.checkin)
        let antes = api.sinaisDoCheckin.count
        await modelo.iniciar(.checkout)
        #expect(api.sinaisDoCheckin.count == antes, "o check-out não passa por fazerCheckin")
    }
}

// MARK: O cliente Supabase

@Suite("Check-in por código: o cliente Supabase manda e lê o contrato 0.2.68", .serialized)
struct CheckinPorCodigoNoClienteTests {
    private let turno = UUID(uuidString: "24000000-0000-0000-0000-000000000001")!
    private let toque = Date(timeIntervalSince1970: 1_791_000_000)

    private func cliente() throws -> SupabaseApiCliente {
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.protocolClasses = [BackendDoCheckinPorCodigo.self]
        return SupabaseApiCliente(
            url: try #require(URL(string: "https://frila-teste.supabase.co")),
            chavePublicavel: "sb_publishable_teste",
            telemetria: TelemetryNula(),
            sessaoHTTP: URLSession(configuration: configuracao)
        )
    }

    private func registro(tipo: String = "manual", verificacao: String = "pendente", extra: String = "") -> String {
        """
        {"turno_id":"\(turno.uuidString.lowercased())","tipo":"\(tipo)","verificacao":"\(verificacao)",
         "registrado_em":"2026-09-30T14:20:00Z","distancia_m":null\(extra)}
        """
    }

    @Test("fazer_checkin sem sinais manda o corpo de antes: as 3 chaves, sem sinais")
    func semSinais() async throws {
        BackendDoCheckinPorCodigo.preparar(["/rest/v1/rpc/fazer_checkin": registro(tipo: "geolocalizado", verificacao: "verificado")])
        _ = try await cliente().fazerCheckin(turnoID: turno, distanciaMetros: 38, registradoEm: toque)
        let corpo = try #require(BackendDoCheckinPorCodigo.corpo(de: "/rest/v1/rpc/fazer_checkin"))
        #expect(Set(corpo.keys) == ["turno_id", "distancia_m", "registrado_em"], "sem `sinais`: o corpo é o de hoje")
        #expect(corpo["distancia_m"] as? Int == 38)
    }

    @Test("fazer_checkin com sinais manda os três campos, e precisao_m nulo vai como null")
    func comSinais() async throws {
        BackendDoCheckinPorCodigo.preparar(["/rest/v1/rpc/fazer_checkin": registro()])
        _ = try await cliente().fazerCheckin(
            turnoID: turno, distanciaMetros: 50, registradoEm: toque,
            sinais: SinaisDoCheckin(localizacaoSimulada: true, precisaoMetros: nil, saltoDePosicao: false)
        )
        let corpo = try #require(BackendDoCheckinPorCodigo.corpo(de: "/rest/v1/rpc/fazer_checkin"))
        #expect(Set(corpo.keys) == ["turno_id", "distancia_m", "registrado_em", "sinais"])
        let sinais = try #require(corpo["sinais"] as? [String: Any])
        #expect(Set(sinais.keys) == ["localizacao_simulada", "precisao_m", "salto_de_posicao"])
        #expect(sinais["localizacao_simulada"] as? Bool == true)
        #expect(sinais["salto_de_posicao"] as? Bool == false)
        #expect(sinais["precisao_m"] is NSNull, "o campo é obrigatório e aceita nulo: vai como null, não some")
    }

    @Test("o resultado lê codigo_exigido e codigo_disponivel, e ausentes valem falso")
    func resultado() async throws {
        BackendDoCheckinPorCodigo.preparar([
            "/rest/v1/rpc/fazer_checkin": registro(extra: #","codigo_exigido":true,"codigo_disponivel":true"#),
            "/rest/v1/rpc/fazer_checkout": registro(tipo: "geolocalizado", verificacao: "verificado")
        ])
        let exigido = try await cliente().fazerCheckin(turnoID: turno, distanciaMetros: 50, registradoEm: toque, sinais: nil)
        #expect(exigido.codigoExigido && exigido.codigoDisponivel)
        #expect(exigido.verificacao == .pendente)
        let sem = try await cliente().fazerCheckout(turnoID: turno, distanciaMetros: 5, registradoEm: toque)
        #expect(!sem.codigoExigido && !sem.codigoDisponivel)
    }

    @Test("gerar_codigo_checkin manda o turno e lê o código, a validade e os segundos restantes")
    func gerar() async throws {
        BackendDoCheckinPorCodigo.preparar([
            "/rest/v1/rpc/gerar_codigo_checkin":
                #"{"turno_id":"24000000-0000-0000-0000-000000000001","codigo":"482913","expira_em":"2026-09-30T14:25:00Z","segundos_restantes":287}"#
        ])
        let codigo = try await cliente().gerarCodigoCheckin(turnoID: turno)
        #expect(codigo.turnoID == turno)
        #expect(codigo.codigo == "482913")
        #expect(codigo.segundosRestantes == 287)
        #expect(codigo.expiraEm == ISO8601DateFormatter().date(from: "2026-09-30T14:25:00Z"))
        let corpo = try #require(BackendDoCheckinPorCodigo.corpo(de: "/rest/v1/rpc/gerar_codigo_checkin"))
        #expect(Set(corpo.keys) == ["turno_id"])
    }

    @Test("validar_codigo_checkin manda turno, código e distância (nula vai como null) e lê tipo codigo")
    func validar() async throws {
        BackendDoCheckinPorCodigo.preparar([
            "/rest/v1/rpc/validar_codigo_checkin": registro(tipo: "codigo", verificacao: "verificado")
        ])
        let resultado = try await cliente().validarCodigoCheckin(turnoID: turno, codigo: "482913", distanciaMetros: nil)
        #expect(resultado.tipo == .codigo)
        #expect(resultado.verificacao == .verificado)
        let corpo = try #require(BackendDoCheckinPorCodigo.corpo(de: "/rest/v1/rpc/validar_codigo_checkin"))
        #expect(Set(corpo.keys) == ["turno_id", "codigo", "distancia_m"])
        #expect(corpo["codigo"] as? String == "482913")
        #expect(corpo["distancia_m"] is NSNull)
    }

    @Test("os erros novos chegam tipados: codigo_invalido, codigo_bloqueado com details e recurso_desligado")
    func erros() async throws {
        func recusa(_ status: Int, _ code: String, _ details: String?) -> BackendDoCheckinPorCodigo.Resposta {
            let detalhe = details.map { #","details":"\#($0)""# } ?? ""
            return .init(status: status, corpo: #"{"code":"\#(code)","message":"\#(code)"\#(detalhe)}"#)
        }
        let rota = "/rest/v1/rpc/validar_codigo_checkin"
        BackendDoCheckinPorCodigo.preparar([rota: recusa(422, "codigo_invalido", nil)])
        let invalido = try await #require(throws: ErroDaApi.self) {
            try await cliente().validarCodigoCheckin(turnoID: turno, codigo: "000001", distanciaMetros: 10)
        }
        #expect(invalido.codigo == .codigoInvalido)

        for (details, esperado) in [("temporario", BloqueioDoCodigo.temporario), ("encerrado", .encerrado)] {
            BackendDoCheckinPorCodigo.preparar([rota: recusa(409, "codigo_bloqueado", details)])
            let erro = try await #require(throws: ErroDaApi.self) {
                try await cliente().validarCodigoCheckin(turnoID: turno, codigo: "000001", distanciaMetros: 10)
            }
            #expect(erro.bloqueioDoCodigo == esperado)
        }

        BackendDoCheckinPorCodigo.preparar([rota: recusa(403, "sem_permissao", "recurso_desligado")])
        let desligado = try await #require(throws: ErroDaApi.self) {
            try await cliente().validarCodigoCheckin(turnoID: turno, codigo: "000001", distanciaMetros: 10)
        }
        #expect(desligado.recursoDesligado)

        BackendDoCheckinPorCodigo.preparar([rota: recusa(409, "checkin_ja_confirmado", nil)])
        let jaConfirmado = try await #require(throws: ErroDaApi.self) {
            try await cliente().validarCodigoCheckin(turnoID: turno, codigo: "000001", distanciaMetros: 10)
        }
        #expect(jaConfirmado.codigo == .checkinJaConfirmado)
    }

    @Test("a leitura do código e a geração não entram nas rotas que o cliente repete sozinho")
    func semRepeticao() {
        #expect(!SupabaseApiCliente.rpcsDeLeitura.contains("validar_codigo_checkin"))
        #expect(!SupabaseApiCliente.rpcsDeLeitura.contains("gerar_codigo_checkin"))
        #expect(!SupabaseApiCliente.rpcsDeLeitura.contains("fazer_checkin"))
    }

    @Test("a configuração lê checkin_por_codigo, e ausente vale falso")
    func configuracao() async throws {
        func configuracao(_ recursos: String) -> String {
            #"{"versao_minima":"1.0.0","versao_recomendada":"1.0.0","mensagem":null,"url_da_loja":"https://apps.apple.com/br/app/frila/id1","recursos":\#(recursos)}"#
        }
        BackendDoCheckinPorCodigo.preparar(["/rest/v1/rpc/configuracao_do_app": configuracao(#"{"checkin_por_codigo":true}"#)])
        #expect(try await cliente().configuracaoDoApp().recursos.checkinPorCodigo)
        BackendDoCheckinPorCodigo.preparar(["/rest/v1/rpc/configuracao_do_app": configuracao(#"{"chamada_direta":true}"#)])
        let sem = try await cliente().configuracaoDoApp().recursos
        #expect(!sem.checkinPorCodigo && sem.chamadaDireta)
    }
}

/// O backend de mentira: responde cada rota com o corpo combinado e guarda o que o cliente mandou.
private final class BackendDoCheckinPorCodigo: URLProtocol {
    struct Resposta {
        let status: Int
        let corpo: String
        init(status: Int = 200, corpo: String) { self.status = status; self.corpo = corpo }
    }

    private static let trava = NSLock()
    nonisolated(unsafe) private static var rotas: [String: Resposta] = [:]
    nonisolated(unsafe) private static var recebidas: [String: Data] = [:]

    static func preparar(_ novas: [String: String]) {
        preparar(novas.mapValues { Resposta(corpo: $0) })
    }

    static func preparar(_ novas: [String: Resposta]) {
        trava.withLock { rotas = novas; recebidas = [:] }
    }

    static func corpo(de rota: String) -> [String: Any]? {
        let dados = trava.withLock { recebidas[rota] }
        return dados.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let enviado = Self.corpo(de: request)
        let resposta = Self.trava.withLock { () -> Resposta? in
            if let enviado { Self.recebidas[url.path] = enviado }
            return Self.rotas[url.path]
        }
        let http = HTTPURLResponse(
            url: url, statusCode: resposta?.status ?? 500, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((resposta?.corpo ?? "{}").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func corpo(de request: URLRequest) -> Data? {
        if let corpo = request.httpBody { return corpo }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var dados = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let lidos = stream.read(&buffer, maxLength: buffer.count)
            if lidos <= 0 { break }
            dados.append(buffer, count: lidos)
        }
        return dados
    }
}
