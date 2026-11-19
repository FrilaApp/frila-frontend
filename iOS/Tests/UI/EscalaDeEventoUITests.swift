import XCTest

/// A escala de evento da casa (`publicar_escala`, contrato 0.2.96): o caminho feliz contra o dublê em memória e as capturas
/// da tela no tamanho padrão e em AX5. `FRILA_CAPTURAS_DIR` (opcional) grava as imagens; sem ela, os anexos ficam só no
/// resultado do teste.
@MainActor
final class EscalaDeEventoUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Ajudantes

    private func abrir(ax5: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "contratante", "-FRILA_CACHE_VAZIO_UI_TEST", "-FRILA_MODO_CLARO",
                               "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"]
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func elemento(_ id: String, em app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func vagas(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-contratante-'"))
    }

    /// Abre a escala pela entrada de Minhas vagas e devolve quantas vagas a lista tinha antes.
    @discardableResult
    private func abrirEscala(_ app: XCUIApplication) -> Int {
        XCTAssertTrue(elemento("minhas-vagas", em: app).waitForExistence(timeout: 15), "Minhas vagas deve abrir")
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: Espera.aparecer))
        let antes = vagas(app).count
        tocar(app.buttons["publicar-escala-entrada"])
        XCTAssertTrue(elemento("escala-nome", em: app).waitForExistence(timeout: Espera.aparecer), "A escala deve abrir")
        return antes
    }

    /// Arrasta a rolagem pela margem direita da tela: o centro pode cair numa roda de data ou hora e girá-la (e mudar um
    /// horário sem querer). `paraCima` leva o conteúdo para cima (mostra o que está abaixo).
    private func arrastarPelaMargem(_ app: XCUIApplication, paraCima: Bool) {
        let de = app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: paraCima ? 0.65 : 0.30))
        let ate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: paraCima ? 0.30 : 0.65))
        de.press(forDuration: 0.1, thenDragTo: ate)
    }

    /// Rola até o elemento ficar inteiro entre a barra e o rodapé (o rodapé ancorado cobre a base da janela).
    private func trazer(_ elemento: XCUIElement, em app: XCUIApplication) {
        let janela = app.windows.firstMatch.frame
        for _ in 0..<14 {
            let quadro = elemento.frame
            if elemento.exists, quadro.minY > 130, quadro.maxY < janela.height - 150 { return }
            arrastarPelaMargem(app, paraCima: !(elemento.exists && quadro.minY <= 130))
        }
    }

    /// Fecha o teclado (texto ou numérico). O numérico não tem Return: arrasta a rolagem para baixo pela margem, que o
    /// `scrollDismissesKeyboard(.interactively)` da tela recolhe.
    private func fecharTecladoEscala(_ app: XCUIApplication) {
        for _ in 0..<3 {
            guard app.keyboards.firstMatch.exists else { return }
            arrastarPelaMargem(app, paraCima: false)
            let sumiu = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
            if XCTWaiter.wait(for: [sumiu], timeout: 2) == .completed { return }
        }
    }

    private func capturar(_ nome: String, ax5: Bool) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let nomeCompleto = "escala-\(nome)-\(ax5 ? "ax5" : "padrao")"
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nomeCompleto
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !pasta.isEmpty {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nomeCompleto).png"))
        }
    }

    /// Escolhe a primeira função da folha (`indice` 0) ou a segunda (`indice` 1) para a vaga `vaga`.
    private func escolherFuncao(_ app: XCUIApplication, vaga: Int, opcao indice: Int) {
        let linha = app.buttons["escala-funcao-\(vaga)"]
        trazer(linha, em: app)
        tocar(linha)
        XCTAssertTrue(elemento("escala-folha-de-funcao", em: app).waitForExistence(timeout: Espera.aparecer))
        let opcoes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'escala-opcao-funcao-'"))
        XCTAssertTrue(opcoes.element(boundBy: indice).waitForExistence(timeout: Espera.aparecer))
        tocar(opcoes.element(boundBy: indice))
        XCTAssertTrue(linha.waitForExistence(timeout: Espera.aparecer))
    }

    /// Toca no campo, apaga o que houver e digita. O valor do campo marcado com erro é lido como "texto, Erro: mensagem"
    /// (a marca é parte do valor para o leitor de tela), por isso a conferência é pelo começo do valor e não pela igualdade
    /// do `substituirTexto` compartilhado.
    private func digitarNoCampo(_ campo: XCUIElement, por texto: String, file: StaticString = #filePath, line: UInt = #line) {
        var focado = false
        for _ in 0..<4 where !focado {
            esperarEstabilizacaoDeFrame(campo, timeout: 3)
            campo.tap()
            focado = esperarFocoDoTeclado(campo, timeout: 3)
        }
        XCTAssertTrue(focado, "o campo deveria receber o foco do teclado", file: file, line: line)
        guard focado else { return }
        let atual = ((campo.value as? String) ?? "")
        if !atual.isEmpty {
            campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: atual.count))
        }
        campo.typeText(texto)
        XCTAssertTrue(((campo.value as? String) ?? "").hasPrefix(texto), "o campo deveria mostrar \"\(texto)\" depois da digitação", file: file, line: line)
    }

    private func preencherResponsavel(_ app: XCUIApplication, vaga: Int, nome: String) {
        let campo = app.textFields["escala-responsavel-\(vaga)"]
        trazer(campo, em: app)
        digitarNoCampo(campo, por: nome)
        fecharTecladoEscala(app)
    }

    /// "16000" -> "R$ 160,00", como o campo mostra (o espaço pode vir inseparável).
    private func textoDoValor(_ centavos: String) -> String {
        let n = Int(centavos) ?? 0
        return String(format: "R$ %d,%02d", n / 100, n % 100)
    }

    private func normalizado(_ texto: String?) -> String {
        (texto ?? "").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    /// Digita o valor, confere o foco e o valor final ("R$ 180,00") e refaz uma vez se não bater.
    private func digitarValor(_ app: XCUIApplication, vaga: Int, centavos: String) {
        let campo = app.textFields.matching(identifier: "valor-vaga-campo").element(boundBy: vaga)
        let esperado = textoDoValor(centavos)
        trazer(campo, em: app)
        for tentativa in 0..<2 {
            tocar(campo)
            XCTAssertTrue(esperarFocoDoTeclado(campo, timeout: 5), "o campo de valor deveria receber o foco")
            if tentativa > 0 { campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12)) }
            campo.typeText(centavos)
            if normalizado(campo.value as? String) == esperado { break }
        }
        XCTAssertEqual(normalizado(campo.value as? String), esperado, "o valor final do campo")
        fecharTecladoEscala(app)
    }

    // MARK: Caminho feliz

    func testCasaPublicaUmaEscalaComDuasVagasEElasApareceNaLista() {
        let app = abrir()
        let antes = abrirEscala(app)

        digitarNoCampo(app.textFields["escala-nome"], por: "Formatura de Direito")
        fecharTecladoEscala(app)

        escolherFuncao(app, vaga: 0, opcao: 0)
        digitarValor(app, vaga: 0, centavos: "16000")
        preencherResponsavel(app, vaga: 0, nome: "Marina")

        let adicionar = app.buttons["escala-adicionar-vaga"]
        trazer(adicionar, em: app)
        tocar(adicionar)
        XCTAssertTrue(elemento("escala-vaga-1", em: app).waitForExistence(timeout: Espera.aparecer), "A segunda vaga deve entrar")
        escolherFuncao(app, vaga: 1, opcao: 1)
        digitarValor(app, vaga: 1, centavos: "18000")
        let maisUma = app.buttons["escala-pessoas-mais-1"]
        trazer(maisUma, em: app)
        tocar(maisUma)
        XCTAssertEqual(elemento("escala-total-de-pessoas", em: app).label, "Total: 3 de 100 pessoas")

        tocar(app.buttons["escala-publicar"])

        let confirmacao = elemento("escala-confirmacao", em: app)
        XCTAssertTrue(confirmacao.waitForExistence(timeout: 15), "A escala publicada deve ser confirmada")
        XCTAssertTrue(confirmacao.label.contains("2 vagas"), confirmacao.label)
        tocar(app.buttons["escala-ver-minhas-vagas"])

        XCTAssertTrue(elemento("minhas-vagas", em: app).waitForExistence(timeout: Espera.aparecer))
        expectation(for: NSPredicate(format: "count == %d", antes + 2), evaluatedWith: vagas(app))
        waitForExpectations(timeout: 15)
    }

    func testPublicarComFormularioVazioMarcaOsCamposENaoPublicaNada() {
        let app = abrir()
        let antes = abrirEscala(app)

        tocar(app.buttons["escala-publicar"])

        let mensagem = elemento("escala-mensagem", em: app)
        XCTAssertTrue(mensagem.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(mensagem.label.contains("Nada foi publicado"), mensagem.label)
        XCTAssertTrue(elemento("escala-erro-nome", em: app).exists)
        XCTAssertFalse(elemento("escala-confirmacao", em: app).exists)

        tocar(app.buttons["escala-cancelar"])
        XCTAssertTrue(vagas(app).firstMatch.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(vagas(app).count, antes)
    }

    /// Em AX5 o aviso vai para o alto da rolagem: depois de Publicar ele tem de aparecer na tela (rolagem até ele), e não
    /// ficar fora da primeira tela, onde quem só aumenta a letra acharia que o botão não fez nada.
    func testEmAX5OErroAparecaNaTelaDepoisDePublicar() {
        let app = abrir(ax5: true)
        abrirEscala(app)

        // Desce a tela, para o aviso do alto ficar fora dela antes do toque.
        for _ in 0..<3 { app.swipeUp(velocity: .fast) }
        tocar(app.buttons["escala-publicar"])

        let mensagem = elemento("escala-mensagem", em: app)
        XCTAssertTrue(mensagem.waitForExistence(timeout: Espera.aparecer))
        let janela = app.windows.firstMatch.frame
        let visivel = NSPredicate { _, _ in
            let quadro = mensagem.frame
            return mensagem.exists && quadro.minY >= 100 && quadro.maxY <= janela.height - 100
        }
        expectation(for: visivel, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        capturar("2-erros-de-campo", ax5: true)
    }

    /// Quem usa letra grande e corrige um campo marcado com erro não pode perder o teclado: a marca do campo não some na
    /// primeira letra (o conteúdo encolheria, o campo pularia debaixo do dedo e o teclado cairia, deixando "M").
    func testEmAX5CorrigirOCampoMarcadoComErroMantemOTecladoAberto() {
        let app = abrir(ax5: true)
        abrirEscala(app)
        tocar(app.buttons["escala-publicar"])
        XCTAssertTrue(elemento("escala-mensagem", em: app).waitForExistence(timeout: Espera.aparecer))

        let campo = app.textFields["escala-responsavel-0"]
        trazer(campo, em: app)
        XCTAssertTrue(elemento("escala-erro-responsavel-0", em: app).exists, "o responsável vazio está marcado")

        digitarNoCampo(campo, por: "Marina")

        XCTAssertTrue((campo.value as? String ?? "").hasPrefix("Marina"), "o campo mostra o que foi digitado: \(campo.value as? String ?? "")")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "o teclado segue aberto depois de digitar no campo marcado")
    }

    /// Em AX5 não há roda de data ou hora dentro da rolagem: dia, início e fim são linhas que abrem uma folha. Rolar a tela
    /// inteira pelo centro não pode girar nada e mudar um horário sem querer.
    func testEmAX5RolarATelaPeloCentroNaoMudaNenhumHorario() {
        let app = abrir(ax5: true)
        abrirEscala(app)
        XCTAssertEqual(app.pickerWheels.count, 0, "em AX5 não há roda de data ou hora dentro da rolagem")

        func horarios() -> [String] {
            ["escala-dia", "escala-inicio-0", "escala-fim-0"].map { id in
                let e = elemento(id, em: app)
                return "\(id)=\(e.exists ? "\(e.label)|\((e.value as? String) ?? "")" : "-")"
            }
        }
        let antes = horarios()
        for _ in 0..<5 { app.swipeUp(velocity: .slow) }
        for _ in 0..<5 { app.swipeDown(velocity: .slow) }
        XCTAssertEqual(horarios(), antes, "rolar pelo centro não muda nenhum horário")
        XCTAssertEqual(app.pickerWheels.count, 0)
    }

    /// Em AX5 a linha do início abre a folha com as duas rodas (dia e hora) e fecha pelo botão.
    func testEmAX5OHorarioSeEscolheNaFolha() {
        let app = abrir(ax5: true)
        abrirEscala(app)
        let linha = elemento("escala-inicio-0", em: app)
        trazer(linha, em: app)
        tocar(linha)
        XCTAssertTrue(elemento("escala-folha-de-horario", em: app).waitForExistence(timeout: Espera.aparecer), "a folha de horário deve abrir")
        // A roda do dia tem 3 colunas (dia, mês, ano) e a da hora 2 (hora, minuto): 5 no total.
        XCTAssertEqual(app.pickerWheels.count, 5, "a folha tem a roda do dia e a da hora")
        tocar(app.buttons["escala-fechar-horario"])
        XCTAssertFalse(elemento("escala-folha-de-horario", em: app).waitForExistence(timeout: 2), "a folha deve fechar")
        XCTAssertEqual(app.pickerWheels.count, 0)
    }

    // MARK: Capturas (tamanho padrão e AX5)

    func testCapturasDaEscala() {
        for ax5 in [false, true] {
            let app = abrir(ax5: ax5)
            abrirEscala(app)
            capturar("1-formulario", ax5: ax5)

            tocar(app.buttons["escala-publicar"])
            XCTAssertTrue(elemento("escala-mensagem", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("2-erros-de-campo", ax5: ax5)

            digitarNoCampo(app.textFields["escala-nome"], por: "Formatura de Direito")
            fecharTecladoEscala(app)
            let funcao = app.buttons["escala-funcao-0"]
            trazer(funcao, em: app)
            tocar(funcao)
            XCTAssertTrue(elemento("escala-folha-de-funcao", em: app).waitForExistence(timeout: Espera.aparecer))
            capturar("3-escolher-funcao", ax5: ax5)
            tocar(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'escala-opcao-funcao-'")).firstMatch)

            let adicionar = app.buttons["escala-adicionar-vaga"]
            trazer(adicionar, em: app)
            tocar(adicionar)
            XCTAssertTrue(elemento("escala-vaga-1", em: app).waitForExistence(timeout: Espera.aparecer))
            trazer(elemento("escala-vaga-1", em: app), em: app)
            capturar("4-duas-vagas", ax5: ax5)

            digitarValor(app, vaga: 0, centavos: "16000")
            preencherResponsavel(app, vaga: 0, nome: "Marina")
            escolherFuncao(app, vaga: 1, opcao: 1)
            preencherResponsavel(app, vaga: 1, nome: "Marina")
            digitarValor(app, vaga: 1, centavos: "18000")
            tocar(app.buttons["escala-publicar"])
            let confirmou = elemento("escala-confirmacao", em: app).waitForExistence(timeout: 15)
            if !confirmou {
                // O que a tela mostra quando a confirmação não vem: a captura e a mensagem da ação, para achar a causa.
                capturar("FALHA-sem-confirmacao", ax5: ax5)
                let marcas = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'escala-erro-'")).allElementsBoundByIndex
                print("FALHA-CAMPOS-MARCADOS: " + marcas.map { "\($0.identifier)=\($0.label)" }.joined(separator: " | "))
                let valores = app.textFields.allElementsBoundByIndex.map { "\($0.identifier)=\(($0.value as? String) ?? "")" }
                print("FALHA-VALORES: " + valores.joined(separator: " | "))
                print("FALHA-SEM-CONFIRMACAO ax5=\(ax5) mensagem=\(elemento("escala-mensagem", em: app).exists ? elemento("escala-mensagem", em: app).label : "(sem mensagem)")")
            }
            XCTAssertTrue(confirmou, "a confirmação da escala deveria aparecer (ax5=\(ax5))")
            capturar("5-publicada", ax5: ax5)
            app.terminate()
        }
    }
}
