# Eight-question onboarding check

Target: RMX2156 / Android 12, device `X4GEAYDMWGAUI7WG`.

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-001, FR-002 | Okay opens question 1, and the questionnaire precedes app selection | `flutter test --no-pub test/features/onboarding/app_flow_screen_test.dart test/features/onboarding/onboarding_question_screen_test.dart`; `first-question-ui.xml` | Passed; both screens are in order | None in tested path |
| FR-002 | All eight exact prompts/options, two multi-select questions, six single-select questions, and disabled Continue until selection | Catalog/widget tests; `first-question.png`, `first-question-selected.png`, `second-question-ui.xml` | Passed in tests; first selection state inspected on device | Other seven option sets were not individually screenshot on device |
| FR-002 | “I'm still finding it” skips dream follow-ups; Back returns to the relevant question | Branch widget test; `fourth-question-ui.xml`, `last-question-ui.xml`, `return-ui.xml` | Passed in tests and device route check | None in tested branch |
| FR-002 | Local draft restores Back/restart choices and is erased at completion | Onboarding widget tests, including invalid draft and completion cleanup | Passed | Device data-store inspection not performed |
| FR-002 | Large text can reach all options | 360×640 at 200% text-scale widget test | Passed | TalkBack spoken output not checked on device |

`dart format --output=none --set-exit-if-changed` found no changes, targeted Flutter analysis found no issues, and all 30 onboarding/question tests passed. The debug APK built with Android Studio JBR, a workspace-local SQLite temp directory, and non-incremental Kotlin/KSP. `adb install -r -d` installed it over the existing app without clearing data. The phone was returned to question 1 with its choices unselected. No live Reels/Shorts counting was tested.
