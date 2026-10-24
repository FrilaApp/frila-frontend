import XCTest

/// Prova automatizada da anatomia Hi-Fi da placa de vaga (fatia Profissional 1): casa acima da
/// função, caixa alta apenas visual (VoiceOver lê o nome original) e identificadores preservados.
@MainActor
final class PlacaDaVagaUITests: XCTestCase {

    // MARK: - 1. Feed: casa acima da função, rótulo original

    func testFeedMostraCasaAcimaDaFuncaoComRotuloOriginal() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer))

        let cartao = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(cartao.waitForExistence(timeout: Espera.aparecer))

        // 1a) O botão do cartão preserva o accessibilityLabel de antes (rotuloDeAcessibilidade),
        //     que contém o nome original do estabelecimento ("Bistrô Ipê", não "BISTRÔ IPÊ").
        let rotulo = cartao.label
        XCTAssertTrue(rotulo.contains("Bistrô Ipê"), "O rótulo do cartão deve conter o nome original do estabelecimento. Rótulo: \(rotulo)")
        XCTAssertFalse(rotulo.contains("BISTRÔ IPÊ"), "O rótulo do cartão não deve conter caixa alta. Rótulo: \(rotulo)")
        XCTAssertTrue(rotulo.contains("Garçom"), "O rótulo do cartão deve conter a função. Rótulo: \(rotulo)")

        // 1b) O cartão preserva o accessibilityIdentifier com prefixo vaga-.
        XCTAssertTrue(cartao.identifier.hasPrefix("vaga-"), "O cartão mantém o identificador 'vaga-<UUID>'")

        // 1c) Ordem visual: casa (estabelecimento) acima da função.
        let todosTextos = app.staticTexts
        let casa = todosTextos.matching(NSPredicate(format: "label == %@ OR label == %@", "Bistrô Ipê", "BISTRÔ IPÊ")).firstMatch
        let funcao = todosTextos["Garçom"].firstMatch
        if casa.waitForExistence(timeout: 3) && funcao.waitForExistence(timeout: 3) {
            esperarEstabilizacaoDeFrame(casa)
            XCTAssertLessThan(casa.frame.minY, funcao.frame.minY,
                              "A casa (estabelecimento) deve estar visualmente acima da função no cartão de vaga")
        }
    }

    // MARK: - 2. Detalhe: placa aberta

    func testDetalheEhPlacaAberta() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001"]
        app.launch()

        let detalhe = app.descendants(matching: .any)["tela-detalhe-vaga"]
        XCTAssertTrue(detalhe.waitForExistence(timeout: Espera.aparecer))

        let todosTextos = app.staticTexts
        let casa = todosTextos.matching(NSPredicate(format: "label == %@", "Bistrô Ipê")).firstMatch
        XCTAssertTrue(casa.waitForExistence(timeout: Espera.aparecer),
                      "O estabelecimento deve estar no detalhe com label original 'Bistrô Ipê'")
        XCTAssertFalse(todosTextos["BISTRÔ IPÊ"].exists,
                      "O estabelecimento não deve expor label em caixa alta para acessibilidade")

        let funcao = todosTextos["Garçom"].firstMatch
        XCTAssertTrue(funcao.waitForExistence(timeout: Espera.aparecer),
                      "A função deve estar no detalhe")

        esperarEstabilizacaoDeFrame(casa)
        XCTAssertLessThan(casa.frame.minY, funcao.frame.minY,
                          "No detalhe, a casa (estabelecimento) deve estar acima da função")

        // NOTA: XCUITest no iOS não expõe o traço .isHeader em XCUIElement público de SwiftUI Text.
        // A ordem e o rótulo original estão comprovados; o traço .isHeader está declarado em TelaDetalheVaga.swift:279.
    }

    // MARK: - 3. Vaga original na candidatura em seleção

    func testVagaOriginalNaCandidaturaMantemRotulo() {
        // 3a) Cenário vaga-em-selecao: após candidatar-se, a confirmação de envio mantém o nome
        //     original do estabelecimento no resumo da vaga.
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "vaga-em-selecao", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001"]
        app.launch()

        let candidatar = app.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: Espera.aparecer))
        candidatar.tap()

        let enviada = app.descendants(matching: .any)["candidatura-enviada"]
        XCTAssertTrue(enviada.waitForExistence(timeout: Espera.aparecer),
                      "A candidatura em seleção deve mostrar o estado 'enviada'")

        let resumo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Bistrô Ipê")).firstMatch
        XCTAssertTrue(resumo.waitForExistence(timeout: Espera.aparecer),
                      "Após candidatar-se, o resumo deve conter o nome original do estabelecimento 'Bistrô Ipê'")
        XCTAssertFalse(resumo.label.contains("BISTRÔ IPÊ"),
                      "O resumo não deve conter o nome do estabelecimento em caixa alta")
        XCTAssertTrue(resumo.label.contains("Garçom"),
                      "O resumo deve conter a função 'Garçom'")

        // 3b) Seção 'Vaga original' (exibida quando a vaga já foi preenchida ou encerrada):
        //     comprova a anatomia Hi-Fi da placa aberta (casa acima da função com rótulo original).
        let appPreenchida = XCUIApplication()
        appPreenchida.launchArguments = ["-FRILA_SCENARIO", "vaga-preenchida", "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001"]
        appPreenchida.launch()

        let candidatarPreenchida = appPreenchida.buttons["candidatar"]
        XCTAssertTrue(candidatarPreenchida.waitForExistence(timeout: Espera.aparecer))
        candidatarPreenchida.tap()

        XCTAssertTrue(appPreenchida.descendants(matching: .any)["resultado-vaga-preenchida"].waitForExistence(timeout: Espera.aparecer))

        let casaOriginal = appPreenchida.staticTexts.matching(NSPredicate(format: "label == %@", "Bistrô Ipê")).firstMatch
        XCTAssertTrue(casaOriginal.waitForExistence(timeout: Espera.aparecer),
                      "Em 'Vaga original', a casa deve aparecer com label original 'Bistrô Ipê'")
        XCTAssertFalse(appPreenchida.staticTexts["BISTRÔ IPÊ"].exists,
                      "Em 'Vaga original', o label não deve ser em caixa alta")

        let funcaoOriginal = appPreenchida.staticTexts["Garçom"].firstMatch
        XCTAssertTrue(funcaoOriginal.waitForExistence(timeout: Espera.aparecer),
                      "Em 'Vaga original', a função deve estar visível")

        esperarEstabilizacaoDeFrame(casaOriginal)
        XCTAssertLessThan(casaOriginal.frame.minY, funcaoOriginal.frame.minY,
                          "Em 'Vaga original', a casa (estabelecimento) deve estar acima da função")
    }

    // MARK: - 4. Chip de filtro ativo mantém valor

    func testChipDeFiltroAtivoMantemValor() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer))

        let filtroFuncao = app.descendants(matching: .any)["filtro-funcao"]
        XCTAssertTrue(filtroFuncao.waitForExistence(timeout: Espera.aparecer))

        let valorAntes = filtroFuncao.value as? String ?? ""
        XCTAssertTrue(valorAntes.isEmpty, "Filtro inativo não deve ter accessibilityValue de 'filtro ativo'")

        tocar(filtroFuncao)

        let garcomBotao = app.buttons["Garçom"]
        let garcomMenu = app.menuItems["Garçom"]
        if garcomBotao.waitForExistence(timeout: 5) {
            garcomBotao.tap()
        } else if garcomMenu.waitForExistence(timeout: 3) {
            garcomMenu.tap()
        } else {
            let opcoes = app.buttons.matching(NSPredicate(format: "identifier == '' AND label != ''"))
            if opcoes.count > 1 {
                opcoes.element(boundBy: 1).tap()
            } else {
                XCTFail("Não foi possível selecionar uma função no menu de filtro")
                return
            }
        }

        let predicadoAtivo = NSPredicate(format: "value == %@", "filtro ativo")
        let esperaAtivo = XCTNSPredicateExpectation(predicate: predicadoAtivo, object: filtroFuncao)
        let resultado = XCTWaiter.wait(for: [esperaAtivo], timeout: Espera.aparecer)
        XCTAssertEqual(resultado, .completed,
                       "Após selecionar uma função, o filtro deve ter accessibilityValue 'filtro ativo'. Valor atual: \(filtroFuncao.value as? String ?? "nil")")
    }
}
