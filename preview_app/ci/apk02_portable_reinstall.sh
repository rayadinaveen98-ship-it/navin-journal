#!/usr/bin/env bash
# APK02 FICTIONAL ONLY: portable archive taken off device, uninstall/reinstall,
# wrong-key refusal, fresh Android Keystore restore, and force-stop reopen.
set -euo pipefail
SERIAL=emulator-5554
PACKAGE=com.navinjournal.navin_journal_portable_probe
ACTIVITY="$PACKAGE/.MainActivity"
APK="$PORTABLE_APK_ROOT/build/app/outputs/flutter-apk/app-debug.apk"
test -s "$APK"
WORK="$(mktemp -d -p "$RUNNER_TEMP" nj-portable-fictional-XXXXXXXX)"
chmod 700 "$WORK"
ARCHIVE="$WORK/archive.njr"
KEY="$WORK/recovery.key"
WRONG="$WORK/wrong.key"
cleanup() { rm -f "$ARCHIVE" "$KEY" "$WRONG"; rmdir "$WORK" 2>/dev/null || true; }
trap cleanup EXIT

adb -s "$SERIAL" wait-for-device
ready=0
for i in $(seq 1 120); do
  state="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$state" == 1 ]] &&
      adb -s "$SERIAL" shell pm path android 2>/dev/null | grep -q '^package:'; then
    ready=1; break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo "::error::Emulator PM not ready"; exit 2; }

# Do not use adb exec-out's process exit status for existence probes:
# it streams stdout and has not reliably propagated remote test(1) failure.
app_path_exists() {
  local path="$1"
  adb -s "$SERIAL" shell run-as "$PACKAGE" ls -ld "$path" 2>/dev/null |
    grep -F -q -- "${path##*/}"
}

marker() {
  adb -s "$SERIAL" exec-out run-as "$PACKAGE" \
    cat files/nj_crash_phase.txt 2>/dev/null | tr -d '\r' || true
}
stop_app() {
  adb -s "$SERIAL" shell am force-stop "$PACKAGE"
  for i in $(seq 1 30); do
    pid="$(adb -s "$SERIAL" shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)"
    if [[ -z "$pid" ]]; then
      echo "Confirmed Android diagnostic process terminated"
      return 0
    fi
    sleep 1
  done
  echo "::error::Diagnostic process did not terminate"; return 1
}
phase() {
  local label="$1" wanted="$2"
  adb -s "$SERIAL" shell run-as "$PACKAGE" rm -f files/nj_crash_phase.txt
  adb -s "$SERIAL" shell am start -n "$ACTIVITY" --es nj_test_phase "$label"
  for i in $(seq 1 150); do
    status="$(marker)"
    if [[ "$status" == "$wanted" ]]; then
      echo "PASSED $wanted · independent fictional portable recovery"
      return 0
    fi
    if [[ "$status" == FAILED ]]; then
      echo "::error::Fictional recovery failed at $label"
      return 1
    fi
    sleep 1
  done
  echo "::error::Timed out waiting for $wanted in $label"
  return 1
}

adb -s "$SERIAL" install -r -t "$APK"
# Always a newly built disposable package, never a user's application.
adb -s "$SERIAL" shell pm clear "$PACKAGE" | grep -q Success
phase export_fixture PORTABLE_EXPORT_READY
adb -s "$SERIAL" exec-out run-as "$PACKAGE" cat files/portable_export.njr > "$ARCHIVE"
adb -s "$SERIAL" exec-out run-as "$PACKAGE" cat files/portable_export.key > "$KEY"
chmod 600 "$ARCHIVE" "$KEY"
test -s "$ARCHIVE" && test "$(wc -c < "$KEY")" -eq 43
if grep -a -q 'Imaginary portable page' "$ARCHIVE"; then
  echo "::error::Recognizable fictional plaintext in encrypted backup"; exit 1
fi
echo "Independent archive and recovery key copied OFF Android before uninstall"
stop_app

adb -s "$SERIAL" uninstall "$PACKAGE" | grep -q Success
if adb -s "$SERIAL" shell pm path "$PACKAGE" 2>/dev/null | grep -q '^package:'; then
  echo "::error::Original Android package still present"; exit 1
fi
echo "Original app and device-bound database removed"
adb -s "$SERIAL" install -r -t "$APK"
# The new app has not launched yet: getFilesDir() has not necessarily run.
# Ensure only its empty private files directory exists before streaming data.
adb -s "$SERIAL" shell run-as "$PACKAGE" mkdir -p files
if app_path_exists files/portable_export.njr; then
  echo "::error::Original app sandbox unexpectedly survived reinstall"; exit 1
fi

# Stream the encrypted backup and separately held key into a fresh sandbox.
# ADB -T disables PTY newline conversion for exact authenticated byte transfer.
adb -s "$SERIAL" shell -T run-as "$PACKAGE" \
  tee files/portable_import.njr < "$ARCHIVE" > /dev/null
adb -s "$SERIAL" shell -T run-as "$PACKAGE" \
  tee files/portable_import.key < "$KEY" > /dev/null
adb -s "$SERIAL" shell run-as "$PACKAGE" \
  chmod 600 files/portable_import.njr files/portable_import.key
adb -s "$SERIAL" exec-out run-as "$PACKAGE" \
  cat files/portable_import.njr | cmp - "$ARCHIVE"
echo "Fresh sandbox contains byte-identical encrypted archive"

python3 - "$WRONG" <<'PY'
import base64, secrets, sys
s = base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('=')
with open(sys.argv[1], 'w', encoding='ascii') as f:
    f.write(s)
PY
chmod 600 "$WRONG"
adb -s "$SERIAL" shell -T run-as "$PACKAGE" \
  tee files/portable_wrong.key < "$WRONG" > /dev/null
adb -s "$SERIAL" shell run-as "$PACKAGE" chmod 600 files/portable_wrong.key
phase reject_wrong_key PORTABLE_WRONG_KEY
for path in portable-restored-vault portable-restored-envelope.json; do
  if app_path_exists "files/$path"; then
    echo "::error::Wrong key caused $path to be created"; exit 1
  fi
done
stop_app

phase restore_fixture PORTABLE_RESTORE_OK
if app_path_exists files/portable_import.key; then
  echo "::error::One-time recovery key input was not deleted"; exit 1
fi
stop_app
phase reopen_fixture PORTABLE_REOPEN_OK
stop_app

adb -s "$SERIAL" uninstall "$PACKAGE" | grep -q Success
echo "VERIFIED: fictional v2 archive off device, original Android install deleted,"
echo "wrong recovery key rejected without staging, fresh device key restore,"
echo "historical revision recovered and reopened after Android force-stop."
echo "NOT verified for actual personal data, media streaming, or production restore."
