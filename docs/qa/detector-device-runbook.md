# Supervised detector validation on RMX2156

This runbook is for the current single-device pass. It cannot satisfy the SRS three-device-family accuracy gate by itself. Record exact app versions before each run; unknown versions stay unsupported.

1. Confirm the in-app Accessibility disclosure was shown and consent acknowledged. The device owner enables the Sync Scroll service in Android Settings. Verify the service reports enabled on return. Do not turn on another app's service or alter other Accessibility settings.
2. Record device model, Android API, app package/version, profile fixture revision, local date, and a session identifier. Keep the target app and Sync Scroll debug APK versions fixed during a labeled run.
3. Manually label each eligible exposure with a coarse monotonic timestamp and outcome. Run first item on feed entry with no swipe; 999 ms and 1,000 ms dwell; fast swipe; stationary item; reused pager index; revisit within/after five minutes; comments, search, long video, feed exit, app switch/background, service restart, permission loss, and unknown version. Do not record captions, messages, account names, images, audio, video, screenshots, OCR, or raw item tokens.
4. Compare only aggregate confirmed/estimated count changes and coverage states. Record TP, FP, FN, and stationary repeated increments. Calculate `precision = TP / (TP + FP)` and `recall = TP / (TP + FN)` where denominators are nonzero. Track uncovered scenarios explicitly.
5. Stop the run if the profile misidentifies non-feed surfaces, the service loses access, or the app version changes. Leave the version unsupported or estimate-only. At the end, the device owner may turn Accessibility off and verify Today reports tracking off with existing counts still readable.

Before collecting that full corpus, establish a privacy-reviewed item identity signal. The RMX2156 is API 31; the local Android 34 SDK exposes `AccessibilityNodeInfo.getUniqueId()` since API 33, so a feasibility pilot needs an API 33+ device. Check whether the app supplies a value, whether it stays stable for repeated observations of one item, and whether it changes across items. Do not log or persist raw values. If no suitable signal is available, keep the version unsupported and stop before the large corpus.

### API 33+ identity feasibility pilot

This is a separate debug-only experiment, not covered by ordinary Accessibility consent. Obtain a separate, affirmative consent specifically for reading the Android-generated node `uniqueId` on the two candidate item containers. Explain that the test compares short-lived values in process memory and adds only categorical continuity labels to the existing sanitized structural fields in a local, bounded debug file. If the tester declines, do not create the identity marker; the structural probe can still be used without reading IDs.

Use a test device running API 33+ and record its model/API plus exact installed target-app versions. The implementation only inspects the Instagram `clips_video_container` and YouTube `reel_player_page_container`; an unobserved node or app version is outside this pilot. Start with empty probe files, then create both ten-minute markers only after the separate consent:

```powershell
adb shell run-as com.appylab.syncscroll sh -c 'rm -f files/detector_probe.tsv files/detector_probe_status.tsv; touch files/detector_probe_enabled files/detector_probe_identity_relations_enabled'
```

For each selected app/version, enter its short-form feed, observe the same item across multiple accessibility events, then move once to a different item and observe it. Record only coarse action timing outside the app; do not record captions, names, URLs, screenshots, media, or raw IDs. Review only the structural row and relation label (`first`, `same`, `changed`, `no_value`, `invalid_value`, or `api_unavailable`). A `same` or `changed` label is evidence about a node ID at one structural occurrence, not proof of a distinct feed item. Check that one item yields repeatable continuity and a different item changes the ID across repeated attempts. Stop if the IDs are missing, unstable for the same item, or fail to distinguish items.

Stop by removing both markers and deleting the bounded debug output/status files after saving only approved labels:

```powershell
adb shell run-as com.appylab.syncscroll sh -c 'rm -f files/detector_probe_enabled files/detector_probe_identity_relations_enabled files/detector_probe.tsv files/detector_probe_status.tsv'
```

The identity tracker uses a random per-process HMAC key and holds digests in memory for at most five minutes; raw IDs and digests are never written to the probe file. The identity marker expires after ten minutes. On the RMX2156/API 31, do not create this marker or attempt the API call. The API 36 `sync-scroll-preview` pilot ran on 2026-11-07: Instagram `454.0.0.54.77` returned `no_value` for 26 allowed candidate observations; YouTube `21.32.4` returned `no_value` for its one observed candidate, with no new candidate event after a second swipe. No continuity evidence was available, so both versions remain unsupported and must not proceed to the full corpus until another identity signal is found.

### API 36 alternative identity-signal probe

This debug-only experiment compares three candidates on the same allowlisted item containers: Android's `AccessibilityNodeInfo.hashCode()` node handle, a bounded topology signature of the container and its immediate children, and a visible-state signature containing visibility, selection, scrollability, and 32-pixel-bucket bounds. Each value is HMAC-compared in process memory; the bounded output contains only `first`, `same`, `changed`, `no_value`, or `invalid_value` labels. The topology signature is absent when the child list is incomplete, exceeds 16 children, or exceeds 512 characters. No signature is used by the counter.

The ordinary structural marker and the separately consented identity marker are both required. Create them before the Accessibility service reconnects so the service subscribes to the selected target packages. The tester enables or reconnects the service through Android Settings; the agent does not change the secure setting. For Instagram Reels and YouTube Shorts, hold one item for two seconds, move once to another item, and hold for two seconds. Review only relation-label counts for the candidate node. A candidate signal is promising only if repeated observations of one stationary item are `same` and the same signal changes after a swipe across repeated attempts. Structural topology and state are evaluated independently; a signal that changes during a stationary hold or stays the same across items is rejected. This feasibility result alone cannot enable a profile or establish accuracy.

Remove both markers and the bounded output/status files after the run using the cleanup command above. If the tester does not reconnect Accessibility before the ten-minute marker expires, remove the markers and restart the setup later.

For a confirmed profile, the full corpus is at least 200 labeled item transitions plus 100 stationary/non-feed cases per exact app/version, spanning three device families and supported Android APIs. Precision must be at least 98%, recall at least 90%, and stationary repeated increments zero. Enter results in `docs/qa/detector-validation-matrix.md`. A debug build or a small RMX2156 sample does not establish these metrics.
