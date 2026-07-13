#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/build/AltuuTests"
mkdir -p "$ROOT/build"

SDK="$(xcrun --show-sdk-path)"

# Only the pure/logic sources the tests exercise (no UI / no main.swift).
LOGIC_SOURCES=(
    "$ROOT/Sources/WindowInfo.swift"
    "$ROOT/Sources/GridSolver.swift"
    "$ROOT/Sources/WindowEnumerator.swift"
    "$ROOT/Sources/Settings.swift"
)

echo "==> Compiling test runner"
swiftc \
    -sdk "$SDK" \
    -target arm64-apple-macos14.0 \
    -swift-version 5 \
    -framework AppKit \
    -framework CoreGraphics \
    -o "$OUT" \
    "${LOGIC_SOURCES[@]}" \
    "$ROOT"/Tests/*.swift

echo "==> Running tests"
"$OUT"
