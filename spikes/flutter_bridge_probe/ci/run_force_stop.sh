#!/usr/bin/env bash
# A3.4 real Android process force-stop and encrypted data recovery.
# DEBUG TEST APP ONLY: wipes its own fictional fixture at the start and
# uninstalls it at the end. NEVER point at a real journaling application.
set -euo pipefail

SERIAL="emulator-5554"
PACKAGE="com.navinjournal.navin_journal_bridge_probe"
ACTIVITY="$PACKAGE/.MainActivity"
APK="$BRIDGE_PROBE_ROOT/build/app/outputs/flutter-apk/app-debug.apk"

[[ -f "$APK" ]] || { echo "::error::No debug test fixture APK"; exit 2; }

is_ready=0
for attempt in $(seq 1 90); do
  boot="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$boot" == "1" ]] &&
      adb -s "$SERIAL" shell pm path android 2>/dev/null | grep -q '^package:'; then
    is_ready=1
    break
  fi
  sleep 2
done
[[ "$is_ready" == "1" ]] || {
  echo "::error::Emulator package service unavailable"
  exit 2
}
echo "Installing disposable A3.4 debug-only fixture"
adb -s "$SERIAL" install -r -t "$APK"
adb -s "$SERIAL" shell am force-stop "$PACKAGE" || true
# This APK contains no real diaries, and this is the only permitted reset.
adb -s "$SERIAL" shell pm clear "$PACKAGE" | grep -q 'Success'

marker() {
  adb -s "$SERIAL" shell run-as "$PACKAGE" \
    cat files/nj_crash_phase.txt 2>/dev/null | tr -d '\r' || true
}

wait_for_marker() {
  local desired="$1"
  local seen=""
  for attempt in $(seq 1 90); do
    seen="$(marker)"
    if [[ "$seen" == "$desired" ]]; then
      echo "Verified diagnostic marker: $desired"
      return 0
    fi
    if [[ "$seen" == "FAILED" ]]; then
      echo "::error::Fixture reported a generic encrypted recovery failure"
      return 1
    fi
    sleep 2
  done
  echo "::error::Timed out awaiting $desired (last code-only marker: $seen)"
  return 1
}

begin_phase() {
  local phase="$1"
  local expect="$2"
  # Remove only the previous generic marker. Never delete/reinitialize
  # the test encrypted database or Keystore alias across force-stop cycles.
  adb -s "$SERIAL" shell run-as "$PACKAGE" \
    rm -f files/nj_crash_phase.txt
  echo "Starting a fresh Android app process for phase $phase"
  adb -s "$SERIAL" shell am start -n "$ACTIVITY" \
    --es nj_test_phase "$phase"
  wait_for_marker "$expect"
}

force_stop() {
  echo "ADB force-stopping the fixture without clearing app-private storage"
  adb -s "$SERIAL" shell am force-stop "$PACKAGE"
  # A force-stop must not let the same Dart isolate remain in the process.
  for attempt in $(seq 1 25); do
    pid="$(adb -s "$SERIAL" shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)"
    if [[ -z "$pid" ]]; then
      echo "Confirmed original Android process is no longer running"
      return 0
    fi
    sleep 1
  done
  echo "::error::Android process still alive after force-stop"
  return 1
}

# Phase 1: new encrypted DB, device-protected key, acknowledged fictional v1.
begin_phase write_v1 ACK_V1
force_stop
# Phase 2: new process, same envelope & Keystore alias, recover v1,
# then acknowledge fictional v2 without replacing the original database.
begin_phase reopen_and_write_v2 ACK_V2
force_stop
# Phase 3: yet another new process, verify exactly acknowledged v2.
begin_phase reopen_v2 RECOVERED_V2
force_stop

echo "A3.4 VERIFIED: actual Android ADB force-stop/relaunch preserves two"
echo "acknowledged fictional encrypted versions with original Keystore key."
# Cleanup only the dedicated test application, which has no real user data.
adb -s "$SERIAL" uninstall "$PACKAGE"
