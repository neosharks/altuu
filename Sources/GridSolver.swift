import CoreGraphics

/// Pure grid geometry for the switcher — no UIKit/AppKit, so it is unit-testable.
///
/// Tiles stay big: the grid grows into rows and only shrinks uniformly (never
/// below `minCellW`) if it would overflow the available screen budget.
struct GridSolver {
    var baseCellW: CGFloat = 360
    var baseCellH: CGFloat = 270
    var gap: CGFloat = 10
    var pad: CGFloat = 18
    var minCellW: CGFloat = 240
    var preferredMaxColumns: Int = 4

    struct Result: Equatable {
        let cols: Int
        let rows: Int
        let cellW: CGFloat
        let cellH: CGFloat
        let size: CGSize
    }

    func solve(count: Int, maxRowWidth: CGFloat, maxColHeight: CGFloat) -> Result {
        let n = max(count, 1)

        // Columns at the big base size: whatever fits across the screen, capped.
        let fitCols = max(1, Int((maxRowWidth - pad * 2 + gap) / (baseCellW + gap)))
        let capCols = max(1, min(fitCols, preferredMaxColumns))
        let rows = Int(ceil(Double(n) / Double(capCols)))
        // Even out the last row (e.g. 8 -> 4x2, not 5+3).
        let cols = min(n, Int(ceil(Double(n) / Double(rows))))

        func size(_ cw: CGFloat, _ ch: CGFloat) -> CGSize {
            CGSize(width: pad * 2 + CGFloat(cols) * cw + CGFloat(cols - 1) * gap,
                   height: pad * 2 + CGFloat(rows) * ch + CGFloat(rows - 1) * gap)
        }

        var full = size(baseCellW, baseCellH)
        // Shrink uniformly only if the grid overflows, but never below minCellW.
        let floor = minCellW / baseCellW
        let scale = max(floor, min(1, min(maxRowWidth / full.width, maxColHeight / full.height)))
        let cw = baseCellW * scale
        let ch = baseCellH * scale
        if scale != 1 { full = size(cw, ch) }

        return Result(cols: cols, rows: rows, cellW: cw, cellH: ch, size: full)
    }
}

/// Pure selection stepping with wrap-around.
enum WindowSelection {
    static func step(index: Int, count: Int, backward: Bool) -> Int {
        guard count > 0 else { return 0 }
        return ((index + (backward ? -1 : 1)) % count + count) % count
    }

    /// Initial highlight when the switcher opens: the *next* window (index 1),
    /// or the last one when opened backward. Single window stays at 0.
    static func initialIndex(count: Int, backward: Bool) -> Int {
        guard count > 1 else { return 0 }
        return backward ? count - 1 : 1
    }
}
