import AppKit
import CoreGraphics

/// Lists every normal, on-screen window on the current Space, front-to-back.
/// Each window is a distinct entry — three Terminal windows show as three items.
enum WindowEnumerator {

    // Owners that only ever expose chrome / overlays, never real app windows.
    private static let ignoredOwners: Set<String> = [
        "Window Server", "Dock", "Control Center", "Notification Center",
        "WindowManager", "Spotlight", "Wallpaper", "SystemUIServer"
    ]

    /// - Parameter allSpaces: when true, includes windows from every desktop/Space;
    ///   when false (default), only windows on the current Space.
    static func currentWindows(allSpaces: Bool = false) -> [WindowInfo] {
        let options: CGWindowListOption = allSpaces
            ? [.excludeDesktopElements]
            : [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let myPid = ProcessInfo.processInfo.processIdentifier
        var iconCache: [pid_t: NSImage?] = [:]
        return makeWindows(from: raw, selfPID: myPid) { pid in
            if let cached = iconCache[pid] { return cached }
            let icon = NSRunningApplication(processIdentifier: pid)?.icon
            iconCache[pid] = icon
            return icon
        }
    }

    // Minimum on-screen size for a window to be worth listing (px).
    static let minWindowSide: CGFloat = 80
    // Windows below this alpha are effectively invisible.
    static let minAlpha: Double = 0.05

    /// Pure transform from raw CGWindowList dictionaries to `WindowInfo`.
    /// Extracted so the filtering rules are unit-testable without the WindowServer.
    static func makeWindows(from raw: [[String: Any]],
                            selfPID: pid_t,
                            iconFor: (pid_t) -> NSImage? = { _ in nil }) -> [WindowInfo] {
        var result: [WindowInfo] = []

        for dict in raw {
            // Layer 0 == normal application windows (skip menus, docks, popovers).
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else { continue }

            guard let pidValue = dict[kCGWindowOwnerPID as String] as? pid_t,
                  pidValue != selfPID else { continue }

            let alpha = dict[kCGWindowAlpha as String] as? Double ?? 1.0
            if alpha < minAlpha { continue }

            guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID else { continue }

            guard let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // Drop slivers: menubar extras, tooltips, 1px helper windows.
            if bounds.width < minWindowSide || bounds.height < minWindowSide { continue }

            let appName = dict[kCGWindowOwnerName as String] as? String ?? ""
            if ignoredOwners.contains(appName) { continue }

            // kCGWindowName is only populated once Screen Recording is granted.
            let title = dict[kCGWindowName as String] as? String ?? ""

            result.append(WindowInfo(windowID: windowID,
                                     pid: pidValue,
                                     appName: appName,
                                     title: title,
                                     frame: bounds,
                                     appIcon: iconFor(pidValue)))
        }

        return result
    }
}
