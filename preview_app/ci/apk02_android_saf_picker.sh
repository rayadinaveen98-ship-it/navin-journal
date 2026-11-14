#!/usr/bin/env bash
# Stage 5B — real Android DocumentsUI picker using ONLY scripted fictional data.
# NOT a personal diary, real user backup, physical device or security audit.
set -euo pipefail

SERIAL=emulator-5554
PACKAGE=com.navinjournal.navin_journal_saf_probe
ACTIVITY="$PACKAGE/.MainActivity"
APK="$SAF_PROBE_ROOT/build/app/outputs/flutter-apk/app-debug.apk"
test -s "$APK"
WORK="$(mktemp -d -p "$RUNNER_TEMP" nj-saf-fictional-XXXXXXXX)"
chmod 700 "$WORK"
cleanup() {
  rm -f "$WORK/hierarchy.xml"
  rmdir "$WORK" 2>/dev/null || true
  adb -s "$SERIAL" shell rm -f /sdcard/nj_fictional_saf_ui.xml >/dev/null 2>&1 || true
}
trap cleanup EXIT

adb -s "$SERIAL" wait-for-device
ready=0
for i in $(seq 1 120); do
  completed="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$completed" == 1 ]] &&
     adb -s "$SERIAL" shell pm path android 2>/dev/null | grep -q '^package:'; then
    ready=1; break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo "::error::API34 emulator PM not ready"; exit 2; }

adb -s "$SERIAL" install -r -t "$APK"
# The only app whose data is cleared is this freshly generated fictional probe.
reset_probe() {
  adb -s "$SERIAL" shell am force-stop "$PACKAGE"
  adb -s "$SERIAL" shell pm clear "$PACKAGE" | grep -q 'Success'
}
marker() {
  adb -s "$SERIAL" exec-out run-as "$PACKAGE" \
    cat files/nj_crash_phase.txt 2>/dev/null | tr -d '\r' || true
}
launch() {
  adb -s "$SERIAL" shell run-as "$PACKAGE" rm -f files/nj_crash_phase.txt
  adb -s "$SERIAL" shell am start -n "$ACTIVITY" --es nj_test_phase "$1"
}
wait_marker() {
  local expected="$1" state
  for i in $(seq 1 120); do
    state="$(marker)"
    if [[ "$state" == "$expected" ]]; then
      echo "PASSED $expected — real API34 Android DocumentsUI, fictional only"
      return 0
    fi
    if [[ "$state" == FAILED ]]; then
      echo "::error::Fictional Android SAF phase failed; $expected was not reached"
      return 1
    fi
    sleep 1
  done
  echo "::error::Timed out before $expected"
  return 1
}
capture_ui() {
  adb -s "$SERIAL" shell uiautomator dump --compressed \
    /sdcard/nj_fictional_saf_ui.xml >/dev/null 2>&1 || return 1
  adb -s "$SERIAL" exec-out cat /sdcard/nj_fictional_saf_ui.xml \
    > "$WORK/hierarchy.xml" 2>/dev/null || return 1
  [[ -s "$WORK/hierarchy.xml" ]]
}
wait_picker() {
  local current activity focused
  # A tight loop of uiautomator accessibility dumps can overload a freshly
  # booted API34 Pixel launcher. Detect resumed activity through lightweight
  # window/activity manager state first; only dump XML when picker is ready.
  for i in $(seq 1 90); do
    activity="$(adb -s "$SERIAL" shell dumpsys activity activities \
      2>/dev/null | grep -E 'topResumedActivity|mResumedActivity' | head -n 3 || true)"
    focused="$(adb -s "$SERIAL" shell dumpsys window \
      2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' | head -n 3 || true)"
    current="$activity $focused"
    if echo "$current" | grep -Eiq 'documentsui|documents.ui'; then
      return 0
    fi
    if echo "$focused" | grep -Eiq 'Application Not Responding'; then
      echo "::error::Android emulator launcher/system ANR blocked picker"
      echo "::error::Last nonsecret app phase: $(marker)"
      return 1
    fi
    if [[ "$(marker)" == FAILED ]]; then
      echo "::error::Probe reported error before document picker"; return 1
    fi
    sleep 1
  done
  echo "::error::Actual Android DocumentsUI did not become foreground"
  echo "::error::Last nonsecret app phase: $(marker)"
  adb -s "$SERIAL" shell dumpsys window 2>/dev/null |
    grep -E 'mCurrentFocus|mFocusedApp' | head -n 3 || true
  return 1
}

# Inspect the actual Android accessibility hierarchy, not a screenshot, OCR,
# hardcoded pixel position, synthetic ActivityResult, or ADB-injected file URI.
node_center() {
  python3 - "$WORK/hierarchy.xml" "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
pattern = re.compile(sys.argv[2], re.I)
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception:
    raise SystemExit(1)
matches = []
for node in root.iter("node"):
    attrs = node.attrib
    if not any(pattern.search(attrs.get(key, "")) for key in
               ("text", "content-desc", "resource-id")):
        continue
    bounds = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
                      attrs.get("bounds", ""))
    if not bounds:
        continue
    x1, y1, x2, y2 = [int(v) for v in bounds.groups()]
    if x2 <= x1 or y2 <= y1:
        continue
    matches.append((attrs.get("clickable") == "true",
                    (x1 + x2) // 2, (y1 + y2) // 2))
if not matches:
    raise SystemExit(1)
matches.sort(reverse=True)
print(matches[0][1], matches[0][2])
PY
}
tap_label() {
  local pattern="$1" coords
  for i in $(seq 1 20); do
    if capture_ui && coords="$(node_center "$pattern")"; then
      # Expected trusted coordinates extracted from on-device Android UI.
      adb -s "$SERIAL" shell input tap $coords
      return 0
    fi
    sleep 1
  done
  echo "::error::Required fictional picker control was not found"; return 1
}
select_downloads() {
  # Some emulator images remember Downloads; others start at Recents.
  if capture_ui && grep -q 'text="Downloads"' "$WORK/hierarchy.xml"; then
    tap_label '^Downloads$'
    return
  fi
  if capture_ui; then
    local coords
    if coords="$(node_center 'Show roots|Show navigation drawer|Navigate up|Open navigation drawer')"; then
      adb -s "$SERIAL" shell input tap $coords
      tap_label '^Downloads$'
      return
    fi
  fi
  # A visible toolbar/menu may already be in the selected document root.
  if capture_ui && grep -Eq 'Downloads' "$WORK/hierarchy.xml"; then
    return
  fi
  echo "::error::Unable to navigate to Android Downloads through DocumentsUI"
  return 1
}

wait_roundtrip() {
  local state focused coords
  for i in $(seq 1 90); do
    state="$(marker)"
    if [[ "$state" == SAF_ROUNDTRIP_VERIFIED ]]; then
      echo "PASSED SAF_ROUNDTRIP_VERIFIED — authenticated fictional archive"
      return 0
    fi
    if [[ "$state" == FAILED ]]; then
      echo "::error::SAF import failed; last nonsecret phase: $state"
      return 1
    fi
    if [[ "$i" == 9 || "$i" == 22 ]]; then
      focused="$(adb -s "$SERIAL" shell dumpsys window 2>/dev/null |
        grep -E 'mCurrentFocus|mFocusedApp' | head -n 3 || true)"
      if echo "$focused" | grep -Eiq 'documentsui|documents.ui'; then
        if capture_ui && coords="$(node_center '^(Open|OPEN)
wait_marker SAF_EXPORT_READY
wait_picker
adb -s "$SERIAL" shell input keyevent KEYCODE_BACK
wait_marker SAF_EXPORT_CANCELLED
reset_probe

launch saf_import_cancel
wait_marker SAF_IMPORT_READY
wait_picker
adb -s "$SERIAL" shell input keyevent KEYCODE_BACK
wait_marker SAF_IMPORT_CANCELLED
reset_probe

launch saf_roundtrip
wait_marker SAF_ROUNDTRIP_EXPORT_READY
wait_picker
select_downloads
tap_label '^(Save|SAVE)$'
# Native checks exact encrypted provider readback before the next Open intent.
wait_marker SAF_ROUNDTRIP_IMPORT_READY
wait_picker
select_downloads
tap_label 'navin-journal-FICTIONAL-only'
wait_marker SAF_ROUNDTRIP_VERIFIED

# Only now is the real Android provider export+import round trip accepted.
# Core API34 clean-uninstall recovery and full UI/physical acceptance are
# tracked separately and are NOT implied by this automated picker gate.
adb -s "$SERIAL" shell am force-stop "$PACKAGE"
adb -s "$SERIAL" uninstall "$PACKAGE" | grep -q Success
echo "VERIFIED: real API34 DocumentsUI export cancellation, import cancellation,"
echo "verified ciphertext write/readback, provider re-selection and authenticated"
echo "fictional Telugu current+historical revision after imported-byte equality."
echo "NOT physical OEM/Gboard, manual recovery-key entry or private diary release."
)"; then
          echo "Android DocumentsUI displayed an explicit Open confirmation"
          adb -s "$SERIAL" shell input tap $coords
        fi
      fi
    fi
    sleep 1
  done
  echo "::error::SAF authenticated roundtrip not confirmed; last phase: $(marker)"
  adb -s "$SERIAL" shell dumpsys window 2>/dev/null |
    grep -E 'mCurrentFocus|mFocusedApp' | head -n 3 || true
  if capture_ui; then
    python3 - "$WORK/hierarchy.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
    nodes = list(root.iter("node"))
    packages = sorted(set(n.attrib.get("package", "") for n in nodes))
    print("Foreground UI packages:", ", ".join(p for p in packages if p)[:320])
    print("Fictional test document still visible:",
          any("navin-journal-FICTIONAL-only" in n.attrib.get("text", "")
              for n in nodes))
    print("Open confirmation visible:",
          any(n.attrib.get("text", "").lower() == "open" for n in nodes))
except Exception:
    print("No readable picker UI hierarchy")
PY
  fi
  return 1
}

reset_probe
launch saf_export_cancel
wait_marker SAF_EXPORT_READY
wait_picker
adb -s "$SERIAL" shell input keyevent KEYCODE_BACK
wait_marker SAF_EXPORT_CANCELLED
reset_probe

launch saf_import_cancel
wait_marker SAF_IMPORT_READY
wait_picker
adb -s "$SERIAL" shell input keyevent KEYCODE_BACK
wait_marker SAF_IMPORT_CANCELLED
reset_probe

launch saf_roundtrip
wait_marker SAF_ROUNDTRIP_EXPORT_READY
wait_picker
select_downloads
tap_label '^(Save|SAVE)$'
# Native checks exact encrypted provider readback before the next Open intent.
wait_marker SAF_ROUNDTRIP_IMPORT_READY
wait_picker
select_downloads
tap_label 'navin-journal-FICTIONAL-only'
wait_roundtrip

# Only now is the real Android provider export+import round trip accepted.
# Core API34 clean-uninstall recovery and full UI/physical acceptance are
# tracked separately and are NOT implied by this automated picker gate.
adb -s "$SERIAL" shell am force-stop "$PACKAGE"
adb -s "$SERIAL" uninstall "$PACKAGE" | grep -q Success
echo "VERIFIED: real API34 DocumentsUI export cancellation, import cancellation,"
echo "verified ciphertext write/readback, provider re-selection and authenticated"
echo "fictional Telugu current+historical revision after imported-byte equality."
echo "NOT physical OEM/Gboard, manual recovery-key entry or private diary release."
