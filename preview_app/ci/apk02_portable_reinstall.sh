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

# TEST ONLY: the worker throws a simulated ENOSPC after writing the readiness
# marker but before native no-replace publication. No new vault or stage may
# be visible afterward; original imported encrypted archive stays intact.
phase fault_pre_publish PORTABLE_ENOSPC_PRE
if app_path_exists files/fault-pre-vault; then
  echo "::error::Pre-publication fault exposed a journal"; exit 1
fi
stop_app

# TEST ONLY: a simulated ENOSPC occurs immediately AFTER atomic rename.
# The result is ambiguous to the caller but must remain independently
# decryptable under its own new Android Keystore key. Never clear this vault.
phase fault_post_publish PORTABLE_ENOSPC_POST
if ! app_path_exists files/fault-post-vault; then
  echo "::error::Post-publication fault lost its encrypted vault"; exit 1
fi
stop_app
phase reopen_faulted PORTABLE_ENOSPC_REOPEN
stop_app

# Existing normal independent-key clean-reinstall behavior must still work.
phase restore_fixture PORTABLE_RESTORE_OK
if app_path_exists files/portable_import.key; then
  echo "::error::One-time recovery key input was not deleted"; exit 1
fi
stop_app
phase reopen_fixture PORTABLE_REOPEN_OK
stop_app

# STAGE 5A native Keystore retained candidate. The earlier portable
# restore deliberately removed BOTH its one-time Android archive and key.
# Re-transfer an independent copy of BOTH from the outside CI host, exactly
# as a separate user-held backup/key would be supplied to a fresh process.
# The app deletes them again after preparing the protected candidate.
# Existing encrypted portable-restored vault must remain intact.
if app_path_exists files/portable_import.njr ||
   app_path_exists files/portable_import.key; then
  echo "::error::Previous portable restore retained one-time input"; exit 1
fi
adb -s "$SERIAL" shell -T run-as "$PACKAGE" \
  tee files/portable_import.njr < "$ARCHIVE" > /dev/null
adb -s "$SERIAL" shell -T run-as "$PACKAGE" \
  tee files/portable_import.key < "$KEY" > /dev/null
adb -s "$SERIAL" shell run-as "$PACKAGE" chmod 600 files/portable_import.key
phase retain_candidate CANDIDATE_RETAINED
if app_path_exists files/portable_import.key ||
   app_path_exists files/portable_import.njr; then
  echo "::error::One-time candidate archive/key remained in Android sandbox"
  exit 1
fi
if ! app_path_exists files/nj-fictional-retained-candidate-v1 ||
   ! app_path_exists files/nj-fictional-retained-candidate-v1.reservation ||
   ! app_path_exists files/nj-fictional-retained-candidate-v1/envelope.json ||
   ! app_path_exists files/nj-fictional-retained-candidate-v1/vault/journal.sqlite3; then
  echo "::error::Retained encrypted vault/envelope/exclusive reservation absent"
  exit 1
fi
stop_app

# Android process has been killed; neither the archive nor its manually
# entered key is passed as argument. Reopen from the *persisted* Android
# Keystore-wrapped envelope. Verify fictional Telugu/current/history.
phase reopen_candidate CANDIDATE_REOPEN_OK
stop_app

# Invalidate ONLY the isolated candidate's own alias. Reopen must now fail
# closed without deleting candidate bytes; the older independent restored
# vault must remain independently unlockable.
phase retire_candidate_alias CANDIDATE_KEY_LOSS_SAFE
if ! app_path_exists files/nj-fictional-retained-candidate-v1/vault/journal.sqlite3 ||
   ! app_path_exists files/nj-fictional-retained-candidate-v1/envelope.json ||
   ! app_path_exists files/nj-fictional-retained-candidate-v1.reservation; then
  echo "::error::Key-loss erroneously erased retained encrypted candidate"
  exit 1
fi
stop_app

adb -s "$SERIAL" uninstall "$PACKAGE" | grep -q Success
echo "VERIFIED: fictional v2 archive off device, original Android install deleted,"
echo "wrong recovery key rejected without staging, fresh device key restore,"
echo "historical revision recovered and reopened after Android force-stop."
echo "Android synthetic ENOSPC before publication failed closed; after rename"
echo "the encrypted journal was preserved and reopened under its own device key."
echo "Native Android Stage 5A: isolated candidate wrapped by its own Keystore alias,"
echo "exclusive no-replace reservation, independent force-stop reopen,"
echo "fictional Telugu revision verification, and missing-alias fail-closed."
echo "NOT verified for actual personal data, manual SAF UX, physical power"
echo "loss, retained-vault activation, or production private-data recovery."
