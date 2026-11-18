import SwiftUI

// O roteiro da abertura animada (D-DS-15 e D-DS-21 do redesign do Fabrício; brief R-18-01).
//
// UMA constante manda no tempo: `RoteiroDaAbertura.duracaoDaAbertura`. Todo marco (encaixe, saída, pulo) é uma
// fração do roteiro original do protótipo (2,82 s) multiplicada por ela, e a linha do tempo dos quadros-chave,
// que guarda os segundos do protótipo, é lida em `t / escala`. Trocar a constante para 1,5 reescala tudo.

/// Os marcos de tempo, em segundos desde o início, derivados de `duracaoDaAbertura` por proporção.
public struct RoteiroDaAbertura: Sendable, Equatable {
    /// A duração da abertura, em segundos. É a ÚNICA linha que muda o tempo (o valor confirmado pelo time; o Android
    /// usa o mesmo nome e o mesmo valor). Encaixe, saída, pulo e todos os quadros-chave derivam dela.
    public static let duracaoDaAbertura: TimeInterval = 2.8

    /// A duração do roteiro original do protótipo, de onde saem as proporções. Não é um ajuste: é a medida da linha
    /// do tempo dos quadros-chave (`CoreografiaDaAbertura.duracao` confere).
    static let duracaoDoPrototipo: TimeInterval = 2.82

    /// Os marcos do protótipo, em segundos de um roteiro de 2,82 s. Cada um vira fração de `duracaoDoPrototipo`.
    private enum DoPrototipo {
        static let encaixe = 1.11
        static let saida = 2.40
        static let reduzidoSaida = 0.6
        static let reduzidoDuracao = 0.9
        static let pulo = 0.25
        static let assentoDoPulo = 0.35
    }

    /// O encaixe das mãos (o toque tátil). Sem encaixe no roteiro reduzido.
    public let encaixe: TimeInterval?
    /// O começo da saída: o pingo vira a janela e o rótulo voa (ou some).
    public let saida: TimeInterval
    /// O fim: a abertura sai de cima.
    public let duracao: TimeInterval
    /// Quanto dura o esmaecimento de um toque para pular, e o app assentar depois dele.
    public let pulo: TimeInterval
    public let assentoDoPulo: TimeInterval
    /// Quanto a linha do tempo do protótipo foi esticada (`duracao / duracaoDoPrototipo` no roteiro cheio).
    let escala: Double
    /// Verdadeiro no roteiro de Reduzir Movimento: nada se desloca, o rótulo aparece parado e some num esmaecimento.
    public let reduzido: Bool

    private init(duracaoDaAbertura d: TimeInterval, reduzido: Bool) {
        func parte(_ segundos: Double) -> TimeInterval { d * segundos / Self.duracaoDoPrototipo }
        self.reduzido = reduzido
        escala = d / Self.duracaoDoPrototipo
        pulo = parte(DoPrototipo.pulo)
        assentoDoPulo = parte(DoPrototipo.assentoDoPulo)
        if reduzido {
            encaixe = nil
            saida = parte(DoPrototipo.reduzidoSaida)
            duracao = parte(DoPrototipo.reduzidoDuracao)
        } else {
            encaixe = parte(DoPrototipo.encaixe)
            saida = parte(DoPrototipo.saida)
            duracao = d
        }
    }

    /// O roteiro cheio, ou o reduzido (0,9 s e saída em 0,6 s no protótipo, sem encaixe e sem o app crescer).
    public static func para(reduzirMovimento: Bool,
                            duracaoDaAbertura: TimeInterval = RoteiroDaAbertura.duracaoDaAbertura) -> RoteiroDaAbertura {
        RoteiroDaAbertura(duracaoDaAbertura: duracaoDaAbertura, reduzido: reduzirMovimento)
    }

    /// Os marcos em ordem, para conferir: encaixe (se houver), saída e fim.
    var marcos: [TimeInterval] { (encaixe.map { [$0] } ?? []) + [saida, duracao] }

    /// Com "Reduzir movimento", nada se desloca: o rótulo fica parado e some num esmaecimento depois da saída.
    func opacidadeReduzida(no t: TimeInterval) -> Double {
        guard t > saida else { return 1 }
        return max(0, 1 - (t - saida) / (duracao - saida))
    }
}

// MARK: - Quadros

/// Valores de cada quadro. Deslocamentos em unidades do SVG do rótulo; giros em graus.
/// No `r` e no `i`, "para o par" é o sentido positivo de `curva` e de `alcance` (`PoseDaLetra`).
struct QuadroDaAbertura: Sendable, Equatable {
    var rX = -300.0, rY = 60.0, rOpacidade = 0.0
    var rCurva = -10.0, rEstica = 1.0, rBraco = 0.0, rAlcance = 0.0, rTorcao = 45.0
    var iX = 300.0, iY = 60.0, iOpacidade = 0.0
    var iCurva = -10.0, iEstica = 1.0, iBraco = 0.0, iAlcance = 0.0, iTorcao = 45.0
    /// Quanto das mãos já se formou: 0 são as letras inteiras, 1 são as do rótulo, com o encaixe.
    var maos = 0.0
    /// O par depois do encaixe: sacudida das mãos, balanço dos corpos e amasso do impacto.
    var sacudida = 0.0, balancoR = 0.0, balancoI = 0.0, aperto = 1.0
    var pingoEscala = 0.0, pingoY = 30.0
    /// Aproximação da câmera e quanto ela já trocou o centro do "ri" pelo do rótulo (0 a 1).
    var zoom = 2.0, enquadramento = 0.0
    var fX = -160.0, fOpacidade = 0.0
    var lX = 160.0, lOpacidade = 0.0
    var aX = 220.0, aOpacidade = 0.0
    var rotuloEscala = 1.0, rotuloOpacidade = 1.0
    /// Abertura da janela do pingo (0 a 1).
    var abertura = 0.0
    var halo = 0.0

    var poseDoR: PoseDaLetra {
        PoseDaLetra(x: rX, y: rY, curva: rCurva, estica: rEstica, braco: rBraco, alcance: rAlcance, torcao: rTorcao)
    }

    /// O `i` inteiro é uma haste: só tem braço para levantar e mão para avançar depois que a mão
    /// se forma. Antes disso, quem se inclina para o `r` é o corpo.
    var poseDoI: PoseDaLetra {
        PoseDaLetra(x: iX, y: iY, curva: iCurva, estica: iEstica, braco: iBraco * maos,
                    alcance: iAlcance * maos, torcao: iTorcao)
    }

    var campo: CampoDoPar {
        CampoDoPar(sacudida: sacudida, balancoR: balancoR, balancoI: balancoI, aperto: aperto)
    }

    /// O mesmo quadro com as mãos formadas até `quanto` (o momento é chave do Laboratório).
    func comMaos(_ quanto: Double) -> QuadroDaAbertura {
        var q = self
        q.maos = quanto
        return q
    }

    /// O mesmo quadro com a deformação das letras multiplicada por `fator` (chave do Laboratório).
    /// Os deslocamentos, a câmera e a saída não mudam.
    func comElasticidade(_ fator: Double) -> QuadroDaAbertura {
        var q = self
        // O braço não passa do desenhado: além disso o polegar do `r` vira ponta e a mão do `i`
        // encosta no pingo.
        let noBraco = min(fator, 1)
        q.rCurva *= fator; q.rBraco *= noBraco; q.rAlcance *= fator; q.rTorcao *= fator
        q.iCurva *= fator; q.iBraco *= noBraco; q.iAlcance *= fator; q.iTorcao *= fator
        q.rEstica = 1 + (rEstica - 1) * fator
        q.iEstica = 1 + (iEstica - 1) * fator
        q.sacudida *= fator; q.balancoR *= fator; q.balancoI *= fator
        q.aperto = 1 + (aperto - 1) * fator
        return q
    }

    /// O rótulo montado e parado, sem janela aberta. Usado com "Reduzir movimento".
    static let repouso: QuadroDaAbertura = {
        var q = QuadroDaAbertura()
        q.rX = 0; q.rY = 0; q.rOpacidade = 1; q.rCurva = 0; q.rTorcao = 0
        q.iX = 0; q.iY = 0; q.iOpacidade = 1; q.iCurva = 0; q.iTorcao = 0
        q.maos = 1; q.pingoEscala = 1; q.pingoY = 0
        q.zoom = 1; q.enquadramento = 1
        q.fX = 0; q.fOpacidade = 1; q.lX = 0; q.lOpacidade = 1; q.aX = 0; q.aOpacidade = 1
        q.halo = 1
        return q
    }()
}

// MARK: - Coreografia

enum CoreografiaDaAbertura {
    static let escalaInicialDoApp: CGFloat = 0.94

    /// O quadro no instante `t` (segundos desde o início) do roteiro dado. A linha do tempo abaixo está nos
    /// segundos do protótipo (2,82 s); o roteiro a estica ou encolhe por inteiro, molas e rastro incluídos, pela
    /// razão entre a duração dele e a do protótipo. Trocar `duracaoDaAbertura` reescala tudo, sem tocar aqui.
    static func quadro(no t: TimeInterval, roteiro: RoteiroDaAbertura) -> QuadroDaAbertura {
        let base = t / roteiro.escala
        return linhaDoTempo.value(time: base)
            .comMaos(maosFormadas(noInstanteDoPrototipo: base))
            .comElasticidade(elasticidade)
    }

    /// A duração da linha do tempo, nos segundos do protótipo: tem de ser `RoteiroDaAbertura.duracaoDoPrototipo`.
    static var duracao: TimeInterval { linhaDoTempo.duration }

    /// Quanto a deformação das letras vale (o padrão "contida" do Laboratório do Fabrício).
    static let elasticidade = 0.6

    /// Quanto das mãos já se formou, de 0 a 1 (o padrão "no toque": das letras inteiras ao encaixe entre 1,05 s e
    /// 1,23 s do protótipo, com o contato em 1,11 s).
    static func maosFormadas(noInstanteDoPrototipo t: TimeInterval) -> Double {
        let inicio = 1.05, fim = 1.23
        let x = min(max((t - inicio) / (fim - inicio), 0), 1)
        return x * x * (3 - 2 * x)
    }

    private static let molaDaEntrada = Spring(duration: 0.45, bounce: 0.2)
    private static let molaDoRotulo = Spring(duration: 0.40, bounce: 0.25)
    /// Sai devagar e pousa sem cauda: a câmera chega e para, em vez de se arrastar.
    private static let pouso = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.35, y: 0),
                                                endControlPoint: UnitPoint(x: 0.2, y: 1))
    /// O voo do rótulo até o da tela: arranca logo e pousa sem cauda, dentro da saída (0,42 s).
    static let pousoDoVoo = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.3, y: 0.1),
                                             endControlPoint: UnitPoint(x: 0.15, y: 1))

    /// Desfoque de movimento: cópias do par alguns milissegundos atrás, só onde a malha corre mais de
    /// uns 8 pt por quadro de 60 Hz (a entrada e o bote, medidos ponto a ponto). Nos outros trechos o
    /// rastro só borraria. A força entra e sai em degrau suave, sem estalo.
    /// `t` e os atrasos estão nos segundos do protótipo: quem desenha multiplica o atraso por `roteiro.escala`.
    static func rastro(noInstanteDoPrototipo t: TimeInterval) -> [(atraso: TimeInterval, opacidade: Double)] {
        func janela(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            func degrau(_ x: Double) -> Double { let y = min(max(x, 0), 1); return y * y * (3 - 2 * y) }
            return min(degrau((t - a) / (b - a)), 1 - degrau((t - c) / (d - c)))
        }
        let forca = max(janela(0.0, 0.03, 0.17, 0.26), janela(0.96, 1.00, 1.105, 1.12))
        guard forca > 0 else { return [] }
        return [(1.0 / 240, 0.40 * forca), (2.0 / 240, 0.22 * forca), (3.0 / 240, 0.10 * forca)]
    }
    // Uma mola com duração fixa termina antes de assentar, e a linha do tempo segura o último valor.
    // Por isso toda mola que leva ao repouso ganha depois um `CubicKeyframe` curto até o valor exato.

    // Roteiro (segundos):
    // 0–0,45  o `r` entra pela esquerda e o `i` pela direita, em arco, destorcendo; o topo de cada um
    //         chega atrasado, passa do ponto uma vez e assenta (o corpo enverga, não gira). Os dois
    //         são as letras inteiras da fonte, sem recorte;
    // 0,40–0,85  o `r` levanta o braço e acena, com o corpo fazendo o contrapeso;
    // 0,62–0,97  o pingo surge: o `i` estica e inclina para o `r`;
    // 0,85–0,97  antecipação: os dois recuam, amassam e recolhem o braço;
    // 0,97–1,11  bote: esticam, a mão vai na frente e o topo do corpo fica para trás;
    //         as mãos (o punho do `r`, o dedo e o recorte do `i`) se formam fora desta linha do
    //         tempo, na janela que `Tema.MaosDaAbertura` escolhe: no bote ou no toque;
    // 1,11  encaixe: amasso do impacto, e o topo dos corpos chega atrasado (balanço);
    // 1,15–1,62  três sacudidas das mãos juntas, cada uma menor; corpos e pingo vão atrás;
    // 1,50–2,00  a câmera se afasta e pousa; o rótulo se forma: F, l e a em cascata (até 2,23);
    // 2,40–2,82  o pingo vira a janela, o rótulo some em 0,16 s e o app assenta.
    // O relógio conta do primeiro quadro desenhado. Na entrada e no bote, um rastro faz o desfoque
    // de movimento (`rastro(no:)`).
    private static let linhaDoTempo = KeyframeTimeline(initialValue: QuadroDaAbertura()) {
        // O `r`: deslocamento
        KeyframeTrack(\.rX) {
            SpringKeyframe(-110, duration: 0.45, spring: molaDaEntrada)
            LinearKeyframe(-110, duration: 0.40)
            CubicKeyframe(-130, duration: 0.12)
            // O bote acelera até o contato: é o impacto que o amasso responde.
            LinearKeyframe(0, duration: 0.14, timingCurve: .easeIn)
        }
        KeyframeTrack(\.rY) {
            CubicKeyframe(-18, duration: 0.22)
            SpringKeyframe(0, duration: 0.30, spring: molaDaEntrada)
            CubicKeyframe(0, duration: 0.15)
        }
        KeyframeTrack(\.rOpacidade) {
            LinearKeyframe(1, duration: 0.22)
        }
        // O `r`: corpo. Cada movimento passa do ponto uma vez e assenta: mais que isso fica mole.
        KeyframeTrack(\.rTorcao) {
            LinearKeyframe(0, duration: 0.34, timingCurve: .easeOut)
        }
        KeyframeTrack(\.rCurva) {
            CubicKeyframe(-8, duration: 0.14)
            CubicKeyframe(5, duration: 0.22)
            CubicKeyframe(-1.5, duration: 0.14)
            CubicKeyframe(0, duration: 0.12)
            LinearKeyframe(0, duration: 0.23)
            // Nos extremos da antecipação e do bote a velocidade é zero dos dois lados: sem isso, as
            // curvas de durações diferentes davam um tranco de velocidade em 1,05 s.
            CubicKeyframe(3, duration: 0.12, endVelocity: 0)
            CubicKeyframe(-7, duration: 0.08, startVelocity: 0, endVelocity: 0)
            CubicKeyframe(0, duration: 0.06, startVelocity: 0)
        }
        KeyframeTrack(\.rEstica) {
            LinearKeyframe(1, duration: 0.26)
            CubicKeyframe(0.96, duration: 0.12)
            CubicKeyframe(1.02, duration: 0.10)
            CubicKeyframe(1, duration: 0.12)
            LinearKeyframe(1, duration: 0.25)
            CubicKeyframe(0.94, duration: 0.12)
            CubicKeyframe(1.05, duration: 0.08)
            CubicKeyframe(1, duration: 0.06)
        }
        KeyframeTrack(\.rBraco) {
            LinearKeyframe(0, duration: 0.40)
            CubicKeyframe(24, duration: 0.13)
            CubicKeyframe(8, duration: 0.10)
            CubicKeyframe(20, duration: 0.10)
            CubicKeyframe(-3, duration: 0.12)
            CubicKeyframe(8, duration: 0.12)
            CubicKeyframe(-2, duration: 0.09)
            CubicKeyframe(0, duration: 0.05)
        }
        KeyframeTrack(\.rAlcance) {
            LinearKeyframe(0, duration: 0.85)
            CubicKeyframe(-12, duration: 0.12, endVelocity: 0)
            CubicKeyframe(18, duration: 0.08, startVelocity: 0, endVelocity: 0)
            CubicKeyframe(0, duration: 0.06, startVelocity: 0)
        }

        // O `i`, 60 ms depois do `r`
        KeyframeTrack(\.iX) {
            LinearKeyframe(300, duration: 0.06)
            SpringKeyframe(110, duration: 0.42, spring: molaDaEntrada)
            LinearKeyframe(110, duration: 0.37)
            CubicKeyframe(130, duration: 0.12)
            LinearKeyframe(0, duration: 0.14, timingCurve: .easeIn)
        }
        KeyframeTrack(\.iY) {
            LinearKeyframe(60, duration: 0.06)
            CubicKeyframe(-18, duration: 0.22)
            SpringKeyframe(0, duration: 0.30, spring: molaDaEntrada)
            CubicKeyframe(0, duration: 0.15)
        }
        KeyframeTrack(\.iOpacidade) {
            LinearKeyframe(0, duration: 0.06)
            LinearKeyframe(1, duration: 0.22)
        }
        KeyframeTrack(\.iTorcao) {
            LinearKeyframe(45, duration: 0.06)
            LinearKeyframe(0, duration: 0.34, timingCurve: .easeOut)
        }
        KeyframeTrack(\.iCurva) {
            LinearKeyframe(-10, duration: 0.06)
            CubicKeyframe(-8, duration: 0.14)
            CubicKeyframe(5, duration: 0.22)
            CubicKeyframe(-1.5, duration: 0.12)
            CubicKeyframe(0, duration: 0.10)
            CubicKeyframe(5, duration: 0.14)
            CubicKeyframe(2, duration: 0.09)
            CubicKeyframe(4, duration: 0.10, endVelocity: 0)
            CubicKeyframe(-8, duration: 0.08, startVelocity: 0, endVelocity: 0)
            CubicKeyframe(0, duration: 0.06, startVelocity: 0)
        }
        KeyframeTrack(\.iEstica) {
            LinearKeyframe(1, duration: 0.32)
            CubicKeyframe(0.96, duration: 0.12)
            CubicKeyframe(1.02, duration: 0.10)
            CubicKeyframe(1, duration: 0.08)
            CubicKeyframe(1.06, duration: 0.10)
            CubicKeyframe(0.99, duration: 0.10)
            CubicKeyframe(0.93, duration: 0.15)
            CubicKeyframe(1.05, duration: 0.08)
            CubicKeyframe(1, duration: 0.06)
        }
        KeyframeTrack(\.iBraco) {
            LinearKeyframe(0, duration: 0.86)
            CubicKeyframe(10, duration: 0.11)
            CubicKeyframe(-2, duration: 0.09)
            CubicKeyframe(0, duration: 0.05)
        }
        KeyframeTrack(\.iAlcance) {
            LinearKeyframe(0, duration: 0.85)
            CubicKeyframe(-10, duration: 0.12, endVelocity: 0)
            CubicKeyframe(16, duration: 0.08, startVelocity: 0, endVelocity: 0)
            CubicKeyframe(0, duration: 0.06, startVelocity: 0)
        }

        // O par, do encaixe em diante
        KeyframeTrack(\.aperto) {
            LinearKeyframe(1, duration: 1.11)
            CubicKeyframe(0.94, duration: 0.04)
            SpringKeyframe(1, duration: 0.25, spring: .snappy)
            CubicKeyframe(1, duration: 0.15)
        }
        KeyframeTrack(\.balancoR) {
            LinearKeyframe(0, duration: 1.09)
            CubicKeyframe(11, duration: 0.07)
            CubicKeyframe(-4, duration: 0.12)
            CubicKeyframe(1.5, duration: 0.12)
            CubicKeyframe(0, duration: 0.14)
        }
        KeyframeTrack(\.balancoI) {
            LinearKeyframe(0, duration: 1.10)
            CubicKeyframe(14, duration: 0.08)
            CubicKeyframe(-5, duration: 0.12)
            CubicKeyframe(2, duration: 0.12)
            CubicKeyframe(0, duration: 0.14)
        }
        KeyframeTrack(\.sacudida) {
            LinearKeyframe(0, duration: 1.15)
            CubicKeyframe(-28, duration: 0.09)
            CubicKeyframe(18, duration: 0.10)
            CubicKeyframe(-10, duration: 0.09)
            CubicKeyframe(4, duration: 0.09)
            CubicKeyframe(0, duration: 0.10)
        }

        // O pingo: surge, e depois vai atrás das mãos, sempre um pouco atrasado
        KeyframeTrack(\.pingoEscala) {
            LinearKeyframe(0, duration: 0.62)
            SpringKeyframe(1, duration: 0.35, spring: Spring(duration: 0.35, bounce: 0.35))
            CubicKeyframe(1, duration: 0.15)
        }
        KeyframeTrack(\.pingoY) {
            LinearKeyframe(30, duration: 0.62)
            SpringKeyframe(0, duration: 0.35, spring: .bouncy)
            LinearKeyframe(0, duration: 0.14)
            // A folga entre o pingo e o `i` é de 16 unidades: o atraso para baixo fica bem aquém disso.
            CubicKeyframe(5, duration: 0.06)
            CubicKeyframe(2, duration: 0.07)
            CubicKeyframe(-10, duration: 0.07)
            CubicKeyframe(3, duration: 0.08)
            CubicKeyframe(-6, duration: 0.09)
            CubicKeyframe(1, duration: 0.08)
            CubicKeyframe(0, duration: 0.10)
        }

        // A câmera
        // Começa encostada na última sacudida, sem quadro parado entre as duas. A curva pousa de vez:
        // a mola de antes se arrastava abaixo de um pixel por quadro até 2,25 s e fazia a borda tremer.
        KeyframeTrack(\.zoom) {
            LinearKeyframe(2, duration: 1.50)
            LinearKeyframe(1, duration: 0.50, timingCurve: pouso)
        }
        KeyframeTrack(\.enquadramento) {
            LinearKeyframe(0, duration: 1.50)
            LinearKeyframe(1, duration: 0.50, timingCurve: pouso)
        }

        // O rótulo se forma
        KeyframeTrack(\.fX) {
            LinearKeyframe(-160, duration: 1.57)
            SpringKeyframe(0, duration: 0.40, spring: molaDoRotulo)
            CubicKeyframe(0, duration: 0.10)
        }
        KeyframeTrack(\.fOpacidade) {
            LinearKeyframe(0, duration: 1.57)
            LinearKeyframe(1, duration: 0.18)
        }
        KeyframeTrack(\.lX) {
            LinearKeyframe(160, duration: 1.65)
            SpringKeyframe(0, duration: 0.40, spring: molaDoRotulo)
            CubicKeyframe(0, duration: 0.10)
        }
        KeyframeTrack(\.lOpacidade) {
            LinearKeyframe(0, duration: 1.65)
            LinearKeyframe(1, duration: 0.18)
        }
        KeyframeTrack(\.aX) {
            LinearKeyframe(220, duration: 1.73)
            SpringKeyframe(0, duration: 0.40, spring: molaDoRotulo)
            CubicKeyframe(0, duration: 0.10)
        }
        KeyframeTrack(\.aOpacidade) {
            LinearKeyframe(0, duration: 1.73)
            LinearKeyframe(1, duration: 0.18)
        }

        // Fundo
        KeyframeTrack(\.halo) {
            LinearKeyframe(0, duration: 0.2)
            CubicKeyframe(1, duration: 1.2)
            CubicKeyframe(0.75, duration: 0.6)
            CubicKeyframe(1, duration: 0.6)
        }

        // Saída
        // Saída mais curta que a entrada (0,42 s contra 0,45 s), acelerando. O pingo vira a janela no
        // primeiro quadro, e o rótulo some em 0,16 s, antes de a janela passar por cima das letras.
        KeyframeTrack(\.abertura) {
            LinearKeyframe(0, duration: 2.40)
            LinearKeyframe(1, duration: 0.42, timingCurve: .bezier(startControlPoint: UnitPoint(x: 0.3, y: 0),
                                                                   endControlPoint: UnitPoint(x: 1, y: 1)))
        }
        KeyframeTrack(\.rotuloEscala) {
            LinearKeyframe(1, duration: 2.40)
            LinearKeyframe(1.12, duration: 0.30, timingCurve: .easeIn)
        }
        KeyframeTrack(\.rotuloOpacidade) {
            LinearKeyframe(1, duration: 2.40)
            LinearKeyframe(0, duration: 0.16, timingCurve: .easeIn)
        }
    }
}
