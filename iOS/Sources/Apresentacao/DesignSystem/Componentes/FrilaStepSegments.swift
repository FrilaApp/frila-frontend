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
/// - **Toque simples:** uma trajetória única de 440 ms para as duas bordas (`TrajetoriaDoToque`), desenhada à mão e
///   renderizada por relógio (`TimelineView`), sem mola. A bolha só existe no vão (0 com o cursor assentado, 1 no meio
///   do vão; sem vidro, o preenchimento fica em 100%) e fecha em 160 ms. Depois vem a reação à inércia, fixa: o corpo
///   inteiro do cursor passa 2 pt do destino e recua 0,75 pt. Os rótulos Início e Fim, a trilha e o cartão ficam
///   parados (rótulos que tremem dessincronizam a leitura), e o cursor nunca passa das margens da trilha.
/// - **Soltar depois de arrastar:** a lente assenta e a bolha ganha uma mola em escala proporcional (comprime a 97% e
///   volta passando de leve de 100%), com um háptico leve no momento em que ela volta.
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
    @State private var gatilhoDeSoltar = 0
    /// Escala proporcional da bolha no assentamento depois de arrastar (1 em repouso).
    @State private var escalaDoAssentamento: CGFloat = 1
    /// A troca veio de um arraste (o háptico de troca já tocou na metade): o toque não repete.
    @State private var trocaVeioDoArraste = false
    /// Toque simples em curso: a trajetória das duas bordas, calculada pelo relógio. `nil` fora do toque; as bordas de
    /// estado (`esquerda`, `direita`) já valem o destino desde o início e é de lá que o arraste continua.
    @State private var viagem: ViagemDoToque?
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

    /// Crescimento da lente do arraste (de estado, animado pela mola da lente). O da bolha do toque vem do relógio.
    private var crescimentoDaLente: (x: CGFloat, y: CGFloat) {
        guard lente, !reduzirMovimento else { return (0, 0) }
        return (FrilaMotion.segmentoLenteCresceX, FrilaMotion.segmentoLenteCresceY)
    }

    private var preenchimentoDoCursor: Double { lente ? FrilaMotion.segmentoPreenchimentoNaLente : 1 }

    /// Margem vertical do corpo: afina na tensão e cresce (margem negativa) na lente.
    private var margemVertical: CGFloat {
        altura * FrilaMotion.segmentoAfinarNaTensao * tensao / 2 - crescimentoDaLente.y / 2
    }

    /// Posiciona o corpo do cursor entre as duas bordas. No arraste e no retorno, cada borda é a margem de um
    /// `padding` próprio, então anima com a mola dela. No toque, as bordas vêm do relógio (`extra` é a bolha do vão).
    private func entreAsBordas<V: View>(_ conteudo: V, esquerda e: CGFloat, direita d: CGFloat, extra: CGSize = .zero) -> some View {
        conteudo
            .scaleEffect(escalaDoAssentamento)
            .padding(.horizontal, -(crescimentoDaLente.x + extra.width) / 2)
            .padding(.vertical, margemVertical - extra.height / 2)
            .padding(.leading, e)
            .padding(.trailing, largura - d)
            .frame(width: largura, height: altura)
    }

    /// As bordas apresentadas agora: as do relógio durante o toque, as de estado fora dele.
    private func bordasApresentadas(em data: Date = .now) -> (esquerda: CGFloat, direita: CGFloat, vao: CGFloat) {
        guard let viagem else { return (esquerda, direita, 0) }
        return viagem.trajetoria.quadro(em: data.timeIntervalSince(viagem.inicio), passo: larguraDoSegmento)
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
        .sensoryFeedback(.impact(flexibility: .soft, intensity: FrilaMotion.segmentoHapticSoltar), trigger: gatilhoDeSoltar)
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
    /// preenchimento cai para 40% e o vidro, por cima dos rótulos, ocupa o lugar dele. No toque, o relógio
    /// (`TimelineView`) manda nas bordas e na bolha do vão, e o preenchimento fica em 100%.
    private var cursor: some View {
        TimelineView(.animation(paused: viagem == nil)) { contexto in
            let q = bordasApresentadas(em: contexto.date)
            entreAsBordas(
                ZStack {
                    Capsule().fill(FrilaCor.superficie.opacity(preenchimentoDoCursor))
                    Capsule().strokeBorder(FrilaCor.divisoria, lineWidth: 1)
                },
                esquerda: q.esquerda, direita: q.direita,
                extra: CGSize(width: FrilaMotion.segmentoToqueCresceX * q.vao, height: FrilaMotion.segmentoToqueCresceY * q.vao)
            )
        }
        .allowsHitTesting(false)
    }

    /// O vidro do arraste, por cima dos rótulos: só existe enquanto o cursor é lente, e some com a mola. O toque
    /// simples não usa vidro (era a origem do flash claro sobre os rótulos).
    private var vidro: some View {
        entreAsBordas(
            Color.clear
                .modifier(LenteDeVidroDosSegmentos())
                .opacity(lente && !reduzirMovimento ? 1 : 0),
            esquerda: esquerda, direita: direita
        )
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
        encerrarViagem()
        escalaDoAssentamento = 1
        arrastando = true
        arrastouAgora = true
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

    /// Termina o toque em curso (se houver) deixando nas bordas de estado a posição apresentada agora, sem animar,
    /// para o arraste ou o retorno continuarem dali sem salto.
    private func encerrarViagem() {
        tarefaDeAssentamento?.cancel()
        guard viagem != nil else { return }
        let q = bordasApresentadas()
        viagem = nil
        var transacao = Transaction()
        transacao.disablesAnimations = true
        withTransaction(transacao) {
            esquerda = q.esquerda
            direita = q.direita
        }
    }

    /// O cursor vai para o segmento ativo. Vale para toque, para arraste e para o retorno de um arraste que não
    /// trocou de lado. `trocou` diz se o cursor virou de lado por um toque (então toca o háptico de troca); `suave`
    /// marca o toque simples.
    ///
    /// - **Toque (`suave`):** uma trajetória única, calculada pelo relógio a partir das bordas apresentadas (um toque
    ///   no meio da viagem parte de onde o cursor está). Sem lente de estado, sem mola e sem pausa; o háptico de
    ///   assentamento toca no pico da frente.
    /// - **Arraste e retorno:** a borda da frente chega primeiro, a de trás depois, e a lente de estado existe
    ///   durante a viagem e assenta depois de uma pausa curta.
    private func viajar(trocou: Bool, suave: Bool) {
        guard largura > 0 else { return }
        let b = bordas(de: indiceAtivo)

        if suave {
            tarefaDeAssentamento?.cancel()
            if lente {
                withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoLenteCresce, reduzir: reduzirMovimento)) { lente = false }
            }
            let origem = bordasApresentadas()
            var transacao = Transaction()
            transacao.disablesAnimations = true
            if reduzirMovimento {
                viagem = nil
                withTransaction(transacao) { esquerda = b.esquerda; direita = b.direita }
            } else {
                let inicio = Date.now
                viagem = ViagemDoToque(
                    inicio: inicio,
                    trajetoria: TrajetoriaDoToque(
                        origem: (origem.esquerda, origem.direita), destino: (b.esquerda, b.direita)
                    )
                )
                withTransaction(transacao) { esquerda = b.esquerda; direita = b.direita }
                tarefaDeAssentamento = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(FrilaMotion.segmentoToqueHapticApos))
                    guard !Task.isCancelled, !arrastando else { return }
                    gatilhoDeAssentamento += 1
                    try? await Task.sleep(for: .seconds(FrilaMotion.segmentoToqueDuracao - FrilaMotion.segmentoToqueHapticApos + 0.02))
                    guard !Task.isCancelled, viagem?.inicio == inicio else { return }
                    viagem = nil
                }
            }
            if trocou { gatilhoDeTroca += 1 }
            return
        }

        encerrarViagem()
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

    /// Depois de arrastar: a lente assenta e a bolha comprime a 97% e volta numa mola macia, em escala
    /// proporcional. O háptico leve toca quando ela começa a voltar.
    private func assentarDepois() {
        tarefaDeAssentamento?.cancel()
        tarefaDeAssentamento = Task { @MainActor in
            try? await Task.sleep(for: .seconds(FrilaMotion.segmentoLenteHold))
            guard !Task.isCancelled, !arrastando else { return }
            withAnimation(FrilaMovimento.animacao(FrilaMotion.segmentoLenteAssenta, reduzir: reduzirMovimento)) { lente = false }
            guard !reduzirMovimento else { gatilhoDeAssentamento += 1; return }
            withAnimation(FrilaMotion.segmentoSoltarCompressao) { escalaDoAssentamento = FrilaMotion.segmentoSoltarEscala }
            try? await Task.sleep(for: .seconds(FrilaMotion.segmentoSoltarCompressaoDuracao))
            guard !Task.isCancelled, !arrastando else { escalaDoAssentamento = 1; return }
            gatilhoDeSoltar += 1
            withAnimation(FrilaMotion.segmentoSoltarMola) { escalaDoAssentamento = 1 }
        }
    }
}

/// O toque em curso: quando começou e a trajetória das bordas.
struct ViagemDoToque: Equatable {
    let inicio: Date
    let trajetoria: TrajetoriaDoToque
}

/// A trajetória das duas bordas do cursor num toque simples, em função do tempo (sem mola nem `delay`).
///
/// Posições absolutas na trilha, em pt, com `s` o sentido (+1 direita, −1 esquerda). Curva quíntica
/// Q(u) = 6u⁵ − 15u⁴ + 10u³ em todo trecho (velocidade e aceleração zero nas junções):
/// - **Transporte:** a frente vai da origem ao destino em 0 a 220 ms; a de trás em 20 a 240 ms (alongamento curto de
///   viagem, sem oscilação própria).
/// - **Reação à inércia (fixa):** o corpo inteiro soma um deslocamento às duas bordas: 0 até 160 ms, +s·2 pt aos 220 ms,
///   −s·0,75 pt aos 310 ms e 0 aos 440 ms. Largura e altura não mudam.
/// - **Bolha:** o centro nominal (origem → destino em 160 ms) atravessa o vão: 0 sobre um centro de célula, 1 no meio
///   do vão; fecha antes da reação e não renasce. Parte da posição apresentada, então uma interrupção no meio do vão
///   continua do ponto certo.
struct TrajetoriaDoToque: Equatable {
    let origem: (esquerda: CGFloat, direita: CGFloat)
    let destino: (esquerda: CGFloat, direita: CGFloat)

    static func == (a: TrajetoriaDoToque, b: TrajetoriaDoToque) -> Bool {
        a.origem == b.origem && a.destino == b.destino
    }

    private var centroDaOrigem: CGFloat { (origem.esquerda + origem.direita) / 2 }
    private var centroDoDestino: CGFloat { (destino.esquerda + destino.direita) / 2 }
    private var sentido: CGFloat { centroDoDestino >= centroDaOrigem ? 1 : -1 }
    private var distancia: CGFloat { abs(centroDoDestino - centroDaOrigem) }

    /// Curva quíntica Q(u) = 6u⁵ − 15u⁴ + 10u³, de 0 a 1 com velocidade e aceleração zero nas pontas.
    private static func suave(_ u: Double) -> CGFloat {
        let x = min(max(u, 0), 1)
        return CGFloat(x * x * x * (x * (x * 6 - 15) + 10))
    }

    /// Valor entre dois pontos de uma lista de (tempo, valor), com Q em cada trecho; antes do primeiro vale o primeiro.
    private static func trechos(_ t: Double, _ pontos: [(t: Double, v: CGFloat)]) -> CGFloat {
        guard let primeiro = pontos.first, let ultimo = pontos.last else { return 0 }
        if t <= primeiro.t { return primeiro.v }
        if t >= ultimo.t { return ultimo.v }
        let k = (0..<pontos.count - 1).first { t <= pontos[$0 + 1].t } ?? pontos.count - 2
        let a = pontos[k], b = pontos[k + 1]
        return a.v + (b.v - a.v) * suave((t - a.t) / (b.t - a.t))
    }

    private func de(_ de: CGFloat, para: CGFloat, em u: Double) -> CGFloat { de + (para - de) * Self.suave(u) }

    /// Bordas e bolha do vão no instante `t` (segundos desde o início). `passo` é a largura de um segmento.
    func quadro(em tempo: TimeInterval, passo: CGFloat) -> (esquerda: CGFloat, direita: CGFloat, vao: CGFloat) {
        let t = max(tempo, 0)
        let s = sentido

        let origemDaFrente = s > 0 ? origem.direita : origem.esquerda
        let destinoDaFrente = s > 0 ? destino.direita : destino.esquerda
        let origemDeTras = s > 0 ? origem.esquerda : origem.direita
        let destinoDeTras = s > 0 ? destino.esquerda : destino.direita

        let chegada = FrilaMotion.segmentoToqueChegadaDaFrente
        let inicioDaReacao = FrilaMotion.segmentoInerciaInicio

        // Transporte: a frente chega aos 220 ms e a de trás aos 240 ms.
        let frente = Self.trechos(t, [(0, origemDaFrente), (chegada, destinoDaFrente)])
        let tras = Self.trechos(t, [
            (FrilaMotion.segmentoToqueSaidaDeTras, origemDeTras),
            (FrilaMotion.segmentoToqueChegadaDeTras, destinoDeTras)
        ])

        // Reação à inércia: o corpo inteiro passa do destino e volta, com o mesmo deslocamento nas duas bordas.
        let corpo = s * Self.trechos(t, [
            (inicioDaReacao, 0),
            (chegada, FrilaMotion.segmentoInerciaExcesso),
            (FrilaMotion.segmentoInerciaRecuoEm, -FrilaMotion.segmentoInerciaRecuo),
            (FrilaMotion.segmentoToqueDuracao, 0)
        ])
        let esquerdaAgora = (s > 0 ? tras : frente) + corpo
        let direitaAgora = (s > 0 ? frente : tras) + corpo

        // Bolha: o centro nominal atravessa o vão (0 sobre o centro de uma célula, 1 no meio do vão).
        var vao: CGFloat = 0
        if passo > 0, t < FrilaMotion.segmentoToqueTransporte {
            let nominal = de(centroDaOrigem, para: centroDoDestino, em: t / FrilaMotion.segmentoToqueTransporte)
            let x = nominal / passo - 0.5
            let distanciaAoCentro = abs(x - x.rounded())
            let inicio = FrilaMotion.segmentoToqueVaoInicio
            let k = min(max((distanciaAoCentro - inicio) / (0.5 - inicio), 0), 1)
            vao = k * k * (3 - 2 * k)
        }
        return (esquerdaAgora, direitaAgora, vao)
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
