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

    func body(content: Content) -> some View {
        content
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
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
    }

    private var cabecalho: some View {
        HStack(spacing: 12) {
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
                    Image(systemName: "square.stack.3d.up")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Variantes", bundle: bundleApresentacao))
            }
            if let registro = contexto.registro, !registro.decisoes.isEmpty {
                Button { informacoes = true } label: {
                    Image(systemName: "info.circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Informações", bundle: bundleApresentacao))
                .popover(isPresented: $informacoes) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(registro.decisoes, id: \.self) { Text(verbatim: $0) }
                    }.padding()
                }
            }
            Spacer()
            Button {
                withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.25), reduzir: reduzirMovimento)) {
                    aberto = false
                }
            } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel(Text("Fechar", bundle: bundleApresentacao))
        }
        .foregroundStyle(FrilaCor.texto)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(FrilaCor.superficie)
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
