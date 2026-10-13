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
