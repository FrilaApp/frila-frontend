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

    func testArrastarMarcadorMudaPontoParaDireitaECima() {
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

        let coordenadaInicial = marcador.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let coordenadaFinal = coordenadaInicial.withOffset(CGVector(dx: 60, dy: -40))
        coordenadaInicial.press(forDuration: 0.2, thenDragTo: coordenadaFinal)

        guard let valorFinal = marcador.value as? String,
              let (latFinal, lonFinal) = extrairCoordenadas(valorFinal) else {
            XCTFail("Não foi possível ler as coordenadas finais do marcador: \(String(describing: marcador.value))")
            return
        }

        XCTAssertGreaterThan(latFinal, latInicial, "Latitude deve aumentar ao arrastar para cima (Norte). Inicial: \(latInicial), Final: \(latFinal)")
        XCTAssertGreaterThan(lonFinal, lonInicial, "Longitude deve aumentar ao arrastar para a direita (Leste). Inicial: \(lonInicial), Final: \(lonFinal)")
    }

    func testArrastarMapaLongeDoMarcadorNaoMudaPonto() {
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

        let pontoLongeInicio = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.15))
        let pontoLongeFim = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35))
        pontoLongeInicio.press(forDuration: 0.1, thenDragTo: pontoLongeFim)

        guard let valorFinal = marcador.value as? String,
              let (latFinal, lonFinal) = extrairCoordenadas(valorFinal) else {
            XCTFail("Não foi possível ler as coordenadas finais do marcador: \(String(describing: marcador.value))")
            return
        }

        XCTAssertEqual(latFinal, latInicial, accuracy: 0.000001, "Latitude não deve mudar ao arrastar fora do marcador.")
        XCTAssertEqual(lonFinal, lonInicial, accuracy: 0.000001, "Longitude não deve mudar ao arrastar fora do marcador.")
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
