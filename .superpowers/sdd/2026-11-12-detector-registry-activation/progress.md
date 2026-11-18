# SDD ledger — plan: docs/superpowers/plans/2026-11-12-detector-registry-activation.md

Pre-flight: Existing interfaces are catalog payload → publisher validation/signature → Android envelope verification → profile resolution → device acceptance. Source and profile tasks feed publication; host/key configuration feeds beta build and device network checks.

Ruling: No `.git` metadata or worktree tooling is available — implement in the user-requested workspace because the workspace itself is the only project checkout and no branch can be selected. Cost if wrong: edits lack branch isolation and commit-based rollback; keep scope additive and report exact files.

Ruling: Do not generate/store a production private key or publish a public registry during this pass — no named custodian, endpoint/domain, or hosting credentials are configured, and external publication/key custody is security-sensitive. Prepare local artifacts and leave deployment steps explicitly open. Cost if wrong: the live network path cannot be demonstrated in this run.

Ruling: Do not add any `supported` profile mappings — current production profile list is empty and existing device pilots do not meet the per-version, three-family accuracy gate. Cost if wrong: users could receive unsupported or inflated counts.

Environment: `node` is installed; `python`, `openssl`, Git repository metadata, host config, and host credentials are absent. Use dependency-free Node.js built-ins for local validator/signing tooling and tests; keep signing-key generation external.

Task 1: local runbook and release configuration gate complete; host, operator, signing custodian, key, and request-log retention remain deployment inputs.
Task 2: local provenance catalog complete with 17 exact entries; archive coverage and weekly maintenance remain open. Five ambiguous YouTube archive labels and one mutable Instagram source were removed from the publishable payload and documented as excluded.
Task 3: complete. `node --test tool/detector_registry/registry.test.mjs` — 15/15 passed. Fresh forced `:app:testDebugUnitTest :app:assembleDebug` — 113 passed, 0 failures/errors/skips; build succeeded. Added an internal test-injected bundle seam to prove exact versions can share one profile ID without populating the production manifest; unknown/disabled versions still fail closed. The service-level revocation regression passes. Release gate rejects missing inputs and accepts the throwaway test P-256 public key with a placeholder URL.
Task 4: blocked by missing per-version labeled corpora across three device families; keep production profile map empty.
Task 5: publisher and release gate are ready; signed publication and configured beta APK are blocked by Task 1 inputs and production signing.
Task 6: rebuilt APK installed on RMX2156/API 31 with `adb install -r` (app data preserved); after an immediate post-install task was removed by the OEM, a subsequent cold launch resumed `MainActivity` (PID 21388), with no app crash entry and no permission changes. This is an install/launch smoke check only; live resolution, accuracy, and multi-device acceptance remain blocked by Tasks 1 and 4.
Task 7: local maintenance and response runbook complete; live renewal, revocation, outage, and key-custody drills remain blocked by Task 1.

TDD fix record: CLI supported-profile signing regression failed with `profile ID is not bundled for this package`, then passed after passing the bundled manifest and sequence/clock through signing and verification. Slow-header deadline test failed at the expected elapsed-time assertion, then passed after adding an overall scheduled disconnect and per-read remaining timeout. Catalog hygiene test failed at 23 entries, then passed with the 17 exact entries and no mutable current-version link.

TDD integration follow-up: exact-version shared-profile tests failed to compile because the resolver had no injectable profile-map parameter; adding a parameter defaulted to the existing empty production map made both shared-ID and disabled/unknown cases pass. `DetectorRegistryRevocationTest` passed through the service replacement path. Fresh final suite: 113 Android tests, zero failures/errors/skips; Node publisher: 15/15; debug APK SHA-256 is recorded in the QA README.

Final review: Fresh `/root/implementation_review` review found the publisher manifest bug, ambiguous archive labels, a missing total transport deadline, and a mutable Instagram source URL. All findings were addressed. Follow-up review found no critical or important issue in the resolver seam or service-level revocation test; it identified a minor QA overstatement of FR-019, which was narrowed to say detector crash/false-positive threshold handling, coverage-gap recording, and history readability remain unproven. No production profile was added. Production accuracy, live host behavior, Play/privacy deployment checks, and service disablement with a validated production candidate remain unreviewed because their required inputs and evidence do not exist.

No commit was created because this workspace has no `.git` metadata. Earlier device evidence: `docs/qa/2026-11-12-detector-registry-activation/rmx2156-final-today.png` and `rmx2156-final-ui.xml`. The latest rebuilt APK launch was verified by `am start -W`, PID, resumed activity, and crash-buffer checks without collecting another screenshot.
