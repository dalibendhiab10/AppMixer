import SwiftUI
import AppKit

@main
struct AppMixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let mixer = Mixer()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Without a saved position macOS may place the item left of the notch, where it is hidden.
        let posKey = "NSStatusItem Preferred Position AppMixerStatusItem"
        if UserDefaults.standard.object(forKey: posKey) == nil { UserDefaults.standard.set(200.0, forKey: posKey) }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "AppMixerStatusItem"
        item.isVisible = true
        let custom = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
        let image = custom ?? NSImage(systemSymbolName: "slider.vertical.3", accessibilityDescription: "Mixer")
        custom?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = custom == nil
        item.button?.image = image
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MixerView(openPreferences: { [weak self] in self?.openPreferences() }).environmentObject(mixer))

        // Developer flags used to capture README screenshots without clicking.
        let args = CommandLine.arguments
        if args.contains("--show-popover") {
            popover.behavior = .applicationDefined
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.togglePopover() }
        }
        if args.contains("--show-preferences") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.openPreferences() }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private var preferencesWindow: NSWindow?

    private func openPreferences() {
        popover.performClose(nil)
        if preferencesWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(
                rootView: PreferencesView(onClose: { [weak self] in self?.preferencesWindow?.close() }).environmentObject(mixer)))
            window.title = mixer.t("prefsTitle")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.title = mixer.t("prefsTitle")
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
}
