#!/usr/bin/env bash
# Test-only Android emulator readiness + sequential Flutter integration.
# No private user data. Do not hide real test failures behind generic retries.
set -euo pipefail

SERIAL="emulator-5554"
echo "Checking Android package-manager readiness on $SERIAL"

ready=0
for attempt in $(seq 1 90); do
  boot="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  # Boot-complete/ADB can precede PackageManager. Flutter install requires it.
  if [[ "$boot" == "1" ]] &&
    adb -s "$SERIAL" shell pm path android 2>/dev/null | grep -q '^package:'; then
    ready=1
    echo "Emulator boot and Android package manager ready"
    break
  fi
  if (( attempt % 10 == 0 )); then
    echo "Still waiting for Android framework services: attempt $attempt/90"
    adb -s "$SERIAL" get-state || true
  fi
  sleep 2
done

if [[ "$ready" != 1 ]]; then
  echo "::error::Android package manager not available after boot"
  adb -s "$SERIAL" shell getprop sys.boot_completed || true
  adb -s "$SERIAL" shell pm path android || true
  exit 2
fi

# Separate Flutter invocations avoid cross-test APK-install overlaps.
cd "$BRIDGE_PROBE_ROOT"
flutter test integration_test/android_key_bridge_integration_test.dart \
  -d "$SERIAL" --reporter expanded

adb -s "$SERIAL" shell pm path android | grep -q '^package:' || {
  echo "::error::Android package manager vanished after first integration suite"
  exit 2
}

flutter test integration_test/autosave_probe_integration_test.dart \
  -d "$SERIAL" --reporter expanded
