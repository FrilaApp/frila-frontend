import XCTest

@MainActor
final class CadastroEstabelecimentoUITests: XCTestCase {
    private func abrir(argumentos: [String] = ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += argumentos
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: Espera.aparecer)
        return app
    }

    func testCadastroSegueParaPublicarVaga() {
        let app = abrir()

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Responsável"].exists)
        // Obrigatória desde o contrato 0.2.20: o roteiro de teste já a traz preenchida.
        XCTAssertTrue(app.staticTexts["Região Administrativa"].exists)
        tocar(app.buttons["continuar-cadastro"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))
        XCTAssertTrue(app.descendants(matching: .any)["publicar-vaga-formulario"].exists)
    }

    func testArrastarMarcadorMudaPontoParaDireitaECima() throws {
        let app = abrir()

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        XCTAssertEqual(marcador.label, "Ponto do estabelecimento")

        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertEqual(mapa.label, "Mapa do estabelecimento")

        // Espera a câmera assentar com região válida (4 componentes) antes de iniciar o gesto.
        let cameraPronta = NSPredicate { _, _ in (mapa.value as? String)?.split(separator: ",").count == 4 }
        let expectativaCamera = XCTNSPredicateExpectation(predicate: cameraPronta, object: mapa)
        XCTAssertEqual(XCTWaiter.wait(for: [expectativaCamera], timeout: Espera.aparecer), .completed, "A câmera deve assentar antes do arrasto.")

        guard let valorInicial = marcador.value as? String,
              let (latInicial, lonInicial) = extrairCoordenadas(valorInicial) else {
            XCTFail("Não foi possível ler as coordenadas iniciais do marcador: \(String(describing: marcador.value))")
            return
        }
        let cameraInicial = try XCTUnwrap(mapa.value as? String)
        XCTAssertEqual(cameraInicial.split(separator: ",").count, 4, "O teste precisa ler o centro e a escala da câmera.")
        XCTAssertAlvoMinimo(marcador.frame.width)
        XCTAssertAlvoMinimo(marcador.frame.height)

        let frameInicial = marcador.frame
        let pontoInicial = CGPoint(x: frameInicial.midX, y: frameInicial.midY)
        let pontoDeSoltura = CGPoint(x: pontoInicial.x + 120, y: pontoInicial.y - 40)
        let referenciaEstatica = app.coordinate(withNormalizedOffset: .zero)
        let coordenadaInicial = referenciaEstatica.withOffset(CGVector(dx: pontoInicial.x, dy: pontoInicial.y))
        let coordenadaFinal = referenciaEstatica.withOffset(CGVector(dx: pontoDeSoltura.x, dy: pontoDeSoltura.y))

        // Segura 0.2s no destino para que o despachador processe todos os eventos de movimento antes da soltura.
        coordenadaInicial.press(forDuration: 0.2, thenDragTo: coordenadaFinal, withVelocity: .default, thenHoldForDuration: 0.2)

        // Espera a condição: marcador visível, valor geográfico atualizado e ponta do marcador no destino dentro da tolerância.
        let marcadorNoDestino = NSPredicate { _, _ in
            guard marcador.exists else { return false }
            guard let valorAtual = marcador.value as? String, valorAtual != valorInicial else { return false }
            let ponta = CGPoint(x: marcador.frame.midX, y: marcador.frame.midY + 15)
            return abs(ponta.x - pontoDeSoltura.x) <= 12 && abs(ponta.y - pontoDeSoltura.y) <= 12
        }
        let expectativaMarcador = XCTNSPredicateExpectation(predicate: marcadorNoDestino, object: marcador)
        XCTAssertEqual(XCTWaiter.wait(for: [expectativaMarcador], timeout: Espera.aparecer), .completed, "O marcador deve atualizar as coordenadas e assentar no destino do arrasto.")

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
        XCTAssertEqual(dyReal, -40, accuracy: 12, "Deslocamento vertical relativo deve ser -40 pt")

        // A tolerância de 12 pt reprova o arrasto que parava no raio de 30 pt.
        XCTAssertEqual(pontaFinal.x, pontoDeSoltura.x, accuracy: 12)
        XCTAssertEqual(pontaFinal.y, pontoDeSoltura.y, accuracy: 12)
        XCTAssertEqual(mapa.value as? String, cameraInicial, "A câmera deve ficar parada durante o arrasto do marcador.")
        XCTAssertGreaterThan(latFinal, latInicial, "Latitude deve aumentar ao arrastar para cima (Norte). Inicial: \(latInicial), Final: \(latFinal)")
        XCTAssertGreaterThan(lonFinal, lonInicial, "Longitude deve aumentar ao arrastar para a direita (Leste). Inicial: \(lonInicial), Final: \(lonFinal)")
    }

    func testArrastarMapaLongeDoMarcadorNaoMudaPonto() throws {
        let app = abrir()

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))

        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))
        app.swipeUp()

        // Espera a câmera assentar com região válida (4 componentes) antes de iniciar o gesto.
        let cameraPronta = NSPredicate { _, _ in (mapa.value as? String)?.split(separator: ",").count == 4 }
        let expectativaCamera = XCTNSPredicateExpectation(predicate: cameraPronta, object: mapa)
        XCTAssertEqual(XCTWaiter.wait(for: [expectativaCamera], timeout: Espera.aparecer), .completed, "A câmera deve assentar antes do arrasto.")

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
        mapa.pinch(withScale: 1.5, velocity: 1)
        let cameraDepoisDoZoom = try XCTUnwrap(mapa.value as? String)
        let componentesFinais = cameraDepoisDoZoom.split(separator: ",").compactMap { Double($0) }
        guard componentesFinais.count == 4 else { XCTFail("Câmera sem região depois do zoom."); return }
        XCTAssertLessThan(componentesFinais[2], componentesIniciais[2], "A pinça deve aproximar o mapa.")
        // O zoom pode tirar o ponto do quadro; reabra a região antes de ler o marcador.
        mapa.pinch(withScale: 0.7, velocity: -1)
        XCTAssertTrue(marcador.waitForExistence(timeout: Espera.aparecer))
        XCTAssertEqual(marcador.value as? String, valorFinal, "O zoom não deve mudar o ponto.")
    }

    func testToqueNoMarcadorNaoMudaPonto() throws {
        let app = abrir()

        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))
        app.swipeUp()
        let cameraPronta = NSPredicate { _, _ in (mapa.value as? String)?.split(separator: ",").count == 4 }
        let expectativaCamera = XCTNSPredicateExpectation(predicate: cameraPronta, object: mapa)
        XCTAssertEqual(XCTWaiter.wait(for: [expectativaCamera], timeout: Espera.aparecer), .completed, "A região da câmera deve estar carregada antes do toque.")

        let pontoInicial = try XCTUnwrap(marcador.value as? String)
        tocar(marcador)
        XCTAssertEqual(marcador.value as? String, pontoInicial, "Tocar sem arrastar deve preservar o ponto do check-in.")
    }

    func testMarcadorForaDoMapaNaoFicaTocavelSobreOFormulario() throws {
        let app = abrir()

        let marcador = app.descendants(matching: .any)["marcador-mapa"]
        XCTAssertTrue(marcador.waitForExistence(timeout: 10))
        let pontoInicial = try XCTUnwrap(marcador.value as? String)
        let mapa = app.descendants(matching: .any)["mapa-estabelecimento"]
        XCTAssertTrue(mapa.waitForExistence(timeout: 10))
        app.swipeUp()

        // Espera a câmera assentar com região válida (4 componentes) antes de iniciar o gesto.
        let cameraPronta = NSPredicate { _, _ in (mapa.value as? String)?.split(separator: ",").count == 4 }
        let expectativaCamera = XCTNSPredicateExpectation(predicate: cameraPronta, object: mapa)
        XCTAssertEqual(XCTWaiter.wait(for: [expectativaCamera], timeout: Espera.aparecer), .completed, "A câmera deve assentar antes do arrasto.")

        let cameraInicial = try XCTUnwrap(mapa.value as? String)
        let inicio = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let fim = mapa.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
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
        XCTAssertTrue(marcador.waitForExistence(timeout: Espera.aparecer))
        XCTAssertTrue(marcador.isHittable)
        XCTAssertEqual(marcador.value as? String, pontoInicial)
    }

    func testPublicarVagaEmAccessibilityXXXLControlesDentroDaTelaETocaveis() throws {
        throw XCTSkip("Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)")
        let app = abrir(argumentos: [
            "-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO",
            "-FRILA_CADASTRO_UI_TEST",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        tocar(app.buttons["continuar-cadastro"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))

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

            if !nao.isHittable { trazerParaATela(nao, em: app) }
            let quadroNao = nao.frame
            XCTAssertLessThanOrEqual(quadroNao.maxX, larguraTela, "Botão Não[\(indice)] extrapolou a tela: maxX=\(quadroNao.maxX) > largura=\(larguraTela)")
            XCTAssertGreaterThanOrEqual(quadroNao.minX, 0, "Botão Não[\(indice)] fora da tela à esquerda: minX=\(quadroNao.minX)")
            XCTAssertTrue(nao.isHittable, "Botão Não[\(indice)] deve ser tocável")
        }

        let dpInicio = app.descendants(matching: .any)["datepicker-inicio"]
        if dpInicio.exists {
            if !dpInicio.isHittable { trazerParaATela(dpInicio, em: app) }
            XCTAssertLessThanOrEqual(dpInicio.frame.maxX, larguraTela, "DatePicker Início em XXXL extrapolou a tela")
            XCTAssertGreaterThanOrEqual(dpInicio.frame.minX, 0, "DatePicker Início em XXXL fora à esquerda")
        }

        let dpFim = app.descendants(matching: .any)["datepicker-fim"]
        if dpFim.exists {
            if !dpFim.isHittable { trazerParaATela(dpFim, em: app) }
            XCTAssertLessThanOrEqual(dpFim.frame.maxX, larguraTela, "DatePicker Fim em XXXL extrapolou a tela")
            XCTAssertGreaterThanOrEqual(dpFim.frame.minX, 0, "DatePicker Fim em XXXL fora à esquerda")
        }

        let botaoPublicar = app.buttons["publicar-vaga-botao"]
        XCTAssertTrue(botaoPublicar.exists)
        if !botaoPublicar.isHittable { trazerParaATela(botaoPublicar, em: app) }
        XCTAssertTrue(botaoPublicar.isHittable)
        XCTAssertLessThanOrEqual(botaoPublicar.frame.maxX, larguraTela)
    }

    func testDatePickersContidosNaLarguraDaTelaNoTamanhoPadrao() {
        let app = abrir()

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        tocar(app.buttons["continuar-cadastro"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))

        let larguraTela = app.windows.firstMatch.frame.width

        let dpInicio = app.descendants(matching: .any)["datepicker-inicio"]
        XCTAssertTrue(dpInicio.waitForExistence(timeout: Espera.aparecer))
        trazerParaATela(dpInicio, em: app)
        XCTAssertGreaterThanOrEqual(dpInicio.frame.minX, 16, "DatePicker Início fora da margem esquerda: \(dpInicio.frame.minX) < 16")
        XCTAssertLessThanOrEqual(dpInicio.frame.maxX, larguraTela - 16, "DatePicker Início extrapolou a margem direita: \(dpInicio.frame.maxX) > \(larguraTela - 16)")

        let dpFim = app.descendants(matching: .any)["datepicker-fim"]
        XCTAssertTrue(dpFim.waitForExistence(timeout: Espera.aparecer))
        trazerParaATela(dpFim, em: app)
        XCTAssertGreaterThanOrEqual(dpFim.frame.minX, 16, "DatePicker Fim fora da margem esquerda: \(dpFim.frame.minX) < 16")
        XCTAssertLessThanOrEqual(dpFim.frame.maxX, larguraTela - 16, "DatePicker Fim extrapolou a margem direita: \(dpFim.frame.maxX) > \(larguraTela - 16)")
    }

    private func trazerParaATela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 12) {
        if elemento.isHittable { return }
        let janela = app.windows.firstMatch
        let quadroJanela = janela.frame
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
                alturaJanela: quadroJanela.height,
                margemSuperior: margemSuperior,
                margemInferior: margemInferior,
                isHittable: elemento.isHittable
            )
            switch direcao {
            case .nenhuma:
                return
            case .rolarParaBaixo:
                app.swipeDown()
            case .rolarParaCima:
                // Em AX5 os DatePickers usam .wheel (largura 320 pt), que intercepta toques verticais no centro
                // da tela (dx: 0.5) girando a roda em vez de rolar a ScrollView. Rolar pela margem direita (dx: 0.90)
                // evita o seletor em roda e atinge diretamente a ScrollView.
                let inicio = janela.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.85))
                let fim = janela.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.15))
                inicio.press(forDuration: 0.01, thenDragTo: fim)
            }
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

    func testCapturasCadastroEstabelecimentoUX03() {
        let app = abrir()

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        let seletorRA = app.buttons["regiao-administrativa"]
        XCTAssertTrue(seletorRA.waitForExistence(timeout: 10))

        for _ in 0..<5 where !seletorRA.isHittable {
            app.swipeUp()
        }
        app.swipeUp()
        XCTAssertTrue(seletorRA.isHittable)
        salvarCaptura("01-cadastro-estabelecimento-padrao")

        tocar(app.buttons["continuar-cadastro"])
        XCTAssertTrue(esperarFormularioDePublicarVaga(app))
        salvarCaptura("03-tela-vizinha-publicar-vaga")
    }

    func testCapturaCadastroEstabelecimentoXXXL() throws {
        throw XCTSkip("Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)")
        let app = abrir(argumentos: [
            "-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO",
            "-FRILA_CADASTRO_UI_TEST",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])

        XCTAssertTrue(app.staticTexts["Dados do negócio"].waitForExistence(timeout: 10))
        salvarCaptura("04-cadastro-estabelecimento-topo-xxxl")

        let seletorRA = app.buttons["regiao-administrativa"]
        XCTAssertTrue(seletorRA.waitForExistence(timeout: 10))

        for _ in 0..<5 where !seletorRA.isHittable {
            app.swipeUp()
        }
        app.swipeUp()
        XCTAssertTrue(seletorRA.isHittable)
        salvarCaptura("02-cadastro-estabelecimento-xxxl")
    }

    func testMascaraDocumentoCPFECNPJNoTamanhoPadrao() {
        conferirMascaraDocumento(categoria: "UICTContentSizeCategoryL", sufixo: "padrao")
    }

    func testMascaraDocumentoCPFECNPJNoMaiorTextoAX5() {
        conferirMascaraDocumento(categoria: "UICTContentSizeCategoryAccessibilityXXXL", sufixo: "ax5")
    }

    private func conferirMascaraDocumento(categoria: String?, sufixo: String) {
        for (digitos, esperado, nome) in [("12345678901", "123.456.789-01", "cpf"), ("12345678000199", "12.345.678/0001-99", "cnpj")] {
            var argumentos = ["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO"]
            if let categoria { argumentos += ["-UIPreferredContentSizeCategoryName", categoria] }
            let app = abrir(argumentos: argumentos)
            defer { app.terminate() }
            let campo = app.textFields["CNPJ ou CPF"]
            XCTAssertTrue(campo.waitForExistence(timeout: Espera.aparecer))
            // Em AX5 o campo pode ficar só parcialmente visível (isHittable já é verdadeiro) e o toque no
            // centro cai fora da janela: rola até o campo caber inteiro.
            let janela = app.windows.firstMatch.frame
            for _ in 0..<4 where !campo.isHittable || campo.frame.maxY > janela.maxY { app.swipeUp() }
            campo.tap()
            campo.typeText(digitos)
            XCTAssertEqual(campo.value as? String, esperado)
            salvarCaptura("mascara-\(nome)-\(sufixo)")
        }
    }

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
}

