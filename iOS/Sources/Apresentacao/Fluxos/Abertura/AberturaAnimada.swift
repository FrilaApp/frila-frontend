import SwiftUI

/// Abertura do app (D-DS-15): o `r` cumprimenta o `i`, o par vira o rótulo "Frila" e o pingo do `i` se abre numa
/// janela que revela o app. Desenho do Fabrício (protótipo), portado para os tokens do app.
///
/// COMO USAR (a raiz do app monta; esta view só desenha por cima, não chama API, não lê sessão e não segura nada):
///
///     ZStack {
///         app                                              // o app carrega por baixo, como sempre
///             .scaleEffect(escalaDoApp)                    // cresce de 0,94 a 1 na saída (opcional)
///             .environment(\.aberturaCobrindo, cobrindo)
///         if cobrindo {
///             AberturaAnimada(destinoDoRotulo: destino, escalaDoApp: $escalaDoApp) { cobrindo = false }
///         }
///     }
///     .onPreferenceChange(DestinoDoRotuloDaAbertura.self) { destino = $0 }   // a entrada marca o rótulo
///
/// - `destinoDoRotulo`: o quadro do rótulo da tela, no espaço global (`DestinoDoRotuloDaAbertura`). Com ele, o
///   rótulo da abertura voa até lá e vira o da tela; sem ele, a saída é a simples (a janela abre e o rótulo some).
/// - `escalaDoApp`: opcional; a abertura a leva de 0,94 a 1 na saída (sem crescer com Reduzir Movimento).
/// - Um toque em qualquer lugar PULA: a cena esmaece e `aoTerminar` vem logo depois.
/// - `duracaoDaAbertura`: o padrão é `RoteiroDaAbertura.duracaoDaAbertura`; passar outra reescala o roteiro inteiro.
/// - `tempoCongelado`: para conferir um quadro (captura): desenha só o instante dado e não termina sozinha.
///
/// Reduzir Movimento: o rótulo aparece parado e some num esmaecimento (`RoteiroDaAbertura` reduzido), sem o app
/// crescer. Toda animação passa por `FrilaMovimento`.
///
/// O `r` e o `i` são malhas deformáveis (`LetraViva`). Nascem inteiros, como a Prodigy Sans os desenha, e só formam
/// as mãos (o punho do `r`, o dedo e o recorte do `i`) quando vão se cumprimentar. Personalidade de movimento:
/// brincalhona na saudação (mola com sobra, antecipação, acompanhamento) e decidida na saída.
public struct AberturaAnimada: View {
    private let destinoDoRotulo: CGRect?
    private let escalaDoApp: Binding<CGFloat>?
    private let duracaoDaAbertura: TimeInterval
    private let tempoCongelado: TimeInterval?
    private let aoTerminar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    @State private var relogio = RelogioDaAbertura()
    /// Muda para recomeçar a condução (toque para pular).
    @State private var geracao = 0
    @State private var pulando = false
    @State private var contato = 0

    public init(destinoDoRotulo: CGRect? = nil,
                escalaDoApp: Binding<CGFloat>? = nil,
                duracaoDaAbertura: TimeInterval = RoteiroDaAbertura.duracaoDaAbertura,
                tempoCongelado: TimeInterval? = nil,
                aoTerminar: @escaping () -> Void) {
        self.destinoDoRotulo = destinoDoRotulo
        self.escalaDoApp = escalaDoApp
        self.duracaoDaAbertura = duracaoDaAbertura
        self.tempoCongelado = tempoCongelado
        self.aoTerminar = aoTerminar
    }

    public var body: some View {
        TimelineView(.animation) { contexto in
            quadro(em: contexto.date)
        }
        .ignoresSafeArea()
        .opacity(pulando ? 0 : 1)
        .contentShape(.rect)
        .onTapGesture(perform: pular)
        .accessibilityElement()
        .accessibilityLabel(Text("Frila", bundle: bundleApresentacao))
        .accessibilityAddTraits(.isImage)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: contato)
        .onAppear {
            // Com "Reduzir movimento" o app não cresce: aparece no lugar quando a abertura esmaece.
            escalaDoApp?.wrappedValue = reduzirMovimento ? 1 : CoreografiaDaAbertura.escalaInicialDoApp
        }
        .task(id: geracao) { await conduzir() }
    }

    // MARK: Tempo

    private var roteiro: RoteiroDaAbertura {
        .para(reduzirMovimento: reduzirMovimento, duracaoDaAbertura: duracaoDaAbertura)
    }

    /// O relógio começa no primeiro quadro desenhado, e não quando a view nasce: numa abertura a frio, o app ainda
    /// inicializa entre um e outro, e a entrada começaria pela metade.
    private func tempo(em data: Date) -> TimeInterval {
        tempoCongelado ?? data.timeIntervalSince(relogio.marcar(data))
    }

    /// Dispara o toque tátil no encaixe, solta o app na saída e tira a abertura no fim.
    private func conduzir() async {
        guard tempoCongelado == nil else { return }
        let roteiro = roteiro
        do {
            if pulando {
                try await Task.sleep(for: .seconds(roteiro.pulo))
                aoTerminar()
                return
            }
            let inicio = try await relogio.esperarInicio()
            func decorrido() -> TimeInterval { Date().timeIntervalSince(inicio) }
            if let encaixe = roteiro.encaixe, decorrido() < encaixe {
                try await Task.sleep(for: .seconds(encaixe - decorrido()))
                contato += 1
            }
            if decorrido() < roteiro.saida {
                try await Task.sleep(for: .seconds(roteiro.saida - decorrido()))
            }
            if let escala = escalaDoApp, escala.wrappedValue != 1 {
                // Curva de duração exata: o app assenta no mesmo quadro em que o rótulo pousa e a abertura sai.
                // Uma mola passaria do tempo e o rótulo da tela ficaria um pouco fora.
                withAnimation(FrilaMovimento.animacao(.easeOut(duration: roteiro.duracao - roteiro.saida), reduzir: reduzirMovimento)) {
                    escala.wrappedValue = 1
                }
            }
            let resto = roteiro.duracao - decorrido()
            if resto > 0 {
                try await Task.sleep(for: .seconds(resto))
            }
            aoTerminar()
        } catch {
            // Cancelada: um toque pulou. A nova tarefa assume.
        }
    }

    /// Pular não corta para o rótulo montado: a cena esmaece de onde está e o app assenta.
    private func pular() {
        guard !pulando, tempoCongelado == nil, let inicio = relogio.inicio,
              Date().timeIntervalSince(inicio) < roteiro.saida else { return }
        let roteiro = roteiro
        // Só a opacidade muda: com Reduzir Movimento o esmaecimento continua valendo.
        withAnimation(FrilaMovimento.animacao(.easeIn(duration: roteiro.pulo), reduzir: reduzirMovimento, somenteOpacidade: true)) {
            pulando = true
        }
        if let escala = escalaDoApp, escala.wrappedValue != 1 {
            withAnimation(FrilaMovimento.animacao(.smooth(duration: roteiro.assentoDoPulo), reduzir: reduzirMovimento)) {
                escala.wrappedValue = 1
            }
        }
        geracao += 1
    }

    // MARK: Desenho

    /// O quadro da coreografia no instante `t`; com Reduzir Movimento, o rótulo montado e parado.
    private func estado(no t: TimeInterval) -> QuadroDaAbertura {
        reduzirMovimento ? QuadroDaAbertura.repouso : CoreografiaDaAbertura.quadro(no: t, roteiro: roteiro)
    }

    @ViewBuilder
    private func quadro(em data: Date) -> some View {
        let roteiro = roteiro
        let t = tempo(em: data)
        // Com destino, o rótulo voa até ele em vez de crescer e sumir; a janela nasce no pingo parado.
        let voa = destinoDoRotulo != nil && !reduzirMovimento && !pulando
        let q: QuadroDaAbertura = {
            var q = estado(no: t)
            if voa { q.rotuloEscala = 1; q.rotuloOpacidade = 1 }
            return q
        }()
        // O quadro de 1/60 s atrás mede quanto a borda da janela corre, para esfumá-la na mesma medida.
        let anterior = estado(no: t - 1.0 / 60)
        let rastro: [Fantasma] = reduzirMovimento ? [] : CoreografiaDaAbertura.rastro(noInstanteDoPrototipo: t / roteiro.escala).map {
            Fantasma(quadro: estado(no: t - $0.atraso * roteiro.escala), opacidade: $0.opacidade)
        }
        let opacidadeGeral = reduzirMovimento ? roteiro.opacidadeReduzida(no: t) : 1

        GeometryReader { geometria in
            let tela = geometria.size
            let largura = min(tela.width - 96, 320)
            let s = largura / ParteDaMarca.tamanho.width
            let centro = CGPoint(x: tela.width / 2, y: tela.height / 2)
            // O destino vem no espaço global; aqui o desenho está no espaço desta view.
            let origem = geometria.frame(in: .global).origin
            let destino = destinoDoRotulo?.offsetBy(dx: -origem.x, dy: -origem.y)

            ZStack {
                fundo(q, anterior: anterior, tela: tela, centro: centro, s: s)
                if voa, t >= roteiro.saida, let destino {
                    let altura = ParteDaMarca.tamanho.height * s
                    rotuloEmVoo(no: t, de: CGRect(x: centro.x - largura / 2, y: centro.y - altura / 2,
                                                   width: largura, height: altura),
                                para: destino, janela: janela(q, tela: tela, centro: centro, s: s))
                } else {
                    rotulo(q, rastro: rastro, largura: largura, s: s)
                        .scaleEffect(q.rotuloEscala)
                        .opacity(q.rotuloOpacidade)
                        .position(centro)
                }
            }
        }
        .opacity(opacidadeGeral)
    }

    /// O rótulo da saída, já parado, a caminho do rótulo da tela: o desenho é o mesmo (`RotuloDaMarca`),
    /// então a troca pela malha não aparece. O lugar e o tamanho seguem uma curva de pouso. A cor vira
    /// onde a janela passa: branco sobre o laranja, tinta dentro da janela, sobre o app. Assim nunca há
    /// um meio-termo cinza.
    private func rotuloEmVoo(no t: TimeInterval, de inicio: CGRect, para fim: CGRect,
                             janela: (centro: CGPoint, raio: CGFloat)) -> some View {
        let duracao = roteiro.duracao - roteiro.saida
        let x = min(max((t - roteiro.saida) / duracao, 0), 1)
        let p = CoreografiaDaAbertura.pousoDoVoo.value(at: x)
        let quadro = CGRect(x: inicio.minX + (fim.minX - inicio.minX) * p,
                            y: inicio.minY + (fim.minY - inicio.minY) * p,
                            width: inicio.width + (fim.width - inicio.width) * p,
                            height: inicio.height + (fim.height - inicio.height) * p)
        func rotulo(_ cor: Color) -> some View {
            RotuloDaMarca(cor: cor)
                .frame(width: quadro.width, height: quadro.height)
                .position(x: quadro.midX, y: quadro.midY)
        }
        return ZStack {
            rotulo(FrilaCor.sobreAcao)
                .mask { MolduraComFuro(centro: janela.centro, raio: janela.raio).fill(style: FillStyle(eoFill: true)) }
            rotulo(FrilaCor.texto)
                .mask { Disco(centro: janela.centro, raio: janela.raio) }
        }
    }

    /// A borda esfumada da janela mede até 15 pt: o raio final passa do canto mais longe por essa folga.
    private static var plumaMaxima: CGFloat { 15 }

    /// O pingo vira a janela: o furo nasce do tamanho e do lugar do pingo e cresce até cobrir a tela.
    private func janela(_ q: QuadroDaAbertura, tela: CGSize, centro: CGPoint, s: CGFloat) -> (centro: CGPoint, raio: CGFloat) {
        let pingo = ParteDaMarca.centroDoPingo
        let meio = CGPoint(x: ParteDaMarca.tamanho.width / 2, y: ParteDaMarca.tamanho.height / 2)
        let c = CGPoint(x: centro.x + (pingo.x - meio.x) * s * q.rotuloEscala,
                        y: centro.y + (pingo.y - meio.y) * s * q.rotuloEscala)
        guard q.abertura > 0 else { return (c, 0) }
        let inicial = ParteDaMarca.raioDoPingo * s * q.rotuloEscala
        let final = hypot(max(c.x, tela.width - c.x), max(c.y, tela.height - c.y)) + Self.plumaMaxima
        return (c, inicial + (final - inicial) * q.abertura)
    }

    private func fundo(_ q: QuadroDaAbertura, anterior: QuadroDaAbertura, tela: CGSize, centro: CGPoint, s: CGFloat) -> some View {
        let (c, r) = janela(q, tela: tela, centro: centro, s: s)
        // Desfoque de movimento da borda: uma borda dura que cresce 20 pt por quadro pisca. A pluma
        // acompanha o quanto ela andou desde o quadro anterior (1 pt parada, até 15 pt no fim).
        let pluma = min(Self.plumaMaxima, 1 + max(0, r - janela(anterior, tela: tela, centro: centro, s: s).raio) * 0.6)

        return ZStack {
            FrilaCor.acao
            // Camada de fundo: um halo claro que respira devagar atrás do rótulo.
            RadialGradient(colors: [FrilaCor.sobreAcao.opacity(0.14 * q.halo), .clear],
                           center: .center, startRadius: 0, endRadius: tela.width * 0.75)
        }
        .mask {
            // Fora do furo, uma moldura sólida; o gradiente só faz a borda, dentro do furo. Um
            // gradiente sozinho como máscara não chegava a opaco e deixava o app transparecer uns 4%.
            ZStack {
                MolduraComFuro(centro: c, raio: r)
                    .fill(style: FillStyle(eoFill: true))
                if r > 0 {
                    RadialGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 1)],
                        center: UnitPoint(x: c.x / tela.width, y: c.y / tela.height),
                        startRadius: max(0, r - pluma), endRadius: r
                    )
                    .clipShape(Disco(centro: c, raio: r))
                }
            }
        }
    }

    private func rotulo(_ q: QuadroDaAbertura, rastro: [Fantasma], largura: CGFloat, s: CGFloat) -> some View {
        let altura = ParteDaMarca.tamanho.height * s
        // Enquanto o par se cumprimenta, a câmera fica perto e centrada no "ri"; depois se afasta e
        // centra o rótulo inteiro.
        let centroDoPar: CGFloat = (352 + 742) / 2
        let deslocamentoDoPar = (ParteDaMarca.tamanho.width / 2 - centroDoPar) * s * q.zoom * (1 - q.enquadramento)

        return ZStack {
            letra(.f, largura: largura, altura: altura)
                .offset(x: q.fX * s)
                .opacity(q.fOpacidade)
            letra(.l, largura: largura, altura: altura)
                .offset(x: q.lX * s)
                .opacity(q.lOpacidade)
            letra(.a, largura: largura, altura: altura)
                .offset(x: q.aX * s)
                .opacity(q.aOpacidade)

            // Desfoque de movimento: o par alguns milissegundos atrás, mais fraco a cada cópia, por
            // baixo do par de agora. Como a cópia é a própria malha, o rastro dobra junto com o braço.
            ForEach(rastro.indices, id: \.self) { k in
                par(rastro[k].quadro, largura: largura, altura: altura)
                    .compositingGroup()
                    .opacity(rastro[k].opacidade)
            }
            par(q, largura: largura, altura: altura)
        }
        .frame(width: largura, height: altura)
        .scaleEffect(q.zoom)
        .offset(x: deslocamentoDoPar)
    }

    /// O `r` e o `i` são malhas: nascem inteiros, como a fonte os desenha, e formam as mãos no aperto;
    /// o esqueleto de cada um e o campo do par deformam o contorno ponto a ponto (`LetraViva`). O pingo
    /// é a cabeça do `i` e segue o corpo dele. Quando a janela começa a abrir, o pingo dá lugar a ela.
    private func par(_ q: QuadroDaAbertura, largura: CGFloat, altura: CGFloat) -> some View {
        ZStack {
            viva(.r, pose: q.poseDoR, q, largura: largura, altura: altura)
                .opacity(q.rOpacidade)
            ZStack {
                viva(.i, pose: q.poseDoI, q, largura: largura, altura: altura)
                LetraViva(parte: .pingo, pose: q.poseDoI, campo: q.campo,
                          escalaPropria: q.pingoEscala, yProprio: q.pingoY)
                    .fill(FrilaCor.sobreAcao)
                    .frame(width: largura, height: altura)
                    .opacity(q.abertura > 0 ? 0 : 1)
            }
            .opacity(q.iOpacidade)
        }
    }

    private func letra(_ parte: ParteDaMarca, largura: CGFloat, altura: CGFloat) -> some View {
        FormaDaMarca(parte: parte)
            .fill(FrilaCor.sobreAcao, style: FillStyle(eoFill: parte.precisaDeParImpar))
            .frame(width: largura, height: altura)
    }

    private func viva(_ parte: ParteDaMarca, pose: PoseDaLetra, _ q: QuadroDaAbertura,
                      largura: CGFloat, altura: CGFloat) -> some View {
        LetraViva(parte: parte, pose: pose, campo: q.campo, maos: q.maos)
            .fill(FrilaCor.sobreAcao)
            .frame(width: largura, height: altura)
    }
}

/// O fundo da abertura com um furo redondo, por onde o app aparece.
private struct MolduraComFuro: Shape {
    let centro: CGPoint
    let raio: CGFloat

    func path(in rect: CGRect) -> Path {
        var caminho = Path(rect)
        if raio > 0 {
            caminho.addPath(Disco(centro: centro, raio: raio).path(in: rect))
        }
        return caminho
    }
}

/// O furo em si: onde a borda esfumada é desenhada.
private struct Disco: Shape {
    let centro: CGPoint
    let raio: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(x: centro.x - raio, y: centro.y - raio, width: raio * 2, height: raio * 2))
    }
}

/// Uma cópia do par num instante pouco atrás, para o desfoque de movimento.
private struct Fantasma {
    let quadro: QuadroDaAbertura
    let opacidade: Double
}

/// Quando o relógio da abertura começou: no primeiro quadro desenhado. É uma referência sem
/// observação de propósito: marcar o início dentro do desenho não pode pedir outro desenho.
@MainActor
private final class RelogioDaAbertura {
    private(set) var inicio: Date?

    func marcar(_ data: Date) -> Date {
        if let inicio { return inicio }
        inicio = data
        return data
    }

    func zerar() {
        inicio = nil
    }

    /// Espera o primeiro quadro. Se ele não vier em 1 s (o app foi para o fundo, por exemplo), o
    /// relógio começa agora, para a abertura não ficar presa.
    func esperarInicio() async throws -> Date {
        let limite = Date().addingTimeInterval(1)
        while inicio == nil, Date() < limite {
            try await Task.sleep(for: .milliseconds(8))
        }
        return marcar(Date())
    }
}

// MARK: - Prévia

/// A montagem que a raiz do app faz: o app por baixo, a abertura por cima e o rótulo de destino na tela.
private struct MontagemDePrevia: View {
    let comDestino: Bool
    @State private var cobrindo = true
    @State private var destino: CGRect?
    @State private var escalaDoApp: CGFloat = 1

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                RotuloDaMarca()
                    .frame(height: 32)
                    .destinoDoRotuloDaAbertura(ativo: comDestino)
                Spacer()
            }
            .padding(FrilaEspaco.grupo)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(FrilaCor.fundo)
            .scaleEffect(escalaDoApp)
            .environment(\.aberturaCobrindo, cobrindo)
            if cobrindo {
                AberturaAnimada(destinoDoRotulo: destino, escalaDoApp: $escalaDoApp) { cobrindo = false }
            }
        }
        .onPreferenceChange(DestinoDoRotuloDaAbertura.self) { destino = $0 }
    }
}

#Preview("Abertura com destino") {
    MontagemDePrevia(comDestino: true)
}

#Preview("Abertura sem destino") {
    MontagemDePrevia(comDestino: false)
}
