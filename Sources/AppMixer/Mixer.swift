import AppKit
import CoreAudio
import Darwin
import SwiftUI

struct AppEntry: Identifiable {
    let id: String            // outermost .app path (or bundle id fallback)
    let name: String
    let icon: NSImage
    let processObjects: Set<AudioObjectID>
    let isPlaying: Bool
}

@MainActor
final class Mixer: ObservableObject {
    /// Every app currently known to Core Audio (before the user's visibility filter).
    @Published private(set) var allApps: [AppEntry] = []
    @Published private(set) var hidden: Set<String>
    @Published private(set) var language: Language
    @Published private(set) var permissionGranted = AudioPermission.isGranted
    /// Apps shown in the menu: playing first, then alphabetical.
    var apps: [AppEntry] { allApps.filter { !hidden.contains($0.id) } }
    @Published var master: Float = CA.masterVolume() ?? 1 {
        didSet { if !syncingMaster { CA.setMasterVolume(master) } }
    }
    @Published private(set) var outputs: [CA.OutputDevice] = []
    @Published private(set) var currentOutput: AudioObjectID = 0
    @Published private(set) var volumes: [String: Float]
    @Published private(set) var muted: Set<String>

    private var taps: [String: AppTap] = [:]
    private var lastPlaying: [String: Date] = [:]
    private var known: [String: String]   // id -> name, so Preferences can list apps that are not running
    private var timer: Timer?
    private var syncingMaster = false
    private var tapsPausedUntil = Date.distantPast
    private var outputListener: AudioObjectPropertyListenerBlock?
    private let defaults = UserDefaults.standard

    init() {
        volumes = (defaults.dictionary(forKey: "volumes") as? [String: Float]) ?? [:]
        muted = Set(defaults.stringArray(forKey: "muted") ?? [])
        hidden = Set(defaults.stringArray(forKey: "hidden") ?? [])
        language = Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .en
        known = (defaults.dictionary(forKey: "known") as? [String: String]) ?? [:]
        refresh()
        watchDefaultOutput()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// A tap keeps audio flowing to the old output device. On Bluetooth devices that makes macOS route
    /// back to it, so the moment the default output changes (from anywhere) every tap is torn down,
    /// and taps are only rebuilt after the route has been stable for a moment.
    private func watchDefaultOutput() {
        var addr = CA.address(kAudioHardwarePropertyDefaultOutputDevice)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    for id in Array(self.taps.keys) { self.removeTap(id) }
                    self.tapsPausedUntil = Date().addingTimeInterval(1.5)
                    self.refresh()
                }
            }
        }
        outputListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block)
    }

    func volume(for app: AppEntry) -> Float { volumes[app.id] ?? 1 }
    func isMuted(_ app: AppEntry) -> Bool { muted.contains(app.id) }

    func setVolume(_ v: Float, for app: AppEntry) {
        volumes[app.id] = v
        if v > 0 { muted.remove(app.id) }
        persist(); apply(app)
    }

    func toggleMute(_ app: AppEntry) {
        if muted.contains(app.id) { muted.remove(app.id) } else { muted.insert(app.id) }
        persist(); apply(app)
    }

    func selectOutput(_ device: CA.OutputDevice) {
        CA.setDefaultOutputDevice(device.id)
        refresh()
    }

    func applyPreferences(hidden newHidden: Set<String>, language newLanguage: Language) {
        hidden = newHidden
        language = newLanguage
        defaults.set(Array(newHidden), forKey: "hidden")
        defaults.set(newLanguage.rawValue, forKey: "language")
    }

    func t(_ key: String) -> String { L10n.t(key, language) }

    private var installed: [String: String] = [:]   // path -> name

    func reloadInstalledApps() {
        installed = Self.scanInstalledApps()
        refresh()
    }

    /// Every app on the Mac (installed, running, or seen before) for the Preferences list.
    var preferenceApps: [AppEntry] {
        var byName: [String: AppEntry] = [:]
        func add(_ id: String, _ name: String, _ objs: Set<AudioObjectID>, _ playing: Bool, icon: NSImage? = nil) {
            let key = name.lowercased()
            if let existing = byName[key], !existing.processObjects.isEmpty { return }   // prefer the running entry
            byName[key] = AppEntry(id: id, name: name, icon: icon ?? NSWorkspace.shared.icon(forFile: id),
                                   processObjects: objs, isPlaying: playing)
        }
        for (path, name) in installed { add(path, name, [], false) }
        for (path, name) in known where FileManager.default.fileExists(atPath: path) { add(path, name, [], false) }
        for app in allApps { add(app.id, app.name, app.processObjects, app.isPlaying, icon: app.icon) }
        return byName.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private static func scanInstalledApps() -> [String: String] {
        let roots = ["/Applications", "/System/Applications", "/Applications/Utilities", "/System/Applications/Utilities",
                     NSHomeDirectory() + "/Applications"]
        var result: [String: String] = [:]
        for root in roots {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
            for item in items where item.hasSuffix(".app") {
                let path = root + "/" + item
                result[path] = String(FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))
            }
        }
        return result
    }

    func syncMaster() {
        syncingMaster = true
        master = CA.masterVolume() ?? master
        syncingMaster = false
    }

    // MARK: - Internals

    private func persist() {
        defaults.set(volumes, forKey: "volumes")
        defaults.set(Array(muted), forKey: "muted")
    }

    private func effectiveGain(_ app: AppEntry) -> Float { isMuted(app) ? 0 : volume(for: app) }

    /// Create, update or remove the tap for an app so it matches the desired gain.
    /// At 100% no tap exists, so untouched apps play with zero added latency.
    private func apply(_ app: AppEntry) {
        let gain = effectiveGain(app)
        // Without the permission a tap would silence the app instead of scaling it.
        guard gain < 0.999, permissionGranted else { removeTap(app.id); return }
        guard Date() >= tapsPausedUntil else { return }   // output just changed; wait for the route to settle
        guard let uid = CA.defaultOutputDevice.flatMap(CA.deviceUID) else { return }

        if let tap = taps[app.id], tap.processObjects == app.processObjects, tap.outputUID == uid {
            tap.gain.target = gain
        } else {
            removeTap(app.id)
            if let tap = AppTap(processObjects: app.processObjects, outputUID: uid, gain: gain) {
                taps[app.id] = tap
            }
        }
    }

    private func removeTap(_ id: String) {
        taps.removeValue(forKey: id)?.stop()
    }

    func refresh() {
        permissionGranted = AudioPermission.isGranted
        outputs = CA.outputDevices()
        let previous = currentOutput
        currentOutput = CA.defaultOutputDevice ?? 0
        if currentOutput != previous { syncMaster() }
        // "Playing" is held for a few seconds so the order doesn't jump when audio briefly pauses (e.g. output switch).
        let now = Date()
        let entries = Self.scanApps().map { app -> AppEntry in
            if app.isPlaying { lastPlaying[app.id] = now }
            let sticky = lastPlaying[app.id].map { now.timeIntervalSince($0) < 5 } ?? false
            return AppEntry(id: app.id, name: app.name, icon: app.icon,
                            processObjects: app.processObjects, isPlaying: sticky)
        }
        .sorted { ($0.isPlaying ? 0 : 1, $0.name.lowercased(), $0.id) < ($1.isPlaying ? 0 : 1, $1.name.lowercased(), $1.id) }
        let newKnown = entries.reduce(into: known) { $0[$1.id] = $1.name }
        if newKnown != known { known = newKnown; defaults.set(known, forKey: "known") }
        allApps = entries
        for app in entries { apply(app) }
        let live = Set(entries.map(\.id))
        for id in taps.keys where !live.contains(id) { removeTap(id) }
    }

    private static func scanApps() -> [AppEntry] {
        let me = getpid()
        var groups: [String: (name: String, icon: NSImage, objs: Set<AudioObjectID>, playing: Bool)] = [:]

        for obj in CA.objectList(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList) {
            guard let pid = CA.get(obj, kAudioProcessPropertyPID, as: pid_t.self), pid != me else { continue }
            let playing = (CA.get(obj, kAudioProcessPropertyIsRunningOutput, as: UInt32.self) ?? 0) != 0

            let key: String
            let name: String
            let icon: NSImage
            if let path = appBundlePath(pid: pid), !path.hasPrefix("/System/Library"), !path.hasPrefix("/Library/Apple") {
                key = path
                name = FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
                icon = NSWorkspace.shared.icon(forFile: path)
            } else { continue }

            var g = groups[key] ?? (name, icon, [], false)
            g.objs.insert(obj)
            g.playing = g.playing || playing
            groups[key] = g
        }

        return groups
            .map { AppEntry(id: $0.key, name: $0.value.name, icon: $0.value.icon,
                            processObjects: $0.value.objs, isPlaying: $0.value.playing) }
    }

    /// Outermost `.app` bundle containing the executable of `pid` (resolves helper processes to their parent app).
    private static func appBundlePath(pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return nil }
        let path = String(cString: buf)
        guard let r = path.range(of: ".app/") else { return nil }
        return String(path[..<r.upperBound]).hasSuffix("/") ? String(path[..<r.upperBound].dropLast()) : String(path[..<r.upperBound])
    }
}
