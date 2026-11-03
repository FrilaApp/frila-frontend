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
/// - **Zona medial:** o cursor só vira de lado depois de passar de 65% do caminho (e só volta ao passar de 35%), então um
///   empurrão curto não troca de segmento. Soltar escolhe o segmento que está valendo.
/// - **Toque simples:** a bolha existe só no vão entre as células. Ela é função da posição (0 com o cursor assentado,
///   1 no meio do vão), então já voltou a ser a célula de seleção antes de chegar. Sem pausa e sem segunda animação
///   de assentamento: a borda da frente se acopla direto ao destino, passa um pouco e volta (bounce curto para o lado
///   de onde veio), enquanto a de trás só acompanha. Press e arrasto mantêm o movimento completo.
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
    /// A viagem veio de um toque simples: a bolha é função da posição (só no vão). No arraste, a lente inteira.
    @State private var viagemSuave = false
    /// Toque simples: a borda de trás parte um instante depois da da frente, numa atualização própria. Duas
    /// `withAnimation` seguidas na mesma atualização se fundem numa transação só, e as duas bordas ganhariam a mesma mola.
    @State private var tarefaDaBordaDeTras: Task<Void, Never>?
    /// Um arraste acabou de terminar: o toque que o botão sob o dedo dispara ao soltar não vale (senão o botão onde o
    /// dedo começou desfaz a troca que o arraste acabou de fazer).
    @State private var arrastouAgora = false

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

    /// Crescimento da lente do arraste (de estado, animado pela mola da lente). O da bolha do toque vem da posição.
    private var crescimentoDaLente: (x: CGFloat, y: CGFloat) {
        guard lente, !reduzirMovimento else { return (0, 0) }
        return (FrilaMotion.segmentoLenteCresceX, FrilaMotion.segmentoLenteCresceY)
    }

    private var preenchimentoDoCursor: Double { lente ? FrilaMotion.segmentoPreenchimentoNaLente : 1 }

    /// A bolha do toque só vale fora do movimento reduzido e fora do arraste.
    private var bolhaDoToque: Bool { viagemSuave && !reduzirMovimento }

    /// Margem vertical do corpo: afina na tensão e cresce (margem negativa) na lente.
    private var margemVertical: CGFloat {
        altura * FrilaMotion.segmentoAfinarNaTensao * tensao / 2 - crescimentoDaLente.y / 2
    }

    /// Posiciona o corpo do cursor entre as duas bordas. Cada borda é a margem de um `padding` próprio, então cada
    /// uma anima com a mola dela (uma única posição derivada das duas misturaria as molas).
    private func entreAsBordas<V: View>(_ conteudo: V) -> some View {
        conteudo
            .padding(.horizontal, -crescimentoDaLente.x / 2)
            .padding(.vertical, margemVertical)
            .padding(.leading, esquerda)
            .padding(.trailing, largura - direita)
            .frame(width: largura, height: altura)
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
            viajar(trocou: !trocaVeioDoArraste, suave: !trocaVeioDoArraste)
            trocaVeioDoArraste = false
        }
    }

    private func rotulo(_ segmento: FrilaStepSegment) -> some View {
        let selecionado = segmento.id == ativo
        return Button {
            guard !arrastouAgora else { return }
            aoSelecionar(segmento.id)
        } label: {
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

    /// O cursor de sempre (a cápsula da superfície com o fio), atrás dos rótulos. Na lente do arraste o
    /// preenchimento cai para 40% e o vidro, por cima dos rótulos, ocupa o lugar dele. No toque, quem manda é o vão.
    private var cursor: some View {
        entreAsBordas(
            ZStack {
                Capsule()
                    .fill(FrilaCor.superficie.opacity(preenchimentoDoCursor))
                    .modifier(NoVao(borda: esquerda, passo: larguraDoSegmento, ativo: bolhaDoToque,
                                    cresceX: FrilaMotion.segmentoToqueCresceX, cresceY: FrilaMotion.segmentoToqueCresceY,
                                    base: 1, pico: FrilaMotion.segmentoToquePreenchimento))
                Capsule()
                    .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
                    .modifier(NoVao(borda: esquerda, passo: larguraDoSegmento, ativo: bolhaDoToque,
                                    cresceX: FrilaMotion.segmentoToqueCresceX, cresceY: FrilaMotion.segmentoToqueCresceY,
                                    base: 1, pico: 1))
            }
        )
        .allowsHitTesting(false)
    }

    /// O vidro por cima dos rótulos. Duas camadas: a do arraste (opacidade de estado, some com a mola) e a do toque
    /// (opacidade e tamanho pela posição, só no vão entre as células).
    private var vidro: some View {
        ZStack {
            entreAsBordas(
                Color.clear
                    .modifier(LenteDeVidroDosSegmentos())
                    .opacity(lente && !reduzirMovimento ? 1 : 0)
            )
            entreAsBordas(
                Color.clear
                    .modifier(LenteDeVidroDosSegmentos())
                    .modifier(NoVao(borda: esquerda, passo: larguraDoSegmento, ativo: bolhaDoToque,
                                    cresceX: FrilaMotion.segmentoToqueCresceX, cresceY: FrilaMotion.segmentoToqueCresceY,
                                    base: 0, pico: FrilaMotion.segmentoToqueVidro))
            )
        }
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

    /// O segmento que vale agora, com zona medial: o cursor só passa para outro segmento depois de se afastar do
    /// atual mais que metade do caminho mais a meia zona (65% com a zona de 30%). Entre 35% e 65% o segmento em
    /// vigor é mantido, nos dois sentidos, e é isso que evita a troca por um empurrão curto.
    private func alvoComZonaMedial(posicao: CGFloat) -> Int {
        let atual = alvoDoArraste ?? indiceAtivo
        let limite = larguraDoSegmento * (0.5 + FrilaMotion.segmentoZonaMedial / 2)
        guard abs(posicao - centro(do: atual)) >= limite else { return atual }
        return indiceMaisProximo(de: posicao)
    }

    private func iniciarArraste() {
        tarefaDeAssentamento?.cancel()
        arrastando = true
        arrastouAgora = true
        viagemSuave = false
        tarefaDaBordaDeTras?.cancel()
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
        let alvo = alvoComZonaMedial(posicao: livre)
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
        let destino = alvoDoArraste ?? indiceAtivo
        arrastando = false
        // O botão dispara o toque dele logo depois deste fim de arraste; só depois disso o toque volta a valer.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            arrastouAgora = false
        }
        alvoDoArraste = nil
        traducao = nil
        withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoRetornoElastico, reduzir: reduzirMovimento)) { tensao = 0 }
        if destino != indiceAtivo {
            trocaVeioDoArraste = true
            aoSelecionar(segmentos[destino].id)
        } else {
            viajar(trocou: false, suave: false)
        }
    }

    // MARK: Viagem e assentamento

    /// O cursor vai para o segmento ativo. Vale para toque, para arraste e para o retorno de um arraste que não
    /// trocou de lado. `trocou` diz se o cursor virou de lado por um toque (então toca o háptico de troca); `suave`
    /// marca o toque simples.
    ///
    /// - **Toque (`suave`):** não há lente de estado nem pausa. A borda da frente se acopla direto ao destino numa
    ///   mola com bounce curto (passa um pouco e volta para o lado de onde veio) e a de trás só acompanha. A bolha é
    ///   desenhada pela posição das bordas (`NoVao`), então só existe no vão e já é a célula quando assenta.
    /// - **Arraste e retorno:** a borda da frente chega primeiro, a de trás depois, e a lente de estado existe
    ///   durante a viagem e assenta depois de uma pausa curta.
    private func viajar(trocou: Bool, suave: Bool) {
        guard largura > 0 else { return }
        viagemSuave = suave
        let b = bordas(de: indiceAtivo)
        let paraDireita = (b.esquerda + b.direita) / 2 >= (esquerda + direita) / 2
        let frente = suave ? FrilaMotion.segmentoToqueIda : FrilaMotion.segmentoBordaDaFrente
        let tras = suave ? FrilaMotion.segmentoToqueBordaDeTras : FrilaMotion.segmentoBordaDeTras

        if suave {
            tarefaDeAssentamento?.cancel()
            if lente {
                withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoLenteCresce, reduzir: reduzirMovimento)) { lente = false }
            }
        } else {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoLenteCresce, reduzir: reduzirMovimento)) { lente = true }
        }

        tarefaDaBordaDeTras?.cancel()
        if reduzirMovimento {
            esquerda = b.esquerda
            direita = b.direita
        } else if suave {
            // A borda da frente passa do destino um pouco (o excesso) e volta: o retorno orgânico da margem. É um
            // bounce desenhado em dois passos (ida e volta), porque o bounce da mola sozinho não aparece nesta
            // geometria. A de trás só acompanha, um instante depois, sem bounce.
            let excesso = FrilaMotion.segmentoToqueExcesso * (paraDireita ? 1 : -1)
            withAnimation(FrilaMovimento.animacao(frente, reduzir: reduzirMovimento)) {
                if paraDireita { direita = b.direita + excesso } else { esquerda = b.esquerda + excesso }
            }
            tarefaDaBordaDeTras = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(FrilaMotion.segmentoToqueAtrasoDeTras))
                guard !Task.isCancelled else { return }
                withAnimation(FrilaMovimento.animacao(tras, reduzir: reduzirMovimento)) {
                    if paraDireita { esquerda = b.esquerda } else { direita = b.direita }
                }
                try? await Task.sleep(for: .milliseconds(FrilaMotion.segmentoToqueQuandoVolta - FrilaMotion.segmentoToqueAtrasoDeTras))
                guard !Task.isCancelled else { return }
                withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoToqueVolta, reduzir: reduzirMovimento)) {
                    if paraDireita { direita = b.direita } else { esquerda = b.esquerda }
                }
            }
        } else {
            withAnimation(FrilaMovimento.animacao(frente, reduzir: reduzirMovimento)) {
                if paraDireita { direita = b.direita } else { esquerda = b.esquerda }
            }
            withAnimation(FrilaMovimento.animacao(tras, reduzir: reduzirMovimento)) {
                if paraDireita { esquerda = b.esquerda } else { direita = b.direita }
            }
        }

        if trocou { gatilhoDeTroca += 1 }
        if suave { confirmarChegadaDoToque() } else { assentarDepois() }
    }

    /// Toque simples: o háptico de assentamento toca quando a borda da frente chega, sem esperar nenhuma pausa.
    private func confirmarChegadaDoToque() {
        tarefaDeAssentamento = Task { @MainActor in
            try? await Task.sleep(for: .seconds(FrilaMotion.segmentoToqueHapticApos))
            guard !Task.isCancelled, !arrastando else { return }
            gatilhoDeAssentamento += 1
        }
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

/// A bolha do toque, desenhada pela posição de uma borda do cursor (`animatableData`): vale 0 quando a borda está
/// numa fronteira de célula (cursor assentado) e vai até 1 no meio do vão entre duas. Assim a bolha aparece no vão e
/// já voltou a ser a célula de seleção antes de a mola assentar, e uma interrupção no meio do caminho continua coerente.
/// Aplica o crescimento além do cursor e leva a opacidade de `base` (fora do vão) a `pico` (no meio do vão).
private struct NoVao: ViewModifier, @preconcurrency Animatable {
    var borda: CGFloat
    let passo: CGFloat
    let ativo: Bool
    let cresceX: CGFloat
    let cresceY: CGFloat
    let base: Double
    let pico: Double

    var animatableData: CGFloat {
        get { borda }
        set { borda = newValue }
    }

    /// Distância da fronteira de célula mais próxima, em fração do passo (0 a 0,5), com suavização S a partir do início.
    private var vao: CGFloat {
        guard ativo, passo > 0 else { return 0 }
        let posicao = borda / passo
        let distancia = abs(posicao - posicao.rounded())
        let inicio = FrilaMotion.segmentoToqueVaoInicio
        let t = min(max((distancia - inicio) / (0.5 - inicio), 0), 1)
        return t * t * (3 - 2 * t)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, -cresceX * vao / 2)
            .padding(.vertical, -cresceY * vao / 2)
            .opacity(base + (pico - base) * Double(vao))
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
