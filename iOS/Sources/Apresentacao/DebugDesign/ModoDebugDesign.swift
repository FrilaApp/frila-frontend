#if FRILA_DESIGN
import SwiftUI
import Observation

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
    @GestureState private var deslocamento: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    private let altura: CGFloat = 112
    private let limiar: CGFloat = 70

    private var progresso: CGFloat { aberto ? 1 : min(max(deslocamento / altura, 0), 1) }

    func body(content: Content) -> some View {
        GeometryReader { geometria in
            ZStack(alignment: .top) {
                FrilaCor.superficie.ignoresSafeArea()
                content
                    .environment(\.contextoDebugDesign, contexto)
                    .scaleEffect(1 - 0.035 * progresso, anchor: .bottom)
                    .offset(y: altura * progresso)
                    .clipShape(RoundedRectangle(cornerRadius: 16 * progresso))
                cabecalho
                    .frame(height: altura, alignment: .bottom)
                    .offset(y: -altura * (1 - progresso))
                    .opacity(progresso)
                    .allowsHitTesting(aberto)
                if !aberto {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: 160, height: max(44, geometria.safeAreaInsets.top))
                        .gesture(gesto)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var gesto: some Gesture {
        LongPressGesture(minimumDuration: 0.15, maximumDistance: 20)
            .sequenced(before: DragGesture(minimumDistance: 1))
            .updating($deslocamento) { valor, estado, _ in
                if case let .second(true, arrasto?) = valor {
                    estado = max(0, arrasto.translation.height)
                }
            }
            .onEnded { valor in
                if case let .second(true, arrasto?) = valor, arrasto.translation.height >= limiar {
                    withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.25), reduzir: reduzirMovimento)) {
                        aberto = true
                    }
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
#endif
