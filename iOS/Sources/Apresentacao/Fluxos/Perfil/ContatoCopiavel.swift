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
    private var ultimoPulsoDeTrava: Date?
    private var tarefaDoPulsoDeSaida: Task<Void, Never>?

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
    func registrarAlternanciaDeTrava(ativa: Bool, agora: Date = Date()) {
        if let pulsarTrava {
            pulsarTrava(ativa)
            return
        }
        tarefaDoPulsoDeSaida?.cancel()
        if ativa {
            pulsarTrava(ativa: true, agora: agora)
        } else {
            tarefaDoPulsoDeSaida = Task { [weak self] in
                try? await Task.sleep(for: .seconds(FrilaMotion.copyUnlatchHapticDelay))
                guard !Task.isCancelled else { return }
                self?.pulsarTrava(ativa: false, agora: Date())
            }
        }
    }

    private func pulsarTrava(ativa: Bool, agora: Date) {
        if let ultimo = ultimoPulsoDeTrava, agora.timeIntervalSince(ultimo) < FrilaMotion.copyLatchHapticMinGap { return }
        ultimoPulsoDeTrava = agora
        geradorDaTrava.impactOccurred(intensity: ativa ? FrilaMotion.copyLatchHapticIntensity : FrilaMotion.copyUnlatchHapticIntensity)
        geradorDaTrava.prepare()
    }

    func fechar() {
        tarefaDeFechamento?.cancel()
        pilulaAberta = nil
    }

    func limpar() {
        tarefaDoPulsoDeSaida?.cancel()
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
    var simbolo: String?

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        HStack(spacing: FrilaEspaco.minimo) {
            if let simbolo { Image(systemName: simbolo).imageScale(.small) }
            Text(verbatim: texto)
                .fixedSize(horizontal: !quebraLinha, vertical: true)
                .accessibilityIdentifier(identificador ?? "")
        }
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

enum AcaoDaRail: Hashable {
    case copiar, editar, compartilhar
}

/// Onde cada parada captura o nó e quanto ele resiste a sair. Com uma parada vale a regra aprovada da
/// cópia; com mais, o raio e a histerese de cada uma são limitados pela distância até as vizinhas.
struct ZonasDasParadas {
    let alvos: [CGFloat]
    let raios: [CGFloat]
    let histereses: [CGFloat]

    init(alvos: [CGFloat], curso: CGFloat, ganho: CGFloat) {
        self.alvos = alvos
        var raios: [CGFloat] = []
        var histereses: [CGFloat] = []
        for (i, alvo) in alvos.enumerated() {
            var distancia = CGFloat.infinity
            if alvos.count > 1 {
                distancia = min(distancia, alvo)
                if i > 0 { distancia = min(distancia, alvo - alvos[i - 1]) }
                if i < alvos.count - 1 { distancia = min(distancia, alvos[i + 1] - alvo) }
            }
            raios.append(min(FrilaMotion.copyCaptureMax, curso * FrilaMotion.copyCaptureFraction, distancia * FrilaMotion.copyStopCaptureShare))
            histereses.append(min(ContatoCopiavel.copyLatchHysteresis * ganho, distancia * FrilaMotion.copyStopHysteresisShare))
        }
        self.raios = raios
        self.histereses = histereses
    }

    /// Escolhe pelo progresso bruto do dedo, nunca pela posição atraída. Travado, a parada resiste até o
    /// raio mais a histerese; fora dela, só a captura de uma zona prende o nó.
    func escolher(progresso: CGFloat, anterior: Int?) -> Int? {
        if let anterior, abs(progresso - alvos[anterior]) <= raios[anterior] + histereses[anterior] {
            return anterior
        }
        var melhor: Int?
        var menor = CGFloat.infinity
        for i in alvos.indices {
            let distancia = abs(progresso - alvos[i])
            if distancia <= raios[i], distancia < menor {
                melhor = i
                menor = distancia
            }
        }
        return melhor
    }
}

/// Par rótulo e valor. Em repouso é só texto: um toque copia. Segurar abre a pílula com o nó já ativo,
/// que segue o dedo; perto de uma parada ele é atraído e trava, e soltar travado executa a ação dela.
struct ContatoCopiavel: View {
    let titulo: String
    let valor: String
    let id: String
    let campo: CampoDeContato
    let copia: CopiaDeContato
    var acoes: [AcaoDaRail] = [.copiar]
    var edicao: EdicaoDeContato?
    var aoAcionar: (AcaoDaRail) -> Void = { _ in }
    var aoConfirmarEdicao: () -> Void = {}

    private enum Fase {
        case repouso, arrastando, travado, copiado
    }

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var fase = Fase.repouso
    @State private var acaoTravada = AcaoDaRail.copiar
    @State private var aberta = false
    @State private var posicao: CGFloat = 0
    @State private var mapeamento: MapeamentoDoArrasto?
    @State private var assentado = false
    @State private var recuando = false
    @State private var deslizando = false
    @State private var transitando = false
    @State private var tarefaDeAssentamento: Task<Void, Never>?
    @State private var larguraDaLinha: CGFloat = 0
    @State private var larguraDoValor: CGFloat = 0
    @State private var larguraDeCopiar: CGFloat = 0
    @State private var larguraDeCopiado: CGFloat = 0
    @State private var larguraDeEditar: CGFloat = 0

    private static let alturaDaPilula: CGFloat = 40
    private static let recuoDoNo: CGFloat = 3
    /// A pílula passa do valor só um pouco para os lados, e o texto dentro dela tem o respiro de sempre. Com o
    /// redimensionamento ancorado à esquerda, a borda nunca encosta na margem da tela.
    private static let excessoEsquerdo: CGFloat = 6
    private static let excessoDireito: CGFloat = 6
    private static let recuoDoTexto: CGFloat = 12
    private static let intervalo: CGFloat = 12
    private static let folgaDoRotulo: CGFloat = 10
    private static let cursoDaDissolucao: CGFloat = 36

    static let copyHitMinHeight: CGFloat = FrilaEspaco.enorme + FrilaEspaco.grande
    /// Assimétrica de propósito: a área de toque do contato sobra mais para baixo do que para cima.
    static let copyHitTopPadding: CGFloat = FrilaEspaco.minimo
    static let copyHitBottomPadding: CGFloat = FrilaEspaco.medio + FrilaEspaco.minimo
    /// Em pontos de dedo: a folga para destravar é a mesma, qualquer que seja o ganho do gesto.
    static let copyLatchHysteresis: CGFloat = FrilaEspaco.medio + FrilaEspaco.minimo
    static let copyDragMinTravel: CGFloat = FrilaEspaco.grande * 2
    static let copyDragMaxGain: CGFloat = 3
    static let copyStopSpacing: CGFloat = FrilaEspaco.minimo
    /// Na troca entre paradas a lente é só um pouco maior que o nó, para a viagem ser macia e não pesada.
    static let copySwitchLensGrowX: CGFloat = FrilaEspaco.grande + FrilaEspaco.medio
    static let copySwitchLensGrowY: CGFloat = FrilaEspaco.grande
    static let copyLensWidth: CGFloat = FrilaEspaco.grande * 5 + FrilaEspaco.medio
    static let copyLensHeight: CGFloat = FrilaEspaco.grande * 2 + FrilaEspaco.medio
    private static let simboloDeEditar = "pencil"

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

    private var alturaDoNo: CGFloat { Self.alturaDaPilula - 2 * Self.recuoDoNo }
    private var bolhaCopiar: CGFloat { larguraDeCopiar + 2 * Self.folgaDoRotulo }
    private var bolhaCopiado: CGFloat { larguraDeCopiado + 2 * Self.folgaDoRotulo }

    private func titulo(da acao: AcaoDaRail) -> String {
        switch acao {
        case .copiar: TextosPerfilConta.copiar
        case .editar: TextosPerfilConta.editar
        case .compartilhar: ""
        }
    }

    private func simbolo(da acao: AcaoDaRail) -> String? {
        acao == .editar ? Self.simboloDeEditar : nil
    }

    /// Rótulo da parada: o texto, e o símbolo quando a ação tem um.
    private func rotulo(da acao: AcaoDaRail) -> some View {
        HStack(spacing: FrilaEspaco.minimo) {
            if let simbolo = simbolo(da: acao) { Image(systemName: simbolo).imageScale(.small) }
            Text(verbatim: titulo(da: acao))
        }
    }

    /// Cada parada reserva a largura da maior palavra que pode mostrar: "Copiar" reserva "Copiado".
    private func larguraDaParada(_ acao: AcaoDaRail) -> CGFloat {
        switch acao {
        case .copiar: bolhaCopiado
        case .editar: larguraDeEditar + 2 * Self.folgaDoRotulo
        case .compartilhar: 0
        }
    }

    private var somaDasParadas: CGFloat {
        acoes.map(larguraDaParada).reduce(0, +) + CGFloat(max(acoes.count - 1, 0)) * Self.copyStopSpacing
    }

    private var larguraDaPilula: CGFloat {
        let ideal = Self.recuoDoTexto + larguraDoValor + Self.intervalo + somaDasParadas + Self.recuoDoNo
        // Cresce ao deslizar: o teto já conta o aumento, para a borda direita também não encostar na tela.
        let teto = (larguraDaLinha + Self.excessoEsquerdo + Self.excessoDireito) / FrilaMotion.copyPillDragScale
        return min(ideal, teto)
    }
    private var valorVisivel: CGFloat {
        max(larguraDaPilula - Self.recuoDoTexto - Self.intervalo - somaDasParadas - Self.recuoDoNo, 0)
    }
    private var larguraInicialDoNo: CGFloat { Self.recuoDoTexto + valorVisivel + Self.recuoDoTexto - Self.recuoDoNo }
    private var centroInicial: CGFloat { Self.recuoDoNo + larguraInicialDoNo / 2 }

    /// Centros das paradas, alinhadas à direita, em coordenadas da pílula.
    private var centrosDasParadas: [CGFloat] {
        var direita = larguraDaPilula - Self.recuoDoNo
        var centros = [CGFloat](repeating: 0, count: acoes.count)
        for i in acoes.indices.reversed() {
            let largura = larguraDaParada(acoes[i])
            centros[i] = direita - largura / 2
            direita -= largura + Self.copyStopSpacing
        }
        return centros
    }
    private var alvos: [CGFloat] { centrosDasParadas.map { $0 - centroInicial } }
    private var curso: CGFloat { max((centrosDasParadas.last ?? centroInicial) - centroInicial, 1) }
    private func zonas(ganho: CGFloat) -> ZonasDasParadas { ZonasDasParadas(alvos: alvos, curso: curso, ganho: ganho) }
    private var indiceTravado: Int? { acoes.firstIndex(of: acaoTravada) }
    private func centro(de acao: AcaoDaRail) -> CGFloat {
        guard let i = acoes.firstIndex(of: acao) else { return centroInicial }
        return centrosDasParadas[i]
    }

    var body: some View {
        if valor.isEmpty {
            par(valorExibido: TextosPerfilConta.naoInformado)
                .modifier(SuperficieDoContato())
        } else {
            par(valorExibido: valor)
                .modifier(SuperficieDoContato())
                .overlay {
                    if edicao?.campo == nil {
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
        let editando = edicao?.campo == campo
        return VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: titulo)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("\(id)-rotulo")
                .opacity(aberta ? 0 : 1)
            valorOuCopiado(valorExibido)
                .opacity(aberta || editando ? 0 : 1)
                .frame(maxWidth: .infinity, minHeight: editando ? FrilaMetrica.alturaDoCampo : nil, alignment: .leading)
                .overlay(alignment: .leading) {
                    if editando, let edicao { editor(edicao) }
                }
                .overlay(alignment: .leading) { pilula.allowsHitTesting(false) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(FrilaMovimento.animacao(FrilaMotion.copyPillOpen, reduzir: reduzirMovimento), value: editando)
    }

    /// Mesmas proporções do campo do app (`CampoFrila`, `CaixaDoCampoFrila`): 52 pt, respiro de 16 e 8, raio de
    /// entrada e superfície do campo, só sem o contorno. O foco vem junto com a entrada, então o teclado sobe
    /// com a pílula saindo.
    private func editor(_ edicao: EdicaoDeContato) -> some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            CampoDeEdicaoDeContato(
                edicao: edicao, campo: campo, identificador: "\(id)-editar", aoConfirmar: aoConfirmarEdicao
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            // Saída explícita, além de tocar fora: descarta o rascunho e fecha o teclado.
            Button { edicao.cancelar() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minWidth: FrilaEspaco.enorme, minHeight: FrilaEspaco.enorme)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -FrilaEspaco.pequeno)
            .accessibilityLabel(Text(verbatim: TextosPerfilConta.fechar))
            .accessibilityIdentifier("\(id)-editar-fechar")
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.pequeno)
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
        .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
        .frilaFormField(id: "\(id)-editar", isFocused: edicao.focado, onDismiss: { edicao.cancelar() })
        .transition(.opacity)
    }

    private var medidas: some View {
        ZStack {
            Text(verbatim: TextosPerfilConta.copiar)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { larguraDeCopiar = $0 }
            Text(verbatim: TextosPerfilConta.copiado)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { larguraDeCopiado = $0 }
            rotulo(da: .editar)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { larguraDeEditar = $0 }
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
    /// parado sobre a parada escolhida, em camadas fixas que trocam de opacidade.
    private var pilulaEstatica: some View {
        let ativo = fase == .travado || fase == .copiado
        return ZStack(alignment: .leading) {
            SombraDaPilula()
            textoDoValor
            HStack(spacing: Self.copyStopSpacing) {
                ForEach(acoes, id: \.self) { acao in
                    let selecionada = ativo && acaoTravada == acao
                    let confirmando = acao == .copiar && fase == .copiado
                    ZStack {
                        Capsule()
                            .fill(FrilaCor.superficieDoCampo)
                            .overlay(Capsule().fill(FrilaCor.texto.opacity(0.12)))
                        rotulo(da: acao)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .opacity(selecionada ? 0 : 1)
                        Capsule()
                            .fill(FrilaCor.texto)
                            .opacity(selecionada ? 1 : 0)
                        rotulo(da: acao)
                            .foregroundStyle(FrilaCor.fundo)
                            .opacity(selecionada && !confirmando ? 1 : 0)
                        if acao == .copiar {
                            Text(verbatim: TextosPerfilConta.copiado)
                                .foregroundStyle(FrilaCor.fundo)
                                .accessibilityIdentifier("\(id)-copiado")
                                .opacity(confirmando ? 1 : 0)
                        }
                    }
                    .font(FrilaTipo.corpo)
                    .frame(width: larguraDaParada(acao), height: alturaDoNo)
                }
            }
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
            HStack(spacing: Self.copyStopSpacing) {
                ForEach(acoes, id: \.self) { acao in
                    rotulo(da: acao)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(width: larguraDaParada(acao))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, Self.recuoDoNo)
            .opacity(recuando ? 0 : 1)
        }
        .frame(width: recuando ? larguraInicialDoNo + 2 * Self.recuoDoNo : larguraDaPilula, height: Self.alturaDaPilula)
        // Em overlay, o nó não participa do layout: só a lente cresce e transborda, a pílula fica com 40 pt.
        .overlay(alignment: .leading) { no }
        .overlay(alignment: .leading) { capaDoNo }
        .opacity(aberta ? 1 : 0)
        .scaleEffect(aberta ? 1 : 0.97, anchor: .leading)
        .scaleEffect(deslizando ? FrilaMotion.copyPillDragScale : 1, anchor: .leading)
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
            .padding(.leading, Self.recuoDoTexto)
    }

    /// Geometria do nó em cada fase. Andando, tudo deriva da posição do dedo, sem saltos.
    private var geometriaDoNo: (largura: CGFloat, altura: CGFloat, centro: CGFloat) {
        switch fase {
        case .travado:
            // Trocando de parada, o nó é lente enquanto viaja: o vidro vem do efeito, não do dedo.
            let natural = acaoTravada == .copiar ? bolhaCopiar : larguraDaParada(acaoTravada)
            if transitando {
                return (natural + Self.copySwitchLensGrowX, alturaDoNo + Self.copySwitchLensGrowY, centro(de: acaoTravada))
            }
            return (natural, alturaDoNo, centro(de: acaoTravada))
        case .copiado:
            return (assentado ? bolhaCopiado : bolhaCopiar, alturaDoNo, centro(de: .copiar))
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
    /// na parada, escurece por cima do vidro e recebe o rótulo.
    private var no: some View {
        let g = geometriaDoNo
        return ZStack {
            Capsule().fill(FrilaCor.texto).opacity(assentado ? (transitando ? FrilaMotion.copySwitchFillOpacity : 1) : 0)
            ZStack {
                if assentado, fase == .travado {
                    TextoRolante(texto: titulo(da: acaoTravada), identificador: nil, simbolo: simbolo(da: acaoTravada))
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

    /// Conforme chega perto de uma parada, o nó é puxado para ela, antes mesmo da trava.
    private var posicaoAtraida: CGFloat {
        let z = zonas(ganho: mapeamento?.ganho ?? 1)
        var atraida = posicao
        var menor = CGFloat.infinity
        for i in z.alvos.indices {
            let distancia = z.alvos[i] - posicao
            let alcance = z.raios[i] * 2
            guard abs(distancia) < alcance, abs(distancia) < menor else { continue }
            let forca = 1 - abs(distancia) / alcance
            atraida = posicao + forca * forca * distancia * 0.5
            menor = abs(distancia)
        }
        return atraida
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
        transitando = false
        copia.abrir(campo)
        withAnimation(FrilaMovimento.animacao(reduzirMovimento ? FrilaMotion.copyReducedFade : FrilaMotion.copyPillOpen, reduzir: reduzirMovimento, somenteOpacidade: true)) {
            aberta = true
        }
    }

    private func mover(dx: CGFloat) {
        guard aberta, fase == .arrastando || fase == .travado, let mapeamento else { return }
        let progresso = mapeamento.progresso(dx: dx, curso: curso)
        if !reduzirMovimento { posicao = progresso }
        let anterior = fase == .travado ? indiceTravado : nil
        let nova = zonas(ganho: mapeamento.ganho).escolher(progresso: progresso, anterior: anterior)
        if !reduzirMovimento, nova == nil, !deslizando, progresso > 0 {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyPillDragSpring, reduzir: reduzirMovimento)) {
                deslizando = true
            }
        }
        guard nova != anterior else { return }
        tarefaDeAssentamento?.cancel()
        // Trocar direto de uma parada para outra é uma sensação só: o pulso é o da que prende.
        if nova != nil {
            copia.registrarAlternanciaDeTrava(ativa: true)
        } else if anterior != nil {
            copia.registrarAlternanciaDeTrava(ativa: false)
        }
        aplicarTrava(nova, direta: anterior != nil && nova != nil)
    }

    private func aplicarTrava(_ nova: Int?, direta: Bool) {
        if reduzirMovimento {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyReducedFade, reduzir: reduzirMovimento, somenteOpacidade: true)) {
                if let nova {
                    acaoTravada = acoes[nova]
                    fase = .travado
                } else {
                    fase = .arrastando
                }
            }
        } else if let nova {
            let acao = acoes[nova]
            withAnimation(FrilaMovimento.animacao(direta ? FrilaMotion.copySwitchSpring : FrilaMotion.copyLatchSpring, reduzir: reduzirMovimento)) {
                acaoTravada = acao
                fase = .travado
                deslizando = false
                // Troca direta: a cor ativa já vem na viagem. Entrada vinda do espaço livre: assenta depois.
                assentado = direta
                transitando = direta
            }
            assentarDepois(aposLente: direta) { fase == .travado && acaoTravada == acao }
        } else {
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyLatchSpring, reduzir: reduzirMovimento)) {
                fase = .arrastando
                assentado = false
                transitando = false
            }
        }
    }

    /// O nó primeiro assenta sobre a parada; só então escurece e o rótulo entra.
    private func assentarDepois(aposLente: Bool = false, _ aindaValido: @escaping () -> Bool) {
        tarefaDeAssentamento?.cancel()
        tarefaDeAssentamento = Task { @MainActor in
            if aposLente {
                try? await Task.sleep(for: .seconds(FrilaMotion.copySwitchLensHold))
                guard !Task.isCancelled, aindaValido() else { return }
                withAnimation(FrilaMovimento.animacao(FrilaMotion.copySwitchSpring, reduzir: reduzirMovimento)) {
                    transitando = false
                }
                return
            }
            try? await Task.sleep(for: .seconds(FrilaMotion.copySettleDelay))
            guard !Task.isCancelled, aindaValido() else { return }
            withAnimation(FrilaMovimento.animacao(FrilaMotion.copyTextRoll, reduzir: reduzirMovimento)) {
                assentado = true
            }
        }
    }

    private func soltar() {
        guard aberta else { return }
        guard fase == .travado else {
            if fase == .arrastando { cancelar() }
            return
        }
        // Outras ações entregam o evento no mesmo ciclo e a pílula some; o que vem depois é da tela.
        guard acaoTravada == .copiar else {
            tarefaDeAssentamento?.cancel()
            let acao = acaoTravada
            copia.fechar()
            aoAcionar(acao)
            return
        }
        // Copia já no soltar. Se ainda não assentou, a troca visual espera a tarefa em curso.
        withAnimation(FrilaMovimento.animacao(reduzirMovimento ? FrilaMotion.copyReducedFade : FrilaMotion.copyTextRoll, reduzir: reduzirMovimento, somenteOpacidade: true)) {
            fase = .copiado
        }
        if !assentado, !reduzirMovimento { assentarDepois { fase == .copiado } }
        copia.concluirDeslize(campo, valor: valor)
    }

    /// O sistema interrompeu o gesto: só soltar é intenção de agir, mesmo com o nó travado.
    private func interromper() {
        guard aberta, fase == .arrastando || fase == .travado else { return }
        tarefaDeAssentamento?.cancel()
        // Sem recuo neste modo: a fase fica como está e a pílula inteira some no fade do recolhimento.
        if reduzirMovimento { return copia.fechar() }
        if fase == .travado {
            assentado = false
            transitando = false
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
            transitando = false
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
