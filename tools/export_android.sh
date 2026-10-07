#!/usr/bin/env bash
# Exports the Android APK headless and verifies it.
#   tools/export_android.sh <version-name> <version-code> [debug|release]
#
# Requires: GODOT, Godot export templates for the same version, an Android SDK
# (ANDROID_SDK_ROOT), a JDK (JAVA_HOME) and a keystore. For debug builds a
# keystore is generated when GODOT_ANDROID_KEYSTORE_DEBUG_PATH is not set.
# Release builds read RELEASE_KEYSTORE_{PATH,ALIAS,PASSWORD}.
set -euo pipefail

VERSION_NAME="${1:?version name}"
VERSION_CODE="${2:?version code}"
MODE="${3:-debug}"
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/build/android"
APK="$OUT_DIR/bus-simulator-$VERSION_NAME-$MODE.apk"
mkdir -p "$OUT_DIR"

# Godot refuses to export when release credentials are only partially set,
# so they are exported only for release builds.
unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER \
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
if [[ "$MODE" == "release" ]]; then
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${RELEASE_KEYSTORE_PATH:?}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${RELEASE_KEYSTORE_ALIAS:?}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${RELEASE_KEYSTORE_PASSWORD:?}"
fi

# Debug builds are signed with the committed debug key, so every release has
# the same signature and installs over the previous one as an update.
if [[ "$MODE" == "debug" && -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$ROOT/tools/android/debug.keystore"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
fi

# Point the editor at the SDK and JDK (Godot reads these from editor settings).
SETTINGS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$SETTINGS_DIR"
for file in editor_settings-4.tres editor_settings-4.4.tres; do
  cat >"$SETTINGS_DIR/$file" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export/android/java_sdk_path = "${JAVA_HOME}"
EOF
done

# Stamp the version into the preset (CI uses the run number as version code).
sed -i.bak -E \
  -e "s/^version\/code=.*/version\/code=$VERSION_CODE/" \
  -e "s/^version\/name=.*/version\/name=\"$VERSION_NAME\"/" \
  "$ROOT/export_presets.cfg"
rm -f "$ROOT/export_presets.cfg.bak"

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" "--export-$MODE" "Android" "$APK"

# ---- Verification -----------------------------------------------------------
test -s "$APK" || { echo "::error::APK was not produced"; exit 1; }
size=$(stat -c %s "$APK")
echo "APK: $APK ($((size / 1024 / 1024)) MiB)"
(( size > 5 * 1024 * 1024 )) || { echo "::error::APK suspiciously small"; exit 1; }

listing=$(unzip -l "$APK")
# arm64 for modern phones, armeabi-v7a for phones running 32-bit Android
# (common on budget devices; without it they report "package appears to be invalid").
for entry in classes.dex AndroidManifest.xml lib/arm64-v8a/ lib/armeabi-v7a/ assets/; do
  grep -q "$entry" <<<"$listing" || { echo "::error::APK is missing $entry"; exit 1; }
done

BUILD_TOOLS=$(ls -d "${ANDROID_SDK_ROOT:-$ANDROID_HOME}"/build-tools/* | sort -V | tail -1)
signing=$("$BUILD_TOOLS/apksigner" verify --verbose --print-certs "$APK")
head -8 <<<"$signing"
# A v2 signature is what Android 7+ checks; without it installs fail as "invalid".
for scheme in v2; do
  grep -q "Verified using $scheme scheme (.*): true" <<<"$signing"     || { echo "::error::APK is not signed with the $scheme scheme"; exit 1; }
done
if [[ "$MODE" == "debug" && "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" == "$ROOT/tools/android/debug.keystore" ]]; then
  grep -qi "8e7be1242bd8660fea115635d97b57567b6696f40b07f43e5cbe8ccf81af5ef8" <<<"$signing"     || { echo "::error::APK not signed with the project debug key"; exit 1; }
fi
badging=$("$BUILD_TOOLS/aapt2" dump badging "$APK")
grep -q "package: name='com.umeriftikhar.bussimulator'" <<<"$badging" \
  || { echo "::error::unexpected package name"; exit 1; }
grep -q "versionName='$VERSION_NAME'" <<<"$badging" \
  || { echo "::error::version name not stamped"; exit 1; }
# The game is 100% offline: it must not request network access.
if grep -qE "uses-permission: name='android.permission.INTERNET'" <<<"$badging"; then
  echo "::error::APK requests INTERNET permission but the game must be offline"
  exit 1
fi
echo "APK verified: signed (v2, stable key), arm64 + armv7, offline (no INTERNET permission)."
echo "apk=$APK" >>"${GITHUB_OUTPUT:-/dev/null}"
