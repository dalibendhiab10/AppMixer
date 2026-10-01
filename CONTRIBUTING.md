# Contributing to AppMixer

Thanks for helping out! Bug reports, ideas and pull requests are all welcome.

## Getting set up

Requirements: macOS 14.2+ and the Swift toolchain (Xcode or the Command Line Tools).

```sh
git clone https://github.com/dalibendhiab10/AppMixer.git
cd AppMixer
./build.sh          # builds AppMixer.app in the project folder
open AppMixer.app
```

The app needs the **audio capture** permission the first time you lower an app's volume.

Handy developer flags (used for the README screenshots):

```sh
./AppMixer.app/Contents/MacOS/AppMixer --show-popover
./AppMixer.app/Contents/MacOS/AppMixer --show-preferences [--pane-apps]
```

## Project layout

| Path | What it does |
|---|---|
| `Sources/AppMixer/AppTap.swift` | Core Audio process tap + aggregate device that scales one app's audio |
| `Sources/AppMixer/Mixer.swift` | App discovery, volumes, output device switching, persistence |
| `Sources/AppMixer/CoreAudioHelpers.swift` | Thin wrappers over Core Audio property APIs |
| `Sources/AppMixer/MixerView.swift` | The menu bar dropdown |
| `Sources/AppMixer/PreferencesView.swift` | Preferences window |
| `Sources/AppMixer/Localization.swift` | UI strings (English, French, Arabic) |
| `scripts/make-pkg.sh` | Builds the installer package used by the release pipeline |

## Workflow

1. Fork the repo and create a branch from `main` (`feat/my-change`, `fix/some-bug`).
2. Make your change. Keep it focused and match the surrounding code style.
3. Make sure `swift build -c release` passes and try the app by hand (there is no automated audio test).
4. Open a pull request against `main`. The `Build` check must pass.

`main` is protected: changes land through pull requests.

## Commit messages (they decide the version number)

Every push to `main` publishes a release, and the version is bumped from the commit messages using
[Conventional Commits](https://www.conventionalcommits.org/):

| Message | Version bump |
|---|---|
| `fix: stop volume resetting after output switch` | patch (1.0.0 → 1.0.1) |
| `feat: add keyboard shortcut` | minor (1.0.0 → 1.1.0) |
| `feat!: change settings format` or a `BREAKING CHANGE:` footer | major (1.0.0 → 2.0.0) |
| `docs:`, `chore:`, `refactor:` … | patch |

The commit subjects become the release notes, so write them for users.

## Adding a language

Add a case to `Language` and a translation for each key in `L10n.table` in `Localization.swift`.

## Reporting bugs

Please include your macOS version, the output device (built-in, AirPods, …), the app whose volume misbehaves, and
what you expected to happen.

## License

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
