import Foundation
import SwiftUI

/// Indicador visual compacto de disponibilidade e lotação de vagas do Frila (LOG-010).
/// - Até 6 posições: círculos de 10 pt com espaçamento de 4 pt (preenchidos em terracota `FrilaCor.marca`, vazios com contorno `FrilaCor.borda`)
///   acompanhados de texto visível com contagem preenchidas/total.
/// - Acima de 6 posições: anel proporcional de 32 pt, traço de 3 pt com número no centro e texto descritivo preenchidas/total.
/// - Suporte a singular ("1 de 1 preenchida") e plural ("%lld de %lld preenchidas").
/// - Dados inválidos (total <= 0, preenchidas < 0, preenchidas > total) são omitidos.
public struct FrilaLotacao: View {
    public let preenchidas: Int
    public let total: Int

    public init(preenchidas: Int, total: Int) {
        self.preenchidas = preenchidas
        self.total = total
    }

    public var body: some View {
        if total > 0 && preenchidas >= 0 && preenchidas <= total {
            if total <= 6 {
                circulosView
            } else {
                anelView
            }
        }
    }

    private var circulosView: some View {
        let circulos = HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { indice in
                if indice < preenchidas {
                    Circle()
                        .fill(FrilaCor.marca)
                        .frame(width: 10, height: 10)
                } else {
                    Circle()
                        .strokeBorder(FrilaCor.borda, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .accessibilityHidden(true)

        return indicadorComTexto(marca: circulos)
    }

    private var anelView: some View {
        let anel = ZStack {
            Circle()
                .stroke(FrilaCor.divisoria, lineWidth: 3)
            Circle()
                .trim(from: 0, to: proporcao)
                .stroke(FrilaCor.marca, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: "\(preenchidas)")
                .font(FrilaTipo.nota.weight(.bold))
                .foregroundStyle(FrilaCor.texto)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)

        return indicadorComTexto(marca: anel)
    }

    /// Marca e texto na mesma linha quando cabem; senão a marca vai acima e o texto abaixo,
    /// sempre inteiro e alinhado à esquerda, sem quebra de palavra nem hifenização na coluna estreita.
    private func indicadorComTexto(marca: some View) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: FrilaEspaco.pequeno) {
                marca
                textoPreenchidasView
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                marca
                textoPreenchidasView
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var textoPreenchidasView: some View {
        if total == 1 {
            Text("\(preenchidas) de 1 preenchida", bundle: bundleApresentacao)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
        } else {
            Text("\(preenchidas) de \(total) preenchidas", bundle: bundleApresentacao)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
        }
    }

    private var proporcao: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(preenchidas) / CGFloat(total)
    }
}

/// Contagem de tempo real até o início do turno ou indicador de andamento (LOG-010).
/// - Sem data de início ou se a data de fim já passou: nada é exibido.
/// - Do horário de início até o horário de fim: exibe "Em andamento".
/// - Antes do início: relógio em tempo real atualizado a cada 1 s exibe "Começa em %@".
/// - Formatação de duração via `DateComponentsFormatter` em pt-BR no estilo `.full` (dia, hora, minuto)
///   com arredondamento sem falso zero (evita abreviações e melhora leitura falada).
/// - Utiliza tokens de cor acessíveis (`FrilaCor.texto` para texto, `FrilaCor.marca` para acento no estado em andamento e `FrilaCor.textoSecundario` no relógio futuro).
public struct FrilaContagemTurno: View {
    public let inicio: Date?
    public let fim: Date?
    private let dataReferencia: (@Sendable () -> Date)?

    private static let formatadorDuracao: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        formatter.calendar = cal
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter
    }()

    public init(inicio: Date?, fim: Date?) {
        self.inicio = inicio
        self.fim = fim
        self.dataReferencia = nil
    }

    init(inicio: Date?, fim: Date?, dataReferencia: (@escaping @Sendable () -> Date)) {
        self.inicio = inicio
        self.fim = fim
        self.dataReferencia = dataReferencia
    }

    public var body: some View {
        if let inicio {
            if let dataReferencia {
                conteudo(agora: dataReferencia(), inicio: inicio)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    conteudo(agora: context.date, inicio: inicio)
                }
            }
        }
    }

    @ViewBuilder
    private func conteudo(agora: Date, inicio: Date) -> some View {
        if let fim, agora >= fim {
            EmptyView()
        } else if agora >= inicio {
            HStack(spacing: FrilaEspaco.minimo) {
                Circle()
                    .fill(FrilaCor.marca)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text("Em andamento", bundle: bundleApresentacao)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.texto)
            }
            .accessibilityElement(children: .combine)
        } else {
            let duracao = formatarDuracao(de: agora, ate: inicio)
            let texto = String(format: String(localized: "Começa em %@", bundle: bundleApresentacao), duracao)
            HStack(spacing: FrilaEspaco.minimo) {
                Image(systemName: "clock")
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)
                Text(verbatim: texto)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.texto)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func formatarDuracao(de agora: Date, ate inicio: Date) -> String {
        let intervalo = inicio.timeIntervalSince(agora)
        guard intervalo > 0 else { return "1 minuto" }

        // Arredondamento sem falso zero: frações de minuto arredondam para cima,
        // garantindo que qualquer período restante antes do início resulte em pelo menos 1 minuto.
        let segundosAjustados = max(60.0, ceil(intervalo / 60.0) * 60.0)
        return Self.formatadorDuracao.string(from: segundosAjustados) ?? "1 minuto"
    }
}
