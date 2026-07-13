import AppKit

/// One switchable window. Reference type so thumbnails can be filled in
/// asynchronously after the switcher is already on screen.
final class WindowInfo {
    let windowID: CGWindowID
    let pid: pid_t
    let appName: String
    var title: String
    let frame: CGRect          // CoreGraphics screen coords (top-left origin)
    let appIcon: NSImage?
    var thumbnail: NSImage?

    init(windowID: CGWindowID,
         pid: pid_t,
         appName: String,
         title: String,
         frame: CGRect,
         appIcon: NSImage?) {
        self.windowID = windowID
        self.pid = pid
        self.appName = appName
        self.title = title
        self.frame = frame
        self.appIcon = appIcon
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? appName : t
    }
}
