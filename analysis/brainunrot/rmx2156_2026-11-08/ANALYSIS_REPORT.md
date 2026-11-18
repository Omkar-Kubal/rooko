# BrainUnrot counting-path analysis

Date: 2026-11-08  
Target: Play-installed `com.appgenlabs.brainunrot`  
Device: RMX2156, Android 12 / API 31

## Result

The counting path traced here uses Android Accessibility events and the active Accessibility node tree. It does not use screenshots in the detector path inspected. The app recognizes app-specific Reel/Short surfaces, derives a `videoId`-named token mainly from visible node text and descriptions, applies event/state duplicate checks, then writes an event and daily totals to its local database. The first eligible item can count on feed entry without a dwell check. For later items, 500 ms is a minimum interval since the last accepted state, not proof that the new item stayed visible for 500 ms.

This is a heuristic identity path, not evidence of an official Instagram Reel or YouTube Short ID. Its keys can change with accessible text and can collide. The static pass does not establish that one user-visible item always produces exactly one count.

## Artifact and device evidence

- RMX2156 is a real device on Android 12 / API 31. REA device Evidence: `ev_4832182c32fcc7fac9b17f22d13872dd4713a2083efb997a5c9932b0e5e63d3b`.
- Installed package is `com.appgenlabs.brainunrot`, version `0.0.1`, version code `5`, installed by Google Play. Package Evidence: `ev_7eeac58699174a7833bc468f499fd4e08de9743b092672ae44e4efb266fe4931`.
- Manifest: minimum SDK 29, target SDK 37. The installed build is compatible with the RM's API 31.
- REA pulled the base APK and all three splits successfully. Pull Evidence: `ev_4197dad55c2123d300a143b2b1920e4e73e8f466e341277a103d4e2bcbda1291`. Base APK SHA-256: `4f15f8fc86dee9b772b8c9b79af455d3b8084d4b16e3d93668a56df570c72e82`.
- Launch Evidence: `ev_d46e50b15ec84f433cff6760432bc5f025aae0ec9ddf544e295efb4d3ff78639`; focused-window Evidence: `ev_39674a29a846908dbdb3cc33f39c1d0385a8629c954fabc1f6b74eafb23032ae`. BrainUnrot opened to its `Onboarding` screen.
- At initial intake, the service `com.appgenlabs.brainunrot.services.BrainRotAccessibilityService` was absent from Android's enabled list, Usage Access was off, and overlay access was ignored. No live count was possible then. The user later completed onboarding and enabled access; the subsequent bound-service state and live counts are documented below. The investigator did not change those permissions.

The base APK differs from the earlier AppPure `0.0.1` artifact (`analysis/brainunrot/reanalysis_2026-11-08/0.0.1/base.apk`, SHA-256 `201206e227ecafa36e3a2f737af4999b55cd9e3a34686e1a21d1fbca3006c3a1`). I compared Android SDK `apkanalyzer` DEX output for the current Play build with that earlier artifact. These normalized method bodies match exactly: `onAccessibilityEvent`, `processReelsDetection`, `isReelsCountEligibleEvent`, `isStablePrimaryReelsContentChange`, `startReelsCounterOnMain`, `x52.h` (platform detector), `y62.d` (item-session state), and `v62.w` (event persistence). This establishes those methods are the same across the two inspected artifacts; it does not establish that the full APKs are identical.

## Static mechanism

### Event intake and page recognition

`BrainRotAccessibilityService.onAccessibilityEvent` filters Accessibility event types, queues the app package, class name, event type, and timestamp, then drains the queue on a handler. The detector reads `getRootInActiveWindow()` and rejects a root whose package does not match the reported app.

The service constants include a 150 ms detection interval, a 500 ms deep-scan throttle, up to eight queued signals, and one processed signal per pass. The count gate accepts a view-scroll event (`0x1000`) directly. It can also accept selected window/content changes (`0x20`, `0x800`, `0x400000`) when the detector returns a primary-feed candidate; recent direct interactions and recent panels suppress those changes.

The manifest and detector identify package-specific surfaces for YouTube, Instagram, TikTok, Snapchat, and Facebook. YouTube uses IDs including `reel_recycler` and `reel_player_page_content`; Instagram uses `clips_viewer_view_pager`, `clips_video_container`, `clips_media_component`, and `clips_caption_component`. Snapchat detection distinguishes Spotlight from Stories. The manifest does not include TikTok Lite in its declared package queries.

### Item-token construction

- **YouTube:** The detector reads text or content descriptions from `reel_player_page_content`, falling back to `subtitle_window_identifier` or selected values from an accessible-node map. It normalizes whitespace and uses `yt_` plus up to the first 40 characters. The truncation helper returns a substring; it is not a cryptographic hash.
- **Instagram:** It reads accessible labels around the clips media component, removes UI phrases such as control labels and “Reel by,” and examines the caption component. The primary label is converted with Java `String.hashCode()` and combined with a caption/fallback token; ad cases use an `ig_ad_` prefix. Some fallback strings are kept as truncated text.
- **TikTok:** The detector reads title/description fields from Accessibility nodes and constructs `tt_` keys using Java `String.hashCode()` over visible text.

The event entity is named `ReelsEventEntity` and includes `id`, `packageName`, `videoId`, timestamp, `viewDurationMillis`, and `isAd`. In the YouTube path, the text-derived key is placed in the persisted `videoId` field. This can retain a prefix of feed text; the Instagram path can retain truncated fallback/caption text. Java `String.hashCode()` is also collision-prone and is not a privacy-preserving keyed hash.

### Session de-duplication and persistence

The item-session manager (`y62`) tracks current and previous tokens per package. Its constructor sets a 500 ms transition threshold and a 300-token `LinkedHashSet` limit; when full, it removes the oldest token. The set is process-memory state. The repository also checks existing database events for same-package/same-token duplicates before creating a new row.

The repository write path (`v62.w`) creates a timestamp-plus-UUID event ID, submits a `ReelsEventEntity`, refreshes `ReelsStatsEntity` daily totals and per-source statistics, and broadcasts `REELS_COUNT_UPDATED`. It can update a prior event's `viewDurationMillis` using the elapsed interval. A later verified Shorts entry changed the aggregate from 35 to 36 before any swipe, consistent with the first-item path; its exact timing was not measured.

### Complete counter trace from the Play-installed build

The Play base APK above was inspected directly with Android SDK `apkanalyzer dex code`. Selected class and method dumps are retained in [`code/`](code/), especially [`play_accessibility_service.smali.txt`](code/play_accessibility_service.smali.txt), [`play_x52.smali.txt`](code/play_x52.smali.txt), [`play_y62.smali.txt`](code/play_y62.smali.txt), [`play_v62.smali.txt`](code/play_v62.smali.txt), [`play_dao_day_count.smali.txt`](code/play_dao_day_count.smali.txt), and [`play_dao_event_filter.smali.txt`](code/play_dao_event_filter.smali.txt). This is disassembled bytecode, not recovered original source. The earlier normalized method comparison establishes that the selected counter methods match the separate AppPure build despite differing APK hashes.

| Stage | Observed implementation | Consequence |
|---|---|---|
| Intake | The Accessibility service queues window, content, scroll, and interaction events. A pending detector pass is posted after 150 ms; `shouldThrottleReelsScan` rejects another scan of the same package within 500 ms. It reads `getRootInActiveWindow()` and checks the root package. | Rapid changes can be merged or skipped before item recognition. |
| Feed and item | `x52.h` switches on YouTube, Instagram, Snapchat, Facebook, and TikTok packages, checks app-specific view IDs/labels, and returns a `t52` content, panel, or surface state. YouTube requires Shorts structures such as `reel_recycler` or a fallback surface and rejects some panels and paused states. | A package being foreground is insufficient to establish a Short or Reel. The five branches are static evidence, not five validated apps. |
| Identity | YouTube recursively takes accessible `text` or `contentDescription` from `reel_player_page_content`, then `subtitle_window_identifier` or a bounded node map, normalizes it and stores `yt_` plus up to 40 characters. Instagram combines a Java `String.hashCode()` of an accessible label with caption/fallback data. Facebook constructs a `fb_` key from accessible text; Snapchat builds a Spotlight key from collected node fields; TikTok uses Java string hashes of accessible title/description fields. | These are content-derived heuristics, not official item IDs. Changed captions can split one item; equal/truncated labels can merge different items. Some database `videoId` values can contain feed text. |
| Count eligibility | `isReelsCountEligibleEvent` accepts `TYPE_VIEW_SCROLLED` directly. It also accepts selected window/content changes after panel and interaction suppression. | An eligible event is a trigger, not evidence of sustained viewing. |
| First item | On a new package context, `y62.d` initializes current/pending keys and returns a count immediately when the event is eligible, the key was not in its recent set, and the detector has not marked it as an ad. | There is no one-second or 500 ms first-item exposure gate. |
| Later item | `y62.d` compares a changed key with current/pending keys and checks `now - lastAcceptedAt >= 500 ms`. It can promote and count the new key in that same call. `now` comes from `System.currentTimeMillis()`. | The 500 ms value limits acceptance frequency; it does not time the new item's visibility. Wall-clock changes can affect the interval. |
| Duplicate handling | `y62` keeps a process-memory `LinkedHashSet` of at most 300 keys; clearing feed context resets current/pending state but leaves this set. The repository also searches today's stored events for the same package/key. | A revisit may be suppressed across feed exits and after a process restart if the day row exists. It is not a documented five-minute viewing-session rule. |
| Ads | `x52.o` scans visible text/descriptions for ad labels. The session result `AD` is written with `isAd=true`; the DAO filter excludes ad events from the displayed day count. The repository can reclassify a previously non-ad row as an ad and recompute totals. | Ad recognition depends on accessible labels and can be late or incomplete. A live sponsored frame coincided with one increment, but the aggregate alone cannot prove whether it was misclassified or a delayed earlier write. |
| Persistence/UI | `v62.w` writes `ReelsEventEntity` with package, key, timestamp, duration and ad flag. `k52.l` derives the day count from unique `package + videoId` pairs after ad filtering. A non-ad write broadcasts `REELS_COUNT_UPDATED` for UI/overlay refresh. | “Reels today” is a daily unique-key count, not a verified one-exposure-per-visible-item measure. |

Review points in the retained bytecode: service event intake at `play_accessibility_service.smali.txt:9170`, scheduler at `:6934`, scan throttle at `:7714`, and diagnostic persistence at `:6373`; detector `x52.h` at `play_x52.smali.txt:6091`, recursive accessible-text selection at `:3412`, ad-label scan at `:4008`, and 40-character truncation at `:2174`; item state `y62.d` at `play_y62.smali.txt:327`, promotion at `:149`, and context reset at `:923`; repository write at `play_v62.smali.txt:3380`; DAO day-count and ad-filter methods in the two focused DAO files.

The diagnostic preference `reels_counter_diagnostics` stores package, event type, detection state, skip reason, and a short unsalted SHA-256 digest of a detector signature. The event database separately stores the content-derived `videoId` key. This is a privacy concern for Sync Scroll's design; no BrainRotty private database or feed strings were extracted during this investigation. `UsageStatsManager.queryEvents` appears in a TikTok Live foreground check; it is not in the inspected Shorts/Reels item-count path. Flutter's `ImageReader` references do not establish screenshot-based counting.

`ReelsCounterFloatingService` and `ShortFormTimerFloatingService` provide separate overlay UI. Overlay display requires the app's separate Android overlay access.

## Comparison to Sync Scroll

BrainUnrot's 500 ms acceptance interval and text-derived keys do not satisfy Sync Scroll's one-second exposure rule or its privacy-preserving identity requirement (SRS FR-012–015). Do not copy the text-based key storage into Sync Scroll: the project rules prohibit persisting feed text, and Java `String.hashCode()` does not provide strong or collision-resistant identity. Deleting a screenshot after counting would still capture feed media and is unnecessary for the observed BrainRotty path. Treat the bounded dashboard totals below as observations against a visually checked sequence, not as proof of accuracy.

## Limitations and next evidence

The REA JADX and screen-capture providers could not start their Windows workers because `C:\Windows\Temp` returned access denied. I used Android SDK `apkanalyzer` with the JDK bundled in Android Studio to inspect the pulled APK and REA for device identity, package metadata, APK pull, launch, and focus evidence. No feed content or feed screenshot was captured during that initial intake. The first-launch permission state described earlier is historical; the user later completed onboarding.

## Live setup and home-feed observations (2026-11-08)

After the user completed onboarding, BrainUnrot opened to its Today dashboard on the same RMX2156. No permissions were changed by the investigator. The current state was read as:

- Accessibility enabled: `accessibility_enabled=1`; `enabled_accessibility_services` contains `com.appgenlabs.brainunrot/com.appgenlabs.brainunrot.services.BrainRotAccessibilityService`. REA Evidence: `ev_3bf79528fc90720c6676104319a667434d8430c2e6dbbdf114e8dc096f9f7b88` and `ev_fb61deff0ab8e9129e76e5a9d0f7b94781b133d464fdd91784fe209c2bce40cd`.
- Usage Stats and overlay app-ops both reported `allow` for `com.appgenlabs.brainunrot` (`adb shell appops get ... GET_USAGE_STATS` and `SYSTEM_ALERT_WINDOW`).
- Instagram was `454.0.0.54.77` (package Evidence `ev_1cc4f0e58e2a926d4a8f57acc103dce17fb0ce908b4cc8415a694f155326b8fe`); YouTube was `21.44.534` (package Evidence `ev_525681ba555f6c0d15e032cee306aadc91291da68aa4a8ea639902a87758e78b`).

The BrainRotty dashboard showed `Reels today: 0` before the sequences. The user later clarified that the Instagram swipes were on the home section, not in Reels. Therefore the Instagram count changes below are home-feed observations. The YouTube `/shorts` VIEW intent reported the app's generic `MainActivity`; its short-form route was never verified, so its `0 → 2` dashboard change cannot be attributed to Shorts. The activity metadata was not sufficient to establish either app's visible sub-screen.

The original app-link run is bounded UI evidence, not an accuracy result. It captured no feed pixels, text, or hierarchy; temporary screenshots were taken only after returning to the BrainRotty dashboard and were deleted after reading the count. The launch result and app usage-time changes support that target apps were foregrounded, but that deep-link run does not prove the URLs displayed actual Reels/Shorts items. The initial extended sequence added home controls and repeated transition batches. A later scrcpy observation visually confirmed Reels and distinct settled item advances; its results are recorded below.

### Extended sequence

The extended ledger is in [LIVE_SEQUENCE.md](LIVE_SEQUENCE.md). The original run had no verified Reels/Shorts route: Instagram Home swipes added one count once (`2 → 3`) and the identical repeat added none; YouTube's manifest-declared `com.google.android.youtube.action.open.shorts` action left the total at `3`, with generic `MainActivity`/`InternalMainActivity` focus. The first later Reels attempt changed `3 → 4`, but the user reported that the screen did not scroll. The presumed-tab run changed `4 → 10` but remained unverified. In the visually verified run, a wheel-style scroll was followed by counts `11 → 12 → 13 → 14` while the feed was still moving and settling; a long swipe then produced `14 → 15 → 16`. Those probes may have crossed multiple items and are excluded from the bounded sample. In the later ten-transition sample, checked after a 2-second dwell, BrainUnrot counted exactly one on four, missed four, and counted twice on two. One additional ambiguous movement added a count, and one gesture did not advance. The count stayed stable in two stationary controls. This is preliminary evidence of unreliable counting on the exact RMX2156/API 31 and app-version combination, not a population accuracy estimate. The ADB focus remains generic `InstagramMainActivity`; REA focus Evidence is `ev_2fc73474a408f694ec8fcdf12e3320737fb220a1566feadd8642cac5e8bb8bc7`, and secure-setting Evidence confirms BrainRotty's service remains enabled (`ev_fb61deff0ab8e9129e76e5a9d0f7b94781b133d464fdd91784fe209c2bce40cd`). Reels was visually confirmed in the mirror. No feed captures were saved to workspace files. Temporary dashboard captures were deleted. `dumpsys accessibility` showed BrainRotty bound with scroll/content/window events enabled and no crashed service.

The pattern is consistent with an event-driven text-token heuristic that sometimes misses a newly visible item's accessible text and sometimes treats transition-time content changes as separate items. That is a hypothesis based on the static mechanism and observed count deltas, not a causal trace: no feed strings or token values were collected, and the live results were aggregate-only.

### Visually verified YouTube Shorts sequence

The same RMX2156 had YouTube `21.44.534` and BrainRotty's service enabled and bound throughout; `dumpsys accessibility` showed its scroll/content/window event subscription and no crashed service after the run. A fresh check showed BrainRotty's dashboard at `35`. The YouTube Shorts action opened Home, so the visible Shorts tab was selected and the viewer itself was confirmed before sampling. The first item then raised the overlay to `36` without a swipe. Across ten distinct settled advances, seven ordinary Shorts each coincided with exactly one increment. Three sponsored Shorts coincided with `0`, `0`, and `1` increments. The aggregate moved `36 → 44`; an unsuccessful gesture was excluded. Two stationary checks stayed fixed, two returns to previously viewed items stayed fixed, and three visually confirmed YouTube Home scrolls left the dashboard at `44`. The item-by-item ordinals and deltas are in [LIVE_SEQUENCE.md](LIVE_SEQUENCE.md).

This Shorts sample is stronger than the earlier unverified deep-link run because the route and every distinct advance were checked visually. It is still one account, one app version, one device family, and a small sample. The +1 during a sponsored item may reflect missed ad recognition or a delayed earlier write; the aggregate overlay does not expose row attribution. The exploratory eight-advance Shorts pass (`27 → 35`) had one delayed extra increment and a sponsored miss, but its individual deltas were not retained, so it is reported separately from the bounded ten-advance tally. The Instagram ten-advance sample already showed four exact-one results, four misses, and two double increments. Together these results rule out a general claim that this build reliably maps one visible item to one count on the tested device.

### What this establishes for Sync Scroll

BrainRotty demonstrates a workable *triggering* route: recognize a target app's short-form surface from Accessibility nodes, derive a candidate, and update a local counter after duplicate checks. Its observed key source is accessible content, and its 500 ms rule is an acceptance interval rather than a verified exposure dwell. The live Reels errors and sponsored Shorts inconsistency show that this mechanism does not provide the identity or accuracy evidence needed to enable Sync Scroll's confirmed profiles. Sync Scroll should keep the currently tested Instagram and YouTube versions unsupported until an independently revalidated, privacy-safe item signal and the SRS three-device corpus pass. This REA is comparative evidence, not an approved requirement or an implementation to copy.

### Remaining unknowns

- No private BrainRotty database or raw candidate token was read. The exact cause of each live miss, double count, delayed write, or sponsored increment cannot be assigned to a particular internal branch.
- TikTok, Facebook, and Snapchat have static detector branches but were absent from the RMX2156 package list and were not live-tested. TikTok Lite has no declared package query in the inspected manifest. No accuracy conclusion is available for them.
- The bounded samples do not measure subsecond latency, behavior across a date change or process death, multi-device accuracy, or future app versions. The old unverified home/deep-link batches remain exploratory.
- The REA Android decompiler and screen providers could not start their Windows workers because `C:\Windows\Temp` access was denied. Android SDK bytecode output and in-memory ADB screen previews supplied the static and visual evidence instead. No feed images, raw feed text, or private database contents were saved to the project. A temporary frame created during an earlier handoff was overwritten to zero bytes after cleanup of its image content.
- The REA Evidence IDs in the historical intake section were emitted in an earlier tool session; the current REA session has no retained records to export. The pulled APK and Play-build bytecode dumps in this folder remain the local reproducible static evidence.
