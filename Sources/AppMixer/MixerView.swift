import SwiftUI

struct MixerView: View {
    @EnvironmentObject var mixer: Mixer
    var openPreferences: () -> Void = {}
    private let visibleApps = 5

    private var outputName: String {
        mixer.outputs.first { $0.id == mixer.currentOutput }?.name ?? mixer.t("output")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // General volume
            VStack(alignment: .leading, spacing: 2) {
                Text(outputName).font(.headline).lineLimit(1)
                Slider(value: Binding(get: { Double(mixer.master) }, set: { mixer.master = Float($0) }), in: 0...1)
            }
            Divider()

            // Apps
            Text(mixer.t("apps")).font(.subheadline).foregroundStyle(.secondary)
            if mixer.apps.isEmpty {
                Text(mixer.t("noApps")).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                ForEach(mixer.apps.prefix(visibleApps)) { AppRow(app: $0) }
                
            }
            Divider()
            // Output device
            Text(mixer.t("outputDevice")).font(.subheadline).foregroundStyle(.secondary)
            ForEach(mixer.outputs) { device in
                Button { mixer.selectOutput(device) } label: {
                    HStack {
                        Image(systemName: "checkmark").opacity(device.id == mixer.currentOutput ? 1 : 0).frame(width: 16)
                        Text(device.name).lineLimit(1)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider()

            Button(mixer.t("preferences"), action: openPreferences).buttonStyle(.plain)
            Button(mixer.t("quit")) { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 320)
        .environment(\.layoutDirection, mixer.language.isRTL ? .rightToLeft : .leftToRight)
        .onAppear { mixer.syncMaster(); mixer.refresh() }
    }
}

struct AppRow: View {
    @EnvironmentObject var mixer: Mixer
    let app: AppEntry

    var body: some View {
        let muted = mixer.isMuted(app)
        let vol = muted ? 0 : mixer.volume(for: app)
        HStack(spacing: 8) {
            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
            Text(app.name).lineLimit(1).frame(width: 90, alignment: .leading)
            if app.isPlaying { Circle().fill(.green).frame(width: 6, height: 6) }
            Slider(value: Binding(get: { Double(vol) }, set: { mixer.setVolume(Float($0), for: app) }), in: 0...1)
            Button { mixer.toggleMute(app) } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2")
            }
            .buttonStyle(.borderless)
            .frame(width: 22)
        }
    }
}
