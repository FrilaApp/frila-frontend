import SwiftUI

/// A arte da entrada (D-DS-21): a Turma em três camadas de profundidade (o cozinheiro atrás, a atendente no meio e
/// o barman na frente), a chave e o copo, soltos, sem mancha atrás. Paradas, as três camadas da Turma refazem a
/// arte inteira (1376 × 880 unidades, as posições da arte original). Desenho do Fabrício, portado sem o Laboratório.
///
/// **Paralaxe desligado**, como no protótipo (decisão de 14/11): a Turma não segue o aparelho e nenhum sensor liga.
/// O `MovimentoDoAparelho` e as chaves de relevo ficaram no repositório dele.
///
/// **Entrada.** Enquanto a abertura cobre (`aberturaCobrindo`), a arte espera. Quando a abertura sai, as camadas
/// entram em sequência: a Turma esmaece subindo um pouco, e o copo e a chave chegam depois, crescendo com uma
/// pequena sobra. Acontece uma vez por montagem da tela. Sem abertura (`aberturaCobrindo` falso desde o início),
/// ela entra assim que a tela monta. Com "Reduzir movimento", nada se desloca: a entrada é só o esmaecimento em
/// sequência.
///
/// **Parada**, a chave e o copo flutuam devagar e fora de fase. Com `ativa` falso (teclado aberto, tela do código
/// por cima) ou com o app fora de foco, a flutuação para numa rampa de 0,4 s, sem salto.
///
/// A entrada da arte (0,82 s) é da arte, não do roteiro da abertura: a duração da abertura não a muda.
struct IlustracaoDeBoasVindas: View {
    /// Falso quando a entrada não está à frente (teclado aberto, tela do código por cima): a arte para de flutuar.
    let ativa: Bool

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.scenePhase) private var fase
    @Environment(\.aberturaCobrindo) private var aberturaCobrindo
    @State private var inicioDaEntrada: Date?
    @State private var entradaConcluida = false
    /// Depois de desativar, a flutuação sai numa rampa antes de o desenho parar.
    @State private var assentando = false
    /// Quando `animada` mudou pela última vez: a flutuação entra e sai numa rampa, sem salto.
    @State private var mudouEm = Date.distantPast

    static let proporcao: CGFloat = 1376.0 / 880.0
    private static let quadro = CGSize(width: 1376, height: 880)
    private static let rampaDaFlutuacao: TimeInterval = 0.4

    private var animada: Bool {
        ativa && !reduzirMovimento && fase == .active
    }

    private var entrando: Bool {
        inicioDaEntrada != nil && !entradaConcluida
    }

    var body: some View {
        TimelineView(AnimationTimelineSchedule(minimumInterval: nil, paused: !(animada || entrando || assentando))) { contexto in
            desenho(em: contexto.date)
        }
        .aspectRatio(Self.proporcao, contentMode: .fit)
        // Marca a mudança na mesma atualização em que `animada` muda (a `.task` só roda depois do desenho), para a
        // rampa da flutuação não pular um quadro.
        .onChange(of: animada) { mudouEm = .now }
        .task(id: animada) {
            if animada {
                assentando = false
            } else {
                assentando = true
                try? await Task.sleep(for: .seconds(Self.rampaDaFlutuacao + 0.05))
                if !Task.isCancelled { assentando = false }
            }
        }
        .onChange(of: aberturaCobrindo, initial: true) { _, cobrindo in
            guard !cobrindo, inicioDaEntrada == nil else { return }
            inicioDaEntrada = .now
        }
        .task(id: inicioDaEntrada) {
            guard inicioDaEntrada != nil, !entradaConcluida else { return }
            try? await Task.sleep(for: .seconds(EntradaDaArte.duracao + 0.05))
            if !Task.isCancelled { entradaConcluida = true }
        }
        .accessibilityHidden(true)
    }

    private func desenho(em data: Date) -> some View {
        let entrada = EntradaDaArte(no: tempoDaEntrada(em: data), comMovimento: !reduzirMovimento)
        // Flutuação: ±1,2% da altura, em 3,6 s e 4,2 s, fora de fase. Entra e sai numa rampa de 0,4 s quando a
        // arte liga ou desliga.
        let rampa = min(max(data.timeIntervalSince(mudouEm) / Self.rampaDaFlutuacao, 0), 1)
        let intensidade = reduzirMovimento ? 0 : (animada ? rampa : 1 - rampa)
        let segundos = data.timeIntervalSinceReferenceDate
        let flutuacaoDaChave = intensidade * 0.012 * sin(2 * .pi * segundos / 3.6)
        let flutuacaoDoCopo = intensidade * 0.012 * sin(2 * .pi * segundos / 4.2 + 1.3)

        return GeometryReader { geometria in
            let w = geometria.size.width, h = geometria.size.height
            ZStack(alignment: .topLeading) {
                peca("TurmaCozinheiro", x: 0, y: 0, largura: 1376, altura: 880, w: w, h: h, entrada.turma)
                peca("TurmaAtendente", x: 0, y: 0, largura: 1376, altura: 880, w: w, h: h, entrada.turma)
                peca("TurmaBarman", x: 0, y: 0, largura: 1376, altura: 880, w: w, h: h, entrada.turma)
                peca("CopoDaTurma", x: 469.15, y: 59.48, largura: 74, altura: 99, w: w, h: h, entrada.copo)
                    .offset(y: flutuacaoDoCopo * h)
                peca("ChaveDaTurma", x: 787, y: 1, largura: 113, altura: 131, w: w, h: h, entrada.chave)
                    .offset(y: flutuacaoDaChave * h)
            }
        }
    }

    /// Segundos desde o começo da entrada; antes dela, negativo (tudo invisível).
    private func tempoDaEntrada(em data: Date) -> TimeInterval {
        guard let inicioDaEntrada else { return -1 }
        return entradaConcluida ? EntradaDaArte.duracao : data.timeIntervalSince(inicioDaEntrada)
    }

    /// Uma peça no quadro de 1376 × 880, pelo canto de cima à esquerda e pelo tamanho em unidades, no estado da
    /// entrada. A escala é em torno do centro da própria peça, antes de posicioná-la.
    private func peca(_ nome: String, x: CGFloat, y: CGFloat, largura: CGFloat, altura: CGFloat,
                      w: CGFloat, h: CGFloat, _ camada: EntradaDaArte.Camada) -> some View {
        Image(nome, bundle: bundleApresentacao)
            .resizable()
            .frame(width: largura / Self.quadro.width * w, height: altura / Self.quadro.height * h)
            .scaleEffect(camada.escala)
            .position(x: (x + largura / 2) / Self.quadro.width * w, y: (y + altura / 2) / Self.quadro.height * h)
            .offset(y: camada.y)
            .opacity(camada.opacidade)
    }
}

// MARK: - Entrada em camadas

/// O estado de cada camada na entrada: a Turma primeiro, em 0,55 s, saindo rápido e assentando devagar; o copo
/// 0,22 s depois e a chave 0,32 s depois, em 0,5 s, crescendo com uma sobra pequena (curva com recuo), porque são
/// os objetos que "chegam" à cena.
struct EntradaDaArte {
    struct Camada {
        var opacidade = 1.0, y = 0.0, escala = 1.0
    }

    static let duracao: TimeInterval = 0.82

    var turma = Camada(), copo = Camada(), chave = Camada()

    init(no t: TimeInterval, comMovimento: Bool) {
        turma = Self.camada(t, atraso: 0, duracao: 0.55, subida: 14, escalaInicial: 0.96, sobra: false, comMovimento)
        copo = Self.camada(t, atraso: 0.22, duracao: 0.5, subida: 18, escalaInicial: 0.6, sobra: true, comMovimento)
        chave = Self.camada(t, atraso: 0.32, duracao: 0.5, subida: 18, escalaInicial: 0.6, sobra: true, comMovimento)
    }

    private static func camada(_ t: TimeInterval, atraso: Double, duracao: Double, subida: Double,
                               escalaInicial: Double, sobra: Bool, _ comMovimento: Bool) -> Camada {
        let x = min(max((t - atraso) / duracao, 0), 1)
        // Sai rápido e assenta devagar (cúbica); a escala dos objetos passa um pouco de 1 e volta.
        let suave = 1 - pow(1 - x, 3)
        let comSobra: Double = {
            let c1 = 1.4, c3 = c1 + 1
            return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
        }()
        let opacidade = min(x / 0.6, 1)
        guard comMovimento else { return Camada(opacidade: opacidade) }
        return Camada(opacidade: opacidade,
                      y: subida * (1 - suave),
                      escala: escalaInicial + (1 - escalaInicial) * (sobra ? comSobra : suave))
    }
}

#Preview("Arte da entrada") {
    IlustracaoDeBoasVindas(ativa: true)
        .padding(FrilaEspaco.grupo)
        .background(FrilaCor.fundo)
}
