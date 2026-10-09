import XCTest

/// Auditoria automática de acessibilidade (base do #71): percorre as telas principais dos dois
/// perfis, nos cenários do dublê, e chama `performAccessibilityAudit` em cada uma, no tamanho
/// padrão e em AX5. O relatório tela × problema × causa está em `Docs/Acessibilidade.md`.
///
/// O que a auditoria do XCTest cobre no iOS: contraste, detecção de elemento, área de toque,
/// descrição suficiente, Dynamic Type, texto cortado e traços. Movimento ela não cobre: a passada
/// com Reduzir Movimento é a mesma suíte com a preferência ligada no simulador
/// (`Scripts/auditoria-de-acessibilidade.sh`), e os achados de movimento vêm de leitura do código.
///
/// Três classes de achado não falham o teste, e ficam só registradas no log e no relatório:
/// - contraste: é do design (tokens), e a medição é por pixel, variável com o aparelho;
/// - "texto cortado" em `TextField`: o XCTest olha a flag `adjustsFontForContentSizeCategory`
///   do `UITextField` que o SwiftUI cria, que fica falsa mesmo com a fonte acompanhando o
///   tamanho; a medida do campo em AX5 (`testCampoDeTextoCresceEmAX5`) é a prova;
/// - "alvo pequeno" no link "Legal" do MapKit: controle do sistema, fora do app.
///
/// O que ainda falha por arquivo ocupado por outro PR, ou por decisão de layout que é do design,
/// fica registrado com `XCTExpectFailure` por tela, com o motivo: a CI fica verde e o teste acusa
/// quando a tela for corrigida. É estrito quando o achado aparece em toda rodada, sem depender de
/// rolagem; os demais ficam não estritos, porque o que a auditoria enxerga depende do tamanho da
/// tela e do que está visível no momento.
///
/// A suíte é opcional: só roda com `TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE=1` no ambiente
/// do `xcodebuild test` (é o que `Scripts/auditoria-de-acessibilidade.sh` passa). Na suíte normal
/// e na CI ela é pulada com `XCTSkip`: são 29 casos que abrem o app e auditam duas vezes, cerca de
/// 9 minutos no simulador, e o passo de testes da CI já leva de 42 a 53 dos 70 minutos do job.
///
/// Com `TEST_RUNNER_FRILA_AUDITORIA_SO_REGISTRA=1` a suíte só registra os achados, sem falhar:
/// é o modo usado para levantar o relatório.
@MainActor
final class AuditoriaDeAcessibilidadeUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private static let ligada = ProcessInfo.processInfo.environment["FRILA_AUDITORIA_DE_ACESSIBILIDADE"] == "1"
        || ProcessInfo.processInfo.environment["TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE"] == "1"
    private static let soRegistra = ProcessInfo.processInfo.environment["FRILA_AUDITORIA_SO_REGISTRA"] == "1"
        || ProcessInfo.processInfo.environment["TEST_RUNNER_FRILA_AUDITORIA_SO_REGISTRA"] == "1"

    private let vagaID = "40000000-0000-0000-0000-000000000001"
    private let turnoEncerradoID = "22000000-0000-0000-0000-000000000001"
    private let turnoDoContratanteID = "82000000-0000-0000-0000-000000000001"
    private let posicaoDoContratanteID = "82000000-0000-0000-0000-000000000002"

    private var appAtual: XCUIApplication?
    private var ax5Atual = false
    private var tamanhoAtual: String { ax5Atual ? "ax5" : "padrao" }

    override func setUpWithError() throws {
        try XCTSkipUnless(
            Self.ligada,
            "Auditoria de acessibilidade opcional: rode com TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE=1 ou por Scripts/auditoria-de-acessibilidade.sh (cerca de 9 minutos)"
        )
        continueAfterFailure = true
    }

    override func tearDown() {
        if let appAtual, let testRun, testRun.failureCount > 0 {
            let anexo = XCTAttachment(screenshot: appAtual.screenshot())
            anexo.name = "falha-\(name)"
            anexo.lifetime = .keepAlways
            add(anexo)
        }
        appAtual = nil
        super.tearDown()
    }

    // MARK: - Suporte

    private func abrir(_ argumentos: [String], ax5: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        appAtual = app
        ax5Atual = ax5
        app.launchArguments = argumentos
        if ax5 { app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5] }
        app.launch()
        return app
    }

    private func elemento(_ id: String, em app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// Rola até o elemento ficar tocável e toca. Em AX5 quase tudo sai da primeira tela.
    private func tocar(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 8) {
        for _ in 0..<tentativas where !(elemento.exists && elemento.isHittable) {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(elemento.exists && elemento.isHittable, "\(elemento) não ficou tocável")
        elemento.tap()
    }

    private func esperar(_ elemento: XCUIElement, _ mensagem: String, timeout: TimeInterval = 15) -> Bool {
        let existe = elemento.waitForExistence(timeout: timeout)
        XCTAssertTrue(existe, mensagem)
        return existe
    }

    /// Achado que não falha o teste (veja o cabeçalho), com a classe para o relatório.
    private func classeIgnorada(_ achado: XCUIAccessibilityAuditIssue) -> String? {
        let elemento = achado.element.map { "\($0)" } ?? ""
        switch achado.auditType {
        case .contrast:
            return "design"
        case .textClipped where elemento.contains("TextField"):
            return "falso-positivo-textfield"
        case .hitRegion where achado.detailedDescription.contains("MKAttributionLabel"):
            return "sistema-mapkit"
        default:
            return nil
        }
    }

    /// Roda a auditoria numa tela. Cada achado vira uma linha
    /// `AUDITORIA|tela|tamanho|tipo|classe|descrição|elemento|detalhe` no log, para o relatório.
    private func auditar(_ app: XCUIApplication, tela: String) {
        var linhas: [String] = []
        do {
            try app.performAccessibilityAudit(for: .all) { achado in
                let classe = self.classeIgnorada(achado)
                let elemento = achado.element.map { "\($0)" } ?? "-"
                let detalhe = achado.detailedDescription.replacingOccurrences(of: "\n", with: " ")
                let linha = "AUDITORIA|\(tela)|\(self.tamanhoAtual)|\(achado.auditType.nome)|\(classe ?? "falha")|\(achado.compactDescription)|\(elemento)|\(detalhe)"
                linhas.append(linha)
                print(linha)
                return Self.soRegistra || classe != nil
            }
        } catch {
            XCTFail("A auditoria de \(tela) não rodou: \(error)")
        }
        let anexo = XCTAttachment(string: linhas.isEmpty ? "sem achados" : linhas.joined(separator: "\n"))
        anexo.name = "auditoria-\(tela)-\(tamanhoAtual)"
        anexo.lifetime = .keepAlways
        add(anexo)
    }

    /// Auditoria de tela com achado conhecido e ainda não corrigido: falha esperada, com o motivo.
    private func auditar(_ app: XCUIApplication, tela: String, pendente motivo: String, estrito: Bool = false) {
        if Self.soRegistra { auditar(app, tela: tela); return }
        let opcoes = XCTExpectedFailure.Options()
        opcoes.isStrict = estrito
        XCTExpectFailure("\(tela): \(motivo)", options: opcoes) { auditar(app, tela: tela) }
    }

    private static let cartaoDaVagaLimitadoAAX1 = "o cartão da vaga não acompanha o Dynamic Type além de AX1 por decisão de layout do design (#139): sem o limite a altura passa da tela em AX5 (957 pt de 874); as pílulas de filtro já acompanham até AX5"
    private static let publicarVagaComDatePicker = "o UIDatePicker do sistema não acompanha o Dynamic Type em AX5 (no cadastro) e no tamanho padrão e AX5 (em Minhas vagas) por limitação do UIKit (_UIDatePickerWheelsTimeLabel e botão compacto não alteram tamanho da fonte)"
    private static let porQueReceboVagasBotaoBarra = "o botão Fechar da barra não acompanha o Dynamic Type em PerfisDaConta.swift por desenho do sistema iOS: item de toolbar com Large Content Viewer (accessibilityShowsLargeContentViewer)"
    private static let ajudaDoPerfilAchados = "o botão Fechar da barra não acompanha o Dynamic Type em PerfisDaConta.swift por desenho do sistema iOS: item de toolbar com Large Content Viewer (accessibilityShowsLargeContentViewer)"

    // MARK: - Profissional

    private func entradaCodigoECadastro(ax5: Bool) {
        let app = abrir(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: ax5)

        let email = app.textFields["entrada-email"]
        guard esperar(email, "A entrada deve abrir") else { return }
        auditar(app, tela: "entrada")

        email.tap()
        email.digitarEEsperar("novo@frila.app")
        tocar(app.buttons["entrada-receber-codigo"], em: app)

        let codigo = app.textFields["Código de acesso"]
        guard esperar(codigo, "A tela do código deve abrir") else { return }
        auditar(app, tela: "codigo")

        codigo.tap()
        codigo.typeText("123456")
        tocar(app.buttons["codigo-entrar"], em: app)

        guard esperar(app.buttons["cadastro-maior-de-idade"], "O cadastro deve abrir") else { return }
        auditar(app, tela: "cadastro")
    }

    func testEntradaCodigoECadastro() { entradaCodigoECadastro(ax5: false) }
    func testEntradaCodigoECadastroEmAX5() { entradaCodigoECadastro(ax5: true) }

    /// Prova de que o "texto cortado" que o XCTest aponta em todo `TextField` é falso positivo: o
    /// campo de e-mail cresce com o tamanho do texto. No tamanho padrão ele tem o mínimo de 44 pt.
    func testCampoDeTextoCresceEmAX5() {
        let app = abrir(["-FRILA_ENTRADA", "-FRILA_SCENARIO", "primeiro-acesso"], ax5: true)
        let email = app.textFields["entrada-email"]
        guard esperar(email, "A entrada deve abrir") else { return }
        print("MEDIDA|entrada-email|ax5|altura=\(email.frame.height)")
        XCTAssertGreaterThan(email.frame.height, 44 + 8, "Em AX5 o campo deve crescer além do mínimo de 44 pt")
    }

    private func listaDetalheECandidatura(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "success"], ax5: ax5)

        guard esperar(app.navigationBars["Vagas no DF"], "A lista deve abrir") else { return }
        auditar(app, tela: "vagas", pendente: Self.cartaoDaVagaLimitadoAAX1, estrito: true)

        let primeira = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'vaga-'")).firstMatch
        guard esperar(primeira, "A lista deve ter vaga") else { return }
        primeira.tap()
        guard esperar(elemento("tela-detalhe-vaga", em: app), "O detalhe deve abrir") else { return }
        auditar(app, tela: "detalhe-vaga")

        tocar(app.buttons["candidatar"], em: app)
        guard esperar(elemento("resultado-confirmada", em: app), "A confirmação deve abrir") else { return }
        auditar(app, tela: "candidatura-confirmada")
    }

    func testListaDetalheECandidatura() { listaDetalheECandidatura(ax5: false) }
    func testListaDetalheECandidaturaEmAX5() { listaDetalheECandidatura(ax5: true) }

    private func resultadosDaCandidatura(ax5: Bool) {
        for (cenario, tela, marca) in [
            ("vaga-preenchida", "vaga-preenchida", "resultado-vaga-preenchida"),
            ("vaga-encerrada", "vaga-encerrada", "resultado-vaga-encerrada"),
            ("inelegivel", "conflito-de-horario", "resultado-turno-sobreposto"),
            ("inelegivel-suspenso", "candidatura-conta-suspensa", "resultado-conta-suspensa"),
        ] {
            let app = abrir(["-FRILA_SCENARIO", cenario, "-FRILA_VAGA_ID", vagaID], ax5: ax5)
            guard esperar(app.buttons["candidatar"], "O detalhe de \(cenario) deve abrir") else { continue }
            tocar(app.buttons["candidatar"], em: app)
            guard esperar(elemento(marca, em: app), "O resultado \(marca) deve abrir") else { continue }
            auditar(app, tela: tela)
        }
    }

    func testResultadosDaCandidatura() { resultadosDaCandidatura(ax5: false) }
    func testResultadosDaCandidaturaEmAX5() { resultadosDaCandidatura(ax5: true) }

    private func candidaturasEmSelecao(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "candidatura-pendente"], ax5: ax5)
        guard esperar(app.navigationBars["Vagas no DF"], "A lista deve abrir") else { return }

        let aba = app.tabBars.buttons["Candidaturas"]
        guard esperar(aba, "A aba Candidaturas deve existir") else { return }
        aba.tap()
        guard esperar(elemento("tela-minhas-candidaturas", em: app), "A aba deve abrir") else { return }
        auditar(app, tela: "candidaturas")

        let pendente = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'candidatura-'")).firstMatch
        guard esperar(pendente, "A candidatura pendente deve estar na lista") else { return }
        pendente.tap()
        guard esperar(elemento("candidatura-enviada", em: app), "O detalhe com a candidatura enviada deve abrir") else { return }
        auditar(app, tela: "detalhe-vaga-candidatura-enviada")
    }

    func testCandidaturasEmSelecao() { candidaturasEmSelecao(ax5: false) }
    func testCandidaturasEmSelecaoEmAX5() { candidaturasEmSelecao(ax5: true) }

    private func meusTurnosMeuTurnoEAvaliacao(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "turno-encerrado"], ax5: ax5)
        guard esperar(app.navigationBars["Vagas no DF"], "A lista deve abrir") else { return }

        let aba = app.tabBars.buttons["Meus turnos"]
        guard esperar(aba, "A aba Meus turnos deve existir") else { return }
        aba.tap()
        guard esperar(app.navigationBars["Meus turnos"], "Meus turnos deve abrir") else { return }
        auditar(app, tela: "meus-turnos")

        let turno = app.buttons["meu-turno-\(turnoEncerradoID)"]
        guard esperar(turno, "O turno encerrado deve estar na lista") else { return }
        turno.tap()
        guard esperar(app.navigationBars["Meu turno"], "Meu turno deve abrir") else { return }
        auditar(app, tela: "meu-turno")

        tocar(app.buttons["Avaliar turno"], em: app)
        guard esperar(app.navigationBars["Avaliar turno"], "A avaliação deve abrir") else { return }
        auditar(app, tela: "avaliacao")
    }

    func testMeusTurnosMeuTurnoEAvaliacao() { meusTurnosMeuTurnoEAvaliacao(ax5: false) }
    func testMeusTurnosMeuTurnoEAvaliacaoEmAX5() { meusTurnosMeuTurnoEAvaliacao(ax5: true) }

    private func meuTurnoComPresenca(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "candidatura-escolhida"], ax5: ax5)
        guard esperar(app.navigationBars["Vagas no DF"], "A lista deve abrir") else { return }

        let aba = app.tabBars.buttons["Meus turnos"]
        guard esperar(aba, "A aba Meus turnos deve existir") else { return }
        aba.tap()
        let turno = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meu-turno-'")).firstMatch
        guard esperar(turno, "O turno confirmado deve estar na lista") else { return }
        turno.tap()
        guard esperar(elemento("tela-meu-turno", em: app), "Meu turno deve abrir") else { return }
        auditar(app, tela: "meu-turno-com-presenca")
    }

    func testMeuTurnoComPresenca() { meuTurnoComPresenca(ax5: false) }
    func testMeuTurnoComPresencaEmAX5() { meuTurnoComPresenca(ax5: true) }

    private func turnoComAvisoDeRecusa(ax5: Bool) {
        let app = abrir([
            "-FRILA_SCENARIO", "turno-cancelado",
            "-FRILA_CACHE_VAZIO_UI_TEST",
            "-FRILA_CHECKIN_CANCELADO_NA_FILA_UI_TEST"
        ], ax5: ax5)
        guard esperar(app.navigationBars["Vagas no DF"], "A lista deve abrir") else { return }

        let aba = app.tabBars.buttons["Meus turnos"]
        guard esperar(aba, "A aba Meus turnos deve existir") else { return }
        aba.tap()
        guard esperar(app.navigationBars["Meus turnos"], "Meus turnos deve abrir") else { return }

        let turno = app.buttons["meu-turno-\(turnoEncerradoID)"]
        guard esperar(turno, "O turno cancelado deve estar na lista") else { return }
        turno.tap()
        guard esperar(app.navigationBars["Meu turno"], "Meu turno deve abrir") else { return }
        guard esperar(elemento("aviso-acao-recusada-checkin", em: app), "O aviso de recusa deve aparecer") else { return }
        guard esperar(app.buttons["fechar-aviso-acao-recusada-checkin"], "O botão Fechar da recusa deve existir") else { return }

        auditar(app, tela: "meu-turno-aviso-recusa")
    }

    func testTurnoComAvisoDeRecusa() { turnoComAvisoDeRecusa(ax5: false) }
    func testTurnoComAvisoDeRecusaEmAX5() { turnoComAvisoDeRecusa(ax5: true) }

    private func perfilEExclusaoDeConta(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "success"], ax5: ax5)
        let perfil = app.buttons["abrir-meu-perfil"]
        guard esperar(perfil, "O botão do perfil deve existir") else { return }
        perfil.tap()
        guard esperar(app.buttons["perfil-excluir-conta"], "O perfil deve abrir") else { return }
        auditar(app, tela: "perfil-profissional")

        tocar(app.buttons["perfil-funcoes-horarios"], em: app)
        guard esperar(elemento("picker-dia-semana", em: app), "Funções e horários deve abrir") else { return }
        auditar(app, tela: "perfil-funcoes-e-horarios")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tocar(app.buttons["perfil-excluir-conta"], em: app)
        guard esperar(elemento("tela-exclusao-de-conta", em: app), "A exclusão deve abrir") else { return }
        auditar(app, tela: "exclusao-de-conta")
    }

    func testPerfilEExclusaoDeConta() { perfilEExclusaoDeConta(ax5: false) }
    func testPerfilEExclusaoDeContaEmAX5() { perfilEExclusaoDeConta(ax5: true) }

    private func contaSuspensa(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "conta-suspensa"], ax5: ax5)
        guard esperar(elemento("tela-conta-suspensa", em: app), "A conta suspensa deve abrir") else { return }
        auditar(app, tela: "conta-suspensa")
    }

    func testContaSuspensa() { contaSuspensa(ax5: false) }
    func testContaSuspensaEmAX5() { contaSuspensa(ax5: true) }

    private func historicoDeTurnos(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "success"], ax5: ax5)
        let perfil = app.buttons["abrir-meu-perfil"]
        guard esperar(perfil, "O botão do perfil deve existir") else { return }
        perfil.tap()

        let entrada = app.buttons["perfil-historico-turnos"]
        guard esperar(entrada, "O item de histórico de turnos deve existir") else { return }
        tocar(entrada, em: app)

        guard esperar(app.buttons["historico-exportar"], "O histórico deve abrir") else { return }
        auditar(app, tela: "historico-turnos")
    }

    func testHistoricoDeTurnos() { historicoDeTurnos(ax5: false) }
    func testHistoricoDeTurnosEmAX5() { historicoDeTurnos(ax5: true) }

    private func confirmacaoDeExclusaoDeConta(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "success"], ax5: ax5)
        let perfil = app.buttons["abrir-meu-perfil"]
        guard esperar(perfil, "O botão do perfil deve existir") else { return }
        perfil.tap()

        let irParaExclusao = app.buttons["perfil-excluir-conta"]
        guard esperar(irParaExclusao, "O item de exclusão de conta deve existir") else { return }
        tocar(irParaExclusao, em: app)
        guard esperar(elemento("tela-exclusao-de-conta", em: app), "A exclusão de conta deve abrir") else { return }

        let toggle = app.switches["toggle-confirmar-consequencias"]
        guard esperar(toggle, "O interruptor de consequências deve existir") else { return }
        for _ in 0..<10 where !toggle.isHittable { app.swipeUp(velocity: .fast) }
        let interruptor = toggle.switches.firstMatch
        let alvo = interruptor.exists ? interruptor : toggle
        tocar(alvo, em: app)

        let botaoExcluir = app.buttons["botao-excluir-conta-definitivo"]
        guard esperar(botaoExcluir, "O botão de exclusão definitiva deve existir") else { return }
        let habilitado = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: botaoExcluir)
        _ = XCTWaiter.wait(for: [habilitado], timeout: 5)
        tocar(botaoExcluir, em: app, tentativas: 10)

        let cancelar = app.buttons["botao-cancelar-exclusao-dialogo"]
        guard esperar(cancelar, "A confirmação de exclusão deve abrir") else { return }
        auditar(app, tela: "confirmacao-exclusao-de-conta")
    }

    func testConfirmacaoDeExclusaoDeConta() { confirmacaoDeExclusaoDeConta(ax5: false) }
    func testConfirmacaoDeExclusaoDeContaEmAX5() { confirmacaoDeExclusaoDeConta(ax5: true) }

    private func porQueReceboVagas(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "success"], ax5: ax5)
        let perfil = app.buttons["abrir-meu-perfil"]
        guard esperar(perfil, "O botão do perfil deve existir") else { return }
        perfil.tap()

        let botao = app.buttons["perfil-por-que-recebo"]
        guard esperar(botao, "O botão Por que recebo vagas deve existir") else { return }
        tocar(botao, em: app)

        guard esperar(elemento("tela-por-que-recebo", em: app), "A tela Por que recebo vagas deve abrir") else { return }
        auditar(app, tela: "por-que-recebo-vagas", pendente: Self.porQueReceboVagasBotaoBarra, estrito: true)
    }

    func testPorQueReceboVagas() { porQueReceboVagas(ax5: false) }
    func testPorQueReceboVagasEmAX5() { porQueReceboVagas(ax5: true) }

    private func ajudaDoPerfil(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "success"], ax5: ax5)
        let perfil = app.buttons["abrir-meu-perfil"]
        guard esperar(perfil, "O botão do perfil deve existir") else { return }
        perfil.tap()

        let botaoAjuda = app.buttons["perfil-ajuda"]
        guard esperar(botaoAjuda, "O botão Ajuda deve existir") else { return }
        tocar(botaoAjuda, em: app)

        guard esperar(elemento("perfil-suporte", em: app), "A tela de ajuda deve abrir") else { return }
        auditar(app, tela: "ajuda-perfil", pendente: Self.ajudaDoPerfilAchados, estrito: true)
    }

    func testAjudaDoPerfil() { ajudaDoPerfil(ax5: false) }
    func testAjudaDoPerfilEmAX5() { ajudaDoPerfil(ax5: true) }

    // MARK: - Catálogo

    private func licencasEDetalhe(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_CATALOGO", "-FRILA_SCENARIO", "success"], ax5: ax5)
        guard esperar(app.navigationBars["Frila UI"], "O catálogo deve abrir") else { return }

        let entrada = app.buttons["abrir-licencas"]
        guard esperar(entrada, "O botão de licenças deve existir no catálogo") else { return }
        let janela = app.windows.firstMatch
        for _ in 0..<12 {
            if entrada.exists && entrada.isHittable && janela.frame.contains(entrada.frame) { break }
            app.swipeUp(velocity: .fast)
        }
        tocar(entrada, em: app, tentativas: 12)

        guard esperar(app.navigationBars["Licenças de código aberto"], "A lista de licenças deve abrir") else { return }
        auditar(app, tela: "licencas")

        let pacote = app.buttons["licenca-abseil-cpp-binary"]
        guard esperar(pacote, "O item da licença deve existir") else { return }
        tocar(pacote, em: app)

        guard esperar(elemento("texto-da-licenca", em: app), "O detalhe da licença deve abrir") else { return }
        auditar(app, tela: "detalhe-licenca")
    }

    func testLicencasEDetalhe() { licencasEDetalhe(ax5: false) }
    func testLicencasEDetalheEmAX5() { licencasEDetalhe(ax5: true) }

    // MARK: - Contratante

    private func cadastroDoEstabelecimentoEPublicarVaga(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO", "-FRILA_CADASTRO_UI_TEST"], ax5: ax5)
        guard esperar(app.staticTexts["Cadastrar estabelecimento"], "O cadastro deve abrir") else { return }
        auditar(app, tela: "cadastro-estabelecimento")

        tocar(app.buttons["continuar-cadastro"], em: app)
        guard esperar(app.staticTexts["Publicar vaga"], "Publicar vaga deve abrir") else { return }
        if ax5 {
            auditar(app, tela: "publicar-vaga", pendente: Self.publicarVagaComDatePicker, estrito: true)
        } else {
            auditar(app, tela: "publicar-vaga")
        }

        tocar(app.buttons["mais-opcoes-botao"], em: app)
        guard esperar(elemento("observacoes-vaga-campo", em: app), "Mais opções deve abrir") else { return }
        let botaoPublicar = app.buttons["publicar-vaga-botao"]
        for _ in 0..<8 where !botaoPublicar.isHittable {
            app.swipeUp(velocity: .fast)
        }
        let estacionado = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: botaoPublicar
        )
        _ = XCTWaiter.wait(for: [estacionado], timeout: 5)
        auditar(app, tela: "publicar-vaga-mais-opcoes")
    }

    func testCadastroDoEstabelecimentoEPublicarVaga() { cadastroDoEstabelecimentoEPublicarVaga(ax5: false) }
    func testCadastroDoEstabelecimentoEPublicarVagaEmAX5() { cadastroDoEstabelecimentoEPublicarVaga(ax5: true) }

    private func minhasVagasDetalheEPerfilPublico(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "painel-contratante"], ax5: ax5)
        guard esperar(app.navigationBars["Minhas vagas"], "Minhas vagas deve abrir") else { return }
        auditar(app, tela: "minhas-vagas")

        tocar(app.buttons["vaga-contratante-\(vagaID)"], em: app)
        guard esperar(elemento("detalhe-vaga-contratante", em: app), "O detalhe deve abrir") else { return }
        auditar(app, tela: "detalhe-vaga-contratante")

        tocar(app.buttons["ver-contato-\(posicaoDoContratanteID)"], em: app)
        guard esperar(elemento("contato-liberado-\(turnoDoContratanteID)", em: app), "O contato deve aparecer") else { return }
        auditar(app, tela: "detalhe-vaga-contratante-com-contato")

        tocar(app.buttons["perfil-publico-\(posicaoDoContratanteID)"], em: app)
        guard esperar(app.navigationBars["Perfil público"], "O perfil público deve abrir") else { return }
        auditar(app, tela: "perfil-publico")
    }

    func testMinhasVagasDetalheEPerfilPublico() { minhasVagasDetalheEPerfilPublico(ax5: false) }
    func testMinhasVagasDetalheEPerfilPublicoEmAX5() { minhasVagasDetalheEPerfilPublico(ax5: true) }

    private func republicarVaga(ax5: Bool) {
        let app = abrir(["-FRILA_ABRIR_MINHAS_VAGAS", "-FRILA_SCENARIO", "vaga-encerrada-contratante"], ax5: ax5)
        guard esperar(app.navigationBars["Minhas vagas"], "Minhas vagas deve abrir") else { return }
        auditar(app, tela: "minhas-vagas-encerradas")

        let republicar = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'republicar-vaga-'")).firstMatch
        tocar(republicar, em: app)
        guard esperar(elemento("tela-republicar-vaga", em: app), "Republicar deve abrir") else { return }
        auditar(app, tela: "republicar-vaga")
    }

    func testRepublicarVaga() { republicarVaga(ax5: false) }
    func testRepublicarVagaEmAX5() { republicarVaga(ax5: true) }

    private func auditarMinhasVagas(_ app: XCUIApplication, tela: String, ax5: Bool) {
        auditar(app, tela: tela)
    }

    private func acompanhamentoDoTurno(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "checkin-manual-pendente"], ax5: ax5)
        guard esperar(elemento("presencas-a-confirmar", em: app), "Minhas vagas com presença a confirmar deve abrir") else { return }
        auditarMinhasVagas(app, tela: "minhas-vagas-presenca-a-confirmar", ax5: ax5)

        tocar(app.buttons["acompanhar-turno-\(turnoDoContratanteID)"], em: app)
        guard esperar(elemento("turno-do-contratante", em: app), "O acompanhamento deve abrir") else { return }
        auditar(app, tela: "acompanhamento-do-turno")
    }

    func testAcompanhamentoDoTurno() { acompanhamentoDoTurno(ax5: false) }
    func testAcompanhamentoDoTurnoEmAX5() { acompanhamentoDoTurno(ax5: true) }

    private func turnoEmAtraso(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "atraso-no-turno"], ax5: ax5)
        let reabrir = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'reabrir-vaga-'")).firstMatch
        guard esperar(reabrir, "Minhas vagas com turno em atraso deve abrir") else { return }
        auditarMinhasVagas(app, tela: "minhas-vagas-turno-em-atraso", ax5: ax5)
    }

    func testTurnoEmAtraso() { turnoEmAtraso(ax5: false) }
    func testTurnoEmAtrasoEmAX5() { turnoEmAtraso(ax5: true) }

    private func perfilDoEstabelecimento(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "contratante"], ax5: ax5)
        let perfil = app.buttons["abrir-perfil-estabelecimento"]
        guard esperar(perfil, "O botão do perfil do estabelecimento deve existir") else { return }
        perfil.tap()
        guard esperar(app.buttons["estabelecimento-excluir-conta"], "O perfil do estabelecimento deve abrir") else { return }
        auditar(app, tela: "perfil-estabelecimento")
    }

    func testPerfilDoEstabelecimento() { perfilDoEstabelecimento(ax5: false) }
    func testPerfilDoEstabelecimentoEmAX5() { perfilDoEstabelecimento(ax5: true) }

    private func equipeDeConfianca(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "equipe-de-confianca-com-membro"], ax5: ax5)
        let perfil = app.buttons["abrir-perfil-estabelecimento"]
        guard esperar(perfil, "O botão do perfil do estabelecimento deve existir") else { return }
        perfil.tap()

        let equipe = app.buttons["estabelecimento-equipe-de-confianca"]
        guard esperar(equipe, "O botão Equipe de confiança deve existir") else { return }
        tocar(equipe, em: app)

        guard esperar(elemento("tela-equipe-de-confianca", em: app), "A equipe de confiança deve abrir") else { return }
        auditar(app, tela: "equipe-de-confianca")
    }

    func testEquipeDeConfianca() { equipeDeConfianca(ax5: false) }
    func testEquipeDeConfiancaEmAX5() { equipeDeConfianca(ax5: true) }

    private func publicarVagaEmMinhasVagas(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "contratante"], ax5: ax5)
        guard esperar(app.navigationBars["Minhas vagas"], "Minhas vagas deve abrir") else { return }

        let entrada = app.buttons["publicar-vaga-entrada"]
        guard esperar(entrada, "O botão Publicar vaga deve existir") else { return }
        tocar(entrada, em: app)
        guard esperar(elemento("publicar-vaga-formulario", em: app), "O formulário de publicar vaga deve abrir") else { return }

        auditar(app, tela: "publicar-vaga-em-minhas-vagas", pendente: Self.publicarVagaComDatePicker, estrito: true)
    }

    func testPublicarVagaEmMinhasVagas() { publicarVagaEmMinhasVagas(ax5: false) }
    func testPublicarVagaEmMinhasVagasEmAX5() { publicarVagaEmMinhasVagas(ax5: true) }

    private func publicarVagaErroAoLerCasa(ax5: Bool) {
        let app = abrir(["-FRILA_SCENARIO", "erro-ao-ler-meu-estabelecimento"], ax5: ax5)
        guard esperar(app.navigationBars["Minhas vagas"], "Minhas vagas deve abrir") else { return }

        let entrada = app.buttons["publicar-vaga-entrada"]
        guard esperar(entrada, "O botão Publicar vaga deve existir") else { return }
        tocar(entrada, em: app)
        guard esperar(elemento("publicar-vaga-erro", em: app), "A tela de erro ao publicar deve abrir") else { return }

        auditar(app, tela: "publicar-vaga-erro")
    }

    func testPublicarVagaErroAoLerCasa() { publicarVagaErroAoLerCasa(ax5: false) }
    func testPublicarVagaErroAoLerCasaEmAX5() { publicarVagaErroAoLerCasa(ax5: true) }
}

private extension XCUIAccessibilityAuditType {
    var nome: String {
        switch self {
        case .contrast: "contraste"
        case .elementDetection: "deteccao"
        case .hitRegion: "alvo"
        case .sufficientElementDescription: "rotulo"
        case .dynamicType: "dynamic-type"
        case .textClipped: "texto-cortado"
        case .trait: "traco"
        default: "outro(\(rawValue))"
        }
    }
}
