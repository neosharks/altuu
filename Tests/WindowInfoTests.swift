import CoreGraphics

func testWindowInfo() {
    T.suite("WindowInfo — display title")

    let withTitle = WindowInfo(windowID: 1, pid: 1, appName: "Safari",
                               title: "Hacker News", frame: .zero, appIcon: nil)
    T.eq(withTitle.displayTitle, "Hacker News", "uses the window title when present")

    let blank = WindowInfo(windowID: 2, pid: 1, appName: "Terminal",
                           title: "   ", frame: .zero, appIcon: nil)
    T.eq(blank.displayTitle, "Terminal", "falls back to app name when title is blank")

    let empty = WindowInfo(windowID: 3, pid: 1, appName: "Notes",
                           title: "", frame: .zero, appIcon: nil)
    T.eq(empty.displayTitle, "Notes", "falls back to app name when title is empty")

    let padded = WindowInfo(windowID: 4, pid: 1, appName: "Xcode",
                            title: "  Project.swift  ", frame: .zero, appIcon: nil)
    T.eq(padded.displayTitle, "Project.swift", "trims surrounding whitespace")
}
