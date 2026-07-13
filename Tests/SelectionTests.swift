func testSelection() {
    T.suite("WindowSelection — highlight stepping")

    // Initial highlight is the *next* window (index 1) so a single ⌥Tab swaps.
    T.eq(WindowSelection.initialIndex(count: 5, backward: false), 1, "open forward → highlight index 1")
    T.eq(WindowSelection.initialIndex(count: 5, backward: true), 4, "open backward → highlight last")
    T.eq(WindowSelection.initialIndex(count: 1, backward: false), 0, "single window → index 0")
    T.eq(WindowSelection.initialIndex(count: 1, backward: true), 0, "single window backward → index 0")
    T.eq(WindowSelection.initialIndex(count: 0, backward: false), 0, "no windows → index 0")

    // Forward stepping.
    T.eq(WindowSelection.step(index: 0, count: 5, backward: false), 1, "step forward 0 → 1")
    T.eq(WindowSelection.step(index: 3, count: 5, backward: false), 4, "step forward 3 → 4")
    T.eq(WindowSelection.step(index: 4, count: 5, backward: false), 0, "step forward wraps 4 → 0")

    // Backward stepping.
    T.eq(WindowSelection.step(index: 0, count: 5, backward: true), 4, "step backward wraps 0 → 4")
    T.eq(WindowSelection.step(index: 2, count: 5, backward: true), 1, "step backward 2 → 1")

    // Edge counts.
    T.eq(WindowSelection.step(index: 0, count: 1, backward: false), 0, "single window forward stays 0")
    T.eq(WindowSelection.step(index: 0, count: 1, backward: true), 0, "single window backward stays 0")
    T.eq(WindowSelection.step(index: 0, count: 0, backward: false), 0, "empty list stays 0")

    // A full forward cycle returns to the start.
    var idx = 0
    for _ in 0..<7 { idx = WindowSelection.step(index: idx, count: 7, backward: false) }
    T.eq(idx, 0, "7 forward steps over 7 windows returns to start")
}
