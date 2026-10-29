#if FRILA_DESIGN
import SwiftUI
import Observation
import UIKit

struct RegistroDebugDesign {
    let id: String
    let titulo: String
    let variantes: [String]
    let decisoes: [String]
}

@Observable @MainActor
final class ContextoDebugDesign {
    var registro: RegistroDebugDesign?
    var selecao: String?
    var selecionar: ((String?) -> Void)?

    func apresentar(_ registro: RegistroDebugDesign, selecionar: @escaping (String?) -> Void) {
        self.registro = registro
        self.selecao = nil
        self.selecionar = selecionar
    }

    func retirar(_ id: String) {
        guard registro?.id == id else { return }
        selecionar?(nil)
        registro = nil
        selecao = nil
        selecionar = nil
    }
}

private struct ContextoDebugKey: EnvironmentKey {
    static let defaultValue: ContextoDebugDesign? = nil
}

extension EnvironmentValues {
    var contextoDebugDesign: ContextoDebugDesign? {
        get { self[ContextoDebugKey.self] }
        set { self[ContextoDebugKey.self] = newValue }
    }
}

struct RegistroDebugModifier: ViewModifier {
    @Environment(\.contextoDebugDesign) private var contexto
    let registro: RegistroDebugDesign
    @Binding var variante: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                contexto?.apresentar(registro) { variante = $0 }
            }
            .onDisappear { contexto?.retirar(registro.id) }
    }
}

public extension View {
    func modoDebugDesign() -> some View {
        modifier(PainelDebugModifier())
    }
}

private struct PainelDebugModifier: ViewModifier {
    @State private var contexto = ContextoDebugDesign()
    @State private var aberto = false
    @State private var progresso: CGFloat = 0
    @State private var tamanho: CGSize = .zero
    @State private var areaSeguraInferior: CGFloat = 0
    private let raioMoldura: CGFloat = 54
    private let folgaDesejada: CGFloat = 8
    private let referenciaReducao: CGFloat = 38

    private var reducao: CGFloat {
        let altura = max(tamanho.height, referenciaReducao + tamanho.width / 2 + 1)
        let reducaoAtual = min(referenciaReducao / (altura - tamanho.width / 2), 0.25)
        let comFolgaMinima = (60 - areaSeguraInferior) / altura
        let comFolgaLateral = (52 - areaSeguraInferior) / (altura - tamanho.width / 2)
        return min(reducaoAtual, max(0, comFolgaMinima, comFolgaLateral))
    }

    private var alturaCabecalho: CGFloat {
        min(44 + 2 * folgaDesejada, tamanho.height * reducao + areaSeguraInferior)
    }
    @State private var informacoes = false
    @State private var versoesAbertas = false
    @State private var linhaDestacada: Int?
    @State private var quadrosDasVariantes: [Int: CGRect] = [:]
    private let retornoDeSelecao = UISelectionFeedbackGenerator()
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.accessibilityReduceTransparency) private var reduzirTransparencia

    func body(content: Content) -> some View {
        content
            .molduraDebug(progresso: progresso, reducao: reducao, areaSeguraInferior: areaSeguraInferior,
                          raio: raioMoldura, reduzirMovimento: reduzirMovimento)
            .allowsHitTesting(!aberto)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { tamanho = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { areaSeguraInferior = $0 }
            .environment(\.contextoDebugDesign, contexto)
            .background {
                DetectorDePressaoDeDoisDedos {
                    alterarPainel(aberto: !aberto)
                }
                .frame(width: 0, height: 0)
            }
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(MagnifyGesture().onEnded { valor in
                        if aberto && valor.magnification >= 1.15 {
                            alterarPainel(aberto: false)
                        }
                    })
                    .allowsHitTesting(aberto)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .top) {
                cabecalho
                    .environment(\.colorScheme, .dark)
                    .frame(height: alturaCabecalho, alignment: .center)
                    .opacity(progresso)
                    .offset(y: reduzirMovimento ? 0 : -alturaCabecalho * (1 - progresso))
                    .allowsHitTesting(aberto)
            }
            .overlay(alignment: .topLeading) {
                if versoesAbertas, let registro = contexto.registro {
                    painelDeVariantes(registro)
                        .environment(\.colorScheme, .dark)
                }
            }
            .onChange(of: contexto.registro?.id) { _, _ in fecharVersoes() }
    }

    private func alterarPainel(aberto novoValor: Bool) {
        aberto = novoValor
        if !novoValor { fecharVersoes() }
        // A geometria não anima com Reduzir Movimento; a opacidade ainda dissolve.
        withAnimation(FrilaMovimento.animacao(.timingCurve(0.2, 0, 0, 1, duration: 0.45), reduzir: false)) {
            progresso = novoValor ? 1 : 0
        }
    }

    @ViewBuilder
    private var cabecalho: some View {
        if #available(iOS 26, *), !reduzirTransparencia {
            GlassEffectContainer(spacing: FrilaEspaco.pequeno) { conteudoDoCabecalho }
        } else {
            conteudoDoCabecalho
        }
    }

    private var conteudoDoCabecalho: some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            if let registro = contexto.registro, !registro.variantes.isEmpty {
                Button {
                    if versoesAbertas { fecharVersoes() } else { abrirVersoes() }
                } label: {
                    rotuloDoBotao("Versões", simbolo: "square.stack.3d.up")
                        .vidroDebug(reduzirTransparencia: reduzirTransparencia)
                }
                .accessibilityIdentifier("debug-versoes")
                .simultaneousGesture(gestoDeSelecao)
            }
            if let registro = contexto.registro {
                Text(verbatim: contexto.selecao ?? registro.titulo)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            if let registro = contexto.registro, !registro.decisoes.isEmpty {
                Button { informacoes = true } label: {
                    rotuloDoBotao("Info", simbolo: "info.circle")
                        .vidroDebug(reduzirTransparencia: reduzirTransparencia)
                }
                .popover(isPresented: $informacoes) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(registro.decisoes, id: \.self) { Text(verbatim: $0) }
                    }.padding()
                }
            }
            Button {
                alterarPainel(aberto: false)
            } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
                    .vidroDebug(reduzirTransparencia: reduzirTransparencia)
            }
                .accessibilityLabel(Text("Fechar", bundle: bundleApresentacao))
        }
        .font(FrilaTipo.chip)
        .foregroundStyle(FrilaCor.texto)
        .padding(.horizontal, FrilaEspaco.medio)
    }

    private func abrirVersoes() {
        retornoDeSelecao.prepare()
        withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.18), reduzir: reduzirMovimento)) {
            versoesAbertas = true
        }
    }

    private func fecharVersoes() {
        versoesAbertas = false
        linhaDestacada = nil
        quadrosDasVariantes = [:]
    }

    private func escolherVariante(_ indice: Int) {
        guard let registro = contexto.registro, registro.variantes.indices.contains(indice) else { return }
        let variante = registro.variantes[indice]
        contexto.selecao = variante
        contexto.selecionar?(variante)
        fecharVersoes()
    }

    private var gestoDeSelecao: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { valor in
                guard aberto else { return }
                if !versoesAbertas { abrirVersoes() }
                let linha = quadrosDasVariantes.first { $0.value.contains(valor.location) }?.key
                if linha != linhaDestacada {
                    linhaDestacada = linha
                    if linha != nil { retornoDeSelecao.selectionChanged() }
                }
            }
            .onEnded { valor in
                let linha = quadrosDasVariantes.first { $0.value.contains(valor.location) }?.key
                if let linha { escolherVariante(linha) } else { linhaDestacada = nil }
            }
    }

    private func painelDeVariantes(_ registro: RegistroDebugDesign) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { fecharVersoes() }
                .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: registro.titulo)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .padding(.horizontal, FrilaEspaco.medio)
                        .padding(.vertical, FrilaEspaco.pequeno)
                    ForEach(Array(registro.variantes.enumerated()), id: \.offset) { indice, variante in
                        Button { escolherVariante(indice) } label: {
                            HStack(spacing: FrilaEspaco.pequeno) {
                                GalhoDebug(ultimo: indice == registro.variantes.count - 1)
                                    .stroke(FrilaCor.textoSecundario, lineWidth: 1)
                                    .frame(width: FrilaEspaco.medio, height: 44)
                                Text(verbatim: variante)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if contexto.selecao == variante {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, FrilaEspaco.medio)
                            .frame(minHeight: 44)
                            .background(linhaDestacada == indice ? FrilaCor.superficie : .clear,
                                        in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: variante))
                        .accessibilityAddTraits(contexto.selecao == variante ? .isSelected : [])
                        .accessibilityIdentifier("debug-variante-\(registro.id)-\(indice)")
                        .background {
                            GeometryReader { geometria in
                                Color.clear.preference(key: QuadrosVariantesDebug.self,
                                    value: [indice: geometria.frame(in: .global)])
                            }
                        }
                    }
                }
                .padding(.vertical, FrilaEspaco.pequeno)
            }
            .frame(width: min(320, max(0, tamanho.width - 2 * FrilaEspaco.medio)))
            .frame(height: min(CGFloat(registro.variantes.count) * 44 + 52,
                               max(100, tamanho.height - alturaCabecalho - FrilaEspaco.medio)))
            .vidroDoPainelDebug(reduzirTransparencia: reduzirTransparencia)
            .padding(.leading, FrilaEspaco.medio)
            .padding(.top, alturaCabecalho)
            .simultaneousGesture(gestoDeSelecao)
            .onPreferenceChange(QuadrosVariantesDebug.self) { quadrosDasVariantes = $0 }
        }
        .simultaneousGesture(MagnifyGesture().onEnded { valor in
            if valor.magnification >= 1.15 { alterarPainel(aberto: false) }
        })
    }

    private func rotuloDoBotao(_ titulo: LocalizedStringKey, simbolo: String) -> some View {
        Label { Text(titulo, bundle: bundleApresentacao) } icon: { Image(systemName: simbolo) }
            .padding(.horizontal, FrilaEspaco.compacto)
            .frame(minHeight: 44)
    }
}
private extension View {
    func molduraDebug(progresso: CGFloat, reducao: CGFloat, areaSeguraInferior: CGFloat,
                      raio: CGFloat, reduzirMovimento: Bool) -> some View {
        self
            .clipShape(FormaMolduraDebug(progresso: progresso, raio: raio))
            .shadow(color: .black.opacity(0.06 * progresso), radius: 3, y: 3)
            .shadow(color: .black.opacity(0.06 * progresso), radius: 12, y: 12)
            .shadow(color: .black.opacity(0.06 * progresso), radius: 24, y: 24)
            .scaleEffect(1 - reducao * progresso, anchor: .bottom)
            .offset(y: areaSeguraInferior * progresso)
            .transaction { if reduzirMovimento { $0.animation = nil } }
            .background {
                ZStack {
                    FrilaCor.fundo
                    Color.black.opacity(progresso)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    func vidroDoPainelDebug(reduzirTransparencia: Bool) -> some View {
        if #available(iOS 26, *), !reduzirTransparencia {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao))
        } else {
            self.background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.cartao))
        }
    }

    @ViewBuilder
    func vidroDebug(reduzirTransparencia: Bool) -> some View {
        if #available(iOS 26, *), !reduzirTransparencia {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.background(FrilaCor.superficie, in: Capsule())
        }
    }
}

private struct QuadrosVariantesDebug: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, novo in novo })
    }
}

private struct GalhoDebug: Shape {
    let ultimo: Bool
    func path(in rect: CGRect) -> Path {
        var caminho = Path()
        let x = rect.minX + rect.width / 2
        caminho.move(to: CGPoint(x: x, y: rect.minY))
        caminho.addLine(to: CGPoint(x: x, y: ultimo ? rect.midY : rect.maxY))
        caminho.move(to: CGPoint(x: x, y: rect.midY))
        caminho.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return caminho
    }
}

private struct FormaMolduraDebug: Shape {
    var progresso: CGFloat
    let raio: CGFloat
    var animatableData: CGFloat {
        get { progresso }
        set { progresso = newValue }
    }

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: raio * progresso, style: .continuous).path(in: rect)
    }
}

private struct DetectorDePressaoDeDoisDedos: UIViewRepresentable {
    let abrir: () -> Void

    func makeCoordinator() -> Coordenador { Coordenador(abrir: abrir) }

    func makeUIView(context: Context) -> AncoraDoGesto {
        let ancora = AncoraDoGesto()
        ancora.coordenador = context.coordinator
        return ancora
    }

    func updateUIView(_ view: AncoraDoGesto, context: Context) {
        context.coordinator.abrir = abrir
    }

    static func dismantleUIView(_ view: AncoraDoGesto, coordinator: Coordenador) {
        coordinator.desligar()
    }

    final class Coordenador: NSObject, UIGestureRecognizerDelegate {
        var abrir: () -> Void
        private weak var janela: UIWindow?
        private lazy var gesto: UILongPressGestureRecognizer = {
            let gesto = UILongPressGestureRecognizer(target: self, action: #selector(reconheceu(_:)))
            gesto.minimumPressDuration = 0.6
            gesto.numberOfTouchesRequired = 2
            gesto.cancelsTouchesInView = false
            gesto.delegate = self
            return gesto
        }()

        init(abrir: @escaping () -> Void) { self.abrir = abrir }

        func ligar(_ janela: UIWindow?) {
            guard self.janela !== janela else { return }
            desligar()
            self.janela = janela
            janela?.addGestureRecognizer(gesto)
        }

        func desligar() {
            janela?.removeGestureRecognizer(gesto)
            janela = nil
        }

        @objc private func reconheceu(_ gesto: UILongPressGestureRecognizer) {
            if gesto.state == .began { abrir() }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    final class AncoraDoGesto: UIView {
        weak var coordenador: Coordenador?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordenador?.ligar(window)
        }
    }
}
#endif
