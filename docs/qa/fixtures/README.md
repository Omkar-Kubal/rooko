# RMX2156 structural samples — 2026-11-07

These RMX2156 debug probe outputs are not an accuracy corpus. For those samples, no node text, descriptions, media, screenshots, OCR, account names, or raw item tokens were read or stored. The user enabled Sync Scroll Accessibility for these selected-app samples; the probe marker and output files were removed from the phone afterward.

## Current package-validated samples

The final probe admitted only resource IDs with the selected app's `package:id/name` prefix and a static-name character pattern. Each event row has nine tab-separated fields: monotonic time rounded to 100 ms, app ID, installed version, event type, from index, to index, source resource name, static resource IDs, and per-node structural features. Node features contain resource name, class name, child count, scrollable/selected/visible flags, and bounds rounded to 32 pixels. The capture marker expires after ten minutes; output is capped at 128 KB.

| File | Scope | Rows | Finding |
| --- | --- | ---: | --- |
| `2026-11-07-rmx2156-instagram-features-entry.tsv` | Instagram Reels entry | 40 | Reels pager and video container visible; no identity field |
| `2026-11-07-rmx2156-instagram-features-transition.tsv` | Instagram hold/swipe/hold | 28 | Container bounds/visibility changed during swipe animation; no pager item transition |
| `2026-11-07-rmx2156-instagram-feature-actions.tsv` | Instagram action times | 4 | Coarse monotonic timestamps for hold, swipe, hold |
| `2026-11-07-rmx2156-youtube-features-entry.tsv` | YouTube home entry | 5 | Not a Shorts screen |
| `2026-11-07-rmx2156-youtube-features-shorts-entry.tsv` | YouTube Shorts entry | 19 | Shorts recycler and player container visible |
| `2026-11-07-rmx2156-youtube-features-transition.tsv` | YouTube hold/swipe/hold | 12 | Recycler structure stayed stable; player child count/bounds changed during transition; no item ID |
| `2026-11-07-rmx2156-youtube-feature-actions.tsv` | YouTube action times | 4 | Coarse monotonic timestamps for hold, swipe, hold |

All 104 nine-field feature rows passed the allowed-character audit. The observed layout changes can indicate animation or loading; they do not identify a short. Neither sample establishes continuous exposure or supplies TP/FP/FN labels. Keep both exact versions unsupported for new counts.

## Superseded exploratory files

`2026-11-07-rmx2156-structural-01.tsv`, `2026-11-07-rmx2156-structural-02.tsv`, `2026-11-07-rmx2156-youtube-controlled.tsv`, and `2026-11-07-rmx2156-youtube-actions.tsv` were captured before package-prefix filtering was added. Their source package for each resource name cannot be reverified. They remain labeled superseded and are excluded from detector-profile and accuracy conclusions.

## API 33+ identity-relation feasibility probe

The debug harness can inspect `AccessibilityNodeInfo.uniqueId` only on API 33 or newer, and only for the observed candidate containers `instagram/clips_video_container` and `youtube/reel_player_page_container`. This field may be null and may identify a view instead of its current feed item. The probe is not a detector profile and cannot enable counting.

Identity inspection has a second, independent opt-in marker: `detector_probe_identity_relations_enabled`, in addition to the ordinary structural-probe marker. A developer/operator must obtain separate affirmative consent for this identity feasibility observation before creating that marker; the existing Accessibility disclosure/acknowledgement does not cover it. The marker expires after ten minutes. Collect only enough supervised same-item and different-item observations to assess continuity.

Raw platform IDs are used only as inputs to a fresh, process-memory HMAC comparison key. Neither raw IDs nor HMAC digests are serialized, logged, or persisted. The identity extension to the bounded `detector_probe.tsv` output adds only the relation labels `first`, `same`, `changed`, `no_value`, `invalid_value`, or `api_unavailable`, scoped to the static candidate node and occurrence; the existing sanitized structural fields remain as documented above. Comparison state is cleared on opt-out/service interruption and is purged within five minutes. The 128 KB output limit is enforced against the complete UTF-8 line before each append. Relation labels describe node-ID continuity; they do not establish item identity without supervised evidence.

The RMX2156/API 31 pass did not create an identity marker or call the API 33+ method. Both exact versions remain unsupported for new counts pending usable identity evidence and the full SRS accuracy gate.

### API 36 emulator identity feasibility result — 2026-11-07

The user selected Instagram and YouTube in Sync Scroll, acknowledged the in-app disclosure, enabled the service, and separately consented to the identity observation. The API 36 Google Play AVD `sync-scroll-preview` (model `sdk_gphone64_x86_64`) ran the current debug build with Instagram `454.0.0.54.77` and YouTube `21.32.4`.

| App/version | Sanitized rows | Candidate observations | Relation labels | Result |
| --- | ---: | ---: | --- | --- |
| Instagram `454.0.0.54.77` | 28 | 26 `clips_video_container` | `no_value` ×26 | No Android node ID was available; continuity could not be tested |
| YouTube `21.32.4` | 2 | 1 `reel_player_page_container` | `no_value` ×1 | No Android node ID was available; second swipe produced no further candidate observation |

These are feasibility observations only. They provide no TP/FP/FN labels, precision/recall, or support evidence. Both exact versions remain unsupported. Only the aggregate labels above were retained; the two markers and bounded emulator output/status files were removed, and Accessibility remains enabled.

During setup debugging, one manual UI-hierarchy read briefly surfaced feed descriptions in transient tool output. No screenshot or feed text was saved to the workspace or emulator files, and target-app UI-hierarchy reads stopped after that diagnostic.
