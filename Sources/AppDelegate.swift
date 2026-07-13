import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let switcher = SwitcherController()
    private let hotkeys = HotKeyManager()
    private var statusItem: NSStatusItem?
    private var trustTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar agent, no Dock icon
        setupStatusItem()
        wireHotkeys()

        // Ask for both permissions up front.
        Permissions.ensureAccessibility(prompt: true)
        Permissions.ensureScreenRecording()

        // Warm ScreenCaptureKit now so the first ⌥Tab isn't slow.
        if #available(macOS 14.0, *) { ThumbnailCapturer.prewarm() }

        startHotkeysWhenTrusted()
    }

    private func wireHotkeys() {
        hotkeys.isActive = { [weak self] in self?.switcher.visible ?? false }
        hotkeys.onInvoke = { [weak self] backward in self?.switcher.invoke(backward: backward) }
        hotkeys.onStep = { [weak self] backward in self?.switcher.stepSelection(backward: backward) }
        hotkeys.onCommit = { [weak self] in self?.switcher.commit() }
        hotkeys.onCancel = { [weak self] in self?.switcher.cancel() }
        hotkeys.onPrewarm = { if #available(macOS 14.0, *) { ThumbnailCapturer.prewarm() } }
    }

    /// The event tap can only be created once Accessibility is granted, which may
    /// happen after launch — poll until it succeeds.
    private func startHotkeysWhenTrusted() {
        if hotkeys.start() { refreshStatusAppearance(); return }

        refreshStatusAppearance()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if Permissions.hasAccessibility(), self.hotkeys.start() {
                self.refreshStatusAppearance()
                timer.invalidate()
                self.trustTimer = nil
            }
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            button.image = NSImage(systemSymbolName: "square.stack.3d.up.fill",
                                   accessibilityDescription: "Altuu")?
                .withSymbolConfiguration(cfg)
            button.imagePosition = .imageOnly
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// Rebuild the menu each time it opens so permission state is always live.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Header.
        let title = NSMenuItem()
        title.attributedTitle = NSAttributedString(
            string: "Altuu",
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .bold)])
        menu.addItem(title)
        let hint = NSMenuItem(title: "Hold ⌥ Option, tap Tab to switch windows",
                              action: nil, keyEquivalent: "")
        hint.isEnabled = false
        hint.attributedTitle = NSAttributedString(
            string: "Hold ⌥ Option, tap Tab to switch windows",
            attributes: [.font: NSFont.systemFont(ofSize: 11),
                         .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(hint)
        menu.addItem(.separator())

        // Live permission status.
        let ax = Permissions.hasAccessibility()
        let sr = Permissions.hasScreenRecording()
        menu.addItem(statusRow("Accessibility", granted: ax, action: #selector(openAccessibility)))
        menu.addItem(statusRow("Screen Recording", granted: sr, action: #selector(openScreenRecording)))

        if !ax || !sr {
            let warn = NSMenuItem(title: "Grant the missing permission above",
                                  action: nil, keyEquivalent: "")
            warn.isEnabled = false
            warn.attributedTitle = NSAttributedString(
                string: "  Grant the missing permission above",
                attributes: [.font: NSFont.systemFont(ofSize: 11),
                             .foregroundColor: NSColor.systemOrange])
            menu.addItem(warn)
        }
        menu.addItem(.separator())

        // Window scope (which windows the switcher lists).
        let scopeHeader = NSMenuItem(title: "Show windows from", action: nil, keyEquivalent: "")
        scopeHeader.isEnabled = false
        scopeHeader.attributedTitle = NSAttributedString(
            string: "Show windows from",
            attributes: [.font: NSFont.systemFont(ofSize: 11),
                         .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(scopeHeader)

        let all = Settings.shared.showAllSpaces
        let thisDesktop = NSMenuItem(title: "This desktop only",
                                     action: #selector(scopeThisDesktop), keyEquivalent: "")
        thisDesktop.target = self
        thisDesktop.state = all ? .off : .on
        menu.addItem(thisDesktop)

        let allDesktops = NSMenuItem(title: "All desktops",
                                     action: #selector(scopeAllDesktops), keyEquivalent: "")
        allDesktops.target = self
        allDesktops.state = all ? .on : .off
        menu.addItem(allDesktops)
        menu.addItem(.separator())

        // Launch at login toggle.
        let login = NSMenuItem(title: "Launch at Login",
                               action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        add(menu, "Quit Altuu", #selector(quit), key: "q")
    }

    private func statusRow(_ name: String, granted: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: name, action: action, keyEquivalent: "")
        item.target = self
        let symbol = granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        let color: NSColor = granted ? .systemGreen : .systemOrange
        let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            .applying(.init(paletteColors: [color]))
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        item.attributedTitle = NSAttributedString(
            string: granted ? "\(name) — granted" : "\(name) — click to grant",
            attributes: [.font: NSFont.systemFont(ofSize: 12)])
        return item
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func refreshStatusAppearance() {
        let active = Permissions.hasAccessibility()
        statusItem?.button?.appearsDisabled = !active
        statusItem?.button?.toolTip = active
            ? "Altuu — ready (⌥Tab)"
            : "Altuu — needs Accessibility permission"
    }

    // MARK: - Launch at login

    private var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("[Altuu] launch-at-login toggle failed: \(error)")
        }
    }

    // MARK: - Actions

    @objc private func scopeThisDesktop() { Settings.shared.showAllSpaces = false }
    @objc private func scopeAllDesktops() { Settings.shared.showAllSpaces = true }

    @objc private func openAccessibility() {
        Permissions.ensureAccessibility(prompt: true)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @objc private func openScreenRecording() {
        Permissions.ensureScreenRecording()
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }
}
