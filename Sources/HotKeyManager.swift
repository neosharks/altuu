import AppKit
import CoreGraphics

/// Global keyboard interception via a CGEventTap.
///
/// Behaviour (Windows Alt-Tab style):
///   • Option+Tab            → open switcher / step forward   (swallowed)
///   • Shift+Option+Tab      → step backward                  (swallowed)
///   • Arrows (while open)   → move selection                 (swallowed)
///   • Return (while open)   → commit selection               (swallowed)
///   • Escape (while open)   → cancel                         (swallowed)
///   • Release Option        → commit current selection
///
/// The tap runs on the main run loop, so callbacks fire on the main thread.
final class HotKeyManager {

    var onInvoke: ((_ backward: Bool) -> Void)?
    var onStep: ((_ backward: Bool) -> Void)?   // arrow keys while open
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onPrewarm: (() -> Void)?          // Option pressed, before Tab
    var isActive: () -> Bool = { false }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let tabKey: Int64 = 48
    private let escKey: Int64 = 53
    private let returnKey: Int64 = 36
    private let keypadEnter: Int64 = 76
    private let leftArrow: Int64 = 123
    private let rightArrow: Int64 = 124
    private let upArrow: Int64 = 126
    private let downArrow: Int64 = 125

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                HotKeyManager.handle(type: type, event: event, refcon: refcon)
            },
            userInfo: refcon
        ) else {
            NSLog("[Altuu] tapCreate FAILED — not trusted for Accessibility")
            return false   // not trusted for Accessibility yet
        }
        NSLog("[Altuu] event tap CREATED and enabled")

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    private static func handle(type: CGEventType,
                               event: CGEvent,
                               refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
        let pass = Unmanaged.passUnretained(event)

        // The system disables the tap on timeout; just re-arm it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = manager.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }

        let optionDown = event.flags.contains(.maskAlternate)

        switch type {
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == manager.tabKey && optionDown {
                manager.onInvoke?(event.flags.contains(.maskShift))
                return nil   // swallow: don't let Tab reach the focused app
            }
            // Remaining keys only act while the switcher is open.
            guard manager.isActive() else { break }
            switch keyCode {
            case manager.escKey:
                manager.onCancel?(); return nil
            case manager.returnKey, manager.keypadEnter:
                manager.onCommit?(); return nil
            case manager.leftArrow, manager.upArrow:
                manager.onStep?(true); return nil
            case manager.rightArrow, manager.downArrow:
                manager.onStep?(false); return nil
            default:
                break
            }
        case .flagsChanged:
            if optionDown && !manager.isActive() {
                manager.onPrewarm?()          // start warming previews while Tab is still coming
            }
            if !optionDown && manager.isActive() {
                manager.onCommit?()
            }
        default:
            break
        }

        return pass
    }
}
