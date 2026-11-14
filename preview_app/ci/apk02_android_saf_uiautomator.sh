#!/usr/bin/env bash
# Stage5B — AndroidX UI Automator against actual Android DocumentsUI.
# A SEPARATE test app drives the fictional encrypted probe. Not release QA.
set -euo pipefail
SERIAL=emulator-5554
PROBE_APK="$SAF_PROBE_ROOT/build/app/outputs/flutter-apk/app-debug.apk"
DRIVER_APP="$SAF_DRIVER_ROOT/build/app/outputs/apk/debug/app-debug.apk"
DRIVER_TEST="$SAF_DRIVER_ROOT/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
for apk in "$PROBE_APK" "$DRIVER_APP" "$DRIVER_TEST"; do
  test -s "$apk" || { echo "::error::Missing generated test APK"; exit 1; }
done

adb -s "$SERIAL" wait-for-device
ready=0
for i in $(seq 1 120); do
  booted="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$booted" == 1 ]] &&
     adb -s "$SERIAL" shell pm path android 2>/dev/null | grep -q '^package:'; then
    ready=1; break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo "::error::API34 emulator not ready"; exit 2; }

adb -s "$SERIAL" install -r -t "$PROBE_APK"
adb -s "$SERIAL" install -r -t "$DRIVER_APP"
adb -s "$SERIAL" install -r -t "$DRIVER_TEST"

# The test driver runs in a different app/process from the fictional probe.
# No ADB coordinates, direct document URI or fabricated picker callback.
set +e
result="$(timeout 420s adb -s "$SERIAL" shell am instrument -w -r \
  -e class 'com.navinjournal.navin_journal_saf_driver.SafDocumentPickerInstrumentedTest#actualFictionalAndroidPickerRoundTrip' \
  com.navinjournal.navin_journal_saf_driver.test/androidx.test.runner.AndroidJUnitRunner 2>&1)"
status=$?
set -e
printf '%s\n' "$result"
if [[ "$status" != 0 ]] || ! grep -q 'OK (1 test)' <<<"$result"; then
  echo "::error::Native AndroidX SAF export/import was not authenticated"
  exit 1
fi

adb -s "$SERIAL" shell am force-stop com.navinjournal.navin_journal_saf_probe
adb -s "$SERIAL" uninstall com.navinjournal.navin_journal_saf_probe | grep -q Success
adb -s "$SERIAL" uninstall com.navinjournal.navin_journal_saf_driver.test | grep -q Success
adb -s "$SERIAL" uninstall com.navinjournal.navin_journal_saf_driver | grep -q Success
echo "PASSED real AndroidX DocumentsUI cancellation and authenticated fictional export/import."
echo "NOT physical OEM, handwritten recovery key, real private writing or production certification."
