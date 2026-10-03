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
        let btnPerfil = app.buttons["Perfil do estabelecimento"]
        XCTAssertTrue(btnPerfil.waitForExistence(timeout: 5))
        btnPerfil.tap()

        let btnFechar = app.buttons["Fechar"]
        XCTAssertTrue(btnFechar.waitForExistence(timeout: 5))
        btnFechar.tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 5))
    }

    func testArrastarMarcadorMudaPontoParaDireitaECima() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        XCTAssertEqual(marcador.label, "Ponto do estabelecimento")

        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))
        XCTAssertEqual(mapa.label, "Mapa do estabelecimento")

        // Espera a câmera assentar com região válida (4 componentes) antes de iniciar o gesto.
        let cameraPronta = NSPredicate { _, _ in (mapa.value as? String)?.split(separator: ",").count == 4 }
        let expectativaCamera = XCTNSPredicateExpectation(predicate: cameraPronta, object: mapa)
        XCTAssertEqual(XCTWaiter.wait(for: [expectativaCamera], timeout: 5), .completed, "A câmera deve assentar antes do arrasto.")

        guard let valorInicial = marcador.value as? String,
              let (latInicial, lonInicial) = extrairCoordenadas(valorInicial) else {
            XCTFail("Não foi possível ler as coordenadas iniciais do marcador: \(String(describing: marcador.value))")
            return
        }
        let cameraInicial = try XCTUnwrap(mapa.value as? String)
        XCTAssertEqual(cameraInicial.split(separator: ",").count, 4, "O teste precisa ler o centro e a escala da câmera.")
        XCTAssertGreaterThanOrEqual(marcador.frame.width, 44)
        XCTAssertGreaterThanOrEqual(marcador.frame.height, 44)

        let coordenadaInicial = marcador.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let pontoInicial = coordenadaInicial.screenPoint
        let coordenadaFinal = coordenadaInicial.withOffset(CGVector(dx: 120, dy: -80))
        let pontoDeSoltura = coordenadaFinal.screenPoint

        // Segura 0.2s no destino para que o despachador processe todos os eventos de movimento antes da soltura.
        coordenadaInicial.press(forDuration: 0.2, thenDragTo: coordenadaFinal, withVelocity: .default, thenHoldForDuration: 0.2)

        // Espera a condição: marcador parado com coordenadas atualizadas após o arrasto.
        let marcadorMoveu = NSPredicate { _, _ in (marcador.value as? String) != valorInicial }
        let expectativaMarcador = XCTNSPredicateExpectation(predicate: marcadorMoveu, object: marcador)
        XCTAssertEqual(XCTWaiter.wait(for: [expectativaMarcador], timeout: 5), .completed, "O marcador deve atualizar as coordenadas após o arrasto.")

        guard let valorFinal = marcador.value as? String,
              let (latFinal, lonFinal) = extrairCoordenadas(valorFinal) else {
            XCTFail("Não foi possível ler as coordenadas finais do marcador: \(String(describing: marcador.value))")
            return
        }

        // A ponta do símbolo é o ponto geográfico, 15 pt abaixo do centro da alça.
        let pontaFinal = CGPoint(x: marcador.frame.midX, y: marcador.frame.midY + 15)

        // Medição do deslocamento relativo da ponta do marcador a partir do ponto de partida lido na hora.
        let dxReal = pontaFinal.x - pontoInicial.x
        let dyReal = pontaFinal.y - pontoInicial.y
        XCTAssertEqual(dxReal, 120, accuracy: 12, "Deslocamento horizontal relativo deve ser 120 pt")
        XCTAssertEqual(dyReal, -80, accuracy: 12, "Deslocamento vertical relativo deve ser -80 pt")

        // A tolerância de 12 pt reprova o arrasto que parava no raio de 30 pt.
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

    func testPublicarVagaEmAccessibilityXXXLControlesDentroDaTelaETocaveis() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO",
            "-FRILA_CADASTRO_UI_TEST",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))

        let larguraTela = app.windows.firstMatch.frame.width

        let botoesSim = app.descendants(matching: .button).allElementsBoundByIndex.filter { $0.label == "Sim" }
        XCTAssertEqual(botoesSim.count, 3, "Devem existir 3 seletores com botão Sim (refeição, transporte, material)")
        let botoesNao = app.descendants(matching: .button).allElementsBoundByIndex.filter { $0.label == "Não" }
        XCTAssertEqual(botoesNao.count, 3, "Devem existir 3 seletores com botão Não (refeição, transporte, material)")

        for indice in 0..<3 {
            let sim = botoesSim[indice]
            let nao = botoesNao[indice]
            trazerParaATela(sim, em: app)
            let quadroSim = sim.frame
            XCTAssertLessThanOrEqual(quadroSim.maxX, larguraTela, "Botão Sim[\(indice)] extrapolou a tela: maxX=\(quadroSim.maxX) > largura=\(larguraTela)")
            XCTAssertGreaterThanOrEqual(quadroSim.minX, 0, "Botão Sim[\(indice)] fora da tela à esquerda: minX=\(quadroSim.minX)")
            XCTAssertTrue(sim.isHittable, "Botão Sim[\(indice)] deve ser tocável")

            trazerParaATela(nao, em: app)
            let quadroNao = nao.frame
            XCTAssertLessThanOrEqual(quadroNao.maxX, larguraTela, "Botão Não[\(indice)] extrapolou a tela: maxX=\(quadroNao.maxX) > largura=\(larguraTela)")
            XCTAssertGreaterThanOrEqual(quadroNao.minX, 0, "Botão Não[\(indice)] fora da tela à esquerda: minX=\(quadroNao.minX)")
            XCTAssertTrue(nao.isHittable, "Botão Não[\(indice)] deve ser tocável")
        }

        let dpInicio = app.descendants(matching: .any)["datepicker-inicio"]
        if dpInicio.exists {
            trazerParaATela(dpInicio, em: app)
            XCTAssertLessThanOrEqual(dpInicio.frame.maxX, larguraTela, "DatePicker Início em XXXL extrapolou a tela")
            XCTAssertGreaterThanOrEqual(dpInicio.frame.minX, 0, "DatePicker Início em XXXL fora à esquerda")
        }

        let dpFim = app.descendants(matching: .any)["datepicker-fim"]
        if dpFim.exists {
            trazerParaATela(dpFim, em: app)
            XCTAssertLessThanOrEqual(dpFim.frame.maxX, larguraTela, "DatePicker Fim em XXXL extrapolou a tela")
            XCTAssertGreaterThanOrEqual(dpFim.frame.minX, 0, "DatePicker Fim em XXXL fora à esquerda")
        }

        let botaoPublicar = app.buttons["publicar-vaga-botao"]
        XCTAssertTrue(botaoPublicar.exists)
        trazerParaATela(botaoPublicar, em: app)
        XCTAssertTrue(botaoPublicar.isHittable)
        XCTAssertLessThanOrEqual(botaoPublicar.frame.maxX, larguraTela)
    }

    func testDatePickersContidosNaLarguraDaTelaNoTamanhoPadrao() {
        let app = XCUIApplication()
        app.launchArguments += ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadastrar estabelecimento"].waitForExistence(timeout: 10))
        app.buttons["continuar-cadastro"].tap()
        XCTAssertTrue(app.staticTexts["Publicar vaga"].waitForExistence(timeout: 10))

        let larguraTela = app.windows.firstMatch.frame.width

        let dpInicio = app.descendants(matching: .any)["datepicker-inicio"]
        XCTAssertTrue(dpInicio.waitForExistence(timeout: 5))
        trazerParaATela(dpInicio, em: app)
        XCTAssertGreaterThanOrEqual(dpInicio.frame.minX, 16, "DatePicker Início fora da margem esquerda: \(dpInicio.frame.minX) < 16")
        XCTAssertLessThanOrEqual(dpInicio.frame.maxX, larguraTela - 16, "DatePicker Início extrapolou a margem direita: \(dpInicio.frame.maxX) > \(larguraTela - 16)")

        let dpFim = app.descendants(matching: .any)["datepicker-fim"]
        XCTAssertTrue(dpFim.waitForExistence(timeout: 5))
        trazerParaATela(dpFim, em: app)
        XCTAssertGreaterThanOrEqual(dpFim.frame.minX, 16, "DatePicker Fim fora da margem esquerda: \(dpFim.frame.minX) < 16")
        XCTAssertLessThanOrEqual(dpFim.frame.maxX, larguraTela - 16, "DatePicker Fim extrapolou a margem direita: \(dpFim.frame.maxX) > \(larguraTela - 16)")
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 8) {
        let janela = app.windows.firstMatch.frame
        let margemSuperior: CGFloat = 120
        let margemInferior: CGFloat = 60

        for _ in 0..<tentativas {
            guard elemento.exists else {
                app.swipeUp()
                continue
            }
            let quadro = elemento.frame
            let direcao = direcaoParaTrazerParaATela(
                quadro: quadro,
                alturaJanela: janela.height,
                margemSuperior: margemSuperior,
                margemInferior: margemInferior,
                isHittable: elemento.isHittable
            )
            switch direcao {
            case .nenhuma:
                break
            case .rolarParaBaixo:
                app.swipeDown()
            case .rolarParaCima:
                app.swipeUp()
            }
            if direcao == .nenhuma { break }
        }
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

