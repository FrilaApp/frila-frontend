import Foundation
import Testing
import UIKit
@testable import FrilaInfraestrutura

@Suite("TmpVisionDiag")
struct TmpVisionDiag {
    @Test("diag")
    func diag() throws {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000))
        let img = r.image { c in UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000)) }
        let jpeg = img.jpegData(compressionQuality: 0.95)!
        for i in 0..<3 {
            do { let a = try VerificadorLocalDeFotoDoSistema.lerCodigosETextos(jpeg); Issue.record("it\(i) OK \(a.temCodigo) \(a.textos)") }
            catch { Issue.record("it\(i) ERRO \(error)") }
        }
    }
}
