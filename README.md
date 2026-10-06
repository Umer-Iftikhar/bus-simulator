# Bus Simulator

Offline 3D bus-driving simulator for Android, built with **Godot 4.4**.
Drive metro-style routes, carry passengers, earn fares, and spend them on bigger
buses, upgrades and paint jobs. Careless driving costs you in repairs.

The full design lives in [docs/game-design.md](docs/game-design.md).

## Project layout

| Path | Contents |
|---|---|
| `src/` | Game code. Pure logic is written as `RefCounted` classes; nodes are thin wrappers around it. |
| `scenes/` | Entry scenes (`main.tscn`). Most of the world is built from code and data. |
| `tests/framework/` | Minimal GDScript test framework (`TestCase`) and headless runner. |
| `tests/unit/` | Pure-logic tests: no scene tree or physics required. |
| `tests/integration/` | Several real nodes working together in a live tree and physics world. |
| `tests/system/` | End-to-end: real game scenes are booted and driven with simulated input. |
| `tools/` | `run_tests.sh` and `lint.sh`, used both locally and in CI. |
| `.github/workflows/` | CI (lint + test pyramid) and CD (Android APK export, releases). |

## Running tests locally

```bash
export GODOT=/path/to/Godot_v4.4-stable   # the editor binary
tools/run_tests.sh unit          # or: integration | system | all
tools/run_tests.sh unit --filter=wallet
```

The runner imports the project, runs headless with `--fixed-fps 60` (deterministic
physics, faster than real time), writes JUnit XML to `reports/`, and fails on any
assertion failure **or** any GDScript error printed during the run.

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

Each feature is developed on its own `feat/*` branch, verified by CI, and merged
into `main` with a merge commit, following the build order in the design doc.
