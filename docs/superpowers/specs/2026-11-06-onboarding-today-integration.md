# Onboarding, Counting, and Today Integration

## Intent

Wire the locked onboarding choices and consent through Android Accessibility setup into Today, including actual selected-app item counting where an exact detector profile is available. Preserve the onboarding layout and leave History and Settings screens untouched.

## User-approved scope and constraints

- The user explicitly requested actual reel counting for selected apps.
- UX-01–UX-04 define selected apps, optional daily cap, disclosure, affirmative acknowledgement, and a usable no-access route.
- SRS FR-001–005 require clear disclosure, actual permission-state checks, honest support states, and observation scoped to selected apps.
- Counts require an exact package/version profile, recognized feed, distinct item transition, at least 750 ms dwell, and duplicate rejection. An unvalidated or ambiguous transition must fail closed or remain explicitly estimated.
- Do not read or persist feed text, messages, images, audio, or video. Persist only the minimum local day/app count and salted duplicate identity required by the profile.
- A single RMX2156 can prove runtime behavior for installed versions, but cannot satisfy the PRD cross-device detector accuracy gate. Do not claim general confirmed support or let unvalidated estimates trigger hard limits.
- History and Settings are explicitly out of scope.

## Implemented behavior

- Onboarding preferences are the source of selected app IDs and the optional cap. Selected package scope is sent to the native service; Today renders the native day/app snapshot and saved limit state.
- The versioned Flutter-to-Kotlin bridge reads selected apps, consent, actual service state, installed versions, and daily counts; it opens Android Accessibility Settings only after affirmative acknowledgement.
- Kotlin owns package/version profiles and candidate/dwell/dedupe logic. The service reads structural view IDs and page indices for selected packages; it does not access node text, messages, images, audio, or video.
- Local storage contains daily per-app aggregates plus salted temporary duplicate hashes. Today refreshes on return from a target app and reflects actual access revocation.
- The RM's Instagram 454.0.0.54.77 profile is estimate-only. YouTube 21.43.523 has no usable Shorts item-transition signal and is unsupported. TikTok, Facebook, and Snapchat are absent on this device.
- Estimates remain separate from confirmed counts and cannot trigger a hard limit. The app remains usable when access is declined or off. History and Settings app screens were not changed.

## RM device outcome

- Device: RMX2156, Android 12/API 31.
- Instagram: two deliberate Reels swipes added two estimated items. Waiting on a stationary Reel did not add another count.
- YouTube Shorts: the installed version exposed no usable item-transition signal; Today reports “Unsupported app version” and no YouTube count was fabricated.
- After the live test, Sync Scroll was disabled in Android Settings. On return, Today showed “Tracking is off,” “Access off,” two estimated Instagram items, and unsupported YouTube status. The previously enabled BrainPal Accessibility service was restored; Sync Scroll remains off.
- Verification: `flutter test` (18 passed), `flutter analyze` (no issues), Gradle `:app:testDebugUnitTest --rerun-tasks` (passed), and `flutter build apk --debug` (succeeded and installed without clearing app data). The test APK was not left with Sync Scroll Accessibility enabled.

## Open validation gates

The PRD requires at least 200 labeled item transitions and 100 stationary/non-feed cases per launch-supported app across three device families, with precision ≥98%, recall ≥90%, and no repeated stationary increments. RM testing alone cannot close that gate. Any profile not meeting it must be shown as unverified/estimated and must not drive a hard limit. Instagram therefore remains estimate-only, and YouTube 21.43.523 remains unsupported. Revocation state was checked on return, but the FR-006 five-second recovery threshold was not timed as a dedicated benchmark. Recheck current Google Play prominent-disclosure and Accessibility declaration requirements before release; the Play Console declaration/review is not complete.
