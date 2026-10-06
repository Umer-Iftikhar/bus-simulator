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
| `.github/workflows/` | CI pipeline (lint + test pyramid). |

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

## Workflow

Each feature is developed on its own `feat/*` branch, verified by CI, and merged
into `main` with a merge commit, following the build order in the design doc.
