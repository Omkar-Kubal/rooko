# Automatic Instagram and YouTube estimated counting

Date: 2026-11-14. User direction: remove the debug toggle, start counting after consent and Android access, detect the installed Instagram/YouTube versions automatically, and leave live Reels/Shorts testing to the user.

## Diagnosis and change

The previous estimator cleared its item state every time Today synchronized the unchanged app selection. That allowed the same visible item to become a new candidate after returning to a feed. Its existing service-reconnect baseline method was never invoked. The counter now retains recent item identity across feed exit and unchanged selection updates; on service reconnect to an already visible feed it seeds the current item without incrementing. The estimator is no longer debug gated or controlled by a Settings switch. It resolves the installed version locally and attempts package-scoped Instagram/YouTube feed recognition when no validated profile exists. Missing feed or item signals still stop counting.

The expanded in-app tracking disclosure names transient visible-label reading, process-memory hashing, local estimated counts, and revocation. A new versioned consent key requires existing users to acknowledge this change once in Settings; first-run users encounter it in onboarding. Instagram and YouTube are selected automatically at first-run consent if the user left app selection untouched and they are installed. Overlay setup remains a separate optional grant.

| SRS ID | Check | Result | Remaining evidence |
| --- | --- | --- | --- |
| FR-011, FR-017 | Automatic package/version resolution and no debug switch | Kotlin profile test and Flutter Settings test | The current resource IDs have not been checked on every target-app version. |
| FR-014–015 | Same item on a quick feed return does not recount | Kotlin estimator regression test | Process death while Today is foreground can still lose transient identity. |
| FR-031, FR-058 | Eligible estimated path selects count Rook and shows accuracy note | Flutter Today test | User will check actual Reels/Shorts behavior. |
| FR-050–051 | Overlay still requires separate opt-in/grant and a recognized feed | Policy wiring and build | User will check the live overlay. |
| FR-055 | Estimated path does not verify a History day | Native verification continues to require validated profiles | Full-day device evidence remains open. |

The user expressly asked to run the live counter test themselves. No agent test opened Reels or Shorts or added counts. An assembled APK and passing automated checks establish build behavior, not cross-version counting accuracy or a release-ready detector corpus.

## Final verification and handoff

- `dart format --output=none --set-exit-if-changed lib test`: 29 files checked, 0 changes.
- `flutter test`: 79 passed.
- `flutter analyze --no-fatal-infos`: exit 0 with three existing Rive `boolean` deprecation infos in `lib/features/today/rook_mascot.dart`; no analyzer errors or warnings. Default `flutter analyze` exits 1 for those infos.
- `:app:testDebugUnitTest :app:assembleDebug :app:assembleRelease`: Gradle completed; Android XML results report 134 tests, 0 failures, 0 errors, 0 skipped. After the final Settings copy edit, `:app:assembleDebug :app:assembleRelease --no-daemon --max-workers=1 -Pkotlin.incremental=false -Pksp.incremental=false -Dkotlin.compiler.execution.strategy=in-process` rebuilt both APKs successfully. A plain Flutter APK build encountered a Kotlin incremental-cache failure in `rive_native` and `shared_preferences_android`; the non-incremental Gradle rebuild passed.
- `adb install -r build/app/outputs/apk/debug/app-debug.apk`: `Success` on RMX2156 (Android 12), preserving app data. The installed package reports version `1.0.0`. Neither target feed was opened during this handoff.
- Debug APK: `build/app/outputs/apk/debug/app-debug.apk`, SHA-256 `137ACB8AB69110F4353740F807A9344BF042958E51EDD25601C8509D0627E5A8`.
- Release APK: `build/app/outputs/apk/release/app-release.apk`, SHA-256 `F97FE63147DEB27E462DA928472770689146B3746E6FC188092B18E3E9196AB0`.

The user must acknowledge the revised tracking disclosure once on this existing install before estimated counting can resume. Floating counter visibility also requires its own in-app opt-in, Android overlay grant, and a recognized feed. Installed Instagram/YouTube versions are detected automatically, but new resource layouts may lack the required feed or item signals. Live counting, overlay behavior, and the cross-device accuracy gate remain unverified by the user's direction.
