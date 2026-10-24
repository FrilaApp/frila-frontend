import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// High-fidelity transition container between Skeleton screens and loaded content.
/// Features interpolating spring physics (stiffness: 350, damping: 25), zero layout shift,
/// micro-blur cross-fade, and VoiceOver announcement on completion.
public struct FrilaSkeletonCrossfade<SkeletonContent: View, RealContent: View>: View {
    public let isLoading: Bool
    public let loadedAccessibilityAnnouncement: String?
    @ViewBuilder public let skeleton: () -> SkeletonContent
    @ViewBuilder public let content: () -> RealContent
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        isLoading: Bool,
        announcement: String? = nil,
        @ViewBuilder skeleton: @escaping () -> SkeletonContent,
        @ViewBuilder content: @escaping () -> RealContent
    ) {
        self.isLoading = isLoading
        self.loadedAccessibilityAnnouncement = announcement
        self.skeleton = skeleton
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            if isLoading {
                skeleton()
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.995))
                    )
                    .allowsHitTesting(false)
            } else {
                content()
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 1.0))
                    )
                    .allowsHitTesting(true)
            }
        }
        .animation(FrilaMovimento.animacao(reduceMotion
                ? .linear(duration: 0.15)
                : .interpolatingSpring(stiffness: 350, damping: 25), reduzir: FrilaMovimentoReduzido.ativo),
            value: isLoading
        )
        .onChange(of: isLoading) { oldValue, newValue in
            if oldValue == true && newValue == false, let announcement = loadedAccessibilityAnnouncement {
                postAccessibilityAnnouncement(announcement)
            }
        }
    }
    
    private func postAccessibilityAnnouncement(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif canImport(AppKit)
        NSAccessibility.post(
            element: NSApp.keyWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message]
        )
        #endif
    }
}

/// Emil Kowalski style micro-blur cross-fade modifier for loading state transitions
public struct FrilaDataCrossFadeModifier: ViewModifier {
    public let isLoading: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(isLoading: Bool) {
        self.isLoading = isLoading
    }
    
    public func body(content: Content) -> some View {
        content
            .blur(radius: (!reduceMotion && isLoading) ? 1.5 : 0.0)
            .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 25), reduzir: reduceMotion),
                value: isLoading
            )
    }
}

public extension View {
    /// Applies subtle micro-blur cross-fade to smooth out transitions between skeleton and real data
    func frilaDataCrossFade(isLoading: Bool) -> some View {
        modifier(FrilaDataCrossFadeModifier(isLoading: isLoading))
    }
}
