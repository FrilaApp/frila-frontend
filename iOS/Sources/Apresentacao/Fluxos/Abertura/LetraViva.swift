import SwiftUI

// As letras do aperto de mão não são peças rígidas: o contorno de cada uma é uma malha de pontos
// (`MalhaDoAperto`), e cada ponto é deslocado por um esqueleto simples (corpo que enverga, braço que
// dobra) e por um campo comum ao par (a sacudida do aperto). É o que deixa o `r` e o `i` dobrarem,
// torcerem e esticarem em vez de só girar em torno da base, e formarem as mãos só na hora do aperto.

/// Pose do esqueleto de uma letra. Tudo em unidades do SVG do rótulo e em graus. "Para o par" é
/// para a direita no `r` e para a esquerda no `i`.
struct PoseDaLetra: Sendable, Equatable {
    /// Deslocamento da letra inteira.
    var x = 0.0, y = 0.0
    /// Envergadura do corpo, em graus no topo. Positivo inclina o topo para o par.
    var curva = 0.0
    /// Esticamento vertical a partir da base (1 é o repouso). A largura compensa parte do volume.
    var estica = 1.0
    /// Quanto o braço levanta, em graus. Metade sobe o braço inteiro a partir do ombro, o resto dobra
    /// o antebraço no cotovelo: o braço dobra em vez de girar como uma régua.
    var braco = 0.0
    /// Quanto a mão avança para o par.
    var alcance = 0.0
    /// Torção em torno do eixo vertical, maior no topo que na base.
    var torcao = 0.0
}

/// Deformação comum ao par depois do encaixe. Por ser um campo só, aplicado às duas letras no
/// mesmo espaço, o punho do `r` e o recorte do `i` continuam encaixados enquanto se mexem.
struct CampoDoPar: Sendable, Equatable {
    /// Subida e descida das mãos (positivo desce). As bases ficam plantadas.
    var sacudida = 0.0
    /// Balanço do topo de cada corpo. Positivo vai em direção ao encaixe.
    var balancoR = 0.0, balancoI = 0.0
    /// Amasso vertical no impacto (1 é o repouso).
    var aperto = 1.0
}

/// O `r`, o `i` ou o pingo da abertura, desenhados a cada quadro.
///
/// O `r` e o `i` são malhas (`MalhaDoAperto`): cada ponto do contorno sai da letra inteira ou da
/// encaixada, conforme `maos`, e depois é deslocado pelo esqueleto e pelo campo do par. Com as mãos
/// formadas e pose e campo neutros, o desenho é o da `FormaDaMarca`. O pingo não deforma: é levado.
struct LetraViva: Shape {
    let parte: ParteDaMarca
    var pose: PoseDaLetra
    var campo: CampoDoPar
    /// 0 é a letra inteira, como a fonte a desenha; 1 é a letra com o encaixe do aperto de mão.
    var maos = 1.0
    /// Só no pingo: escala a partir do próprio pé e deslocamento vertical.
    var escalaPropria = 1.0
    var yProprio = 0.0

    func path(in rect: CGRect) -> Path {
        let escala = min(rect.width / ParteDaMarca.tamanho.width, rect.height / ParteDaMarca.tamanho.height)
        let esqueleto = Esqueleto(parte: parte)
        func naTela(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x * escala, y: rect.minY + p.y * escala)
        }

        let inteira: [CGPoint], encaixada: [CGPoint]
        switch parte {
        case .r: (inteira, encaixada) = (MalhaDoAperto.rInteiro, MalhaDoAperto.rEncaixado)
        case .i: (inteira, encaixada) = (MalhaDoAperto.iInteiro, MalhaDoAperto.iEncaixado)
        default: return pingo(esqueleto, naTela)
        }

        var caminho = Path()
        caminho.addLines(zip(inteira, encaixada).map { inteiro, encaixado in
            let p = CGPoint(x: inteiro.x + (encaixado.x - inteiro.x) * maos,
                            y: inteiro.y + (encaixado.y - inteiro.y) * maos)
            return naTela(campo.aplicar(a: esqueleto.aplicar(pose, a: p)))
        })
        caminho.closeSubpath()
        return caminho
    }

    /// O pingo é levado inteiro. De lado, segue o arco do corpo do `i`; em altura, segue o topo do
    /// `i` logo abaixo dele (o pescoço), para a folga entre os dois não fechar. Cresce a partir do
    /// próprio pé, pelo mesmo motivo.
    private func pingo(_ esqueleto: Esqueleto, _ naTela: (CGPoint) -> CGPoint) -> Path {
        let centro = ParteDaMarca.centroDoPingo
        let pe = centro.y + ParteDaMarca.raioDoPingo
        let pescoco = CGPoint(x: centro.x, y: 135)
        let noArco = campo.aplicar(a: esqueleto.aplicar(pose, a: centro))
        let noPescoco = campo.aplicar(a: esqueleto.aplicar(pose, a: pescoco))
        let origem = naTela(CGPoint(x: noArco.x, y: pe + (noPescoco.y - pescoco.y) + yProprio))
        let escala = naTela(CGPoint(x: 1, y: 0)).x - naTela(.zero).x
        let transformacao = CGAffineTransform(translationX: origem.x, y: origem.y)
            .scaledBy(x: escala * escalaPropria, y: escala * escalaPropria)
            .translatedBy(x: -centro.x, y: -pe)
        return parte.caminho().applying(transformacao)
    }
}

// MARK: - Esqueleto e campo

/// Onde cada letra dobra. As medidas saem do desenho do rótulo (`FormaDaMarca`).
struct Esqueleto: Sendable {
    /// Linha do chão e altura do corpo das letras minúsculas.
    static let chao: CGFloat = 432
    static let altura: CGFloat = 300

    /// +1 quando o par está à direita (o `r`), -1 quando está à esquerda (o `i` e o pingo).
    let sentido: CGFloat
    /// Eixo vertical do corpo.
    let eixo: CGFloat
    /// O braço sai do ombro e dobra no cotovelo. Cada faixa em x diz onde a influência começa (0)
    /// e onde é total (1).
    let ombro: CGPoint, faixaDoBraco: (CGFloat, CGFloat)
    let cotovelo: CGPoint, faixaDoAntebraco: (CGFloat, CGFloat)
    /// Faixa em y abaixo da qual a mão não se mexe (no `i`, a perna fica fora).
    let faixaDaMao: (CGFloat, CGFloat)
    let temBraco: Bool

    init(parte: ParteDaMarca) {
        switch parte {
        case .r:
            sentido = 1; eixo = 421; temBraco = true
            ombro = CGPoint(x: 478, y: 262); faixaDoBraco = (476, 580)
            cotovelo = CGPoint(x: 560, y: 205); faixaDoAntebraco = (545, 630)
            faixaDaMao = (Self.chao, 350)
        case .i:
            sentido = -1; eixo = 674; temBraco = true
            ombro = CGPoint(x: 700, y: 262); faixaDoBraco = (700, 610)
            cotovelo = CGPoint(x: 640, y: 215); faixaDoAntebraco = (650, 590)
            faixaDaMao = (335, 265)
        default:
            sentido = -1; eixo = 674; temBraco = false
            ombro = .zero; faixaDoBraco = (0, 0); cotovelo = .zero; faixaDoAntebraco = (0, 0); faixaDaMao = (0, 0)
        }
    }

    func aplicar(_ pose: PoseDaLetra, a ponto: CGPoint) -> CGPoint {
        var p = ponto

        if temBraco, pose.braco != 0 || pose.alcance != 0 {
            let foraDoChao = suave(Self.chao, 350, p.y)
            let noBraco = suave(faixaDoBraco.0, faixaDoBraco.1, p.x) * foraDoChao
            let giro = pose.braco * .pi / 180
            // O braço inteiro sobe sem girar (as paredes do recorte continuam em pé)...
            p.y -= abs(p.x - ombro.x) * tan(giro * 0.5) * noBraco
            // ...e o antebraço dobra em torno do cotovelo.
            let naMao = suave(faixaDaMao.0, faixaDaMao.1, p.y)
            let noAntebraco = suave(faixaDoAntebraco.0, faixaDoAntebraco.1, p.x) * naMao
            let angulo = -sentido * giro * 0.6 * noAntebraco
            let dx = p.x - cotovelo.x, dy = p.y - cotovelo.y
            p = CGPoint(x: cotovelo.x + dx * cos(angulo) - dy * sin(angulo) + sentido * pose.alcance * noBraco * naMao,
                        y: cotovelo.y + dx * sin(angulo) + dy * cos(angulo))
        }

        var lado = p.x - eixo
        var subida = Self.chao - p.y
        let nivel = subida / Self.altura

        // Torção: a letra gira em torno do próprio eixo, mais em cima que embaixo.
        if pose.torcao != 0 {
            lado *= cos(pose.torcao * .pi / 180 * (0.3 + 0.7 * nivel))
        }
        // Esticar e amassar a partir do chão, devolvendo na largura parte do volume.
        subida *= pose.estica
        lado *= 1 + (1 - pose.estica) * 0.5

        // Envergar: o eixo do corpo vira um arco, e cada corte horizontal acompanha o arco.
        let total = sentido * pose.curva * .pi / 180
        if abs(total) > 0.0001 {
            let k = total / Self.altura
            let a = k * subida
            p = CGPoint(x: eixo + (1 - cos(a)) / k + lado * cos(a),
                        y: Self.chao - (sin(a) / k - lado * sin(a)))
        } else {
            p = CGPoint(x: eixo + lado, y: Self.chao - subida)
        }
        return CGPoint(x: p.x + pose.x, y: p.y + pose.y)
    }
}

extension CampoDoPar {
    /// Centro do par "ri" no espaço do SVG, por onde passa o encaixe.
    private static let centro: CGFloat = 600

    func aplicar(a ponto: CGPoint) -> CGPoint {
        guard self != CampoDoPar() else { return ponto }
        var p = ponto
        let chao = Esqueleto.chao

        // Amasso do impacto: o par inteiro cede para baixo e alarga um pouco.
        p.y = chao - (chao - p.y) * aperto
        p.x = Self.centro + (p.x - Self.centro) * (1 + (1 - aperto) * 0.45)

        let subida = max(0, chao - p.y)
        let nivel = min(subida / Esqueleto.altura, 1.4)

        // Sacudida: as mãos sobem e descem inteiras; o ombro do `r` e o corpo do `i` acompanham
        // em parte, e quem toca o chão não sai do lugar.
        let naMao = suave(400, 540, p.x) * (1 - 0.45 * suave(672, 745, p.x))
        p.y += sacudida * naMao * suave(0, 95, subida)

        // Balanço: o topo de cada corpo chega atrasado e passa do ponto.
        let alavanca = pow(nivel, 1.5)
        p.x += balancoR * alavanca * suave(Self.centro, 450, p.x)
        p.x -= balancoI * alavanca * suave(Self.centro, 700, p.x)
        return p
    }
}

/// Degrau suave de 0 (em `a`) a 1 (em `b`). Aceita `a` maior que `b`.
private func suave(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}
