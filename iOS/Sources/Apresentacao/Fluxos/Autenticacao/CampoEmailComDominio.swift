import SwiftUI
import UIKit
import CoreText

/// Campo de e-mail do Login com predição de domínio.
/// Depois do "@", uma roda vertical mostra o domínio sugerido como um placeholder cinza,
/// com os vizinhos cortados e esmaecidos acima e abaixo. Deslizar troca e confirma;
/// a cápsula com a seta confirma o primeiro candidato manual. Digitar à mão nunca é bloqueado.
struct CampoEmailComDominio: View {
    @Binding var texto: String
    let habilitado: Bool
    let aoEnviar: () -> Void

    @State private var estado = EstadoDoCursor()
    @State private var posicao: Double = 0
    @State private var posicaoNoToque: Double = 0
    @State private var estendido = false
    @State private var tarefaDePreenchimento: Task<Void, Never>?
    @State private var foco = PonteDeFoco()
    @State private var gestoIntencional = false
    @State private var deslocamentoAtual = 0.0
    @State private var deslocamentoNaIntencao = 0.0
    @State private var offsetNaIntencao = 0.0
    @State private var destaque = 0.0
    @State private var acentoCTA = false
    @State private var usouAcentoCTA = false
    @State private var tarefaDoAcento: Task<Void, Never>?
    @State private var transicao: TransicaoDoDominio?
    @State private var tempoDaCadeia = 0.0
    @State private var aguardandoCadeia = false

    private var preenchendo: Bool { transicao != nil }

    private var ctaAtivo: Bool { sugestao.map { !$0.prefixo.isEmpty } == true && !preenchendo }

    /// Distância entre a cápsula e a borda do campo; o raio da cápsula é o do campo menos este valor.
    private let respiro: CGFloat = 6
    private let larguraDaCapsula: CGFloat = 44
    private let passoDaRoda: CGFloat = 24
    /// Durante o deslize o contêiner cresce 40% na vertical, sem empurrar a tela.
    private let crescimento: CGFloat = 1.4

    private var altura: CGFloat { FrilaMetrica.alturaDoCampo }
    private var raioDoCampo: CGFloat { FrilaRaio.entrada }
    private var raioDaCapsula: CGFloat { max(raioDoCampo - respiro, 0) }
    private var reservaDireita: CGFloat { larguraDaCapsula + respiro * 2 }

    private var alturaVisual: CGFloat { estendido ? altura * crescimento : altura }

    private var sugestao: SugestaoDominio? {
        guard habilitado, estado.focado, !preenchendo else { return nil }
        return SugestaoDominio.criar(texto: texto, cursorNoFim: estado.cursorNoFim)
    }

    /// x do fim do texto, medido pela largura (o cursor do UIKit chega atrasado durante o preenchimento).
    private func inicioDaRoda(_ largura: CGFloat) -> CGFloat {
        let medida = (texto as NSString)
            .size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body)]).width
        let limite = max(largura - FrilaEspaco.medio - reservaDireita, 0)
        return FrilaEspaco.medio + min(medida, limite) + 0.5
    }

    var body: some View {
        GeometryReader { geometria in
            let sugestaoAtual = sugestao
            let largura = geometria.size.width
            let inicioX = inicioDaRoda(largura)
            let larguraDaRoda = largura - inicioX - reservaDireita - 4
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: raioDoCampo, style: .continuous)
                    .fill(FrilaCor.superficieDoCampo)
                    .frame(width: largura, height: alturaVisual)
                    .allowsHitTesting(false)
                RoundedRectangle(cornerRadius: raioDoCampo, style: .continuous)
                    .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1)
                    .frame(width: largura, height: alturaVisual)
                    .allowsHitTesting(false)

                CampoEmailNativo(
                    texto: $texto,
                    habilitado: habilitado,
                    reservaDireita: reservaDireita,
                    foco: foco,
                    ocultarTexto: preenchendo,
                    aoInteragir: cancelarPreenchimento,
                    aoEnviar: aoEnviar,
                    aoMudarCursor: { novo in estado = novo }
                )
                .frame(width: largura, height: altura)

                if let transicao {
                    PreenchimentoPorBlocos(transicao: transicao, tempo: tempoDaCadeia, mostrarGhost: !aguardandoCadeia,
                                           baseline: estado.baseline, linhaDoCursor: estado.linhaDoCursor)
                        .frame(width: max(0, largura - FrilaEspaco.medio - reservaDireita), height: altura)
                        .clipped()
                        .offset(x: FrilaEspaco.medio)
                        .allowsHitTesting(false)
                        .id(transicao.id)
                        .onAppear { animarCadeia(transicao) }

                    if aguardandoCadeia {
                        let inicio = min(medir(transicao.textoAnterior), max(0, largura - FrilaEspaco.medio - reservaDireita)) + FrilaEspaco.medio + 0.5
                        RodaDeDominios(sugestao: transicao.sugestao, posicao: Double(transicao.posicao),
                                       passo: passoDaRoda, interacao: destaque)
                            .frame(width: max(0, largura - inicio - reservaDireita - 4), height: alturaVisual, alignment: .leading)
                            .offset(x: inicio)
                            .allowsHitTesting(false)
                    }
                }

                if let sugestaoAtual, larguraDaRoda >= 56 {
                    RodaDeDominios(sugestao: sugestaoAtual, posicao: preenchendo ? 0 : posicao, passo: passoDaRoda, interacao: destaque)
                        .frame(width: larguraDaRoda, height: alturaVisual, alignment: .leading)
                        .offset(x: inicioX)
                        .allowsHitTesting(false)

                    AreaDeGestosDaRoda(
                        habilitada: sugestaoAtual.candidatos.count > 1 && !preenchendo,
                        aoTocar: { cancelarPreenchimento(); posicao = 0; destaque = 0; foco.focar() },
                        aoInterromper: {
                            if preenchendo || tarefaDeEncaixe != nil { cancelarPreenchimento(); posicao = 0 }
                        },
                        aoComecar: {
                            tarefaDeEncaixe?.cancel()
                            tarefaDeEncaixe = nil
                            menorPosicaoVista = posicao.rounded()
                            maiorPosicaoVista = posicao.rounded()
                            posicaoNoToque = posicao.rounded()
                            gestoIntencional = false
                            deslocamentoAtual = 0
                            ultimoPasso = Int(posicao.rounded())
                            geradorDeSelecao.prepare()
                        },
                        aoArrastar: { deslocamento, velocidade in arrastar(deslocamento, velocidade: velocidade) },
                        aoSoltar: { velocidade in soltar(sugestao: sugestaoAtual, velocidade: velocidade) },
                        aoCancelar: {
                            tarefaDeEncaixe?.cancel()
                            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.12)) {
                                posicao = posicaoNoToque.rounded()
                                destaque = 0
                                estendido = false
                            }
                        }
                    )
                    .frame(width: larguraDaRoda, height: alturaVisual)
                    .offset(x: inicioX)
                }

                if let sugestaoAtual, !preenchendo {
                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            confirmar(sugestao: sugestaoAtual, posicao: 0)
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(ctaAtivo ? FrilaCor.sobreSelecao : FrilaCor.textoSecundario)
                                .frame(width: larguraDaCapsula, height: alturaVisual - respiro * 2)
                                .background {
                                    ZStack(alignment: .leading) {
                                        FrilaCor.controle
                                        FrilaCor.selecao.opacity(sugestaoAtual.prefixoUnico ? 1 : 0.65)
                                            .scaleEffect(x: ctaAtivo ? 1 : 0, y: 1, anchor: .leading)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: raioDaCapsula, style: .continuous))
                                }
                                .scaleEffect(acentoCTA ? 1.015 : 1)
                                .animation(.timingCurve(0.16, 1, 0.3, 1, duration: ctaAtivo ? 0.12 : 0.08), value: ctaAtivo)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, respiro)
                        .accessibilityIdentifier("entrada-email-dominio-confirmar")
                    }
                    .frame(width: largura, height: altura)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .frame(width: largura, height: altura)
            // Expande sem reflow; conserva 2 pt dos 8 pt que separam o rótulo.
            .offset(y: estendido ? max(0, (alturaVisual - altura) / 2 - 6) : 0)
            .animation(!preenchendo ? .snappy(duration: 0.18) : nil, value: sugestaoAtual != nil)
            .animation(.timingCurve(0.16, 1, 0.3, 1, duration: estendido ? 0.15 : 0.12), value: estendido)
        }
        .frame(height: altura)
        .onChange(of: sugestao?.prefixo) { _, _ in
            if !preenchendo { posicao = 0 }
        }
        .onChange(of: texto) { _, novo in
            if tarefaDeEncaixe != nil {
                tarefaDeEncaixe?.cancel()
                tarefaDeEncaixe = nil
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.12)) { estendido = false }
            }
            if preenchendo, novo != textoEsperado { cancelarPreenchimento() }
        }
        .onChange(of: ctaAtivo) { _, ativo in
            guard ativo, !usouAcentoCTA else { return }
            usouAcentoCTA = true
            tarefaDoAcento = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                guard ctaAtivo else { return }
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.05)) { acentoCTA = true }
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                withAnimation(.spring(duration: 0.14, bounce: 0.04)) { acentoCTA = false }
            }
        }
        .onChange(of: estado.focado) { _, focado in
            if !focado { usouAcentoCTA = false; tarefaDoAcento?.cancel(); acentoCTA = false }
            if !focado { cancelarPreenchimento() }
        }
        .onChange(of: estado.cursorNoFim) { _, noFim in
            if !noFim { cancelarPreenchimento() }
        }
        .onChange(of: habilitado) { _, habilitado in
            if !habilitado { cancelarPreenchimento() }
        }
        .onDisappear { cancelarPreenchimento() }
    }

    // MARK: Gesto da roda

    @State private var textoEsperado = ""
    @State private var ultimoPasso = 0
    @State private var ultimoTique = ContinuousClock.now
    @State private var menorPosicaoVista = 0.0
    @State private var maiorPosicaoVista = 0.0
    @State private var tarefaDeEncaixe: Task<Void, Never>?
    private let geradorDeSelecao = UISelectionFeedbackGenerator()

    private func arrastar(_ deslocamento: CGFloat, velocidade: CGFloat) {
        deslocamentoAtual = Double(deslocamento)
        if !gestoIntencional {
            let offset = LimiarDaRoda.resistencia(deslocamentoAtual)
            if LimiarDaRoda.intencional(deslocamento: deslocamentoAtual, velocidade: Double(velocidade)) {
                gestoIntencional = true
                deslocamentoNaIntencao = deslocamentoAtual
                offsetNaIntencao = offset
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.15)) { estendido = true; destaque = 1 }
            } else {
                posicao = posicaoNoToque - offset / Double(passoDaRoda)
                return
            }
        }
        let efetivo = offsetNaIntencao + deslocamentoAtual - deslocamentoNaIntencao
        let alvo = posicaoNoToque - efetivo / Double(passoDaRoda)
        posicao = alvo
        menorPosicaoVista = min(menorPosicaoVista, alvo.rounded())
        maiorPosicaoVista = max(maiorPosicaoVista, alvo.rounded())
        let limite = 0.5 + 2 / Double(passoDaRoda)
        if abs(alvo - Double(ultimoPasso)) >= limite {
            ultimoPasso = Int(alvo.rounded())
            let agora = ContinuousClock.now
            if ultimoTique.duration(to: agora) >= .milliseconds(50) {
                geradorDeSelecao.selectionChanged()
                ultimoTique = agora
            }
        }
    }

    private func soltar(sugestao: SugestaoDominio, velocidade: CGFloat) {
        tarefaDeEncaixe?.cancel()
        let origem = posicao
        let intencional = LimiarDaRoda.intencional(deslocamento: deslocamentoAtual, velocidade: Double(velocidade))
        let duracao = intencional ? 0.24 : 0.14
        let bounce = intencional ? 0.12 : 0.08
        withAnimation(.easeOut(duration: 0.12)) { destaque = 0 }
        let velocidadeEmItens = -Double(velocidade / passoDaRoda)
        let projecao = min(0.35, max(-0.35, velocidadeEmItens * 0.06))
        let direcao = deslocamentoAtual < 0 ? 1.0 : -1.0
        let projetado = (origem + projecao).rounded()
        let alvo = intencional ? (projetado == posicaoNoToque ? posicaoNoToque + direcao : projetado) : posicaoNoToque
        let distancia = alvo - origem
        let velocidadeNormalizada = distancia == 0 ? 0 : velocidadeEmItens / distancia
        let velocidadeInicial = velocidadeNormalizada * distancia
        let inicial = texto
        tarefaDeEncaixe = Task { @MainActor in
            let relogio = ContinuousClock()
            let inicio = relogio.now
            let spring = Spring(duration: duracao, bounce: bounce)
            while inicio.duration(to: relogio.now) < .seconds(duracao) {
                guard !Task.isCancelled, preenchimentoValido(inicial) else { return }
                let decorrido = inicio.duration(to: relogio.now)
                let segundos = Double(decorrido.components.seconds) + Double(decorrido.components.attoseconds) / 1e18
                posicao = spring.value(fromValue: origem, toValue: alvo, initialVelocity: velocidadeInicial, time: segundos)
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
            guard !Task.isCancelled, preenchimentoValido(inicial) else { return }
            posicao = alvo
            if Int(alvo) != Int(posicaoNoToque.rounded()) {
                tarefaDeEncaixe = nil
                confirmar(sugestao: sugestao, posicao: Int(alvo), espera: 200)
            } else {
                tarefaDeEncaixe = nil
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.12)) { estendido = false }
            }
        }
    }

    // MARK: Confirmação com preenchimento animado

    /// Seta e roda confirmam o valor inteiro antes da apresentação por blocos.
    private func confirmar(sugestao: SugestaoDominio, posicao: Int, espera: Int = 0) {
        guard preenchimentoValido(texto),
              sugestao == SugestaoDominio.criar(texto: texto, cursorNoFim: estado.cursorNoFim) else { return }
        let escolhido = sugestao.candidato(em: posicao)
        let restante = sugestao.restante(de: escolhido)
        guard !restante.isEmpty else { return }
        cancelarPreenchimento()
        // Só uma apresentação nova começa em zero; a camada que sai conserva seu quadro final.
        tempoDaCadeia = 0
        estendido = espera > 0
        aguardandoCadeia = espera > 0
        transicao = TransicaoDoDominio(textoAnterior: texto, sugestao: sugestao, posicao: posicao,
                                      espera: espera, cadeia: CadeiaDoDominio(restante: restante))
        textoEsperado = texto + restante
        texto = textoEsperado
        if espera > 0 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func animarCadeia(_ apresentacao: TransicaoDoDominio) {
        tarefaDePreenchimento = Task { @MainActor in
            guard !Task.isCancelled, transicao?.id == apresentacao.id else { return }
            // O campo se recolhe dentro do dwell, antes de começar a troca de texto.
            // Assim o fill inteiro e o campo nativo final compartilham a mesma origem.
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.12)) { estendido = false }
            if apresentacao.espera > 0 {
                do { try await Task.sleep(for: .milliseconds(apresentacao.espera)) } catch { return }
            }
            guard transicao?.id == apresentacao.id else { return }
            guard preenchimentoValido(textoEsperado) else { cancelarPreenchimento(); return }
            aguardandoCadeia = false
            // Relógio uniforme; o cronograma aplica a Bézier de conjunto e a curva de cada bloco.
            withAnimation(.linear(duration: apresentacao.cadeia.duracao), completionCriteria: .logicallyComplete) {
                tempoDaCadeia = apresentacao.cadeia.duracao
            } completion: {
                guard transicao?.id == apresentacao.id else { return }
                cancelarPreenchimento()
                self.posicao = 0
            }
        }
    }

    private func medir(_ valor: String) -> CGFloat {
        (valor as NSString).size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body)]).width
    }

    private func preenchimentoValido(_ esperado: String) -> Bool {
        guard !Task.isCancelled, habilitado, texto == esperado,
              let campo = foco.campo, campo.isFirstResponder, campo.markedTextRange == nil,
              let selecao = campo.selectedTextRange, selecao.isEmpty else { return false }
        return campo.compare(selecao.start, to: campo.endOfDocument) == .orderedSame
    }

    private func cancelarPreenchimento() {
        // Remover a apresentação revela imediatamente o UITextField com o valor final.
        var transacao = Transaction()
        transacao.disablesAnimations = true
        withTransaction(transacao) { transicao = nil; aguardandoCadeia = false }
        tarefaDeEncaixe?.cancel()
        tarefaDeEncaixe = nil
        tarefaDePreenchimento?.cancel()
        tarefaDePreenchimento = nil
        destaque = 0
        estendido = false
    }
}

private struct TransicaoDoDominio {
    let id = UUID()
    let textoAnterior: String
    let sugestao: SugestaoDominio
    let posicao: Int
    let espera: Int
    let cadeia: CadeiaDoDominio
}

/// Fade do ghost e entrada integral do restante, com blur curto como máscara da troca.
/// O cursor visual acompanha a largura interpolada; o cursor nativo já está no fim real.
private struct PreenchimentoPorBlocos: View, Animatable {
    let transicao: TransicaoDoDominio
    var tempo: Double
    let mostrarGhost: Bool
    let baseline: CGFloat
    let linhaDoCursor: CGRect

    nonisolated var animatableData: Double {
        get { tempo }
        set { tempo = newValue }
    }

    var body: some View {
        GeometryReader { geometria in
            let fonte = UIFont.preferredFont(forTextStyle: .body)
            let blocos = transicao.cadeia.blocos
            let completo = transicao.textoAnterior + blocos.map(\.texto).joined()
            let linha = CTLineCreateWithAttributedString(NSAttributedString(string: completo, attributes: [.font: fonte]))
            let anterior = CTLineGetOffsetForStringIndex(linha, transicao.textoAnterior.utf16.count, nil)
            let limites = blocos.reduce(into: [transicao.textoAnterior.utf16.count]) { $0.append($0.last! + $1.texto.utf16.count) }
                .map { CTLineGetOffsetForStringIndex(linha, $0, nil) }
            let larguras = blocos.indices.map { limites[$0 + 1] - limites[$0] }
            let largura = anterior + blocos.indices.reduce(CGFloat.zero) { $0 + larguras[$1] * blocos[$1].progresso(em: tempo) }
            let recuo = max(0, largura - max(0, geometria.size.width - 2))
            ZStack(alignment: .leading) {
                TextoNaBaselineDoCampo(texto: completo, baseline: baseline, altura: geometria.size.height)
                    .mask(alignment: .leading) { Rectangle().frame(width: anterior) }
                ForEach(blocos.indices, id: \.self) { indice in
                    let progresso = blocos[indice].progresso(em: tempo)
                    let inicio = limites[indice]
                    ZStack(alignment: .leading) {
                        if mostrarGhost {
                            TextoNaBaselineDoCampo(texto: completo, baseline: baseline, altura: geometria.size.height)
                                .mask(alignment: .leading) { Rectangle().frame(width: larguras[indice]).offset(x: inicio) }
                                .opacity(0.38 * (1 - progresso))
                        }
                        TextoNaBaselineDoCampo(texto: completo, baseline: baseline, altura: geometria.size.height)
                            .mask(alignment: .leading) { Rectangle().frame(width: larguras[indice]).offset(x: inicio) }
                            .blur(radius: 6 * (1 - progresso))
                            .opacity(progresso)
                    }
                    .fixedSize()
                }
                Rectangle()
                    .fill(FrilaCor.primaria)
                    .frame(width: 2, height: linhaDoCursor.height)
                    .offset(y: linhaDoCursor.midY - geometria.size.height / 2)
                    .offset(x: largura)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: geometria.size.height)
            .offset(x: -recuo)
        }
    }
}

/// Usa o mesmo motor de texto do UITextField, ancorado na baseline medida no campo.
/// Não estima centro vertical com métricas ou arredondamentos do Text do SwiftUI.
private struct TextoNaBaselineDoCampo: UIViewRepresentable {
    let texto: String
    let baseline: CGFloat
    let altura: CGFloat

    func makeUIView(context: Context) -> Vista {
        Vista()
    }

    func updateUIView(_ vista: Vista, context: Context) {
        vista.rotulo.text = texto
        vista.rotulo.font = .preferredFont(forTextStyle: .body)
        vista.rotulo.textColor = FrilaCor.textoUIKit
        vista.baseline.constant = baseline
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: Vista, context: Context) -> CGSize? {
        CGSize(width: (texto as NSString).size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: .body)]).width,
               height: altura)
    }

    final class Vista: UIView {
        let rotulo = UILabel()
        private(set) var baseline: NSLayoutConstraint!

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            rotulo.translatesAutoresizingMaskIntoConstraints = false
            addSubview(rotulo)
            baseline = rotulo.firstBaselineAnchor.constraint(equalTo: topAnchor)
            NSLayoutConstraint.activate([rotulo.leadingAnchor.constraint(equalTo: leadingAnchor), baseline])
        }

        required init?(coder: NSCoder) { nil }
    }
}

// MARK: - Roda

/// Lista vertical circular. O item do centro é o selecionado; os vizinhos aparecem cortados,
/// com opacidade progressiva nas pontas, como a roda nativa.
private struct RodaDeDominios: View, Animatable {
    @Environment(\.self) private var ambiente
    let sugestao: SugestaoDominio
    let posicao: Double
    let passo: CGFloat
    var interacao: Double
    nonisolated var animatableData: Double {
        get { interacao }
        set { interacao = newValue }
    }

    var body: some View {
        conteudo.mask(opacidadeProgressiva).clipped()
            .accessibilityHidden(true)
    }

    private var conteudo: some View {
        let base = Int(posicao.rounded(.down))
        let faixa = sugestao.candidatos.count > 1 ? (base - 3)...(base + 4) : 0...0
        return ZStack(alignment: .leading) {
            ForEach(Array(faixa), id: \.self) { indice in
                let d = min(1, abs(Double(indice) - posicao))
                let q = (1 - d * d * (3 - 2 * d)) * interacao
                Text(verbatim: sugestao.restante(de: sugestao.candidato(em: indice)))
                    .font(Font(UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                                                weight: UIFont.Weight(rawValue: CGFloat(q) * UIFont.Weight.medium.rawValue))))
                    .lineLimit(1)
                    .foregroundStyle(tomNeutro(q))
                    .offset(y: (CGFloat(Double(indice) - posicao)) * passo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func tomNeutro(_ q: Double) -> Color {
        let secundario = FrilaCor.texto.resolve(in: ambiente)
        let principal = FrilaCor.texto.resolve(in: ambiente)
        let t = Float(q)
        return Color(.sRGBLinear,
                     red: Double(secundario.linearRed + (principal.linearRed - secundario.linearRed) * t),
                     green: Double(secundario.linearGreen + (principal.linearGreen - secundario.linearGreen) * t),
                     blue: Double(secundario.linearBlue + (principal.linearBlue - secundario.linearBlue) * t),
                     opacity: 0.38 + 0.62 * q)
    }

    private var opacidadeProgressiva: some View {
        LinearGradient(stops: (0...80).map { indice in
            let y = Double(indice) / 80
            let d = abs(y - 0.5) * 2
            let pontos: [(Double, Double)] = [(0, 1), (0.4, 0.9), (0.65, 0.5), (0.85, 0.15), (1, 0)]
            let par = (0..<4).first { d <= pontos[$0 + 1].0 } ?? 3
            let t = (d - pontos[par].0) / (pontos[par + 1].0 - pontos[par].0)
            let suave = t * t * (3 - 2 * t)
            let opacidade = pontos[par].1 + (pontos[par + 1].1 - pontos[par].1) * suave
            return Gradient.Stop(color: .black.opacity(opacidade), location: y)
        }, startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Gestos isolados da rolagem da tela

/// Área sobre a roda. O arrasto vertical aqui tem prioridade sobre a rolagem da tela:
/// o pan da rolagem é obrigado a esperar este pan falhar. Arrasto horizontal ou toque simples
/// não começam o gesto da roda, então a rolagem e a edição seguem normais.
private struct AreaDeGestosDaRoda: UIViewRepresentable {
    let habilitada: Bool
    let aoTocar: () -> Void
    let aoInterromper: () -> Void
    let aoComecar: () -> Void
    let aoArrastar: (CGFloat, CGFloat) -> Void
    let aoSoltar: (CGFloat) -> Void
    let aoCancelar: () -> Void

    func makeUIView(context: Context) -> VistaDeGestos {
        let vista = VistaDeGestos()
        vista.backgroundColor = .clear
        return vista
    }

    func updateUIView(_ vista: VistaDeGestos, context: Context) {
        vista.habilitada = habilitada
        vista.aoTocar = aoTocar
        vista.aoInterromper = aoInterromper
        vista.aoComecar = aoComecar
        vista.aoArrastar = aoArrastar
        vista.aoSoltar = aoSoltar
        vista.aoCancelar = aoCancelar
    }
}

private final class VistaDeGestos: UIView, UIGestureRecognizerDelegate {
    var habilitada = true
    var aoTocar: (() -> Void)?
    var aoInterromper: (() -> Void)?
    var aoComecar: (() -> Void)?
    var aoArrastar: ((CGFloat, CGFloat) -> Void)?
    var aoSoltar: ((CGFloat) -> Void)?
    var aoCancelar: (() -> Void)?

    private var amostras: [(TimeInterval, CGFloat)] = []
    private func velocidadeMedia(_ pan: UIPanGestureRecognizer) -> CGFloat {
        let agora = ProcessInfo.processInfo.systemUptime
        amostras.append((agora, pan.translation(in: self).y))
        while amostras.count > 2 && amostras[1].0 < agora - 0.04 { amostras.removeFirst() }
        guard let primeira = amostras.first, agora > primeira.0 else { return 0 }
        return (pan.translation(in: self).y - primeira.1) / (agora - primeira.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(arrastou(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        let toque = UITapGestureRecognizer(target: self, action: #selector(tocou))
        toque.delegate = self
        addGestureRecognizer(toque)
    }
    required init?(coder: NSCoder) { nil }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        aoInterromper?()
        super.touchesBegan(touches, with: event)
    }
    @objc private func tocou() { aoTocar?() }

    @objc private func arrastou(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began: amostras = []; _ = velocidadeMedia(pan); aoComecar?()
            aoArrastar?(pan.translation(in: self).y, 0)
        case .changed: aoArrastar?(pan.translation(in: self).y, velocidadeMedia(pan))
        case .ended: aoSoltar?(velocidadeMedia(pan))
        case .cancelled, .failed: aoCancelar?()
        default: break
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard habilitada else { return false }
        // Vertical vence: a velocidade pode vir zerada no início, então o deslocamento também vale.
        let v = pan.velocity(in: self)
        let t = pan.translation(in: self)
        return abs(v.y) >= 1.5 * abs(v.x) && abs(t.y) >= 1.5 * abs(t.x)
    }

    /// Qualquer outro pan (a rolagem da tela) espera este falhar: aqui a roda ganha.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UIPanGestureRecognizer && other is UIPanGestureRecognizer && other.view !== self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        false
    }
}

// MARK: - Campo nativo

struct EstadoDoCursor: Equatable {
    var caretX: CGFloat = 0
    var cursorNoFim = false
    var focado = false
    var baseline: CGFloat = 0
    var linhaDoCursor: CGRect = .zero
}

final class PonteDeFoco {
    weak var campo: UITextField?
    func focar() { _ = campo?.becomeFirstResponder() }
}

/// UITextField puro: sem subviews, sem gestos próprios. Só informa onde está o cursor.
private struct CampoEmailNativo: UIViewRepresentable {
    @Binding var texto: String
    let habilitado: Bool
    let reservaDireita: CGFloat
    let foco: PonteDeFoco
    let ocultarTexto: Bool
    let aoInteragir: () -> Void
    let aoEnviar: () -> Void
    let aoMudarCursor: (EstadoDoCursor) -> Void

    func makeCoordinator() -> Coordenador { Coordenador(self) }

    func makeUIView(context: Context) -> CampoComMargens {
        let campo = CampoComMargens()
        campo.delegate = context.coordinator
        campo.keyboardType = .emailAddress
        campo.textContentType = .emailAddress
        campo.autocapitalizationType = .none
        campo.autocorrectionType = .no
        campo.spellCheckingType = .no
        campo.returnKeyType = .send
        campo.font = .preferredFont(forTextStyle: .body)
        campo.adjustsFontForContentSizeCategory = true
        campo.textColor = FrilaCor.textoUIKit
        campo.placeholder = "nome@exemplo.com"
        campo.accessibilityIdentifier = "entrada-email"
        campo.addTarget(context.coordinator, action: #selector(Coordenador.editou(_:)), for: .editingChanged)
        foco.campo = campo
        return campo
    }

    func updateUIView(_ campo: CampoComMargens, context: Context) {
        context.coordinator.pai = self
        campo.isEnabled = habilitado
        campo.reservaDireita = reservaDireita
        campo.aoInteragir = aoInteragir
        campo.aoToqueNaJanela = ocultarTexto ? aoInteragir : nil
        if campo.text != texto, campo.markedTextRange == nil {
            campo.text = texto
            campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
            context.coordinator.relatar(campo)
        }
        // Publica primeiro conteúdo e seleção; só depois revela ou oculta a apresentação nativa.
        campo.layoutIfNeeded()
        campo.textColor = ocultarTexto ? .clear : FrilaCor.textoUIKit
        campo.tintColor = ocultarTexto ? .clear : nil
    }

    final class Coordenador: NSObject, UITextFieldDelegate {
        var pai: CampoEmailNativo
        init(_ pai: CampoEmailNativo) { self.pai = pai }

        @objc func editou(_ campo: CampoComMargens) {
            pai.texto = campo.text ?? ""
            relatar(campo)
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool { pai.aoEnviar(); return true }
        func textFieldDidBeginEditing(_ textField: UITextField) { relatar(textField) }
        func textFieldDidEndEditing(_ textField: UITextField) { relatar(textField) }
        func textFieldDidChangeSelection(_ textField: UITextField) { relatar(textField) }

        func relatar(_ textField: UITextField) {
            let relato = pai.aoMudarCursor
            // Medido no próximo ciclo: o caret só tem a posição final depois do layout do texto novo.
            DispatchQueue.main.async { [weak textField] in
                guard let textField else { return }
                textField.layoutIfNeeded()
                var novo = EstadoDoCursor()
                novo.focado = textField.isFirstResponder
                novo.baseline = (textField as? CampoComMargens)?.baselineDoTexto ?? 0
                if let selecao = textField.selectedTextRange, selecao.isEmpty {
                    novo.linhaDoCursor = textField.caretRect(for: selecao.start)
                    novo.cursorNoFim = textField.compare(selecao.start, to: textField.endOfDocument) == .orderedSame
                    // Com o cursor no fim, o x é a largura do texto: o caretRect do UIKit chega atrasado.
                    let largura = ((textField.text ?? "") as NSString)
                        .size(withAttributes: [.font: textField.font ?? UIFont.preferredFont(forTextStyle: .body)]).width
                    let limite = textField.bounds.width - FrilaEspaco.medio - ((textField as? CampoComMargens)?.reservaDireita ?? 0)
                    novo.caretX = FrilaEspaco.medio + min(largura, max(limite, 0))
                }
                relato(novo)
            }
        }
    }
}

private final class CampoComMargens: UITextField {
    private let referenciaDaBaseline = UIView()
    var baselineDoTexto: CGFloat { referenciaDaBaseline.frame.minY }

    override init(frame: CGRect) {
        super.init(frame: frame)
        referenciaDaBaseline.translatesAutoresizingMaskIntoConstraints = false
        referenciaDaBaseline.isUserInteractionEnabled = false
        addSubview(referenciaDaBaseline)
        NSLayoutConstraint.activate([
            referenciaDaBaseline.topAnchor.constraint(equalTo: firstBaselineAnchor),
            referenciaDaBaseline.leadingAnchor.constraint(equalTo: leadingAnchor),
            referenciaDaBaseline.widthAnchor.constraint(equalToConstant: 0),
            referenciaDaBaseline.heightAnchor.constraint(equalToConstant: 0)
        ])
    }

    required init?(coder: NSCoder) { nil }
    var aoInteragir: (() -> Void)?
    var aoToqueNaJanela: (() -> Void)?
    private weak var janelaObservada: UIWindow?
    private lazy var observador = ObservadorDeInicioDeToque { [weak self] in self?.aoToqueNaJanela?() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        janelaObservada?.removeGestureRecognizer(observador)
        janelaObservada = window
        window?.addGestureRecognizer(observador)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        aoInteragir?()
        super.touchesBegan(touches, with: event)
    }
    var reservaDireita: CGFloat = 0
    private func area(_ limites: CGRect) -> CGRect {
        CGRect(
            x: FrilaEspaco.medio, y: 0,
            width: max(0, limites.width - FrilaEspaco.medio - reservaDireita), height: limites.height
        )
    }
    override func textRect(forBounds bounds: CGRect) -> CGRect { area(bounds) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { area(bounds) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { area(bounds) }
}

/// Observa o começo de qualquer toque na janela sem reconhecer nem bloquear gestos.
private final class ObservadorDeInicioDeToque: UIGestureRecognizer {
    private let aoComecar: () -> Void

    init(aoComecar: @escaping () -> Void) {
        self.aoComecar = aoComecar
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        aoComecar()
        state = .failed
    }
}
