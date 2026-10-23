import SwiftUI

// MARK: - FrilaLPESegmentedItem
/// Item model for `FrilaLPESegmentedControl`.
public struct FrilaLPESegmentedItem<Selection: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    public let tag: Selection
    public let title: String
    public let systemImage: String?
    
    public var id: Selection { tag }
    
    public init(tag: Selection, title: String, systemImage: String? = nil) {
        self.tag = tag
        self.title = title
        self.systemImage = systemImage
    }
}

// MARK: - CANONICAL COMPONENT: FrilaLPESegmentedControl
/// Curatorial Segmented Capsule Control with sliding glider animation.
/// Synthesizes the minimalist museum aesthetic with fluid tactile physics:
/// - 100% Capsule geometry (container and glider).
/// - Dynamic surface background (`dynamicSurfaceInput`).
/// - Spring-animated sliding glider pill with continuous offset physics.
/// - Apple HIG compliant minimum touch hitbox (>= 44pt).
/// - Full VoiceOver accessibility support.
public struct FrilaLPESegmentedControl<Selection: Hashable & Sendable>: View {
    public let items: [FrilaLPESegmentedItem<Selection>]
    @Binding public var selection: Selection
    public let isDark: Bool
    /// External height of the segmented control.
    public let height: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isInitialLoad: Bool = true
    
    public static var defaultSpacing: CGFloat { 4 }
    public static var defaultPadding: CGFloat { 3 }

    private let spacing: CGFloat = 4
    private let padding: CGFloat = 3
    
    /// Inner height available for the glider and button labels after subtracting vertical padding.
    public var innerHeight: CGFloat {
        max(0, height - (padding * 2))
    }

    /// External height of the segmented control container.
    public var externalHeight: CGFloat {
        height
    }
    
    public init(
        items: [FrilaLPESegmentedItem<Selection>],
        selection: Binding<Selection>,
        isDark: Bool = false,
        height: CGFloat = 36
    ) {
        self.items = items
        self._selection = selection
        self.isDark = isDark
        self.height = height
    }
    
    private var selectedIndex: Int {
        items.firstIndex(where: { $0.tag == selection }) ?? 0
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let count = CGFloat(max(1, items.count))
            let availableWidth = max(0, totalWidth - (padding * 2) - (spacing * (count - 1)))
            let segmentWidth = availableWidth / count
            let gliderOffset = padding + CGFloat(selectedIndex) * (segmentWidth + spacing)
            
            ZStack(alignment: .topLeading) {
                // Hardware-accelerated sliding cell glider capsule (single persistent layer)
                if segmentWidth > 0 && innerHeight > 0 {
                    Capsule()
                        .fill(isDark ? Color.white : FrilaLPEColor.dynamicTextInk(isDark: isDark))
                        .frame(width: segmentWidth, height: innerHeight)
                        .shadow(color: isDark ? Color.black.opacity(0.25) : Color.black.opacity(0.08), radius: 2, y: 1)
                        .offset(x: gliderOffset, y: padding)
                        .animation(FrilaMovimento.animacao(.interpolatingSpring(stiffness: 350, damping: 26), reduzir: reduceMotion || isInitialLoad),
                            value: selectedIndex
                        )
                }
                
                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        let isSelected = selection == item.tag
                        Button {
                            selection = item.tag
                        } label: {
                            HStack(spacing: 6) {
                                if let systemImage = item.systemImage {
                                    Image(systemName: systemImage)
                                        .font(isSelected ? FrilaLPETypography.captionBold : FrilaLPETypography.captionMedium)
                                }
                                Text(verbatim: item.title)
                                    .font(isSelected ? FrilaLPETypography.captionBold : FrilaLPETypography.captionMedium)
                            }
                            .foregroundColor(
                                isSelected
                                    ? (isDark ? Color.black : Color.white)
                                    : FrilaLPEColor.dynamicTextMuted(isDark: isDark)
                            )
                            .animation(FrilaMovimento.animacao(.easeInOut(duration: 0.18), reduzir: FrilaLPEMovimentoReduzido.ativo), value: selectedIndex)
                            .frame(maxWidth: .infinity)
                            .frame(height: innerHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                selection = item.tag
                            }
                        )
                        .accessibilityLabel(item.title)
                        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
                    }
                }
                .padding(padding)
            }
            .frame(width: totalWidth, height: height)
            .background(FrilaLPEColor.dynamicFormFieldSurface(isDark: isDark))
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(FrilaLPEColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1) }
        }
        .frame(height: height)
        .frilaLPEHitbox()
        .sensoryFeedback(.selection, trigger: selection)
        .onAppear {
            DispatchQueue.main.async {
                isInitialLoad = false
            }
        }
    }
}
