import XCTest

/// Varredura final da 1.1: a denúncia da foto pelo perfil público (A1, 0.2.54, CD-RF12) e o
/// "Chamar de novo" a partir da Equipe de confiança (A6, CD-RF07), no dublê.
@MainActor
final class VarreduraFinal11UITests: XCTestCase {
    private let vagaID = "40000000-0000-0000-0000-000000000001"
    private let bruno = "70000000-0000-0000-0000-000000000002"
    private let carla = "70000000-0000-0000-0000-000000000003"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func abrir(_ argumentos: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = argumentos
        AjudanteDeLancamentoUITests.preparar(app)
        app.launch()
        return app
    }

    /// Rola até o elemento ficar tocável, longe da barra de navegação e da borda de baixo.
    private func rolarAte(_ elemento: XCUIElement, em app: XCUIApplication) {
        let altura = app.windows.firstMatch.frame.height
        for _ in 0..<10 {
            if elemento.exists, elemento.isHittable, elemento.frame.minY > 100, elemento.frame.maxY < altura - 40 { return }
            if elemento.exists, elemento.frame.minY <= 100 { app.swipeDown() } else { app.swipeUp() }
        }
    }

    private func abrirPerfilDoCandidato(_ id: String, em app: XCUIApplication) {
        let vaga = app.buttons["vaga-contratante-\(vagaID)"]
        XCTAssertTrue(vaga.waitForExistence(timeout: 15))
        vaga.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detalhe-vaga-contratante"].waitForExistence(timeout: 10))
        let perfil = app.buttons["perfil-do-candidato-\(id)"]
        rolarAte(perfil, em: app)
        perfil.tap()
        XCTAssertTrue(app.descendants(matching: .any)["perfil-publico-contratante"].waitForExistence(timeout: 10))
    }

    func testDenunciaDaFotoPeloPerfilPublicoEnviaComProtocolo() {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "denuncia-de-foto"])
        abrirPerfilDoCandidato(bruno, em: app)

        let denunciar = app.buttons["denunciar"]
        rolarAte(denunciar, em: app)
        denunciar.tap()

        let sobreAFoto = app.switches["denuncia-sobre-foto"]
        XCTAssertTrue(sobreAFoto.waitForExistence(timeout: 10), "com foto no perfil, a folha oferece denunciar a foto")
        XCTAssertEqual(sobreAFoto.value as? String, "0", "a denúncia começa sobre o perfil")
        sobreAFoto.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(sobreAFoto.value as? String, "1")

        let relato = app.descendants(matching: .any)["relato-denuncia"].firstMatch
        relato.tap()
        relato.typeText("A foto mostra uma chave Pix.")
        if app.buttons["recolher-teclado"].exists { app.buttons["recolher-teclado"].tap() }
        app.buttons["enviar-denuncia"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["protocolo-denuncia"].waitForExistence(timeout: 10), "a denúncia da foto devolve protocolo")
    }

    func testPerfilSemFotoNaoOfereceDenunciarAFoto() {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "denuncia-de-foto"])
        abrirPerfilDoCandidato(carla, em: app)

        let denunciar = app.buttons["denunciar"]
        rolarAte(denunciar, em: app)
        denunciar.tap()

        XCTAssertTrue(app.descendants(matching: .any)["relato-denuncia"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["denuncia-sobre-foto"].exists, "sem foto, a denúncia é só sobre o perfil")
    }

    func testChamarDeNovoPelaEquipeAbreOFormularioDaChamada() {
        let app = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "chamada-direta"])
        let chamar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chamar-de-novo-'")).firstMatch
        XCTAssertTrue(chamar.waitForExistence(timeout: 15), "com a chamada direta ligada, cada pessoa da equipe tem Chamar de novo")
        rolarAte(chamar, em: app)
        chamar.tap()

        XCTAssertTrue(app.navigationBars["Chamar de novo"].waitForExistence(timeout: 10), "Chamar de novo abre o formulário da chamada")
        // O botão fica no fim do formulário: a lista só cria a linha quando ela aparece.
        let enviar = app.buttons["enviar-chamada"]
        for _ in 0..<6 where !enviar.exists { app.swipeUp() }
        XCTAssertTrue(enviar.waitForExistence(timeout: 5), "o formulário termina em Enviar chamada")
        XCTAssertFalse(enviar.isEnabled, "sem valor e sem o total confirmado, a chamada não sai")
        let total = app.switches["confirmar-total-chamada"]
        for _ in 0..<4 where !total.exists { app.swipeDown() }
        XCTAssertTrue(total.exists, "o total fechado é confirmado a cada chamada")
    }

    func testEquipeSemChamadaDiretaNaoOfereceChamarDeNovo() {
        let app = abrir(["-FRILA_ABRIR_EQUIPE_CONFIANCA", "-FRILA_SCENARIO", "equipe-de-confianca-com-membro"])
        let remover = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'remover-da-equipe-'")).firstMatch
        XCTAssertTrue(remover.waitForExistence(timeout: 15), "a equipe carregou com a pessoa")
        let chamar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chamar-de-novo-'")).firstMatch
        XCTAssertFalse(chamar.waitForExistence(timeout: 3), "com a chave desligada, a equipe não oferece Chamar de novo")
    }
}
