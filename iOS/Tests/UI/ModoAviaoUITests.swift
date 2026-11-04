import XCTest

/// Modo avião (#73, RNF06): o turno confirmado com rede fica no cache do aparelho; aberto de novo sem
/// rede (o dublê `sem-rede` recusa toda chamada), Meus turnos e o turno continuam na tela, e o
/// check-in vai para a fila. O "Como chegar" (endereço e Abrir no mapa) continua na tela, e nada de
/// contato aparece, com ou sem rede (contato fora do app).
@MainActor
final class ModoAviaoUITests: XCTestCase {
    /// O telefone do exemplo do contrato (`Resources/Fixtures/contato.json`), que o dublê ainda entrega
    /// como contato do turno: o app não pode mostrá-lo.
    private static let telefoneDoDuble = "+5561999990000"

    private func telefone(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", Self.telefoneDoDuble)).firstMatch
    }

    private func conferirSemContato(_ app: XCUIApplication) {
        XCTAssertFalse(telefone(app).exists, "o telefone do dublê não deve aparecer")
        XCTAssertFalse(app.buttons["botao-whatsapp"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["contato-do-turno"].exists)
    }

    private func destinoDoMapa(_ app: XCUIApplication) throws -> URL {
        let mapa = app.buttons["botao-abrir-no-mapa"]
        XCTAssertTrue(mapa.waitForExistence(timeout: Espera.aparecer))
        for _ in 0..<3 where !mapa.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(mapa.isHittable)
        mapa.tap()
        let abertura = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value BEGINSWITH %@", "https://maps.apple.com/"), object: mapa
        )
        XCTAssertEqual(XCTWaiter.wait(for: [abertura], timeout: Espera.aparecer), .completed, "o toque deve abrir o endereço no mapa")
        let valor = try XCTUnwrap(mapa.value as? String, "o abridor deve registrar o destino acionado pelo Link")
        let url = try XCTUnwrap(URL(string: valor), "destino capturado: \(valor)")
        XCTAssertEqual(url.host, "maps.apple.com")
        return url
    }

    func testTurnoConfirmadoContinuaLegivelSemRedeEOCheckinVaiParaAFila() throws {
        // Com rede: candidata-se e abre Meus turnos, que guarda o turno no cache, e o turno, com o Como chegar.
        let comRede = XCUIApplication()
        // Sem `-FRILA_CACHE_VAZIO_UI_TEST`, que troca o cache por um em memória: o turno tem de ir ao
        // disco para o segundo lançamento ler.
        comRede.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_LOCALIZACAO", "perto", "-FRILA_CAPTURAR_URL_UI_TEST"]
        comRede.launch()
        let primeira = comRede.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        XCTAssertTrue(primeira.waitForExistence(timeout: 10))
        primeira.tap()
        let candidatar = comRede.buttons["candidatar"]
        XCTAssertTrue(candidatar.waitForExistence(timeout: 10))
        candidatar.tap()
        XCTAssertTrue(comRede.descendants(matching: .any)["resultado-confirmada"].waitForExistence(timeout: 10))
        comRede.buttons["voltar-para-lista"].tap()
        let meusTurnos = comRede.tabBars.buttons["Meus turnos"]
        XCTAssertTrue(meusTurnos.waitForExistence(timeout: 10))
        meusTurnos.tap()
        let turnoComRede = comRede.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        XCTAssertTrue(turnoComRede.waitForExistence(timeout: 10))
        // O id do turno novo: o cache em disco pode ter turnos de outros testes, e a fila, ações deles.
        let idDoTurno = turnoComRede.identifier
        turnoComRede.tap()
        XCTAssertTrue(comRede.descendants(matching: .any)["como-chegar-do-turno"].waitForExistence(timeout: 10), "com rede o Como chegar aparece")
        conferirSemContato(comRede)
        let destinoComRede = try destinoDoMapa(comRede)
        comRede.terminate()

        // Sem rede, com o mesmo cache.
        let semRede = XCUIApplication()
        semRede.launchArguments = ["-FRILA_SCENARIO", "sem-rede", "-FRILA_LOCALIZACAO", "perto", "-FRILA_CAPTURAR_URL_UI_TEST"]
        semRede.launch()
        let aba = semRede.tabBars.buttons["Meus turnos"]
        XCTAssertTrue(aba.waitForExistence(timeout: 10))
        aba.tap()
        XCTAssertTrue(semRede.descendants(matching: .any)["aviso-cache-turnos"].waitForExistence(timeout: 10), "a lista vem do cache, com o aviso")
        let turno = semRede.buttons[idDoTurno]
        // O cache em disco conserva turnos de rodadas anteriores; a LazyVStack só cria os cartões
        // fora da tela ao rolar. Procura o mesmo turno, sem escolher outro da lista.
        for _ in 0..<20 where !turno.isHittable {
            semRede.swipeUp()
        }
        XCTAssertTrue(turno.waitForExistence(timeout: Espera.aparecer), "o turno confirmado com rede está no cache")
        turno.tap()
        XCTAssertTrue(semRede.descendants(matching: .any)["tela-meu-turno"].waitForExistence(timeout: 10))
        XCTAssertTrue(semRede.descendants(matching: .any)["como-chegar-do-turno"].waitForExistence(timeout: Espera.aparecer), "o Como chegar do turno confirmado continua na tela sem rede")
        conferirSemContato(semRede)
        XCTAssertEqual(try destinoDoMapa(semRede), destinoComRede, "o cache conserva o endereço do mapa")

        // Sem rede não há o ponto da vaga para medir a distância: o check-in sai manual e vai para a fila.
        let fazerCheckin = semRede.buttons["fazer-checkin"]
        XCTAssertTrue(fazerCheckin.waitForExistence(timeout: 10))
        fazerCheckin.tap()
        XCTAssertTrue(semRede.descendants(matching: .any)["explicacao-localizacao"].waitForExistence(timeout: Espera.aparecer))
        semRede.buttons["permitir-localizacao"].tap()
        let manual = semRede.buttons["registro-manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 10))
        manual.tap()
        let checkin = semRede.descendants(matching: .any)["checkin-situacao"]
        XCTAssertTrue(checkin.waitForExistence(timeout: 10))
        XCTAssertTrue(checkin.label.contains("será enviado quando a internet voltar"), checkin.label)
    }
}
