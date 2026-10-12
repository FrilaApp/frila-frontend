import Foundation
import Network
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Observation
import Testing

/// Medição de desempenho e de dados (#73): percentil, registro guardado no aparelho, relatório,
/// soma de bytes e o fim da abertura pela mudança do view model.
@Suite("Medição de desempenho (#73)")
struct MedicaoDeDesempenhoTests {
    private func registroIsolado() -> (RegistroDeMedicoes, UserDefaults) {
        let nome = "medicao-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: nome)!
        defaults.removePersistentDomain(forName: nome)
        return (RegistroDeMedicoes(defaults: defaults), defaults)
    }

    @Test("p95 pelo posto mais próximo: com 20 medições, é a 19ª menor")
    func percentilDeVinteMedicoes() {
        let valores = (1...20).map(Double.init).shuffled()
        #expect(RegistroDeMedicoes.percentil(95, de: valores) == 19)
        #expect(RegistroDeMedicoes.percentil(50, de: valores) == 10)
        #expect(RegistroDeMedicoes.percentil(100, de: valores) == 20)
    }

    @Test("Percentil de uma medição é ela mesma, e sem medição não há percentil")
    func percentilNasBordas() {
        #expect(RegistroDeMedicoes.percentil(95, de: [480]) == 480)
        #expect(RegistroDeMedicoes.percentil(95, de: []) == nil)
        #expect(RegistroDeMedicoes.percentil(0, de: [1, 2]) == nil)
    }

    @Test("As medições ficam no aparelho entre execuções e somem com Zerar")
    func registroGuardadoEZerado() {
        let (registro, defaults) = registroIsolado()
        registro.registrar(.detalheDaVaga, milissegundos: 300)
        registro.registrar(.detalheDaVaga, milissegundos: 500)
        registro.registrarTransferencia(enviados: 1_200, recebidos: 8_800)

        let reaberto = RegistroDeMedicoes(defaults: defaults)
        let resumo = reaberto.resumo()
        let detalhe = resumo.telas.first { $0.tela == .detalheDaVaga }
        #expect(detalhe?.quantidade == 2)
        #expect(detalhe?.p95 == 500)
        #expect(detalhe?.maximo == 500)
        #expect(resumo.requisicoes == 1)
        #expect(resumo.bytesTotais == 10_000)

        reaberto.zerar()
        #expect(RegistroDeMedicoes(defaults: defaults).resumo().telas.allSatisfy { $0.quantidade == 0 })
        #expect(RegistroDeMedicoes(defaults: defaults).resumo().bytesTotais == 0)
    }

    @Test("O relatório só tem números e diz se a sessão ficou abaixo de 1 MB")
    func relatorioEmTexto() {
        let (registro, _) = registroIsolado()
        registro.registrar(.listaDeVagas, milissegundos: 812.4)
        registro.registrarTransferencia(enviados: 2_000, recebidos: 998_001)
        let texto = registro.resumo().texto
        #expect(texto.contains("Lista de vagas: n=1 p50=812 ms p95=812 ms máx=812 ms"))
        #expect(texto.contains("Detalhe da vaga: sem medições"))
        #expect(texto.contains("total 1000001 B (acima de 1 MB)"))
    }

    @Test("A soma de bytes ignora o que veio do cache local")
    func somaDeBytes() {
        let soma = MedidorDeRede.somar([
            .init(pelaRede: true, enviados: 700, recebidos: 4_000),
            .init(pelaRede: false, enviados: 0, recebidos: 9_999),
            .init(pelaRede: true, enviados: 300, recebidos: 1_000),
        ])
        #expect(soma?.enviados == 1_000)
        #expect(soma?.recebidos == 5_000)
        #expect(MedidorDeRede.somar([.init(pelaRede: false, enviados: 10, recebidos: 10)]) == nil)
    }

    @Test("Sessão HTTP local com cache vazio: lista, três detalhes e candidatura abaixo de 1 MB", .timeLimit(.minutes(1)))
    func bytesDaSessaoComHTTPReal() async throws {
        let lista = try FixturesDoContrato.dados("vagas-abertas")
        let detalhe = try FixturesDoContrato.dados("vaga")
        let candidatura = try FixturesDoContrato.dados("candidatura-urgencia")
        let servidor = try ServidorHTTPDeMedicao(respostas: [
            "/rest/v1/rpc/vagas_abertas": lista,
            "/rest/v1/rpc/detalhe_vaga": detalhe,
            "/rest/v1/rpc/candidatar": candidatura
        ])
        defer { servidor.parar() }
        let url = try await servidor.iniciar()
        let (registro, _) = registroIsolado()
        registro.zerar()
        let configuracao = URLSessionConfiguration.ephemeral
        configuracao.urlCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0, diskPath: nil)
        configuracao.urlCache?.removeAllCachedResponses()
        configuracao.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuracao.timeoutIntervalForRequest = 5
        let sessao = URLSession(configuration: configuracao, delegate: MedidorDeRede(registro: registro), delegateQueue: nil)
        defer { sessao.invalidateAndCancel() }
        let cliente = SupabaseApiCliente(
            url: url, chavePublicavel: "sb_publishable_teste", telemetria: TelemetryNula(),
            sessaoHTTP: sessao, armazenamentoDaSessao: ArmazenamentoDeSessaoEmMemoria()
        )
        #expect(configuracao.urlCache?.currentMemoryUsage == 0)
        #expect(registro.resumo().bytesTotais == 0)

        let vagas = try await cliente.vagasAbertas(FiltroVagas())
        let vaga = try #require(vagas.first)
        for _ in 0..<3 {
            #expect(try await cliente.detalheDaVaga(id: vaga.id).id == vaga.id)
        }
        guard try await cliente.candidatar(vagaID: vaga.id).estado == .confirmada else {
            Issue.record("A fixture deve confirmar a candidatura")
            return
        }
        // O delegate pode terminar de publicar as métricas depois da resposta do cliente.
        let prazo = ContinuousClock.now.advanced(by: .seconds(2))
        while registro.resumo().requisicoes < 5, ContinuousClock.now < prazo {
            try await Task.sleep(for: .milliseconds(20))
        }
        let resumo = registro.resumo()
        #expect(servidor.rotasRecebidas == [
            "/rest/v1/rpc/vagas_abertas", "/rest/v1/rpc/detalhe_vaga",
            "/rest/v1/rpc/detalhe_vaga", "/rest/v1/rpc/detalhe_vaga", "/rest/v1/rpc/candidatar"
        ])
        #expect(resumo.requisicoes == 5)
        #expect(resumo.bytesEnviados > 0, "0 B não prova o contador HTTP")
        #expect(resumo.bytesRecebidos >= Int64(lista.count + 3 * detalhe.count + candidatura.count))
        #expect(resumo.bytesTotais < ResumoDasMedicoes.limiteDaSessao)
        print("MEDICOES HTTP local: requisições=\(resumo.requisicoes) enviados=\(resumo.bytesEnviados) B recebidos=\(resumo.bytesRecebidos) B total=\(resumo.bytesTotais) B limite=\(ResumoDasMedicoes.limiteDaSessao) B")
    }

    @Test("A abertura termina na mudança que publica o conteúdo, e não no fim da carga")
    @MainActor
    func aberturaTerminaNoConteudo() async {
        let (registro, _) = registroIsolado()
        let tela = TelaFalsa()
        let antes = ContinuousClock.now
        await medirAbertura(.listaDeVagas, registro: registro, carregar: { await tela.carregar(depoisDoConteudo: .milliseconds(300)) }) {
            tela.naTela
        }
        let total = milissegundos(ContinuousClock.now - antes)
        let lista = registro.resumo().telas.first { $0.tela == .listaDeVagas }
        #expect(lista?.quantidade == 1)
        let medida = lista?.maximo ?? 0
        #expect(medida >= 59, "inclui a espera pela API (\(medida) ms)")
        // Depois do conteúdo, a carga ainda espera 300 ms (como a lista, que busca as funções).
        #expect(medida <= total - 300, "não inclui o resto da carga (\(medida) de \(total) ms)")
    }

    @Test("Puxar para atualizar com vagas novas mede até a lista nova")
    @MainActor
    func atualizarComNovidade() async {
        let (registro, _) = registroIsolado()
        let tela = TelaFalsa()
        tela.estado = .carregada(versao: 1)
        await medirAbertura(.listaDeVagas, registro: registro, carregar: { await tela.atualizar(para: 2) }) {
            tela.naTela
        }
        #expect(registro.resumo().telas.first { $0.tela == .listaDeVagas }?.quantidade == 1)
    }

    @Test("Puxar para atualizar sem novidade mede até o retorno da carga")
    @MainActor
    func atualizarSemNovidade() async {
        let (registro, _) = registroIsolado()
        let tela = TelaFalsa()
        tela.estado = .carregada(versao: 1)
        await medirAbertura(.listaDeVagas, registro: registro, carregar: { await tela.atualizar(para: 1) }) {
            tela.naTela
        }
        let lista = registro.resumo().telas.first { $0.tela == .listaDeVagas }
        #expect(lista?.quantidade == 1)
        #expect((lista?.maximo ?? 0) >= 29)
    }

    @Test("Erro ou falta de rede não entram na medição")
    @MainActor
    func falhaNaoRegistra() async {
        let (registro, _) = registroIsolado()
        let tela = TelaFalsa()
        await medirAbertura(.detalheDaVaga, registro: registro, carregar: { await tela.falhar() }) {
            tela.naTela
        }
        #expect(registro.resumo().telas.allSatisfy { $0.quantidade == 0 })
    }

    @Test("Sem registro (Debug sem -FRILA_MEDICAO), a tela só carrega")
    @MainActor
    func semRegistroSoCarrega() async {
        let tela = TelaFalsa()
        await medirAbertura(.meuTurno, registro: nil, carregar: { await tela.carregar(depoisDoConteudo: .zero) }) {
            tela.naTela
        }
        #expect(tela.naTela)
    }

    private func milissegundos(_ duracao: Duration) -> Double {
        Double(duracao.components.seconds) * 1000 + Double(duracao.components.attoseconds) / 1e15
    }
}

/// Dublê HTTP na interface loopback: usa o transporte real para a URLSession produzir métricas.
/// As respostas são imutáveis; as rotas observadas têm trava. Não guarda cabeçalhos ou credenciais.
private final class ServidorHTTPDeMedicao: @unchecked Sendable {
    private let listener: NWListener
    private let fila = DispatchQueue(label: "frila.testes.medicao-http")
    private let respostas: [String: Data]
    private let trava = NSLock()
    private var rotas: [String] = []
    var rotasRecebidas: [String] { trava.withLock { rotas } }

    init(respostas: [String: Data]) throws {
        self.respostas = respostas
        let parametros = NWParameters.tcp
        parametros.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parametros)
    }

    func iniciar() async throws -> URL {
        try await withCheckedThrowingContinuation { continuacao in
            listener.stateUpdateHandler = { [self] estado in
                switch estado {
                case .ready:
                    listener.stateUpdateHandler = nil
                    guard let porta = listener.port,
                          let url = URL(string: "http://127.0.0.1:\(porta.rawValue)") else {
                        continuacao.resume(throwing: URLError(.badURL))
                        return
                    }
                    continuacao.resume(returning: url)
                case let .failed(erro):
                    listener.stateUpdateHandler = nil
                    continuacao.resume(throwing: erro)
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] conexao in
                guard let self else { conexao.cancel(); return }
                conexao.start(queue: self.fila)
                self.receber(conexao, acumulado: Data())
            }
            listener.start(queue: fila)
        }
    }

    func parar() { listener.cancel() }

    private func receber(_ conexao: NWConnection, acumulado: Data) {
        conexao.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [self] dados, _, fim, erro in
            let completo = acumulado + (dados ?? Data())
            guard erro == nil else { conexao.cancel(); return }
            if let separador = completo.range(of: Data("\r\n\r\n".utf8)) {
                let cabecalho = String(decoding: completo[..<separador.lowerBound], as: UTF8.self)
                let linhas = cabecalho.components(separatedBy: "\r\n")
                let tamanho = linhas.first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "") } ?? 0
                if completo.count >= separador.upperBound + tamanho {
                    let rota = linhas.first?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
                    trava.withLock { rotas.append(rota) }
                    let corpo = respostas[rota] ?? Data("{}".utf8)
                    let status = respostas[rota] == nil ? "404 Not Found" : "200 OK"
                    let resposta = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(corpo.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8) + corpo
                    conexao.send(content: resposta, completion: .contentProcessed { _ in conexao.cancel() })
                    return
                }
            }
            guard !fim else { conexao.cancel(); return }
            receber(conexao, acumulado: completo)
        }
    }
}

/// View model mínimo: carregando, a resposta da API depois de uma espera e, às vezes, mais trabalho
/// depois de publicar (como a lista, que busca as funções depois das vagas).
@MainActor @Observable
private final class TelaFalsa {
    enum Estado: Equatable { case ociosa, carregando, carregada(versao: Int), falha }
    var estado: Estado = .ociosa
    var naTela: Bool { if case .carregada = estado { true } else { false } }

    func carregar(depoisDoConteudo resto: Duration) async {
        estado = .carregando
        try? await Task.sleep(for: .milliseconds(60))
        estado = .carregada(versao: 1)
        try? await Task.sleep(for: resto)
    }

    /// Puxar para atualizar: a lista fica na tela, e a resposta pode ser igual à de antes.
    func atualizar(para versao: Int) async {
        try? await Task.sleep(for: .milliseconds(30))
        estado = .carregada(versao: versao)
    }

    func falhar() async {
        estado = .carregando
        try? await Task.sleep(for: .milliseconds(20))
        estado = .falha
    }
}
