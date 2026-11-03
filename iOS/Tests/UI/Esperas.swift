import Foundation
import XCTest

enum Espera {
    // Folga para a consulta da árvore de acessibilidade na CI sem deixar os testes mais lentos.
    static let aparecer: TimeInterval = 10
}

/// Toca em um elemento de UI garantindo que ele exista e esteja interagível antes do toque.
func tocar(_ elemento: XCUIElement, timeout: TimeInterval = Espera.aparecer, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(elemento.waitForExistence(timeout: timeout), file: file, line: line)
    if !elemento.isHittable || !elemento.isEnabled {
        let pronto = NSPredicate(format: "hittable == true AND enabled == true")
        let espera = XCTNSPredicateExpectation(predicate: pronto, object: elemento)
        _ = XCTWaiter.wait(for: [espera], timeout: timeout)
    }
    elemento.tap()
}

/// Toca em um botão quando um campo pode estar com o teclado aberto.
///
/// O escopo de fechamento do teclado (`frilaKeyboardDismissScope`, M21, decisão Q3) consome o primeiro
/// toque fora do campo focado só para fechar o teclado: o botão não age. Foi o que derrubou 66 testes
/// de interface depois do #650 (a Entrada não abria a tela do código). Aqui o primeiro toque fecha o
/// teclado e, se a tela continuou a mesma, o segundo toque aciona o botão, como a pessoa faria.
func tocarFechandoTeclado(_ elemento: XCUIElement, em app: XCUIApplication, timeout: TimeInterval = Espera.aparecer, file: StaticString = #filePath, line: UInt = #line) {
    let teclado = app.keyboards.firstMatch
    let estavaAberto = teclado.exists
    tocar(elemento, timeout: timeout, file: file, line: line)
    guard estavaAberto else { return }
    let sumiu = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: teclado)
    guard XCTWaiter.wait(for: [sumiu], timeout: 3) == .completed else { return }
    // Folga para uma transição de tela iniciada pelo primeiro toque terminar antes de decidir.
    let saiu = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: elemento)
    guard XCTWaiter.wait(for: [saiu], timeout: 1) != .completed else { return }
    if elemento.isHittable && elemento.isEnabled {
        elemento.tap()
    }
}

extension XCUIElement {
    /// Garante o foco do teclado antes de digitar. Com o teclado de outro campo aberto, o escopo de
    /// fechamento (M21, decisão Q3) consome o toque no campo seguinte só para fechar o teclado, e o
    /// `typeText` falharia com "Neither element nor any descendant has keyboard focus". Toca de novo.
    func garantirFocoDoTeclado(file: StaticString = #filePath, line: UInt = #line) {
        guard !esperarFocoDoTeclado(self, timeout: 1) else { return }
        for _ in 0..<2 {
            if isHittable { tap() }
            if esperarFocoDoTeclado(self, timeout: 2) { return }
        }
    }
}

/// Fecha o teclado numérico pela barra "Ok" que o `CampoMascara` põe acima dele desde o #650. A barra
/// aumenta o teclado em 44 pt e cobre o que vem logo abaixo do campo (Termos, no cadastro), e o arraste
/// não o recolhe. Devolve `true` quando o teclado fechou.
@discardableResult
func fecharTecladoPeloOk(_ app: XCUIApplication) -> Bool {
    let teclado = app.keyboards.firstMatch
    guard teclado.exists else { return true }
    let ok = app.toolbars.buttons.matching(NSPredicate(format: "label ==[c] %@", "ok")).firstMatch
    guard ok.exists, ok.isHittable else { return false }
    ok.tap()
    let sumiu = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: teclado)
    return XCTWaiter.wait(for: [sumiu], timeout: 2) == .completed
}

/// O formulário de publicar vaga (o Estúdio de Criação) na tela. A barra do Estúdio mostra
/// "Publicar vaga, etapa n de 3" no lugar do título "Nova vaga" do formulário antigo.
@discardableResult
func esperarFormularioDePublicarVaga(_ app: XCUIApplication, timeout: TimeInterval = Espera.aparecer) -> Bool {
    app.descendants(matching: .any)["publicar-vaga-formulario"].waitForExistence(timeout: timeout)
}

/// O Estúdio celebra a vaga publicada antes de seguir: concluir a celebração leva o fluxo adiante.
func concluirCelebracao(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    tocar(app.buttons["celebracao-concluir"], file: file, line: line)
}

/// Escolhe o valor por turno pelos atalhos do estúdio (R$ 100, 120, 140, 160 e 200): a régua do SwiftUI
/// não obedece ao `adjust(toNormalizedSliderPosition:)` do XCUITest, e os atalhos são o caminho que a
/// origem oferece. O texto do valor vem do `pt_BR` (espaço inseparável depois de "R$").
///
/// Com o teclado do campo anterior aberto, o atalho existe mas fica coberto (na CI: "Failed to not
/// hittable: Button 'R$ 160'"), e nenhum swipe o descobre. Por isso o teclado fecha primeiro e a
/// rolagem é pelo quadro do atalho, sem laço cego nem toque repetido.
func ajustarValorPorTurno(_ app: XCUIApplication, para valor: Int, file: StaticString = #filePath, line: UInt = #line) {
    fecharTeclado(app)
    let atalho = app.buttons.matching(textoDeDinheiro(valor)).firstMatch
    XCTAssertTrue(atalho.waitForExistence(timeout: Espera.aparecer), "o atalho R$ \(valor) deve existir", file: file, line: line)
    trazerParaAJanela(atalho, em: app)
    atalho.tap()
    let mostrado = app.staticTexts.matching(textoDeDinheiro(valor)).firstMatch
    XCTAssertTrue(mostrado.waitForExistence(timeout: Espera.aparecer), "o estúdio deveria mostrar R$ \(valor)", file: file, line: line)
}

/// Fecha o teclado se ele estiver aberto: Return encerra a edição do campo de texto focado; se o
/// teclado continuar (campo sem Return), a rolagem interativa do estúdio o recolhe.
func fecharTeclado(_ app: XCUIApplication) {
    let teclado = app.keyboards.firstMatch
    guard teclado.exists else { return }
    app.typeText("\n")
    let sumiu = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: teclado)
    if XCTWaiter.wait(for: [sumiu], timeout: 2) != .completed {
        app.swipeDown(velocity: .slow)
        _ = XCTWaiter.wait(for: [sumiu], timeout: 2)
    }
}

/// Traz o elemento para a área tocável. O Estúdio alinha a rolagem ao topo da seção
/// (`FrilaLPEJobFormSectionPagingBehavior`): uma faixa fixa de altura nunca é atingida, e o laço
/// antigo oscilava dez vezes entre "alto demais" e "baixo demais" (2,5 s cada no simulador, três
/// vezes por teste). Aqui basta o elemento ser tocável, e a rolagem para quando o quadro não se move.
func trazerParaAJanela(_ elemento: XCUIElement, em app: XCUIApplication, tentativas: Int = 4) {
    let janela = app.windows.firstMatch.frame
    var anterior = CGRect.null
    for _ in 0..<tentativas {
        guard elemento.exists else {
            app.swipeUp(velocity: .slow)
            continue
        }
        if elemento.isHittable { return }
        let quadro = elemento.frame
        if quadro.equalTo(anterior) { return }
        anterior = quadro
        if quadro.midY < janela.midY {
            app.swipeDown(velocity: .slow)
        } else {
            app.swipeUp(velocity: .slow)
        }
    }
}

/// "R$ 180" como o `pt_BR` escreve (com espaço inseparável) ou com espaço comum,
/// além do rótulo fonético do VoiceOver ("180 reais por turno/hora") e do identificador do preset.
func textoDeDinheiro(_ valor: Int) -> NSPredicate {
    NSPredicate(
        format: "label == %@ OR label == %@ OR label BEGINSWITH %@ OR identifier == %@",
        "R$\u{00A0}\(valor)",
        "R$ \(valor)",
        "\(valor) reais",
        "preset-valor-\(valor)"
    )
}

/// Verdadeiro se há um texto na tela com o valor em reais.
func mostraDinheiro(_ app: XCUIApplication, _ valor: Int) -> Bool {
    app.staticTexts.matching(textoDeDinheiro(valor)).firstMatch.exists
}

/// Substitui o texto de um campo: foca (até três toques, pois o estúdio reorganiza o formulário quando o
/// teclado sobe), apaga o que há e digita o novo.
func substituirTexto(_ campo: XCUIElement, por texto: String, file: StaticString = #filePath, line: UInt = #line) {
    var focado = false
    for _ in 0..<3 where !focado {
        campo.tap()
        focado = esperarFocoDoTeclado(campo, timeout: 2)
    }
    XCTAssertTrue(focado, "o campo deveria receber o foco do teclado", file: file, line: line)
    guard focado else { return }
    // O toque no meio do campo cai depois do fim de um texto curto, e o cursor fica no fim.
    let atual = (campo.value as? String) ?? ""
    if !atual.isEmpty {
        campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: atual.count))
    }
    campo.digitarEEsperar(texto, file: file, line: line)
}

/// Aguarda até que o elemento obtenha foco do teclado (`hasKeyboardFocus`).
@discardableResult
func esperarFocoDoTeclado(_ elemento: XCUIElement, timeout: TimeInterval = Espera.aparecer) -> Bool {
    let predicado = NSPredicate(format: "hasKeyboardFocus == true")
    let espera = XCTNSPredicateExpectation(predicate: predicado, object: elemento)
    return XCTWaiter.wait(for: [espera], timeout: timeout) == .completed
}

/// Aguarda até que o estado de habilitação (`isEnabled`) do elemento seja o esperado.
@discardableResult
func esperarHabilitado(_ elemento: XCUIElement, _ habilitado: Bool = true, timeout: TimeInterval = Espera.aparecer) -> Bool {
    let predicado = NSPredicate(format: "isEnabled == %@", NSNumber(value: habilitado))
    let espera = XCTNSPredicateExpectation(predicate: predicado, object: elemento)
    return XCTWaiter.wait(for: [espera], timeout: timeout) == .completed
}

/// Aguarda até que o estado de seleção (`isSelected`) do elemento seja o esperado.
@discardableResult
func esperarSelecionado(_ elemento: XCUIElement, _ selecionado: Bool = true, timeout: TimeInterval = Espera.aparecer) -> Bool {
    let predicado = NSPredicate(format: "isSelected == %@", NSNumber(value: selecionado))
    let espera = XCTNSPredicateExpectation(predicate: predicado, object: elemento)
    return XCTWaiter.wait(for: [espera], timeout: timeout) == .completed
}

/// Aguarda a estabilização do frame do elemento (cessar momentum de rolagem).
func esperarEstabilizacaoDeFrame(_ elemento: XCUIElement, timeout: TimeInterval = 2.0) {
    let predicado = NSPredicate(format: "isHittable == true")
    let espera = XCTNSPredicateExpectation(predicate: predicado, object: elemento)
    _ = XCTWaiter.wait(for: [espera], timeout: timeout)
}

