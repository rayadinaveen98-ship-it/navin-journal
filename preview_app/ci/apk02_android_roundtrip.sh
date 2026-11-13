#!/usr/bin/env bash
# APK02 Android integration: full journal_core + Keystore + fresh isolate.
# ONLY disposable fictional test data. Never target a user-journal app.
set -euo pipefail

SERIAL="emulator-5554"
PACKAGE="com.navinjournal.navin_journal_preview"
ACTIVITY="$PACKAGE/.MainActivity"
APK="$APK02_ROOT/build/app/outputs/flutter-apk/app-debug.apk"

test -s "$APK" || { echo "::error::Debug APK missing"; exit 2; }
ready=0
for attempt in $(seq 1 100); do
  boot="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$boot" == "1" ]] &&
      adb -s "$SERIAL" shell pm path android 2>/dev/null | grep -q '^package:'; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == "1" ]] || {
  echo "::error::Android emulator package manager is not ready"
  exit 2
}

adb -s "$SERIAL" install -r -t "$APK"
adb -s "$SERIAL" shell am force-stop "$PACKAGE" || true
# This package is a disposable scripted fixture; never run this against a
# released application or existing user data.
adb -s "$SERIAL" shell pm clear "$PACKAGE" | grep -q 'Success'

marker() {
  adb -s "$SERIAL" shell run-as "$PACKAGE" \
    cat files/nj_crash_phase.txt 2>/dev/null | tr -d '\r' || true
}

run_phase() {
  local phase="$1"
  local expected="$2"
  adb -s "$SERIAL" shell run-as "$PACKAGE" rm -f files/nj_crash_phase.txt
  adb -s "$SERIAL" shell am start -n "$ACTIVITY" --es nj_test_phase "$phase"
  for attempt in $(seq 1 100); do
    status="$(marker)"
    if [[ "$status" == "$expected" ]]; then
      echo "PASSED $expected · Android Keystore/whole-journal encrypted storage"
      return 0
    fi
    if [[ "$status" == "FAILED" ]]; then
      echo "::error::Encrypted journal fixture failed at $phase"
      return 1
    fi
    sleep 2
  done
  echo "::error::Missing expected $expected status after $phase"
  return 1
}

force_stop() {
  adb -s "$SERIAL" shell am force-stop "$PACKAGE"
  for attempt in $(seq 1 25); do
    pid="$(adb -s "$SERIAL" shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)"
    if [[ -z "$pid" ]]; then
      echo "Confirmed original Android process is terminated"
      return 0
    fi
    sleep 1
  done
  echo "::error::Android process survived force-stop"
  return 1
}

run_phase write_v1 ACK_V1
force_stop
run_phase reopen_and_write_v2 ACK_V2
force_stop
run_phase reopen_v2 RECOVERED_V2
force_stop

echo "APK02 Android verified: original app-private encrypted full-schema vault"
echo "and AndroidKeyStore wrapped database key survived two real OS force-stops."
echo "No private data used, no real-world backup or beta release proof implied."
adb -s "$SERIAL" uninstall "$PACKAGE"
