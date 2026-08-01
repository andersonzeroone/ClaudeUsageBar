import Foundation

/// The app's display language — independent of the macOS system language,
/// so it can be switched from the menu regardless of how the Mac itself is
/// configured. Persisted in `UserDefaults`; falls back to the system
/// language on first launch.
enum AppLanguage: String, CaseIterable {
    case en
    case ptBR = "pt-BR"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ptBR: return "Português (BR)"
        }
    }

    private static let defaultsKey = "ClaudeUsageBar.language"

    static var current: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: defaultsKey),
               let saved = AppLanguage(rawValue: raw) {
                return saved
            }
            return systemDefault
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    private static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("pt") ? .ptBR : .en
    }
}
