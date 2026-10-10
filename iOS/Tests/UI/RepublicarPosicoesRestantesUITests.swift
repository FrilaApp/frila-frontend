import XCTest

@MainActor
final class RepublicarPosicoesRestantesUITests: XCTestCase {
    private func salvarCaptura(_ nome: String) {
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)

        if let diretorio = ProcessInfo.processInfo.environment["FRILA_CAPTURAS_DIR"], !diretorio.isEmpty {
            let destino = URL(fileURLWithPath: diretorio).appendingPathComponent("\(nome).png")
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: diretorio), withIntermediateDirectories: true)
                try captura.pngRepresentation.write(to: destino)
            } catch {
                XCTFail("Falha ao exportar captura para \(destino.path): \(error)")
            }
        }
    }

    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 5) {
        for _ in 0..<tentativas {
            if elemento.isHittable { return }
            app.swipeUp()
        }
    }

    func testFluxoDeRepublicacaoEmMinhasVagasEDetalhePadrao() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "selecao-encerrada-sem-escolha"
        ]
        app.launch()

        // 1. Minhas vagas (lista) - padrão
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        let botaoNaLista = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-vaga-")).firstMatch
        XCTAssertTrue(botaoNaLista.waitForExistence(timeout: 10), "Botão de urgência deve aparecer no cartão da vaga de seleção encerrada")
        salvarCaptura("minhas-vagas-padrao")

        // 2. Detalhe da vaga original - padrão
        let cartaoVaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vaga-contratante-")).firstMatch
        XCTAssertTrue(cartaoVaga.waitForExistence(timeout: 10))
        cartaoVaga.tap()

        let botaoNoDetalhe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-detalhe-vaga-")).firstMatch
        XCTAssertTrue(botaoNoDetalhe.waitForExistence(timeout: 10), "Botão de urgência deve aparecer no detalhe da vaga")
        rolarAte(botaoNoDetalhe, em: app)
        salvarCaptura("detalhe-padrao")

        // 3. Toca em republicar: navega para a nova vaga de urgência criada (resolvida pelo Roteador no Environment)
        botaoNoDetalhe.tap()

        // Aguarda a nova vaga de urgência abrir na hierarquia do NavigationStack comprovando ID exato
        let novoTitulo = app.staticTexts["funcao-vaga-detalhe-50000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(novoTitulo.waitForExistence(timeout: 10), "Navegação deve exibir detalhe da nova vaga com ID exato retornado pela RPC (50000000-0000-0000-0000-000000000001)")

        let tituloOriginal = app.staticTexts["funcao-vaga-detalhe-40000000-0000-0000-0000-000000000001"]
        XCTAssertFalse(tituloOriginal.exists, "A tela aberta não deve ser a vaga original de seleção (40000000-0000-0000-0000-000000000001)")
        salvarCaptura("urgencia-criada-padrao")

        // 4. Retorna da tela de urgência criada
        let botaoVoltar = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(botaoVoltar.waitForExistence(timeout: 10))
        botaoVoltar.tap()
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10) || cartaoVaga.waitForExistence(timeout: 10), "Deve retornar à tela de Minhas vagas")
    }

    func testMinhasVagasEDetalheDynamicTypeXXXL() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "selecao-encerrada-sem-escolha",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        // 1. Minhas vagas em Dynamic Type XXXL
        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        let botaoNaLista = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-vaga-")).firstMatch
        XCTAssertTrue(botaoNaLista.waitForExistence(timeout: 10))
        rolarAte(botaoNaLista, em: app)
        salvarCaptura("minhas-vagas-xxxl")

        // 2. Detalhe em Dynamic Type XXXL
        let cartaoVaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vaga-contratante-")).firstMatch
        XCTAssertTrue(cartaoVaga.waitForExistence(timeout: 10))
        cartaoVaga.tap()

        let botaoNoDetalhe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-detalhe-vaga-")).firstMatch
        XCTAssertTrue(botaoNoDetalhe.waitForExistence(timeout: 10))
        rolarAte(botaoNoDetalhe, em: app)
        salvarCaptura("detalhe-xxxl")
    }

    func testRecusaMantemErroVisivelAposReleituraRemoverElegibilidade() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "selecao-encerrada-sem-escolha",
            "-FRILA_REPUBLICAR_RECUSA", "sem_posicoes_restantes"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        let cartaoVaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vaga-contratante-")).firstMatch
        XCTAssertTrue(cartaoVaga.waitForExistence(timeout: 10))
        cartaoVaga.tap()

        let botaoNoDetalhe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-detalhe-vaga-")).firstMatch
        XCTAssertTrue(botaoNoDetalhe.waitForExistence(timeout: 10))
        rolarAte(botaoNoDetalhe, em: app)

        // Executa republicação: o dublê responde com a recusa simulada (sem_posicoes_restantes)
        botaoNoDetalhe.tap()

        // 1. O aviso de erro de recusa aparece com a mensagem correspondente
        let avisoErro = app.descendants(matching: .any)["republicar-urgencia-detalhe-vaga-40000000-0000-0000-0000-000000000001-erro"]
        XCTAssertTrue(avisoErro.waitForExistence(timeout: 10), "Aviso de erro deve ser exibido após recusa da RPC")

        // 2. A releitura do painel conclui de forma estruturada e remove a ação
        XCTAssertFalse(botaoNoDetalhe.waitForExistence(timeout: 2), "O botão de ação deve ser removido quando a elegibilidade é perdida")

        // 3. O aviso de erro permanece retido e legível na tela
        XCTAssertTrue(avisoErro.exists, "O aviso de erro deve permanecer visível após a remoção do botão")
        salvarCaptura("recusa-erro-retido-padrao")
    }

    func testIdempotenciaReusoDeChaveAposFalhaTransitoria() throws {
        let tempDir = NSTemporaryDirectory()
        let arquivoChaves = URL(fileURLWithPath: tempDir).appendingPathComponent("frila-chaves-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: arquivoChaves) }

        let app = XCUIApplication()
        app.launchEnvironment["FRILA_CHAVES_ARQUIVO"] = arquivoChaves.path
        app.launchArguments = [
            "-FRILA_ABRIR_MINHAS_VAGAS",
            "-FRILA_SCENARIO", "selecao-encerrada-sem-escolha",
            "-FRILA_REPUBLICAR_FALHA_TRANSITORIA"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Minhas vagas"].waitForExistence(timeout: 10))
        let cartaoVaga = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "vaga-contratante-")).firstMatch
        XCTAssertTrue(cartaoVaga.waitForExistence(timeout: 10))
        cartaoVaga.tap()

        let botaoNoDetalhe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "republicar-urgencia-detalhe-vaga-")).firstMatch
        XCTAssertTrue(botaoNoDetalhe.waitForExistence(timeout: 10))
        rolarAte(botaoNoDetalhe, em: app)

        // 1. Primeiro toque: dublê simula semRede
        botaoNoDetalhe.tap()

        // Aviso de erro transitório de rede aparece
        let avisoErro = app.descendants(matching: .any).matching(NSPredicate(format: "identifier ENDSWITH %@", "-erro")).firstMatch
        XCTAssertTrue(avisoErro.waitForExistence(timeout: 10), "Aviso de erro transitório deve aparecer na tela")

        // Como o erro foi transitório (semRede), a ação continua elegível na tela para retentativa
        XCTAssertTrue(botaoNoDetalhe.waitForExistence(timeout: 5), "Botão de republicação deve permanecer disponível para nova tentativa após erro transitório")

        // 2. Segundo toque: deve reutilizar a mesma chave de idempotência
        botaoNoDetalhe.tap()

        // Aguarda navegação para a nova vaga de urgência criada
        let novaVaga = app.staticTexts["funcao-vaga-detalhe-50000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(novaVaga.waitForExistence(timeout: 10), "Segunda tentativa deve ter sucesso e navegar para a nova vaga de urgência")

        // 3. Validação observável das chaves recebidas pela RPC
        let conteudo = try String(contentsOf: arquivoChaves, encoding: .utf8)
        let chaves = conteudo.split(separator: "\n").map(String.init)
        XCTAssertEqual(chaves.count, 2, "RPC deve registrar duas chamadas")
        XCTAssertEqual(chaves[0], chaves[1], "Ambas as chamadas devem reutilizar a mesma chave de idempotência")
    }
}
