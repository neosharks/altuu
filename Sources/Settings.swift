import Foundation

/// Small persisted settings store (UserDefaults).
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard
    private let allSpacesKey = "AltuuShowAllSpaces"

    /// false → only windows on the current desktop/Space (default).
    /// true  → windows across all desktops/Spaces.
    var showAllSpaces: Bool {
        get { defaults.bool(forKey: allSpacesKey) }
        set { defaults.set(newValue, forKey: allSpacesKey) }
    }
}
