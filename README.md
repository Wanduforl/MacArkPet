# MacArkPet

MacArkPet is an unofficial native macOS desktop pet app for browsing and running
Ark-style Spine models as small interactive desktop characters.

It is inspired by Ark-Pets, but the macOS runtime is native Swift/AppKit/SwiftUI.

## Project Statement

MacArkPet borrows ideas from and is inspired by isHarryh's original Windows
[Ark-Pets](https://github.com/isHarryh/Ark-Pets), especially its desktop-pet
experience and model ecosystem. This macOS version exists so more Arknights
fans who only have a Mac, and do not have a Windows machine, can also enjoy a
small operator desktop pet.

This project is for learning, community sharing, and non-commercial personal
use only. Commercial use is prohibited. Do not sell, paywall, monetize with
ads, bundle with commercial software, or otherwise commercially use this
project, packaged builds, model resources, or modified versions of this project.

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
are not owned by this project. If you publish forks, builds, or releases, do not
bundle copyrighted game assets unless you have permission.

MacArkPet is an unofficial fan-made project. It is not affiliated with,
endorsed by, or maintained by Hypergryph, Yostar, the Ark-Pets maintainers, or
the Ark-Models maintainers.

Spine runtime code is included under its own license. See
`Resources/spine-ts-LICENSE` and `NOTICE.md`.

## Requirements

- macOS 13 or later
- Xcode command line tools or Xcode with Swift 5.9+

## Run From Source

```bash
git clone https://github.com/YOUR_NAME/MacArkPet.git
cd MacArkPet
./script/build_and_run.sh
```

The first launch may show an empty or partial model list until you click
`Sync Models`.

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
```

## License

MacArkPet source code is released under the MacArkPet Non-Commercial License.
It is source-available for non-commercial use only. Third-party runtime code and
model resources remain under their respective licenses and terms.
