# Debug estimator restoration

Date: 2026-11-14. Device: RMX2156 / Android 12 (API 31), Instagram `455.0.0.51.72`, YouTube `21.45.82`.

The user requested the old debug counting path back after the validated registry correctly left both installed versions unsupported. The restored path is a separate, off-by-default debug experiment. Settings requires a fresh acknowledgement before enabling it. Its bounded visible labels are immediately hashed with a process-local key; only estimated count events are stored. The shared daily total, Today count pose, and floating counter can use those events. History verification and production profile support remain gated.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-011, FR-017 | Exact-version debug mapping is separate from production profiles; estimated events use the shared count | `DebugEventEstimateTest`, Kotlin unit suite | 133 tests, 0 failures/errors/skips | Live transition accuracy is unmeasured. |
| FR-031, FR-058 | Today can use a count pose with an experimental warning | Flutter Today widget test and full suite | 78 tests passed | No live feed capture after fresh opt-in. |
| FR-050–051 | Experimental feed recognition can show the static-pose counter, subject to overlay/access gates | Native policy wiring inspection; APK installed in place on RMX2156 | Build and install succeeded; exact installed app versions match the allowlist | Live overlay on Reels/Shorts has not been exercised with new consent. |
| FR-055 | Debug estimates cannot establish a verified History day | Production profile fingerprint and day-verification path inspection | Debug profiles do not enter the validated registry | Recheck during a ground-truthed device pilot. |
| NFR-09 | Experiment is unavailable in release runtime | `BuildConfig.DEBUG` gates in native bridge and service, `kDebugMode` Settings gate | Static inspection only | Release artifact scan remains open. |

Verification: `flutter test --no-pub` passed 78 tests; `flutter analyze --no-pub --no-fatal-infos` exited 0 with three existing Rive deprecation infos; `dart format --output=none --set-exit-if-changed lib test` changed 0 of 29 files. Android `:app:testDebugUnitTest :app:assembleDebug` succeeded with Android Studio JBR, `org.sqlite.tmpdir` at `build/sqlite-temp`, in-process non-incremental Kotlin/KSP, and one Gradle worker. APK SHA-256: `90D6CB97C6A1E9CC93A3B685358449722E045B2928497A4D9AAF96A7D7070F66`. `adb install -r` succeeded without clearing app data. The app launched with no crash-buffer entry. The new `debug_counting_experiment_consent_v2` preference is absent on the device, and the Settings accessibility tree shows **Experimental counting — Off · debug build only**. The phone remains on Settings for the user's acknowledgement.

The older pilot observed duplicate estimates and missed Shorts. This build has no new labeled accuracy corpus, so neither version is production-supported and live counting is not yet verified. A live pilot requires the user to enable **Settings → Experimental counting** and acknowledge the disclosure; selected apps, Accessibility, and floating-counter overlay access must also remain enabled.
