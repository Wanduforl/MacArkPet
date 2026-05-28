# MacArkPet

MacArkPet is an unofficial native macOS desktop pet app for browsing and running
Ark-style Spine models as small interactive desktop characters.

It is inspired by Ark-Pets, but the macOS runtime is native Swift/AppKit/SwiftUI.
This repository is released under GNU GPL v3.0 to preserve license
compatibility with the upstream Ark-Pets project.

## Project Statement

MacArkPet borrows ideas from and is inspired by isHarryh's original Windows
[Ark-Pets](https://github.com/isHarryh/Ark-Pets), especially its desktop-pet
experience and model ecosystem. This macOS version exists so more Arknights
fans who only have a Mac, and do not have a Windows machine, can also enjoy a
small operator desktop pet.

The upstream Ark-Pets project is licensed under GPL-3.0. In accordance with
that license, MacArkPet preserves the original project attribution and is
released under the same GNU GPL v3.0 license.

## Features

- Native macOS launcher window with search, filters, preview, size, and speed controls
- Transparent borderless desktop pet window
- Spine/WebGL model rendering through `WKWebView`
- Walking, sitting, sleeping, interaction, and special-action states
- Basic gravity and support surfaces for the desktop, Dock area, and window tops
- Menu bar controls for launcher, click-through, always-on-top, reset position, and quit
- Model sync from the community Ark-Models repository

## Important Legal Note

This repository does not include Arknights game assets or model packages.

MacArkPet can download community model resources at runtime, but those resources
are not owned by this project. The Ark-Models README states that those materials
belong to Shanghai Hypergryph Network Technology Co., Ltd. and must not be used
commercially or in a way that harms the rights holder's interests.

If you publish forks, builds, or releases, do not bundle downloaded game/model
assets unless you have permission from the relevant rights holders.

MacArkPet is an unofficial fan-made project. It is not affiliated with,
endorsed by, or maintained by Hypergryph, Yostar, the Ark-Pets maintainers, or
the Ark-Models maintainers.

Spine runtime code is included under its own license. See
`Resources/spine-ts-LICENSE`, `NOTICE.md`, `THIRD_PARTY_NOTICES.md`, and
`docs/LEGAL.md`.

## Requirements

- macOS 13 or later
- Xcode command line tools or Xcode with Swift 5.9+

## Player Guide

Download the app from GitHub Releases, unzip it, and move `MacArkPet.app` to
`Applications`.

If macOS says Apple cannot check the app for malicious software, see the
English [User Guide](docs/USAGE.md). It also explains how to use `Sync Models`,
the bottom progress indicator, and the model library location:

```text
~/Library/Application Support/MacArkPet/ArkModels
```

## Run From Source

```bash
git clone https://github.com/Wanduforl/MacArkPet.git
cd MacArkPet
./script/build_and_run.sh
```

The first launch may show an empty or partial model list until you click
`Sync Models`. During sync, the launcher footer shows a circular progress
indicator with the percentage, current stage, and save location.

For local development with an existing Ark-Pets checkout, you may point the app
at local assets:

```bash
ARK_PETS_ASSETS=/path/to/Ark-Pets/assets ./script/build_and_run.sh
```

## Build A Release Zip

```bash
./script/package_release.sh
```

The zip will be created under `release/`, for example:

```text
release/MacArkPet-0.1.0-macOS.zip
```

By default the app is ad-hoc signed, not notarized. Players may need to right
click the app and choose `Open` the first time. For public distribution without
Gatekeeper friction, sign with a Developer ID certificate and notarize:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/package_release.sh
```

## GitHub Release Flow

This repository includes GitHub Actions:

- `CI` builds the Swift package on macOS.
- `Release` runs on tags like `v0.1.0` and uploads the packaged zip to the GitHub Release.

Create a release tag:

```bash
git tag v0.1.0
git push origin main --tags
```

## Controls

- Left drag: move the desktop pet
- Right click the pet or click the `AP` menu bar item: open the control menu
- `Click Through`: let mouse clicks pass through the pet window
- `Reset Position`: recover the pet if it is off-screen

## Project Layout

```text
Sources/MacArkPet/     Swift app source
Resources/             App icon and Spine runtime
script/                Build and release scripts
docs/                  Usage and legal/distribution notes
```

## License

MacArkPet source code is released under the GNU General Public License v3.0.
See [LICENSE](LICENSE).

Third-party runtime code and model resources remain under their respective
licenses and terms. This repository does not grant rights to Arknights game
assets or community model resources downloaded at runtime.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and
[docs/LEGAL.md](docs/LEGAL.md) before redistributing builds.
