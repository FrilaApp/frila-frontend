import FrilaApresentacao
import SwiftUI
import Testing

@Suite("Cortina de privacidade no seletor de apps")
struct CortinaDePrivacidadeTests {
    @Test("Esconde fora de .active: no seletor de apps (.inactive) e em segundo plano")
    func escondeForaDeAtivo() {
        #expect(!CortinaDePrivacidade.esconde(.active))
        #expect(CortinaDePrivacidade.esconde(.inactive))
        #expect(CortinaDePrivacidade.esconde(.background))
    }
}
