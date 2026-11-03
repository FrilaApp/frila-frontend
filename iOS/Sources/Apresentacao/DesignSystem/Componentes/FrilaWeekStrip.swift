import SwiftUI

/// Um dia da faixa semanal.
public struct FrilaWeekStripDia: Identifiable, Hashable {
    /// 0 = domingo até 6 = sábado, como o contrato.
    public let id: Int
    public let rotulo: String
    /// O dia já tem ao menos um horário.
    public let preenchido: Bool

    public init(id: Int, rotulo: String, preenchido: Bool) {
        self.id = id
        self.rotulo = rotulo
        self.preenchido = preenchido
    }
}

/// Faixa fixa com os sete dias da semana, uma célula por dia. Não é calendário corrido: serve para dizer
/// em quais dias da semana a pessoa trabalha.
///
/// Estados da célula: neutra (dia sem horário), preenchida (fundo suave na cor de seleção) e selecionada
/// (contorno completo e texto em peso maior). Preenchida e selecionada somam os dois. A célula tem o raio
/// concêntrico do contêiner que a abriga: raio do contêiner menos o recuo.
public struct FrilaWeekStrip: View {
    private let dias: [FrilaWeekStripDia]
    private let selecionado: Int
    private let aoSelecionar: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    public init(dias: [FrilaWeekStripDia], selecionado: Int, aoSelecionar: @escaping (Int) -> Void) {
        self.dias = dias
        self.selecionado = selecionado
        self.aoSelecionar = aoSelecionar
    }

    public var body: some View {
        HStack(spacing: FrilaEspaco.minimo) {
            ForEach(dias) { dia in
                let ativo = dia.id == selecionado
                Button { aoSelecionar(dia.id) } label: {
                    Text(verbatim: dia.rotulo)
                        .font(ativo ? FrilaTipo.chip.weight(.bold) : FrilaTipo.chip)
                        .foregroundStyle(ativo || dia.preenchido ? FrilaCor.texto : FrilaCor.textoSecundario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                                .fill(FrilaCor.selecao.opacity(dia.preenchido ? 0.12 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                                .strokeBorder(ativo ? FrilaCor.selecao : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(CelulaDaFaixaSemanal())
                .accessibilityAddTraits(ativo ? .isSelected : [])
                .accessibilityIdentifier("dia-semana-\(dia.id)")
            }
        }
        .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: selecionado)
        .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: dias)
    }
}

/// Toque na célula: afunda 4% e volta. Entra em 140 ms e sai em 200 ms, ease-out forte.
private struct CelulaDaFaixaSemanal: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    func makeBody(configuration: Configuration) -> some View {
        let pressionado = configuration.isPressed
        return configuration.label
            .scaleEffect(reduzirMovimento ? 1 : (pressionado ? 0.96 : 1))
            .animation(FrilaMovimento.animacao(FrilaMotion.horarioToque(pressionado: pressionado), reduzir: reduzirMovimento), value: pressionado)
    }
}
