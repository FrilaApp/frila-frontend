import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

enum CampoDeContato: Hashable {
    case telefone, email
}

/// Dono único da cópia de contato. Toque e deslize chegam aqui, então cada intenção escreve uma vez
/// e dispara um único haptic de conclusão.
@MainActor @Observable
final class CopiaDeContato {
    private(set) var tipVisivel: CampoDeContato?
    private(set) var pilulaAberta: CampoDeContato?
    private(set) var copias = 0
    private(set) var aberturas = 0

    private let escrever: (String) -> Void
    private let pulsarTrava: ((Bool) -> Void)?
    private let geradorDaTrava = UIImpactFeedbackGenerator(style: .rigid)
    private var tarefaDoTip: Task<Void, Never>?
    private var tarefaDeFechamento: Task<Void, Never>?
    private var ultimoHaptic: Date?

    init(
        escrever: @escaping (String) -> Void = { UIPasteboard.general.string = $0 },
        pulsarTrava: ((Bool) -> Void)? = nil
    ) {
        self.escrever = escrever
        self.pulsarTrava = pulsarTrava
    }

    /// Toque simples: copia e mostra "Copiado" no lugar do valor.
    func copiar(_ campo: CampoDeContato, valor: String, agora: Date = Date()) {
        guard escreverValor(valor, agora: agora) else { return }
        tipVisivel = campo
        tarefaDoTip?.cancel()
        tarefaDoTip = Task { [weak self] in
            try? await Task.sleep(for: .seconds(FrilaMotion.copyTipHold))
            guard !Task.isCancelled else { return }
            self?.tipVisivel = nil
        }
    }

    /// Soltar o dedo com o nó travado: copia, e a própria pílula confirma antes de fechar.
    func concluirDeslize(_ campo: CampoDeContato, valor: String, agora: Date = Date()) {
        guard escreverValor(valor, agora: agora) else { return fechar() }
        tarefaDeFechamento?.cancel()
        tarefaDeFechamento = Task { [weak self] in
            try? await Task.sleep(for: .seconds(FrilaMotion.copyPillHold))
            guard !Task.isCancelled else { return }
            self?.pilulaAberta = nil
        }
    }

    func abrir(_ campo: CampoDeContato) {
        tipVisivel = nil
        tarefaDoTip?.cancel()
        tarefaDeFechamento?.cancel()
        pilulaAberta = campo
        aberturas += 1
        geradorDaTrava.prepare()
    }

    /// Um pulso por transição, igual ao travar e ao destravar. Vai direto ao gerador porque idas e
    /// vindas rápidas no mesmo ciclo do SwiftUI se fundiriam em um único gatilho de `sensoryFeedback`.
    func registrarAlternanciaDeTrava(ativa: Bool) {
        if let pulsarTrava {
            pulsarTrava(ativa)
        } else {
            geradorDaTrava.impactOccurred(intensity: FrilaMotion.copyLatchHapticIntensity)
            geradorDaTrava.prepare()
        }
    }

    func fechar() {
        tarefaDeFechamento?.cancel()
        pilulaAberta = nil
    }

    func limpar() {
        tarefaDoTip?.cancel()
        tarefaDeFechamento?.cancel()
        tipVisivel = nil
        pilulaAberta = nil
    }

    private func escreverValor(_ valor: String, agora: Date) -> Bool {
        guard !valor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        escrever(valor)
        if ultimoHaptic.map({ agora.timeIntervalSince($0) >= FrilaMotion.copyHapticInterval }) ?? true {
            copias += 1
            ultimoHaptic = agora
        }
        return true
    }
}

/// Texto que entra subindo de baixo, com desfoque, e sai para cima. É a animação do "Copiado",
/// usada tanto no valor do toque quanto na bolha do deslize.
private struct TextoRolante: View {
    let texto: String
    let identificador: String?
    var quebraLinha = false

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        Text(verbatim: texto)
            .fixedSize(horizontal: !quebraLinha, vertical: true)
            .accessibilityIdentifier(identificador ?? "")
            .id(texto)
            .transition(reduzirMovimento ? .opacity : Self.rolagem)
    }

    private static let rolagem: AnyTransition = .asymmetric(
        insertion: .modifier(active: RolagemDoTexto(y: 14, desfoque: 4), identity: RolagemDoTexto(y: 0, desfoque: 0)),
        removal: .modifier(active: RolagemDoTexto(y: -14, desfoque: 4), identity: RolagemDoTexto(y: 0, desfoque: 0))
    )
}

private struct RolagemDoTexto: ViewModifier {
    let y: CGFloat
    let desfoque: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: y)
            .blur(radius: desfoque)
            .opacity(desfoque > 0 ? 0 : 1)
    }
}

/// Par rótulo e valor. Em repouso é só texto: um toque copia. Segurar abre a pílula com o nó já ativo,
/// que segue o dedo; perto de "Copiar" ele é atraído e trava, e soltar travado executa a cópia.
struct ContatoCopiavel: View {
    let titulo: String
    let valor: String
    let id: String
    let campo: CampoDeContato
    let copia: CopiaDeContato

    private enum Fase {
        case repouso, arrastando, travado, copiado
    }

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var fase = Fase.repouso
    @State private var aberta = false
    @State private var posicao: CGFloat = 0
    @State private var mapeamento: MapeamentoDoArrasto?
    @State private var assentado = false
    @State private var recuando = false
    @State private var deslizando = false
    @State private var tarefaDeAssentamento: Task<Void, Never>?
    @State private var larguraDaLinha: CGFloat = 0
    @State private var larguraDoValor: CGFloat = 0
    @State private var larguraDeCopiar: CGFloat = 0
    @State private var larguraDeCopiado: CGFloat = 0

    private static let alturaDaPilula: CGFloat = 40
    private static let recuoDoNo: CGFloat = 3
    private static let excessoEsquerdo: CGFloat = 12
    private static let excessoDireito: CGFloat = 12
    private static let intervalo: CGFloat = 12
    private static let folgaDoRotulo: CGFloat = 14
    private static let cursoDaDissolucao: CGFloat = 36

    static let copyLensWidth: CGFloat = FrilaEspaco.grande * 5
    static let copyLensHeight: CGFloat = FrilaEspaco.enorme + FrilaEspaco.grande
    static let copyHitMinHeight: CGFloat = FrilaEspaco.enorme + FrilaEspaco.grande
    /// Assimétrica de propósito: a área de toque do contato sobra mais para baixo do que para cima.
    static let copyHitTopPadding: CGFloat = FrilaEspaco.minimo
    static let copyHitBottomPadding: CGFloat = FrilaEspaco.compacto
    /// Em pontos de dedo: a folga para destravar é a mesma, qualquer que seja o ganho do gesto.
    static let copyLatchHysteresis: CGFloat = FrilaEspaco.medio + FrilaEspaco.minimo
    static let copyDragMinTravel: CGFloat = FrilaEspaco.grande * 2
    static let copyDragMaxGain: CGFloat = 3

    /// Traduz o dedo em progresso do nó. É definido ao reconhecer o gesto e fica fixo até o fim. Sem
    /// curso físico à direita não existe mapeamento, e o toque longo nem começa.
    struct MapeamentoDoArrasto {
        let ganho: CGFloat

        init?(curso: CGFloat, folgaDireita: CGFloat) {
            let minimo = max(ContatoCopiavel.copyDragMinTravel, curso / ContatoCopiavel.copyDragMaxGain)
            guard folgaDireita >= minimo else { return nil }
            ganho = min(ContatoCopiavel.copyDragMaxGain, max(1, curso / min(curso, folgaDireita)))
        }

        func progresso(dx: CGFloat, curso: CGFloat) -> CGFloat {
            min(max(dx * ganho, 0), curso)
        }
    }

    /// Mesma decisão nos dois modos. A entrada e a saída têm limites diferentes para não oscilar.
    static func deveTravar(posicao: CGFloat, estavaTravado: Bool, curso: CGFloat, raio: CGFloat, ganho: CGFloat) -> Bool {
        let distancia = curso - posicao
        return estavaTravado ? distancia <= raio + copyLatchHysteresis * ganho : distancia <= raio
    }

    private var alturaDoNo: CGFloat { Self.alturaDaPilula - 2 * Self.recuoDoNo }
    private var bolhaCopiar: CGFloat { larguraDeCopiar + 2 * Self.folgaDoRotulo }
    private var bolhaCopiado: CGFloat { larguraDeCopiado + 2 * Self.folgaDoRotulo }

    /// A largura é reservada para "Copiado", a palavra maior: a pílula não muda de tamanho ao confirmar.
    private var larguraDaPilula: CGFloat {
        let ideal = Self.excessoEsquerdo + larguraDoValor + Self.intervalo + bolhaCopiado + Self.recuoDoNo
        return min(ideal, larguraDaLinha + Self.excessoEsquerdo + Self.excessoDireito)
    }
    private var valorVisivel: CGFloat {
        max(larguraDaPilula - Self.excessoEsquerdo - Self.intervalo - bolhaCopiado - Self.recuoDoNo, 0)
    }
    private var larguraInicialDoNo: CGFloat { Self.excessoEsquerdo + valorVisivel + Self.excessoEsquerdo - Self.recuoDoNo }
    private var centroInicial: CGFloat { Self.recuoDoNo + larguraInicialDoNo / 2 }
    private var centroFinal: CGFloat { larguraDaPilula - Self.recuoDoNo - bolhaCopiar / 2 }
    private var curso: CGFloat { max(centroFinal - centroInicial, 1) }
    private var raioDeCaptura: CGFloat { min(FrilaMotion.copyCaptureMax, curso * FrilaMotion.copyCaptureFraction) }

    var body: some View {
        if valor.isEmpty {
            par(valorExibido: TextosPerfilConta.naoInformado)
                .modifier(SuperficieDoContato())
        } else {
            par(valorExibido: valor)
                .modifier(SuperficieDoContato())
                .overlay {
                    ReconhecedorDeContato(
                        podeSegurar: { MapeamentoDoArrasto(curso: curso, folgaDireita: $0) != nil },
                        aoTocar: { copia.copiar(campo, valor: valor) },
                        aoSegurar: segurar,
                        aoMover: mover,
                        aoSoltar: soltar,
                        aoInterromper: interromper
                    )
                    .accessibilityHidden(true)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text(verbatim: TextosPerfilConta.copiar)) {
                    copia.copiar(campo, valor: valor)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { largura in
                    if largura != larguraDaLinha { interromper() }
                    larguraDaLinha = largura
                }
                .onChange(of: valor) { interromper() }
                .background(medidas)
                .zIndex(aberta ? 1 : 0)
                .onChange(of: copia.pilulaAberta) { _, agora in
                    if agora != campo { recolher() }
                }
        }
    }

    private func par(valorExibido: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: titulo)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("\(id)-rotulo")
                .opacity(aberta ? 0 : 1)
            valorOuCopiado(valorExibido)
                .opacity(aberta ? 0 : 1)
                .overlay(alignment: .leading) { pilula.allowsHitTesting(false) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var medidas: some View {
        ZStack {
            Text(verbatim: TextosPerfilConta.copiar)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { larguraDeCopiar = $0 }
            Text(verbatim: TextosPerfilConta.copiado)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { larguraDeCopiado = $0 }
        }
        .font(FrilaTipo.corpo)
        .fixedSize()
        .hidden()
    }

    /// O toque simples confirma no lugar do valor: "Copiado" entra na cor da marca e o valor volta sozinho.
    /// O valor oculto segura a altura e a largura, para um e-mail que quebra linha não mexer na tela.
    private func valorOuCopiado(_ valorExibido: String) -> some View {
        let copiado = copia.tipVisivel == campo
        return ZStack(alignment: .topLeading) {
            Text(verbatim: valorExibido)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { larguraDoValor = $0 }
            if copiado {
                TextoRolante(texto: TextosPerfilConta.copiado, identificador: "\(id)-copiado")
                    .foregroundStyle(FrilaCor.marca)
            } else {
                TextoRolante(texto: valorExibido, identificador: "\(id)-valor", quebraLinha: true)
                    .foregroundStyle(FrilaCor.texto)
            }
        }
        .font(FrilaTipo.corpo)
        .animation(FrilaMovimento.animacao(reduzirMovimento ? FrilaMotion.copyReducedFade : FrilaMotion.copyTextRoll, reduzir: reduzirMovimento, somenteOpacidade: true), value: copiado)
    }

    // MARK: - Pílula

    @ViewBuilder private var pilula: some View {
        if reduzirMovimento {
            pilulaEstatica
        } else {
            pilulaContinua
        }
    }

    /// Reduzir Movimento: tudo já está no lugar desde a abertura. O arrasto só alterna o estado do nó
    /// parado sobre "Copiar", em camadas fixas que trocam de opacidade.
    private var pilulaEstatica: some View {
        let ativo = fase == .travado || fase == .copiado
        return ZStack(alignment: .leading) {
            SombraDaPilula()
            textoDoValor
            ZStack {
                Capsule()
                    .fill(FrilaCor.superficieDoCampo)
                    .overlay(Capsule().fill(FrilaCor.texto.opacity(0.12)))
                Text(verbatim: TextosPerfilConta.copiar)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .opacity(ativo ? 0 : 1)
                Capsule()
                    .fill(FrilaCor.texto)
                    .opacity(ativo ? 1 : 0)
                Text(verbatim: TextosPerfilConta.copiar)
                    .foregroundStyle(FrilaCor.fundo)
                    .opacity(fase == .travado ? 1 : 0)
                Text(verbatim: TextosPerfilConta.copiado)
                    .foregroundStyle(FrilaCor.fundo)
                    .accessibilityIdentifier("\(id)-copiado")
                    .opacity(fase == .copiado ? 1 : 0)
            }
            .font(FrilaTipo.corpo)
            .frame(width: bolhaCopiado, height: alturaDoNo)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, Self.recuoDoNo)
        }
        .frame(width: larguraDaPilula, height: Self.alturaDaPilula)
        .opacity(aberta ? 1 : 0)
        .offset(x: -Self.excessoEsquerdo)
        .accessibilityHidden(fase != .copiado)
    }

    private var pilulaContinua: some View {
        ZStack(alignment: .leading) {
            SombraDaPilula()
            // Conteúdo fica sob o nó: é ele que o vidro refrata ao passar.
            textoDoValor
            Text(verbatim: TextosPerfilConta.copiar)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, Self.recuoDoNo + Self.folgaDoRotulo)
                .opacity(recuando ? 0 : 1)
        }
        .frame(width: recuando ? larguraInicialDoNo + 2 * Self.recuoDoNo : larguraDaPilula, height: Self.alturaDaPilula)
        // Em overlay, o nó não participa do layout: só a lente cresce e transborda, a pílula fica com 40 pt.
        .overlay(alignment: .leading) { no }
        .overlay(alignment: .leading) { capaDoNo }
        .opacity(aberta ? 1 : 0)
        .scaleEffect(aberta ? 1 : 0.97, anchor: .leading)
        .scaleEffect(deslizando ? FrilaMotion.copyPillDragScale : 1)
        .offset(x: -Self.excessoEsquerdo)
        .accessibilityHidden(fase != .copiado)
    }

    private var textoDoValor: some View {
        Text(verbatim: valor)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: valorVisivel, alignment: .leading)
            .padding(.leading, Self.excessoEsquerdo)
    }

    /// Geometria do nó em cada fase. Andando, tudo deriva da posição do dedo, sem saltos.
    private var geometriaDoNo: (largura: CGFloat, altura: CGFloat, centro: CGFloat) {
        switch fase {
        case .travado:
            return (bolhaCopiar, alturaDoNo, centroFinal)
        case .copiado:
            return (assentado ? bolhaCopiado : bolhaCopiar, alturaDoNo,
                    larguraDaPilula - Self.recuoDoNo - (assentado ? bolhaCopiado : bolhaCopiar) / 2)
        case .repouso, .arrastando:
            let avanco = min(posicao / max(curso * 0.25, 1), 1)
            let lente = min(Self.copyLensWidth, larguraDaPilula)
            return (
                larguraInicialDoNo + (lente - larguraInicialDoNo) * avanco,
                alturaDoNo + (Self.copyLensHeight - alturaDoNo) * avanco,
                centroInicial + posicaoAtraida
            )
        }
    }

    /// Nó: o vidro está sempre presente, então nunca há troca brusca de material. Depois de assentar
    /// em "Copiar", escurece por cima do vidro e recebe o rótulo.
    private var no: some View {
        let g = geometriaDoNo
        return ZStack {
            Capsule().fill(FrilaCor.texto).opacity(assentado ? 1 : 0)
            ZStack {
                if assentado, fase == .travado {
                    TextoRolante(texto: TextosPerfilConta.copiar, identificador: nil)
                } else if assentado, fase == .copiado {
                    TextoRolante(texto: TextosPerfilConta.copiado, identificador: "\(id)-copiado")
                }
            }
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.fundo)
        }
        .clipShape(Capsule())
        .frame(width: g.largura, height: g.altura)
        .modifier(LenteDeVidro())
        .offset(x: g.centro - g.largura / 2)
    }

    /// Parado, o nó é cinza sólido com o valor nítido. Esta capa cobre o vidro e se dissolve conforme
    /// o dedo anda, e é isso que faz a passagem para a lente ser contínua.
    private var capaDoNo: some View {
        let g = geometriaDoNo
        let visibilidade = fase == .arrastando ? max(1 - posicao / Self.cursoDaDissolucao, 0) : 0
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(FrilaCor.superficieDoCampo)
                .overlay(Capsule().fill(FrilaCor.texto.opacity(0.12)))
                .frame(width: g.largura, height: g.altura)
                .offset(x: g.centro - g.largura / 2)
            textoDoValor
        }
        .opacity(visibilidade)
    }

    /// Conforme chega perto de "Copiar", o nó é puxado para o destino, antes mesmo da trava.
    private var posicaoAtraida: CGFloat {
        let distancia = curso - posicao
        let alcance = raioDeCaptura * 2
        guard distancia < alcance else { return posicao }
        let forca = 1 - distancia / alcance
        return posicao + forca * forca * distancia * 0.5
    }

    // MARK: - Gesto

    private func segurar(folga: CGFloat) {
        guard let novo = MapeamentoDoArrasto(curso: curso, folgaDireita: folga) else { return }
        mapeamento = novo
        posicao = 0
        assentado = false
        recuando = false
        tarefaDeAssentamento?.cancel()
        fase = .arrastando
        copia.abrir(campo)
        withAnimation(FrilaMovimento.animacao(reduzirMovimento ? FrilaMotion.copyReducedFade : FrilaMotion.copyPillOpen, reduzir: reduzirMovimento, somenteOpacidade: true)) {
            aberta = true
        }
    }

    private func mover(dx: CGFloat) {
        guard aberta, fase == .arrastando || fase == .travado, let mapeamento else { return }
        let progresso = mapeamento.progresso(dx: dx, curso: curso)
        if !reduzirMovimento { posicao = progresso }
        let estavaTravado = fase == .travado
        let travar = Self.deveTravar(posicao: progresso, estavaTravado: estavaTravado, curso: curso, raio: raioDeCaptura, ganho: mapeamento.ganho)
        if !reduzirMovimento, !travar, !deslizando, progresso > 0 {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyPillDragSpring, reduzir: reduzirMovimento)) {
                deslizando = true
            }
        }
        guard travar != estavaTravado else { return }
        copia.registrarAlternanciaDeTrava(ativa: travar)
        if reduzirMovimento {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyReducedFade, reduzir: reduzirMovimento, somenteOpacidade: true)) {
                fase = travar ? .travado : .arrastando
            }
        } else if travar {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyLatchSpring, reduzir: reduzirMovimento)) {
                fase = .travado
                deslizando = false
            }
            assentarDepois { fase == .travado }
        } else {
            tarefaDeAssentamento?.cancel()
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyLatchSpring, reduzir: reduzirMovimento)) {
                fase = .arrastando
                assentado = false
            }
        }
    }

    /// O nó primeiro assenta sobre "Copiar"; só então escurece e o rótulo entra.
    private func assentarDepois(_ aindaValido: @escaping () -> Bool) {
        tarefaDeAssentamento?.cancel()
        tarefaDeAssentamento = Task { @MainActor in
            try? await Task.sleep(for: .seconds(FrilaMotion.copySettleDelay))
            guard !Task.isCancelled, aindaValido() else { return }
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyTextRoll, reduzir: reduzirMovimento)) {
                assentado = true
            }
        }
    }

    private func soltar() {
        guard aberta else { return }
        if fase == .travado {
            // Copia já no soltar. Se ainda não assentou, a troca visual espera a tarefa em curso.
            withAnimation(FrilaMovimento.animacao(reduzirMovimento ? FrilaMotion.copyReducedFade : FrilaMotion.copyTextRoll, reduzir: reduzirMovimento, somenteOpacidade: true)) {
                fase = .copiado
            }
            if !assentado, !reduzirMovimento { assentarDepois { fase == .copiado } }
            copia.concluirDeslize(campo, valor: valor)
        } else if fase == .arrastando {
            cancelar()
        }
    }

    /// O sistema interrompeu o gesto: só soltar é intenção de copiar, mesmo com o nó travado.
    private func interromper() {
        guard aberta, fase == .arrastando || fase == .travado else { return }
        tarefaDeAssentamento?.cancel()
        // Sem recuo neste modo: a fase fica como está e a pílula inteira some no fade do recolhimento.
        if reduzirMovimento { return copia.fechar() }
        if fase == .travado {
            assentado = false
            fase = .arrastando
        }
        cancelar()
    }

    /// Soltar antes da trava: a lente volta para o valor enquanto a pílula se retrai até ele, e some.
    private func cancelar() {
        if reduzirMovimento { return copia.fechar() }
        withAnimation(FrilaMovimento.animacao(FrilaMotion.copyCancelSpring, reduzir: reduzirMovimento), completionCriteria: .logicallyComplete) {
            posicao = 0
            recuando = true
            deslizando = false
        } completion: {
            copia.fechar()
        }
    }

    private func recolher() {
        tarefaDeAssentamento?.cancel()
        withAnimation(FrilaMovimento.animacao(reduzirMovimento ? FrilaMotion.copyReducedFade : FrilaMotion.copyPillClose, reduzir: reduzirMovimento, somenteOpacidade: true)) {
            aberta = false
        } completion: {
            guard !aberta else { return }
            fase = .repouso
            posicao = 0
            assentado = false
            recuando = false
            deslizando = false
            mapeamento = nil
        }
    }
}

/// Reserva a área de toque e o ritmo vertical do contato, sem mudar o par de texto.
private struct SuperficieDoContato: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.top, ContatoCopiavel.copyHitTopPadding)
            .padding(.bottom, ContatoCopiavel.copyHitBottomPadding)
            .frame(maxWidth: .infinity, minHeight: ContatoCopiavel.copyHitMinHeight, alignment: .topLeading)
    }
}

/// Vidro nativo do nó. Abaixo do iOS 26, um véu neutro faz o mesmo papel.
private struct LenteDeVidro: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.clear.tint(FrilaCor.texto.opacity(0.10)), in: Capsule())
        } else {
            content.background(FrilaCor.texto.opacity(0.10), in: Capsule())
        }
    }
}

/// Superfície da pílula com sombra em camadas: fio fino mais cinco degraus que dobram de distância,
/// neutros, para a pílula se destacar da tela durante o toque longo.
private struct SombraDaPilula: View {
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        ZStack {
            ForEach([1.0, 3.0, 6.0, 12.0, 24.0], id: \.self) { y in
                Capsule()
                    .fill(FrilaCor.superficieDoCampo)
                    .shadow(color: .black.opacity(esquema == .dark ? 0.24 : 0.07), radius: y / 2, y: y)
            }
            Capsule()
                .fill(FrilaCor.superficieDoCampo)
            Capsule()
                .strokeBorder(esquema == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

/// Ponte UIKit: o toque só vale se o toque longo falhar, e mover antes do tempo libera a rolagem.
/// Depois de reconhecido, o mesmo contato informa o deslocamento horizontal até o dedo sair.
private struct ReconhecedorDeContato: UIViewRepresentable {
    let podeSegurar: (CGFloat) -> Bool
    let aoTocar: () -> Void
    let aoSegurar: (CGFloat) -> Void
    let aoMover: (CGFloat) -> Void
    let aoSoltar: () -> Void
    let aoInterromper: () -> Void

    func makeCoordinator() -> Coordenador { Coordenador(self) }

    func makeUIView(context: Context) -> UIView {
        let vista = UIView()
        vista.backgroundColor = .clear
        let longo = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordenador.segurou(_:)))
        longo.minimumPressDuration = FrilaMotion.copyLongPress
        longo.allowableMovement = 10
        longo.delegate = context.coordinator
        let toque = ToqueCurto(target: context.coordinator, action: #selector(Coordenador.tocou))
        toque.require(toFail: longo)
        vista.addGestureRecognizer(longo)
        vista.addGestureRecognizer(toque)
        return vista
    }

    func updateUIView(_ vista: UIView, context: Context) {
        context.coordinator.ponte = self
    }

    /// Na faixa sem curso, o toque longo é rejeitado aos 0,45 s e libera o toque: sem este limite,
    /// segurar e soltar ali copiaria.
    final class ToqueCurto: UITapGestureRecognizer {
        private var inicio: TimeInterval = 0

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            inicio = event.timestamp
            super.touchesBegan(touches, with: event)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            if event.timestamp - inicio >= FrilaMotion.copyLongPress {
                state = .failed
            }
            super.touchesEnded(touches, with: event)
        }
    }

    @MainActor
    final class Coordenador: NSObject, UIGestureRecognizerDelegate {
        var ponte: ReconhecedorDeContato
        private var inicio: CGFloat = 0

        init(_ ponte: ReconhecedorDeContato) { self.ponte = ponte }

        @objc func tocou() { ponte.aoTocar() }

        func gestureRecognizerShouldBegin(_ gesto: UIGestureRecognizer) -> Bool {
            guard let vista = gesto.view else { return false }
            return ponte.podeSegurar(folga(de: gesto, em: vista))
        }

        private func folga(de gesto: UIGestureRecognizer, em vista: UIView) -> CGFloat {
            vista.bounds.width - gesto.location(in: vista).x
        }

        @objc func segurou(_ gesto: UILongPressGestureRecognizer) {
            let janela = gesto.view?.window
            let x = gesto.location(in: janela).x
            switch gesto.state {
            case .began:
                inicio = x
                ponte.aoSegurar(gesto.view.map { folga(de: gesto, em: $0) } ?? 0)
            case .changed:
                ponte.aoMover(x - inicio)
            case .ended:
                ponte.aoSoltar()
            case .cancelled, .failed:
                ponte.aoInterromper()
            default:
                break
            }
        }
    }
}
