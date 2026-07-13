import AppKit
import CoreGraphics

private func boundsDict(_ w: CGFloat, _ h: CGFloat) -> [String: Any] {
    let rect = CGRect(x: 0, y: 0, width: w, height: h)
    return (rect.dictionaryRepresentation as NSDictionary) as? [String: Any] ?? [:]
}

/// Build a synthetic CGWindowList-style dictionary.
private func win(id: CGWindowID, pid: pid_t, owner: String, name: String? = nil,
                 layer: Int = 0, alpha: Double = 1.0,
                 w: CGFloat = 800, h: CGFloat = 600) -> [String: Any] {
    var d: [String: Any] = [
        kCGWindowNumber as String: id,
        kCGWindowOwnerPID as String: pid,
        kCGWindowOwnerName as String: owner,
        kCGWindowLayer as String: layer,
        kCGWindowAlpha as String: alpha,
        kCGWindowBounds as String: boundsDict(w, h),
    ]
    if let name { d[kCGWindowName as String] = name }
    return d
}

func testWindowEnumerator() {
    T.suite("WindowEnumerator — filtering rules")
    let selfPID: pid_t = 999

    // A normal window is kept, with its fields mapped through.
    let normal = WindowEnumerator.makeWindows(
        from: [win(id: 1, pid: 100, owner: "Terminal", name: "zsh")], selfPID: selfPID)
    T.eq(normal.count, 1, "normal window is included")
    if let w = normal.first {
        T.eq(w.windowID, 1, "windowID mapped")
        T.eq(w.appName, "Terminal", "appName mapped")
        T.eq(w.title, "zsh", "title mapped")
    }

    // THE headline feature: three windows of the SAME app are three entries.
    let terminals = WindowEnumerator.makeWindows(from: [
        win(id: 10, pid: 100, owner: "Terminal", name: "zsh — one"),
        win(id: 11, pid: 100, owner: "Terminal", name: "zsh — two"),
        win(id: 12, pid: 100, owner: "Terminal", name: "zsh — three"),
    ], selfPID: selfPID)
    T.eq(terminals.count, 3, "3 Terminal windows → 3 separate entries")
    T.eq(Set(terminals.map { $0.windowID }).count, 3, "each entry keeps a distinct windowID")

    // Front-to-back order is preserved.
    T.eq(terminals.map { $0.windowID }, [10, 11, 12], "input order is preserved")

    // Exclusions.
    let excluded = WindowEnumerator.makeWindows(from: [
        win(id: 20, pid: 100, owner: "Menu", layer: 25),          // non-zero layer
        win(id: 21, pid: selfPID, owner: "Altuu"),                // our own process
        win(id: 22, pid: 100, owner: "Ghost", alpha: 0.01),       // invisible
        win(id: 23, pid: 100, owner: "Tiny", w: 40, h: 40),       // sliver
        win(id: 24, pid: 100, owner: "Dock"),                     // ignored owner
    ], selfPID: selfPID)
    T.eq(excluded.count, 0, "layer≠0, self-pid, low-alpha, tiny, and Dock are all excluded")

    // Exactly one boundary case survives among a mixed batch.
    let mixed = WindowEnumerator.makeWindows(from: [
        win(id: 30, pid: 100, owner: "Dock"),                     // dropped
        win(id: 31, pid: 100, owner: "Safari", name: "News"),     // kept
        win(id: 32, pid: 100, owner: "Tiny", w: 10, h: 10),       // dropped
    ], selfPID: selfPID)
    T.eq(mixed.count, 1, "mixed batch keeps only the valid window")
    T.eq(mixed.first?.appName, "Safari", "the kept window is Safari")

    // Missing title (Screen Recording not granted) → empty title, icon falls back later.
    let noTitle = WindowEnumerator.makeWindows(
        from: [win(id: 40, pid: 100, owner: "Notes")], selfPID: selfPID)
    T.eq(noTitle.first?.title ?? "nil", "", "missing kCGWindowName → empty title")

    // The icon provider is used for each window's pid.
    var askedPIDs: [pid_t] = []
    let dummy = NSImage(size: NSSize(width: 1, height: 1))
    let withIcon = WindowEnumerator.makeWindows(
        from: [win(id: 50, pid: 321, owner: "Xcode", name: "main")], selfPID: selfPID) { pid in
            askedPIDs.append(pid); return dummy
        }
    T.eq(askedPIDs, [321], "icon provider queried with the window's pid")
    T.check(withIcon.first?.appIcon === dummy, "provided icon is attached to the window")
}
