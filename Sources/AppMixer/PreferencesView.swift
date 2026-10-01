import SwiftUI
import AppKit
import Collaboration
import ServiceManagement

private enum Pane: String, CaseIterable, Identifiable {
    case general, apps
    var id: String { rawValue }
    var icon: String { self == .general ? "gearshape" : "square.grid.2x2" }
}

struct PreferencesView: View {
    @EnvironmentObject var mixer: Mixer
    var onClose: () -> Void = {}

    @State private var pane: Pane = CommandLine.arguments.contains("--pane-apps") ? .apps : .general
    @State private var draftLanguage: Language = .en
    @State private var draftLaunchAtLogin = false
    @State private var draftHidden: Set<String> = []
    @State private var search = ""
    @State private var apps: [AppEntry] = []
    @State private var error: String?

    private let userName = NSFullUserName()
    private let userPhoto: NSImage? = CBIdentity(name: NSUserName(), authority: CBIdentityAuthority.default())?.image

    private var filtered: [AppEntry] {
        search.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                Group {
                    switch pane {
                    case .general: general
                    case .apps: appsPane
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                footer
            }
        }
        .frame(width: 680, height: 540)
        .environment(\.layoutDirection, draftLanguage.isRTL ? .rightToLeft : .leftToRight)
        .onAppear(perform: load)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 8) {
                Group {
                    if let userPhoto { Image(nsImage: userPhoto).resizable().scaledToFill() }
                    else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary) }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                Text("\(L10n.t("hello", draftLanguage)), \(userName)")
                    .font(.headline).multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            ForEach(Pane.allCases) { p in
                Button { pane = p } label: {
                    Label(L10n.t(p.rawValue, draftLanguage), systemImage: p.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(pane == p ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 200)
        .background(.quaternary.opacity(0.4))
    }

    // MARK: Panes

    private var general: some View {
        Form {
            Picker(L10n.t("language", draftLanguage), selection: $draftLanguage) {
                ForEach(Language.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle(L10n.t("openAtLogin", draftLanguage), isOn: $draftLaunchAtLogin)
                .toggleStyle(.switch)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var appsPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("appsShown", draftLanguage)).font(.headline)
            TextField(L10n.t("search", draftLanguage), text: $search).textFieldStyle(.roundedBorder)
            List(filtered) { app in
                Toggle(isOn: Binding(
                    get: { !draftHidden.contains(app.id) },
                    set: { if $0 { draftHidden.remove(app.id) } else { draftHidden.insert(app.id) } }
                )) {
                    HStack(spacing: 8) {
                        Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                        Text(app.name)
                    }
                }
                .toggleStyle(.switch)
            }
        }
        .padding(16)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(L10n.t("reset", draftLanguage), action: reset)
            Spacer()
            Button(L10n.t("close", draftLanguage), action: onClose)
            Button(L10n.t("save", draftLanguage), action: save).keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    // MARK: Actions

    private func load() {
        mixer.reloadInstalledApps()
        apps = mixer.preferenceApps
        draftLanguage = mixer.language
        draftHidden = mixer.hidden
        draftLaunchAtLogin = SMAppService.mainApp.status == .enabled
        error = nil
    }

    /// Restore defaults in the form (applied when Save is pressed).
    private func reset() {
        draftLanguage = .en
        draftHidden = []
        draftLaunchAtLogin = false
        search = ""
    }

    private func save() {
        do {
            let enabled = SMAppService.mainApp.status == .enabled
            if draftLaunchAtLogin != enabled {
                if draftLaunchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            }
        } catch {
            self.error = error.localizedDescription
            pane = .general
            return
        }
        mixer.applyPreferences(hidden: draftHidden, language: draftLanguage)
        onClose()
    }
}
