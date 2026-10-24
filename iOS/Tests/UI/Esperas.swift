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

/// Ajusta o valor por turno na régua do Estúdio (R$ 80 a R$ 300, passo 10) e confere o valor mostrado.
/// Quando o arrasto erra um passo, corrige pela porcentagem que a régua informa.
func ajustarValorPorTurno(_ app: XCUIApplication, para valor: Int, file: StaticString = #filePath, line: UInt = #line) {
    let regua = app.sliders["valor-vaga-campo"]
    XCTAssertTrue(regua.waitForExistence(timeout: Espera.aparecer), "a régua de valor deve existir", file: file, line: line)
    let mostrado = app.staticTexts["R$ \(valor)"]
    var posicao = CGFloat(valor - 80) / 220
    for _ in 0..<4 {
        regua.adjust(toNormalizedSliderPosition: posicao)
        if mostrado.waitForExistence(timeout: 1) { return }
        guard let texto = regua.value as? String,
              let porcentagem = Double(texto.filter { $0.isNumber || $0 == "." || $0 == "," }.replacingOccurrences(of: ",", with: ".")) else { break }
        let atual = 80 + porcentagem / 100 * 220
        posicao += CGFloat((Double(valor) - atual) / 220)
    }
    XCTAssertTrue(mostrado.exists, "a régua deveria mostrar R$ \(valor)", file: file, line: line)
}

/// Substitui o texto de um campo: leva o cursor ao fim, apaga o que há e digita o novo.
func substituirTexto(_ campo: XCUIElement, por texto: String, file: StaticString = #filePath, line: UInt = #line) {
    campo.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    _ = esperarFocoDoTeclado(campo)
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

