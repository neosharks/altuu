import Foundation

func testSettings() {
    T.suite("Settings — persisted window scope")
    let s = Settings.shared

    let original = s.showAllSpaces

    s.showAllSpaces = true
    T.eq(s.showAllSpaces, true, "showAllSpaces persists true")

    s.showAllSpaces = false
    T.eq(s.showAllSpaces, false, "showAllSpaces persists false")

    // Round-trips through UserDefaults (fresh read).
    s.showAllSpaces = true
    T.eq(UserDefaults.standard.bool(forKey: "AltuuShowAllSpaces"), true,
         "value is written to UserDefaults under the expected key")

    s.showAllSpaces = original   // restore
}
