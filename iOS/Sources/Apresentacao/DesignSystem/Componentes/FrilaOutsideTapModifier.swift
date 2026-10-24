import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum FrilaTouchDisposition: Equatable, Sendable {
    case ignore
    case protectedInside
    case outsideCandidate
    case consumingExitRegion
}

enum FrilaGestureDisposition: Equatable, Sendable {
    case recognized
    case failed
}

enum FrilaOutsideTapResolution: Equatable, Sendable {
    case none
    case dismissedKeyboard
    case dismissedInlineAnchors(count: Int)
}

// MARK: - Registros Internos

struct FrilaAnchorRecord: Sendable {
    let id: String
    var frame: CGRect
    var collapsingFrame: CGRect?
    var isOpen: Bool
    var isCollapsing: Bool
    var activeCycleID: UUID?
    var onClose: @MainActor @Sendable () -> Void
}

struct FrilaActiveKeyboardRecord: Sendable {
    var fieldID: String
    var fieldFrame: CGRect
    var onDismiss: @MainActor @Sendable () -> Void
}

@Observable
@MainActor
final class FrilaOutsideTapCoordinator {
    let coordinateSpaceName: String

    private(set) var scopeFrame: CGRect = .zero
    private var anchors: [String: FrilaAnchorRecord] = [:]
    private var activeKeyboard: FrilaActiveKeyboardRecord?
    private(set) var isKeyboardVisible: Bool = false

    #if canImport(UIKit) && os(iOS)
    private(set) weak var scopeView: UIView?
    private(set) weak var scopeWindow: UIWindow?

    func attachScopeView(_ view: UIView, window: UIWindow) {
        self.scopeView = view
        self.scopeWindow = window
        self.keyboardObserver?.attachScope(view: view, window: window)
        if !view.bounds.isEmpty {
            self.scopeFrame = CGRect(origin: .zero, size: view.bounds.size)
        }
    }

    func detachScopeView() {
        self.scopeView = nil
        self.scopeWindow = nil
        self.keyboardObserver?.detachScope()
    }
    #endif

    #if canImport(AppKit) && os(macOS)
    private(set) weak var scopeNSView: NSView?
    private(set) weak var scopeNSWindow: NSWindow?

    func attachScopeNSView(_ view: NSView, window: NSWindow) {
        self.scopeNSView = view
        self.scopeNSWindow = window
        self.keyboardObserver?.attachScopeNS(view: view, window: window)
        if !view.bounds.isEmpty {
            self.scopeFrame = CGRect(origin: .zero, size: view.bounds.size)
        }
    }

    func detachScopeNSView() {
        self.scopeNSView = nil
        self.scopeNSWindow = nil
        self.keyboardObserver?.detachScopeNS()
    }
    #endif

    weak var keyboardObserver: FrilaKeyboardObserver?

    func setKeyboardObserver(_ observer: FrilaKeyboardObserver) {
        self.keyboardObserver = observer
        observer.coordinator = self
        #if canImport(UIKit) && os(iOS)
        if let view = scopeView, let win = scopeWindow {
            observer.attachScope(view: view, window: win)
        }
        #elseif canImport(AppKit) && os(macOS)
        if let view = scopeNSView, let win = scopeNSWindow {
            observer.attachScopeNS(view: view, window: win)
        }
        #endif
    }

    init(scopeID: String = UUID().uuidString) {
        self.coordinateSpaceName = "FrilaOutsideTapScope_\(scopeID)"
    }


    /// Candidatos ativos incluem controles abertos, em recolhimento (R10) ou teclado focado neste escopo (R7).
    var hasActiveCandidates: Bool {
        let hasOpenOrCollapsingAnchor = anchors.values.contains { $0.isOpen || $0.isCollapsing }
        let hasKeyboard = (activeKeyboard != nil)
        return hasOpenOrCollapsingAnchor || hasKeyboard
    }

    func setKeyboardVisible(_ visible: Bool) {
        self.isKeyboardVisible = visible
        if !visible {
            self.activeKeyboard = nil
        }
    }

    var activeKeyboardFieldID: String? {
        activeKeyboard?.fieldID
    }

    var activeKeyboardFrame: CGRect? {
        activeKeyboard?.fieldFrame
    }

    public private(set) var currentVisibleWindow: FrilaVisibleWindow? = nil

    func updateVisibleWindow(_ window: FrilaVisibleWindow) {
        self.currentVisibleWindow = window
    }

    func bottomScrollMargin(for fieldID: String) -> CGFloat {
        guard let window = currentVisibleWindow else { return FrilaGeometry.space16 }
        let bottomOcclusion = max(0, window.viewportBottom - window.bottomBoundary)
        return bottomOcclusion + FrilaGeometry.space16
    }

    func topScrollMargin(for fieldID: String) -> CGFloat {
        guard let window = currentVisibleWindow else { return 0 }
        let topOcclusion = max(0, window.topBoundary - window.viewportTop)
        return topOcclusion
    }

    func setScopeFrame(_ frame: CGRect) {
        // N2: Estabelece os bounds locais como autoridade para pontos convertidos da janela.
        // O referencial de point em evaluateTouch é sempre o espaço de coordenadas local do escopo (origem .zero).
        self.scopeFrame = CGRect(origin: .zero, size: frame.size)
    }

    func anchor(id: String) -> FrilaAnchorRecord? {
        anchors[id]
    }

    /// Inicia o ciclo de recolhimento de uma âncora com identidade única,
    /// preservando o último frame aberto antes de escrever o estado fechado (R10).
    @discardableResult
    func beginCollapse(id: String) -> UUID? {
        guard var record = anchors[id] else { return nil }
        let cycleID = UUID()
        record.collapsingFrame = record.frame
        record.isOpen = false
        record.isCollapsing = true
        record.activeCycleID = cycleID
        anchors[id] = record
        return cycleID
    }

    /// Encerra o ciclo de recolhimento por completion da animação dona.
    /// Se o ciclo foi invalidado por reabertura ou ciclo posterior, a chamada é descartada (R10).
    func endCollapse(id: String, cycleID: UUID? = nil) {
        guard var record = anchors[id] else { return }
        if let cycleID = cycleID {
            guard record.activeCycleID == cycleID else { return }
        }
        record.isCollapsing = false
        record.collapsingFrame = nil
        record.activeCycleID = nil
        anchors[id] = record
    }

    func registerAnchor(
        id: String,
        frame: CGRect,
        isOpen: Bool,
        isCollapsing: Bool = false,
        onClose: @escaping @MainActor @Sendable () -> Void
    ) {
        anchors[id] = FrilaAnchorRecord(
            id: id,
            frame: frame,
            collapsingFrame: nil,
            isOpen: isOpen,
            isCollapsing: isCollapsing,
            activeCycleID: nil,
            onClose: onClose
        )
    }

    func updateAnchorOpen(id: String, isOpen: Bool, isCollapsing: Bool = false) {
        guard var record = anchors[id] else { return }
        if isOpen {
            // Reabertura invalida ciclo de recolhimento anterior (R10)
            record.activeCycleID = nil
            record.isCollapsing = false
            record.collapsingFrame = nil
            record.isOpen = true
        } else {
            record.isOpen = false
            record.isCollapsing = isCollapsing
            if !isCollapsing {
                record.collapsingFrame = nil
                record.activeCycleID = nil
            }
        }
        anchors[id] = record
    }

    /// Trata a transição de isOpen de um controle (R10 / H1).
    /// Se o controle fechou sem ciclo explícito prévio em andamento, garante que não fica
    /// nenhuma região presa em `isCollapsing` consumindo toques de alvos legítimos.
    func handleAnchorOpenChanged(id: String, wasOpen: Bool, nowOpen: Bool) {
        if wasOpen && !nowOpen {
            let record = anchor(id: id)
            if !(record?.isCollapsing ?? false) {
                updateAnchorOpen(id: id, isOpen: false, isCollapsing: false)
            }
        } else if nowOpen {
            updateAnchorOpen(id: id, isOpen: true)
        }
    }

    func unregisterAnchor(id: String) {
        anchors.removeValue(forKey: id)
    }

    func setActiveKeyboard(
        fieldID: String = "default_field",
        fieldFrame: CGRect,
        onDismiss: @escaping @MainActor @Sendable () -> Void
    ) {
        self.activeKeyboard = FrilaActiveKeyboardRecord(
            fieldID: fieldID,
            fieldFrame: fieldFrame,
            onDismiss: onDismiss
        )
    }

    func updateActiveKeyboardFrame(fieldID: String, frame: CGRect) {
        guard activeKeyboard?.fieldID == fieldID else { return }
        self.activeKeyboard?.fieldFrame = frame
    }

    func clearActiveKeyboard(fieldID: String? = nil) {
        if let fieldID = fieldID {
            guard activeKeyboard?.fieldID == fieldID else { return }
            self.activeKeyboard = nil
        } else {
            self.activeKeyboard = nil
        }
    }

    @MainActor
    func dismissActiveKeyboard() {
        if let kb = activeKeyboard {
            let dismissAction = kb.onDismiss
            self.activeKeyboard = nil
            self.isKeyboardVisible = false
            dismissAction()
        } else {
            dismissScopeFocus()
        }
    }

    @MainActor
    func dismissScopeFocus() {
        #if canImport(UIKit) && os(iOS)
        let target = scopeView?.superview ?? scopeView
        _ = target?.endEditing(true)
        #elseif canImport(AppKit) && os(macOS)
        if let scopeView = scopeNSView, let window = scopeNSWindow ?? scopeView.window {
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

    func evaluateTouch(at point: CGPoint) -> FrilaTouchDisposition {
        let hasOpenAnchors = anchors.values.contains { $0.isOpen }
        let hasCollapsingAnchors = anchors.values.contains { $0.isCollapsing }
        let hasKeyboard = (activeKeyboard != nil)

        guard hasOpenAnchors || hasCollapsingAnchors || hasKeyboard else {
            return .ignore
        }

        // N2: Bounds locais do escopo são a autoridade para pontos convertidos da janela
        let effectiveBounds: CGRect
        #if canImport(UIKit) && os(iOS)
        if let scope = scopeView, !scope.bounds.isEmpty {
            effectiveBounds = scope.bounds
        } else if !scopeFrame.isEmpty {
            effectiveBounds = CGRect(origin: .zero, size: scopeFrame.size)
        } else {
            effectiveBounds = .zero
        }
        #elseif canImport(AppKit) && os(macOS)
        if let scope = scopeNSView, !scope.bounds.isEmpty {
            effectiveBounds = scope.bounds
        } else if !scopeFrame.isEmpty {
            effectiveBounds = CGRect(origin: .zero, size: scopeFrame.size)
        } else {
            effectiveBounds = .zero
        }
        #else
        effectiveBounds = !scopeFrame.isEmpty ? CGRect(origin: .zero, size: scopeFrame.size) : .zero
        #endif

        if !effectiveBounds.isEmpty && !effectiveBounds.contains(point) {
            return .ignore
        }

        // Prioridade Q3 (R4): com teclado ativo, apenas o campo focado é protegido.
        // Qualquer outro toque no escopo (inclusive dentro de roleta aberta) é outsideCandidate
        // para fechar APENAS o teclado, consumindo o toque para que alvos abaixo não ajam.
        if hasKeyboard {
            if let kb = activeKeyboard, !kb.fieldFrame.isEmpty, kb.fieldFrame.contains(point) {
                return .protectedInside
            }
            return .outsideCandidate
        }

        // Sem teclado ativo: checar se está dentro de alguma âncora aberta.
        for record in anchors.values where record.isOpen {
            if !record.frame.isEmpty && record.frame.contains(point) {
                return .protectedInside
            }
        }

        // Checar se está dentro de alguma âncora em recolhimento/saída (R10).
        // Toque dentro do frame preservado em saída é consumido pela ponte (.consumingExitRegion),
        // não atravessa para alvos que surgiram ali e não dispara novo onClose.
        for record in anchors.values where record.isCollapsing {
            let frame = record.collapsingFrame ?? record.frame
            if !frame.isEmpty && frame.contains(point) {
                return .consumingExitRegion
            }
        }

        // Se há âncoras abertas, o toque fora é outsideCandidate para fechá-las.
        // Mas se apenas há âncoras em saída (isCollapsing) e nenhuma aberta, o toque fora
        // não tem candidatos a fechar: deixa o alvo agir (.ignore) em vez de engolir com .none (R10).
        if hasOpenAnchors {
            return .outsideCandidate
        } else {
            return .ignore
        }
    }

    func validateGesture(
        movement: CGFloat,
        duration: TimeInterval,
        touchCount: Int
    ) -> FrilaGestureDisposition {
        guard touchCount == 1 else { return .failed }
        guard movement <= FrilaGeometry.outsideTapMaxMovement else { return .failed }
        guard duration <= FrilaMotion.outsideTapMaxDuration else { return .failed }
        return .recognized
    }

    @discardableResult
    func performOutsideTap() -> FrilaOutsideTapResolution {
        // Decisão Q3: teclado ativo tem prioridade de fechamento (R7: apenas se registrado no escopo)
        if let kb = activeKeyboard {
            let dismissAction = kb.onDismiss
            self.activeKeyboard = nil
            self.isKeyboardVisible = false
            dismissAction()
            return .dismissedKeyboard
        }

        let openAnchors = anchors.values.filter { $0.isOpen }
        guard !openAnchors.isEmpty else { return .none }

        for anchor in openAnchors {
            anchor.onClose()
        }

        return .dismissedInlineAnchors(count: openAnchors.count)
    }

    func syncAnchors(_ dataList: [FrilaOutsideTapAnchorData]) {
        let activeIDs = Set(dataList.map(\.id))

        // Reconciliação (R1): remove âncoras ausentes da preferência, exceto em recolhimento
        for id in Array(anchors.keys) {
            if !activeIDs.contains(id) {
                if !(anchors[id]?.isCollapsing ?? false) {
                    anchors.removeValue(forKey: id)
                }
            }
        }

        for data in dataList {
            if var existing = anchors[data.id] {
                existing.frame = data.frame
                existing.isOpen = data.isOpen
                anchors[data.id] = existing
            }
        }
    }
}

// MARK: - PreferenceKeys e Dados

struct FrilaOutsideTapAnchorData: Equatable, Sendable {
    let id: String
    let frame: CGRect
    let isOpen: Bool
}

struct FrilaOutsideTapAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [FrilaOutsideTapAnchorData] = []
    static func reduce(value: inout [FrilaOutsideTapAnchorData], nextValue: () -> [FrilaOutsideTapAnchorData]) {
        value.append(contentsOf: nextValue())
    }
}

struct FrilaOutsideTapScopeFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Ambiente

private struct FrilaOutsideTapCoordinatorKey: EnvironmentKey {
    static let defaultValue: FrilaOutsideTapCoordinator? = nil
}

extension EnvironmentValues {
    var frilaOutsideTapCoordinator: FrilaOutsideTapCoordinator? {
        get { self[FrilaOutsideTapCoordinatorKey.self] }
        set { self[FrilaOutsideTapCoordinatorKey.self] = newValue }
    }
}

struct FrilaOutsideTapScopeModifier: ViewModifier {
    @State private var coordinator = FrilaOutsideTapCoordinator()

    init() {}

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: coordinator.coordinateSpaceName)
            .environment(\.frilaOutsideTapCoordinator, coordinator)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: FrilaOutsideTapScopeFramePreferenceKey.self, value: proxy.frame(in: .named(coordinator.coordinateSpaceName)))
                }
            )
            .background(FrilaOutsideTapBridgeView(coordinator: coordinator))
            .onPreferenceChange(FrilaOutsideTapScopeFramePreferenceKey.self) { frame in
                coordinator.setScopeFrame(frame)
            }
            .onPreferenceChange(FrilaOutsideTapAnchorPreferenceKey.self) { anchors in
                coordinator.syncAnchors(anchors)
            }
    }
}

@MainActor
private final class FrilaCloseCallbackBox {
    var onClose: @MainActor @Sendable () -> Void
    init(onClose: @escaping @MainActor @Sendable () -> Void) {
        self.onClose = onClose
    }
}

@MainActor
struct FrilaOutsideTapModifier: ViewModifier {
    @Environment(\.frilaOutsideTapCoordinator) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var instanceID = UUID().uuidString
    private let explicitID: String?
    let isOpen: Bool
    let onClose: @MainActor @Sendable () -> Void
    @State private var callbackBox: FrilaCloseCallbackBox

    init(
        id: String? = nil,
        isOpen: Bool,
        onClose: @escaping @MainActor @Sendable () -> Void
    ) {
        self.explicitID = id
        self.isOpen = isOpen
        self.onClose = onClose
        self._callbackBox = State(initialValue: FrilaCloseCallbackBox(onClose: onClose))
    }

    private var effectiveID: String {
        explicitID ?? instanceID
    }

    func body(content: Content) -> some View {
        callbackBox.onClose = onClose
        return content
            .background(
                GeometryReader { proxy in
                    if let coordinator = coordinator {
                        Color.clear
                            .preference(
                                key: FrilaOutsideTapAnchorPreferenceKey.self,
                                value: [
                                    FrilaOutsideTapAnchorData(
                                        id: effectiveID,
                                        frame: proxy.frame(in: .named(coordinator.coordinateSpaceName)),
                                        isOpen: isOpen
                                    )
                                ]
                            )
                    } else {
                        Color.clear
                    }
                }
            )
            .onAppear {
                let box = callbackBox
                coordinator?.registerAnchor(
                    id: effectiveID,
                    frame: .zero,
                    isOpen: isOpen,
                    isCollapsing: false,
                    onClose: {
                        box.onClose()
                    }
                )
            }
            .onDisappear {
                coordinator?.unregisterAnchor(id: effectiveID)
            }
            .onChange(of: isOpen) { wasOpen, nowOpen in
                coordinator?.handleAnchorOpenChanged(id: effectiveID, wasOpen: wasOpen, nowOpen: nowOpen)
            }
    }
}

// MARK: - Extensões de View

public extension View {
    /// Define uma região de escopo de toque fora (M20 / M21).
    func frilaOutsideTapScope() -> some View {
        modifier(FrilaOutsideTapScopeModifier())
    }

    /// Registra um controle expansível inline como âncora de toque fora.
    func frilaOutsideTap(
        id: String? = nil,
        isOpen: Bool,
        onClose: @escaping @MainActor @Sendable () -> Void
    ) -> some View {
        modifier(
            FrilaOutsideTapModifier(
                id: id,
                isOpen: isOpen,
                onClose: onClose
            )
        )
    }
}

// MARK: - Pontes de Plataforma (UIKit & AppKit)

#if canImport(UIKit)
struct FrilaOutsideTapBridgeView: UIViewRepresentable {
    let coordinator: FrilaOutsideTapCoordinator

    func makeUIView(context: Context) -> FrilaBridgeUIView {
        let view = FrilaBridgeUIView(coordinator: coordinator)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: FrilaBridgeUIView, context: Context) {
        uiView.updateCoordinator(coordinator)
    }

    static func dismantleUIView(_ uiView: FrilaBridgeUIView, coordinator: ()) {
        uiView.cleanup()
    }
}

final class FrilaBridgeUIView: UIView {
    private(set) var coordinator: FrilaOutsideTapCoordinator
    private var gestureRecognizer: FrilaOutsideTapGestureRecognizer?
    private weak var attachedWindow: UIWindow?

    init(coordinator: FrilaOutsideTapCoordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateCoordinator(_ newCoordinator: FrilaOutsideTapCoordinator) {
        self.coordinator = newCoordinator
        gestureRecognizer?.updateCoordinator(newCoordinator)
    }

    func cleanup() {
        coordinator.detachScopeView()
        if let gr = gestureRecognizer {
            gr.delegate = nil
            attachedWindow?.removeGestureRecognizer(gr)
            self.gestureRecognizer = nil
            self.attachedWindow = nil
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil || newWindow != attachedWindow {
            cleanup()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window = self.window else { return }

        coordinator.attachScopeView(self, window: window)

        if gestureRecognizer == nil {
            let gr = FrilaOutsideTapGestureRecognizer(coordinator: coordinator, scopeView: self)
            window.addGestureRecognizer(gr)
            self.gestureRecognizer = gr
            self.attachedWindow = window
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

final class FrilaOutsideTapGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var coordinator: FrilaOutsideTapCoordinator
    private weak var scopeView: UIView?

    private var activeTouch: UITouch?
    private var activeTouchCount: Int = 0
    private var startPoint: CGPoint = .zero
    private var startTime: TimeInterval = 0
    private var timeoutTimer: Timer?
    private var acceptedDisposition: FrilaTouchDisposition = .ignore

    init(coordinator: FrilaOutsideTapCoordinator, scopeView: UIView) {
        self.coordinator = coordinator
        self.scopeView = scopeView
        super.init(target: nil, action: nil)

        self.delegate = self
        self.delaysTouchesBegan = true
        self.delaysTouchesEnded = true
        self.cancelsTouchesInView = true
    }

    func updateCoordinator(_ newCoordinator: FrilaOutsideTapCoordinator) {
        self.coordinator = newCoordinator
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        if preventedGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }


    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Não subordinar gestos de rolagem / arrasto contínuo (pan)
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        // Não subordinar outro recognizer de toque fora (evita ciclo de espera mútua - V3-G1 / W4-3)
        if otherGestureRecognizer is FrilaOutsideTapGestureRecognizer {
            return false
        }
        // Só subordina controles quando o escopo possui candidatos ativos para fechamento
        guard coordinator.hasActiveCandidates else {
            return false
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard coordinator.hasActiveCandidates else { return false }
        guard let scope = scopeView, let window = scope.window else { return false }

        // R8: Descarte de eventos de outro dono / outra janela
        if let touchWindow = touch.window, touchWindow !== window {
            return false
        }

        // Proteger toques na hierarquia do teclado do sistema (teclas e toolbar acessória nativa)
        if let touchView = touch.view {
            let className = String(describing: type(of: touchView))
            if className.contains("Keyboard") || className.contains("InputSet") {
                return false
            }
        }

        let pointInScope = scope.convert(touch.location(in: window), from: window)
        guard scope.bounds.contains(pointInScope) else { return false }

        let disposition = coordinator.evaluateTouch(at: pointInScope)
        guard disposition == .outsideCandidate || disposition == .consumingExitRegion else { return false }

        return true
    }

    private func scheduleTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: FrilaMotion.outsideTapMaxDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.state == .possible {
                self.state = .failed
            }
        }
    }

    private func cancelTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        activeTouchCount += touches.count
        if activeTouchCount > 1 || activeTouch != nil {
            cancelTimeoutTimer()
            state = .failed
            return
        }

        guard let touch = touches.first, let scope = scopeView, let window = scope.window else {
            state = .failed
            return
        }

        if let touchWindow = touch.window, touchWindow !== window {
            cancelTimeoutTimer()
            state = .failed
            return
        }

        activeTouch = touch
        startPoint = scope.convert(touch.location(in: window), from: window)
        startTime = event.timestamp

        // A2: Rastrear e guardar a disposição aceita no início da sequência
        let disposition = coordinator.evaluateTouch(at: startPoint)
        guard disposition == .outsideCandidate || disposition == .consumingExitRegion else {
            cancelTimeoutTimer()
            state = .failed
            return
        }
        self.acceptedDisposition = disposition

        state = .possible
        scheduleTimeoutTimer()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = activeTouch, touches.contains(touch), let scope = scopeView, let window = scope.window else {
            cancelTimeoutTimer()
            state = .failed
            return
        }

        let currentPoint = scope.convert(touch.location(in: window), from: window)
        let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
        if distance > FrilaGeometry.outsideTapMaxMovement {
            cancelTimeoutTimer()
            state = .failed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        cancelTimeoutTimer()
        guard let touch = activeTouch, touches.contains(touch), let scope = scopeView, let window = scope.window else {
            state = .failed
            return
        }

        let currentPoint = scope.convert(touch.location(in: window), from: window)
        let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
        let duration = event.timestamp - startTime

        let validation = coordinator.validateGesture(
            movement: distance,
            duration: duration,
            touchCount: 1
        )

        guard validation == .recognized else {
            state = .failed
            return
        }

        // A2: Validar consumo antes de transicionar state para .ended.
        // Se a região de saída ou o candidato ativo desaparecerem entre down e up,
        // o recognizer falha para que o UIKit entregue o toque ao controle subjacente sem engolir.
        let currentDisposition = coordinator.evaluateTouch(at: currentPoint)
        switch currentDisposition {
        case .outsideCandidate:
            state = .ended
            coordinator.performOutsideTap()
        case .consumingExitRegion:
            state = .ended
        case .ignore, .protectedInside:
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        cancelTimeoutTimer()
        state = .failed
    }

    override func reset() {
        super.reset()
        cancelTimeoutTimer()
        activeTouch = nil
        activeTouchCount = 0
        startPoint = .zero
        startTime = 0
        acceptedDisposition = .ignore
    }
}
#elseif canImport(AppKit)
struct FrilaOutsideTapBridgeView: NSViewRepresentable {
    let coordinator: FrilaOutsideTapCoordinator

    func makeNSView(context: Context) -> FrilaBridgeNSView {
        let view = FrilaBridgeNSView(coordinator: coordinator)
        return view
    }

    func updateNSView(_ nsView: FrilaBridgeNSView, context: Context) {
        nsView.updateCoordinator(coordinator)
    }

    static func dismantleNSView(_ nsView: FrilaBridgeNSView, coordinator: ()) {
        nsView.cleanup()
    }
}

final class FrilaBridgeNSView: NSView, NSGestureRecognizerDelegate {
    private(set) var coordinator: FrilaOutsideTapCoordinator
    private var clickRecognizer: NSClickGestureRecognizer?
    private weak var attachedView: NSView?

    init(coordinator: FrilaOutsideTapCoordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateCoordinator(_ newCoordinator: FrilaOutsideTapCoordinator) {
        self.coordinator = newCoordinator
    }

    func cleanup() {
        coordinator.detachScopeNSView()
        if let gr = clickRecognizer {
            gr.target = nil
            gr.action = nil
            gr.delegate = nil
            attachedView?.removeGestureRecognizer(gr)
            self.clickRecognizer = nil
            self.attachedView = nil
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil || newWindow != self.window {
            cleanup()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = self.window, let contentView = window.contentView else { return }

        coordinator.attachScopeNSView(self, window: window)

        if clickRecognizer == nil {
            let gr = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
            gr.delegate = self
            gr.delaysPrimaryMouseButtonEvents = true
            contentView.addGestureRecognizer(gr)
            self.clickRecognizer = gr
            self.attachedView = contentView
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    // MARK: - Pre-recognition triage (R5)

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        guard coordinator.hasActiveCandidates else { return false }
        guard let contentView = attachedView, let window = self.window else { return false }

        if gestureRecognizer.view?.window !== window { return false }

        let locationInContent = gestureRecognizer.location(in: contentView)
        let pointInScope = self.convert(locationInContent, from: contentView)
        guard self.bounds.contains(pointInScope) else { return false }

        let y = self.isFlipped ? pointInScope.y : (self.bounds.height - pointInScope.y)
        let flippedPoint = CGPoint(x: pointInScope.x, y: y)

        let disposition = coordinator.evaluateTouch(at: flippedPoint)
        return disposition == .outsideCandidate || disposition == .consumingExitRegion
    }

    @objc private func handleClick(_ sender: NSClickGestureRecognizer) {
        guard let contentView = attachedView else { return }
        let locationInContent = sender.location(in: contentView)
        let pointInScope = self.convert(locationInContent, from: contentView)
        guard self.bounds.contains(pointInScope) else { return }

        let y = self.isFlipped ? pointInScope.y : (self.bounds.height - pointInScope.y)
        let flippedPoint = CGPoint(x: pointInScope.x, y: y)

        if coordinator.evaluateTouch(at: flippedPoint) == .outsideCandidate {
            coordinator.performOutsideTap()
        }
    }
}
#endif
