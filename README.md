# Altuu (macOS)

A Windows-style window switcher for macOS, inspired by [alt-tab.app](https://alt-tab.app/).

Instead of macOS's app-level ⌘Tab, this switches between **individual windows** with
live previews. Three Terminal windows show up as three separate entries — pick the
exact one you want.

## Features

- **Per-window switching** — every window is its own entry (not grouped by app).
- **Live previews** — thumbnail of each window via ScreenCaptureKit, prewarmed on
  Option-down so previews are ready the instant the switcher opens.
- **Big tiles** — each tile carries the app icon + app name on top, the preview in
  the middle, the window title at the bottom. Tiles stay large; the grid grows into
  rows and only shrinks (to a floor) if it would overflow the screen.
- **Header** shows the highlighted window and position (e.g. `Terminal — zsh · 2/6`).
- **Windows-style keys**
  - `⌥ Option + Tab` — open switcher / step forward
  - `⌥ Option + ⇧ Shift + Tab` — step backward
  - `← ↑` / `→ ↓` — move selection while open
  - `Return` — switch to the highlighted window
  - release `⌥ Option` — switch to the highlighted window
  - `Esc` — cancel
- **Click to pick** — click any preview to jump straight to it.
- **Polished menu-bar agent** — live permission status with green/orange indicators,
  one-click links to the right Settings pane, and a Launch-at-Login toggle. No Dock icon.
- **Custom app icon**, fade-in animation, accent-colored selection.

## Build

```bash
# one-time: generate the app icon (writes build_assets/AppIcon.icns)
swiftc -O -framework AppKit tools/make_icon.swift -o tools/make_icon
mkdir -p tools/AppIcon.iconset
./tools/make_icon tools/AppIcon.iconset
iconutil -c icns tools/AppIcon.iconset -o build_assets/AppIcon.icns

# build + run
./build.sh
open build/Altuu.app
```

Requires the Swift toolchain from Xcode or Command Line Tools. No Xcode project needed.

## First-run permissions

The app needs two macOS permissions. It prompts on launch; grant both, then relaunch
if the hotkey doesn't respond yet. The menu-bar icon shows a green tick per permission
once granted.

1. **Accessibility** — System Settings → Privacy & Security → Accessibility
   (needed to capture the ⌥Tab hotkey and raise windows).
2. **Screen Recording** — System Settings → Privacy & Security → Screen Recording
   (needed for window previews and titles).

Both settings are reachable from the menu-bar icon.

## Stable signing (so permissions persist)

`build.sh` signs with a stable self-signed identity if the keychain
`~/.altuu-signing/signing.keychain-db` (identity `Altuu Dev`) exists — this
keeps the TCC grant valid across rebuilds. Without it, the app is ad-hoc signed and
you must re-grant Accessibility after each rebuild.

## Known limitations

- Shows windows on the **current Space** only.
- Fixed hotkey (⌥Tab); not yet configurable.

## Layout

| File | Responsibility |
|------|----------------|
| `WindowEnumerator.swift` | List on-screen windows (`CGWindowList`) |
| `ThumbnailCapturer.swift` | Per-window previews (ScreenCaptureKit), cached + prewarmed |
| `HotKeyManager.swift` | Global ⌥Tab / arrows / Return interception (`CGEventTap`) |
| `SwitcherPanel.swift` | Overlay UI: grid of previews + header + selection |
| `WindowActivator.swift` | Raise the chosen window (Accessibility API) |
| `AppDelegate.swift` | Wiring, permissions, menu bar, launch-at-login |
| `tools/make_icon.swift` | Generates `AppIcon.icns` |
