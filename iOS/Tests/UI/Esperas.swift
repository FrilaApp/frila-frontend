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
func ajustarValorPorTurno(_ app: XCUIApplication, para valor: Int, file: StaticString = #filePath, line: UInt = #line) {
    let atalho = app.buttons.matching(textoDeDinheiro(valor)).firstMatch
    for _ in 0..<10 where !atalho.isHittable { app.swipeUp(velocity: .slow) }
    XCTAssertTrue(atalho.waitForExistence(timeout: Espera.aparecer), "o atalho R$ \(valor) deve existir", file: file, line: line)
    // Com o teclado aberto, o primeiro toque fora do campo só fecha o teclado; o segundo chega ao atalho.
    let mostrado = app.staticTexts.matching(textoDeDinheiro(valor)).firstMatch
    for _ in 0..<2 where !mostrado.exists {
        atalho.tap()
        _ = mostrado.waitForExistence(timeout: 2)
    }
    XCTAssertTrue(mostrado.exists, "o estúdio deveria mostrar R$ \(valor)", file: file, line: line)
}

/// "R$ 180" como o `pt_BR` escreve (com espaço inseparável) ou com espaço comum.
func textoDeDinheiro(_ valor: Int) -> NSPredicate {
    NSPredicate(format: "label == %@ OR label == %@", "R$\u{00A0}\(valor)", "R$ \(valor)")
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

