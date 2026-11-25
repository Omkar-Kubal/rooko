# SocialLite reverse engineering findings

**Status:** Targeted APK static REA plus one bounded, no-permission Android launch observation completed. The investigation traced the shipped feed-recognition, full-app blocker/schedule/usage-limit, and billing paths. It did not create an account, grant permissions, activate a rule, or make a purchase. Static findings establish code paths, not that they work correctly on a live feed.

## Target and method

- Target: Sociallite -Block Reels&Shorts, Play package `com.sociallite.android`, [Google Play listing](https://play.google.com/store/apps/details?id=com.sociallite.android&hl=en_IN).
- Installed through the official Play route on OPPO CPH2565 / Android 15 (`b5637f72`); installed build is version **3.0.4, version code 262**. The pulled base APK is `artifacts/com.sociallite.android/base.apk`, SHA-256 `06684f4f99bda02146eca696af4b37b94c9d5fa5f63ab700390b2e94551954e6`. Pulled ARM64 and `xxhdpi` splits are retained alongside it.
- REA/JADX 0.7.1 reports Android min SDK 32, target SDK 36, 9,200 classes, and 583 resources for the base APK. Android package/manifest view is complete for that APK.
- Signature inspection finds declared v2 and v3 signers on base and both pulled splits. All declare certificate SHA-256 `835c327bbfbe6f4cc56c9f6344302e56a303c4ff48eef4b0a871812d12c6652d`; the declared source-stamp certificate hash is `3257d599a49d2c961a471ca9843f59d341a405884583fc087df4237b733bbd6d`. This is structural consistency only: APK signatures, certificate trust, authenticity, and stamp are not cryptographically verified by this inspection.
- The first-launch screen was captured once at `captures/app-launch-updated/screen.png` (1080×2400). It shows a large SocialLite promotional panel, “Take your life back,” language selection, and “I already have an account.” No UI action followed. No login, permission grant, app-feed test, purchase, or account creation occurred.
- The Play listing capture remains a separate source (`ev_5964b418af487b1aa216d4637431b777e63e7d3482b8cc3437e73d68a7f87567`): it is observed website content, not APK behavior. Individual review comments and the app’s public FAQ are not treated as code evidence.

## Listing observation (separate from APK evidence)

- At capture time the listing named “Sociallite -Block Reels&Shorts,” publisher “Sociallite,” and displayed in-app purchases, 4.4 stars, 22.6K reviews, 5L+ downloads, and an update date of 11 November 2026. These are volatile listing values.
- Its description claims Accessibility-based foreground-app monitoring and configured limits. It advertises removing short-form feeds, recommendations, Explore/discovery, live streams, shopping tabs, and ads while preserving messages, profiles, direct-shared content, and posting; it also describes optional adult-content blocking through a VPN. These remain developer claims; the code/runtime evidence above supports only a subset of implementation paths and does not verify effectiveness.
- The captured page's Data Safety panel says the developer reports possible collection/sharing of “Personal info” and “Device or other IDs,” encryption in transit, and deletion requests. This sits alongside broad copy about not tracking browsing or selling data. The listing does not resolve data-flow scope; this REA did not inspect network traffic or server retention.
- Three visible recent reviews alleged unexpected blocking outside selected scope, a subscription prompt after onboarding questions, and tracking/support issues on app variants. They are selected, self-reported examples, not representative prevalence or verified behavior.
- The Play accessibility capture did not expose checkout terms, regional pricing, trial, or feature-to-entitlement mapping. SocialLite's public FAQ claims new signups require a subscription and gives US reference prices of $9.99/month or $29.99/year; these are developer-published claims, not observed app prices or evidence of Indian willingness to pay.

## What the APK implements

### Native short-form feed recognition

- The manifest declares a dedicated `NativeReelsBlockerService` Accessibility service. Its static initializer contains Instagram Reels resource IDs `clips_viewer_view_pager`, `clips_viewer_container`, and `clips_viewer_video_layout`, and YouTube Shorts IDs `reel_player_page_container`, `shorts_player_container`, and `reel_recycler` (`ev_bb7f7b43745c6c6778778d0fd7020c66f72864444129889e048402e6a307a90f`).
- A preference named `nativeReelsBlocking` gates this service’s active path. Its `F()` check also excludes child-account mode and requires the device to be interactive and unlocked (`ev_4123a20bb09ad2000c263bf9232e8796d3bc39c95ba54594f4568effd17561d0`). When connected, the service configures broad Accessibility event types, resets worker objects, checks settings, and observes screen state (`ev_a902b6f1c3b95747494e5b3a2a7018af308fc02912317d9de0845fa4aa44828e`).
- Static code therefore supports the claim that the build recognizes native Instagram Reels and YouTube Shorts surfaces. It does **not** prove that it removes those surfaces, preserves every other screen, or works across app versions. No target-app feed was opened in the runtime pass.
- `YouTubePlaybackService` is separately declared as a media-playback foreground service. Its existence does not establish a Shorts-free YouTube replacement or prove how long-form playback is exposed.

### Full-app blocking, sleep schedules, and limits

- A second Accessibility service, `AppBlockerService`, handles foreground window-state events and calls a daily-limit check. Its `enforcePackage` path checks whether the phone is interactive/unlocked, account type and protected-package state, configured blocked packages, sleep/downtime state, content-break/post-mode state, and usage limits. It rate-limits repeated block launches for the same package to 500 ms (`ev_427843311839c1ba713f784c86fd7929f6c587e2dc5b46570cc9d0630096ed77`, `ev_a620974d43c148c23ba5a563e6e661f5a02b523c5f07f93b7e28d35654361c60`).
- When the blocker decides to intervene, it launches an internal `BlockedAppActivity` with the target package, reason, and a sleep-block flag (`ev_8f1f9a534954a579aed6d44438c832720008a9b1f53368464a361cc47c0edf7c`). The activity also recognizes daily-limit block state. This is a full-package boundary distinct from the feed-ID-based service; its live screen and user override behavior were not tested.
- `UsageTracker` persists per-app minute totals in local preferences, snapshots them by date, and uses foreground-session timestamps to add minutes (`ev_a09945bd66afe406205cc3e9069374a2bad26d6366b5b1270b4ba94f4f08b0be`, `ev_8c730f5267165cf6fe66f95ad89aa67587a08e38d6c86fa620a36c9cdf13f944`, `ev_b178f80a87bfcd722c329850b583d79a88f078827530682c12f339157a49e9d8`). `AppBlockerService` requests limit checks from the foreground event path (`ev_5331cf63fef2596e1cbd04514e7c94bb5415b537636f570c01ab9e4edf436e74`). For personal accounts it loads per-app minute caps; child accounts have a separate branch. The code also contains a once-daily prior-day aggregate sync through a parent/account manager when local usage data exists (`ev_1a6b3da799338921822d6ad8b4f7c2e89375647feaa0f4e9d8ee5a460c327223`). Network receipt and data handling were not observed.
- Sleep is not just a named screen: the blocker reacts to preference changes, screen on/off, unlock, wall-clock change, timezone change, and date change. Screen-off cancels pending sleep/quota work; other clock/screen events request fresh checks (`ev_e77df1d6a368c21d42e267a27836a6ed65438f96be9dd2b43ddd9deeb0547432`, `ev_6996b90546e5ba6d5a151ec2c2e01545de4b75b80e69b8df647150d263e6669`). A schedule calculator reads per-weekday bedtime/wake values and configured wind-down and morning-lock buffers; the code defaults to 22:00 bedtime, 07:00 wake, and 30-minute buffers (`ev_2c4a1774136bef0a1677928e4b3c1ff23939c75c45c6465ed145914ed13240eb`).
- Boot, locked-boot, package-replacement, and wake-alarm receivers route back into shared scheduling code (`ev_92a49731c457886510a9b0b73f740d96b2090c4b32109bba3bdbbbc91f54d697`, `ev_74aff0169208fc18ab473f7884091c4b120c0aecd9cad26fb616ed9dae5d14ac`). Manifest permissions include Usage Stats, overlay, exact alarms, and boot reception. Schedule delivery after reboot, OEM process killing, and timezone changes remains untested.

### Subscription and entitlement paths

- The manifest contains Play Billing permission and RevenueCat billing components. `MainActivity.onCreate` initializes a `BillingManager` during app startup (`ev_fd407b0cd6e92eb314be4c00af3b352a4c5cbda906bb46ece68cd3a9443d7ef6`). Its configuration method configures the RevenueCat SDK, fetches customer information, installs a customer-info update listener, and requests offerings (`ev_3f53b3dcf7b5540f1d7f28bdeca91a5c8ffa53ca3918ea681a3cab823aa7893d`).
- Entitlement lookup recognizes `parent` and `pro`; the code checks `isActive` and expiration before treating either as active (`ev_f05b0ffc3d9471f6c6564d8d71c752afb6f8aa966c148582b4d49f8e1d9833d4`, `ev_6ac19a79f4f4d3b9d65666a0875edc51913a620f51696dcd9c0309469d38933d`). Offerings are loaded dynamically from RevenueCat. Static fallback identifiers include `monthly-999`, `monthly-1399`, `yearly-2999`, and a `yearly-4788-7d` offer; code also looks for a `pro_2999` offering and `PAYWALL_DISCOUNT` (`ev_72889cfd8f62d78d4be937a5be6e11da95af24450dae16e0c87e9afdfa12b982`, `ev_dbf8c5ad55b78b62e8d0ebb8e2a0c8c48b3f5c7802ea6613e5ab559f43735de0`, `ev_e33eec2349000eea952f2dcc7679098ef2adbc28afd0c6be17ef964bfc15a0c3`). Identifier suffixes are not verified prices or currencies. The live products and country-specific prices may come from remote offerings.
- Purchase methods invoke Play/RevenueCat purchase flows and emit a `paywall_purchase_started` event (`ev_72889cfd8f62d78d4be937a5be6e11da95af24450dae16e0c87e9afdfa12b982`, `ev_48f33a02c65020af06e7a09347d4b32b5033437c123bfff575e6b884c66b4b44`). Customer-info refresh schedules a billing check every 12 hours while an entitlement is active and a reminder worker path is present (`ev_37aed68cb896c0251b4adef2fb32789ac72dce718fd4dc70807511214ecb7a72`).
- This is positive evidence of a real subscription/entitlement implementation, beyond the Play listing’s “in-app purchases” badge. It does not identify which settings/features require `pro` versus `parent`, the signup/paywall sequence, live price, trial, conversion, or whether any given offering is currently returned by the server. The landing screen capture shows a get-started CTA and existing-account route, not a paywall. No account was created to inspect later screens.

## Comparison to the five Rooko ideas

| Idea | SocialLite evidence | REA conclusion |
| --- | --- | --- |
| Instagram creator-only feed | The Play listing claims intentionally visited profiles can remain accessible. Top-level class-name search for “Creator” returned no match (`ev_220820509c66f9ca091335720750c8ae1214479ea977a52cc66b001c2300dea8`). | No evidence that it filters Reels to an allowlist of creators. Listing language is not code proof. |
| Hashtag-only Instagram Reels | Top-level class-name search for “Hashtag” returned no match (`ev_c85a10c96d2f23568aae1714d4f28268ed14223872b1b20336a5016105d9e35c`). | Not established. The bounded name search cannot rule out an obfuscated or server-driven implementation. |
| YouTube long-form only | Static Shorts resource IDs and a YouTube playback service are present. | Shorts-surface recognition is supported. Whether native Shorts are hidden while long-form remains, and what the private playback service presents, were not observed. |
| Sleep mode | Shared blocker has a time/day schedule calculation, clock and reboot hooks, screen-state checks, and a block surface. | Feature path is implemented in code; real schedule enforcement, exceptions, and override behavior are untested. |
| Reels/Shorts blocker or limit | Separate feed-recognition service plus a generic package blocker and per-app minute counter/limit path. | Both feed-aware and whole-app approaches exist in code. Thresholds, selected-package behavior, intervention timing, accuracy, and plan gates remain unresolved. |

## Evidence index

| Evidence | What it supports |
| --- | --- |
| `ev_5964b418af487b1aa216d4637431b777e63e7d3482b8cc3437e73d68a7f87567` | Controlled Play-listing capture and developer claims. |
| `ev_687500a56341fd1d2912c6e5fe9c1de57f6338ad4d170191965576844cc0a1c1` | Installed package/version on the connected device. |
| `ev_06092da68a5ae253d48fb5ea0a1c3d9b7dec064efa62468f1fddaaffd84da709` | APK package identity, SDK declarations, manifest components and requested permissions. |
| `ev_6e8f9eb83ef247e967f597f45faef763568f7775e80f567560c38509aee35e87` | Base APK declared signer/digest structure; verification limits. Split evidence: `ev_c1b389e4d9871dd50348c0baa731174be5b4b15ec0020dcce14294d27887bb63`, `ev_862fef7a8e3e5ec15b610e5c0d3110460448bc6759a166521b822cb294e3ff42`. |
| `ev_bb7f7b43745c6c6778778d0fd7020c66f72864444129889e048402e6a307a90f`, `ev_4123a20bb09ad2000c263bf9232e8796d3bc39c95ba54594f4568effd17561d0`, `ev_a902b6f1c3b95747494e5b3a2a7018af308fc02912317d9de0845fa4aa44828e`, `ev_95d114092ce9bf248fe8dda08b6c41954107672720afd3cf68d87ad4a9e297a4` | Native feed IDs, activation check, service setup, and event-handler code. |
| `ev_427843311839c1ba713f784c86fd7929f6c587e2dc5b46570cc9d0630096ed77`, `ev_5331cf63fef2596e1cbd04514e7c94bb5415b537636f570c01ab9e4edf436e74`, `ev_8f1f9a534954a579aed6d44438c832720008a9b1f53368464a361cc47c0edf7c` | Full-app enforcement path, limit-check scheduling, and block-activity launch. |
| `ev_a09945bd66afe406205cc3e9069374a2bad26d6366b5b1270b4ba94f4f08b0be`, `ev_8c730f5267165cf6fe66f95ad89aa67587a08e38d6c86fa620a36c9cdf13f944`, `ev_2c4a1774136bef0a1677928e4b3c1ff23939c75c45c6465ed145914ed13240eb`, `ev_92a49731c457886510a9b0b73f740d96b2090c4b32109bba3bdbbbc91f54d697`, `ev_74aff0169208fc18ab473f7884091c4b120c0aecd9cad26fb616ed9dae5d14ac` | Local per-app usage tracker, dated totals, sleep interval calculation, reboot and alarm rescheduling entry points. |
| `ev_fd407b0cd6e92eb314be4c00af3b352a4c5cbda906bb46ece68cd3a9443d7ef6`, `ev_3f53b3dcf7b5540f1d7f28bdeca91a5c8ffa53ca3918ea681a3cab823aa7893d`, `ev_f05b0ffc3d9471f6c6564d8d71c752afb6f8aa966c148582b4d49f8e1d9833d4`, `ev_6ac19a79f4f4d3b9d65666a0875edc51913a620f51696dcd9c0309469d38933d` | App-start billing initialization, RevenueCat configuration, and active/expiry-aware `pro`/`parent` entitlements. |
| `ev_dbf8c5ad55b78b62e8d0ebb8e2a0c8c48b3f5c7802ea6613e5ab559f43735de0`, `ev_72889cfd8f62d78d4be937a5be6e11da95af24450dae16e0c87e9afdfa12b982`, `ev_37aed68cb896c0251b4adef2fb32789ac72dce718fd4dc70807511214ecb7a72` | Dynamic offerings, purchase path, and entitlement refresh / billing-work scheduling. |
| `ev_02ed433c7b43c56875f04b0fb0dbdd08863794f925669b9c16e5cad8c531cad1` | One-frame Android launch capture on OPPO CPH2565 / Android 15, no app interaction. |

## Coverage and unresolved questions

| Question | Status |
| --- | --- |
| What are the exact package/build and primary Android components? | Answered statically for base APK 3.0.4 (262); signer authenticity not verified. |
| Does the build contain Reels/Shorts recognition, sleep schedules, and app limits? | Answered at static-code level; live intervention and reliability remain unknown. |
| Does it filter to selected creators or hashtags? | Unresolved; bounded class-name searches found no matching top-level class names, which is not proof of absence. |
| What is the account and paywall sequence, feature gate mapping, trial, and live pricing? | Partially answered: billing/RevenueCat, `pro` and `parent` entitlements, product identifiers, and purchase calls are present. UI timing, exact gates, remote offering, and prices remain unknown. |
| What happens on current Instagram/YouTube feeds and different device/version combinations? | Unresolved. Only the first launch page was observed; no feed or blocker scenario was exercised. |
| Are counts, time caps, and sleep behavior accurate? | Unresolved; no configured-rule runtime test was run. |
| What exact personal data is sent by the app or its SDKs? | Unresolved. Manifest permissions and a daily usage-aggregate sync path are visible; network bodies and server retention were not inspected. |

### REA limits

- JADX reports source/decompilation warnings in some complex methods; obfuscated helper types retain short names. Conclusions above rely on narrow method paths and manifest facts, not whole-program semantic certainty.
- The configured `apktool` decoder was unavailable, so Android resource tables and localized UI strings were not fully decoded. Top-level class-name search is a bounded discovery probe; it is not a complete feature-absence test.
- No account, permissions, purchase, feed, schedule, or app-blocking scenario was exercised. No signature verification, network capture, server review, multi-version comparison, or cross-device test was performed.
