import Foundation

enum Language: String, CaseIterable, Identifiable {
    case en, fr, ar
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .ar: return "العربية"
        }
    }
    var isRTL: Bool { self == .ar }
}

enum L10n {
    private static let table: [String: [Language: String]] = [
        "hello": [.en: "Hello", .fr: "Bonjour", .ar: "مرحباً"],
        "general": [.en: "General", .fr: "Général", .ar: "عام"],
        "apps": [.en: "Apps", .fr: "Applications", .ar: "التطبيقات"],
        "language": [.en: "Language", .fr: "Langue", .ar: "اللغة"],
        "openAtLogin": [.en: "Open at login", .fr: "Ouvrir à la connexion", .ar: "فتح عند تسجيل الدخول"],
        "appsShown": [.en: "Apps shown in the menu", .fr: "Applications affichées dans le menu", .ar: "التطبيقات الظاهرة في القائمة"],
        "search": [.en: "Search apps", .fr: "Rechercher des applications", .ar: "ابحث عن التطبيقات"],
        "reset": [.en: "Reset", .fr: "Réinitialiser", .ar: "إعادة ضبط"],
        "close": [.en: "Close", .fr: "Fermer", .ar: "إغلاق"],
        "save": [.en: "Save", .fr: "Enregistrer", .ar: "حفظ"],
        "prefsTitle": [.en: "App Mixer Preferences", .fr: "Préférences d'App Mixer", .ar: "تفضيلات App Mixer"],
        "noApps": [.en: "No apps with audio yet", .fr: "Aucune application audio pour le moment", .ar: "لا توجد تطبيقات صوتية بعد"],
        "moreApps": [.en: "More Apps", .fr: "Plus d'applications", .ar: "المزيد من التطبيقات"],
        "outputDevice": [.en: "Output Device", .fr: "Périphérique de sortie", .ar: "جهاز الإخراج"],
        "preferences": [.en: "Preferences…", .fr: "Préférences…", .ar: "التفضيلات…"],
        "quit": [.en: "Quit App Mixer", .fr: "Quitter App Mixer", .ar: "إنهاء App Mixer"],
        "output": [.en: "Output", .fr: "Sortie", .ar: "الإخراج"],
    ]

    static func t(_ key: String, _ lang: Language) -> String {
        table[key]?[lang] ?? table[key]?[.en] ?? key
    }
}
