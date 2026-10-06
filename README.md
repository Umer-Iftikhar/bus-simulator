# Bus Simulator

Offline 3D bus-driving simulator for Android, built with **Godot 4.4**.
Drive metro-style routes, carry passengers, earn fares, and spend them on bigger
buses, upgrades and paint jobs. Careless driving costs you in repairs.

The full design lives in [docs/game-design.md](docs/game-design.md).

| Driver's seat | Downtown | Pine Hills by night |
|---|---|---|
| ![Driver view](docs/screenshots/driver-view.png) | ![Downtown](docs/screenshots/downtown.png) | ![Night](docs/screenshots/night.png) |

## Install on your Android phone

1. On the phone, open the **[latest release](https://github.com/Umer-Iftikhar/bus-simulator/releases/latest)**
   in your browser (no GitHub account needed).
2. Under **Assets**, tap `bus-simulator-<version>-debug.apk` to download it.
3. Open the downloaded file. When asked, allow your browser / Files app to
   **install unknown apps**, then tap **Install** (if Play Protect warns, choose
   **More details → Install anyway**).
4. Open **Bus Simulator** and rotate the phone to landscape.

Requires Android 7.0+ on a 64-bit phone; no internet needed to play. Full guide
with USB/ADB install, updating and troubleshooting:
**[docs/install-android.md](docs/install-android.md)**.

## Features

* **Driving** — procedural `VehicleBody3D` buses with a realistic drivetrain
  (top-speed fade, brake-to-reverse, speed-sensitive steering), touch steering
  wheel + pedals, keyboard support, horn, chase / driver / top-down cameras.
* **Routes** — 4 hand-tuned maps (Harbor Loop, Desert Highway, Downtown,
  Pine Hills by Night), stops as `Area3D` triggers, metro-style passengers with
  fixed boarding and destination stops, fare paid at the end terminal.
* **Economy** — 5-bus ladder (capacity only comes from buying bigger buses),
  4 upgrade lines × 5 levels, paint jobs, optional repairs. Balance is checked
  by tests so there is always a next goal.
* **Traffic** — lane-locked AI cars using the Intelligent Driver Model; they
  queue behind the bus and **give way when you signal** a lane change.
* **Damage** — hittable parts (front/rear/left/right panels, left/right
  mirrors); top speed drops with health, 0 health = wrecked; dents show per panel.
* **Mirrors** — functional low-res SubViewport mirrors (left, right, rear) with
  a battery-saver refresh mode; smashed mirrors crack and stop rendering.
* **Look** — see-through bus with a full interior (dashboard, wheel, seats,
  upper deck), ACES tone mapping, soft shadows, haze, textured roads,
  procedural building facades with lit windows at night, street lights,
  broadleaf and pine trees, detailed traffic cars. All procedural: no image assets.
* **Save** — local JSON in `user://`, atomic writes, defensive loading.

## Controls

| Action | Touch | Keyboard |
|---|---|---|
| Steer | drag the wheel | A / D or ← / → |
| Accelerate / brake (hold brake to reverse) | GAS / BRAKE | W / S or ↑ / ↓ |
| Indicators | `<` / `>` | Q / E |
| Camera | CAM | C |
| Horn | HORN | H |
| Menu | MENU | Esc |

## Project layout

| Path | Contents |
|---|---|
| `src/` | Game code. Pure logic is written as `RefCounted` classes; nodes are thin wrappers around it. |
| `scenes/` | Entry scene (`main.tscn`). The world is built from code and data. |
| `tests/framework/` | Minimal GDScript test framework (`TestCase`) and headless runner. |
| `tests/helpers/` | Autopilot (drives through the player's input actions), game driver, fixtures. |
| `tests/unit/` | Pure-logic tests: no scene tree or physics required. |
| `tests/integration/` | Several real nodes working together in a live tree and physics world. |
| `tests/system/` | End-to-end: the real game is booted and played with simulated input. |
| `tools/` | `run_tests.sh`, `lint.sh`, `export_android.sh` (local + CI/CD), `screenshots.gd` (renders views). |
| `.github/workflows/` | CI (lint + test pyramid) and CD (Android APK export, releases). |

## Running tests locally

```bash
export GODOT=/path/to/Godot_v4.4-stable   # the editor binary
tools/run_tests.sh unit          # or: integration | system | all
tools/run_tests.sh unit --filter=wallet
```

The runner imports the project, runs headless with `--fixed-fps 60` (deterministic
physics, faster than real time), writes JUnit XML to `reports/`, and fails on any
assertion failure **or** any GDScript error printed during the run. System tests
use throwaway save files and never touch a real save.

Lint and formatting checks (requires `pip install "gdtoolkit==4.*"`):

```bash
tools/lint.sh
```

## CI/CD

* **CI** (`ci.yml`) runs on every branch push and pull request:
  `lint` and `unit` in parallel → `integration` → `system`.
  Each stage uploads its JUnit report and writes a summary to the job page.
* **CD** (`cd.yml`) runs on every push to `main` and on `v*` tags: the full CI
  pipeline, then a headless Android export (`tools/export_android.sh`). The APK
  is verified (signed, arm64, correct package/version, and **no INTERNET
  permission** since the game is fully offline) and uploaded as an artifact.
  Tags also publish a GitHub Release with the APK attached.

### Release signing

Without secrets, CD produces a debug-signed APK. To ship release-signed builds,
add these repository secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.keystore` |
| `ANDROID_KEYSTORE_ALIAS` | key alias |
| `ANDROID_KEYSTORE_PASSWORD` | keystore/key password |

## Workflow

Each feature is developed on its own branch, verified by CI, and merged into
`main` with a merge commit, following the build order in the design doc.
