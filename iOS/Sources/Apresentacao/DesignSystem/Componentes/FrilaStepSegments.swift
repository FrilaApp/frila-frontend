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

/// Segmentos de um fluxo linear (por exemplo Início e Fim): a trilha afundada com um cursor que marca a etapa
/// ativa. Cada segmento mostra o nome e o valor daquela etapa. É o mesmo conceito do seletor de etapas do
/// turno na publicação de vaga, sem a etapa de data.
///
/// **Interação.** Tocar num segmento salta para ele. O cursor também se arrasta com o dedo, como o nó da rail
/// de copiar contato: enquanto viaja, ele vira uma lente de vidro (cresce além da trilha, o preenchimento cai
/// para 40% e o vidro nativo aparece), é puxado em direção ao segmento mais próximo e dá um pulso rígido ao
/// passar pela metade. Soltar escolhe o segmento mais próximo e a lente assenta na mola da rail. Tocar e
/// arrastar passam pelo mesmo caminho: a lente nasce sempre que a etapa muda.
public struct FrilaStepSegments: View {
    private let segmentos: [FrilaStepSegment]
    private let ativo: String
    private let aoSelecionar: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    /// Largura e altura úteis da trilha, medidas de dentro (sem o recuo).
    @State private var largura: CGFloat = 0
    @State private var altura: CGFloat = 52
    /// Quanto o dedo andou desde que pegou o cursor. `nil` fora do arraste.
    @State private var traducao: CGFloat?
    @State private var arrastando = false
    /// Segmento mais próximo do cursor durante o arraste: muda de valor na metade e dispara o pulso.
    @State private var alvoDoArraste: Int?
    /// O cursor é lente: viajando ou arrastado.
    @State private var lente = false
    @State private var tarefaDeAssentamento: Task<Void, Never>?

    public init(segmentos: [FrilaStepSegment], ativo: String, aoSelecionar: @escaping (String) -> Void) {
        self.segmentos = segmentos
        self.ativo = ativo
        self.aoSelecionar = aoSelecionar
    }

    // MARK: Geometria

    private var quantidade: Int { max(segmentos.count, 1) }
    private var indiceAtivo: Int { segmentos.firstIndex { $0.id == ativo } ?? 0 }
    private var larguraDoSegmento: CGFloat { largura / CGFloat(quantidade) }

    private func centro(do indice: Int) -> CGFloat { (CGFloat(indice) + 0.5) * larguraDoSegmento }

    /// Onde o dedo deixou o cursor, limitado à trilha.
    private var centroLivre: CGFloat {
        let repouso = centro(do: indiceAtivo)
        guard let traducao else { return repouso }
        return min(max(repouso + traducao, centro(do: 0)), centro(do: quantidade - 1))
    }

    private func indiceMaisProximo(de x: CGFloat) -> Int {
        (0..<quantidade).min { abs(centro(do: $0) - x) < abs(centro(do: $1) - x) } ?? 0
    }

    /// Perto de um segmento, o cursor é puxado para ele antes mesmo de soltar (a atração da rail).
    private var centroDoCursor: CGFloat {
        guard traducao != nil else { return centro(do: indiceAtivo) }
        let livre = centroLivre
        let alvo = centro(do: indiceMaisProximo(de: livre))
        let distancia = alvo - livre
        let alcance = larguraDoSegmento * 0.5
        guard alcance > 0, abs(distancia) < alcance else { return livre }
        let forca = 1 - abs(distancia) / alcance
        return livre + forca * forca * distancia * 0.5
    }

    private var crescimento: (x: CGFloat, y: CGFloat) {
        lente && !reduzirMovimento ? (FrilaMotion.segmentoLenteCresceX, FrilaMotion.segmentoLenteCresceY) : (0, 0)
    }

    // MARK: Corpo

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(segmentos) { segmento in
                rotulo(segmento)
            }
        }
        .background { cursor }
        .overlay { vidro }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { largura = geo.size.width; altura = geo.size.height }
                    .onChange(of: geo.size) { _, novo in largura = novo.width; altura = novo.height }
            }
        }
        .simultaneousGesture(arraste)
        .padding(FrilaEspaco.minimo)
        .background(FrilaCor.superficieDoCampo, in: Capsule())
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: FrilaMotion.segmentoHapticIntensidade), trigger: alvoDoArraste) { antes, depois in
            arrastando && depois != nil && antes != depois
        }
        .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: segmentos)
        .onChange(of: ativo) { _, _ in lenteAoTrocar() }
    }

    private func rotulo(_ segmento: FrilaStepSegment) -> some View {
        let selecionado = segmento.id == ativo
        return Button { aoSelecionar(segmento.id) } label: {
            VStack(spacing: 0) {
                Text(verbatim: segmento.titulo)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                // Palavra ("Selecionar") que vira hora troca por fade escalonado; hora que muda de dígito rola.
                // Misturar os dois na mesma transição numérica embaralhava as letras.
                ZStack {
                    Text(verbatim: segmento.valor)
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .monospacedDigit()
                        .contentTransition(reduzirMovimento ? .identity : .numericText())
                        .id(segmento.valor.contains(":") ? "hora" : segmento.valor)
                        .transition(reduzirMovimento ? .identity : .asymmetric(
                            insertion: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.contentFadeIn, reduzir: reduzirMovimento)),
                            removal: .opacity.animation(FrilaMovimento.animacao(FrilaMotion.contentFadeOut, reduzir: reduzirMovimento))
                        ))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selecionado ? .isSelected : [])
        .accessibilityIdentifier("segmento-\(segmento.id)")
    }

    /// O cursor de sempre (a cápsula da superfície com o fio), atrás dos rótulos. Na lente o preenchimento cai
    /// para 40% e o vidro, por cima dos rótulos, ocupa o lugar dele.
    private var cursor: some View {
        Capsule()
            .fill(FrilaCor.superficie.opacity(lente ? FrilaMotion.segmentoPreenchimentoNaLente : 1))
            .overlay(Capsule().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
            .frame(width: larguraDoSegmento + crescimento.x, height: altura + crescimento.y)
            .position(x: centroDoCursor, y: altura / 2)
            .animation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento), value: ativo)
            .animation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento), value: lente)
            .allowsHitTesting(false)
    }

    /// A lente de vidro por cima dos rótulos: só existe enquanto o cursor viaja, e some com a mola.
    private var vidro: some View {
        Color.clear
            .frame(width: larguraDoSegmento + crescimento.x, height: altura + crescimento.y)
            .modifier(LenteDeVidroDosSegmentos())
            .opacity(lente && !reduzirMovimento ? 1 : 0)
            .position(x: centroDoCursor, y: altura / 2)
            .animation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento), value: ativo)
            .animation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento), value: lente)
            .allowsHitTesting(false)
    }

    // MARK: Gesto

    private var arraste: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { valor in
                if !arrastando {
                    // Só vale arrasto de lado: na vertical, a rolagem da tela continua dona do dedo.
                    guard abs(valor.translation.width) > abs(valor.translation.height) else { return }
                    iniciarArraste()
                }
                traducao = valor.translation.width
                alvoDoArraste = indiceMaisProximo(de: centroLivre)
            }
            .onEnded { _ in soltar() }
    }

    private func iniciarArraste() {
        tarefaDeAssentamento?.cancel()
        arrastando = true
        withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento)) { lente = true }
    }

    private func soltar() {
        guard arrastando else { return }
        let destino = indiceMaisProximo(de: centroLivre)
        arrastando = false
        alvoDoArraste = nil
        withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento)) { traducao = nil }
        if destino != indiceAtivo {
            aoSelecionar(segmentos[destino].id)
        } else {
            assentarDepois()
        }
    }

    // MARK: Lente

    /// A etapa mudou (toque ou arraste): a lente existe durante a viagem e assenta depois.
    private func lenteAoTrocar() {
        withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento)) { lente = true }
        assentarDepois()
    }

    private func assentarDepois() {
        tarefaDeAssentamento?.cancel()
        tarefaDeAssentamento = Task { @MainActor in
            try? await Task.sleep(for: .seconds(FrilaMotion.segmentoLenteHold))
            guard !Task.isCancelled, !arrastando else { return }
            withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoMola, reduzir: reduzirMovimento)) { lente = false }
        }
    }
}

/// Vidro nativo da lente, como o do nó da rail de copiar contato. Abaixo do iOS 26, um véu neutro faz o papel.
private struct LenteDeVidroDosSegmentos: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.clear.tint(FrilaCor.texto.opacity(0.10)), in: Capsule())
        } else {
            content.background(FrilaCor.texto.opacity(0.10), in: Capsule())
        }
    }
}
