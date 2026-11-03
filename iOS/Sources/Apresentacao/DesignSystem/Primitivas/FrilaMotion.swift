import SwiftUI

// MARK: - CANONICAL PRIMITIVE: FrilaMotion
/// Tokens de física e molas canônicas do Frila Design System.
/// Encodifica as diretrizes de Emil Kowalski e Apple Human Interface Guidelines:
/// - Molas interpolantes de alta fidelidade
/// - Bounces refinados e sutis (0.1 a 0.25 de bounce físico; 0.94x a 1.05x de escala)
/// - Respeito estrito a `accessibilityReduceMotion` (clamping a 1.0)
public enum FrilaMotion {
    // MARK: - Escalas Canônicas de Compressão e Overshoot
    
    /// Compressão padrão para botões de grande e médio porte ao pressionar.
    public static let pressScaleButton: CGFloat = 0.96
    
    /// Compressão tátil refinada para chips e pílulas compactas (28-36pt).
    public static let pressScaleChip: CGFloat = 0.94
    
    /// Leve overshoot de ativação ao selecionar um chip (salto de 5%).
    public static let chipOvershootScale: CGFloat = 1.05
    
    /// Micro-pulso sutil para atualização ou verificação de status chip (4%).
    public static let chipPulseScale: CGFloat = 1.04

    // MARK: - Molas Canônicas (Spring Physics)
    
    /// Mola tátil geral para botões e cards (rigidez: 350, amortecimento: 25).
    public static let tactileSpring: Animation = .interpolatingSpring(stiffness: 350, damping: 25)
    
    /// Mola ultrarrápida para compressão de chips (massa menor: rigidez 380, amortecimento 24).
    public static let chipPressSpring: Animation = .interpolatingSpring(stiffness: 380, damping: 24)
    
    /// Mola de ativação e overshoot para seleção de chips (resposta 0.28s, amortecimento 0.68).
    public static let chipActivationSpring: Animation = .spring(response: 0.28, dampingFraction: 0.68)
    
    /// Mola para deslizadores fluidos entre pílulas (resposta 0.32s, amortecimento 0.74).
    public static let chipGliderSpring: Animation = .spring(response: 0.32, dampingFraction: 0.74)
    
    /// Mola para expansão suave de tags com inserção de ícone (resposta 0.26s, amortecimento 0.76).
    public static let chipTagExpansionSpring: Animation = .spring(response: 0.26, dampingFraction: 0.76)

    /// Mola para preenchimento de barras de progresso contínuo e varredura de validação por etapas
    /// (rigidez: 300, amortecimento: 20). Fluida, sem oscilação excessiva, com resposta orgânica.
    public static let progressBarSpring: Animation = .interpolatingSpring(stiffness: 300, damping: 20)

    // MARK: - Disclosure (expansão e recolhimento de containers)

    /// Expansão: mola quase sem bounce (0.42 s, bounce 0.08). Abre com corpo, assenta sem balançar.
    public static let disclosureExpand: Animation = .spring(duration: 0.42, bounce: 0.08)

    /// Recolhimento: mola criticamente amortecida e mais curta (0.32 s, sem bounce). Fechar só assenta.
    public static let disclosureCollapseDuration: Double = 0.32
    public static let disclosureCollapse: Animation = .spring(duration: disclosureCollapseDuration, bounce: 0)

    /// Folga de overshoot do container na expansão (pt): com bounce 0.08, poucos pontos bastam.
    public static let disclosureOvershootAllowance: CGFloat = 3

    /// Morfologia da borda (raio) ao expandir: Bézier de gaveta iOS (0.32, 0.72, 0, 1), fora da mola de
    /// altura, para o canto nunca passar do alvo nem oscilar.
    public static let disclosureMorphExpand: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.4)

    /// Morfologia da borda ao recolher: mesma curva, mais curta, acompanhando a mola de recolhimento.
    public static let disclosureMorphCollapse: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.3)

    /// Entrada do conteúdo: ease-out, nasce rápido e desacelera, depois de a saída terminar.
    public static let contentFadeIn: Animation = .easeOut(duration: 0.2).delay(0.07)

    /// Saída do conteúdo: ease-in, acelera ao sair para liberar o lugar antes do novo conteúdo.
    public static let contentFadeOut: Animation = .easeIn(duration: 0.09)

    /// Conclusão de uma escolha: espera do fechamento do campo até o pulo do check (ms), para o
    /// check pular quando o campo já assentou e não durante a troca de conteúdo.
    public static let confirmCelebrationDelayMs: Int = 220

    /// Seleção em lista aberta por deslize: quanto tempo o dedo segura uma linha antes de a camada de
    /// seleção passar a segui-lo (s). Um arrasto vertical mais rápido que isso rola a página.
    public static let selectionSlideHoldDuration: Double = 0.15

    /// Deslize da camada de seleção de uma linha para outra numa lista aberta: mola Liquid Glass
    /// (0,5 s, bounce 0.12). Parte do repouso, desliza e passa uns poucos pontos do alvo antes de
    /// assentar. A curva simétrica de 0,32 s freava seco no fim; a curva de gaveta (0.32, 0.72, 0, 1)
    /// cobria 150 pt nos primeiros 0,1 s e lia como salto.
    public static let selectionWashSlide: Animation = .spring(duration: 0.5, bounce: 0.12)

    /// Quanto tempo o check de conclusão fica no lugar do chevron depois de a lista recolher (s).
    public static let conclusionHold: Double = 1.2

    /// Troca de peso do texto da linha escolhida (Bricolage Regular para Bold): esmaecimento com desfoque
    /// leve, ease-in-out de 0,3 s, no tempo do deslize da camada. Opacidade usa curva; movimento usa mola.
    public static let selectionTextCrossfade: Animation = .easeInOut(duration: 0.3)

    /// Desfoque de pico (pt) na troca de peso do texto da linha escolhida (`FrilaWeightCrossfadeTitle`).
    /// Funde as versões Regular e Bold no meio do cross-fade com larguras casadas. Em Reduce Motion, cai a zero.
    public static let selectionTextCrossfadeBlur: CGFloat = 0.6

    /// Cartão do fluxo do turno mudando de forma entre etapas (calendário para roleta): mola suave com bounce
    /// leve (0,45 s, bounce 0.12). Largura, altura, régua e troca de miolo andam na mesma mola.
    public static let shiftCardMorph: Animation = .spring(duration: 0.45, bounce: 0.12)

    /// Painel de horas: atraso entre a mudança do valor e o destaque (ms), o tempo de o cartão do seletor
    /// fechar, para o olhar chegar ao painel já com o número novo.
    public static let hoursHighlightDelayMs: Int = 380

    /// Quanto tempo a borda do painel de horas fica acesa (s).
    public static let hoursHighlightHold: Double = 0.9

    /// Chegada dos valores do fluxo do turno no formulário: intervalo entre um campo e o próximo na cascata
    /// (Data, Início, Fim e o painel de horas), depois de o cartão fechar (`hoursHighlightDelayMs`). Curto,
    /// dentro da faixa de 30 a 80 ms: lê como uma onda passando pelos campos, sem fazer esperar.
    public static let shiftLandingStaggerMs: Int = 80

    /// Atraso da entrada de um miolo pesado que fica vivo e só troca de opacidade (calendário e roletas do
    /// cartão do turno): só começa depois de a saída (`contentFadeOut`, 0,09 s) terminar. Com o atraso de
    /// 0,07 s da troca dos campos, calendário e roleta ficavam visíveis juntos por alguns quadros.
    public static let coreSwapFadeInDelay: Double = 0.1

    /// Entrada do miolo: ease-out de 0,2 s depois de `coreSwapFadeInDelay`.
    public static let coreSwapFadeIn: Animation = .easeOut(duration: 0.2).delay(coreSwapFadeInDelay)

    // MARK: - Disclosure: assentamento para baixo (keyframes sobre a mola de altura)

    /// Expansão: o container desce alguns pontos (ease-out curto), como se a folha descesse do campo,
    /// e volta ao lugar com mola sem bounce. Sem escala: escala ancorada no topo lia como pop-up.
    public static let disclosureDropOffset: CGFloat = 2.5
    public static let disclosureDropLead: Double = 0.14
    public static let disclosureDropSettle: Double = 0.3

    /// Recolhimento: um afundar ainda menor e mais curto, só para o fechamento ter peso.
    public static let disclosurePressOffset: CGFloat = 1.5
    public static let disclosurePressDip: Double = 0.1
    public static let disclosurePressSettle: Double = 0.24

    // MARK: - Segmentos com lente de vidro (movimento da rail de copiar contato, refinado)

    // A rail da Conta (PR #653) tem os `copy*`; aqui o movimento foi refinado depois do teste no aparelho:
    // molas mais curtas e quase sem bounce (a mola dá a sensação de que algo assentou, nunca de brinquedo),
    // bordas independentes (a da frente chega primeiro e a de trás um pouco depois, e a bolha se alonga na
    // viagem) e tensão elástica contra a margem. Quando as duas entrarem na `main`, vale unificar.

    /// Depois de a lente chegar, espera este tempo antes de assentar. Mais curto que o `copySwitchLensHold`
    /// (0,18 s), com o assentamento também mais rápido.
    public static let segmentoLenteHold: Double = 0.14

    /// Borda da frente do cursor na viagem: chega primeiro.
    public static let segmentoBordaDaFrente: Animation = .spring(duration: 0.26, bounce: 0.08)

    /// Borda de trás: chega um pouco depois e com menos bounce, e é isso que alonga a bolha enquanto viaja.
    public static let segmentoBordaDeTras: Animation = Animation.spring(duration: 0.36, bounce: 0.06).delay(0.025)

    /// A lente cresce sem bounce: tamanho que pula como mola vira desenho animado.
    public static let segmentoLenteCresce: Animation = .spring(duration: 0.22, bounce: 0)

    /// A lente assenta com um bounce curto de compensação: é o que dá a affordance de que algo assentou.
    public static let segmentoLenteAssenta: Animation = .spring(duration: 0.26, bounce: 0.10)

    /// Volta da tensão contra a margem: elástico firme, com pouco retorno.
    public static let segmentoRetornoElastico: Animation = .spring(duration: 0.34, bounce: 0.14)

    /// Enquanto é lente, o preenchimento do cursor cai para 40% para o vidro aparecer (`copySwitchFillOpacity`).
    public static let segmentoPreenchimentoNaLente: Double = 0.40

    /// A lente cresce além do cursor: 28 pt a mais na largura e 14 na altura, e transborda a trilha.
    public static let segmentoLenteCresceX: CGFloat = 28
    public static let segmentoLenteCresceY: CGFloat = 14

    /// Tensão contra a margem: a bolha estica no máximo 12% da largura de um segmento (cerca de 18 pt). Com a
    /// lente (14 pt de cada lado) isso cabe no espaço livre até a borda do cartão, sem sair dele. Perto de zero
    /// a resistência é de 40%, e vai fechando até o limite (curva `1 - exp`).
    public static let segmentoEsticadaMaxima: CGFloat = 0.12
    public static let segmentoResistencia: CGFloat = 0.6
    /// Esticada ao máximo, a bolha afina 10% na altura, como um volume que se conserva.
    public static let segmentoAfinarNaTensao: CGFloat = 0.10

    /// Zona medial entre dois segmentos: faixa em que o arrasto ainda não decide. Vale 30% da largura de um segmento,
    /// então o cursor só vira de lado depois de passar de 65% do caminho (e só volta ao passar de 35%). Um empurrão
    /// curto ou um arremesso leve do cursor não troca de segmento sem querer. É uma histerese: o limite é medido a
    /// partir do segmento que está valendo.
    public static let segmentoZonaMedial: CGFloat = 0.30

    // Toque simples: a bolha continua existindo, mas quase do tamanho do cursor ativo e sem bounce.

    /// No toque, a lente cresce só 6 por 4 pt além do cursor (no arraste são 28 por 14).
    public static let segmentoToqueCresceX: CGFloat = 6
    public static let segmentoToqueCresceY: CGFloat = 4
    /// No toque o preenchimento só cai para 80% e o vidro aparece a 60%.
    public static let segmentoToquePreenchimento: Double = 0.80
    public static let segmentoToqueVidro: Double = 0.60
    /// As duas bordas viajam em molas sem bounce, quase juntas (15 ms de diferença): translação linear e calma.
    public static let segmentoToqueBordaDaFrente: Animation = .spring(duration: 0.30, bounce: 0)
    public static let segmentoToqueBordaDeTras: Animation = Animation.spring(duration: 0.34, bounce: 0).delay(0.015)
    public static let segmentoToqueCresce: Animation = .spring(duration: 0.24, bounce: 0)
    public static let segmentoToqueAssenta: Animation = .spring(duration: 0.28, bounce: 0.02)

    /// Háptico 1, a troca de lado: pulso rígido (`copyLatchHapticIntensity`).
    public static let segmentoHapticTroca: Double = 0.45
    /// Háptico 2, o assentamento: um toque suave que confirma o estado.
    public static let segmentoHapticAssentamento: Double = 0.55

    // MARK: - Horários (faixa semanal e lista acoplada)

    /// O contêiner cresce para baixo quando ganha uma linha ou um painel de horários (240 ms).
    public static let horarioExpandir: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.24)

    /// A linha nova nasce depois que o contêiner começou a abrir: 180 ms, com 40 ms de atraso.
    public static let horarioLinhaEntrada: Animation = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.18).delay(0.04)

    /// Destaque do dia (fundo do grupo e da célula): 160 ms, ease-out.
    public static let horarioDestaque: Animation = .easeOut(duration: 0.16)

    /// A linha removida some e o contêiner recolhe em 200 ms, ease-out.
    public static let horarioRemover: Animation = .easeOut(duration: 0.2)

    /// Toque numa célula: afunda em 140 ms; ao soltar volta em 200 ms.
    public static func horarioToque(pressionado: Bool) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: pressionado ? 0.14 : 0.2)
    }

    // MARK: - Toque Fora (Outside Tap Dismissal)

    /// Duração máxima de contato para reconhecimento de toque fora (0.30 s).
    /// Contato superior a este limite caracteriza toque longo ou exploração e cancela o fechamento (M20 / SPEC 2.2).
    public static let outsideTapMaxDuration: Double = 0.30
}

#if canImport(UIKit)
import UIKit

/// Enxerto: a origem animava sem checar o Reduzir Movimento fora das views com `@Environment`.
/// O app exige `FrilaMovimento.animacao(_:reduzir:)` em toda animação; isto lê o ajuste do sistema.
enum FrilaMovimentoReduzido {
    @MainActor static var ativo: Bool { UIAccessibility.isReduceMotionEnabled }
}
#endif
