@testable import FrilaApresentacao
import Testing

/// As etapas do turno que o selo e a linha de etapas do Meu turno mostram (R3 do redesign).
struct EtapasDoTurnoTests {
    @Test("A etapa atual é a mais adiantada que já aconteceu")
    func etapaAtual() {
        #expect(EtapaDoTurno.atual(aCaminho: false, presenca: false, concluido: false) == .confirmado)
        #expect(EtapaDoTurno.atual(aCaminho: true, presenca: false, concluido: false) == .aCaminho)
        #expect(EtapaDoTurno.atual(aCaminho: true, presenca: true, concluido: false) == .presenca)
        #expect(EtapaDoTurno.atual(aCaminho: false, presenca: true, concluido: false) == .presenca)
        #expect(EtapaDoTurno.atual(aCaminho: true, presenca: true, concluido: true) == .concluido)
    }

    @Test("Presença sem o aviso \"a caminho\" não conta a caminho como etapa feita")
    func presencaSemAviso() {
        let feitas = EtapaDoTurno.feitas(aCaminho: false, presenca: true, concluido: false)
        #expect(feitas == [.confirmado, .presenca])
    }

    @Test("Concluído conta todas as etapas que aconteceram, e a ordem das etapas é a do turno")
    func concluido() {
        let feitas = EtapaDoTurno.feitas(aCaminho: true, presenca: true, concluido: true)
        #expect(feitas == Set(EtapaDoTurno.allCases))
        #expect(EtapaDoTurno.allCases == [.confirmado, .aCaminho, .presenca, .concluido])
    }

    @Test("O selo de cada etapa leva o estilo do desenho")
    func selos() {
        #expect(EtapaDoTurno.confirmado.selo.estilo == .destaque)
        #expect(EtapaDoTurno.aCaminho.selo.estilo == .andamento)
        #expect(EtapaDoTurno.presenca.selo.estilo == .andamento)
        #expect(EtapaDoTurno.concluido.selo.estilo == .contorno)
    }
}
