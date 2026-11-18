# Slower onboarding handoffs — 2026-11-15

Target: RMX2156, Android 12/API 31, device `X4GEAYDMWGAUI7WG`. Installed `build/app/outputs/flutter-apk/app-debug.apk` with `adb install -r -d`; app data was preserved. The device was left on question 1. No live feeds or detector counts were tested.

| Requirement | Check | Result |
| --- | --- | --- |
| FR-001: distinct page fade, pause, and entrance; Rook scene continuity | App-flow widget test checks intermediate opacity, delayed swap, repeated tap, background pause/resume. Device UI trees and screenshots cover preview → Rook → Okay → question 1. | Passed; frame timing is widget-tested because this device has no working `screenrecord`. |
| FR-002: question heading/options and navigation handoff | Question and app-flow widget tests cover answer branches, forward/Back, delayed heading/options, reduced motion, background pause, and large text. | Passed. |
| FR-002A: staged story and black beat | Story widget tests cover projection, recall, impact, exit pause, background pause, and reduced motion. | Passed. |
| Draft cleanup | App-flow test checks completion removes question and recall drafts after the Today transition. | Passed. |

Commands: `flutter test --no-pub test/features/onboarding/app_flow_screen_test.dart test/features/onboarding/onboarding_question_screen_test.dart test/features/onboarding/onboarding_story_screen_test.dart --reporter compact` (46 passed); `flutter analyze --no-pub` (three pre-existing Rive boolean deprecation infos, no onboarding findings); `flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false --android-project-arg=ksp.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process` (passed); `flutter test --no-pub --reporter compact` (113 passed, 1 existing History personal-best failure).

Captures: `first-page.png`/`.xml`, `rook-page.png`/`.xml`, `rook-reveal.xml`, `okay-page.xml`, and `question-one.png`/`.xml`. The UI trees confirm the intended labels and controls; screenshots confirm settled layouts. TalkBack spoken output remains an open release gate.
