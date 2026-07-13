import Foundation

/// Minimal assert-based test harness — runs as a plain command-line executable,
/// so it works with just the Command Line Tools (no Xcode / XCTest bundle).
final class TestRunner {
    static let shared = TestRunner()
    private(set) var passed = 0
    private(set) var failed = 0
    private var failures: [String] = []

    func suite(_ name: String) { print("\n▶ \(name)") }

    func check(_ cond: Bool, _ msg: String,
               file: StaticString = #file, line: UInt = #line) {
        if cond {
            passed += 1
            print("  ✓ \(msg)")
        } else {
            failed += 1
            let f = "\(msg)  (\(file):\(line))"
            failures.append(f)
            print("  ✗ FAIL: \(f)")
        }
    }

    func eq<T: Equatable>(_ a: T, _ b: T, _ msg: String,
                          file: StaticString = #file, line: UInt = #line) {
        check(a == b, "\(msg) — got \(a), expected \(b)", file: file, line: line)
    }

    func approx(_ a: CGFloat, _ b: CGFloat, _ msg: String, eps: CGFloat = 0.5,
                file: StaticString = #file, line: UInt = #line) {
        check(abs(a - b) <= eps, "\(msg) — got \(a), expected ≈\(b)", file: file, line: line)
    }

    func finish() -> Never {
        print("\n──────────────────────────────")
        print("PASSED \(passed)   FAILED \(failed)")
        if failed > 0 {
            print("\nFailures:")
            failures.forEach { print("  • \($0)") }
        }
        exit(failed == 0 ? 0 : 1)
    }
}

let T = TestRunner.shared
