import SwiftUI

/// Um segmento de etapa: o nome e o valor vivo daquela etapa.
public struct FrilaStepSegment: Identifiable, Hashable {
    public let id: String
    public let titulo: String
    public let valor: String

    public init(id: String, titulo: String, valor: String) {
        self.id = id
        self.titulo = titulo
        self.valor = valor
    }
}

/// Segmentos de um fluxo linear (por exemplo Início e Fim): a trilha afundada com uma cápsula que desliza
/// até a etapa ativa. Cada segmento mostra o nome e o valor daquela etapa, e tocar num segmento salta para
/// ele. É o mesmo conceito do seletor de etapas do turno na publicação de vaga, sem a etapa de data.
public struct FrilaStepSegments: View {
    private let segmentos: [FrilaStepSegment]
    private let ativo: String
    private let aoSelecionar: (String) -> Void

    @Namespace private var cursor
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    public init(segmentos: [FrilaStepSegment], ativo: String, aoSelecionar: @escaping (String) -> Void) {
        self.segmentos = segmentos
        self.ativo = ativo
        self.aoSelecionar = aoSelecionar
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(segmentos) { segmento in
                let selecionado = segmento.id == ativo
                Button { aoSelecionar(segmento.id) } label: {
                    VStack(spacing: 0) {
                        Text(verbatim: segmento.titulo)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                        Text(verbatim: segmento.valor)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .monospacedDigit()
                            .contentTransition(reduzirMovimento ? .identity : .numericText())
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if selecionado {
                            Capsule()
                                .fill(FrilaCor.superficie)
                                .overlay(Capsule().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
                                .matchedGeometryEffect(id: "cursor", in: cursor)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selecionado ? .isSelected : [])
                .accessibilityIdentifier("segmento-\(segmento.id)")
            }
        }
        .padding(FrilaEspaco.minimo)
        .background(FrilaCor.superficieDoCampo, in: Capsule())
        .animation(FrilaMovimento.animacao(FrilaMotion.horarioExpandir, reduzir: reduzirMovimento), value: ativo)
        .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: segmentos)
    }
}
