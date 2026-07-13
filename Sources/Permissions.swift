import ApplicationServices
import CoreGraphics

/// Thin wrappers over the two TCC permissions this app needs:
/// Accessibility (event tap + window raising) and Screen Recording (previews + titles).
enum Permissions {

    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func hasAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func ensureScreenRecording() -> Bool {
        // Prompts on first call if not yet granted.
        CGRequestScreenCaptureAccess()
    }

    static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}
