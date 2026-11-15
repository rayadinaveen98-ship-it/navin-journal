#!/usr/bin/env bash
# Stage 5C native Android first-run check. 100% disposable fictional only.
# The uploaded screenshots are restricted to the empty first-launch view and
# a scripted fictional Library. Never capture a key-entry screen or picker.
set -euo pipefail

SERIAL=emulator-5554
PACKAGE=com.navinjournal.navin_journal_library_probe
ACTIVITY="$PACKAGE/.MainActivity"
APK="$APK02_LIBRARY_ROOT/build/app/outputs/flutter-apk/app-debug.apk"
CAPTURE="$GITHUB_WORKSPACE/preview_app/_stage5c_firstlaunch_artifacts"
WORK="$(mktemp -d -p "$RUNNER_TEMP" nj-firstlaunch-XXXXXXXX)"
chmod 700 "$WORK"
mkdir -p "$CAPTURE"
test -s "$APK"

cleanup() {
  adb -s "$SERIAL" shell settings put system font_scale 1.0 >/dev/null 2>&1 || true
  adb -s "$SERIAL" shell rm -f /sdcard/nj_stage5c_dump.xml >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

adb -s "$SERIAL" wait-for-device
ready=0
for _ in $(seq 1 120); do
  if [[ "$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]] &&
     adb -s "$SERIAL" shell pm path android 2>/dev/null | grep -q '^package:'; then
    ready=1
    break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo "::error::API34 Android not booted"; exit 2; }
adb -s "$SERIAL" install -r -t "$APK" >/dev/null
# Clear only our freshly installed disposable fictional package.
adb -s "$SERIAL" shell pm clear "$PACKAGE" | grep -q Success

capture_ui() {
  if ! timeout 25s adb -s "$SERIAL" shell uiautomator dump --compressed \
      /sdcard/nj_stage5c_dump.xml >/dev/null 2>&1; then
    return 1
  fi
  adb -s "$SERIAL" exec-out cat /sdcard/nj_stage5c_dump.xml \
    > "$WORK/hierarchy.xml" 2>/dev/null
  [[ -s "$WORK/hierarchy.xml" ]]
}
has_label() {
  python3 - "$WORK/hierarchy.xml" "$1" <<'PY'
import sys
import xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
    label = sys.argv[2].casefold()
    ok = any(label in (n.attrib.get('text','') + " " +
                       n.attrib.get('content-desc','')).casefold()
             for n in root.iter('node'))
except Exception:
    ok = False
raise SystemExit(0 if ok else 1)
PY
}
wait_label() {
  local label="$1"
  for _ in $(seq 1 25); do
    if capture_ui && has_label "$label"; then
      return 0
    fi
    sleep 2
  done
  echo "::error::Expected visible Android UI label absent: $label"
  return 1
}
assert_no_vault() {
  if adb -s "$SERIAL" shell run-as "$PACKAGE" \
      test -e files/nj_apk02_library_fixture; then
    echo "::error::First launch silently occupied fictional vault before consent"
    exit 1
  fi
}
launch() {
  adb -s "$SERIAL" shell am start -n "$ACTIVITY" >/dev/null
}
shot() {
  local name="$1" bytes
  adb -s "$SERIAL" exec-out screencap -p > "$CAPTURE/$name.png"
  test -s "$CAPTURE/$name.png"
  bytes="$(stat -c %s "$CAPTURE/$name.png")"
  # API34 Pixel4 fixture: a composited first-launch screen is >40KiB.
  # A previous capture was a ~20KiB blank emulator transition frame even
  # though UI Automator could read the semantics hierarchy. Fail closed.
  if [[ "$bytes" -lt 40960 ]]; then
    echo "::error::Captured Android screenshot looks blank/incomplete"
    return 1
  fi
}
tap_label() {
  local coords
  coords="$(python3 - "$WORK/hierarchy.xml" "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
label = sys.argv[2].casefold()
rx = re.compile(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]')
for n in root.iter('node'):
    attrs=n.attrib
    if label not in (attrs.get('text','')+' '+attrs.get('content-desc','')).casefold():
        continue
    rect=rx.fullmatch(attrs.get('bounds',''))
    if rect is None: continue
    x1,y1,x2,y2=map(int,rect.groups())
    if x2>x1 and y2>y1:
        print((x1+x2)//2,(y1+y2)//2)
        raise SystemExit(0)
raise SystemExit(1)
PY
)" || { echo "::error::Cannot locate control safely"; exit 1; }
  adb -s "$SERIAL" shell input tap $coords
}
echo "Checking actual Android API34 fictional first launch, normal text scale"
adb -s "$SERIAL" shell settings put system font_scale 1.0
launch
wait_label "Your fictional journal"
capture_ui
has_label "Create a fresh fictional journal" ||
  { echo "::error::First-launch Create choice absent"; exit 1; }
assert_no_vault
shot first-launch-normal
echo "PASSED NATIVE_FIRST_RUN_NO_SILENT_VAULT"

echo "Checking actual Android 200% font scale and scrolled recovery actions"
adb -s "$SERIAL" shell settings put system font_scale 2.0
[[ "$(adb -s "$SERIAL" shell settings get system font_scale | tr -d '\r')" == 2.0 ]] ||
  { echo "::error::Font scale setting was not applied"; exit 1; }
adb -s "$SERIAL" shell am force-stop "$PACKAGE"
launch
wait_label "Your fictional journal"
assert_no_vault
# Do not screenshot immediately after Android settings/relaunch: Flutter
# semantics can become visible before SurfaceView's compositor first frame.
seen_import=0
seen_recovery=0
size="$(adb -s "$SERIAL" shell wm size | head -n 1 | tr -d '\r')"
read -r w h < <(python3 - "$size" <<'PY'
import re,sys
m=re.search(r'(\d+)x(\d+)',sys.argv[1])
if not m: raise SystemExit(1)
print(m.group(1),m.group(2))
PY
)
for _ in $(seq 1 12); do
  if capture_ui; then
    if has_label "Choose fictional encrypted file"; then seen_import=1; fi
    if has_label "Check recovery state"; then seen_recovery=1; fi
  fi
  if [[ "$seen_import" == 1 && "$seen_recovery" == 1 ]]; then break; fi
  # Viewport-relative gesture, no fixed element coordinates or injected result.
  adb -s "$SERIAL" shell input swipe "$((w/2))" "$((h*75/100))" \
    "$((w/2))" "$((h*25/100))" 280
  sleep 1
done
[[ "$seen_import" == 1 && "$seen_recovery" == 1 ]] ||
  { echo "::error::First-launch large-text Import/Recovery actions not reachable"; exit 1; }
assert_no_vault
# Real 200% Recovery controls are now in the viewport; let the actual native
# compositor settle, then capture both the bottom controls and original top.
sleep 2
shot first-launch-200-percent-recovery
for _ in $(seq 1 12); do
  if capture_ui && has_label "Your fictional journal"; then break; fi
  adb -s "$SERIAL" shell input swipe "$((w/2))" "$((h*25/100))" \
    "$((w/2))" "$((h*75/100))" 280
  sleep 1
done
wait_label "Your fictional journal"
sleep 2
shot first-launch-200-percent
assert_no_vault
echo "PASSED NATIVE_200_PERCENT_RECOVERY_SCROLL"

# Return to normal-scale first launch and use the actual visible Create button.
adb -s "$SERIAL" shell settings put system font_scale 1.0
adb -s "$SERIAL" shell am force-stop "$PACKAGE"
launch
wait_label "Create a fresh fictional journal"
capture_ui
tap_label "Create a fresh fictional journal"
wait_label "Your Pages"
if ! adb -s "$SERIAL" shell run-as "$PACKAGE" \
  test -s files/nj_apk02_library_fixture/journal.sqlite3; then
  echo "::error::Scripted fictional encrypted database not created"
  exit 1
fi
shot fictional-library-after-create
echo "PASSED NATIVE_EXPLICIT_FICTIONAL_CREATE"

adb -s "$SERIAL" shell am force-stop "$PACKAGE"
launch
wait_label "Your Pages"
if ! adb -s "$SERIAL" shell run-as "$PACKAGE" \
  test -s files/nj_apk02_library_fixture/journal.sqlite3; then
  echo "::error::Fictional encrypted database lost after force-stop"
  exit 1
fi
echo "PASSED NATIVE_CREATED_LIBRARY_REOPEN"
echo "NOT physical Android phone/tablet, visual founder sign-off, recovery-key usability, or private diary approval"
