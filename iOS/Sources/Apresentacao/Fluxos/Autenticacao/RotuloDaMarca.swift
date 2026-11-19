// O rótulo "Frila" da entrada (T6, D-DS-19 do redesign), sem a abertura animada (D-DS-15, fora do lote).
// Desenho do Fabrício (`FrilaAssets/FrilaBrandLabel.svg`), traçado em código: não precisa de asset novo nem
// de mudança no `project.yml`. Componente do fluxo da entrada; sobe ao sistema quando outra tela usar a marca.
import SwiftUI

// Gerado de FrilaAssets/FrilaBrandLabel.svg (viewBox 1311 × 439). Não edite à mão: cada letra é uma
// parte separada para a abertura poder animar uma de cada vez. As coordenadas ficam no espaço do SVG
// e a forma escala para o retângulo que recebe, mantendo a proporção do rótulo inteiro.

/// Uma letra do rótulo "Frila". O `r` e o `i` se encaixam: o punho do `r` entra no recorte do `i`,
/// e os dedos do `i` passam por cima dele. É o aperto de mão que a abertura anima.
enum ParteDaMarca: CaseIterable, Sendable {
    case f, r, i, pingo, l, a

    /// Tamanho do rótulo inteiro no espaço do SVG.
    static let tamanho = CGSize(width: 1311, height: 439)

    /// O `a` tem o furo do bojo: precisa de preenchimento par-ímpar.
    var precisaDeParImpar: Bool { self == .a }

    func caminho() -> Path {
        var p = Path()
        // swiftlint:disable:next identifier_name
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        switch self {
        case .a:
            p.move(to: P(1100.58, 130.956))
            p.addCurve(to: P(1277.6, 221.276), control1: P(1167.5, 127.556), control2: P(1261.94, 140.045))
            p.addCurve(to: P(1279.7, 318.216), control1: P(1283.19, 250.266), control2: P(1278.25, 288.036))
            p.addCurve(to: P(1310.25, 355.287), control1: P(1281.02, 345.786), control2: P(1278.65, 354.527))
            p.addCurve(to: P(1306.66, 425.806), control1: P(1309.81, 377.857), control2: P(1307.93, 403.046))
            p.addLine(to: P(1305.8, 426.257))
            p.addCurve(to: P(1205.78, 431.726), control1: P(1277.29, 441.116), control2: P(1236, 441.326))
            p.addCurve(to: P(1161.51, 394.806), control1: P(1185.13, 425.166), control2: P(1171.3, 414.046))
            p.addCurve(to: P(1013.97, 428.406), control1: P(1133.57, 442.676), control2: P(1060.5, 446.406))
            p.addCurve(to: P(963.858, 355.566), control1: P(983.578, 414.736), control2: P(964.148, 388.876))
            p.addCurve(to: P(1143.17, 262.466), control1: P(962.959, 254.066), control2: P(1076.5, 262.476))
            p.addCurve(to: P(1138.52, 234.797), control1: P(1143.13, 252.716), control2: P(1144.67, 243.327))
            p.addCurve(to: P(1096.3, 232.106), control1: P(1128.9, 221.447), control2: P(1108.19, 222.126))
            p.addCurve(to: P(1085.83, 257.346), control1: P(1087.46, 239.526), control2: P(1086.7, 246.436))
            p.addCurve(to: P(962.078, 234.946), control1: P(1044.99, 250.926), control2: P(1002.83, 242.526))
            p.addCurve(to: P(1100.58, 130.956), control1: P(976.828, 163.734), control2: P(1033.54, 136.95))
            p.closeSubpath()
            p.move(to: P(1142.81, 317.566))
            p.addCurve(to: P(1117.31, 317.917), control1: P(1134.52, 317.666), control2: P(1125.52, 317.597))
            p.addCurve(to: P(1099.3, 326.997), control1: P(1110.07, 319.127), control2: P(1103.96, 320.777))
            p.addCurve(to: P(1096.02, 341.047), control1: P(1096.26, 330.997), control2: P(1095.06, 336.107))
            p.addCurve(to: P(1121.94, 358.247), control1: P(1098.39, 353.746), control2: P(1110.23, 358.567))
            p.addCurve(to: P(1142.81, 317.566), control1: P(1145.06, 352.957), control2: P(1142.92, 337.516))
            p.closeSubpath()
        case .l:
            p.move(to: P(776.558, 15.4413))
            p.addLine(to: P(914.818, 15.1813))
            p.addLine(to: P(914.738, 267.466))
            p.addCurve(to: P(958.558, 322.846), control1: P(914.738, 305.076), control2: P(908.898, 334.896))
            p.addCurve(to: P(959.478, 420.406), control1: P(958.208, 354.856), control2: P(959.038, 388.286))
            p.addLine(to: P(948.128, 425.266))
            p.addCurve(to: P(800.608, 413.746), control1: P(908.178, 441.896), control2: P(834.238, 447.276))
            p.addCurve(to: P(776.558, 311.746), control1: P(774.668, 387.876), control2: P(776.518, 345.536))
            p.addLine(to: P(776.558, 15.4413))
            p.closeSubpath()
        case .i:
            p.move(to: P(605.728, 135.71))
            p.addCurve(to: P(742.488, 135.31), control1: P(649.958, 134.573), control2: P(697.838, 135.597))
            p.addLine(to: P(742.468, 432.496))
            p.addLine(to: P(606.271, 432.326))
            p.addLine(to: P(605.997, 324.166))
            p.addCurve(to: P(650.798, 280.106), control1: P(619.472, 308.926), control2: P(636.688, 295.036))
            p.addCurve(to: P(666.488, 239.516), control1: P(661.308, 268.976), control2: P(682.638, 256.146))
            p.addCurve(to: P(619.059, 195.19), control1: P(652.068, 224.656), control2: P(635.748, 207.076))
            p.addCurve(to: P(582.02, 212.976), control1: P(606.659, 186.36), control2: P(592.28, 211.466))
            p.addCurve(to: P(553.342, 186.771), control1: P(574.902, 213.766), control2: P(553.253, 194.576))
            p.addCurve(to: P(605.728, 135.71), control1: P(556.093, 182.453), control2: P(601.123, 138.787))
            p.closeSubpath()
        case .r:
            p.move(to: P(559.209, 130.958))
            p.addCurve(to: P(586.889, 136.22), control1: P(565.481, 130.704), control2: P(583.327, 130.802))
            p.addCurve(to: P(544.805, 178.482), control1: P(583.425, 142.314), control2: P(550.582, 169.913))
            p.addCurve(to: P(541.431, 191.043), control1: P(541.718, 183.061), control2: P(540.844, 185.392))
            p.addCurve(to: P(568.078, 220.526), control1: P(544.234, 201.676), control2: P(561.105, 214.236))
            p.addCurve(to: P(618.683, 209.056), control1: P(589.599, 239.906), control2: P(605.407, 197.606))
            p.addCurve(to: P(660.208, 253.106), control1: P(627.78, 216.896), control2: P(658.928, 244.716))
            p.addCurve(to: P(618.75, 294.506), control1: P(649.586, 269.201), control2: P(632.438, 281.183))
            p.addCurve(to: P(591.155, 321.986), control1: P(609.66, 303.346), control2: P(600.848, 313.976))
            p.addCurve(to: P(581.29, 326.846), control1: P(588.649, 324.056), control2: P(584.745, 326.986))
            p.addCurve(to: P(523.795, 276.566), control1: P(570.252, 326.426), control2: P(534.523, 285.826))
            p.addCurve(to: P(490.794, 349.396), control1: P(485.042, 282.256), control2: P(490.727, 319.796))
            p.addLine(to: P(491.099, 432.536))
            p.addLine(to: P(352.59, 432.406))
            p.addLine(to: P(352.432, 135.379))
            p.addLine(to: P(477.913, 135.094))
            p.addCurve(to: P(479.152, 206.896), control1: P(478.005, 151.931), control2: P(477.333, 191.569))
            p.addCurve(to: P(485.355, 192.197), control1: P(481.702, 202.236), control2: P(483.237, 197.076))
            p.addCurve(to: P(559.209, 130.958), control1: P(500.604, 157.048), control2: P(519.82, 134.95))
            p.closeSubpath()
        case .f:
            p.move(to: P(0, 15.7693))
            p.addLine(to: P(344.632, 15.6883))
            p.addLine(to: P(344.756, 134.77))
            p.addLine(to: P(140.574, 134.777))
            p.addLine(to: P(140.703, 190.44))
            p.addLine(to: P(305.832, 190.183))
            p.addLine(to: P(305.796, 305.936))
            p.addCurve(to: P(140.431, 306.056), control1: P(251.274, 306.736), control2: P(195.064, 306.076))
            p.addLine(to: P(140.685, 432.516))
            p.addLine(to: P(0.0499878, 432.416))
            p.addLine(to: P(0, 15.7693))
            p.closeSubpath()
        case .pingo:
            p.move(to: P(661.998, 2.46674))
            p.addCurve(to: P(747.855, 52.649), control1: P(697.528, -0.567587), control2: P(742.143, 11.803))
            p.addCurve(to: P(689.023, 118.871), control1: P(753.966, 93.53), control2: P(725.285, 113.745))
            p.addCurve(to: P(602.222, 68.6497), control1: P(653.123, 121.115), control2: P(608.075, 110.608))
            p.addCurve(to: P(661.998, 2.46674), control1: P(596.689, 28.7477), control2: P(626.535, 7.22831))
            p.closeSubpath()
        }
        return p
    }
}

/// Uma letra desenhada no quadro do rótulo inteiro. Todas as partes ocupam o mesmo quadro, então
/// empilhadas num `ZStack` montam o rótulo na posição certa.
struct FormaDaMarca: Shape {
    let parte: ParteDaMarca

    func path(in rect: CGRect) -> Path {
        let escala = min(rect.width / ParteDaMarca.tamanho.width, rect.height / ParteDaMarca.tamanho.height)
        let transformacao = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: escala, y: escala)
        return parte.caminho().applying(transformacao)
    }
}

/// O rótulo "Frila" inteiro, numa cor só, na proporção do SVG. A abertura termina nele; a T6 o usa
/// como marca (D-DS-19).
struct RotuloDaMarca: View {
    var cor: Color = FrilaCor.texto

    var body: some View {
        ZStack {
            ForEach(ParteDaMarca.allCases, id: \.self) { parte in
                FormaDaMarca(parte: parte)
                    .fill(cor, style: FillStyle(eoFill: parte.precisaDeParImpar))
            }
        }
        .aspectRatio(ParteDaMarca.tamanho.width / ParteDaMarca.tamanho.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("Frila", bundle: bundleApresentacao))
        .accessibilityAddTraits(.isImage)
    }
}
