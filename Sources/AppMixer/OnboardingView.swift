import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var mixer: Mixer
    var onDone: () -> Void

    @State private var status = AudioPermission.status
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private func t(_ key: String) -> String { mixer.t(key) }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 84, height: 84)
            Text(t("welcomeTitle")).font(.title.bold())
            Text(t("welcomeBody")).multilineTextAlignment(.center).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: status == .granted ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(status == .granted ? .green : .secondary).font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("permName")).font(.headline)
                        Text(t(status == .granted ? "permGranted" : status == .denied ? "permDenied" : "permNeeded"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text(t("privacyNote")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            if status == .denied {
                Text(t("deniedHelp")).font(.callout).multilineTextAlignment(.center)
                Button(t("openSettings")) { AudioPermission.openSystemSettings() }.buttonStyle(.borderedProminent)
            } else if status == .notDetermined {
                Button(t("grant")) {
                    AudioPermission.request { _ in status = AudioPermission.status }
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }

            HStack {
                Button(t("later"), action: onDone)
                Spacer()
                Button(t("getStarted"), action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .disabled(status != .granted)
            }
        }
        .padding(28)
        .frame(width: 460)
        .environment(\.layoutDirection, mixer.language.isRTL ? .rightToLeft : .leftToRight)
        .onReceive(timer) { _ in status = AudioPermission.status }
    }
}
