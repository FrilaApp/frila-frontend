import XCTest

@MainActor
final class DetalheVagaBarraInferiorUITests: XCTestCase {

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

    private func abrirDetalhe(horario: String, modoEscuro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-FRILA_SCENARIO", "success",
            "-FRILA_VAGA_ID", "40000000-0000-0000-0000-000000000001",
            "-FRILA_HORARIO_VAGA", horario
        ]
        if modoEscuro {
            args.append("-FRILA_MODO_ESCURO")
        } else {
            args.append("-FRILA_MODO_CLARO")
        }
        app.launchArguments = args
        app.launch()
        let detalhe = app.descendants(matching: .any)["tela-detalhe-vaga"]
        XCTAssertTrue(detalhe.waitForExistence(timeout: Espera.aparecer), "A tela de detalhe da vaga deve abrir")
        return app
    }

    private func abrirFeed(modoEscuro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-FRILA_SCENARIO", "success"]
        if modoEscuro {
            args.append("-FRILA_MODO_ESCURO")
        } else {
            args.append("-FRILA_MODO_CLARO")
        }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.navigationBars["Vagas no DF"].waitForExistence(timeout: Espera.aparecer), "O feed de vagas deve abrir")
        return app
    }

    func testCapturaAmanha23h30Claro() {
        let app = abrirDetalhe(horario: "amanha-23h30", modoEscuro: false)
        salvarCaptura("01-detalhe-amanha-23h30-claro")
        let botao = app.buttons["candidatar"]
        XCTAssertTrue(botao.waitForExistence(timeout: 5))
        XCTAssertEqual(botao.frame.width, app.frame.width - 32, accuracy: 2, "O botão ocupa toda a largura útil da barra")
        XCTAssertEqual(botao.frame.midX, app.frame.midX, accuracy: 1, "O botão fica centralizado abaixo do valor")
    }

    func testCapturaAmanha23h30Escuro() {
        let app = abrirDetalhe(horario: "amanha-23h30", modoEscuro: true)
        salvarCaptura("02-detalhe-amanha-23h30-escuro")
        let botao = app.buttons["candidatar"]
        XCTAssertTrue(botao.waitForExistence(timeout: 5))
        XCTAssertEqual(botao.frame.width, app.frame.width - 32, accuracy: 2, "O botão ocupa toda a largura útil da barra")
        XCTAssertEqual(botao.frame.midX, app.frame.midX, accuracy: 1, "O botão fica centralizado abaixo do valor")
    }

    func testCapturaHoje18hClaro() {
        let app = abrirDetalhe(horario: "hoje-18h", modoEscuro: false)
        salvarCaptura("03-detalhe-hoje-18h-claro")
        let botao = app.buttons["candidatar"]
        XCTAssertTrue(botao.waitForExistence(timeout: 5))
        XCTAssertEqual(botao.frame.width, app.frame.width - 32, accuracy: 2, "O botão ocupa toda a largura útil da barra")
        XCTAssertEqual(botao.frame.midX, app.frame.midX, accuracy: 1, "O botão fica centralizado abaixo do valor")
    }

    func testCapturaHoje18hEscuro() {
        let app = abrirDetalhe(horario: "hoje-18h", modoEscuro: true)
        salvarCaptura("04-detalhe-hoje-18h-escuro")
        let botao = app.buttons["candidatar"]
        XCTAssertTrue(botao.waitForExistence(timeout: 5))
        XCTAssertEqual(botao.frame.width, app.frame.width - 32, accuracy: 2, "O botão ocupa toda a largura útil da barra")
        XCTAssertEqual(botao.frame.midX, app.frame.midX, accuracy: 1, "O botão fica centralizado abaixo do valor")
    }

    func testCapturaVizinhaFeedClaro() {
        _ = abrirFeed(modoEscuro: false)
        salvarCaptura("05-feed-vizinha-claro")
    }

    func testCapturaVizinhaFeedEscuro() {
        _ = abrirFeed(modoEscuro: true)
        salvarCaptura("06-feed-vizinha-escuro")
    }
}
