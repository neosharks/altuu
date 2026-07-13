import AppKit
import ScreenCaptureKit

/// Caches the (slow) SCShareableContent query and refreshes it in the
/// background, so opening the switcher never pays the cold-query cost.
@available(macOS 14.0, *)
actor SCContentCache {
    static let shared = SCContentCache()

    private var content: SCShareableContent?
    private var lastFetch: Date = .distantPast
    private var inFlight: Task<SCShareableContent?, Never>?

    /// Returns cached content if younger than `maxAge`, else fetches fresh.
    /// Concurrent callers share a single in-flight fetch.
    func current(maxAge: TimeInterval) async -> SCShareableContent? {
        if let content, Date().timeIntervalSince(lastFetch) < maxAge {
            return content
        }
        if let inFlight { return await inFlight.value }

        let task = Task { () -> SCShareableContent? in
            // onScreenWindowsOnly:false so previews also cover windows on other Spaces.
            try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        }
        inFlight = task
        let result = await task.value
        if let result {
            content = result
            lastFetch = Date()
        }
        inFlight = nil
        return result
    }
}

/// Captures a still preview of each window via ScreenCaptureKit and reports
/// each one back on the main thread as soon as it is ready.
@available(macOS 14.0, *)
enum ThumbnailCapturer {

    // Retina cells top out ~340pt wide -> 680px; 600 is plenty and faster to encode.
    private static let maxDimension: CGFloat = 600

    /// Warm the shareable-content cache (call at launch and on Option-down).
    static func prewarm() {
        Task { _ = await SCContentCache.shared.current(maxAge: 1.0) }
    }

    static func capture(windows: [WindowInfo],
                        onEach: @escaping (CGWindowID, NSImage) -> Void) {
        let ids = windows.map { $0.windowID }
        guard !ids.isEmpty else { return }

        Task.detached {
            // Cache is usually warm from the Option-down prewarm, so this is instant.
            guard let content = await SCContentCache.shared.current(maxAge: 5.0) else { return }

            let byID = Dictionary(content.windows.map { ($0.windowID, $0) },
                                  uniquingKeysWith: { a, _ in a })

            await withTaskGroup(of: (CGWindowID, NSImage?).self) { group in
                for id in ids {
                    guard let scWindow = byID[id] else { continue }
                    group.addTask { (id, await shot(of: scWindow)) }
                }
                for await (id, image) in group {
                    guard let image = image else { continue }
                    await MainActor.run { onEach(id, image) }
                }
            }
        }
    }

    private static func shot(of window: SCWindow) async -> NSImage? {
        // Note: don't gate on window.isOnScreen — that skips occluded (behind
        // other) windows on the current Space too. ScreenCaptureKit composites
        // those fine; only genuinely empty captures are dropped below.
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()

        let w = max(window.frame.width, 1)
        let h = max(window.frame.height, 1)
        let scale = min(1, maxDimension / max(w, h))
        config.width = max(Int(w * scale), 32)
        config.height = max(Int(h * scale), 32)
        config.showsCursor = false

        guard let cg = try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config) else { return nil }
        guard !isBlank(cg) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    /// Cheap empty-frame detector: downsample to 1×1 and check it isn't fully
    /// transparent. Only transparency means "nothing rendered" — we deliberately
    /// do NOT treat dark frames as blank, or dark-themed apps (terminals, dark
    /// IDEs) would lose their previews.
    private static func isBlank(_ cg: CGImage) -> Bool {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1,
                                  bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel[3] < 8   // alpha ~0 → nothing was drawn
    }
}
