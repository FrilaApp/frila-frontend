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
    @State private var informacoes = false
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.accessibilityReduceTransparency) private var reduzirTransparencia

    func body(content: Content) -> some View {
        content
            .molduraDebug(aberto: aberto)
            .environment(\.contextoDebugDesign, contexto)
            .background {
                DetectorDePressaoDeDoisDedos {
                    guard !aberto else { return }
                    withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.25), reduzir: reduzirMovimento)) {
                        aberto = true
                    }
                }
                .frame(width: 0, height: 0)
            }
            .overlay(alignment: .top) {
                if aberto {
                    cabecalho
                        .environment(\.colorScheme, .dark)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
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
                Menu {
                    Menu(registro.titulo) {
                        ForEach(registro.variantes, id: \.self) { variante in
                            Button(variante) {
                                contexto.selecao = variante
                                contexto.selecionar?(variante)
                            }
                        }
                    }
                } label: {
                    rotuloDoBotao("Versões", simbolo: "square.stack.3d.up")
                        .vidroDebug(reduzirTransparencia: reduzirTransparencia)
                }
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
                withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.25), reduzir: reduzirMovimento)) {
                    aberto = false
                }
            } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
                    .vidroDebug(reduzirTransparencia: reduzirTransparencia)
            }
                .accessibilityLabel(Text("Fechar", bundle: bundleApresentacao))
        }
        .font(FrilaTipo.chip)
        .foregroundStyle(FrilaCor.texto)
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.bottom, FrilaEspaco.pequeno)
    }

    private func rotuloDoBotao(_ titulo: LocalizedStringKey, simbolo: String) -> some View {
        Label { Text(titulo, bundle: bundleApresentacao) } icon: { Image(systemName: simbolo) }
            .padding(.horizontal, FrilaEspaco.compacto)
            .frame(minHeight: 44)
    }
}
private extension View {
    @ViewBuilder
    func molduraDebug(aberto: Bool) -> some View {
        if aberto {
            self
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 3)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 12)
                .shadow(color: .black.opacity(0.06), radius: 24, y: 24)
                .scaleEffect(0.93, anchor: .bottom)
                .padding(.bottom, 8)
                .allowsHitTesting(false)
                .background(Color.black.ignoresSafeArea())
        } else {
            self
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
