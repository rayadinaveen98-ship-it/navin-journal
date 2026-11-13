# Folded Page — approved Stage 3 mark, asset handoff

**Owner decision:** 2026-11-13 — approved option **01 / Folded Page** as the primary visual mark.  
**Visual system:** Still Pages (writing) + Memory Atelier (memories), Midnight Archive for dark theme.  
**Consumer name:** Not approved. "Navin Journal" remains the **internal project name**.  
**Production Android/iOS icon validation:** Not yet performed.

## Source assets

| Artifact | Path | Status |
|---|---|---|
| Selected light mark | [folded-page-approved.svg](../prototype/brand/folded-page-approved.svg) | Approved direction; browser preview |
| Dark mark | [folded-page-dark.svg](../prototype/brand/folded-page-dark.svg) | Design companion; browser preview |
| Adaptive foreground (108x108) | [folded-page-adaptive-foreground.svg](../prototype/brand/folded-page-adaptive-foreground.svg) | Design-stage candidate |
| Adaptive background (108x108) | [folded-page-adaptive-background.svg](../prototype/brand/folded-page-adaptive-background.svg) | Design-stage candidate |
| Monochrome foreground | [folded-page-monochrome.svg](../prototype/brand/folded-page-monochrome.svg) | Design-stage candidate |
| Provisional wordmark lockup | [folded-page-lockup.svg](../prototype/brand/folded-page-lockup.svg) | Internal name only |
| Android vector foreground XML | [drawable/navin_journal_launcher_foreground.xml](../prototype/brand/android/drawable/navin_journal_launcher_foreground.xml) | Staging resource, NOT compiled |
| Android monochrome XML | [drawable/navin_journal_launcher_monochrome.xml](../prototype/brand/android/drawable/navin_journal_launcher_monochrome.xml) | Staging resource, NOT compiled |
| Android background XML | [drawable/navin_journal_launcher_bg.xml](../prototype/brand/android/drawable/navin_journal_launcher_bg.xml) | Staging resource, NOT compiled |
| Android adaptive icon definition | [mipmap-anydpi-v26/navin_journal_ic_launcher.xml](../prototype/brand/android/mipmap-anydpi-v26/navin_journal_ic_launcher.xml) | Staging resource, NOT compiled |

[Adaptive mask and themed-icon preview](../prototype/brand/adaptive-preview.html) simulates circle, squircle, rounded masks and system tint with CSS. It is **not** an Android emulator.

## Geometry and optical rules

Android's layers use 108×108dp. Google's documented inner safe design zone is 66×66dp, centered at x/y 21–87. Source journal geometry from the F1 mark is transformed by scale 0.7, translation 9.8:

- Estimated extrema: x=27.3 to 81.9; y=30.8 to 77.0.
- These extrema are inside 21–87, including the clay bookmark.
- A visible 66dp dashed guide is included in the mask preview.
- The foreground has transparent outer space; the background is full-bleed pine green.
- The themed layer is monochromatic and must be recolored by the Android launcher; it is not intended to retain clay accents.
- Light/dark app UI may use distinct icon tiles, but the future launcher icon does **not** need to change shape or logic when themes switch.

Source review is **not** enough to prove Android vector compatibility: compile with Android SDK/AAPT2 and inspect round, squircle, and themed launcher masks on target devices before shipping.

## Integrated UX areas

- Welcome: larger Folded Page mark and provisional wordmark.
- First-journal setup: same mark to establish continuity.
- Desktop/tablet sidebar: 42px mark, calm wordmark.
- Compact mobile header: 27px mark; hidden in focused Writing Studio.
- The editor's own content canvas remains unbranded and distraction-free.

The design preview still has fictional sample content, no secure vault, no on-device saving, no cloud backend, no backup engine and no APK.

## Sign-off checklist still pending

1. Owner approval of final consumer-facing **name** and wordmark.
2. AAPT2 compile of Android resources and real adaptive/themed launcher tests.
3. Android adaptive mask, iOS home icon and PWA/browser favicon exports at all required sizes.
4. App-store branding, trademark/name availability review (not implied by logo approval).
5. Real phone/tablet and accessibility review.
6. Packaging into actual native project after Stage 4 platform choice.

## Quality evidence

The repository's Stage 3 CI now includes the main UX regression suite and approved-mark rendering/Android XML source checks. Refer to [GitHub Actions](https://github.com/rayadinaveen98-ship-it/navin-journal/actions) for the exact last passing run rather than assuming every commit passes automatically.

Official Android references:
- https://developer.android.com/reference/android/graphics/drawable/AdaptiveIconDrawable
- https://developer.android.com/develop/ui/compose/system/icon_design_adaptive
- https://developer.android.com/distribute/aep/aep-req-theme-app-icons

Do not bundle an SVG from `prototype/` directly into Android expecting Android to render it as a launcher vector drawable; use the staged, validated Android XML resources during native implementation.
