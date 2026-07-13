import CoreGraphics

func testGridSolver() {
    T.suite("GridSolver — grid geometry")
    let s = GridSolver()
    let wide: CGFloat = 2000
    let tall: CGFloat = 1400

    // Single window: 1x1, tiles at full base size on a big screen.
    let one = s.solve(count: 1, maxRowWidth: wide, maxColHeight: tall)
    T.eq(one.cols, 1, "1 window → 1 column")
    T.eq(one.rows, 1, "1 window → 1 row")
    T.approx(one.cellW, 360, "1 window → full-size tile (360)")

    // 3 windows fit in one row (below the 4-col cap).
    let three = s.solve(count: 3, maxRowWidth: wide, maxColHeight: tall)
    T.eq(three.cols, 3, "3 windows → 3 columns")
    T.eq(three.rows, 1, "3 windows → 1 row")

    // 5 windows: cap 4/row → 2 rows, evened to 3x2 (not 4+1).
    let five = s.solve(count: 5, maxRowWidth: wide, maxColHeight: tall)
    T.eq(five.rows, 2, "5 windows → 2 rows")
    T.eq(five.cols, 3, "5 windows → evened to 3 columns")

    // 8 windows → 4x2.
    let eight = s.solve(count: 8, maxRowWidth: wide, maxColHeight: tall)
    T.eq(eight.cols, 4, "8 windows → 4 columns")
    T.eq(eight.rows, 2, "8 windows → 2 rows")

    // 12 windows → 4x3.
    let twelve = s.solve(count: 12, maxRowWidth: wide, maxColHeight: tall)
    T.eq(twelve.cols, 4, "12 windows → 4 columns")
    T.eq(twelve.rows, 3, "12 windows → 3 rows")

    // Narrow screen forces a single column.
    let narrow = s.solve(count: 3, maxRowWidth: 500, maxColHeight: tall)
    T.eq(narrow.cols, 1, "narrow screen → 1 column")
    T.eq(narrow.rows, 3, "narrow screen, 3 windows → 3 rows")

    // Many windows on a short screen: shrink, but never below minCellW (240).
    let many = s.solve(count: 30, maxRowWidth: wide, maxColHeight: 400)
    T.check(many.cellW >= 240 - 0.5, "30 windows on short screen → tile stays ≥ minCellW (got \(many.cellW))")
    T.approx(many.cellW, 240, "30 windows → tile clamped to the 240 floor")

    // Tiles keep the base aspect ratio when shrunk.
    let ratioBase = s.baseCellW / s.baseCellH
    T.approx(many.cellW / many.cellH, ratioBase, "shrunk tiles keep aspect ratio", eps: 0.01)

    // Panel size is positive and grows with more rows.
    T.check(eight.size.width > 0 && eight.size.height > 0, "panel size is positive")
    T.check(twelve.size.height > eight.size.height, "more rows → taller panel")

    // count 0 is treated as 1 (never a zero/negative grid).
    let zero = s.solve(count: 0, maxRowWidth: wide, maxColHeight: tall)
    T.eq(zero.cols, 1, "0 windows → clamped to 1 column")
    T.eq(zero.rows, 1, "0 windows → clamped to 1 row")
}
