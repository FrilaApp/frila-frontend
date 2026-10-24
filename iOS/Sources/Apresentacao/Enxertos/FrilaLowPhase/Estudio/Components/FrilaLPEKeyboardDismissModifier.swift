import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Modelo de cálculo da janela útil de visualização durante digitação (M21 / SPEC 2.4).
public struct FrilaLPEVisibleWindow: Equatable, Sendable {
    public let viewportTop: CGFloat
    public let headerBottom: CGFloat
    public let viewportBottom: CGFloat
    public let keyboardTop: CGFloat?
    public let barTop: CGFloat?

    /// Margem mínima de folga entre a base do campo e o topo da oclusão inferior (16 pt).
    public static let minimumFieldMargin: CGFloat = FrilaLPEGeometry.space16

    public init(
        viewportTop: CGFloat = 0,
        headerBottom: CGFloat = 0,
        viewportBottom: CGFloat,
        keyboardTop: CGFloat? = nil,
        barTop: CGFloat? = nil
    ) {
        self.viewportTop = viewportTop
        self.headerBottom = headerBottom
        self.viewportBottom = viewportBottom
        self.keyboardTop = keyboardTop
        self.barTop = barTop
    }

    /// Limite superior útil T = max(topos do viewport, base do cabeçalho fixo).
    public var topBoundary: CGFloat {
        max(viewportTop, headerBottom)
    }

    /// Limite inferior útil B = min(base do viewport, topo do teclado, topo da barra).
    public var bottomBoundary: CGFloat {
        var b = viewportBottom
        if let kt = keyboardTop {
            b = min(b, kt)
        }
        if let bt = barTop {
            b = min(b, bt)
        }
        return b
    }

    /// Limite inferior com folga mínima de 16 pt para o campo.
    public var bottomBoundaryWithMargin: CGFloat {
        bottomBoundary - Self.minimumFieldMargin
    }

    /// Altura útil livre da janela.
    public var usefulHeight: CGFloat {
        max(0, bottomBoundary - topBoundary)
    }

    /// Indica se o campo está inteiramente visível na janela útil respeitando a margem de 16 pt.
    public func isFieldWithinUsefulWindow(_ field: CGRect) -> Bool {
        field.maxY <= bottomBoundaryWithMargin && field.minY >= topBoundary
    }

    /// Calcula o deslocamento de rolagem necessário (em pt) para trazer o campo à janela útil.
    /// Retorna nil se o campo já estiver dentro da janela útil.
    public func scrollCorrection(for field: CGRect) -> CGFloat? {
        if field.maxY > bottomBoundaryWithMargin {
            // Precisa rolar para cima (delta positivo)
            return field.maxY - bottomBoundaryWithMargin
        } else if field.minY < topBoundary {
            // Precisa rolar para baixo (delta negativo)
            return field.minY - topBoundary
        }
        return nil
    }

    /// Avalia a geometria de um campo em relação à janela útil visível, retornando a correção detalhada (R2 / B1).
    func evaluateReveal(
        fieldID: String,
        fieldFrame: CGRect,
        isDragging: Bool = false
    ) -> FrilaLPEFieldRevealCorrection {
        guard !fieldID.isEmpty, fieldFrame != .zero, !isDragging else {
            return .none
        }

        let topBound = topBoundary
        let useful = usefulHeight

        // Campo maior que a janela útil: mantém o topo/caret alcançável sem loop
        if fieldFrame.height > useful && useful > 0 {
            let delta = fieldFrame.minY - topBound
            if abs(delta) < 1.0 {
                return .none
            }
            return FrilaLPEFieldRevealCorrection(
                direction: .toTop(targetID: fieldID, delta: delta, boundary: topBound),
                requiredScrollDelta: delta,
                targetID: fieldID,
                targetAnchor: .top
            )
        }

        // Campo já visível na janela útil respeitando a margem de 16 pt
        if isFieldWithinUsefulWindow(fieldFrame) {
            return .none
        }

        guard let delta = scrollCorrection(for: fieldFrame) else {
            return .none
        }

        // Delta com magnitude inferior a 1 pt não gera correção
        if abs(delta) < 1.0 {
            return .none
        }

        if delta > 0 {
            // Oclusão na base: rola trazendo a base do campo + margem de 16 pt
            return FrilaLPEFieldRevealCorrection(
                direction: .toBottom(targetID: fieldID + "_bottom_margin", delta: delta, boundary: bottomBoundaryWithMargin),
                requiredScrollDelta: delta,
                targetID: fieldID + "_bottom_margin",
                targetAnchor: .bottom
            )
        } else {
            // Oclusão no topo: rola até o topo da janela útil
            return FrilaLPEFieldRevealCorrection(
                direction: .toTop(targetID: fieldID, delta: delta, boundary: topBound),
                requiredScrollDelta: delta,
                targetID: fieldID,
                targetAnchor: .top
            )
        }
    }
}

@Observable
@MainActor
public final class FrilaLPEKeyboardObserver {
    public private(set) var isKeyboardVisible: Bool = false
    public private(set) var keyboardTop: CGFloat = .infinity

    #if canImport(UIKit) && os(iOS)
    public private(set) weak var attachedWindow: UIWindow?
    public private(set) weak var scopeView: UIView?
    private var lastRawKeyboardEndFrame: CGRect? = nil

    func attachScope(view: UIView?, window: UIWindow?) {
        self.scopeView = view
        self.attachedWindow = window
        if let raw = lastRawKeyboardEndFrame, let win = window ?? view?.window, isKeyboardVisible {
            updateKeyboardGeometry(endFrame: raw, window: win)
        }
    }

    func detachScope() {
        self.scopeView = nil
        self.attachedWindow = nil
    }
    #endif

    #if canImport(AppKit) && os(macOS)
    public private(set) weak var attachedNSWindow: NSWindow?
    public private(set) weak var scopeNSView: NSView?

    func attachScopeNS(view: NSView?, window: NSWindow?) {
        self.scopeNSView = view
        self.attachedNSWindow = window
    }

    func detachScopeNS() {
        self.scopeNSView = nil
        self.attachedNSWindow = nil
    }
    #endif

    weak var coordinator: FrilaLPEOutsideTapCoordinator?

    public init() {
        #if canImport(UIKit) && os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        #endif
    }

    #if canImport(UIKit) && os(iOS)
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        // R7: Notificação só atualiza a geometria quando houver campo/responder registrado no escopo dono
        if let coord = coordinator {
            guard coord.activeKeyboardFieldID != nil else { return }
        }

        guard let userInfo = notification.userInfo,
              let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = attachedWindow ?? scopeView?.window else { return }

        self.lastRawKeyboardEndFrame = endFrame
        updateKeyboardGeometry(endFrame: endFrame, window: window)
    }

    private func updateKeyboardGeometry(endFrame: CGRect, window: UIWindow) {
        let screenBounds = window.bounds
        let convertedFrame = window.convert(endFrame, from: nil)
        let intersects = convertedFrame.intersects(screenBounds)
        let isVisible = intersects && convertedFrame.minY < screenBounds.maxY

        let scopeTop: CGFloat
        if let scope = scopeView {
            let inScope = scope.convert(endFrame, from: nil)
            scopeTop = inScope.minY
        } else if let coord = coordinator, coord.scopeFrame != .zero {
            scopeTop = convertedFrame.minY - coord.scopeFrame.minY
        } else {
            scopeTop = convertedFrame.minY
        }

        withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.25), reduzir: UIAccessibility.isReduceMotionEnabled)) {
            self.isKeyboardVisible = isVisible
            self.keyboardTop = isVisible ? scopeTop : .infinity
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        self.lastRawKeyboardEndFrame = nil
        withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.25), reduzir: UIAccessibility.isReduceMotionEnabled)) {
            self.isKeyboardVisible = false
            self.keyboardTop = .infinity
        }
    }
    #endif

    public func setKeyboardForTesting(isVisible: Bool, top: CGFloat = .infinity) {
        self.isKeyboardVisible = isVisible
        self.keyboardTop = top
    }

    public func visibleWindow(
        viewportTop: CGFloat = 0,
        headerBottom: CGFloat = 0,
        viewportBottom: CGFloat,
        barTop: CGFloat? = nil
    ) -> FrilaLPEVisibleWindow {
        FrilaLPEVisibleWindow(
            viewportTop: viewportTop,
            headerBottom: headerBottom,
            viewportBottom: viewportBottom,
            keyboardTop: isKeyboardVisible ? keyboardTop : nil,
            barTop: barTop
        )
    }

    @MainActor
    public func dismissKeyboard() {
        if let coord = coordinator {
            coord.dismissActiveKeyboard()
        } else {
            #if canImport(UIKit) && os(iOS)
            let target = scopeView?.superview ?? scopeView
            _ = target?.endEditing(true)
            #elseif canImport(AppKit) && os(macOS)
            if let scopeView = scopeNSView, let window = attachedNSWindow ?? scopeView.window {
                let scopeTarget = scopeView.superview ?? scopeView
                if let firstResponder = window.firstResponder as? NSView,
                   firstResponder.isDescendant(of: scopeTarget) {
                    window.makeFirstResponder(nil)
                } else if let fieldEditor = window.firstResponder as? NSText,
                          let delegate = fieldEditor.delegate as? NSView,
                          delegate.isDescendant(of: scopeTarget) {
                    window.makeFirstResponder(nil)
                }
            }
            #endif
        }
    }

    @available(*, deprecated, message: "Use local scope dismissKeyboard() instead")
    public static func hideKeyboard() {
        #if canImport(UIKit) && os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #elseif canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }
}

// MARK: - Ambiente de Visibilidade do Teclado

private struct FrilaLPEIsKeyboardVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    /// Indica se o teclado virtual está ativo e visível na tela atual.
    var frilaLPEIsKeyboardVisible: Bool {
        get { self[FrilaLPEIsKeyboardVisibleKey.self] }
        set { self[FrilaLPEIsKeyboardVisibleKey.self] = newValue }
    }
}

struct FrilaLPEKeyboardDismissScopeModifier: ViewModifier {
    @State private var keyboardObserver: FrilaLPEKeyboardObserver

    @MainActor
    init(observer: FrilaLPEKeyboardObserver? = nil) {
        self._keyboardObserver = State(initialValue: observer ?? FrilaLPEKeyboardObserver())
    }

    func body(content: Content) -> some View {
        content
            .modifier(FrilaLPEKeyboardScopeInnerModifier(keyboardObserver: keyboardObserver))
            .frilaLPEOutsideTapScope()
    }
}

private struct FrilaLPEKeyboardScopeInnerModifier: ViewModifier {
    let keyboardObserver: FrilaLPEKeyboardObserver
    @Environment(\.frilaLPEOutsideTapCoordinator) private var coordinator

    func body(content: Content) -> some View {
        content
            .environment(\.frilaLPEIsKeyboardVisible, keyboardObserver.isKeyboardVisible)
            .onAppear {
                coordinator?.setKeyboardObserver(keyboardObserver)
                coordinator?.setKeyboardVisible(keyboardObserver.isKeyboardVisible)
            }
            .onChange(of: keyboardObserver.isKeyboardVisible) { _, isVisible in
                coordinator?.setKeyboardVisible(isVisible)
                if !isVisible {
                    coordinator?.clearActiveKeyboard()
                }
            }
    }
}

struct FrilaLPECollapseOnKeyboardModifier: ViewModifier {
    @Environment(\.frilaLPEIsKeyboardVisible) private var isKeyboardVisible

    init() {}

    @ViewBuilder
    func body(content: Content) -> some View {
        if !isKeyboardVisible {
            content
        }
    }
}

struct FrilaLPEFormFieldRegistrationModifier: ViewModifier {
    let id: String
    let isFocused: Bool
    let onDismiss: (@MainActor @Sendable () -> Void)?

    @Environment(\.frilaLPEOutsideTapCoordinator) private var coordinator
    @State private var localFrame: CGRect = .zero

    init(id: String, isFocused: Bool, onDismiss: (@MainActor @Sendable () -> Void)? = nil) {
        self.id = id
        self.isFocused = isFocused
        self.onDismiss = onDismiss
    }

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
                .id(id)
                .background(alignment: .bottom) {
                    Color.clear
                        .frame(height: 1)
                        .offset(y: coordinator?.bottomScrollMargin(for: id) ?? FrilaLPEGeometry.space16)
                        .id(id + "_bottom_margin")
                        .accessibilityHidden(true)
                }
                .background(alignment: .top) {
                    Color.clear
                        .frame(height: 1)
                        .offset(y: -(coordinator?.topScrollMargin(for: id) ?? 0))
                        .id(id + "_top_margin")
                        .accessibilityHidden(true)
                }
                .background(
                    GeometryReader { proxy in
                        if let coord = coordinator {
                            Color.clear
                                .preference(
                                    key: FrilaLPEFormFieldFramePreferenceKey.self,
                                    value: [
                                        FrilaLPEFormFieldData(
                                            id: id,
                                            frame: proxy.frame(in: .named(coord.coordinateSpaceName)),
                                            isFocused: isFocused
                                        )
                                    ]
                                )
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .id(id + "_container")
        .onPreferenceChange(FrilaLPEFormFieldFramePreferenceKey.self) { fields in
            guard let coord = coordinator else { return }
            if let activeField = fields.first(where: { $0.id == id }) {
                localFrame = activeField.frame
                if activeField.isFocused {
                    coord.updateActiveKeyboardFrame(fieldID: id, frame: activeField.frame)
                }
            }
        }
        .onAppear {
            if isFocused, let coord = coordinator {
                let customDismiss = onDismiss
                coord.setActiveKeyboard(fieldID: id, fieldFrame: localFrame) {
                    customDismiss?()
                    coord.dismissScopeFocus()
                }
            }
        }
        .onChange(of: isFocused) { _, nowFocused in
            guard let coord = coordinator else { return }
            if nowFocused {
                let customDismiss = onDismiss
                coord.setActiveKeyboard(fieldID: id, fieldFrame: localFrame) {
                    customDismiss?()
                    coord.dismissScopeFocus()
                }
            } else {
                coord.clearActiveKeyboard(fieldID: id)
            }
        }
        .onDisappear {
            coordinator?.clearActiveKeyboard(fieldID: id)
        }
    }
}

public struct FrilaLPEFormFieldData: Equatable, Sendable {
    public let id: String
    public let frame: CGRect
    public let isFocused: Bool

    public init(id: String, frame: CGRect, isFocused: Bool) {
        self.id = id
        self.frame = frame
        self.isFocused = isFocused
    }
}

public struct FrilaLPEFormFieldFramePreferenceKey: PreferenceKey {
    public static let defaultValue: [FrilaLPEFormFieldData] = []
    public static func reduce(value: inout [FrilaLPEFormFieldData], nextValue: () -> [FrilaLPEFormFieldData]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Correção Estruturada e Política de Revelação (R2, B1, A5)

struct FrilaLPEFieldRevealCorrection: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case none
        case toBottom(targetID: String, delta: CGFloat, boundary: CGFloat)
        case toTop(targetID: String, delta: CGFloat, boundary: CGFloat)
    }

    static let none = FrilaLPEFieldRevealCorrection(
        direction: .none,
        requiredScrollDelta: nil,
        targetID: nil,
        targetAnchor: nil
    )

    let direction: Direction
    let requiredScrollDelta: CGFloat?
    let targetID: String?
    let targetAnchor: UnitPoint?
}

struct FrilaLPERevealGeometrySnapshot: Equatable, Sendable {
    let fieldID: String
    let fieldFrame: CGRect
    let visibleWindow: FrilaLPEVisibleWindow
}

struct FrilaLPEFieldRevealPolicy: Sendable {
    enum Action: Equatable, Sendable {
        case noCorrection
        case scrollTo(targetID: String, anchor: UnitPoint)
    }

    static func evaluate(
        fieldID: String,
        fieldFrame: CGRect,
        visibleWindow: FrilaLPEVisibleWindow,
        isDragging: Bool = false
    ) -> Action {
        let correction = visibleWindow.evaluateReveal(
            fieldID: fieldID,
            fieldFrame: fieldFrame,
            isDragging: isDragging
        )
        switch correction.direction {
        case .none:
            return .noCorrection
        case .toBottom(let targetID, _, _):
            return .scrollTo(targetID: targetID, anchor: .bottom)
        case .toTop(let targetID, _, _):
            return .scrollTo(targetID: targetID, anchor: .top)
        }
    }
}

public struct FrilaLPEFieldRevealModifier: ViewModifier {
    let scrollProxy: ScrollViewProxy
    let keyboardObserver: FrilaLPEKeyboardObserver
    let headerBottom: CGFloat?
    let viewportBottom: CGFloat?
    let barTop: CGFloat?
    let isEditingField: Binding<Bool>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.frilaLPEOutsideTapCoordinator) private var coordinator

    @State private var activeFocusedField: FrilaLPEFormFieldData? = nil
    @State private var isDragging: Bool = false
    @State private var measuredViewportFrame: CGRect = .zero
    @State private var measuredHeaderBottom: CGFloat = 0
    @State private var measuredBarTop: CGFloat? = nil
    @State private var geometryRevision: Int = 0
    @State private var lastRevealedGeometry: FrilaLPERevealGeometrySnapshot? = nil

    public init(
        scrollProxy: ScrollViewProxy,
        keyboardObserver: FrilaLPEKeyboardObserver,
        headerBottom: CGFloat? = nil,
        viewportBottom: CGFloat? = nil,
        barTop: CGFloat? = nil,
        isEditingField: Binding<Bool>? = nil
    ) {
        self.scrollProxy = scrollProxy
        self.keyboardObserver = keyboardObserver
        self.headerBottom = headerBottom
        self.viewportBottom = viewportBottom
        self.barTop = barTop
        self.isEditingField = isEditingField
    }

    public func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                if let name = coordinator?.coordinateSpaceName {
                    return proxy.frame(in: .named(name))
                } else {
                    return proxy.frame(in: .local)
                }
            } action: { newFrame in
                if abs(measuredViewportFrame.origin.y - newFrame.origin.y) >= 0.5 ||
                   abs(measuredViewportFrame.height - newFrame.height) >= 0.5 ||
                   abs(measuredViewportFrame.origin.x - newFrame.origin.x) >= 0.5 ||
                   abs(measuredViewportFrame.width - newFrame.width) >= 0.5 {
                    measuredViewportFrame = newFrame
                    geometryRevision += 1
                    if let focused = activeFocusedField {
                        evaluateReveal(for: focused)
                    }
                }
            }
            .onPreferenceChange(FrilaLPERevealHeaderBottomPreferenceKey.self) { newHeaderBottom in
                if abs(measuredHeaderBottom - newHeaderBottom) >= 0.5 {
                    measuredHeaderBottom = newHeaderBottom
                    geometryRevision += 1
                    if let focused = activeFocusedField {
                        evaluateReveal(for: focused)
                    }
                }
            }
            .onPreferenceChange(FrilaLPERevealBarTopPreferenceKey.self) { newBarTop in
                if measuredBarTop != newBarTop {
                    measuredBarTop = newBarTop
                    geometryRevision += 1
                    if let focused = activeFocusedField {
                        evaluateReveal(for: focused)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { _ in
                        if !isDragging { isDragging = true }
                    }
                    .onEnded { _ in
                        isDragging = false
                        if let focused = activeFocusedField {
                            evaluateReveal(for: focused)
                        }
                    }
            )
            .onPreferenceChange(FrilaLPEFormFieldFramePreferenceKey.self) { fields in
                let focused = fields.first(where: { $0.isFocused })
                activeFocusedField = focused
                isEditingField?.wrappedValue = (focused != nil)
                if let focused = focused {
                    evaluateReveal(for: focused)
                } else {
                    lastRevealedGeometry = nil
                }
            }
            .onChange(of: keyboardObserver.isKeyboardVisible) { _, isVisible in
                if isVisible, let focused = activeFocusedField {
                    evaluateReveal(for: focused)
                } else if !isVisible {
                    lastRevealedGeometry = nil
                }
            }
            .onChange(of: keyboardObserver.keyboardTop) { _, _ in
                if keyboardObserver.isKeyboardVisible, let focused = activeFocusedField {
                    evaluateReveal(for: focused)
                }
            }
    }

    private func evaluateReveal(for fieldData: FrilaLPEFormFieldData) {
        guard !isDragging else { return }
        guard measuredViewportFrame.height > 0 else { return }

        let vTop = measuredViewportFrame.minY
        let vBottom = viewportBottom ?? measuredViewportFrame.maxY
        guard vBottom > vTop else { return }

        let effectiveHeaderBottom = max(headerBottom ?? 0, measuredHeaderBottom, vTop)
        let effectiveBarTop = barTop ?? measuredBarTop

        let visibleWindow = keyboardObserver.visibleWindow(
            viewportTop: vTop,
            headerBottom: effectiveHeaderBottom,
            viewportBottom: vBottom,
            barTop: effectiveBarTop
        )

        coordinator?.updateVisibleWindow(visibleWindow)

        let correction = visibleWindow.evaluateReveal(
            fieldID: fieldData.id,
            fieldFrame: fieldData.frame,
            isDragging: isDragging
        )

        let snapshot = FrilaLPERevealGeometrySnapshot(
            fieldID: fieldData.id,
            fieldFrame: fieldData.frame,
            visibleWindow: visibleWindow
        )

        switch correction.direction {
        case .none:
            break
        case .toBottom(let targetID, _, _):
            if lastRevealedGeometry == snapshot { return }
            lastRevealedGeometry = snapshot
            if reduceMotion {
                scrollProxy.scrollTo(targetID, anchor: .bottom)
            } else {
                withAnimation(FrilaMovimento.animacao(FrilaLPEMotion.disclosureExpand, reduzir: reduceMotion)) {
                    scrollProxy.scrollTo(targetID, anchor: .bottom)
                }
            }
        case .toTop(let targetID, _, _):
            if lastRevealedGeometry == snapshot { return }
            lastRevealedGeometry = snapshot
            if reduceMotion {
                scrollProxy.scrollTo(targetID, anchor: .top)
            } else {
                withAnimation(FrilaMovimento.animacao(FrilaLPEMotion.disclosureExpand, reduzir: reduceMotion)) {
                    scrollProxy.scrollTo(targetID, anchor: .top)
                }
            }
        }
    }
}

// MARK: - Medição Dinâmica de Cabeçalho e Barra

struct FrilaLPERevealHeaderBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct FrilaLPERevealBarTopPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() {
            if let current = value {
                value = min(current, next)
            } else {
                value = next
            }
        }
    }
}

private struct FrilaLPERevealHeaderReader: View {
    @Environment(\.frilaLPEOutsideTapCoordinator) private var coordinator
    let proxy: GeometryProxy

    var body: some View {
        Color.clear
            .preference(
                key: FrilaLPERevealHeaderBottomPreferenceKey.self,
                value: coordinator.map { proxy.frame(in: .named($0.coordinateSpaceName)).maxY } ?? proxy.frame(in: .local).maxY
            )
    }
}

private struct FrilaLPERevealBarReader: View {
    @Environment(\.frilaLPEOutsideTapCoordinator) private var coordinator
    let proxy: GeometryProxy

    var body: some View {
        Color.clear
            .preference(
                key: FrilaLPERevealBarTopPreferenceKey.self,
                value: coordinator.map { proxy.frame(in: .named($0.coordinateSpaceName)).minY } ?? proxy.frame(in: .local).minY
            )
    }
}

// MARK: - Extensões de View

public extension View {
    /// Define um escopo de fechamento de teclado por toque fora na raiz da tela/sheet (M21).
    func frilaLPEKeyboardDismissScope(observer: FrilaLPEKeyboardObserver? = nil) -> some View {
        modifier(FrilaLPEKeyboardDismissScopeModifier(observer: observer))
    }

    /// Registra um campo de formulário com seu ID e estado de foco para proteção e dismiss de teclado.
    func frilaLPEFormField(
        id: String,
        isFocused: Bool,
        onDismiss: (@MainActor @Sendable () -> Void)? = nil
    ) -> some View {
        modifier(FrilaLPEFormFieldRegistrationModifier(id: id, isFocused: isFocused, onDismiss: onDismiss))
    }

    /// Recolhe o conteúdo inteiramente quando o teclado virtual estiver visível (M21b).
    func frilaLPECollapseOnKeyboard() -> some View {
        modifier(FrilaLPECollapseOnKeyboardModifier())
    }

    /// Mede e reporta a base do cabeçalho fixo no espaço de coordenadas do escopo para cálculo de janela útil (R2).
    func frilaLPERevealHeader() -> some View {
        background(
            GeometryReader { proxy in
                FrilaLPERevealHeaderReader(proxy: proxy)
            }
        )
    }

    /// Mede e reporta o topo da barra de ação inferior no espaço de coordenadas do escopo para cálculo de janela útil (R2).
    func frilaLPERevealBottomBar() -> some View {
        background(
            GeometryReader { proxy in
                FrilaLPERevealBarReader(proxy: proxy)
            }
        )
    }

    /// Revela o campo focado trazendo-o para a janela útil respeitando margens e oclusões (R2).
    func frilaLPEFieldReveal(
        scrollProxy: ScrollViewProxy,
        keyboardObserver: FrilaLPEKeyboardObserver,
        headerBottom: CGFloat? = nil,
        viewportBottom: CGFloat? = nil,
        barTop: CGFloat? = nil,
        isEditingField: Binding<Bool>? = nil
    ) -> some View {
        modifier(
            FrilaLPEFieldRevealModifier(
                scrollProxy: scrollProxy,
                keyboardObserver: keyboardObserver,
                headerBottom: headerBottom,
                viewportBottom: viewportBottom,
                barTop: barTop,
                isEditingField: isEditingField
            )
        )
    }
}
