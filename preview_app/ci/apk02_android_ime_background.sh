#!/usr/bin/env bash
# API 34, disposable, synthetic Telugu preedit only.
# Uses Android HOME + actual force-stop/relaunch; not Gboard or personal input.
set -euo pipefail

SERIAL="emulator-5554"
PACKAGE="com.navinjournal.navin_journal_ime_probe"
ACTIVITY="$PACKAGE/.MainActivity"
APK="$IME_PROBE_ROOT/build/app/outputs/flutter-apk/app-debug.apk"

[[ -s "$APK" ]] || { echo "::error::Missing fictional IME APK"; exit 2; }
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
  echo "::error::Android package manager was not ready"
  exit 2
}

adb -s "$SERIAL" install -r -t "$APK"
adb -s "$SERIAL" shell am force-stop "$PACKAGE" || true
# Only ever clear this explicitly named disposable engineering test package.
adb -s "$SERIAL" shell pm clear "$PACKAGE" | grep -q 'Success'

marker() {
  adb -s "$SERIAL" shell run-as "$PACKAGE"     cat files/nj_crash_phase.txt 2>/dev/null | tr -d '\r' || true
}
wait_marker() {
  local expected="$1"
  for attempt in $(seq 1 120); do
    local status
    status="$(marker)"
    if [[ "$status" == "$expected" ]]; then
      echo "PASSED $expected (Android API 34, fictional-only)"
      return 0
    fi
    if [[ "$status" == "FAILED" ]]; then
      echo "::error::App-side encrypted IME diagnostic failed at $expected"
      return 1
    fi
    sleep 2
  done
  echo "::error::Timed out waiting for $expected; last marker: $(marker)"
  return 1
}
launch() {
  local phase="$1"
  adb -s "$SERIAL" shell run-as "$PACKAGE" rm -f files/nj_crash_phase.txt
  adb -s "$SERIAL" shell am start -n "$ACTIVITY" --es nj_test_phase "$phase"
}
force_stop() {
  adb -s "$SERIAL" shell am force-stop "$PACKAGE"
  for attempt in $(seq 1 25); do
    pid="$(adb -s "$SERIAL" shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)"
    if [[ -z "$pid" ]]; then
      echo "Confirmed Android app process terminated"
      return 0
    fi
    sleep 1
  done
  echo "::error::App process survived force-stop"
  return 1
}

# No typed input: the read-only Flutter editor is filled with fixed imaginary
# Telugu TextEditingValue and an unfinished composing range.
launch ime_prepare
wait_marker IME_PREEDIT_READY
adb -s "$SERIAL" shell input keyevent KEYCODE_HOME
# Only an actual Flutter Android lifecycle transition may trigger this ACK;
# the Dart harness checks the live editor remains unclosable and reopens the
# encrypted SQLite file with an independently unwrapped Keystore key.
wait_marker IME_BACKGROUND_ACK_V1
force_stop

launch ime_finalize
wait_marker IME_FINAL_ACK_V2
force_stop

launch ime_reopen
wait_marker IME_REOPENED_V2
force_stop

echo "Android HOME + two confirmed app force-stops: partial fictional"
echo "Telugu preedit and final revised encrypted entry survived same-install"
echo "Keystore reopen; real Gboard, physical hardware and OS power-loss untested."
adb -s "$SERIAL" uninstall "$PACKAGE"
