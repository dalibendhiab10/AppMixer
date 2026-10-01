import AppKit
import Darwin

/// System Audio Recording permission (TCC service `kTCCServiceAudioCapture`), required for process taps.
/// macOS has no public API to query or request it, so this uses the TCC framework's symbols.
enum AudioPermission {
    enum Status { case granted, denied, notDetermined }

    private typealias Preflight = @convention(c) (CFString, CFDictionary?) -> Int
    private typealias Request = @convention(c) (CFString, CFDictionary?, @escaping @convention(block) (Bool) -> Void) -> Void

    private static let service = "kTCCServiceAudioCapture" as CFString
    private static let handle = dlopen("/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)

    static var status: Status {
        guard let handle, let sym = dlsym(handle, "TCCAccessPreflight") else { return .notDetermined }
        let preflight = unsafeBitCast(sym, to: Preflight.self)
        switch preflight(service, nil) {
        case 0: return .granted
        case 1: return .denied
        default: return .notDetermined
        }
    }

    static var isGranted: Bool { status == .granted }

    /// Shows the system permission prompt (only appears while the status is "not determined").
    static func request(_ completion: @escaping (Bool) -> Void = { _ in }) {
        guard let handle, let sym = dlsym(handle, "TCCAccessRequest") else { return }
        let request = unsafeBitCast(sym, to: Request.self)
        request(service, nil) { granted in DispatchQueue.main.async { completion(granted) } }
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
