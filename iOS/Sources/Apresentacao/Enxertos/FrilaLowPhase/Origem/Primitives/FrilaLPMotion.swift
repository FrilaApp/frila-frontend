import SwiftUI

// MARK: - CANONICAL PRIMITIVE: FrilaLPMotion
/// Tokens de física e molas canônicas do Frila Design System.
/// Encodifica as diretrizes de Emil Kowalski e Apple Human Interface Guidelines:
/// - Molas interpolantes de alta fidelidade
/// - Bounces refinados e sutis (0.1 a 0.25 de bounce físico; 0.94x a 1.05x de escala)
/// - Respeito estrito a `accessibilityReduceMotion` (clamping a 1.0)
public enum FrilaLPMotion {
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

    /// Desfoque de pico (pt) na troca de peso do texto da linha escolhida (`FrilaLPWeightCrossfadeTitle`).
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

    // MARK: - Toque Fora (Outside Tap Dismissal)

    /// Duração máxima de contato para reconhecimento de toque fora (0.30 s).
    /// Contato superior a este limite caracteriza toque longo ou exploração e cancela o fechamento (M20 / SPEC 2.2).
    public static let outsideTapMaxDuration: Double = 0.30
}
