# MacArkPet User Guide

This guide is for players who download the packaged macOS app from GitHub
Releases.

## Download And Install

1. Open the latest MacArkPet release on GitHub.
2. Download the latest `MacArkPet-<version>-macOS.zip` file.
3. Unzip it.
4. Move `MacArkPet.app` to your `Applications` folder.
5. Double-click `MacArkPet.app`.

MacArkPet is currently ad-hoc signed and not notarized by Apple. This means
macOS may block the first launch even when the file was downloaded correctly.

## If macOS Says "Apple cannot check it for malicious software"

You may see an alert like:

```text
Apple cannot check "MacArkPet" for malicious software.
```

Do not click `Move to Trash` unless you want to delete the app. To allow the
app manually:

1. Click `Done` in the warning dialog.
2. Open `System Settings`.
3. Go to `Privacy & Security`.
4. Scroll down to the `Security` section.
5. Find the message about `MacArkPet` being blocked.
6. Click `Open Anyway`.
7. Confirm by clicking `Open` or `Open Anyway`.
8. Enter your Mac password or use Touch ID if macOS asks.

After this, macOS saves MacArkPet as an exception and you can open it normally
by double-clicking the app.

If you do not see `Open Anyway`, try opening `MacArkPet.app` once more, click
`Done`, then return to `System Settings -> Privacy & Security`. The button is
usually available only for a limited time after you attempt to open the app.

Apple's official explanation of this flow is here:
<https://support.apple.com/en-us/102445>

### Advanced Fallback

Only use this if you downloaded the app from the official release page and you
trust the build:

```bash
xattr -dr com.apple.quarantine /Applications/MacArkPet.app
open /Applications/MacArkPet.app
```

## Download Models

MacArkPet does not include Arknights game assets or model files in the app
bundle. Models are downloaded separately at runtime.

1. Open `MacArkPet`.
2. In the launcher window, click `Sync Models`.
3. Wait for the sync to finish.

While syncing, the bottom of the launcher shows a circular progress indicator
with:

- download percentage
- current stage, such as preparing, downloading, unpacking, or installing
- the model library save location

The default model library location is:

```text
~/Library/Application Support/MacArkPet/ArkModels
```

When sync completes, the model list will reload automatically.

## Choose And Launch A Character

1. Use the search box to search by name, outfit, skin, or model ID.
2. Use the model type filter to switch between local models, operators,
   dynamic illustrations, and enemies.
3. Use the tag filter to narrow the list further.
4. Select a model in the sidebar.
5. Check the preview and details on the right.
6. Adjust `Size` and `Speed` if needed.
7. Click `Launch Full Character`.

The desktop pet can be controlled from the menu bar item or by right-clicking
the pet.

## Where Models Are Stored

Downloaded models are stored here:

```text
~/Library/Application Support/MacArkPet/ArkModels
```

To open that folder in Finder:

```bash
open "$HOME/Library/Application Support/MacArkPet/ArkModels"
```

To reset the downloaded model library, quit MacArkPet and remove that folder.
Then open MacArkPet again and click `Sync Models`.

## If Model Sync Fails

Try these checks:

- Make sure your network can access GitHub.
- Click `Sync Models` again after a short wait.
- Check that your Mac has enough free disk space.
- If the model list looks stale, quit MacArkPet, delete the model library
  folder, reopen MacArkPet, and sync again.

## Notes About Assets

MacArkPet is an unofficial fan-made macOS app. It does not bundle Arknights
assets. The in-app sync feature downloads community model resources at runtime,
and those resources are not owned by this project. Please follow the terms of
the original rights holders and upstream resource projects.
