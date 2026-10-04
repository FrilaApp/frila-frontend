import SwiftUI
import UIKit
@testable import FrilaApresentacao
import XCTest

@MainActor
final class CampoValorVagaTests: XCTestCase {
    func testMascaraReescreveTextoAntesDaProximaTeclaMesmoQuandoValorNaoMuda() throws {
        var texto = ""
        let tela = UIHostingController(rootView: CampoValorVaga(texto: Binding(
            get: { texto }, set: { texto = $0 }
        )))
        let janela = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        janela.rootViewController = tela
        janela.makeKeyAndVisible()
        tela.view.layoutIfNeeded()
        defer { janela.isHidden = true }
        let campo = try XCTUnwrap(campoDeTexto(em: tela.view))

        // Apagar um zero deixa os mesmos centavos: a máscara também precisa reescrever aqui.
        campo.text = "R$ 0,0"
        campo.sendActions(for: .editingChanged)
        XCTAssertEqual(campo.text, "R$ 0,00")
        XCTAssertEqual(Int(texto), 0)

        // Texto observado na falha, entregue de uma vez, sem esperar um ciclo de renderização.
        campo.text = "R$ 0,018000"
        campo.sendActions(for: .editingChanged)
        XCTAssertEqual(campo.text, "R$ 180,00")
        XCTAssertEqual(Int(texto), 18000)

        // Teclas rápidas e exclusão usam a mesma atualização síncrona.
        for (entrada, esperado, centavos) in [
            ("R$ 180,001", "R$ 1800,01", 180001),
            ("R$ 1800,0", "R$ 180,00", 18000),
            ("", "R$ 0,00", 0)
        ] {
            campo.text = entrada
            campo.sendActions(for: .editingChanged)
            XCTAssertEqual(campo.text, esperado)
            XCTAssertEqual(Int(texto), centavos)
        }
    }

    private func campoDeTexto(em view: UIView) -> UITextField? {
        if let campo = view as? UITextField { return campo }
        return view.subviews.lazy.compactMap { self.campoDeTexto(em: $0) }.first
    }
}
