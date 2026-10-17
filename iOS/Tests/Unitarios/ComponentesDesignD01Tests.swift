import FrilaApresentacao
import FrilaDominio
import SwiftUI
import Testing

@Suite("Missão D-01: Toque tátil, Beautiful Shadows e leitura de dinheiro")
@MainActor
struct ComponentesDesignD01Tests {

    // MARK: - Lacuna 11: Leitura de Dinheiro para VoiceOver

    @Test("Leitura de dinheiro para zero")
    func leituraDinheiroZero() {
        #expect(FrilaMoney.spoken(cents: 0) == "0 reais")
        #expect(FrilaMoney.spoken(cents: 0, por: "hora") == "0 reais por hora")
        #expect(FrilaMoney.spoken(cents: 0, por: "turno") == "0 reais por turno")
        #expect(FrilaMoney.spoken(Dinheiro(centavos: 0)) == "0 reais")
        #expect(FormatadorFrila().dinheiroFalado(Dinheiro(centavos: 0)) == "0 reais")
    }

    @Test("Leitura de dinheiro com valores e centavos por extenso")
    func leituraDinheiroValoresComCentavos() {
        // 160 reais por hora (exemplo canônico do critério de aceite)
        #expect(FrilaMoney.spoken(cents: 16_000, por: "hora") == "160 reais por hora")
        #expect(FrilaMoney.spoken(reais: 160, por: "hora") == "160 reais por hora")

        // 1 real e singular
        #expect(FrilaMoney.spoken(cents: 100) == "1 real")
        #expect(FrilaMoney.spoken(cents: 100, por: "hora") == "1 real por hora")
        #expect(FrilaMoney.spoken(reais: 1) == "1 real")

        // Apenas centavos (0 reais)
        #expect(FrilaMoney.spoken(cents: 1) == "1 centavo")
        #expect(FrilaMoney.spoken(cents: 50) == "50 centavos")
        #expect(FrilaMoney.spoken(cents: 99, por: "hora") == "99 centavos por hora")

        // Reais + centavos combinados
        #expect(FrilaMoney.spoken(cents: 101) == "1 real e 1 centavo")
        #expect(FrilaMoney.spoken(cents: 14_050) == "140 reais e 50 centavos")
        #expect(FrilaMoney.spoken(cents: 14_050, por: "turno") == "140 reais e 50 centavos por turno")
        #expect(FrilaMoney.spoken(reais: 140, centavos: 50) == "140 reais e 50 centavos")

        // Via Dinheiro e FormatadorFrila
        let valor = Dinheiro(centavos: 14_050)
        #expect(FrilaMoney.spoken(valor, por: "turno") == "140 reais e 50 centavos por turno")
        #expect(FormatadorFrila().dinheiroFalado(valor, por: "turno") == "140 reais e 50 centavos por turno")
    }

    @Test("Leitura de dinheiro para milhares")
    func leituraDinheiroMilhar() {
        // 1.000 reais
        #expect(FrilaMoney.spoken(cents: 100_000) == "1.000 reais")
        #expect(FrilaMoney.spoken(cents: 100_000, por: "turno") == "1.000 reais por turno")
        #expect(FrilaMoney.spoken(reais: 1000) == "1.000 reais")

        // Milhares com centavos
        #expect(FrilaMoney.spoken(cents: 100_001) == "1.000 reais e 1 centavo")
        #expect(FrilaMoney.spoken(cents: 100_050) == "1.000 reais e 50 centavos")
        #expect(FrilaMoney.spoken(cents: 250_075, por: "turno") == "2.500 reais e 75 centavos por turno")
        #expect(FrilaMoney.spoken(reais: 2500, centavos: 75) == "2.500 reais e 75 centavos")
    }

    // MARK: - Lacuna 2: Estilos Táteis e Reduzir Movimento

    @Test("Tokens de movimento e compressão tátil")
    func tokensDeMovimento() {
        #expect(FrilaMovimento.pressScaleBotao == 0.96)
        #expect(FrilaMovimento.pressScaleChip == 0.94)
        #expect(FrilaMovimento.animacao(reduzir: true) == nil)
        #expect(FrilaMovimento.animacao(reduzir: false) != nil)
    }

    @Test("EstiloBotaoTatil respeita escala e Reduzir Movimento")
    func estiloBotaoTatilParametros() {
        let estiloNormal = EstiloBotaoTatil(reduceMotion: false)
        #expect(estiloNormal.scale == 0.96)
        #expect(estiloNormal.reduceMotion == false)

        let estiloReduzido = EstiloBotaoTatil(reduceMotion: true)
        #expect(estiloReduzido.scale == 0.96)
        #expect(estiloReduzido.reduceMotion == true)
    }

    @Test("EstiloChipTatil respeita escala e Reduzir Movimento")
    func estiloChipTatilParametros() {
        let estiloNormal = EstiloChipTatil(reduceMotion: false)
        #expect(estiloNormal.scale == 0.94)
        #expect(estiloNormal.reduceMotion == false)

        let estiloReduzido = EstiloChipTatil(reduceMotion: true)
        #expect(estiloReduzido.scale == 0.94)
        #expect(estiloReduzido.reduceMotion == true)
    }

    @Test("Alvo de toque mínimo do chip preserva métrica de 44 pt")
    func alvoMinimoDoChipPreservado() {
        #expect(FrilaMetrica.alvoMinimo == 44)
        #expect(FrilaMetrica.alturaDoChip == 32)
        #expect(FrilaMetrica.alturaDoCampo == 52)
    }

    // MARK: - Lacuna 7: Beautiful Shadows (Elevação em 3 Camadas)

    @Test("Zero-shadow nos cartões com fio de 1 pt")
    func zeroShadowCartao() {
        #expect(FrilaElevacao.nenhuma.camadas(escuro: false).isEmpty)
        #expect(FrilaElevacao.nenhuma.camadas(escuro: true).isEmpty)
    }

    @Test("Elevação de folha decompõe exatamente em 3 camadas coordenadas (rim, key, ambient)")
    func elevacaoFolhaTresCamadas() {
        let camadasClaro = FrilaElevacao.folha.camadas(escuro: false)
        #expect(camadasClaro.count == 3)

        // Camada 1: Rim / Contato (raio milimétrico, y curto)
        #expect(camadasClaro[0].raio == 2)
        #expect(camadasClaro[0].y == 1)

        // Camada 2: Key / Luz direta (raio médio, y intermediário)
        #expect(camadasClaro[1].raio == 12)
        #expect(camadasClaro[1].y == 6)

        // Camada 3: Ambient / Difusão ambiente (raio amplo, y maior)
        #expect(camadasClaro[2].raio == 28)
        #expect(camadasClaro[2].y == 14)

        // Modo escuro: 3 camadas calibradas com sombra fraca
        let camadasEscuro = FrilaElevacao.folha.camadas(escuro: true)
        #expect(camadasEscuro.count == 3)
        #expect(camadasEscuro[0].raio == 2)
        #expect(camadasEscuro[1].raio == 12)
        #expect(camadasEscuro[2].raio == 28)
    }

    @Test("Elevação sutil possui 3 camadas coordenadas")
    func elevacaoSutilTresCamadas() {
        let camadasClaro = FrilaElevacao.sutil.camadas(escuro: false)
        #expect(camadasClaro.count == 3)
        #expect(camadasClaro[0].raio == 1.5)
        #expect(camadasClaro[1].raio == 5)
        #expect(camadasClaro[2].raio == 14)

        let camadasEscuro = FrilaElevacao.sutil.camadas(escuro: true)
        #expect(camadasEscuro.count == 3)
    }
}
