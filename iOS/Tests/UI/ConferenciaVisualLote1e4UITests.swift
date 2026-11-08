import UIKit
import XCTest

/// Lotes 1 e 4 da conferência visual da 1.1: o que dá para provar na tela, com captura anexada.
/// A variável de ambiente `FRILA_CAPTURAS` (opcional) também grava cada captura em PNG nessa pasta.
@MainActor
final class ConferenciaVisualLote1e4UITests: XCTestCase {
    private let botaoChamar = NSPredicate(format: "identifier BEGINSWITH 'chamar-de-novo-'")
    private let carla = "70000000-0000-0000-0000-000000000003"
    private let vagaID = "40000000-0000-0000-0000-000000000001"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Ajudantes

    private func abrir(_ argumentos: [String], escuro: Bool = false, ax3: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos + [escuro ? "-FRILA_MODO_ESCURO" : "-FRILA_MODO_CLARO",
                                            "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-FRILA_SEM_ANIMACOES"]
        if ax3 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launch()
        return app
    }

    @discardableResult
    private func capturar(_ nome: String) -> XCUIScreenshot {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let captura = XCUIScreen.main.screenshot()
        let anexo = XCTAttachment(screenshot: captura)
        anexo.name = nome
        anexo.lifetime = .keepAlways
        add(anexo)
        if let pasta = ProcessInfo.processInfo.environment["FRILA_CAPTURAS"] {
            try? FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
            try? captura.pngRepresentation.write(to: URL(fileURLWithPath: "\(pasta)/\(nome).png"))
        }
        return captura
    }

    private func rolarAte(_ elemento: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<10 {
            if elemento.exists, elemento.isHittable {
                let quadro = elemento.frame
                let altura = app.windows.firstMatch.frame.height
                if quadro.minY > 110 && quadro.maxY < altura - 90 { return }
                if quadro.minY <= 110 { app.swipeDown() } else { app.swipeUp() }
            } else {
                app.swipeUp()
            }
        }
    }

    private func abrirChamada(_ app: XCUIApplication) {
        let chamar = app.buttons.matching(botaoChamar).firstMatch
        XCTAssertTrue(chamar.waitForExistence(timeout: 15), "o botão Chamar de novo da Equipe")
        rolarAte(chamar, app)
        chamar.tap()
        // O Form só cria o botão do fim quando ele entra na tela.
        XCTAssertTrue(app.navigationBars["Chamar de novo"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["total-chamada-centavos"].waitForExistence(timeout: 10))
    }

    private func ligar(_ interruptor: XCUIElement, _ app: XCUIApplication) {
        rolarAte(interruptor, app)
        interruptor.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    /// Há algum ponto colorido (não cinza nem branco) na faixa direita do interruptor?
    private func temCorNoTrilho(_ interruptor: XCUIElement, _ captura: XCUIScreenshot) -> Bool {
        guard let imagem = captura.image.cgImage,
              let dados = imagem.dataProvider?.data, let bytes = CFDataGetBytePtr(dados) else { return false }
        let escala = CGFloat(imagem.width) / captura.image.size.width
        let quadro = interruptor.frame
        let porLinha = imagem.bytesPerRow, porPixel = imagem.bitsPerPixel / 8
        for x in stride(from: quadro.maxX - 80, through: quadro.maxX - 4, by: 2) {
            let px = Int(x * escala), py = Int(quadro.midY * escala)
            guard px >= 0, px < imagem.width, py >= 0, py < imagem.height else { continue }
            let i = py * porLinha + px * porPixel
            let (a, b, c) = (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
            if max(a, b, c) - min(a, b, c) > 80 { return true }
        }
        return false
    }

    // MARK: V6: interruptor ligado no escuro

    func testV6InterruptorLigadoAparecenoEscuro() {
        let app = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "chamada-direta"], escuro: true)
        abrirChamada(app)
        let total = app.switches["confirmar-total-chamada"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertFalse(temCorNoTrilho(total, capturar("V6-chamada-total-desligado-escuro")), "desligado, o trilho é neutro")
        ligar(total, app)
        XCTAssertEqual(total.value as? String, "1")
        XCTAssertTrue(temCorNoTrilho(total, capturar("V6-chamada-total-ligado-escuro")),
                      "ligado, o trilho tem a cor de seleção, e não o branco do tint global")
    }

    func testV6InterruptorLigadoNoEditorDeServicosEscuro() {
        let app = abrir(["-FRILA_SCENARIO", "perfil-rico-habilitado", "-FRILA_ABRIR_PERFIL_PROFISSIONAL"], escuro: true)
        let editar = app.buttons["editar-servicos"]
        XCTAssertTrue(editar.waitForExistence(timeout: 15))
        rolarAte(editar, app)
        editar.tap()
        XCTAssertTrue(app.buttons["salvar-servicos"].waitForExistence(timeout: 10))
        let ligado = app.switches.matching(NSPredicate(format: "value == '1'")).firstMatch
        XCTAssertTrue(ligado.waitForExistence(timeout: 5), "o dublê tem um serviço ligado (Garçom)")
        rolarAte(ligado, app)
        XCTAssertTrue(temCorNoTrilho(ligado, capturar("V6-editar-servicos-escuro")))
    }

    // MARK: V7, V8 e V9: chamada direta

    func testV7V8V9ChamadaDiretaRotulosValorEmReaisEBotaoDesligado() {
        let app = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "chamada-direta"])
        abrirChamada(app)
        // V9: cada campo diz o que é. O rótulo visível fica fora do VoiceOver; o campo o lê.
        XCTAssertEqual(app.textFields["responsavel-chamada"].label, "Responsável no local")
        XCTAssertEqual(app.textFields["total-chamada-centavos"].label, "Valor total")
        capturar("V9-chamada-campos-claro")
        // V7: desligado, o botão diz o que falta.
        let enviar = app.buttons["enviar-chamada"]
        rolarAte(enviar, app)
        XCTAssertTrue(enviar.waitForExistence(timeout: 5))
        XCTAssertFalse(enviar.isEnabled)
        let falta = app.staticTexts["chamada-o-que-falta"]
        XCTAssertTrue(falta.exists)
        XCTAssertEqual(falta.label, "Para enviar, informe o valor total.")
        capturar("V7-V9-chamada-vazia-claro")

        // V8 e RN29: "-500" colado não vira valor negativo nem derruba o app; 180 é R$ 180.
        let valor = app.textFields["total-chamada-centavos"]
        rolarAte(valor, app)
        valor.tap()
        valor.typeText("-500")
        XCTAssertEqual(valor.value as? String, "500")
        XCTAssertEqual(app.state, .runningForeground)
        valor.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        valor.typeText("180")
        XCTAssertEqual(valor.value as? String, "180")
        capturar("V8-valor-180-claro")
        app.toolbars.buttons["OK"].firstMatch.tap()

        rolarAte(enviar, app)
        XCTAssertEqual(falta.label, "Para enviar, confirme que este é o valor total.")
        ligar(app.switches["confirmar-total-chamada"], app)
        rolarAte(enviar, app)
        XCTAssertTrue(enviar.isEnabled)
        XCTAssertFalse(falta.exists)
        capturar("V7-chamada-pronta-claro")
    }

    // MARK: V13 e V14: escolha do candidato

    func testV13V14EscolhaComTextoNeutroESemRepetir() {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "selecao-com-candidatos"])
        let vaga = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        vaga.tap()
        let escolher = app.buttons["escolher-candidato-\(carla)"]
        XCTAssertTrue(escolher.waitForExistence(timeout: 10))
        rolarAte(escolher, app)
        escolher.tap()
        let alerta = app.alerts.firstMatch
        XCTAssertTrue(alerta.waitForExistence(timeout: 5))
        XCTAssertTrue(alerta.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Você vai confirmar Carla Menezes'")).firstMatch.exists)
        capturar("V13-confirmar-escolha-claro")
        alerta.buttons["confirmar-escolha-botao"].firstMatch.tap()
        let resultado = app.descendants(matching: .any)["resultado-da-escolha"]
        XCTAssertTrue(resultado.waitForExistence(timeout: 10))
        XCTAssertTrue(resultado.label.contains("Você confirmou Carla Menezes"), resultado.label)
        XCTAssertFalse(resultado.label.contains("confirmado"), resultado.label)
        capturar("V13-V14-resultado-escolha-claro")
    }

    // MARK: V16, V17 e V18: serviços

    func testV17V18EditorDeServicos() {
        let app = abrir(["-FRILA_SCENARIO", "perfil-rico-habilitado", "-FRILA_ABRIR_PERFIL_PROFISSIONAL"])
        let editar = app.buttons["editar-servicos"]
        XCTAssertTrue(editar.waitForExistence(timeout: 15))
        rolarAte(editar, app)
        XCTAssertTrue(editar.label.contains("Valores, unidade de preço e o que está incluído"), editar.label)
        capturar("V18-funcoes-horarios-claro")
        editar.tap()
        XCTAssertTrue(app.buttons["salvar-servicos"].waitForExistence(timeout: 10))
        // V17: os seletores dizem do que se trata (o rótulo visível fica fora do VoiceOver; o seletor o lê).
        let unidade = app.buttons["unidade-servico"].firstMatch
        XCTAssertTrue(unidade.waitForExistence(timeout: 5))
        XCTAssertTrue(unidade.label.contains("Unidade de preço"), unidade.label)
        capturar("V17-editar-servicos-claro")
        let material = app.buttons["material-servico"].firstMatch
        rolarAte(material, app)
        XCTAssertTrue(material.label.contains("Leva material?"), material.label)
        capturar("V17-editar-servicos-claro-2")
    }

    func testV16ErroDoQueEstaIncluidoComTecladoFechado() {
        let app = abrir(["-FRILA_SCENARIO", "servicos-inclusos-recusados", "-FRILA_ABRIR_PERFIL_PROFISSIONAL"])
        let editar = app.buttons["editar-servicos"]
        XCTAssertTrue(editar.waitForExistence(timeout: 15))
        rolarAte(editar, app)
        editar.tap()
        XCTAssertTrue(app.buttons["salvar-servicos"].waitForExistence(timeout: 10))
        let inclui = app.descendants(matching: .any).matching(identifier: "inclui-servico").firstMatch
        rolarAte(inclui, app)
        inclui.tap()
        inclui.typeText("Texto sintetico para recusa")
        let salvar = app.buttons["salvar-servicos"]
        rolarAte(salvar, app)
        salvar.tap()
        let erro = app.staticTexts["erro-servico-inclui"]
        XCTAssertTrue(erro.waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists, "o Salvar fecha o teclado")
        rolarAte(erro, app)
        XCTAssertTrue(erro.isHittable)
        capturar("V16-erro-inclui-claro")
    }

    // MARK: V19: títulos em AX3

    func testV19TitulosEmAX3() {
        let app = abrir(["-FRILA_SCENARIO", "perfil-rico-habilitado"], ax3: true)
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: 20))
        conta.tap()
        let apresentacao = app.buttons["perfil-apresentacao-regioes"]
        XCTAssertTrue(apresentacao.waitForExistence(timeout: 10))
        rolarAte(apresentacao, app)
        apresentacao.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tela-apresentacao-regioes"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Apresentação e regiões"].waitForExistence(timeout: 5))
        capturar("V19-apresentacao-ax3")
        app.terminate()

        let contratante = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "chamada-direta"], ax3: true)
        XCTAssertTrue(contratante.navigationBars.firstMatch.waitForExistence(timeout: 15))
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        capturar("V19-equipe-ax3")
    }

    // MARK: V20 a V22: telefone e foto

    func testV20TelefoneComMascara() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_ABA_CONTA"])
        let telefone = app.staticTexts["perfil-telefone-valor"]
        XCTAssertTrue(telefone.waitForExistence(timeout: 15))
        XCTAssertEqual(telefone.label, "(61) 98888-7777")
        capturar("V20-telefone-claro")
    }

    func testV21FotoComRecursoDesligado() {
        let app = abrir(["-FRILA_SCENARIO", "foto-recurso-desligado"])
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: 20))
        conta.tap()
        let estado = app.staticTexts["perfil-foto-estado"]
        XCTAssertTrue(estado.waitForExistence(timeout: 10))
        rolarAte(estado, app)
        XCTAssertEqual(estado.label, "Foto guardada")
        capturar("V21-foto-recurso-desligado-claro")
    }

    func testV22AvisoPrevioDaFotoEmAX3() {
        let app = abrir(["-FRILA_SCENARIO", "foto-sem-foto"], ax3: true)
        let conta = app.tabBars.buttons["Conta"]
        XCTAssertTrue(conta.waitForExistence(timeout: 20))
        conta.tap()
        let escolher = app.buttons["perfil-foto-escolher"]
        XCTAssertTrue(escolher.waitForExistence(timeout: 10))
        rolarAte(escolher, app)
        escolher.tap()
        let alerta = app.alerts.firstMatch
        XCTAssertTrue(alerta.waitForExistence(timeout: 5), "o aviso prévio é um alerta, com o fundo escurecido")
        XCTAssertTrue(alerta.buttons["Escolher da galeria"].exists)
        capturar("V22-foto-aviso-previo-ax3")
    }

    // MARK: V23 e V24: contestação

    private func contestar(_ app: XCUIApplication) -> XCUIElement {
        let contestar = app.buttons["botao-contestar-despacho"]
        XCTAssertTrue(contestar.waitForExistence(timeout: 15))
        rolarAte(contestar, app)
        contestar.tap()
        let campo = app.descendants(matching: .any)["campo-relato-despacho"].firstMatch
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.tap()
        campo.typeText("Recebo vagas longe da minha região de trabalho.")
        let enviar = app.buttons["botao-enviar-revisao"]
        rolarAte(enviar, app)
        return enviar
    }

    func testV23ProtocoloCurto() {
        for ax3 in [false, true] {
            let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_ABRIR_POR_QUE_RECEBO_VAGAS"], ax3: ax3)
            tocarFechandoTeclado(contestar(app), em: app)
            let protocolo = app.descendants(matching: .any)["protocolo-revisao-despacho"]
            XCTAssertTrue(protocolo.waitForExistence(timeout: 15))
            XCTAssertTrue(protocolo.label.range(of: #"^#[0-9A-F]{8}$"#, options: .regularExpression) != nil, protocolo.label)
            rolarAte(protocolo, app)
            capturar("V23-protocolo-\(ax3 ? "ax3" : "claro")")
            app.terminate()
        }
    }

    func testV24FormularioDaContestacao() {
        let app = abrir(["-FRILA_SCENARIO", "success", "-FRILA_ABRIR_POR_QUE_RECEBO_VAGAS"])
        let enviar = contestar(app)
        let cancelar = app.buttons.matching(NSPredicate(format: "label == 'Cancelar'")).firstMatch
        XCTAssertGreaterThanOrEqual(cancelar.frame.minY, enviar.frame.maxY - 1, "os botões empilhados")
        capturar("V24-formulario-preenchido-claro")
    }
}
