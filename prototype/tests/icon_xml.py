#!/usr/bin/env python3
"""Validate staged Android vector XML well-formedness and geometry assumptions.

Design stage only. This does NOT compile a native Android resource with aapt2,
exercise device masks, or validate any signed APK.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1] / "brand" / "android"
ns = "{http://schemas.android.com/apk/res/android}"
files = {
    "background": root / "drawable" / "navin_journal_launcher_bg.xml",
    "foreground": root / "drawable" / "navin_journal_launcher_foreground.xml",
    "monochrome": root / "drawable" / "navin_journal_launcher_monochrome.xml",
    "launcher": root / "mipmap-anydpi-v26" / "navin_journal_ic_launcher.xml",
}
trees = {name: ET.parse(path).getroot() for name, path in files.items()}
assert trees["background"].tag == "shape"
for name in ("foreground", "monochrome"):
    vec = trees[name]
    assert vec.tag == "vector"
    assert vec.attrib[ns + "width"] == "108dp"
    assert vec.attrib[ns + "height"] == "108dp"
    assert float(vec.attrib[ns + "viewportWidth"]) == 108
    assert float(vec.attrib[ns + "viewportHeight"]) == 108
    group = vec.find("group")
    assert group is not None
    for key, expected in (("translateX", 9.8), ("translateY", 9.8),
                          ("scaleX", 0.7), ("scaleY", 0.7)):
        assert abs(float(group.attrib[ns + key]) - expected) < 0.001
    assert len(group.findall("path")) >= 3
    print(f"PASS {name}: 108dp XML valid; group transform as expected")
launcher = trees["launcher"]
assert launcher.tag == "adaptive-icon"
for layer in ("background", "foreground", "monochrome"):
    node = launcher.find(layer)
    assert node is not None and node.attrib[ns + "drawable"].startswith("@drawable/")
    print(f"PASS launcher: {layer} drawable reference")
# These extrema are a conservative geometry review of the hand-authored source
# path data. They do not replace raster clipping QA under actual Android masks.
x_min, x_max = 25.0, 103.0
y_min, y_max = 30.0, 96.0
left, right = 9.8 + .7 * x_min, 9.8 + .7 * x_max
top, bottom = 9.8 + .7 * y_min, 9.8 + .7 * y_max
safe_min, safe_max = 21.0, 87.0  # centered 66x66 within 108x108
assert safe_min <= left < right <= safe_max
assert safe_min <= top < bottom <= safe_max
print(f"PASS foreground design bounding estimate: x={left:.1f}..{right:.1f}, y={top:.1f}..{bottom:.1f} within {safe_min}..{safe_max}")
print("PASS 8 staged icon source checks (NOT aapt2 compilation)")
