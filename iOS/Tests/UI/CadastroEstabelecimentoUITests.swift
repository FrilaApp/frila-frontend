import XCTest

@MainActor
final class CadastroEstabelecimentoUITests: XCTestCase {
    func testCadastroSegueParaPublicarVaga() {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Responsável"].exists)
        // Obrigatória desde o contrato 0.2.20: o roteiro de teste já a traz preenchida.
        XCTAssertTrue(app.staticTexts["Região Administrativa"].exists)
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].exists)
        XCTAssertTrue(app.staticTexts["O profissional recebe o valor integral"].exists)
    }

    func testArrastarMarcadorMudaPontoParaDireitaECima() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))

        guard let valorInicial = marcador.value as? String,
              let (latInicial, lonInicial) = extrairCoordenadas(valorInicial) else {
            XCTFail("Não foi possível ler as coordenadas iniciais do marcador: \(String(describing: marcador.value))")
            return
        }

        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        let cameraInicial = try XCTUnwrap(mapa.value as? String)
        XCTAssertEqual(cameraInicial.split(separator: ",").count, 4, "O teste precisa ler o centro e a escala da câmera.")
        XCTAssertGreaterThanOrEqual(marcador.frame.width, 44)
        XCTAssertGreaterThanOrEqual(marcador.frame.height, 44)
        let coordenadaInicial = marcador.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let coordenadaFinal = coordenadaInicial.withOffset(CGVector(dx: 120, dy: -80))
        // XCUICoordinate acompanha o elemento; fixe o destino antes de ele se mover.
        let pontoDeSoltura = coordenadaFinal.screenPoint
        coordenadaInicial.press(forDuration: 0.2, thenDragTo: coordenadaFinal)

        guard let valorFinal = marcador.value as? String,
              let (latFinal, lonFinal) = extrairCoordenadas(valorFinal) else {
            XCTFail("Não foi possível ler as coordenadas finais do marcador: \(String(describing: marcador.value))")
            return
        }

        // A ponta do símbolo é o ponto geográfico, 15 pt abaixo do centro da alça.
        // A tolerância de 12 pt reprova o arrasto que parava no raio de 30 pt.
        let pontaFinal = CGPoint(x: marcador.frame.midX, y: marcador.frame.midY + 15)
        XCTAssertEqual(pontaFinal.x, pontoDeSoltura.x, accuracy: 12)
        XCTAssertEqual(pontaFinal.y, pontoDeSoltura.y, accuracy: 12)
        XCTAssertEqual(mapa.value as? String, cameraInicial, "A câmera deve ficar parada durante o arrasto do marcador.")
        XCTAssertGreaterThan(latFinal, latInicial, "Latitude deve aumentar ao arrastar para cima (Norte). Inicial: \(latInicial), Final: \(latFinal)")
        XCTAssertGreaterThan(lonFinal, lonInicial, "Longitude deve aumentar ao arrastar para a direita (Leste). Inicial: \(lonInicial), Final: \(lonFinal)")
    }

    func testArrastarMapaLongeDoMarcadorNaoMudaPonto() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))

        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))

        guard let valorInicial = marcador.value as? String,
              let (latInicial, lonInicial) = extrairCoordenadas(valorInicial) else {
            XCTFail("Não foi possível ler as coordenadas iniciais do marcador: \(String(describing: marcador.value))")
            return
        }

        let cameraInicial = try XCTUnwrap(mapa.value as? String)
        XCTAssertEqual(cameraInicial.split(separator: ",").count, 4, "O teste precisa ler o centro e a escala da câmera.")
        let pontoLongeInicio = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.15))
        let pontoLongeFim = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35))
        pontoLongeInicio.press(forDuration: 0.1, thenDragTo: pontoLongeFim)

        guard let valorFinal = marcador.value as? String,
              let (latFinal, lonFinal) = extrairCoordenadas(valorFinal) else {
            XCTFail("Não foi possível ler as coordenadas finais do marcador: \(String(describing: marcador.value))")
            return
        }

        XCTAssertNotEqual(mapa.value as? String, cameraInicial, "Arrastar fora do marcador deve mover a câmera.")
        XCTAssertEqual(latFinal, latInicial, accuracy: 0.000001, "Latitude não deve mudar ao arrastar fora do marcador.")
        XCTAssertEqual(lonFinal, lonInicial, accuracy: 0.000001, "Longitude não deve mudar ao arrastar fora do marcador.")

        let cameraAntesDoZoom = try XCTUnwrap(mapa.value as? String)
        let componentesIniciais = cameraAntesDoZoom.split(separator: ",").compactMap { Double($0) }
        guard componentesIniciais.count == 4 else { XCTFail("Câmera sem região antes do zoom."); return }
        mapa.pinch(withScale: 2, velocity: 1)
        let cameraDepoisDoZoom = try XCTUnwrap(mapa.value as? String)
        let componentesFinais = cameraDepoisDoZoom.split(separator: ",").compactMap { Double($0) }
        guard componentesFinais.count == 4 else { XCTFail("Câmera sem região depois do zoom."); return }
        XCTAssertLessThan(componentesFinais[2], componentesIniciais[2], "A pinça deve aproximar o mapa.")
        // O zoom pode tirar o ponto do quadro; reabra a região antes de ler o marcador.
        mapa.pinch(withScale: 0.5, velocity: -1)
        XCTAssertTrue(marcador.waitForExistence(timeout: 5))
        XCTAssertEqual(marcador.value as? String, valorFinal, "O zoom não deve mudar o ponto.")
    }

    func testToqueNoMarcadorNaoMudaPonto() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        let pontoInicial = try XCTUnwrap(marcador.value as? String)
        marcador.tap()
        XCTAssertEqual(marcador.value as? String, pontoInicial, "Tocar sem arrastar deve preservar o ponto do check-in.")
    }

    func testMarcadorForaDoMapaNaoFicaTocavelSobreOFormulario() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        let pontoInicial = try XCTUnwrap(marcador.value as? String)
        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        let cameraInicial = try XCTUnwrap(mapa.value as? String)
        let inicio = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.8))
        let fim = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.15))
        inicio.press(forDuration: 0.1, thenDragTo: fim)

        XCTAssertNotEqual(mapa.value as? String, cameraInicial, "O gesto precisa mover o mapa até o ponto sair do quadro.")
        XCTAssertFalse(marcador.exists, "O marcador deve desaparecer quando o ponto sai do quadro do mapa.")
        XCTAssertFalse(marcador.exists && marcador.isHittable, "O marcador fora do mapa não pode interceptar os campos do formulário.")
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "marcador-fora-do-mapa"
        captura.lifetime = .keepAlways
        add(captura)

        // Reponha o mapa para conferir que esconder o marcador não alterou o ponto.
        fim.press(forDuration: 0.1, thenDragTo: inicio)
        XCTAssertTrue(marcador.waitForExistence(timeout: 5))
        XCTAssertTrue(marcador.isHittable)
        XCTAssertEqual(marcador.value as? String, pontoInicial)
    }

    private func extrairCoordenadas(_ valor: String) -> (Double, Double)? {
        let partes = valor.split(separator: ",")
        guard partes.count == 2,
              let lat = Double(partes[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(partes[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return (lat, lon)
    }
}
