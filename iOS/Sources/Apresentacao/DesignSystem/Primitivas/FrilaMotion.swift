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

    // MARK: - Cópia de contato (tip e pílula de deslizar)

    public static let copyTipHold: Double = 1.4
    /// Tempo da pílula com "Copiado" antes de sumir.
    public static let copyPillHold: Double = 1.8
    /// Espera para o nó assentar sobre "Copiar" antes de escurecer e receber o rótulo.
    public static let copySettleDelay: Double = 0.10
    /// Ao trocar direto de uma parada para outra, o nó vira lente de vidro enquanto viaja e só depois encolhe.
    public static let copySwitchLensHold: Double = 0.18
    /// A troca é mais lenta e macia que a trava; a cor ativa já vem na viagem, sem espera para assentar.
    public static let copySwitchSpring: Animation = .spring(duration: 0.36, bounce: 0.14)
    /// Durante a viagem o preenchimento ativo aparece parcial: o vidro continua visível por baixo.
    public static let copySwitchFillOpacity: Double = 0.40
    public static let copyHapticInterval: Double = 0.15
    public static let copyLongPress: Double = 0.45
    public static let copyPillOpen: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.24)
    /// Cancelamento: a lente recua e a pílula se retrai até o valor, rápido e com leve vida.
    public static let copyCancelSpring: Animation = .spring(duration: 0.22, bounce: 0.1)
    public static let copyPillClose: Animation = .timingCurve(0.4, 0, 1, 1, duration: 0.16)
    /// Atração do nó para "Copiar" e a troca de lente para bolha, com leve excesso.
    public static let copyLatchSpring: Animation = .spring(duration: 0.20, bounce: 0.16)
    /// Texto que sobe rolando ao trocar de "Copiar" para "Copiado".
    public static let copyTextRoll: Animation = .spring(duration: 0.28, bounce: 0.08)
    /// A pílula cresce de leve enquanto a lente desliza, como a barra de abas nativa. A nativa, medida em
    /// gravação, chega a 1,043; aqui 1,03, porque a pílula já corre quase rente às margens da tela.
    public static let copyPillDragScale: CGFloat = 1.06
    public static let copyPillDragSpring: Animation = .spring(duration: 0.25, bounce: 0.2)
    /// Reduzir Movimento: toda troca do componente é só este fade de opacidade.
    public static let copyReducedFade: Animation = .easeOut(duration: 0.12)
    /// Pulso seco ao travar e ao destravar em "Copiar". Dispara na captura, antes da troca visual.
    public static let copyLatchHapticIntensity: Double = 0.45
    /// Sair para o espaço livre pesa menos que entrar: a ida e a volta não se somam num rufar.
    public static let copyUnlatchHapticIntensity: Double = 0.25
    /// O pulso de saída espera um instante: se o nó prender noutra parada logo em seguida, só o da entrada vale.
    public static let copyUnlatchHapticDelay: Double = 0.07
    /// Dois pulsos de trava nunca ficam mais perto que isto.
    public static let copyLatchHapticMinGap: Double = 0.09
    /// A zona de captura cresce com o curso, até este teto: ativar o toggle mais cedo.
    public static let copyCaptureFraction: CGFloat = 0.4
    public static let copyCaptureMax: CGFloat = 80
    /// Com várias paradas, cada zona de captura ocupa no máximo esta fração da distância até a vizinha, e a
    /// histerese esta outra: as zonas de retenção de duas paradas nunca se sobrepõem.
    public static let copyStopCaptureShare: CGFloat = 0.38
    public static let copyStopHysteresisShare: CGFloat = 0.08

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

    // Toque simples: uma trajetória única de 420 ms para as duas bordas, desenhada à mão (sem mola), em que a bolha só
    // existe no vão e a margem tem um retorno orgânico. Valores propostos pelos dois Codex e escolhidos pelo
    // usuário (opção A, 03/11/2026); ainda a validar no aparelho.

    /// Relógio único de 440 ms, com a curva quíntica Q(u) = 6u⁵ − 15u⁴ + 10u³ em cada trecho (velocidade e aceleração
    /// zero nas junções). O transporte chega ao destino aos 220 ms: a frente em 0 a 220 ms, a de trás em 20 a 240 ms
    /// (um alongamento curto de viagem, sem oscilação própria). O háptico toca na chegada.
    public static let segmentoToqueDuracao: Double = 0.44
    public static let segmentoToqueChegadaDaFrente: Double = 0.22
    public static let segmentoToqueSaidaDeTras: Double = 0.02
    public static let segmentoToqueChegadaDeTras: Double = 0.24

    /// Reação à inércia: o corpo inteiro (as duas bordas juntas, fio incluso) passa do destino e volta, e os rótulos
    /// reagem no sentido oposto. Efeito fixo, sem proporção com a distância. A trilha e o cartão ficam parados: a trilha
    /// é a referência que faz o movimento ler como inércia. Começa aos 160 ms (nos últimos 60 ms do transporte), para
    /// não parecer uma segunda ação depois da chegada.
    public static let segmentoInerciaInicio: Double = 0.16
    /// Excesso do corpo aos 220 ms e recuo para dentro aos 310 ms, em pt. Com o recuo de 4 pt da trilha e o fio de 1 pt,
    /// sobra 1 pt livre até a borda da trilha.
    public static let segmentoInerciaExcesso: CGFloat = 2
    public static let segmentoInerciaRecuo: CGFloat = 0.75
    public static let segmentoInerciaRecuoEm: Double = 0.31
    /// Os rótulos Início e Fim não reagem: ficam parados, porque rótulos que tremem dessincronizam a leitura.

    /// A bolha do vão vale 0 com o cursor num centro de célula e cresce até 1 no meio do vão (começa a 10% do passo,
    /// com suavização S). Cresce 8 por 5 pt além do cursor (no arraste são 28 por 14). Sem vidro e sem véu:
    /// o preenchimento fica em 100%, o cursor só se alarga.
    /// A bolha acompanha o transporte nominal do centro e fecha em 160 ms, antes de a reação inercial começar.
    public static let segmentoToqueTransporte: Double = 0.16
    public static let segmentoToqueVaoInicio: CGFloat = 0.10
    public static let segmentoToqueCresceX: CGFloat = 8
    public static let segmentoToqueCresceY: CGFloat = 5

    /// O segundo háptico do toque toca quando a frente chega à parede.
    public static let segmentoToqueHapticApos: Double = 0.22

    // Soltar o dedo depois de um arraste: o assentamento da bolha ganha uma mola em escala proporcional.

    /// A bolha se comprime a 97% (uniforme nos dois eixos) e volta numa mola longa e macia, passando de leve de 100%.
    /// Bounce entre 0,1 e 0,3 é o que se aceita em UI; aqui 0,25, com 0,46 s para a mola não parecer brinquedo.
    public static let segmentoSoltarEscala: CGFloat = 0.97
    public static let segmentoSoltarCompressao: Animation = .easeOut(duration: 0.11)
    public static let segmentoSoltarMola: Animation = .spring(duration: 0.46, bounce: 0.25)
    public static let segmentoSoltarCompressaoDuracao: Double = 0.11
    /// Háptico do assentamento depois de arrastar: mais leve que o do toque, no momento em que a bolha volta.
    public static let segmentoHapticSoltar: Double = 0.35

    /// Háptico 1, a troca de lado: pulso rígido (`copyLatchHapticIntensity`).
    public static let segmentoHapticTroca: Double = 0.45
    /// Háptico 2, o assentamento: um toque suave que confirma o estado.
    public static let segmentoHapticAssentamento: Double = 0.55

    // MARK: - Horários (faixa semanal e lista acoplada)

    /// Troca de página em `FrilaPaginasHorizontais` (a roleta de Início e Fim): o conjunto desliza a distância inteira
    /// da janela, em sentido oposto ao do cursor, e a máscara esmaece as pontas. 0,34 s com bounce de só 0,05: a
    /// distância longa pede mais tempo que os 0,28 s do "Copiado" da tela de Conta, sem sobra de mola.
    public static let paginasHorizontais: Animation = .spring(duration: 0.34, bounce: 0.05)

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

    // MARK: - Faixa semanal (dissolução do destaque, 03/11/2026, segunda rodada)
    //
    // O contorno não viaja: recolhe para dentro do dia que sai e nasce de dentro no dia que entra. Espessura, escala e
    // opacidade andam juntas por uma só curva de arrancada forte (ease-out: o anel some ou nasce rápido e assenta
    // devagar). No meio da troca a espessura incha para dentro (o stroke é interno), o que impede o vale em que os dois
    // contornos, finos e translúcidos, deixariam a célula sem destaque. Os rótulos reagem com um pop.
    // A primeira rodada (180 ms, escalas de 3%) era imperceptível no aparelho; esta alonga e abre os valores.
    // A validar no aparelho.

    /// Duração do contorno, da saída e da entrada, em segundos.
    public static let semanaDestaqueDuracao: Double = 0.34
    /// A entrada espera a saída começar a abrir espaço: 60 ms de atraso (só quando parte do repouso).
    public static let semanaDestaqueAtraso: Double = 0.06
    /// Espessura nominal do contorno com o dia ativo, em pt.
    public static let semanaDestaqueEspessura: CGFloat = 2
    /// Espessura extra no meio da troca (pico em p = 0,5), em pt: o stroke incha para dentro.
    public static let semanaDestaqueEspessuraExtra: CGFloat = 1.5
    /// Escala do contorno quando o dia está oculto (0), crescendo até 1 com o dia ativo. Recolhe 18% para dentro.
    public static let semanaDestaqueEscalaOculta: CGFloat = 0.82

    /// Quíntica suave Q(u) = 6u⁵ − 15u⁴ + 10u³ (velocidade e aceleração zero nas pontas), com u limitado a [0, 1].
    /// Usada nos pops dos rótulos.
    public static func semanaDestaqueProgresso(_ u: Double) -> Double {
        let x = min(max(u, 0), 1)
        return x * x * x * (x * (6 * x - 15) + 10)
    }

    /// Derivada de Q em u: 30u²(1 − u)².
    public static func semanaDestaqueDerivada(_ u: Double) -> Double {
        let x = min(max(u, 0), 1)
        return 30 * x * x * (1 - x) * (1 - x)
    }

    /// Curva de arrancada do contorno: 1 − (1 − u)⁴. Começa rápida (velocidade 4) e chega a 0 devagar.
    public static func semanaContornoProgresso(_ u: Double) -> Double {
        let x = 1 - min(max(u, 0), 1)
        return 1 - x * x * x * x
    }

    /// Derivada da curva de arrancada: 4(1 − u)³. Serve à continuidade de velocidade quando um toque interrompe a troca.
    public static func semanaContornoDerivada(_ u: Double) -> Double {
        let x = 1 - min(max(u, 0), 1)
        return 4 * x * x * x
    }

    /// Frenagem máxima ao interromper uma trajetória em curso: até 24 ms, desaceleração constante até velocidade 0.
    public static let semanaInterrupcaoFreioMaximo: Double = 0.024

    /// Pop do rótulo que perde o destaque: afunda a 0,92 em 100 ms e volta a 1 até o fim dos 340 ms.
    public static let semanaRotuloSaidaEscala: CGFloat = 0.92
    public static let semanaRotuloSaidaPico: Double = 0.10
    /// Pop do rótulo que recebe o destaque: afunda a 0,95 em 70 ms, passa a 1,04 aos 190 ms e assenta em 1 aos 340 ms.
    public static let semanaRotuloEntradaCompressao: CGFloat = 0.95
    public static let semanaRotuloEntradaExcesso: CGFloat = 1.04
    public static let semanaRotuloEntradaCompressaoEm: Double = 0.07
    public static let semanaRotuloEntradaExcessoEm: Double = 0.19

    /// Háptico leve da troca de dia por toque: uma vez por troca, sem pulso de assentamento.
    public static let semanaHapticIntensidade: Double = 0.35

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
