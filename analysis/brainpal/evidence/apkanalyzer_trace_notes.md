# Supplemental Android DEX traces

Target: `apk/com.brainrot.android/base.apk`

- SHA-256: `1447f2dfe73e7b9253bda4693b404f6e335e4b2dbf9068cbd74c06a9ed18eaff`
- Tool: Android SDK `apkanalyzer` from command-line tools `23.0`, running with Temurin Java 17.
- Evidence type: static Smali generated from the APK's DEX. These files are supplementary to the REA Evidence JSON and have no REA Evidence IDs. They do not show that a call ran or that a request reached a server.
- REA's JADX provider was unavailable during this continuation because its caller-supplied `jadx-headless-mcp 0.7.1` JAR was not present; no provider was downloaded or installed.

## Commands used

All commands used the base APK above:

```text
apkanalyzer dex code --class com.brainrot.android.services.ReelsAccessibilityService base.apk
apkanalyzer dex code --class uj.c0 base.apk
apkanalyzer dex code --class j2.i base.apk
apkanalyzer dex code --class q0.v1 base.apk
apkanalyzer dex code --class wd.d base.apk
apkanalyzer dex code --class wd.c base.apk
apkanalyzer dex code --class a2.n2 base.apk
apkanalyzer dex code --class com.brainrot.android.BlockReelsOverlayActivity base.apk
apkanalyzer dex code --class com.brainrot.android.network.BrainRotStatsApiService base.apk
apkanalyzer dex code --class lh.y base.apk
apkanalyzer dex code --class ud.e base.apk
apkanalyzer dex code --class jc.y base.apk
apkanalyzer dex code --class com.brainrot.android.network.ScrollUpdateRequest base.apk
apkanalyzer dex code --class com.brainrot.android.network.AppSplitItem base.apk
apkanalyzer dex code --class com.brainrot.android.network.BlockReelsState base.apk
apkanalyzer dex code --class hg.i base.apk
apkanalyzer dex code --class eh.e base.apk
apkanalyzer dex code --class di.m base.apk
apkanalyzer dex code --class oc.d base.apk
apkanalyzer dex code --class n9.z0 base.apk
apkanalyzer dex code --class lc.b base.apk
apkanalyzer dex code --class d1.e base.apk
apkanalyzer dex code --class lc.a base.apk
apkanalyzer dex code --class kc.a base.apk
apkanalyzer dex code --class ng.r base.apk
apkanalyzer dex code --class ng.e0 base.apk
apkanalyzer dex code --class ng.d0 base.apk
apkanalyzer dex code --class ng.l base.apk
apkanalyzer dex code --class ng.h base.apk
apkanalyzer dex code --class ng.p base.apk
apkanalyzer dex code --class jg.n base.apk
apkanalyzer dex code --class jg.l base.apk
apkanalyzer dex code --class jg.f base.apk
apkanalyzer dex code --class jg.h base.apk
apkanalyzer dex code --class gk.a base.apk
apkanalyzer dex reference-tree --references-to jg.f base.apk
apkanalyzer dex reference-tree --references-to jg.h base.apk
apkanalyzer dex reference-tree --references-to ng.h base.apk
apkanalyzer dex reference-tree --references-to xg.c base.apk
apkanalyzer dex reference-tree --references-to xg.d base.apk
apkanalyzer dex reference-tree --references-to wd.c base.apk
apkanalyzer dex reference-tree --references-to wd.d base.apk
apkanalyzer dex reference-tree --references-to com.brainrot.android.network.BrainRotStatsApiService base.apk
```

## Fallback counter increment trace

The targeted follow-up maps the counter state machine. The existing REA service tick record is `fallback_counter_tick.json` (`ev_edffca5f35632a3ae1750a2abd8dfa4211c426651a01e4957967de57d0f1b5af`). Android SDK extracts were generated from the same base APK with `apkanalyzer` 23.0 and Android Studio JBR 25.0.3:

```text
apkanalyzer dex code --class we.d base.apk
apkanalyzer dex code --class com.brainrot.android.feature_fallback_counter.FallbackReelsCounterService --method c(Ljava/lang/String;Ljava/lang/String;Lms/c;)Ljava/lang/Object; base.apk
apkanalyzer dex code --class com.brainrot.android.feature_fallback_counter.FallbackReelsCounterService --method n(Landroid/media/AudioPlaybackConfiguration;)Ljava/lang/String; base.apk
apkanalyzer dex code --class ve.a --method h(Landroid/media/AudioPlaybackConfiguration;)Ljava/lang/String; base.apk
apkanalyzer dex code --class n9.z0 --method f(JLjava/lang/String;Lms/c;)Ljava/lang/Object; base.apk
apkanalyzer dex code --class lh.v base.apk
apkanalyzer dex code --class qh.f base.apk
```

The extract hashes and interpretation are recorded in `fallback_counter_trace.md`. The trace shows an audio-configuration-derived candidate key, five-minute de-duplication, a 750 ms dwell threshold, and local daily per-app count aggregation. It does not establish a one-to-one relationship between candidates and Shorts.

The Smali extracts were written after inspecting the generated methods and model fields. The `five-minute` interval is `0x493e0` milliseconds in the cache-pruning method. The `BrainRotStatsApiService` provider passes `AuthConfig.serverBaseUrl` into Retrofit; the separate literal `https://api.brainpalapp.ai/` in the APK belongs to a feedback API provider, so it is not treated as proof of the stats client's active host.

## Onboarding answer trace

For the onboarding resource cross-reference, `classes.dex`, `classes2.dex`, and `classes3.dex` were extracted from the same base APK to `analysis/brainpal/scratch/onboard-dexscan/`. Their SHA-256 hashes are respectively `8f9a3a3dd73d200d48d908120d78bb6b8c86cdcec892ff2605f02b08458320e0`, `1e086d67cde4c695ac4f52ff79d341f8931af0cd6806535b96b88bb026238ad7`, and `57785cde8f82dd919afaeb03746c0f898f84e8b633121ef06b73b4df85f3de6d`. These focused onboarding commands used the Android Studio bundled JetBrains Runtime `25.0.3`; the earlier supplemental traces above used Temurin Java 17.

The local helper `analysis/brainpal/scratch/scan_dex_resource_refs.js` matches string resource IDs to direct DEX `const` literals. It includes `entry_ob_*`, `ob_question_*`, and `onboarding_handoff_*` strings. From the project root, the command is `node analysis/brainpal/scratch/scan_dex_resource_refs.js analysis/brainpal/scratch/onboard-dexscan analysis/brainpal/evidence/resources_dump.txt`. This is a bounded cross-reference aid, not a complete resource-use index. The current `apkanalyzer_onboarding_resource_refs.json` SHA-256 is `889c32214b92f0b897d56e3cdb8e3ac2d29b1a9cf17bebf878335b4f8e070a0c`.

The onboarding method extracts are in `apkanalyzer_onboarding_trace.smali.txt`, SHA-256 `4737477c59d7b0ad0d07d2e79d4b6aff2829483734778fc6ef043aa426986499`. It records the answer enum, answer handler, `br_*` forwarding, RevenueCat attribute path, analytics event dispatch, and selected Firebase/Meta worker context. The concrete injected `n9.z0` mode and any actual analytics/RevenueCat network requests remain unobserved.

## Separate onboarding handoff trace

`apkanalyzer dex code --class vg.o0 base.apk` supplied the focused `Lvg/o0;` option excerpts in `apkanalyzer_handoff_options.smali.txt`. It shows construction of a separate `Lvg/e0` option vocabulary, including `when_bored` and hour-value identifiers that overlap with the `hg.i` question enum. `apkanalyzer dex code --class kc.a base.apk` identifies `kc.a.q3` as `ONBOARDING_HANDOFF_OPTION_SELECTED` / “Onboarding Handoff: Option Selected”.

The field scan used `node analysis/brainpal/scratch/scan_dex_field_refs.js analysis/brainpal/scratch/onboard-dexscan 'Lkc/a;' q3`. The helper searches encoded DEX field-access instructions across `classes.dex`, `classes2.dex`, and `classes3.dex`. Its JSON output has two hits in `classes.dex` (enum initialization and an enum values-table/accessor method) and no hits in the other two DEX files. This is a bounded direct field-reference scan; it does not find name-based, reflective, ordinal, or otherwise indirect event dispatch, so the absence of a business-code caller in these results does not establish that the event is unused.

The focused state trace in `apkanalyzer_handoff_state.smali.txt` follows `Lvg/n;`'s selected-option map into `Lvg/y;.m`, which writes `handoff_selected_option_count` and `handoff_selected_option_ids` (plus the current page identifiers) into a `JSONObject`. `Lvg/x;.e` maps the `HandoffV1` screen state to `ONBOARDING_HANDOFF_SCREEN_SHOWN`; `Lvg/x;.g` handles `OnHandoffContinueClicked` as `ONBOARDING_HANDOFF_CONTINUE_CLICKED`. Both pass the state JSON to `oc.d`. These are analytics call paths, not evidence of runtime execution or network transmission. The complete focused extract has SHA-256 `57cf362377a0ceff060470f8c91140023e76449d988759731c540f8b0979691d`.

The handoff artifacts were generated from the base APK above and have these SHA-256 hashes:

- `apkanalyzer_handoff_options.smali.txt` — `71a754a922a5c4070fcaa01319300502d07a6aee436f8c74f828d6207cb04f1b`
- `apkanalyzer_handoff_event_refs.json` — `13870fbe392eea2fc74e7a63a8f658a82f49d2abca45a9b34593aae9640f27de`
- `apkanalyzer_handoff_state.smali.txt` — `57cf362377a0ceff060470f8c91140023e76449d988759731c540f8b0979691d`

## NFC blocking-state update trace

The field mapping and callback-side update were extracted from the same base APK with Android SDK `apkanalyzer` 23.0 using the Android Studio JBR selected through `JAVA_HOME`. Commands:

```text
apkanalyzer dex code --class wd.a base.apk
apkanalyzer dex code --class xd.h base.apk
apkanalyzer dex code --class xd.g base.apk
apkanalyzer dex code --class xd.f base.apk
apkanalyzer dex code --class tq.a base.apk
apkanalyzer dex code --class u0.d2 base.apk
apkanalyzer dex code --class com.brainrot.android.core.domain.model.UserBlockingConfig base.apk
apkanalyzer dex code --class tc.h base.apk
```

Focused extracts and SHA-256:

- `../scratch/wd_a.smali` — `17add33353e4aa93b745f95e8dd2aeaaa7bae0435afa68145f9f02182f2310d4`
- `../scratch/xd_h.smali` — `88f523c458e72dd95b410b3d0b3df2d8b35457b75551a1c6d8d962c5ef0682b3`
- `../scratch/xd_g.smali` — `e9f6984d10c90ad0a7fbb1f53d90e6e5c03894b1177db28dcc374310398ba6cf`
- `../scratch/xd_f.smali` — `f2af184142d912e77f5fb524cdd6cbb52365a66bff3ff0ffa0897410ba9b0171`
- `../scratch/tq_a.smali` — `c971a9d589bae1614cf9462ab23320c17d268b1ff89ac28c24d6feac80cda360`
- `../scratch/u0_d2.smali` — `ed49e7c938aae25660321d8dc0f08df6ec5ce9b232833a0acaf7346c07987395`
- `../scratch/UserBlockingConfig.smali` — `8d656c25b672aeedcabce88fa08e485320caf9152c566bf2f5004945030067ef`
- `../scratch/tc_h.smali` — `d918bfc6c010ca74c4a08523ccbed5540ee563e108bad0ca5a9c6bfc8e0cac9`

The interpretation, field mapping, and unresolved runtime/network behavior are in `apkanalyzer_nfc_state_update.md`.

## EntryOnboarding path

The resource scan maps `entry_ob_q1_bored` and `entry_ob_q2_3_6` to `Lng/l;->h`; the resource strings are “When I'm bored” and “3–6 hours”. `Lng/r` defines `q1_when` and `q2_screen_time`; `Lng/e0` and `Lng/d0` define the corresponding option IDs `bored` and `3_6`. `jg.n.c(jg.j)` dispatches `ENTRY_ONBOARDING_SCREEN_SHOWN`; `jg.n.c(jg.f)` validates and stores selections in the `jg.l` ViewModel state map, derives `EntryAnswers`, and calls `oc.d` with `ENTRY_ONBOARDING_OPTION_SELECTED` carrying `screen`, `option`, `selected`, and comma-joined `picks`. Continue dispatches `ENTRY_ONBOARDING_CONTINUE_CLICKED` with the active screen. On completion, `hi.l0.invokeSuspend` calls `ENTRY_ONBOARDING_COMPLETED` with only a `limit` field. These are static call paths; they do not establish runtime event delivery, network transmission, or durable storage. Details and scope are in `apkanalyzer_onboarding_trace.md`.

The focused class outputs were generated with Android SDK `apkanalyzer` 23.0 and Android Studio JBR 25.0.3. Their SHA-256 hashes are:

- `../scratch/entry_jg_n.smali` — `005dc40c9b5ffd2aa8c0edfdf7508809dee92b225b37995dbc8f04ac80a99cec`
- `../scratch/entry_jg_l.smali` — `d364201e0494cc0fa9a829559bb548f68de848c86f7e9a31fe9c4edd977e28e0`
- `../scratch/entry_jg_f.smali` — `e67e94dcdca07e3fe3df4e01d65effbf950adcfe91926b04dee15604700a8d3f`
- `../scratch/entry_jg_h.smali` — `a03f39de044bfcc3aa858b505fe5b69abebb7a44e637245240754aab119fcf49`
- `../scratch/entry_ng_r.smali` — `6a30be0b24ffde54a66bf1b60b5ddcfb011ab45b74e120e867b7623ec56f4bf5`
- `../scratch/entry_ng_e0.smali` — `f5457b8652b670c2ff4f7dc5581b2b78cc436209b233c603955777816c7c7b26`
- `../scratch/entry_ng_d0.smali` — `56851b4eada8a21e373f59134118d8214f2c0bd8d2e371a44b8e79e09221c73e3`
- `../scratch/entry_ng_l.smali` — `0940fb71f966c9e1e7c9b689746b3d57f1507bc422d74464f7a4ece2c6c9dddd`
- `../scratch/entry_hi_l0.smali` — `c401897f817cfdab5aeb3726669955089291bef5daf0a487fe2a8a34f36107a4`
- `../scratch/entry_completed_event_refs.json` — `df10bb30e212c1d0c318201f6e3c266b8ef5fa9e2f791228ff3c4bbbb720eea`
- `apkanalyzer_onboarding_resource_refs.json` — `889c32214b92f0b897d56e3cdb8e3ac2d29b1a9cf17bebf878335b4f8e070a0c`
- `apkanalyzer_handoff_state.smali.txt` — `57cf362377a0ceff060470f8c91140023e76449d988759731c540f8b0979691d`

## UserPref Room persistence follow-up

To verify the Room boundary, I inspected `tc.k`, `tc.e`, `rj.x1`, `UserPrefDatabase`, `UserPrefDatabase_Impl`, `dg.q`, `vc.r`, `of.b`, `po.b`, and `ka.r` from the same base APK. The local extracts are in `../scratch/pref_*.smali`; `apkanalyzer_preferences_trace.md` records the exact schema, insert statements, wrapper path, completion keys, field-reference scans, and SHA-256 values.

The direct field-reference scans used `node scan_dex_field_refs.js analysis/brainpal/scratch/onboard-dexscan 'Ljg/l;' b`, then the same command with field names `d` and `e`. Outputs are `apkanalyzer_entry_state_refs.json`, `apkanalyzer_entry_answers_refs.json`, and `apkanalyzer_entry_prefs_state_refs.json`. They show the selection map and derived answer state are read by the selection/completion logic, while the Room-writing completion helper reads the separate `e` plan/path field. These are bounded static references across the three extracted DEX files, not runtime database observations.

## Extract files and SHA-256

- `apkanalyzer_block_trigger.smali.txt` — `481bec53246773a4b0b452298c79a44e4ef617ff6599f39ba09d04f68c87bd8c`
- `apkanalyzer_reel_dedupe.smali.txt` — `d3513428d53f88196a5cc9eda6dd3c78b886b181cdb2f8259a4684353049b901`
- `apkanalyzer_block_decision.smali.txt` — `b9c2f9762f8587dd952653a454ab743420c1662e37e6d72a25e69a6d85cf26df`
- `apkanalyzer_block_launch.smali.txt` — `5b3dd67fcf3817c7a3f038e34d2946d3ef32aef7a4a253e529f33d45853dc728`
- `apkanalyzer_stats_api.smali.txt` — `1b424e9850d21a6ae3e6218d2277b0ad4562b6bf472253a59df24743e78754c2`
- `apkanalyzer_onboarding_trace.smali.txt` — `4737477c59d7b0ad0d07d2e79d4b6aff2829483734778fc6ef043aa426986499`
- `apkanalyzer_onboarding_resource_refs.json` — `889c32214b92f0b897d56e3cdb8e3ac2d29b1a9cf17bebf878335b4f8e070a0c`
- `apkanalyzer_handoff_options.smali.txt` — `71a754a922a5c4070fcaa01319300502d07a6aee436f8c74f828d6207cb04f1b`
- `apkanalyzer_handoff_event_refs.json` — `13870fbe392eea2fc74e7a63a8f658a82f49d2abca45a9b34593aae9640f27de`
