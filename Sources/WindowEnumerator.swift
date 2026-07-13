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
        var result: [WindowInfo] = []

        for dict in raw {
            // Layer 0 == normal application windows (skip menus, docks, popovers).
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else { continue }

            guard let pidValue = dict[kCGWindowOwnerPID as String] as? pid_t,
                  pidValue != myPid else { continue }

            let alpha = dict[kCGWindowAlpha as String] as? Double ?? 1.0
            if alpha < 0.05 { continue }

            guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID else { continue }

            guard let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // Drop slivers: menubar extras, tooltips, 1px helper windows.
            if bounds.width < 80 || bounds.height < 80 { continue }

            let appName = dict[kCGWindowOwnerName as String] as? String ?? ""
            if ignoredOwners.contains(appName) { continue }

            // kCGWindowName is only populated once Screen Recording is granted.
            let title = dict[kCGWindowName as String] as? String ?? ""

            let icon: NSImage?
            if let cached = iconCache[pidValue] {
                icon = cached
            } else {
                icon = NSRunningApplication(processIdentifier: pidValue)?.icon
                iconCache[pidValue] = icon
            }

            result.append(WindowInfo(windowID: windowID,
                                     pid: pidValue,
                                     appName: appName,
                                     title: title,
                                     frame: bounds,
                                     appIcon: icon))
        }

        return result
    }
}
