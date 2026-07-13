import AppKit

// MARK: - One window cell (app header + thumbnail + title)

private final class CellView: NSView {
    private let appIcon = NSImageView()          // top: app icon
    private let appName = NSTextField(labelWithString: "")   // top: app name
    private let thumb = NSImageView()            // middle: window preview
    private let title = NSTextField(labelWithString: "")     // bottom: window title

    var index = 0
    var onClick: ((Int) -> Void)?
    var isSelected = false { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        appIcon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(appIcon)

        appName.font = .systemFont(ofSize: 15, weight: .semibold)
        appName.textColor = .white
        style(appName)
        addSubview(appName)

        thumb.imageScaling = .scaleProportionallyUpOrDown
        thumb.wantsLayer = true
        thumb.layer?.cornerRadius = 4
        thumb.layer?.masksToBounds = true
        addSubview(thumb)

        title.font = .systemFont(ofSize: 13, weight: .regular)
        title.textColor = NSColor.white.withAlphaComponent(0.72)
        style(title)
        addSubview(title)
    }

    private func style(_ field: NSTextField) {
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.cell?.truncatesLastVisibleLine = true
        field.alignment = .left
        field.backgroundColor = .clear
        field.isBezeled = false
        field.drawsBackground = false
    }

    required init?(coder: NSCoder) { fatalError("no coder") }

    func configure(_ info: WindowInfo) {
        appIcon.image = info.appIcon
        appName.stringValue = info.appName
        thumb.image = info.thumbnail ?? info.appIcon
        title.stringValue = info.title.trimmingCharacters(in: .whitespacesAndNewlines)
        toolTip = info.displayTitle
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 12
        let headerH: CGFloat = 22
        let titleH: CGFloat = 18
        let iconSize: CGFloat = 24

        // Header (app icon + app name) pinned to the top.
        let headerY = bounds.height - inset - headerH
        appIcon.frame = NSRect(x: inset, y: headerY, width: iconSize, height: iconSize)
        appName.frame = NSRect(x: inset + iconSize + 5, y: headerY,
                               width: bounds.width - inset * 2 - iconSize - 5, height: headerH)

        // Window title pinned to the bottom.
        title.frame = NSRect(x: inset, y: inset, width: bounds.width - inset * 2, height: titleH)

        // Thumbnail fills the space between header and title.
        let thumbTop = headerY - 6
        let thumbBottom = inset + titleH + 6
        thumb.frame = NSRect(x: inset, y: thumbBottom,
                             width: bounds.width - inset * 2,
                             height: max(thumbTop - thumbBottom, 1))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isSelected else { return }
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.20).setFill()
        path.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 3
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) { onClick?(index) }
}

// MARK: - Grid of cells inside a blurred rounded background

private final class SwitcherView: NSView {
    private let background = NSVisualEffectView()
    private let border = CALayer()
    private let header = NSTextField(labelWithString: "")
    private var cells: [CellView] = []
    private var windows: [WindowInfo] = []
    private var selected = 0

    var onClickIndex: ((Int) -> Void)?
    var maxRowWidth: CGFloat = 1200
    var maxColHeight: CGFloat = 800

    private let gap: CGFloat = 10
    private let pad: CGFloat = 18
    private let headerH: CGFloat = 30      // title strip at the top

    // Pure geometry lives in GridSolver (see GridSolverTests).
    private let solver = GridSolver()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        background.material = .hudWindow
        background.state = .active
        background.blendingMode = .behindWindow
        background.wantsLayer = true
        background.layer?.cornerRadius = 20
        background.layer?.masksToBounds = true
        addSubview(background)

        // Hairline border for a crisper edge over the blur.
        border.borderWidth = 1
        border.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        border.cornerRadius = 20
        background.layer?.addSublayer(border)

        header.font = .systemFont(ofSize: 13, weight: .semibold)
        header.textColor = NSColor.white.withAlphaComponent(0.85)
        header.alignment = .center
        header.backgroundColor = .clear
        header.isBezeled = false
        header.drawsBackground = false
        addSubview(header)
    }

    required init?(coder: NSCoder) { fatalError("no coder") }

    private func layoutMetrics() -> GridSolver.Result {
        solver.solve(count: windows.count, maxRowWidth: maxRowWidth, maxColHeight: maxColHeight)
    }

    func preferredSize() -> NSSize {
        var s = layoutMetrics().size
        s.height += headerH
        return s
    }

    func update(windows: [WindowInfo], selected: Int) {
        let sameSet = windows.count == self.windows.count &&
            !zip(windows, self.windows).contains { $0.windowID != $1.windowID }
        self.windows = windows
        self.selected = selected

        // Header: show the highlighted window's title, with a count.
        if windows.indices.contains(selected) {
            let w = windows[selected]
            header.stringValue = "\(w.appName) — \(w.displayTitle)   ·   \(selected + 1)/\(windows.count)"
        } else {
            header.stringValue = "\(windows.count) windows"
        }

        if sameSet && cells.count == windows.count {
            for (i, cell) in cells.enumerated() {
                cell.configure(windows[i])
                cell.isSelected = (i == selected)
            }
        } else {
            rebuild()
        }
        needsLayout = true
    }

    private func rebuild() {
        cells.forEach { $0.removeFromSuperview() }
        cells = windows.enumerated().map { i, info in
            let cell = CellView(frame: .zero)
            cell.index = i
            cell.configure(info)
            cell.isSelected = (i == selected)
            cell.onClick = { [weak self] idx in self?.onClickIndex?(idx) }
            addSubview(cell)
            return cell
        }
    }

    override func layout() {
        super.layout()
        background.frame = bounds
        border.frame = bounds

        header.frame = NSRect(x: pad, y: bounds.height - headerH,
                              width: bounds.width - pad * 2, height: headerH - 6)

        let m = layoutMetrics()
        let gridTop = bounds.height - headerH
        for (i, cell) in cells.enumerated() {
            let row = CGFloat(i / m.cols)
            let col = CGFloat(i % m.cols)
            let x: CGFloat = pad + col * (m.cellW + gap)
            let rowsFromTop: CGFloat = (row + 1) * m.cellH + row * gap
            let y: CGFloat = gridTop - pad - rowsFromTop
            cell.frame = NSRect(x: x, y: y, width: m.cellW, height: m.cellH)
        }
    }
}

// MARK: - Controller: owns the panel and drives selection

final class SwitcherController {
    private let panel: NSPanel
    private let view: SwitcherView
    private var windows: [WindowInfo] = []
    private var selectedIndex = 0

    private(set) var visible = false

    init() {
        view = SwitcherView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))

        panel = NSPanel(contentRect: view.frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = view

        view.onClickIndex = { [weak self] idx in
            self?.selectedIndex = idx
            self?.commit()
        }
    }

    /// Called on every Option+Tab press.
    func invoke(backward: Bool) {
        if visible {
            step(backward: backward)
        } else {
            windows = WindowEnumerator.currentWindows(allSpaces: Settings.shared.showAllSpaces)
            guard !windows.isEmpty else { return }
            selectedIndex = WindowSelection.initialIndex(count: windows.count, backward: backward)
            show()
            captureThumbnails()
        }
        view.update(windows: windows, selected: selectedIndex)
    }

    /// Arrow-key navigation while the switcher is open.
    func stepSelection(backward: Bool) {
        guard visible else { return }
        step(backward: backward)
        view.update(windows: windows, selected: selectedIndex)
    }

    private func step(backward: Bool) {
        selectedIndex = WindowSelection.step(index: selectedIndex, count: windows.count, backward: backward)
    }

    private func show() {
        let screen = screenUnderMouse()
        view.maxRowWidth = screen.visibleFrame.width * 0.92
        view.maxColHeight = screen.visibleFrame.height * 0.9
        view.update(windows: windows, selected: selectedIndex)

        let size = view.preferredSize()
        let sf = screen.frame
        let origin = NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        // Quick fade + slight scale-in.
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        visible = true
    }

    func cancel() { hide() }

    func commit() {
        guard visible else { return }
        hide()
        if windows.indices.contains(selectedIndex) {
            WindowActivator.activate(windows[selectedIndex])
        }
    }

    private func hide() {
        panel.orderOut(nil)
        visible = false
    }

    private func captureThumbnails() {
        guard #available(macOS 14.0, *) else { return }
        let snapshot = windows
        ThumbnailCapturer.capture(windows: snapshot) { [weak self] id, image in
            guard let self = self, self.visible else { return }
            guard let win = self.windows.first(where: { $0.windowID == id }) else { return }
            win.thumbnail = image
            self.view.update(windows: self.windows, selected: self.selectedIndex)
        }
    }

    private func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
