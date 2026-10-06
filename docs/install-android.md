# Installing Bus Simulator on an Android phone

The game is distributed as an APK file attached to each
[GitHub Release](https://github.com/Umer-Iftikhar/bus-simulator/releases).
It is not on the Play Store, so you install it directly ("sideloading").

## Requirements

* Android 7.0 or newer, 64-bit (arm64) phone — practically every phone from 2017 onward.
* About 100 MB of free space.
* No internet is needed to play; the game is fully offline.

## Option A — download straight to the phone

1. **Open the Releases page on your phone.**
   In your phone's browser (e.g. Chrome) open
   <https://github.com/Umer-Iftikhar/bus-simulator/releases/latest>.
   No GitHub account or sign-in is needed.
2. **Download the APK.** Under **Assets**, tap
   `bus-simulator-<version>-debug.apk`. If Chrome warns that the file may be
   harmful, tap **Download anyway**.
3. **Allow installs from your browser (one time only).** Open the downloaded file
   (from the download notification or the **Files / Downloads** app). Android will
   say installing unknown apps is blocked: tap **Settings**, turn on
   **Allow from this source**, then go back.
   (Exact wording varies by brand: *Install unknown apps*, *Unknown sources*.)
4. **Install.** Tap **Install**. If Google Play Protect shows *"Unsafe app
   blocked"* or *"App scan recommended"*, tap **More details → Install anyway**.
   This appears because the build is not from the Play Store, not because
   anything is wrong with it.
5. **Play.** Tap **Open**, or find **Bus Simulator** in your app drawer. The game
   runs in landscape; rotate the phone sideways.

## Option B — download on a computer, then copy or install over USB

1. On the computer, download the APK from the
   [latest release](https://github.com/Umer-Iftikhar/bus-simulator/releases/latest).
2. Either:
   * **Copy the file** to the phone (USB cable in *File transfer* mode, Google
     Drive, etc.), open it on the phone with the Files app and follow steps 3–5
     above; **or**
   * **Install with ADB** (developer option): enable *Developer options →
     USB debugging* on the phone, connect it, and run

     ```bash
     adb install -r bus-simulator-0.1.0-debug.apk
     ```

## Updating to a new version

Install the new APK the same way. Your progress (money, buses, upgrades) is
stored on the phone and is kept when an update installs over the old version.

> **Note on current builds:** releases are currently *debug-signed*, and the CI
> signs each build with a fresh debug key. Android refuses to install an app
> over one signed with a different key ("App not installed" / "package
> conflicts"). If that happens, uninstall the old version first (this deletes
> your saved progress) and then install the new one. Once a permanent release
> keystore is added to the repository secrets (see the README), updates will
> install over the old version and keep your progress.

## Uninstalling

Long-press the **Bus Simulator** icon → **App info** → **Uninstall**, or
*Settings → Apps → Bus Simulator → Uninstall*.

## Troubleshooting

| Problem | Fix |
|---|---|
| The Releases page shows **404** | Check the link is exactly `github.com/Umer-Iftikhar/bus-simulator/releases/latest`. |
| **"App not installed"** | Uninstall the existing Bus Simulator first (see the note above), make sure you have free space, then try again. |
| **"There was a problem parsing the package"** | The download was incomplete — download the APK again. Also check the phone runs Android 7.0+ and is 64-bit. |
| Nothing happens when tapping the APK | Open it from the **Files** app instead of the browser, and check *Install unknown apps* is allowed for that app. |
| Game is slow / phone gets hot | In the main menu set **Mirrors: Battery saver**. |
