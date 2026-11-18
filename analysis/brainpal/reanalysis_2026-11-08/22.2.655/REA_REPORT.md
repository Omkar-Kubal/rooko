# BrainPal counter REA refresh — 22.2.655

Date: 2026-11-08  
Target: `com.brainrot.android` on RMX2156 (Android 12 / API 31)  
Question: did the latest BrainPal build change how its Reels/Shorts counter identifies and counts items?

## Result

The counter logic is not shown to be fixed in 22.2.655. The latest build still uses candidate signals derived from Accessibility nodes or Android audio playback configuration, a 750 ms dwell threshold, and a five-minute in-memory duplicate cache. Neither path establishes a stable Reel/Short identity. The selected counting methods match 22.1.644 after normalizing obfuscation-only names, and the dedupe and local aggregate-write methods are text-identical.

This is evidence about BrainPal's implementation. It does not validate its displayed total as one count per actual Short, and it does not change Sync Scroll's unsupported status for Instagram or YouTube.

## Artifact and device identity

| Item | Observation |
|---|---|
| Current BrainPal | `22.2.655` (code 655), installed from Google Play; APK SHA-256 `dfcfb0676760d42ead6705b09227737ef0cf50d8a0901727341f886ba2e10c9a` |
| Comparison build | `22.1.644` (code 644); APK SHA-256 `1447f2dfe73e7b9253bda4693b404f6e335e4b2dbf9068cbd74c06a9ed18eaff` |
| Device | RMX2156, Android 12 / API 31, serial `X4GEAYDMWGAUI7WG` |
| YouTube | `21.44.534` |
| Accessibility state | BrainPal `ReelsAccessibilityService` and Sync Scroll `SelectedAppAccessibilityService` were both enabled in Android Settings. Evidence `ev_fdb7912213477263d407b3e6ab3155e5f5dfa8b891d7e4d0f15545200adc4f85`. |
| Usage Access | `adb shell appops get com.brainrot.android GET_USAGE_STATS` returned `ignore`; the fallback route could not be live-tested in this pass. |

The current APK's REA archive inventory is complete within the ZIP scope: 2,751 entries, 954 file occurrences, 844 graph nodes, 953 edges, and no integrity contradictions. Inventory Evidence: `ev_c7402f46de9b8b9f455875f60b0e2bfb4d988d84255bf34b033425ca1e4b421c`; archive inspection Evidence: `ev_18b427ee720f098907d79822d36e7d6d51b46ed238cbf9f4413c0e510e9811da`; summary view Evidence: `ev_77e84ed851b914f4acf97b3f140265ae46d3dac2505703d0bff453a8db13a7a1`.

REA's Android/JADX provider was unavailable on this Windows host because its self-test could not access `C:\WINDOWS\TEMP`. I did not retry that provider. Focused DEX comparisons used Android SDK `apkanalyzer` 23.0 with Android Studio JBR 25.0.3. The APK archive inventory and signature inspection remained available through REA.

## How the Accessibility route counts

1. `ReelsAccessibilityService` receives Accessibility events for monitored apps and traverses the visible node tree. The extracted path reads node text, content descriptions, class names, resource IDs, bounds, and child counts.
2. YouTube recognition and candidate construction use those structural/accessibility values. The candidate helper distinguishes `yt` and `yt_ad` prefixes, combines node-derived pieces, and caps the resulting token at 40 characters. The traced extractor does not produce a stable YouTube Short content ID. Node traversal and candidate logic are preserved in `code/node_tree_collector.smali.txt`, `code/node_tree_projection.smali.txt`, `code/youtube_token_extractor.smali.txt`, and `code/node_candidate.smali.txt`.
3. The shared tracker starts a candidate and finalizes it on a later candidate transition or app/service exit. A segment is eligible after 750 ms. The cache uses an `app|candidate` key and suppresses matching candidates for 300,000 ms (five minutes).
4. A successful finalization increments the local per-app/per-day aggregate and adds dwell duration. The aggregate write receives the app and dwell, not a persisted Reel/Short ID. The displayed daily total is based on those app/day rows.

These rules can de-duplicate a repeated candidate, but they cannot prove that each new candidate represents one new video. Text or layout changes can create a different token while the same video remains visible; repeated or recycled node values can also collapse distinct videos.

## How the fallback route counts

The fallback service polls foreground-app usage and active `AudioPlaybackConfiguration` records. It accepts audio usage `1`, derives a value from `AudioPlaybackConfiguration.toString()`, and uses that value as part of a candidate key. The latest tick also contains quick-return handling, a 30-second no-playback bubble timeout, and synthetic `motion_<timestamp>_<index>` candidates. None of these is a Short/Reel content identifier.

The fallback candidate enters the same 750 ms dwell and five-minute de-duplication tracker, then writes the same local per-app/day aggregate. Because Usage Access was `ignore`, the 22.2.655 fallback path was not exercised live. The earlier 22.1.644 RM session recorded a displayed change from 4 to 5 after a swipe that ended on YouTube's “Recommendations are off” screen; this did not establish one Short per increment. Historical path trace: `../../evidence/fallback_counter_trace.md`.

## Version comparison

Focused method output was compared between the two APKs with `apkanalyzer dex code`:

| Path | Raw comparison | After obfuscation normalization | Finding |
|---|---:|---:|---|
| Shared tracker transition finalizer `uj.c0.e` | 12 changed rows | 0 changed rows | Only short obfuscated class/member references differed. |
| Shared tracker exit finalizer `uj.c0.c` | 2 changed rows | 0 changed rows | Only a renamed obfuscated formatter reference differed. |
| Shared dedupe decision `uj.c0.i` | 0 changed rows | 0 changed rows | Exact method text match. |
| Fallback tick `FallbackReelsCounterService.m` | 194 changed rows | 0 changed rows | Coroutine continuation/field obfuscation accounted for the raw differences; normalized instruction bodies and all 19 string literals matched. |
| Fallback audio key `FallbackReelsCounterService.n` | 4 changed rows | helper calls changed names | Verified old and new wrappers both call `AudioPlaybackConfiguration.getAudioAttributes()` and `.toString()`. |

The count write and duplicate-cache lookup methods were also text-identical across the two builds. In both, the duplicate cache is pruned after 300,000 ms and accepted segments are written as a per-app/day count plus dwell duration. The current extracts are in `code/tracker_finalize_transition.smali.txt`, `code/tracker_finalize_exit.smali.txt`, `code/dedupe_decision.smali.txt`, `code/dedupe_cache_lookup.smali.txt`, `code/count_write_use_case.smali.txt`, `code/count_row_update.smali.txt`, `code/fallback_audio_key.smali.txt`, and `code/fallback_tick.smali.txt`.

## RMX2156 runtime observation

I opened YouTube using the Shorts deep link, waited, and performed one upward swipe. I then filtered logcat locally to retain only lines matching BrainPal's `today_seed: counted reel` aggregate message, extracting only `count` and `dwell_ms`. No matching count line appeared. I did not inspect a screenshot, UI hierarchy, feed text, or media. BrainPal was returned to the foreground afterward; its Accessibility service remained enabled.

This runtime sample is inconclusive: absence of that log line does not prove the displayed total stayed unchanged, and the deep link plus one swipe do not establish ground truth for a completed Shorts transition. Runtime focus evidence shows the YouTube activity was foreground during the attempt (`ev_c40add74d1ffb8f63771cdc1299cd757273893ca5abab4b2577df4e9bb6a3806`); the launch was recorded as `ev_b6b173d917ae7789d37ca5c599911152a4aa214c7c7aeea00755498511435ebd`.

Prior 22.1.644 Accessibility testing on the RMX2156 changed the displayed count from 1 to 3 after one swipe that ended on the same non-Short recommendation screen. Combined with the unchanged counter methods, that remains evidence against treating BrainPal's counter as an exact one-swipe/one-Short count. It does not establish the 22.2.655 live count behavior.

## Conclusion and next step

- The latest build retains the same basic counting design: node/audio-derived candidates, 750 ms dwell, five-minute de-duplication, and local per-app/day aggregates.
- The Accessibility route has no established stable Reel/Short identity in the inspected path. The fallback route uses audio/session-derived keys, not item IDs.
- Neither route is validated as exactly one count per real Reel or Short. The current live sample did not expose an observable aggregate change.
- Sync Scroll should continue to leave the tested Instagram and YouTube versions unsupported until a stable item signal and the SRS accuracy corpus pass. Do not enable transition-only estimates as confirmed counts.
- To live-test BrainPal's fallback route on this RM, the user must enable BrainPal's Usage Access in Android Settings first. No permission was changed by this analysis.

## Boundaries

This report covers BrainPal's counter paths in 22.2.655 and compares the corresponding methods with 22.1.644. It does not repeat unrelated onboarding, network, blocking, analytics, or mascot investigations. Static code shows what the app can do, not which path ran in this session. No screenshots, screen recordings, feed text, media, or UI hierarchy were captured or retained.
