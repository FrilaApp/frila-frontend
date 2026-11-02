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
    /// Dá ao botão da tela a mesma regra do Return: com ghost, nada é enviado.
    var controle: ControleDoCampoEmail?

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
    /// Cor de acento do item central: entra com o gesto, segue no snap e sai no fim do dwell.
    @State private var acento = 0.0
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
    private let crescimento: CGFloat = 1.5
    /// Folga da área de gestos além do contêiner do campo, em cada lado.
    private let folgaVerticalDaArea: CGFloat = 10
    /// Largura mínima da área de gestos quando o texto já ocupa quase todo o campo.
    private let larguraMinimaDaArea: CGFloat = 56

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

    /// x da borda esquerda do "@", medido pela largura da parte local do e-mail.
    private func inicioDoArroba(_ largura: CGFloat) -> CGFloat {
        let local = texto.firstIndex(of: "@").map { String(texto[..<$0]) } ?? texto
        let limite = max(largura - FrilaEspaco.medio - reservaDireita, 0)
        return FrilaEspaco.medio + min(medir(local), limite)
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
                    aoInteragir: { cancelarPreenchimento(); restaurarBlocoDoArroba() },
                    completaNoRetorno: estado.focado && completacaoPendente(cursorNoFim: estado.cursorNoFim) != nil,
                    aoEnviar: { if !completarAntesDeEnviar() { aoEnviar() } },
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
                                       passo: passoDaRoda, interacao: destaque, acento: acento)
                            .frame(width: max(0, largura - inicio - reservaDireita - 4), height: alturaVisual, alignment: .leading)
                            .offset(x: inicio)
                            .allowsHitTesting(false)
                    }
                }

                if let sugestaoAtual, larguraDaRoda >= 56 {
                    RodaDeDominios(sugestao: sugestaoAtual, posicao: preenchendo ? 0 : posicao, passo: passoDaRoda, interacao: destaque, acento: acento)
                        .frame(width: larguraDaRoda, height: alturaVisual, alignment: .leading)
                        .offset(x: inicioX)
                        .allowsHitTesting(false)
                }

                // A interação existe sempre que há sugestão, mesmo com a roda oculta (texto longo ou um só candidato).
                if let sugestaoAtual {
                    // O bloco de interação é todo o trecho do "@" em diante, até a seta.
                    let fimDaArea = largura - reservaDireita - 4
                    let inicioDaArea = min(inicioDoArroba(largura), fimDaArea - larguraMinimaDaArea)
                    let larguraDaArea = fimDaArea - inicioDaArea
                    AreaDeGestosDaRoda(
                        habilitada: !preenchendo,
                        foco: foco,
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
                            acento = 0
                            deslocamentoAtual = 0
                            ultimoPasso = Int(posicao.rounded())
                            hapticos.preparar()
                        },
                        aoArrastar: { deslocamento, velocidade in arrastar(deslocamento, velocidade: velocidade) },
                        aoSoltar: { velocidade in soltar(sugestao: sugestaoAtual, velocidade: velocidade) },
                        aoCancelar: {
                            tarefaDeEncaixe?.cancel()
                            restaurarBlocoDoArroba()
                            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.12)) {
                                posicao = posicaoNoToque.rounded()
                                destaque = 0
                                acento = 0
                                estendido = false
                            }
                        }
                    )
                    // A área passa poucos pontos da borda do campo, em cima e embaixo, para o deslize não exigir pontaria.
                    .frame(width: larguraDaArea, height: alturaVisual + folgaVerticalDaArea * 2)
                    .offset(x: inicioDaArea)
                    .allowsHitTesting(false)
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
                        .buttonStyle(ToqueDaSeta(aoPressionar: hapticos.toqueDaSeta))
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
            .animation(estendido ? MovimentoDoCampo.expandir : MovimentoDoCampo.recolher, value: estendido)
        }
        .frame(height: altura)
        .onAppear { controle?.completarAntesDeEnviar = completarAntesDeEnviar }
        .onChange(of: sugestao?.prefixo) { _, _ in
            if !preenchendo, textoAntesDoReinicio == nil { posicao = 0 }
        }
        .onChange(of: texto) { _, novo in
            if tarefaDeEncaixe != nil {
                tarefaDeEncaixe?.cancel()
                tarefaDeEncaixe = nil
                withAnimation(MovimentoDoCampo.recolher) { estendido = false; acento = 0 }
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
    @State private var hapticos = HapticosDoDominio()
    /// Texto de antes de a roda reiniciar o bloco do "@"; volta a ele se o gesto não trocar de domínio.
    @State private var textoAntesDoReinicio: String?
    @State private var selecaoAntesDoReinicio: NSRange?
    /// Último valor produzido por uma completação; apagar parte dele indica que a pessoa recusou o domínio.
    @State private var ultimoTextoCompletado: String?
    @State private var conferenciaAte: Date?
    @State private var tarefaDeHaptico: Task<Void, Never>?

    private func arrastar(_ deslocamento: CGFloat, velocidade: CGFloat) {
        deslocamentoAtual = Double(deslocamento)
        if !gestoIntencional {
            let offset = LimiarDaRoda.resistencia(deslocamentoAtual)
            if LimiarDaRoda.intencional(deslocamento: deslocamentoAtual, velocidade: Double(velocidade)) {
                gestoIntencional = true
                reiniciarBlocoDoArroba()
                deslocamentoNaIntencao = deslocamentoAtual
                offsetNaIntencao = offset
                withAnimation(MovimentoDoCampo.expandir) { estendido = true; destaque = 1; acento = 1 }
            } else {
                posicao = posicaoNoToque - offset / Double(passoDaRoda)
                return
            }
        }
        let efetivo = offsetNaIntencao + deslocamentoAtual - deslocamentoNaIntencao
        let continuo = posicaoNoToque - efetivo / (Double(passoDaRoda) * LimiarDaRoda.tracao)
        let alvo = LimiarDaRoda.comDetente(continuo, base: posicaoNoToque)
        posicao = alvo
        menorPosicaoVista = min(menorPosicaoVista, alvo.rounded())
        maiorPosicaoVista = max(maiorPosicaoVista, alvo.rounded())
        let limite = 0.5 + 2 / Double(passoDaRoda)
        if abs(alvo - Double(ultimoPasso)) >= limite {
            ultimoPasso = Int(alvo.rounded())
            let agora = ContinuousClock.now
            if ultimoTique.duration(to: agora) >= .milliseconds(50) {
                hapticos.tique()
                ultimoTique = agora
            }
        }
    }

    /// Reset do componente: o domínio já escrito sai e a roda assume o bloco com a lista inteira,
    /// como se o texto terminasse no "@". O texto anterior fica guardado até a troca ser confirmada.
    private func reiniciarBlocoDoArroba() {
        guard textoAntesDoReinicio == nil,
              let campo = foco.campo, let selecao = campo.selectedTextRange, selecao.isEmpty,
              campo.compare(selecao.start, to: campo.endOfDocument) == .orderedSame,
              let atual = SugestaoDominio.criar(texto: texto, cursorNoFim: estado.cursorNoFim),
              !atual.prefixo.isEmpty,
              let arroba = texto.firstIndex(of: "@") else { return }
        textoAntesDoReinicio = texto
        if let campo = foco.campo, let selecao = campo.selectedTextRange {
            selecaoAntesDoReinicio = NSRange(
                location: campo.offset(from: campo.beginningOfDocument, to: selecao.start),
                length: campo.offset(from: selecao.start, to: selecao.end)
            )
        }
        texto = String(texto[...arroba])
        // Continuidade: a roda parte do domínio que estava em seleção, não do primeiro da lista.
        let inicio = atual.candidatos.first.flatMap { SugestaoDominio.dominios.firstIndex(of: $0) } ?? 0
        posicao = Double(inicio)
        posicaoNoToque = Double(inicio)
        ultimoPasso = inicio
    }

    private func restaurarBlocoDoArroba() {
        guard let anterior = textoAntesDoReinicio else { return }
        textoAntesDoReinicio = nil
        foco.selecaoParaRestaurar = selecaoAntesDoReinicio
        selecaoAntesDoReinicio = nil
        texto = anterior
        posicao = 0
    }

    private func soltar(sugestao: SugestaoDominio, velocidade: CGFloat) {
        tarefaDeEncaixe?.cancel()
        let origem = posicao
        let intencional = LimiarDaRoda.intencional(deslocamento: deslocamentoAtual, velocidade: Double(velocidade))
        let duracao = intencional ? 0.20 : 0.14
        let bounce = intencional ? 0.02 : 0.02
        withAnimation(.easeOut(duration: 0.12)) { destaque = 0 }
        let velocidadeEmItens = -Double(velocidade / passoDaRoda)
        let projecao = min(0.25, max(-0.25, velocidadeEmItens * 0.04))
        let direcao = deslocamentoAtual < 0 ? 1.0 : -1.0
        let projetado = (origem + projecao).rounded()
        let deslocadoEmItens = abs(origem - posicaoNoToque)
        let rapido = abs(velocidade) >= LimiarDaRoda.velocidadeDeTroca
        // Trocar de item exige passar do ponto de resistência; o gesto curto devolve ao item de partida.
        let cruzou = deslocadoEmItens >= LimiarDaRoda.pontoDeTroca || (rapido && deslocadoEmItens >= 0.2)
        let alvo = intencional ? (projetado == posicaoNoToque ? (cruzou ? posicaoNoToque + direcao : posicaoNoToque) : projetado) : posicaoNoToque
        // Sem troca não há escolha a afirmar: a cor sai já na volta ao item de partida.
        if alvo == posicaoNoToque { withAnimation(.easeOut(duration: 0.12)) { acento = 0 } }
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
                if transicao == nil { withAnimation(.easeOut(duration: 0.12)) { acento = 0 } }
            } else {
                tarefaDeEncaixe = nil
                restaurarBlocoDoArroba()
                withAnimation(MovimentoDoCampo.recolher) { estendido = false }
            }
        }
    }

    // MARK: Segurança do envio

    /// Sugestão que uma tentativa de envio deve completar antes de enviar, se houver.
    private func completacaoPendente(cursorNoFim: Bool) -> SugestaoDominio? {
        guard habilitado, textoAntesDoReinicio == nil,
              let atual = SugestaoDominio.criar(texto: texto, cursorNoFim: cursorNoFim),
              // Sem prefixo não há escolha da pessoa: o envio nunca inventa o domínio.
              !atual.prefixo.isEmpty,
              // Domínio já completo da lista é uma escolha válida: `yahoo.com` não vira `yahoo.com.br`.
              !SugestaoDominio.dominios.contains(atual.prefixo) else { return nil }
        // Quem apagou uma extensão (`uol.com.br` para `uol.com`) recusou o domínio. A exceção só vale com o
        // texto parado numa fronteira de rótulo; apagar um caractere solto (`gmail.co`) continua completando.
        if let completado = ultimoTextoCompletado, completado != texto, completado.hasPrefix(texto),
           atual.restante(de: atual.candidato(em: 0)).hasPrefix(".") { return nil }
        return atual
    }

    /// Retorna true quando a tentativa foi consumida e não deve enviar.
    private func completarAntesDeEnviar() -> Bool {
        // Durante o preenchimento ou o reset da roda, enviar impediria a pessoa de conferir o resultado.
        if preenchendo { return true }
        if textoAntesDoReinicio != nil { restaurarBlocoDoArroba(); return true }
        // Janela de conferência: depois de completar, o envio não vale para um toque em reflexo.
        if let fim = conferenciaAte, Date() < fim { return true }
        // O toque no botão da tela pode já ter fechado o teclado; o foco real vale mais que o estado relatado.
        let focado = foco.campo?.isFirstResponder == true
        guard let atual = completacaoPendente(cursorNoFim: focado ? estado.cursorNoFim : true) else { return false }
        conferenciaAte = Date().addingTimeInterval(0.6)
        if focado {
            confirmar(sugestao: atual, posicao: 0)
            if transicao != nil { return true }
        }
        // Sem teclado, ou com a animação recusada, completa direto: a tentativa nunca vira envio do texto parcial.
        let completo = texto + atual.restante(de: atual.candidato(em: 0))
        ultimoTextoCompletado = completo
        texto = completo
        hapticos.confirmacao()
        return true
    }

    // MARK: Confirmação com preenchimento animado

    /// Seta e roda confirmam o valor inteiro antes da apresentação por blocos.
    private func confirmar(sugestao: SugestaoDominio, posicao: Int, espera: Int = 0) {
        guard preenchimentoValido(texto),
              sugestao == SugestaoDominio.criar(texto: texto, cursorNoFim: estado.cursorNoFim) else { return }
        let escolhido = sugestao.candidato(em: posicao)
        let restante = sugestao.restante(de: escolhido)
        guard !restante.isEmpty else { return }
        textoAntesDoReinicio = nil
        selecaoAntesDoReinicio = nil
        cancelarPreenchimento()
        acento = espera > 0 ? 1 : 0
        // Só uma apresentação nova começa em zero; a camada que sai conserva seu quadro final.
        tempoDaCadeia = 0
        estendido = espera > 0
        aguardandoCadeia = espera > 0
        transicao = TransicaoDoDominio(textoAnterior: texto, sugestao: sugestao, posicao: posicao,
                                      espera: espera, cadeia: CadeiaDoDominio(restante: restante))
        textoEsperado = texto + restante
        ultimoTextoCompletado = textoEsperado
        texto = textoEsperado
        if espera > 0 { hapticos.confirmacao() }
    }

    private func animarCadeia(_ apresentacao: TransicaoDoDominio) {
        tarefaDePreenchimento = Task { @MainActor in
            guard !Task.isCancelled, transicao?.id == apresentacao.id else { return }
            // O campo se recolhe dentro do dwell, antes de começar a troca de texto.
            // Assim o fill inteiro e o campo nativo final compartilham a mesma origem.
            withAnimation(MovimentoDoCampo.recolher) { estendido = false }
            if apresentacao.espera > 0 {
                // A cor afirma a escolha no dwell e sai antes da troca, para o fill nascer no tom do texto.
                let saidaDoAcento = min(100, apresentacao.espera)
                do { try await Task.sleep(for: .milliseconds(apresentacao.espera - saidaDoAcento)) } catch { return }
                guard transicao?.id == apresentacao.id else { return }
                withAnimation(.easeOut(duration: Double(saidaDoAcento) / 1000)) { acento = 0 }
                do { try await Task.sleep(for: .milliseconds(saidaDoAcento)) } catch { return }
            }
            guard transicao?.id == apresentacao.id else { return }
            guard preenchimentoValido(textoEsperado) else { cancelarPreenchimento(); return }
            aguardandoCadeia = false
            animarHapticos(da: apresentacao.cadeia, id: apresentacao.id)
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

    /// Um toque por bloco, no instante em que o bloco entra; cada bloco é um pouco mais firme que o anterior.
    private func animarHapticos(da cadeia: CadeiaDoDominio, id: UUID) {
        tarefaDeHaptico?.cancel()
        tarefaDeHaptico = Task { @MainActor in
            let relogio = ContinuousClock()
            let inicio = relogio.now
            for (indice, bloco) in cadeia.blocos.enumerated() {
                do { try await Task.sleep(until: inicio.advanced(by: .seconds(bloco.inicio)), clock: relogio) } catch { return }
                guard !Task.isCancelled, transicao?.id == id else { return }
                hapticos.bloco(indice, de: cadeia.blocos.count)
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
        tarefaDeHaptico?.cancel()
        tarefaDeHaptico = nil
        destaque = 0
        acento = 0
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
    var acento: Double
    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(interacao, acento) }
        set { interacao = newValue.first; acento = newValue.second }
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
                    .foregroundStyle(tom(q, acentoDoItem: tomDeAcento(distancia: d)))
                    .offset(y: (CGFloat(Double(indice) - posicao)) * passo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// A cor só existe perto do centro: no meio da travessia nenhum item está laranja, nunca dois.
    private func tomDeAcento(distancia d: Double) -> Double {
        let t = min(1, max(0, (0.45 - d) / 0.30))
        return t * t * (3 - 2 * t) * acento
    }

    private func tom(_ q: Double, acentoDoItem a: Double) -> Color {
        let neutro = FrilaCor.texto.resolve(in: ambiente)
        // Mesma seleção da seta no claro; no escuro, a terracota viva da marca.
        let cor = (ambiente.colorScheme == .dark ? FrilaCor.marca : FrilaCor.selecao).resolve(in: ambiente)
        let t = Float(a)
        return Color(.sRGBLinear,
                     red: Double(neutro.linearRed + (cor.linearRed - neutro.linearRed) * t),
                     green: Double(neutro.linearGreen + (cor.linearGreen - neutro.linearGreen) * t),
                     blue: Double(neutro.linearBlue + (cor.linearBlue - neutro.linearBlue) * t),
                     opacity: 0.38 + 0.62 * max(q, a))
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

/// Mede a área sem participar do hit-test. Os toques continuam chegando ao UITextField.
private struct AreaDeGestosDaRoda: UIViewRepresentable {
    let habilitada: Bool
    let foco: PonteDeFoco
    let aoInterromper: () -> Void
    let aoComecar: () -> Void
    let aoArrastar: (CGFloat, CGFloat) -> Void
    let aoSoltar: (CGFloat) -> Void
    let aoCancelar: () -> Void

    func makeUIView(context: Context) -> VistaDeGestos { VistaDeGestos() }

    func updateUIView(_ vista: VistaDeGestos, context: Context) {
        vista.habilitada = habilitada
        vista.foco = foco
        vista.aoInterromper = aoInterromper
        vista.aoComecar = aoComecar
        vista.aoArrastar = aoArrastar
        vista.aoSoltar = aoSoltar
        vista.aoCancelar = aoCancelar
        vista.resolverRolagem()
    }

    static func dismantleUIView(_ vista: VistaDeGestos, coordinator: ()) {
        vista.desinstalar()
    }
}

private final class VistaDeGestos: UIView, UIGestureRecognizerDelegate {
    var habilitada = true
    weak var foco: PonteDeFoco?
    var aoInterromper: (() -> Void)?
    var aoComecar: (() -> Void)?
    var aoArrastar: ((CGFloat, CGFloat) -> Void)?
    var aoSoltar: ((CGFloat) -> Void)?
    var aoCancelar: (() -> Void)?
    private weak var janelaObservada: UIWindow?
    private lazy var vertical = IntencaoVerticalDoDominio(target: self, action: #selector(arrastou(_:)))
    private var cancelamentoDaSessao: (() -> Void)?
    private weak var rolagemDaTela: UIScrollView?
    private var avisouAusenciaDeRolagem = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        vertical.delegate = self

    }
    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        desinstalar()
        janelaObservada = window
        window?.addGestureRecognizer(vertical)
        resolverRolagem()
    }

    func desinstalar() {
        // Remover um recognizer ativo também encerra a sessão, sem deixar reset pendente.
        let cancelar = cancelamentoDaSessao
        cancelamentoDaSessao = nil
        janelaObservada?.removeGestureRecognizer(vertical)
        rolagemDaTela = nil
        janelaObservada = nil
        cancelar?()
    }

    func resolverRolagem() {
        var ancestral = foco?.campo?.superview
        while let vista = ancestral {
            if let scroll = vista as? UIScrollView {
                rolagemDaTela = scroll
                return
            }
            ancestral = vista.superview
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard habilitada, let campo = foco?.campo, campo.isEnabled, campo.isFirstResponder,
              campo.markedTextRange == nil,
              let selecao = campo.selectedTextRange, selecao.isEmpty,
              campo.compare(selecao.start, to: campo.endOfDocument) == .orderedSame,
              bounds.contains(touch.location(in: self)) else { return false }
        resolverRolagem()
        if rolagemDaTela == nil, !avisouAusenciaDeRolagem {
            avisouAusenciaDeRolagem = true
            #if DEBUG
            NSLog("Roda de domínio: ScrollView ancestral ausente; prioridade vertical indisponível.")
            #endif
        }
        vertical.campo = campo
        return true
    }

    @objc private func arrastou(_ gesto: IntencaoVerticalDoDominio) {
        switch gesto.state {
        case .began:
            cancelamentoDaSessao = aoCancelar
            aoInterromper?()
            aoComecar?()
            aoArrastar?(gesto.deslocamento, gesto.velocidade)
        case .changed: aoArrastar?(gesto.deslocamento, gesto.velocidade)
        case .ended:
            cancelamentoDaSessao = nil
            aoSoltar?(gesto.velocidade)
        case .cancelled:
            let cancelar = cancelamentoDaSessao
            cancelamentoDaSessao = nil
            cancelar?()
        default: break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        // Só a rolagem ancestral espera a intenção vertical. Os gestos de edição nunca esperam.
        gestureRecognizer === vertical && other === rolagemDaTela?.panGestureRecognizer
    }
}

/// Apenas vertical inicial. Horizontal ou reconhecimento nativo encerram a candidatura;
/// não há transferência de edição para roda nesta etapa. O prazo de candidatura
/// protege repouso sem inferir o estado dos recognizers privados do UIKit.
private final class IntencaoVerticalDoDominio: UIGestureRecognizer {
    weak var campo: UITextField?
    private var inicio: CGPoint?
    private var inicioTemporal: TimeInterval = 0
    private var maiorDeslocamento: CGFloat = 0
    private var textoInicial: String?
    private var selecaoInicial: NSRange?
    private var prazoDeCandidatura: DispatchWorkItem?
    private var amostras: [(TimeInterval, CGPoint)] = []
    private(set) var deslocamento: CGFloat = 0
    private(set) var velocidade: CGFloat = 0
    private var velocidadeHorizontal: CGFloat = 0

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard inicio == nil, touches.count == 1, let toque = touches.first else {
            state = state == .possible ? .failed : .cancelled
            return
        }
        let ponto = toque.location(in: view)
        inicio = ponto
        inicioTemporal = toque.timestamp
        textoInicial = campo?.text
        selecaoInicial = selecaoAtual
        amostras = [(toque.timestamp, ponto)]
        // Prazo de candidatura, não detecção do long press privado do UIKit.
        // Libera também a rolagem que esperava este recognizer após repouso.
        let prazo = DispatchWorkItem { [weak self] in
            guard let self, self.state == .possible, self.maiorDeslocamento <= 4 else { return }
            self.state = .failed
        }
        prazoDeCandidatura = prazo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: prazo)
    }

    private var selecaoAtual: NSRange? {
        guard let campo, let selecao = campo.selectedTextRange else { return nil }
        return NSRange(location: campo.offset(from: campo.beginningOfDocument, to: selecao.start),
                       length: campo.offset(from: selecao.start, to: selecao.end))
    }

    private func medir(_ toque: UITouch) -> CGFloat {
        guard let inicio else { return 0 }
        let ponto = toque.location(in: view)
        amostras.append((toque.timestamp, ponto))
        while amostras.count > 2 && amostras[1].0 < toque.timestamp - 0.04 { amostras.removeFirst() }
        let primeira = amostras[0]
        let intervalo = toque.timestamp - primeira.0
        velocidadeHorizontal = intervalo > 0 ? (ponto.x - primeira.1.x) / intervalo : 0
        velocidade = intervalo > 0 ? (ponto.y - primeira.1.y) / intervalo : 0
        deslocamento = ponto.y - inicio.y
        return ponto.x - inicio.x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let toque = touches.first else { return }
        let estavaEmRepouso = maiorDeslocamento <= 4
        let dx = medir(toque)
        maiorDeslocamento = max(maiorDeslocamento, hypot(dx, deslocamento))
        if state == .possible {
            guard campo?.isFirstResponder == true, campo?.markedTextRange == nil,
                  campo?.text == textoInicial, selecaoAtual == selecaoInicial,
                  !(estavaEmRepouso && toque.timestamp - inicioTemporal >= 0.35) else {
                state = .failed
                return
            }
            // Oscilação curta continua com UIKit; horizontal/diagonal não vira roda depois.
            if abs(dx) >= 6 && abs(deslocamento) < 1.5 * abs(dx) {
                state = .failed
            } else if abs(deslocamento) >= 1.5 * abs(dx),
                      (abs(velocidade) < 10 || abs(velocidade) >= 1.5 * abs(velocidadeHorizontal)),
                      LimiarDaRoda.intencional(deslocamento: Double(deslocamento), velocidade: Double(velocidade)) {
                prazoDeCandidatura?.cancel()
                state = .began
            }
        } else if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let toque = touches.first { _ = medir(toque) }
        state = state == .possible ? .failed : .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = state == .possible ? .failed : .cancelled
    }

    override func reset() {
        super.reset()
        prazoDeCandidatura?.cancel()
        prazoDeCandidatura = nil
        inicio = nil
        inicioTemporal = 0
        maiorDeslocamento = 0
        textoInicial = nil
        selecaoInicial = nil
        amostras = []
        deslocamento = 0
        velocidade = 0
        velocidadeHorizontal = 0
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

@MainActor
final class ControleDoCampoEmail {
    var completarAntesDeEnviar: (@MainActor () -> Bool)?
}

final class PonteDeFoco {
    weak var campo: UITextField?
    var selecaoParaRestaurar: NSRange?
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
    let completaNoRetorno: Bool
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
        // A tecla avisa que o próximo Return completa, e ainda não envia.
        let tecla: UIReturnKeyType = completaNoRetorno ? .next : .send
        if campo.returnKeyType != tecla {
            campo.returnKeyType = tecla
            if campo.isFirstResponder { campo.reloadInputViews() }
        }
        campo.reservaDireita = reservaDireita
        campo.aoInteragir = aoInteragir
        campo.aoToqueNaJanela = ocultarTexto ? aoInteragir : nil
        if campo.text != texto, campo.markedTextRange == nil {
            campo.text = texto
            campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
            context.coordinator.relatar(campo)
        }
        if let selecao = foco.selecaoParaRestaurar, campo.markedTextRange == nil {
            foco.selecaoParaRestaurar = nil
            if let inicio = campo.position(from: campo.beginningOfDocument, offset: selecao.location),
               let fim = campo.position(from: inicio, offset: selecao.length) {
                campo.selectedTextRange = campo.textRange(from: inicio, to: fim)
                context.coordinator.relatar(campo)
            }
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
        func textFieldDidChangeSelection(_ textField: UITextField) {
            (textField as? CampoComMargens)?.corrigirSelecaoDoToque(origem: "delegate")
            #if DEBUG
            if let selecao = textField.selectedTextRange {
                NSLog("Roda de domínio: seleção %d+%d de %d",
                      textField.offset(from: textField.beginningOfDocument, to: selecao.start),
                      textField.offset(from: selecao.start, to: selecao.end),
                      (textField.text ?? "").count)
            }
            #endif
            relatar(textField)
        }

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
        instalarObservadorDePrecisao()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: Toque preciso
    private let observadorDePrecisao = ObservadorDeToquePreciso()
    private var corrigindoSelecao = false
    private var notificacaoAntesDoFim: UInt?
    private var textoNoInicioDoToque: String?

    private func instalarObservadorDePrecisao() {
        observadorDePrecisao.aoComecar = { [weak self] in
            guard let self else { return }
            self.notificacaoAntesDoFim = nil
            self.textoNoInicioDoToque = self.text
        }
        observadorDePrecisao.aoTerminar = { [weak self] in
            guard let self else { return }
            let geracao = self.observadorDePrecisao.geracao
            // Só agenda quando houve seleção antes do observador receber o fim do toque.
            guard self.notificacaoAntesDoFim == geracao,
                  self.observadorDePrecisao.curto else { return }
            self.notificacaoAntesDoFim = nil
            #if DEBUG
            NSLog("Precisão %.6f g%llu fallback agendado", CACurrentMediaTime(), UInt64(geracao))
            #endif
            DispatchQueue.main.async { [weak self] in
                guard let self, self.observadorDePrecisao.geracao == geracao else { return }
                self.corrigirSelecaoDoToque(origem: "fallback")
            }
        }
        addGestureRecognizer(observadorDePrecisao)
    }

    func corrigirSelecaoDoToque(origem: String) {
        let toque = observadorDePrecisao
        #if DEBUG
        NSLog("Precisão %.6f g%llu %@ seleção fim=%d reentrada=%d",
              CACurrentMediaTime(), UInt64(toque.geracao), origem, toque.fim != nil ? 1 : 0,
              corrigindoSelecao ? 1 : 0)
        #endif
        guard !corrigindoSelecao, toque.emCurso || toque.fim != nil else { return }
        if toque.emCurso {
            notificacaoAntesDoFim = toque.geracao
            guard toque.curtoEmCurso else { return }
        } else {
            guard let fim = toque.fim,
                  (origem == "fallback" || CACurrentMediaTime() - fim < 0.1),
                  toque.curto else { return }
        }
        guard isFirstResponder, markedTextRange == nil,
              text == textoNoInicioDoToque,
              let selecao = selectedTextRange, selecao.isEmpty else { return }
        // closestPosition usa o sistema de coordenadas da view que desenha o texto.
        let ponto = (textInputView ?? self).convert(toque.ponto, from: self)
        guard let alvo = closestPosition(to: ponto), compare(selecao.start, to: alvo) != .orderedSame else { return }
        corrigindoSelecao = true
        defer { corrigindoSelecao = false }
        #if DEBUG
        NSLog("Precisão %.6f g%llu correção %@ %d -> %d", CACurrentMediaTime(), UInt64(toque.geracao), origem,
              offset(from: beginningOfDocument, to: selecao.start), offset(from: beginningOfDocument, to: alvo))
        #endif
        selectedTextRange = textRange(from: alvo, to: alvo)
    }

    var aoInteragir: (() -> Void)?
    var aoToqueNaJanela: (() -> Void)?
    private weak var janelaObservada: UIWindow?
    private lazy var observador = ObservadorDeInicioDeToque { [weak self] in self?.aoToqueNaJanela?() }
    private lazy var dispensa = DispensaDoTecladoNaJanela { [weak self] ponto in
        guard let self, let janela = self.window, self.isFirstResponder else { return false }
        // Zona do campo, com folga vertical para a roda de domínios que cresce durante o deslize.
        let zona = self.convert(self.bounds, to: janela).insetBy(dx: 0, dy: -48)
        return !zona.contains(ponto)
    } aoDispensar: { [weak self] in _ = self?.resignFirstResponder() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        janelaObservada?.removeGestureRecognizer(observador)
        janelaObservada?.removeGestureRecognizer(dispensa)
        janelaObservada = window
        if window == nil { observadorDePrecisao.invalidar() }
        window?.addGestureRecognizer(observador)
        window?.addGestureRecognizer(dispensa)
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

/// Observa a sequência original sem reconhecer, cancelar ou atrasar os gestos nativos.
private final class ObservadorDeToquePreciso: UIGestureRecognizer {
    var aoComecar: (() -> Void)?
    var aoTerminar: (() -> Void)?
    private(set) var geracao: UInt = 0
    private(set) var ponto = CGPoint.zero
    private(set) var fim: CFTimeInterval?
    private(set) var emCurso = false
    private(set) var curto = false
    var curtoEmCurso: Bool {
        emCurso && numberOfTouches == 1 && CACurrentMediaTime() - inicioTemporal < 0.3 && deslocamentoMaximo < 10
    }
    private var inicio = CGPoint.zero
    private var inicioTemporal: TimeInterval = 0
    private var deslocamentoMaximo: CGFloat = 0

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    func invalidar() {
        geracao &+= 1
        emCurso = false
        curto = false
        fim = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard !emCurso, touches.count == 1, let toque = touches.first else {
            invalidar()
            state = .failed
            return
        }
        geracao &+= 1
        emCurso = true
        curto = false
        fim = nil
        inicio = toque.location(in: view)
        ponto = inicio
        inicioTemporal = toque.timestamp
        deslocamentoMaximo = 0
        let agora = CACurrentMediaTime()
        aoComecar?()
        #if DEBUG
        NSLog("Precisão %.6f g%llu began (%.1f,%.1f)", agora, UInt64(geracao), ponto.x, ponto.y)
        #endif
    }

    private func medir(_ toque: UITouch) {
        ponto = toque.location(in: view)
        deslocamentoMaximo = max(deslocamentoMaximo, hypot(ponto.x - inicio.x, ponto.y - inicio.y))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let toque = touches.first { medir(toque) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard emCurso, let toque = touches.first else { state = .failed; return }
        medir(toque)
        fim = CACurrentMediaTime()
        emCurso = false
        curto = toque.timestamp - inicioTemporal < 0.3 && deslocamentoMaximo < 10
        #if DEBUG
        NSLog("Precisão %.6f g%llu ended (%.1f,%.1f) duração=%.3f máximo=%.1f curto=%d",
              fim!, UInt64(geracao), ponto.x, ponto.y, toque.timestamp - inicioTemporal,
              deslocamentoMaximo, curto ? 1 : 0)
        #endif
        aoTerminar?()
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        invalidar()
        state = .failed
    }

    // O reset do recognizer não apaga a amostra final: o delegate ainda pode recebê-la
    // no mesmo ciclo. Novo toque, cancelamento ou desmontagem invalidam a geração.
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

/// Dispensa do teclado (regra do design system): toque curto ou arrasto para baixo fora da zona do campo.
/// Nunca reconhece nem bloqueia outros gestos; só observa e pede para fechar.
private final class DispensaDoTecladoNaJanela: UIGestureRecognizer {
    private let podeDispensar: (CGPoint) -> Bool
    private let aoDispensar: () -> Void
    private var inicio: CGPoint?

    init(podeDispensar: @escaping (CGPoint) -> Bool, aoDispensar: @escaping () -> Void) {
        self.podeDispensar = podeDispensar
        self.aoDispensar = aoDispensar
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, let toque = touches.first, let janela = view else { state = .failed; return }
        let ponto = toque.location(in: janela)
        inicio = podeDispensar(ponto) ? ponto : nil
        if inicio == nil { state = .failed }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let inicio, let toque = touches.first, let janela = view else { return }
        let ponto = toque.location(in: janela)
        let dx = ponto.x - inicio.x, dy = ponto.y - inicio.y
        if dy >= 14, dy > abs(dx) * 1.5 { aoDispensar(); self.inicio = nil; state = .failed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let inicio, let toque = touches.first, let janela = view {
            let ponto = toque.location(in: janela)
            if hypot(ponto.x - inicio.x, ponto.y - inicio.y) < 10 { aoDispensar() }
        }
        inicio = nil
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { inicio = nil; state = .failed }
    override func reset() { inicio = nil }
}

/// Mapa de haptics do seletor de domínio. Todos leves: a roda é contínua e o preenchimento é curto.
/// Rolar: tique de seleção do sistema por item, como o picker nativo. Confirmar pela roda: um toque mais claro. Seta: toque ao pressionar.
/// Preencher: um toque por bloco, crescente. Não há haptic ao cancelar nem ao digitar à mão.
@MainActor
final class HapticosDoDominio {
    private let suave = UIImpactFeedbackGenerator(style: .soft)
    private let leve = UIImpactFeedbackGenerator(style: .light)
    private let selecao = UISelectionFeedbackGenerator()

    func preparar() { suave.prepare(); leve.prepare(); selecao.prepare() }
    func tique() { selecao.selectionChanged() }
    func confirmacao() { leve.impactOccurred(intensity: 0.65) }
    func toqueDaSeta() { leve.impactOccurred(intensity: 0.75) }
    func bloco(_ indice: Int, de total: Int) {
        let fracao = total > 1 ? Double(indice) / Double(total - 1) : 0.5
        suave.impactOccurred(intensity: 0.3 + 0.3 * fracao)
    }
}

/// Visual idêntico ao `.plain`; só acrescenta o toque ao pressionar.
private struct ToqueDaSeta: ButtonStyle {
    let aoPressionar: () -> Void
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressionado in
                if pressionado { aoPressionar() }
            }
    }
}

/// Curvas próprias da expansão e da retração do contêiner do campo.
/// Expandir entra rápido e pousa macio; recolher parte devagar e fecha sem estalo.
enum MovimentoDoCampo {
    static let expandir = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.20)
    static let recolher = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.22)
}
