#!/usr/bin/env bash
# Static checks: gdlint + gdformat (pip install "gdtoolkit==4.*").
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
gdlint src tests
gdformat --check --line-length 100 src tests
