# Detector version discovery and fresh-install QA

Date: 2026-11-13

## Outcome

Added a review-only version discovery tool and weekly GitHub Actions workflow. The tool reads the APKPure YouTube and Instagram version indexes, accepts only exact numeric package-scoped paths, excludes channel/variant suffixes, and writes candidates without editing or signing the live registry. A discovery run observed 14 links (5 YouTube, 9 Instagram). Two exact YouTube detail pages were checked: canonical URL and `softwareVersion` matched `21.42.243` and `21.44.528`. Both were added to the local catalog as `catalogued`; the local catalog now contains 20 versions (10 per app), with zero profiles.

The workflow runs every Monday and uploads a 30-day review artifact. This workspace has no Git metadata or remote, so the workflow is defined but not active on GitHub.

The connected RMX2156 did not have Sync Scroll installed at the start of this pass. The 1.0.0/code 1 debug APK installed and launched successfully, then was rebuilt and reinstalled with exact-version debug-only signal profiles for YouTube `21.45.82` and Instagram `455.0.0.51.72`. These candidates reuse previously observed resource IDs and require the separate in-app debug test consent; release builds still reject them. On first launch the app fetched and cached signed registry sequence 1 with digest `32a7421a56c737e22a2f6c0df9776b026c41cd150d4a5c26e45e8c29fcbb8310`. I selected YouTube and Instagram and advanced onboarding to the tracking consent screen. The consent checkbox remains unchecked and Continue is disabled. Accessibility is off and overlay access is denied; I left both unchanged. No feed or counter test ran.

## Acceptance evidence

| SRS | Acceptance behavior | Evidence | Result | Remaining gap |
|---|---|---|---|---|
| FR-010 | Exact installed versions map to validated profiles only | Local catalog test: 20 entries; all catalogued and no profiles. Discovery report found two new source entries, which were added without support mappings. | Fail-closed catalog behavior preserved | Current YouTube `21.45.82` and Instagram `455.0.0.51.72` still have no validated profile. |
| FR-018 | New installs fetch and verify the shared signed registry; failed/expired data fails closed | RMX2156 fresh install cached sequence 1 and the expected signed payload digest; Android registry tests passed. | Pass for first-install fetch/cache | Live endpoint remains v1 with 18 entries; the local 20-entry catalog has not been published. |
| FR-010 / debug-only QA | Current installed versions can enter the separately consented debug signal path without enabling production support | `DebugEventEstimateTest.profileRequiresExactVersionAndDebugBuild`; debug APK reinstalled on RMX2156 with YouTube `21.45.82` and Instagram `455.0.0.51.72`. | Pass for exact-version debug routing; release path remains disabled | The user has not given the separate debug-test consent, so no labels or feed transitions were read. |
| PR-17 / NFR-05 | Registry lookup does not transmit installed app or device details | Existing fixed whole-registry request implementation and request tests; this run only checked local cache sequence/digest. | Pass by implementation and tests | No packet capture in this run. |

## Verification

- `node --test tool/detector_registry/*.test.mjs` — 28 passed, 0 failed.
- `node tool/detector_registry/discover_versions.mjs` — 14 source links observed; after catalog review, 0 candidates remain unreviewed.
- Flutter `flutter test --no-pub` — 50 passed.
- `flutter analyze --no-pub` — exit 0; five existing Rive deprecation info notices.
- `dart format --output=none --set-exit-if-changed lib test` — 29 files unchanged.
- Android `:app:testDebugUnitTest --rerun-tasks` — 119 passed, 0 failures/errors/skips (JUnit XML), including the current-version debug-only routing test.
- Android `:app:assembleDebug :app:validateDetectorRegistryReleaseConfig` — succeeded.
- RMX2156/API 31: APK install succeeded; `MainActivity` resumed and app process remained alive; registry sequence and digest were read from app cache. No Android permissions were changed.
- RMX2156 onboarding: YouTube and Instagram are selected; consent is unaccepted at the in-app disclosure screen; Accessibility remains disabled and overlay permission remains denied.

## Open gates

- Production profiles remain empty. Each exact app version needs at least 200 transitions and 100 stationary/non-feed cases across three device families, with precision ≥98%, recall ≥90%, and zero stationary repeats.
- The RMX2156 is at first-launch Welcome. The user must complete the app disclosure and Android permission setup personally before monitoring tests. The debug label-key signal test requires its own explicit in-app consent.
- Only one device is connected. No profile was marked supported and no count behavior was tested.
- Move registry hosting to a project-controlled HTTPS origin, assign a signing custodian, verify an independent encrypted key backup, and confirm host log retention before production publication. Current sequence 1 expires 2026-12-12.
- The GitHub workflow requires a GitHub repository/remote before its weekly schedule can run.
