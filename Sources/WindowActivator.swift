import AppKit
import ApplicationServices
import Darwin

/// Raises a specific window and brings its app to the front.
enum WindowActivator {

    // Private HIServices symbol: maps an AXUIElement back to its CGWindowID.
    // This is how we tell three windows of the same app apart.
    private typealias GetWindowFn =
        @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private static let getWindowID: GetWindowFn? = {
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        guard let sym = dlsym(RTLD_DEFAULT, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(sym, to: GetWindowFn.self)
    }()

    static func activate(_ info: WindowInfo) {
        let axApp = AXUIElementCreateApplication(info.pid)

        if let window = findWindow(axApp: axApp, info: info) {
            // Un-minimize if needed.
            var minimizedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
               (minimizedRef as? Bool) == true {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }

            // Focus THIS window and raise it *before* activating the app. Raising a
            // specific window that lives on another Space is what makes macOS switch
            // to that Space when the app is then activated.
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }

        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        // Plain activate (NOT .activateAllWindows — that would pull a current-Space
        // window forward and cancel the cross-Space switch to the raised window).
        let app = NSRunningApplication(processIdentifier: info.pid)
        if #available(macOS 14.0, *) {
            app?.activate()
        } else {
            app?.activate(options: [])
        }
    }

    private static func findWindow(axApp: AXUIElement, info: WindowInfo) -> AXUIElement? {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return nil }

        // Preferred: exact CGWindowID match.
        if let fn = getWindowID {
            for window in windows {
                var id: CGWindowID = 0
                if fn(window, &id) == .success, id == info.windowID { return window }
            }
        }

        // Fallback: match by title, then by frame origin, else first window.
        if !info.title.isEmpty {
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String, title == info.title {
                    return window
                }
            }
        }
        for window in windows {
            var posRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
               let posValue = posRef {
                var point = CGPoint.zero
                AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
                if abs(point.x - info.frame.origin.x) < 4 && abs(point.y - info.frame.origin.y) < 4 {
                    return window
                }
            }
        }
        return windows.first
    }
}
