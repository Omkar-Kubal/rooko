# Live counter overlay QA — RMX2156, 2026-11-08

## Device and build

- Device: OPPO RMX2156, Android 12 / API 31.
- Sync Scroll debug build code 21 was installed in place; app data was retained.
- Installed target apps: Instagram `454.0.0.54.77`, YouTube `21.44.534`.
- Sync Scroll Accessibility was enabled, Instagram and YouTube were selected, the separate debug text-key test consent was enabled, the counter opt-in was enabled, and Android `SYSTEM_ALERT_WINDOW` reported `allow`.
- The retained daily estimates are test data, not personal viewing totals.

## Results

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
|---|---|---|---|---|
| FR-050 | Optional overlay requires separate opt-in and overlay permission | Build 21 Settings showed “Show live counter” enabled; `SYSTEM_ALERT_WINDOW` was `allow`. Turning the switch off set `bubble_enabled=false`; the in-app disclosure was shown before restoring it. | Pass | Permission revoke while the live service was showing a counter was not exercised. |
| FR-050 | Show count with quality marker | Build 21 preview showed `0 EST.` with a close control. Historical viewer runs on earlier builds displayed Instagram and YouTube counts; Instagram changed `21→22` on one swipe and stayed at `22` during a stationary hold; YouTube changed `41→42` on one swipe. | Pass for presentation and earlier live wiring | Those viewer updates were on earlier builds; current build 21 was not freshly run through both viewers. The underlying counts remain estimates and app versions remain unsupported for confirmed counting. |
| FR-050 | Move the counter | Build 21 preview overlay window moved from Android position `(41,245)` to `(393,647)` after a drag. [Successful drag image](live-counter-drag-build21-rmx2156.png) | Pass | Drag bounds are limited to the display; rotation and large-font behavior were not checked. |
| FR-050 | Dismiss and opt out | Closing the build 21 preview removed its overlay window. Turning the Settings switch off also removed the overlay and persisted `bubble_enabled=false`. The feature was restored through its disclosure afterward. | Pass | Closing the live viewer counter itself was not freshly exercised on build 21. |
| FR-050–051 | Hide outside the app / respect system navigation | Sending Home while the build 21 preview was visible removed the overlay. Android Home remained available. Earlier viewer checks also hid the counter on Home. | Pass for preview lifecycle | Service interruption and runtime overlay-permission revocation were not exercised. |
| FR-012–020 | Count accuracy and supported-version qualification | Existing RMX2156 pilots and SRS corpus gate | Not passed | This overlay check does not validate item identity, one-item/one-count accuracy, ad handling, or the three-device accuracy corpus. Instagram and YouTube remain unsupported for confirmed counts. |

## Ready Rook update — build 22

- Rebuilt and installed debug build code 22 in place on RMX2156; no data was cleared. The first build 21 reinstall attempt was rejected as a version downgrade; build 22 installed successfully.
- The overlay now loads the existing `assets/rook/rook-ready-transparent.png` at reduced bitmap resolution, displays Ready Rook to the left of the app label/count, and keeps the 48 dp close target. It remains a static Ready frame, not a game-state animation.
- The Settings preview was opened on device and showed Rook alongside `0 EST.`. [Build 22 Rook preview](live-counter-rook-preview-build22-rmx2156.png)
- Rechecked on RMX2156 after the user asked for another pass: the preview appeared again; dragging it moved the Android overlay position from `(41,245)` to `(390,644)`; tapping its close control removed the preview window while leaving the counter opt-in enabled.
- `SYSTEM_ALERT_WINDOW` remains `allow` and the floating-counter preference remains enabled. After the update, Android returned `null` for `enabled_accessibility_services`, so the live Reels/Shorts viewer was not re-tested on build 22. The user-controlled Accessibility setting was not changed.
- `flutter build apk --debug --build-number=22 --no-pub --android-project-arg=kotlin.incremental=false` succeeded; the APK installed on RMX2156. `:app:testDebugUnitTest` and `:app:compileReleaseKotlin` completed successfully. Build output: `live-counter-rook-build22-gradle.log`.

## Screenshots

- [Build 22 Rook counter preview](live-counter-rook-preview-build22-rmx2156.png)
- [Build 22 Rook preview recheck](live-counter-rook-recheck-rmx2156.png)
- [Build 21 counter preview](live-counter-preview-build21-rmx2156.png)
- [Build 21 successful drag](live-counter-drag-build21-rmx2156.png)
- [Build 21 opt-in disclosure](live-counter-disclosure-build21-rmx2156.png)

Only Sync Scroll Settings/preview screens were retained. No feed screenshots or feed content were saved.

## Verification

- `flutter test test/core/platform/tracking_platform_test.dart` — 8 tests passed.
- `flutter analyze` — no errors; five existing Rive deprecation notices.
- `:app:testDebugUnitTest` and `:app:compileReleaseKotlin` — successful after the Rook update; Kotlin deprecation warnings remain.
- Debug build code 22 was installed in place on RMX2156 before the Rook preview check.

## Live viewer recheck after user re-enabled Accessibility — build 22

- Device: RMX2156/API 31. Sync Scroll version code 22, Instagram `454.0.0.54.77`, YouTube `21.44.534`.
- Android reported `accessibility_enabled=1` and `com.appylab.syncscroll/.SelectedAppAccessibilityService` enabled. In-app tracking consent, separate debug text-key consent, counter opt-in, and `SYSTEM_ALERT_WINDOW=allow` were present.
- No feed screenshots or feed text were saved. Results use the foreground app package, presence of Sync Scroll's `TYPE_APPLICATION_OVERLAY` window, and local aggregate values.

| App/view sequence | Estimate observations | Overlay evidence | Result and limit |
|---|---|---|---|
| Instagram Reels; baseline 23 | Viewer entry/tab action: 24; 2-second stationary hold: 24; one swipe: 25 | Foreground package was `com.instagram.android`; Sync Scroll's overlay window remained present at both checks. | The live counter path appeared on the recognized viewer, stayed stable during this short hold, and the estimate increased after one swipe. Debug estimate only; not a confirmed-count sample. |
| YouTube Shorts; baseline 46 | App launch plus Shorts-tab action: 48 (two increments before a separately measured swipe; attribution unclear); 2-second stationary hold: 48; one swipe: 49 | Foreground package was `com.google.android.youtube`; Sync Scroll's overlay window remained present at both checks. | The live counter path appeared, stayed stable during the hold, and the estimate increased after the swipe. The two entry increments remain unassigned. Debug estimate only. |

The live overlay and Settings preview use the same `FloatingCounterOverlay` view, which loads the Ready Rook bitmap. The Settings preview screenshot verifies Rook rendering without capturing a feed. Neither app version passes the SRS accuracy gate; do not present these debug estimates as exact or supported counts.

After this run the RM phone was left in YouTube with the counter enabled and its overlay visible. The accessibility service remains enabled as granted by the user. Live close-on-dismiss and permission-revocation behavior remain untested on a viewer.

## Global palette update — build 26

- The user clarified that the attached screenshots are layout references and asked the counter to follow the global CSS. The overlay retains Sync Scroll's original Ready Rook and the circular medallion/count badge composition; custom brown/gold fills were replaced with existing monochrome values mirrored between `AppColors` and `web/global.css`.
- `flutter build apk --debug --build-number=26 --no-pub --android-project-arg=kotlin.incremental=false` succeeded. Build 26 was installed in place on RMX2156/API 31; app data was retained. The installed package reports version code 26, target SDK 36.
- With the floating-counter setting enabled and `SYSTEM_ALERT_WINDOW=allow`, the Settings preview displayed Ready Rook, `0 EST.`, and the close target in the updated palette. Screenshot: [build 26 monochrome preview](live-counter-monochrome-build26-rmx2156.png). The preview was visually checked; drag and close interactions were last exercised on build 25, not repeated in this color-only pass.
- At the time of this check, `enabled_accessibility_services` listed only BrainRotty's service; Sync Scroll Accessibility was off. The setting was not changed. Therefore no build 26 Reels/Shorts live-view check was performed. No feed screenshot or feed text was captured.
- This is a presentation-only change under FR-050. Instagram `454.0.0.54.77` and YouTube `21.44.534` remain unsupported for confirmed counts; the SRS accuracy gate and count semantics are unchanged.

## Android 13 presentation check — build 26

- Device: Samsung SM-M325F, Android 13 / API 33. Debug build 26 (`versionCode=26`, `targetSdk=36`) was installed for this check.
- The Settings counter preference was on. Android reported `SYSTEM_ALERT_WINDOW=allow` and `SelectedAppAccessibilityService` enabled when checked. No system permission toggle was performed during this test. The app reported **No apps selected** after onboarding; the app-selection switches were left off.
- Tapping **Preview counter** displayed Ready Rook in the monochrome medallion with `0 EST.` and the close control. [Android 13 preview](live-counter-preview-build26-android13.png). A screenshot taken 11 seconds later showed the overlay gone, confirming the preview's 10-second auto-hide. [After auto-hide](live-counter-auto-hide-build26-android13.png).
- The installed target-app inventory was YouTube `18.12.34`; Instagram was not installed for user 0 (`pm path com.instagram.android` returned no APK). The onboarding also showed YouTube as “Version not checked.” Neither installed state nor version matches a validated counting profile. No live feed run was made, no app was selected, and no feed content was captured.
- This extends FR-050 visual and preview-lifecycle smoke coverage to API 33. It does not validate detector behavior or support for YouTube `18.12.34`; the app/version accuracy gate remains unmet.

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
|---|---|---|---|---|
| FR-050 | Show Rook, count, quality marker; preview ends cleanly | Build 26, Samsung SM-M325F/API 33; Settings overlay screenshot plus screenshot after 11 seconds | Pass for preview rendering and timed hide | Drag/close not re-tested on this device |
| FR-010–017 | Count only selected, supported app versions with correct confidence | No apps selected; YouTube `18.12.34` is unvalidated; Instagram not installed for user 0 | Not tested | Needs app selection and a supported exact version; no accuracy claim follows |
