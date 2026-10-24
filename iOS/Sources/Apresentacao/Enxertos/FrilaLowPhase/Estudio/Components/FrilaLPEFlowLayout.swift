import SwiftUI

// MARK: - CANONICAL COMPONENT: FrilaLPEFlowLayout
/// Curatorial Wrapping Flow Layout driven by intrinsic child sizes.
///
/// Places child views horizontally along a row until an element cannot fit within
/// the available width, then breaks to a subsequent row while maintaining consistent
/// horizontal and vertical spacing.
///
/// Conforms to Apple HIG touch targets, zero web-shadow mandates, and anti-slop rules.
/// If an individual child's intrinsic width exceeds the container width on an ultra-narrow
/// viewport, only that specific child is constrained to the container width, allowing
/// graceful truncation as the real last resort without overflowing the container bounds.
public struct FrilaLPEFlowLayout: Layout, Sendable {
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat
    public var horizontalAlignment: HorizontalAlignment
    public var verticalAlignment: VerticalAlignment
    
    public init(
        horizontalSpacing: CGFloat = FrilaLPEGeometry.space8,
        verticalSpacing: CGFloat = FrilaLPEGeometry.space8,
        horizontalAlignment: HorizontalAlignment = .leading,
        verticalAlignment: VerticalAlignment = .center
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
    }
    
    // MARK: - Layout Calculation Model
    
    public struct LayoutResult: Sendable {
        public struct RowItem: Sendable {
            public let index: Int
            public let size: CGSize
        }
        
        public struct Row: Sendable {
            public var items: [RowItem] = []
            public var width: CGFloat = 0
            public var height: CGFloat = 0
        }
        
        public let rows: [Row]
        public let totalSize: CGSize
    }
    
    // MARK: - Layout Caching (Performance Audit)
    
    public struct CacheData: Sendable {
        public var lastWidth: CGFloat?
        public var lastResult: LayoutResult?
        
        public init(lastWidth: CGFloat? = nil, lastResult: LayoutResult? = nil) {
            self.lastWidth = lastWidth
            self.lastResult = lastResult
        }
    }
    
    public func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }
    
    public func updateCache(_ cache: inout CacheData, subviews: Subviews) {
        cache.lastWidth = nil
        cache.lastResult = nil
    }

    /// Pure mathematical calculation for row distribution, line breaks, and bounding size.
    public static func calculateLayout(
        itemSizes: [CGSize],
        availableWidth: CGFloat,
        horizontalSpacing: CGFloat = FrilaLPEGeometry.space8,
        verticalSpacing: CGFloat = FrilaLPEGeometry.space8
    ) -> LayoutResult {
        guard !itemSizes.isEmpty, availableWidth > 0 else {
            return LayoutResult(rows: [], totalSize: .zero)
        }
        
        let maxWidth = availableWidth.isFinite ? availableWidth : .infinity
        let tolerance: CGFloat = 0.5
        var rows: [LayoutResult.Row] = []
        var currentRow = LayoutResult.Row()
        var maxRowWidth: CGFloat = 0
        
        for (index, idealSize) in itemSizes.enumerated() {
            let itemWidth: CGFloat
            let itemHeight: CGFloat
            if maxWidth.isFinite && idealSize.width > maxWidth {
                itemWidth = maxWidth
                itemHeight = idealSize.height
            } else {
                itemWidth = idealSize.width
                itemHeight = idealSize.height
            }
            let itemSize = CGSize(width: max(0, itemWidth), height: max(0, itemHeight))
            
            if currentRow.items.isEmpty {
                currentRow.items.append(LayoutResult.RowItem(index: index, size: itemSize))
                currentRow.width = itemSize.width
                currentRow.height = itemSize.height
            } else {
                let candidateWidth = currentRow.width + horizontalSpacing + itemSize.width
                if candidateWidth <= maxWidth + tolerance {
                    currentRow.items.append(LayoutResult.RowItem(index: index, size: itemSize))
                    currentRow.width = candidateWidth
                    currentRow.height = max(currentRow.height, itemSize.height)
                } else {
                    rows.append(currentRow)
                    maxRowWidth = max(maxRowWidth, currentRow.width)
                    currentRow = LayoutResult.Row(
                        items: [LayoutResult.RowItem(index: index, size: itemSize)],
                        width: itemSize.width,
                        height: itemSize.height
                    )
                }
            }
        }
        
        if !currentRow.items.isEmpty {
            rows.append(currentRow)
            maxRowWidth = max(maxRowWidth, currentRow.width)
        }
        
        let totalHeight = rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * verticalSpacing
        let resolvedWidth = (availableWidth.isFinite && availableWidth > 0) ? availableWidth : maxRowWidth
        
        return LayoutResult(rows: rows, totalSize: CGSize(width: resolvedWidth, height: totalHeight))
    }
    
    private func computeLayout(
        subviews: Subviews,
        availableWidth: CGFloat
    ) -> LayoutResult {
        guard !subviews.isEmpty, availableWidth > 0 else {
            return LayoutResult(rows: [], totalSize: .zero)
        }
        
        let maxWidth = availableWidth.isFinite ? availableWidth : .infinity
        
        var measuredSizes: [CGSize] = []
        measuredSizes.reserveCapacity(subviews.count)
        
        for subview in subviews {
            let idealSize = subview.sizeThatFits(.unspecified)
            if maxWidth.isFinite && idealSize.width > maxWidth {
                let constrained = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                let clampedWidth = max(0, min(constrained.width, maxWidth))
                let clampedHeight = max(idealSize.height, constrained.height)
                measuredSizes.append(CGSize(width: clampedWidth, height: clampedHeight))
            } else {
                measuredSizes.append(idealSize)
            }
        }
        
        return Self.calculateLayout(
            itemSizes: measuredSizes,
            availableWidth: availableWidth,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
    }
    
    private func cachedComputeLayout(
        subviews: Subviews,
        availableWidth: CGFloat,
        cache: inout CacheData
    ) -> LayoutResult {
        if let lastWidth = cache.lastWidth,
           abs(lastWidth - availableWidth) < 0.001,
           let lastResult = cache.lastResult {
            return lastResult
        }
        let result = computeLayout(subviews: subviews, availableWidth: availableWidth)
        cache.lastWidth = availableWidth
        cache.lastResult = result
        return result
    }
    
    // MARK: - SwiftUI Layout Implementation
    
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let availableWidth = proposal.width ?? .infinity
        guard availableWidth > 0 else { return .zero }
        let result = cachedComputeLayout(subviews: subviews, availableWidth: availableWidth, cache: &cache)
        return result.totalSize
    }
    
    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) {
        guard !subviews.isEmpty, bounds.width > 0 else { return }
        
        let result = cachedComputeLayout(subviews: subviews, availableWidth: bounds.width, cache: &cache)
        guard !result.rows.isEmpty else { return }
        
        var currentY = bounds.minY
        
        for row in result.rows {
            let rowXOffset: CGFloat
            switch horizontalAlignment {
            case .leading:
                rowXOffset = 0
            case .center:
                rowXOffset = max(0, (bounds.width - row.width) / 2)
            case .trailing:
                rowXOffset = max(0, bounds.width - row.width)
            default:
                rowXOffset = 0
            }
            
            var currentX = bounds.minX + rowXOffset
            
            for item in row.items {
                let subview = subviews[item.index]
                
                let itemYOffset: CGFloat
                switch verticalAlignment {
                case .top:
                    itemYOffset = 0
                case .center:
                    itemYOffset = (row.height - item.size.height) / 2
                case .bottom:
                    itemYOffset = row.height - item.size.height
                default:
                    itemYOffset = (row.height - item.size.height) / 2
                }
                
                subview.place(
                    at: CGPoint(x: currentX, y: currentY + itemYOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                
                currentX += item.size.width + horizontalSpacing
            }
            
            currentY += row.height + verticalSpacing
        }
    }
}

/// Typealias adhering to WrappingLayout terminology specified in Issue #20.
public typealias FrilaLPEWrappingLayout = FrilaLPEFlowLayout

// MARK: - Previews
