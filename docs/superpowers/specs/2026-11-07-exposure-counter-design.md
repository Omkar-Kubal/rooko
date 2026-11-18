# One-second exposure counter design

## User problem

The daily counter should represent distinct short-form items that were actually visible long enough to qualify, while avoiding guesses from app foreground time or playback activity. The app currently recognizes only one Instagram version, has no stable item identity, and has no confirmed detector profile.

## Source classification

- **User-approved planning target:** support all five apps currently shown in onboarding: YouTube Shorts, Instagram, TikTok, Facebook, and Snapchat. Count a distinct recognized item after it remains visible for one second; include the first item when entering a recognized feed.
- **Existing approved product requirements:** SRS FR-010–021 define per-app/version profiles, fail-closed behavior, confidence separation, duplicate handling, and the multi-device accuracy gate. PRD M0 is the detector proof milestone; the PRD/SRS v2.0 target also lists TikTok Lite, which is intentionally omitted from onboarding.
- **REA observation:** BrainPal's visible count changed without evidence of one increment per Short. Its behavior is not a Sync Scroll accuracy requirement and will not be copied.
- **Proposal for this design:** defer an always-visible overlay until detector profiles pass the accuracy gate. Today continues to refresh the committed count on resume. The optional floating counter remains a separate, permission-gated M2 surface.

## Product behavior

1. Observe only a selected, installed package whose exact app version has an enabled profile and whose recognized short-form feed is visible.
2. When a profile recognizes entry into the feed, identify and seed the first visible eligible item as a candidate. A feed open alone is not a count.
3. Recheck the foreground package, feed signature, and same current item after 1,000 ms of monotonic elapsed time. Commit one exposure if the identity/transition evidence meets that profile's validated rule. A later item starts its own candidate.
4. Items visible for less than 1,000 ms do not count. Repeated events for a stationary item do not count again. A revisit to a confirmed identity within the SRS five-minute window is de-duplicated.
5. The count means “eligible item exposure”; it does not claim the user watched, heard, completed, or attended to the item.
6. Only profiles that pass the SRS accuracy gate may produce confirmed events and drive limits. A profile under evaluation stays estimated; an unknown app version or missing feed/item signal is unsupported or a coverage gap.
7. Today shows confirmed and estimated values separately. It refreshes from the local snapshot on app resume. After profile validation, an optional floating counter may display confirmed totals while a selected supported app is foreground; it requires a separate contextual overlay permission and can be declined or disabled.

## Detection and identity

- Replace the pager index as content identity. An index may be used as transition evidence, never as a stable Reel identity by itself.
- Prefer an opaque stable accessibility token only when an app exposes one and privacy review permits its use. Hash it locally with a rotating app-scoped salt; discard the plain token immediately and retain only a short-lived hash for duplicate rejection.
- If a stable token is unavailable, a profile may use two independent structural signals, as SRS FR-013 allows, and a bounded transition fingerprint only when the profile can re-derive the same signals from the active root at the dwell deadline. A transition fingerprint alone does not prove the same item is still visible. Do not use node text, descriptions containing feed copy, media, screenshots, OCR, audio, or network content.
- If the profile cannot distinguish items sufficiently to pass accuracy and revisit tests, keep it estimated or unsupported. Do not synthesize IDs from pager position and call them exact.
- Keep item candidates in memory. Persist only daily confirmed/estimated aggregates, last-detection timestamps, and salted duplicate hashes subject to the SRS retention window.
- Current implementation boundary: stable tokens are rederived from one configured visible node in the active root. An estimated-only structural strategy now combines a node handle with bounded child topology and rederives the pair from the active root; later items also require an observed pager transition. This pair is not validated as item identity for any observed app version, so `DetectorProfiles` remains empty and no profile is enabled.

## Scope and assumptions

- Initial detector target: the five onboarding apps. TikTok Lite remains a separate PRD/SRS scope reconciliation and is not re-added to onboarding by this work.
- Android app minimum SDK is 29. Validate versions the user can install on supported Android API levels; an app-family label does not imply support for every future third-party version.
- The RMX2156/API 31 structural pass found no independent item identity for Instagram `454.0.0.54.77` or YouTube `21.44.534`. The API 36 `sync-scroll-preview` pilot found no usable Android node ID for Instagram `454.0.0.54.77` or YouTube `21.32.4`. Both versions remain unsupported for new counts; TikTok, Facebook, and Snapchat were not tested. The user-enabled Accessibility service remains on, while temporary probe markers and output files were removed.
- Do not add Usage Stats/audio fallback to confirmed counting. FR-020 permits it only as a separately labeled estimate if a future M0 benchmark supports it.

## Acceptance evidence

For each app/version profile, collect at least 200 labeled item transitions and 100 stationary/non-feed cases across at least three device families and the supported Android range. Compute precision and recall; a profile can be confirmed only with precision at least 98%, recall at least 90%, and zero repeated increments in the stationary cases. Include feed entry, rapid skips, one-second exposure, revisit, stationary feed, comments/search, regular video, app exit, permission loss, and unsupported-version cases.

Ground truth is manually labeled exposure events and coarse timestamps. Store no screenshots, feed text, messages, media, audio, or raw item tokens. Preserve per-app/version results and mark every untested combination uncovered.

## Failure behavior

- Permission revoked, service interrupted, app leaves foreground, or recognized feed disappears: cancel the active candidate and report the corresponding coverage state; do not count foreground time as an exposure.
- App version is unknown, the feed marker changes, or identity is missing: fail closed and show unsupported/partial coverage.
- Detector crashes or exceeds the false-positive gate: disable that profile and keep previously stored totals readable.
- Overlay permission declined or revoked: omit the floating counter; detector and Today remain usable.

## Requirement impact

Implemented after plan review: PRD and SRS now define a 1,000 ms foreground-visible exposure, allow a candidate for the first eligible item on recognized feed entry, and retain the M0 accuracy gate before confirmed status. FR-013–017 and the M0/M2 boundaries were clarified alongside those changes. The observed app/version confidence labels remain unsupported because the pilot produced no usable item identity and no accuracy corpus has passed.

## Open follow-up

Investigate whether a privacy-safe structural signal can independently re-identify the visible item from the active root at the dwell deadline. If so, validate it as a separate profile strategy before enabling a profile; otherwise keep the version unsupported. Reconcile TikTok Lite's v2 target with its removal from onboarding.
