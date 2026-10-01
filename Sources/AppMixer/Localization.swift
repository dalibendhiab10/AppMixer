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
        "welcomeTitle": [.en: "Welcome to AppMixer", .fr: "Bienvenue dans AppMixer", .ar: "مرحباً بك في AppMixer"],
        "welcomeBody": [.en: "AppMixer lets you control the volume of each app separately. To do that, macOS needs your permission.", .fr: "AppMixer vous permet de régler le volume de chaque application séparément. Pour cela, macOS a besoin de votre autorisation.", .ar: "يتيح لك AppMixer التحكم في مستوى صوت كل تطبيق على حدة. لذلك يحتاج macOS إلى إذنك."],
        "permName": [.en: "System Audio Recording", .fr: "Enregistrement audio du système", .ar: "تسجيل صوت النظام"],
        "permGranted": [.en: "Permission granted. You're all set.", .fr: "Autorisation accordée. Tout est prêt.", .ar: "تم منح الإذن. كل شيء جاهز."],
        "permDenied": [.en: "Permission denied. Enable it in System Settings.", .fr: "Autorisation refusée. Activez-la dans Réglages Système.", .ar: "تم رفض الإذن. فعّله من إعدادات النظام."],
        "permNeeded": [.en: "Permission needed so AppMixer can adjust each app's volume.", .fr: "Autorisation requise pour que AppMixer règle le volume de chaque application.", .ar: "الإذن مطلوب ليتمكن AppMixer من ضبط صوت كل تطبيق."],
        "privacyNote": [.en: "Audio is processed on your Mac only. It is never recorded, saved or sent anywhere.", .fr: "L'audio est traité uniquement sur votre Mac. Il n'est jamais enregistré, sauvegardé ni envoyé.", .ar: "تتم معالجة الصوت على جهازك فقط. لا يتم تسجيله أو حفظه أو إرساله."],
        "deniedHelp": [.en: "Open System Settings → Privacy & Security → Screen & System Audio Recording and turn AppMixer on.", .fr: "Ouvrez Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran et de l'audio système, puis activez AppMixer.", .ar: "افتح إعدادات النظام ← الخصوصية والأمان ← تسجيل الشاشة وصوت النظام وفعّل AppMixer."],
        "openSettings": [.en: "Open System Settings", .fr: "Ouvrir Réglages Système", .ar: "فتح إعدادات النظام"],
        "grant": [.en: "Grant Permission", .fr: "Accorder l'autorisation", .ar: "منح الإذن"],
        "later": [.en: "Later", .fr: "Plus tard", .ar: "لاحقاً"],
        "getStarted": [.en: "Get Started", .fr: "Commencer", .ar: "ابدأ"],
        "permBanner": [.en: "Permission needed to adjust app volumes", .fr: "Autorisation requise pour régler les volumes", .ar: "الإذن مطلوب لضبط مستوى الصوت"],
        "fix": [.en: "Fix", .fr: "Corriger", .ar: "إصلاح"],
        "output": [.en: "Output", .fr: "Sortie", .ar: "الإخراج"],
    ]

    static func t(_ key: String, _ lang: Language) -> String {
        table[key]?[lang] ?? table[key]?[.en] ?? key
    }
}
