# Fallback counter increment trace

Target: `com.brainrot.android`, version `22.1.644`  
APK SHA-256: `1447f2dfe73e7b9253bda4693b404f6e335e4b2dbf9068cbd74c06a9ed18eaff`  
Evidence type: static REA evidence plus Android SDK `apkanalyzer` Smali. No code was run on the RM for this trace.

## Traced path

1. `FallbackReelsCounterService.m` polls `UsageStatsManager.queryEvents` over a recent time window and reads active `AudioPlaybackConfiguration` entries. Its helper `n(configuration)` accepts audio usage `1`, parses the configuration string, and returns that string only when its parser checks pass. The helper `ve.a.h` resolves to `AudioPlaybackConfiguration.toString()`.

2. For each accepted configuration, `FallbackReelsCounterService.c` builds `audio_<package>_<configuration-string>`, then calls `uj.c0.i(candidate, package, "FallbackCounter")`. If the tracker returns true, the service calls `uj.c0.f(candidate, package)` to begin tracking that candidate. `we.d` also maintains foreground-app session timing; its static app set is Snapchat, Facebook, Instagram, YouTube, and TikTok. That duration accumulator is separate from the reel counter update.

3. `uj.c0.i` classifies `package|candidate` through `j2.i.q`. The cache prunes entries only when they are older than 300,000 ms. A match with the current candidate is skipped as the same item; a match in the recent cache is skipped as recently counted; an unseen candidate is accepted. The skip branches finalize the current segment, while the accepted branch allows the fallback service to start tracking the new candidate.

4. `uj.c0.f` stores the active app and start time. On a candidate transition, `uj.c0.e` finalizes the segment; on service/app exit, `uj.c0.c` finalizes it. Both compare elapsed dwell with `0x2ee` (750 ms): below that threshold they do not add a reel; at or above it they call `n9.z0.f(dwell, appId)`.

5. The write path in `lh.v` updates the local `DailyReelsAppSplit` row. If the app/day/device row exists, it increments `reelCount` by one and adds the segment dwell to `viewDurationMs`; otherwise it creates a row with count one and the dwell duration. The row is written through the Room DAO. `qh.f.a(statsDate)` then sums `reelCount` across that date's app rows, and `uj.c0` caches the total in its `m` field. The fallback service passes that count to the floating-counter path.

## What this establishes

Static code establishes the five-minute candidate de-duplication interval, the 750 ms minimum dwell, and the per-app daily aggregate that feeds the displayed total. It also shows that the fallback candidate identity is derived from an audio playback configuration string rather than a reel/video content ID.

It does not establish that Android produces a new configuration string for every Short, that every accepted candidate represents exactly one Short, or that the live counter increments once per swipe. The earlier RM fallback observation changed from 4 to 5 after a swipe that ended at YouTube's “Recommendations are off” screen, so it still does not validate a one-swipe/one-count rule.

## Evidence and extracts

- REA method evidence for the fallback service tick: `fallback_counter_tick.json`, Evidence ID `ev_edffca5f35632a3ae1750a2abd8dfa4211c426651a01e4957967de57d0f1b5af`. The saved body is Smali fallback and includes the provider's static-analysis limitations.
- Supplemental extracts from the same APK, produced with Android SDK `apkanalyzer` 23.0 and Android Studio JBR 25.0.3:
  - `../scratch/uj_c0.smali` — `4EC778B99CB48F1DFED185F46C3CBAE94EB8D35C9F977AD6AD9ACB676247CF62`
  - `../scratch/j2_i.smali` — `276E03D4169DEBF9CD28573832AEB6897F04384DC78527DA660611BD867281A2`
  - `../scratch/fallback_method_c_apkanalyzer.smali` — `EB9399B202AD735170E0214F06E184E3DE62D1FBDD2C73BB14222029336BE36E`
  - `../scratch/fallback_method_n.smali` — `B0DF4F9DD45F3D0C419CBD75F4726ADCB66D51BBBEEC4721AB7E26DD5059FA36`
  - `../scratch/ve_a_h.smali` — `1C3F577C9207921DA9880F094B721B1156B501863CC14C1122C0364A0BF2659C`
  - `../scratch/we_d.smali` — `34A13C569BE51F4EC2E0D3DAB2E540269D6BC2E8F589AA59D1627A568FE04CC8`
  - `../scratch/n9_z0_f.smali` — `DB4F1D9FBA7410457945B26E7DB7D5C48F13E0131B65B8854F0E6F256E40D69D`
  - `../scratch/lh_v.smali` — `1398719BB10012DA66CBF0338D4EBAF5CB587723CCFF35DAE47020F94CA91D2E`
  - `../scratch/qh_f.smali` — `521E82612A6393976C0F3BB64F390D22199F689FE8B55B0E00168DCBC0CA29F5`
- The Room table identity and insert adapter are documented in `apkanalyzer_preferences_trace.md`; the table is `daily_reels_app_split` with the daily app-split count and duration fields.

These are static observations. They do not show that a candidate passed the checks or that the local write ran during the RM session.
