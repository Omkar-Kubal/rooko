# Debug event-counter pilot — RMX2156, 2026-11-08

## Scope and setup

- Device: RMX2156, Android 12/API 31, one account and one device family.
- Target versions: Instagram `454.0.0.54.77`; YouTube `21.44.534`.
- Sync Scroll debug builds used exact-version, separately consented transient text-key estimates. The user enabled Sync Scroll Accessibility; the in-app test consent was acknowledged. No source text, digest, feed screenshot, media, or UI hierarchy was saved. A live scrcpy mirror was used only to confirm viewer route and distinct settled advances. Only ordinal and aggregate deltas are retained here.
- Counts were read from Sync Scroll's local estimated daily aggregate without switching away from the viewer. The day was `2026-11-08` on the device. Today showed a separate estimated value, zero confirmed items, and an inactive limit.
- The acceptance corpus and other device/app versions remain open. These rows are a pilot, not precision or recall estimates.
- The earlier pilot APK was version code `7` and was installed in place. After that pilot, the test consent was turned **off** in Today and verified false in private preferences; the Android Accessibility grant remained user-controlled and enabled. Both versions returned to **Unsupported app version** for new counts. The existing estimated daily aggregates were retained as labeled test artifacts (`22` YouTube and `13` Instagram on `2026-11-08`); they must not be read as personal viewing totals.

## Startup baseline follow-up

The service-restart risk prompted a regression test: when the service attaches to an already visible feed, its first item seeds an in-memory baseline without adding an estimate; a later changed item remains eligible. `DebugEventEstimateTest.serviceStartingInsideAFeedSeedsBaselineWithoutRecountingThatItem` failed before implementation and passed afterward. The service now checks the already foreground root at connection and seeds this baseline only when separate test consent, selected exact-version profile, recognized feed, and a usable key are all present. If Android supplies no root at connection, this safeguard cannot establish the baseline; that path still needs device evidence.

The user re-enabled the separate test consent in Today. Build `8` installed in place on RMX2156 with the Accessibility grant and consent both on, and the previous estimated aggregates still at `22` YouTube and `13` Instagram. A final source correction immediately seeded the observed current key, avoiding suppression of the next item if no event arrives before a swipe. After that correction, the Android suite reported **80 tests, zero failures**, `:app:compileReleaseKotlin` passed, the focused Flutter suite reported **8 tests passing**, and `flutter analyze` reported only five existing Rive deprecation notices. The first visual attempt stopped when the computer-use control reported a user Escape. On a later explicit user request, build `9` was installed and tested as recorded below.

## Build 9 live follow-up

Build `9` (`com.appylab.syncscroll`, Android target SDK 36) installed in place on RMX2156/API 31 with `adb install -r`. The installed version code, user-enabled Accessibility service, selected Instagram/YouTube apps, and separate test consent were verified afterward. Target versions remained Instagram `454.0.0.54.77` and YouTube `21.44.534`. A transient scrcpy mirror verified the viewer and visibly distinct advances; no frame, caption, or raw key was saved. Only ordinal deltas below were retained.

| Viewer/control | Before → after estimate | Ground truth and outcome |
| --- | --- | --- |
| YouTube Shorts entry | `22 → 22` | First visible Short added none; cause not isolated |
| YouTube ordinary Short advances 1–2 | `22 → 23 → 23` | Two distinct items; one hit, one miss |
| YouTube sponsored Short advance | `23 → 23` | Visibly sponsored item added none in this instance |
| YouTube ordinary Short advances 3–4 | `23 → 23 → 23` | Two further distinct items; both missed |
| YouTube stationary hold | `23 → 23` | No repeat estimate observed |
| Instagram Reels entry | `13 → 14` | First visible Reel added one |
| Instagram distinct Reel advances 1–3 | `14 → 15 → 16 → 17` | One estimate per distinct advance |
| Instagram stationary hold | `17 → 17` | No repeat estimate observed |
| Reinstall build 9 while same Instagram Reel stayed open | `17 → 17` | No startup recount in this observed case; grant and consent remained on |
| Instagram next distinct Reel after reinstall | `17 → 18` | Next changed item remained countable |

This small restart check supports the baseline behavior when Android supplies the foreground feed root. The YouTube sample has three misses among four ordinary advances, so build `9` fails the detector accuracy gate. The earlier positive YouTube pilot does not generalize to this sequence. The exact cause of the misses and the no-root-at-connection restart path remain open. Both versions stay estimate-only in debug and unsupported for confirmed/release counting.

## YouTube miss diagnosis, build 10 probe and clean build 11

To investigate the build 9 misses, a temporary debug-only probe logged categorical scan results and counter outcomes for the selected, consented YouTube version. It logged no labels, key values, media, or screenshots. Build 10 was installed in place for this bounded run. The probe was then removed from source, the full Android unit suite passed **80 tests with zero failures**, `:app:compileReleaseKotlin` passed, and clean debug build 11 was built and installed in place. Source search found no remaining `SyncScrollKeyProbe` or `Log.d` in the service. Build 11 retained the user-enabled Accessibility grant and test consent.

The run began at 23 YouTube estimates and ended at 35. Shorts entry added one; nine visually checked ordinary advances each produced one. One further swipe also produced a count, but its distinctness was not visually checked. A visibly sponsored Short added one, confirming the ad-label exclusion is unreliable. The prior three ordinary misses did **not** recur in this sequence, so their individual cause cannot be assigned retrospectively from the aggregate-only build 9 data.

The categorical trace did show the mechanism that can lose items. Immediately after several swipes, the recognized feed briefly contained **two** visible item containers, or one container with **zero** accessible labels. Those scans returned `MissingKey` and cleared the candidate. Later Accessibility events exposed one container with four labels; the key then became available and the candidate settled to `Counted`. For example, one advance moved from `items=2, labels=4, MissingKey` to `items=1, labels=0, MissingKey`, then to `items=1, labels=4, Candidate` and `Counted` about one second after the swipe. The service schedules a follow-up only for `Candidate` or `Waiting`, not `MissingKey`; if Android emits no later event after labels arrive, that item cannot be recovered by the current logic. This is a demonstrated code-path gap and a plausible explanation for missed Shorts, **not proof** of what happened on the three uninstrumented build 9 items.

The sponsored Short's scan remained `sponsored=false` and ended `Counted`, consistent with the earlier observation that a visible ad label was absent from the queried accessible item subtree. No version qualifies for confirmed counting. The subsequent bounded-retry experiment and its remaining signal gap are recorded below.

## Bounded missing-key retry follow-up, builds 12–14

The source change adds up to 1,200 ms of process-local rescans at 150 ms intervals after a recognized feed reports `MissingKey`. It preserves the last accepted key and its 500 ms spacing timestamp while canceling the pending candidate. On service connection inside an already recognized feed, startup suppression now remains active if the initial key is unavailable, until a key can seed the baseline. It stores no new data.

Tests added for accepted-key preservation, spacing, bounded retry deadlines, and startup baseline suppression through missing labels. The focused counter tests and full Android suite passed; the full suite reported **83 tests, zero failures**, and `:app:compileReleaseKotlin` passed. Build `12` tested the retry before diagnostics; build `13` temporarily logged only booleans/counts/outcomes, no text or key; that instrumentation was removed from source. Clean build `14` was built and installed in place on RMX2156/API 31 with Instagram `454.0.0.54.77`, YouTube `21.44.534`, Accessibility on, and separate test consent on. Source search confirmed no diagnostic tag or `Log.d` remains in the service.

On build `12`, one ordinary Short remained uncounted after 2.7 seconds. Build `13` reproduced a distinct Short with visible text rendered over the video: the scan first saw two item containers, then one item with zero accessible labels on every 150 ms retry until the 1,200 ms window expired; the estimate remained unchanged at `36`. This establishes that some visually visible words are not exposed as Accessibility labels and cannot become a text-derived key through retries. Build `14` likewise showed no increment for another visually distinct Short containing video-rendered text. A sponsored Short also counted in the diagnostic run because its visible sponsor signal was absent from the accessible subtree.

The retry can recover labels that arrive late, but it cannot recover labels YouTube never exposes. The three earlier build 9 misses remain individually unattributed; missing accessible labels are a demonstrated plausible mechanism, not a retrospective proof for those exact items. The ad false positive and missed-item behavior leave YouTube unsupported for confirmed counting. Instagram and YouTube remain debug estimates only; the retained YouTube aggregate `36` is a test artifact and not a personal total.

## RMX structural-signal check, YouTube 21.44.534

To check the next privacy-safe identity route, the existing ten-minute structural and separately gated identity-relation markers were enabled on RMX2156/API 31 while the signed-in YouTube Shorts viewer was foreground. Five distinct Short advances produced **51 bounded structural rows**. The probe stored only app/version, static resource IDs, event type/indexes, coarse time, class/child counts, visibility/scroll state, coarse bounds, and categorical same/changed relations; it did not read content labels or save keys. After review, both markers and the bounded output were removed. Only `profileInstalled` remains in the app's private files directory.

Every captured event was `TYPE_WINDOW_CONTENT_CHANGED` (`2048`) with `fromIndex=-1` and `toIndex=-1`; no pager transition index was available. The API 33 `uniqueId` signal reported `api_unavailable` on API 31. Node-handle relations were mostly `same`, with occasional `changed` during transitions. Topology and state relations fluctuated during animations, then returned to `same` on settled scans. Settled child counts varied, but neither those counts nor the relations gave a consistent per-item identity across five distinct items. The visible Shorts remained recognized, so the failure was item identity rather than feed detection.

Conclusion: the exact-version RMX signal set tested so far has no reliable item key from either accessible text or structural relations. Bounded label retries can only help when text labels eventually appear. Structural transitions may support a separately labeled transition estimate, but they cannot be promoted to item counts without fresh stationary/revisit/false-positive validation. Keep YouTube `21.44.534` unsupported for confirmed counting.

## First debug build: viewer and control results

| Route and ground truth | Estimated count delta | Observation |
| --- | ---: | --- |
| Instagram Reels entry, first visible item | +1 (`0 → 1`) | Viewer title and Reels tab visually checked |
| Instagram Reels, 10 distinct settled advances | +10 (`1 → 11`) | Each advance coincided with exactly one estimate |
| Instagram stationary hold and one visible revisit to the prior Reel | 0 | Total stayed 11 |
| Instagram Reels later re-entry to a new first item | +1 (`11 → 12`) | New visible item on re-entry |
| Instagram Home, three feed scrolls | 0 | Home tab visually checked; total stayed 12 |
| YouTube Shorts entry, first visible item | +1 (`0 → 1`) | Shorts viewer visually checked |
| YouTube Shorts, nine distinct ordinary advances | +9 (`1 → 2`, then `2 → 8`, then `9 → 11`) | Each ordinary advance coincided with one estimate; two unsuccessful swipe gestures were excluded |
| YouTube Shorts, three distinct sponsored advances | `0, +1, +1` | Sponsored handling inconsistent; total reached 12 |
| YouTube stationary/unsuccessful gestures and one visible revisit | 0 | No extra estimate in these controls |
| YouTube Home, three feed scrolls | 0 | Home tab visually checked; total stayed 12 |

The ordinary-item run had long enough observation intervals to read a settled item and aggregate. It does not measure subsecond detection latency, rapid-skip recall, unseen duplicate counts, or behavior on other feeds.

## Sponsored-item follow-up

The revised build added a strict `Sponsored`/`Paid promotion` label check inside the allowlisted item subtree. On a later visually confirmed sponsored YouTube Short, the estimate still changed `15 → 16`. A bounded debug diagnostic on that same visible ad reported one visible item candidate with a key, `itemSponsored=false`, and zero matches from Android's `findAccessibilityNodeInfosByText("Sponsored")`. The label visible in the mirror was not available through these queried Accessibility fields at that moment. This does not rule out a different structural ad signal.

Installing diagnostic builds while the same sponsored item remained foreground coincided with `16 → 18`. The exact cause of each extra count cannot be separated between process-local key rotation, service re-entry, and changing accessible labels. This is a concrete restart/duplicate risk for the debug prototype. The diagnostic log contained only booleans and small counts and was removed from source after the investigation; no content or key was logged.

## Acceptance map

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-005, FR-010 | Selected exact versions and separate consent | Device package/service/preference checks; debug profile tests | Instagram/YouTube test versions only; release lookup returns no profile | TikTok, Facebook, Snapchat, TikTok Lite and other versions uncovered |
| FR-011, FR-014 | Feed recognition and stationary suppression | Verified Reels/Shorts viewer runs, Home controls, failed gestures | No Home increments; no stationary increments in this small run | Larger negative corpus, comments/search/long-video cases open |
| FR-012–015 | Item timing, identity, duplicate behavior | Kotlin counter tests; per-item estimated deltas; revisit and build 9 restart observations | Earlier deliberate ordinary advances worked; build 9 missed three of four ordinary YouTube advances; one Instagram restart/revisit stayed flat | Sponsored frames inconsistent; no-root restart and exact YouTube miss cause open; confirmed gate fails |
| FR-016–017, FR-031 | Local date, confidence, limit separation | Local estimated aggregate, Today status, Flutter platform tests, code review | Estimates separate from the zero confirmed total; Today had no saved limit | Real limit-crossing, cross-midnight and interruption-device tests open |
| M0 gate | ≥200 transitions and ≥100 stationary/non-feed cases per app across ≥3 device families, precision ≥98%, recall ≥90%, zero stationary repeats | This one-device pilot | Not met | No version is confirmed or release-supported by this evidence |

## Verification commands

```text
android/gradlew.bat :app:testDebugUnitTest :app:compileReleaseKotlin --no-daemon -Pkotlin.incremental=false
flutter test test/core/platform/tracking_platform_test.dart
flutter test test/features/today/debug_text_test_dialog_test.dart
flutter analyze
flutter build apk --debug --build-number=<pilot revision> --no-pub --android-project-arg=kotlin.incremental=false
adb -s X4GEAYDMWGAUI7WG install -r build/app/outputs/flutter-apk/app-debug.apk
```

The full Today widget suite still encounters the existing Windows Rive native DLL failure; the isolated consent dialog test passed. Analyzer output has five existing Rive deprecation notices in `rook_mascot.dart`, no new analyzer error.

Original pilot verification: Android `:app:testDebugUnitTest` reported **79 tests, zero failures**; `:app:compileReleaseKotlin` completed. The two focused Flutter files reported **8 passing tests**. `flutter analyze` returned only the five existing Rive info notices. That debug APK built and installed successfully on RMX2156 with version code `7`. Source search found no remaining `SyncScrollAdProbe`, `Log.d`, or `findAccessibilityNodeInfosByText` diagnostic call in the service. Later startup-baseline verification and build status are recorded above.
