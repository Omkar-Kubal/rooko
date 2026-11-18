# Event-driven counter prototype design

## Intent and authority

The user directed Sync Scroll to replace its inactive one-second detector route with an original approach informed by the BrainRotty REA, and explicitly allowed transient text-derived keys **for testing** on 2026-11-08. This supersedes the earlier structural-only prototype direction. The REA is evidence, not source code: BrainRotty missed and doubled Instagram items in a small RMX2156 sample. No accuracy claim follows from its algorithm.

## Approaches

- Structural-only transition estimates preserve the earlier privacy boundary but the observed Instagram structural signals did not distinguish pager advances, and YouTube's transition evidence was inconclusive.
- Transient text-key estimates use a small allowlist of feed and item nodes and a keyed, process-local digest of selected accessible labels. This can distinguish some items, but captions and labels can change, be absent, or repeat. **Chosen by the user for a debug test.**
- Screenshots/OCR would capture feed media and require a broader permission and privacy change; it is out of this prototype.

## Behavior

- Only a debug build, separate affirmative in-app test consent, selected app, enabled Accessibility service, and exact approved test version can activate the prototype. The initial versions are Instagram `454.0.0.54.77` and YouTube `21.44.534` on RMX2156/API 31. Other apps and versions remain unsupported.
- Recognize the Reels or Shorts viewer from app-specific resource IDs. Ignore home, comments, search, other packages, and ambiguous roots.
- Read accessible label text only within one allowlisted visible item subtree. Normalize it in memory, immediately HMAC it with a random process-local secret, and discard the text. Never log, serialize, or persist the source text or digest. Do not inspect messages or media pixels. No screenshot or OCR path.
- Seed the first eligible item on feed entry. For a later item, require a changed digest while the same feed remains recognized. Accept only when the digest is stable on a second scan after a 150 ms settle delay and at least 500 ms have elapsed since the last accepted item. Use monotonic time. Repeated events and revisits within five minutes do not increment. If the feed is recognized but a scan temporarily has no usable key, cancel only the pending candidate and rescan every 150 ms for at most 1,200 ms. Keep the last accepted key and spacing time during that gap. Clear retry state on key recovery, feed exit, permission loss, consent revocation, or ambiguous root.
- Store only a daily **estimated** aggregate and last-detection timestamp through the existing local store. Estimated counts never trigger the confirmed-only limit. The UI identifies this as a debug estimate, and test consent can be switched off in Today. A release build has no text-key profiles or activation control.
- The user must enable Sync Scroll Accessibility through Android Settings; installation or app consent never changes that system grant automatically.

## Acceptance and limits

- Unit cases: first item, changed item, stationary events, repeated label, revisit, feed exit, missing label, bounded missing-key retries, accepted-key/spacing preservation during a gap, startup baseline suppression through a missing key, 150 ms settle, 500 ms spacing, consent/selection/version gate, and release-build exclusion.
- Build and install a debug APK on RMX2156 without clearing data. With the user-enabled service, compare a supervised, visually verified Reels and Shorts sequence to the estimated deltas. Report misses and doubles. This device test is a pilot; the SRS corpus of 200 transitions and 100 stationary/non-feed cases per app across three device families remains required before any confirmed profile.
- Content-derived keys may merge distinct items or split one item. Process death loses the duplicate memory. No current version can be called confirmed on this evidence.
- The RMX2156 pilot found inconsistent sponsored-item handling and extra estimates around debug APK reinstall while an ad stayed visible. Exact sponsored-label matching inside the item subtree did not catch a later ad; Android's `findAccessibilityNodeInfosByText("Sponsored")` returned zero matches on that visible frame. Ads and process restart are explicit open validation failures, not a supported exclusion rule.
- Follow-up probe found YouTube can leave visible video overlay text outside the accessible item subtree: a distinct Short repeatedly returned one visible item but zero labels for the entire 1,200 ms retry window. The retry cannot recover a signal the app does not expose. Another visibly sponsored Short was counted. These exact-version debug profiles remain estimates and are not supported for confirmed counting.
- On RMX2156/API 31 with YouTube `21.44.534`, a bounded structural identity probe over five distinct Short advances found only content-change events without pager indices. Node-handle relations were mostly same; topology/state changed during animations and returned to same after settling. API 33 `uniqueId` was unavailable. No tested structural relation reliably identified an item; transition-only estimates need separate precision/recall and stationary/revisit evidence.

## Requirement and privacy impact

This is a debug-only test path. PRD/SRS production counting and release accuracy gates remain in force until a later explicit product decision. The debug disclosure must describe temporary access to visible labels and local aggregate retention. `AGENTS.md` and root context record the narrow exception to the structural-only rule. Release code must fail closed.
