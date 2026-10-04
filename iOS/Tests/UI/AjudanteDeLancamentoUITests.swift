import XCTest

/// Ajudante comum de lançamento para os testes de interface (#111).
///
/// Adiciona `-FRILA_SEM_ANIMACOES` para acelerar os testes de interface desligando
/// animações UIKit e transações SwiftUI, preservando animações completas quando
/// `-FRILA_MEDICAO` está presente (#73) e no QA manual com `-FRILA_SCENARIO`.
@objc(AjudanteDeLancamentoUITests)
public final class AjudanteDeLancamentoUITests: NSObject, XCTestObservation {
    public static let argumentoSemAnimacoes = "-FRILA_SEM_ANIMACOES"

    public override init() {
        super.init()
        Self.ativarInterceptacaoAutomatica()
    }

    /// Configura o aplicativo para testes de interface, adicionando `-FRILA_SEM_ANIMACOES`
    /// caso não seja teste de medição (-FRILA_MEDICAO).
    public static func preparar(_ app: XCUIApplication) {
        if !app.launchArguments.contains("-FRILA_MEDICAO") &&
           !app.launchArguments.contains(argumentoSemAnimacoes) {
            app.launchArguments.append(argumentoSemAnimacoes)
        }
    }

    /// Lança o app configurado com `-FRILA_SEM_ANIMACOES` para os testes de interface.
    @discardableResult
    @MainActor
    public static func abrir(
        _ app: XCUIApplication,
        argumentos: [String] = []
    ) -> XCUIApplication {
        if !argumentos.isEmpty {
            app.launchArguments += argumentos
        }
        preparar(app)
        app.launch()
        return app
    }

    @discardableResult
    @MainActor
    public static func abrir(
        argumentos: [String] = []
    ) -> XCUIApplication {
        abrir(XCUIApplication(), argumentos: argumentos)
    }

    nonisolated(unsafe) private static var swizzled = false

    /// Ativa a interceptação de `XCUIApplication.launch()` para garantir que todas as classes
    /// de testes de interface passem automaticamente pelo ajudante comum.
    public static func ativarInterceptacaoAutomatica() {
        guard !swizzled else { return }
        swizzled = true
        let originalSelector = #selector(XCUIApplication.launch)
        let swizzledSelector = #selector(XCUIApplication.frila_launchComAnimacoesDesligadas)
        guard let originalMethod = class_getInstanceMethod(XCUIApplication.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(XCUIApplication.self, swizzledSelector) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension XCUIApplication {
    @objc fileprivate func frila_launchComAnimacoesDesligadas() {
        AjudanteDeLancamentoUITests.preparar(self)
        frila_launchComAnimacoesDesligadas()
    }

    /// Método explícito do ajudante comum para iniciar o app com `-FRILA_SEM_ANIMACOES`.
    @MainActor
    public func abrirParaTeste(argumentos: [String] = []) {
        launchArguments += argumentos
        AjudanteDeLancamentoUITests.preparar(self)
        launch()
    }
}

// MARK: - Alvo mínimo

/// Alvo de toque mínimo (44 pt, HIG). O frame que o XCTest devolve sai de conta em ponto
/// flutuante e um controle de 44 pt pode medir 43,999999…: a comparação tem 0,01 pt de folga.
enum AlvoMinimo {
    static let pontos: CGFloat = 44
    static let tolerancia: CGFloat = 0.01

    static func atende(_ medida: CGFloat) -> Bool { medida >= pontos - tolerancia }
}

/// Confere que a medida (largura ou altura do frame) chega ao alvo mínimo, com a folga de `AlvoMinimo`.
func XCTAssertAlvoMinimo(
    _ medida: CGFloat,
    _ mensagem: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertGreaterThanOrEqual(medida, AlvoMinimo.pontos - AlvoMinimo.tolerancia, mensagem(), file: file, line: line)
}

// MARK: - Testes do Ajudante

@MainActor
final class AjudanteDeLancamentoUITestsInternos: XCTestCase {
    func testInjetaArgumentoSemAnimacoesEmTestesComuns() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success"]
        AjudanteDeLancamentoUITests.preparar(app)
        XCTAssertTrue(app.launchArguments.contains("-FRILA_SEM_ANIMACOES"))
    }

    func testPreservaAnimacoesComArgumentoDeMedicao() {
        let app = XCUIApplication()
        app.launchArguments = ["-FRILA_SCENARIO", "success", "-FRILA_MEDICAO"]
        AjudanteDeLancamentoUITests.preparar(app)
        XCTAssertFalse(app.launchArguments.contains("-FRILA_SEM_ANIMACOES"))
    }

    func testAlvoMinimoAceitaErroDePontoFlutuanteERecusaAlvoMenor() {
        XCTAssertTrue(AlvoMinimo.atende(44))
        XCTAssertTrue(AlvoMinimo.atende(43.999999), "erro de ponto flutuante de um controle de 44 pt")
        XCTAssertFalse(AlvoMinimo.atende(43.98), "alvo de verdade menor que 44 pt")
        XCTAssertAlvoMinimo(43.999999)
        XCTExpectFailure("43,9 pt fica abaixo do alvo mínimo") { XCTAssertAlvoMinimo(43.9) }
    }
}

