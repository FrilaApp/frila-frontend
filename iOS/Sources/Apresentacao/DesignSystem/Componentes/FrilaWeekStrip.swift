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
/// Estados da célula: neutra (dia sem horário), preenchida (fundo neutro do campo) e selecionada
/// (contorno de 2 pt por dentro, no Quente do botão de escolher funções, e texto em peso maior). Preenchida e selecionada somam os dois. A célula tem o raio
/// concêntrico do contêiner que a abriga: raio do contêiner menos o recuo.
///
/// Movimento (03/11/2026): o contorno não viaja de um dia ao outro. Ele dissolve no dia que sai e nasce no que entra,
/// num relógio de 340 ms em que espessura, escala e opacidade andam pela mesma curva de arrancada. Os rótulos reagem com um pop.
/// Cada dia tem a sua trajetória, então um toque no meio da troca redireciona sem salto (ver `FrilaTrilha`).
public struct FrilaWeekStrip: View {
    private let dias: [FrilaWeekStripDia]
    private let selecionado: Int
    private let aoSelecionar: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    @State private var estado: EstadoDaFaixa
    @State private var emCurso = false
    @State private var geracao = 0
    @State private var tarefaDeFim: Task<Void, Never>?
    @State private var gatilhoDeToque = 0

    public init(dias: [FrilaWeekStripDia], selecionado: Int, aoSelecionar: @escaping (Int) -> Void) {
        self.dias = dias
        self.selecionado = selecionado
        self.aoSelecionar = aoSelecionar
        _estado = State(initialValue: EstadoDaFaixa(alvo: selecionado))
    }

    public var body: some View {
        TimelineView(AnimationTimelineSchedule(minimumInterval: nil, paused: !emCurso)) { contexto in
            // Parada a agenda, o desenho vai direto ao fim das trajetórias: nenhum quadro intermediário preso.
            let agora = emCurso && !reduzirMovimento ? contexto.date.timeIntervalSinceReferenceDate : .infinity
            HStack(spacing: FrilaEspaco.minimo) {
                ForEach(dias) { dia in
                    celula(dia, presenca: estado.presenca(dia.id).amostra(agora).valor, escalaDoRotulo: estado.rotulo(dia.id).amostra(agora).valor)
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: FrilaMotion.semanaHapticIntensidade), trigger: gatilhoDeToque)
        .onChange(of: selecionado) { antigo, novo in trocar(de: antigo, para: novo) }
        .onAppear { assentar() }
        .onDisappear {
            tarefaDeFim?.cancel()
            geracao += 1
            emCurso = false
        }
    }

    // MARK: Célula

    private func celula(_ dia: FrilaWeekStripDia, presenca: Double, escalaDoRotulo: Double) -> some View {
        let ativo = dia.id == selecionado
        return Button {
            // Háptico só na ação de trocar de dia, antes do callback; seleção vinda de fora anima sem pulso.
            if dia.id != selecionado { gatilhoDeToque += 1 }
            aoSelecionar(dia.id)
        } label: {
            Text(verbatim: dia.rotulo)
                .font(ativo ? FrilaTipo.chip.weight(.bold) : FrilaTipo.chip)
                .foregroundStyle(ativo || dia.preenchido ? FrilaCor.texto : FrilaCor.textoSecundario)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .scaleEffect(escalaDoRotulo)
                // Cor, peso e escala vêm do relógio: nada de animação herdada do pai (240 ms) por cima.
                .transaction { $0.animation = nil }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                        .fill(dia.preenchido ? FrilaCor.superficieDoCampo : Color.clear)
                        .animation(FrilaMovimento.animacao(FrilaMotion.horarioDestaque, reduzir: reduzirMovimento), value: dia.preenchido)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous)
                        .strokeBorder(FrilaCor.quente, lineWidth: Self.espessura(presenca))
                        .scaleEffect(FrilaMotion.semanaDestaqueEscalaOculta + (1 - FrilaMotion.semanaDestaqueEscalaOculta) * presenca)
                        .opacity(presenca)
                        .transaction { $0.animation = nil }
                        .allowsHitTesting(false)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(CelulaDaFaixaSemanal())
        .accessibilityAddTraits(ativo ? .isSelected : [])
        .accessibilityIdentifier("dia-semana-\(dia.id)")
    }

    /// Espessura do contorno para a presença p: 2 pt em p = 1, mais um inchaço para dentro que passa por 0 nas pontas
    /// e chega a `semanaDestaqueEspessuraExtra` em p = 0,5.
    private static func espessura(_ p: Double) -> CGFloat {
        FrilaMotion.semanaDestaqueEspessura * CGFloat(p) + FrilaMotion.semanaDestaqueEspessuraExtra * CGFloat(4 * p * (1 - p))
    }

    // MARK: Trocas

    private func agora() -> Double { Date().timeIntervalSinceReferenceDate }

    /// Primeiro desenho e retorno à tela: tudo em repouso no dia que está valendo, sem animação de entrada.
    private func assentar() {
        estado = EstadoDaFaixa(alvo: selecionado)
        emCurso = false
    }

    private func trocar(de antigo: Int, para novo: Int) {
        guard !reduzirMovimento else {
            assentar()
            return
        }
        let t = agora()
        let ids = Set(dias.map(\.id) + [antigo, novo])
        estado.redirecionar(para: novo, de: antigo, ids: ids, em: t)
        agendarFim(depoisDe: estado.fim)
    }

    /// Uma só tarefa cancelável por faixa: pausa a agenda quando a última trajetória em curso acaba. Estender o
    /// prazo cancela a anterior, e a geração impede uma tarefa velha de parar a agenda de uma troca mais nova.
    private func agendarFim(depoisDe fim: Double) {
        tarefaDeFim?.cancel()
        geracao += 1
        let minha = geracao
        emCurso = true
        let espera = max(fim - agora(), 0) + 0.03
        tarefaDeFim = Task { @MainActor in
            try? await Task.sleep(for: .seconds(espera))
            guard !Task.isCancelled, geracao == minha else { return }
            emCurso = false
        }
    }
}

// MARK: - Trajetórias

/// Um trecho de uma trajetória: quíntica de `de` a `para`, ou frenagem a desaceleração constante a partir de `v0`.
private struct Trecho {
    var inicio: Double
    var duracao: Double
    var de: Double
    var para: Double
    /// Velocidade inicial de uma frenagem (a velocidade final é 0). `nil` num trecho de quíntica.
    var velocidadeInicial: Double?
    /// Curva de arrancada do contorno (ease-out) em vez da quíntica suave dos pops.
    var arrancada = false

    var fim: Double { inicio + duracao }

    static func quintica(inicio: Double, duracao: Double, de: Double, para: Double) -> Trecho {
        Trecho(inicio: inicio, duracao: duracao, de: de, para: para, velocidadeInicial: nil)
    }

    static func contorno(inicio: Double, duracao: Double, de: Double, para: Double) -> Trecho {
        Trecho(inicio: inicio, duracao: duracao, de: de, para: para, velocidadeInicial: nil, arrancada: true)
    }

    static func freio(inicio: Double, duracao: Double, de: Double, velocidade: Double) -> Trecho {
        Trecho(inicio: inicio, duracao: duracao, de: de, para: de + velocidade * duracao / 2, velocidadeInicial: velocidade)
    }

    func amostra(_ t: Double) -> (valor: Double, velocidade: Double) {
        let tau = min(max(t - inicio, 0), duracao)
        if let v0 = velocidadeInicial {
            // v(τ) = v0 (1 − τ/d): chega a 0 em d. Valor = de + v0 τ − v0 τ² / 2d.
            return (de + v0 * tau - v0 * tau * tau / (2 * duracao), v0 * (1 - tau / duracao))
        }
        let u = tau / duracao
        if arrancada {
            return (
                de + (para - de) * FrilaMotion.semanaContornoProgresso(u),
                (para - de) * FrilaMotion.semanaContornoDerivada(u) / duracao
            )
        }
        return (
            de + (para - de) * FrilaMotion.semanaDestaqueProgresso(u),
            (para - de) * FrilaMotion.semanaDestaqueDerivada(u) / duracao
        )
    }
}

/// Trajetória de um valor ao longo do tempo (presença do contorno ou escala do rótulo), feita de trechos em sequência
/// com valor e velocidade contínuos nas junções. Amostrar em `.infinity` devolve o fim.
private struct FrilaTrilha {
    var repouso: Double
    var trechos: [Trecho] = []

    var valorFinal: Double { trechos.last?.para ?? repouso }
    var fim: Double { trechos.last?.fim ?? 0 }

    func amostra(_ t: Double) -> (valor: Double, velocidade: Double) {
        guard let primeiro = trechos.first else { return (repouso, 0) }
        if t < primeiro.inicio { return (primeiro.de, 0) }
        for trecho in trechos where t < trecho.fim {
            return trecho.amostra(t)
        }
        return (valorFinal, 0)
    }

    /// Frenagem para interromper no instante `t` sem salto de velocidade, em até 24 ms e sem passar dos limites:
    /// a folga até o limite na direção do movimento comporta o deslocamento v·b/2 (a metade dela, no máximo).
    /// Devolve os trechos de freio (se houver), o valor e o instante em que a trajetória fica em repouso.
    func frear(em t: Double, limites: ClosedRange<Double>) -> (trechos: [Trecho], valor: Double, instante: Double) {
        let (valor, velocidade) = amostra(t)
        guard abs(velocidade) > 1e-9 else { return ([], valor, t) }
        let folga = velocidade > 0 ? limites.upperBound - valor : valor - limites.lowerBound
        guard folga > 1e-9 else { return ([], valor, t) }
        let duracao = min(FrilaMotion.semanaInterrupcaoFreioMaximo, folga / abs(velocidade))
        let freio = Trecho.freio(inicio: t, duracao: duracao, de: valor, velocidade: velocidade)
        return ([freio], freio.para, t + duracao)
    }

    /// Presença do contorno: frena e segue pela curva de arrancada até o destino (0 ou 1). A entrada que parte do
    /// repouso espera 60 ms (a saída abre espaço primeiro); interrompida no meio, vai direto, sem espera.
    mutating func irPara(_ destino: Double, em t: Double) {
        let freio = frear(em: t, limites: 0...1)
        var novos = freio.trechos
        var inicio = freio.instante
        if destino == 1, freio.trechos.isEmpty, freio.valor < 0.001 {
            novos.append(.quintica(inicio: inicio, duracao: FrilaMotion.semanaDestaqueAtraso, de: 0, para: 0))
            inicio += FrilaMotion.semanaDestaqueAtraso
        }
        novos.append(.contorno(inicio: inicio, duracao: FrilaMotion.semanaDestaqueDuracao, de: freio.valor, para: destino))
        trechos = novos
    }

    /// Pop do rótulo. Parte do valor freado, nunca reinicia em 1, e não repete a compressão que a trajetória interrompida
    /// já passou. Em repouso (valor 1) dá exatamente a tabela nominal; termina em até 24 + 340 ms.
    mutating func pop(entrando: Bool, em t: Double) {
        let piso = Double(FrilaMotion.semanaRotuloSaidaEscala)
        let excesso = Double(FrilaMotion.semanaRotuloEntradaExcesso)
        let freio = frear(em: t, limites: piso...excesso)
        let s = freio.valor
        let folga = 0.0005

        let compressao = Double(FrilaMotion.semanaRotuloEntradaCompressao)
        let passos: [(para: Double, duracao: Double)]
        if entrando {
            let aoExcesso = FrilaMotion.semanaRotuloEntradaExcessoEm - FrilaMotion.semanaRotuloEntradaCompressaoEm
            let aoRepouso = FrilaMotion.semanaDestaqueDuracao - FrilaMotion.semanaRotuloEntradaExcessoEm
            if s > excesso - folga {
                passos = [(1, aoRepouso)]
            } else if s > 1 + folga {
                passos = [(excesso, aoExcesso), (1, aoRepouso)]
            } else if s > compressao + folga {
                passos = [(compressao, FrilaMotion.semanaRotuloEntradaCompressaoEm), (excesso, aoExcesso), (1, aoRepouso)]
            } else {
                passos = [(excesso, aoExcesso), (1, aoRepouso)]
            }
        } else {
            let volta = FrilaMotion.semanaDestaqueDuracao - FrilaMotion.semanaRotuloSaidaPico
            passos = s > piso + folga ? [(piso, FrilaMotion.semanaRotuloSaidaPico), (1, volta)] : [(1, volta)]
        }

        var novos = freio.trechos
        var inicio = freio.instante
        var de = s
        for passo in passos {
            novos.append(.quintica(inicio: inicio, duracao: passo.duracao, de: de, para: passo.para))
            inicio += passo.duracao
            de = passo.para
        }
        trechos = novos
    }
}

/// As sete trajetórias de presença do contorno e as sete de escala do rótulo, por id do dia, mais o dia que vale.
private struct EstadoDaFaixa {
    var alvo: Int
    private var presencas: [Int: FrilaTrilha] = [:]
    private var rotulos: [Int: FrilaTrilha] = [:]

    init(alvo: Int) { self.alvo = alvo }

    func presenca(_ id: Int) -> FrilaTrilha { presencas[id] ?? FrilaTrilha(repouso: id == alvo ? 1 : 0) }
    func rotulo(_ id: Int) -> FrilaTrilha { rotulos[id] ?? FrilaTrilha(repouso: 1) }

    /// Fim da última trajetória ainda em curso, no relógio de referência.
    var fim: Double {
        (presencas.values.map(\.fim) + rotulos.values.map(\.fim)).max() ?? 0
    }

    /// Nova seleção: só mudam as trajetórias cujo destino mudou (o dia que sai e o que entra); as que já iam ao mesmo
    /// destino seguem sem reiniciar. O mesmo dia não faz nada.
    mutating func redirecionar(para novo: Int, de antigo: Int, ids: Set<Int>, em t: Double) {
        guard novo != alvo else { return }
        // `alvo` só muda depois do laço: o repouso padrão de um dia sem trajetória depende dele (1 se é o alvo).
        for id in ids {
            let destino: Double = id == novo ? 1 : 0
            var presenca = self.presenca(id)
            if abs(presenca.valorFinal - destino) > 1e-9 {
                presenca.irPara(destino, em: t)
                presencas[id] = presenca
            }
        }
        var saindo = rotulo(antigo)
        saindo.pop(entrando: false, em: t)
        rotulos[antigo] = saindo
        var entrando = rotulo(novo)
        entrando.pop(entrando: true, em: t)
        rotulos[novo] = entrando
        alvo = novo
    }
}

/// O toque na célula não comprime o conjunto: o feedback de seleção é o pop do rótulo, e somar os dois multiplicaria o efeito.
private struct CelulaDaFaixaSemanal: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
