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
/// de copiar contato.
///
/// - **Lente de vidro:** viajando, por toque ou por arrasto, o cursor vira uma lente (cresce além da trilha,
///   o preenchimento cai para 40% e entra o vidro nativo) e assenta depois numa mola curta.
/// - **Bolha com duas bordas:** a borda da frente chega primeiro e a de trás um pouco depois, então a bolha se
///   alonga na viagem e se recolhe ao chegar. A mola é suave, com bounce de no máximo 0,10: dá a sensação de que
///   algo assentou, sem efeito de brinquedo.
/// - **Tensão na margem:** arrastar além do primeiro ou do último segmento estica a bolha com resistência
///   crescente (no máximo 12% de um segmento) e ela afina na altura; soltar devolve com um elástico firme.
/// - **Dois hápticos:** um pulso rígido quando o cursor vira de lado (na metade do arrasto, ou no toque) e um
///   toque suave quando a lente assenta, confirmando o estado.
public struct FrilaStepSegments: View {
    private let segmentos: [FrilaStepSegment]
    private let ativo: String
    private let aoSelecionar: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    /// Largura e altura úteis da trilha, medidas de dentro (sem o recuo).
    @State private var largura: CGFloat = 0
    @State private var altura: CGFloat = 52
    /// As duas bordas do corpo do cursor, na trilha. Cada uma anima com a própria mola.
    @State private var esquerda: CGFloat = 0
    @State private var direita: CGFloat = 0
    /// Quanto o dedo andou desde que pegou o cursor. `nil` fora do arraste.
    @State private var traducao: CGFloat?
    @State private var arrastando = false
    /// 0 a 1: tensão contra a margem. A bolha afina na altura proporcionalmente.
    @State private var tensao: CGFloat = 0
    /// Segmento mais próximo do cursor durante o arraste: muda de valor na metade e dispara o primeiro háptico.
    @State private var alvoDoArraste: Int?
    /// O cursor é lente: viajando ou arrastado.
    @State private var lente = false
    @State private var tarefaDeAssentamento: Task<Void, Never>?
    @State private var gatilhoDeTroca = 0
    @State private var gatilhoDeAssentamento = 0
    /// A troca veio de um arraste (o háptico de troca já tocou na metade): o toque não repete.
    @State private var trocaVeioDoArraste = false

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
    private func bordas(de indice: Int) -> (esquerda: CGFloat, direita: CGFloat) {
        (CGFloat(indice) * larguraDoSegmento, CGFloat(indice + 1) * larguraDoSegmento)
    }

    private func indiceMaisProximo(de x: CGFloat) -> Int {
        (0..<quantidade).min { abs(centro(do: $0) - x) < abs(centro(do: $1) - x) } ?? 0
    }

    /// Resistência da margem: começa em 40% e vai fechando até a esticada máxima.
    private func esticar(_ excesso: CGFloat) -> CGFloat {
        let maxima = larguraDoSegmento * FrilaMotion.segmentoEsticadaMaxima
        guard maxima > 0 else { return 0 }
        return maxima * (1 - exp(-FrilaMotion.segmentoResistencia * excesso / maxima))
    }

    private var crescimento: (x: CGFloat, y: CGFloat) {
        lente && !reduzirMovimento ? (FrilaMotion.segmentoLenteCresceX, FrilaMotion.segmentoLenteCresceY) : (0, 0)
    }

    /// Corpo do cursor: do canto esquerdo ao direito, mais fino quando esticado.
    private var corpo: (largura: CGFloat, altura: CGFloat, centro: CGFloat) {
        let afinado = altura * (1 - FrilaMotion.segmentoAfinarNaTensao * tensao)
        return (max(direita - esquerda, 0) + crescimento.x, afinado + crescimento.y, (esquerda + direita) / 2)
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
                    .onAppear { medir(geo.size) }
                    .onChange(of: geo.size) { _, novo in medir(novo) }
            }
        }
        .simultaneousGesture(arraste)
        .padding(FrilaEspaco.minimo)
        .background(FrilaCor.superficieDoCampo, in: Capsule())
        // Háptico 1, a troca de lado; háptico 2, o assentamento.
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: FrilaMotion.segmentoHapticTroca), trigger: gatilhoDeTroca)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: FrilaMotion.segmentoHapticAssentamento), trigger: gatilhoDeAssentamento)
        .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: segmentos)
        .onChange(of: ativo) { _, _ in
            // No arraste o háptico de troca já tocou na metade; no toque ele toca aqui.
            viajar(trocou: !trocaVeioDoArraste)
            trocaVeioDoArraste = false
        }
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
        let c = corpo
        return Capsule()
            .fill(FrilaCor.superficie.opacity(lente ? FrilaMotion.segmentoPreenchimentoNaLente : 1))
            .overlay(Capsule().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
            .frame(width: c.largura, height: c.altura)
            .position(x: c.centro, y: altura / 2)
            .allowsHitTesting(false)
    }

    /// A lente de vidro por cima dos rótulos: só existe enquanto o cursor viaja, e some com a mola.
    private var vidro: some View {
        let c = corpo
        return Color.clear
            .frame(width: c.largura, height: c.altura)
            .modifier(LenteDeVidroDosSegmentos())
            .opacity(lente && !reduzirMovimento ? 1 : 0)
            .position(x: c.centro, y: altura / 2)
            .allowsHitTesting(false)
    }

    // MARK: Medida e repouso

    private func medir(_ tamanho: CGSize) {
        largura = tamanho.width
        altura = tamanho.height
        guard !arrastando else { return }
        var transacao = Transaction()
        transacao.disablesAnimations = true
        withTransaction(transacao) {
            let b = bordas(de: indiceAtivo)
            esquerda = b.esquerda
            direita = b.direita
        }
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
                seguir(valor.translation.width)
            }
            .onEnded { _ in soltar() }
    }

    private func iniciarArraste() {
        tarefaDeAssentamento?.cancel()
        arrastando = true
        alvoDoArraste = indiceAtivo
        withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoLenteCresce, reduzir: reduzirMovimento)) { lente = true }
    }

    /// O cursor acompanha o dedo. Dentro da trilha é puxado para o segmento mais próximo; passando do primeiro ou
    /// do último, o centro para na margem e a borda de fora estica com resistência (a bolha em tensão).
    private func seguir(_ deslocamento: CGFloat) {
        traducao = deslocamento
        let minimo = centro(do: 0)
        let maximo = centro(do: quantidade - 1)
        let bruto = centro(do: indiceAtivo) + deslocamento
        let livre = min(max(bruto, minimo), maximo)
        let excesso = bruto - livre
        let metade = larguraDoSegmento / 2
        let alvo = indiceMaisProximo(de: livre)
        if alvo != alvoDoArraste {
            alvoDoArraste = alvo
            gatilhoDeTroca += 1
        }

        if excesso == 0 {
            // Atração: perto de um segmento, o cursor é puxado para ele antes de soltar.
            let alvoCentro = centro(do: alvo)
            let distancia = alvoCentro - livre
            let alcance = larguraDoSegmento * 0.5
            var c = livre
            if abs(distancia) < alcance {
                let forca = 1 - abs(distancia) / alcance
                c = livre + forca * forca * distancia * 0.5
            }
            esquerda = c - metade
            direita = c + metade
            tensao = 0
        } else {
            let esticado = reduzirMovimento ? 0 : esticar(abs(excesso))
            if excesso > 0 {
                esquerda = livre - metade + esticado * 0.15
                direita = livre + metade + esticado
            } else {
                esquerda = livre - metade - esticado
                direita = livre + metade - esticado * 0.15
            }
            tensao = esticado / max(larguraDoSegmento * FrilaMotion.segmentoEsticadaMaxima, 1)
        }
    }

    private func soltar() {
        guard arrastando else { return }
        let minimo = centro(do: 0)
        let maximo = centro(do: quantidade - 1)
        let livre = min(max(centro(do: indiceAtivo) + (traducao ?? 0), minimo), maximo)
        let destino = indiceMaisProximo(de: livre)
        arrastando = false
        alvoDoArraste = nil
        traducao = nil
        withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoRetornoElastico, reduzir: reduzirMovimento)) { tensao = 0 }
        if destino != indiceAtivo {
            trocaVeioDoArraste = true
            aoSelecionar(segmentos[destino].id)
        } else {
            viajar(trocou: false)
        }
    }

    // MARK: Viagem e assentamento

    /// O cursor vai para o segmento ativo: a borda da frente chega primeiro e a de trás depois, e a lente existe
    /// durante a viagem. Vale para toque, para arraste e para o retorno de um arraste que não trocou de lado.
    /// `trocou` diz se o cursor virou de lado por um toque (então toca o háptico de troca).
    private func viajar(trocou: Bool) {
        guard largura > 0 else { return }
        let b = bordas(de: indiceAtivo)
        let paraDireita = (b.esquerda + b.direita) / 2 >= (esquerda + direita) / 2

        withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoLenteCresce, reduzir: reduzirMovimento)) { lente = true }
        if reduzirMovimento {
            esquerda = b.esquerda
            direita = b.direita
        } else {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoBordaDaFrente, reduzir: reduzirMovimento)) {
                if paraDireita { direita = b.direita } else { esquerda = b.esquerda }
            }
            withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoBordaDeTras, reduzir: reduzirMovimento)) {
                if paraDireita { esquerda = b.esquerda } else { direita = b.direita }
            }
        }

        if trocou { gatilhoDeTroca += 1 }
        assentarDepois()
    }

    private func assentarDepois() {
        tarefaDeAssentamento?.cancel()
        tarefaDeAssentamento = Task { @MainActor in
            try? await Task.sleep(for: .seconds(FrilaMotion.segmentoLenteHold))
            guard !Task.isCancelled, !arrastando else { return }
            withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoLenteAssenta, reduzir: reduzirMovimento)) { lente = false }
            gatilhoDeAssentamento += 1
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
