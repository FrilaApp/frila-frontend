import Foundation
import FrilaApresentacao
import FrilaDados
import Testing

/// Busca estática no código do app (critério 4 do #53): os logs de execução são auditados por
/// `Scripts/auditar-logs-sensiveis.sh`; aqui a busca é no próprio código, a cada `xcodebuild test`.
@Suite("Dados sensíveis no código")
struct SegurancaDoCodigoTests {
    private static let raiz = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func arquivosSwift() throws -> [(nome: String, linhas: [Substring])] {
        let fontes = raiz.appending(path: "Sources")
        // Caminhos relativos: o prefixo absoluto visto pelo simulador pode diferir do de #filePath
        // (/tmp e /private/tmp), e o nome "Sources/..." não pode depender dele.
        let caminhos = try #require(FileManager.default.subpaths(atPath: fontes.path))
        return try caminhos
            .filter { $0.hasSuffix(".swift") }
            .map { relativo in
                let conteudo = try String(contentsOf: fontes.appending(path: relativo), encoding: .utf8)
                return ("Sources/" + relativo, conteudo.split(separator: "\n", omittingEmptySubsequences: false))
            }
    }

    @Test("A busca enxerga o código do app")
    func enxergaOCodigo() throws {
        #expect(try Self.arquivosSwift().count > 20)
    }

    @Test("Nenhum print, NSLog, debugPrint ou dump no app")
    func semSaidaSolta() throws {
        let saidaSolta = /(^|[^A-Za-z0-9_.])(print|NSLog|debugPrint|dump)\(/
        var achados: [String] = []
        for arquivo in try Self.arquivosSwift() {
            for (indice, linha) in arquivo.linhas.enumerated() where linha.contains(saidaSolta) {
                achados.append("\(arquivo.nome):\(indice + 1)")
            }
        }
        #expect(achados.isEmpty, "saída fora do Logger em \(achados)")
    }

    @Test("A raiz liga a janela de privacidade acima das apresentações, também em Release (A4)")
    func cortinaLigadaNaRaiz() throws {
        let app = try #require(try Self.arquivosSwift().first { $0.nome == "Sources/App/FrilaApp.swift" })
        var pilha = 0
        var ligadaForaDeIf = false
        for linha in app.linhas {
            let codigo = linha.trimmingCharacters(in: .whitespaces)
            if codigo.hasPrefix("#if") { pilha += 1 } else if codigo.hasPrefix("#endif") { pilha -= 1 }
            if pilha == 0, codigo.hasPrefix(".cortinaDePrivacidade()") { ligadaForaDeIf = true }
        }
        #expect(ligadaForaDeIf, "FrilaApp.swift precisa aplicar .cortinaDePrivacidade() na raiz, em Release também")
        let cortina = try #require(try Self.arquivosSwift().first { $0.nome == "Sources/Apresentacao/CortinaDePrivacidade.swift" })
        let codigo = cortina.linhas.joined(separator: "\n")
        #expect(codigo.contains("JanelaDaCortina(windowScene: novaCena)"))
        #expect(codigo.contains("janela.windowLevel = .alert + 1"), "A janela precisa ficar acima das apresentações UIKit")
        #expect(codigo.contains("UIScene.willDeactivateNotification"), "Cobrir antes da captura, sem aguardar o SwiftUI")
        #expect(codigo.contains("UIScene.didActivateNotification"))
        #expect(codigo.contains("override var canBecomeKey: Bool { false }"))
        #expect(!codigo.contains("makeKeyAndVisible"))
        #expect(!codigo.contains("#if"), "A proteção das folhas também precisa existir em Release")
    }

    @Test("Argumentos de rota e de catálogo só existem dentro de #if DEBUG")
    func argumentosSoEmDebug() throws {
        let argumentosDeDebug = ["-FRILA_VAGA_ID", "-FRILA_ABRIR_CATALOGO"]
        var achados: [String] = []
        var encontrados = 0
        for arquivo in try Self.arquivosSwift() {
            // Pilha dos #if abertos: true quando o ramo atual só compila em DEBUG.
            var pilha: [Bool] = []
            for (indice, linha) in arquivo.linhas.enumerated() {
                let codigo = linha.trimmingCharacters(in: .whitespaces)
                if codigo.hasPrefix("#if") {
                    pilha.append(codigo == "#if DEBUG")
                } else if codigo.hasPrefix("#else") || codigo.hasPrefix("#elseif") {
                    if !pilha.isEmpty { pilha[pilha.count - 1] = false }
                } else if codigo.hasPrefix("#endif") {
                    _ = pilha.popLast()
                } else if argumentosDeDebug.contains(where: { linha.contains($0) }) {
                    encontrados += 1
                    if !pilha.contains(true) { achados.append("\(arquivo.nome):\(indice + 1)") }
                }
            }
        }
        #expect(encontrados > 0, "a busca não achou os argumentos: o teste não está olhando o lugar certo")
        #expect(achados.isEmpty, "argumento de Debug fora de #if DEBUG em \(achados)")
    }

    @Test("Todo arquivo que o app grava leva .completeFileProtection")
    func arquivosGravadosComProtecaoCompleta() throws {
        // `Data.write(to:options:)`: o que o app grava em disco é a exportação dos dados da pessoa
        // (JSON, CSV, PDF). O simulador não tem proteção de dados, então a opção é conferida no
        // código, a cada `xcodebuild test`, e não no atributo do arquivo.
        let gravacao = /\.write\(to:/
        var achados: [String] = []
        var encontrados = 0
        for arquivo in try Self.arquivosSwift() {
            for (indice, linha) in arquivo.linhas.enumerated() where linha.contains(gravacao) {
                encontrados += 1
                if !linha.contains(".completeFileProtection") { achados.append("\(arquivo.nome):\(indice + 1)") }
            }
        }
        #expect(encontrados > 0, "a busca não achou nenhuma gravação: o teste não está olhando o lugar certo")
        #expect(achados.isEmpty, "gravação em disco sem .completeFileProtection em \(achados)")
    }

    @Test("Nenhum log interpola e-mail, token, sessão, senha, telefone ou chave")
    func logsSemDadoSensivel() throws {
        let interpolacao = /\\\(([^)]*)\)/
        let sensivel = /(?i)(e-?mail|token|sess(ao|ion)|senha|password|telefone|phone|chave|apikey|jwt|bearer)/
        var achados: [String] = []
        for arquivo in try Self.arquivosSwift() {
            for (indice, linha) in arquivo.linhas.enumerated() where linha.contains(/logger\.|Logger\(|os_log/) {
                for trecho in linha.matches(of: interpolacao) where trecho.output.1.contains(sensivel) {
                    achados.append("\(arquivo.nome):\(indice + 1)")
                }
            }
        }
        #expect(achados.isEmpty, "log com dado sensível em \(achados)")
    }

    // MARK: - Acessibilidade e Colagem do Código (JayUsWVo)

    @Test("Entrada de código suporta colagem direta limitando a 6 dígitos e filtrando caracteres mistos")
    @MainActor
    func colagemDeCodigoFiltraELimita() {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")

        // Código colado com mais de 6 caracteres limita em 6 dígitos
        vm.codigo = "12345678"
        #expect(vm.codigo == "123456")
        #expect(vm.codigoValido)

        // Código colado com caracteres mistos filtra apenas dígitos e limita em 6
        vm.codigo = "12ab34cd5678"
        #expect(vm.codigo == "123456")
        #expect(vm.codigoValido)
    }

    @Test("VoiceOver anuncia dígitos separadamente com vírgula para leitura dígito a dígito")
    @MainActor
    func acessibilidadeVoiceOverDigitoADigito() {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")

        vm.codigo = "123456"
        #expect(vm.textoAcessibilidadeCodigo == "1, 2, 3, 4, 5, 6")
    }

    @Test("Campo de código vazio retorna string localizada Vazio para o VoiceOver")
    @MainActor
    func acessibilidadeCodigoVazio() {
        let api = ApiClienteEmMemoria()
        let vm = CodigoViewModel(api: api, email: "teste@frila.app")

        vm.codigo = ""
        #expect(vm.textoAcessibilidadeCodigo == "Vazio")
    }

    @Test("TelaCodigo amarra colagem direta (.oneTimeCode) e leitura VoiceOver (.accessibilityValue)")
    func telaCodigoConfiguraColagemEAcessibilidade() throws {
        let tela = try #require(try Self.arquivosSwift().first { $0.nome.contains("TelaCodigo.swift") })
        let codigo = tela.linhas.joined(separator: "\n")
        #expect(codigo.contains(".textContentType(.oneTimeCode)"))
        #expect(codigo.contains(".accessibilityValue(viewModel.textoAcessibilidadeCodigo)"))
        #expect(codigo.contains(".accessibilityIdentifier(\"codigo-campo\")"))
    }
}
