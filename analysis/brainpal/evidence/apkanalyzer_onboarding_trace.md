# Onboarding answer handling: focused static trace

Target: `../apk/com.brainrot.android/base.apk`  
SHA-256: `1447f2dfe73e7b9253bda4693b404f6e335e4b2dbf9068cbd74c06a9ed18eaff`  
Tool: Android SDK `apkanalyzer` 23.0, using Android Studio's bundled Temurin Java 17.  
DEX resource references: `apkanalyzer_onboarding_resource_refs.json` (SHA-256 `889c32214b92f0b897d56e3cdb8e3ac2d29b1a9cf17bebf878335b4f8e070a0c`). The scan helper is `../scratch/scan_dex_resource_refs.js`; extracted DEX file hashes and commands are recorded in `apkanalyzer_trace_notes.md`.

This is static Smali evidence. It identifies declared call paths, not proof that the onboarding handler ran, that analytics SDKs transmitted data, or that a durable local copy was made.

## Question keys and answer domains

`hg.i` constructs these question definitions. Its constructor stores `e` as the analytics question name, `n` as the `br_*` property key, `s` as the accepted answer list, and `t` as the multi-select flag.

| Question | `br_*` key | Accepted answer values | Multi-select |
|---|---|---|---|
| `life_stage` | `br_life_stage` | `school_student`, `college_student`, `working`, `other` | No |
| `main_scroll_app` | `br_main_scroll_app` | `instagram`, `tiktok`, `youtube`, `snapchat`, `facebook`, `moj_josh_sharechat` | Yes |
| `scroll_hours` | `br_self_estimate_hours` | `1_3_hours`, `3_5_hours`, `5_7_hours`, `7_plus_hours` | No |
| `goal` | `br_goal` | `studies`, `work`, `sleep`, `fitness`, `family`, `peace_of_mind` | Yes |
| `peak_scroll_time` | `br_peak_scroll_time` | `morning_in_bed`, `during_study_work`, `after_dinner`, `late_night` | No |
| `after_scroll_feeling` | `br_after_scroll_feeling` | `guilty`, `tired`, `cant_focus`, `sleep_late` | Yes |
| `daily_limit` | `br_daily_reel_limit` | `25`, `50`, `100`, `150` | No |
| `reel_recall` | `br_reel_recall` | `all_3`, `maybe_one`, `none` | No |

## Separate handoff option path

The DEX also defines a separate handoff option model: `Lvg/o0;.<clinit>` creates `Lvg/e0` values paired with `onboarding_handoff_*` string resources. Its values include `when_bored` and `1_3_hours`, `3_5_hours`, `5_7_hours`, and `7_plus_hours`. The generic `hg.i` questionnaire has some overlapping hour identifiers, but shared strings do not establish a shared handler or analytics property. The RM's synthetic “When I'm bored” and “3–6 hours” selections map to the separate EntryOnboarding path described below; they are not evidence that `eh.e.w` or HandoffV1 handled those answers.

The event enum `kc.a.q3` is declared as `ONBOARDING_HANDOFF_OPTION_SELECTED` (“Onboarding Handoff: Option Selected”). A direct DEX field-reference scan of all three APK DEX files found the field in the enum initializer and one enum values-table/accessor method in `classes.dex`, with no references in `classes2.dex` or `classes3.dex`. This bounded scan did not identify a business-code caller. It does not prove the event is unused: name-based dispatch, reflection, ordinal-based handling, or other indirect paths are outside this scan. The scan output is `apkanalyzer_handoff_event_refs.json`; the focused option excerpts are `apkanalyzer_handoff_options.smali.txt`.

The handoff ViewModel state (`Lvg/n;`) holds selected option IDs in a `Map`. `Lvg/y;.m` serializes that map as `handoff_selected_option_ids` and includes `handoff_selected_option_count`, `handoff_page_index`, and `handoff_page_id` in a `JSONObject`. For the `HandoffV1` flow, `Lvg/x;.e` sends `ONBOARDING_HANDOFF_SCREEN_SHOWN` with that JSON to `oc.d`; the `OnHandoffContinueClicked` handler in `Lvg/x;.g` sends `ONBOARDING_HANDOFF_CONTINUE_CLICKED` with the same state projection. This is a static path into the asynchronous analytics repository. It shows selected IDs can be included in those event payloads, but does not prove either path ran or that the payload left the phone. The separately declared `ONBOARDING_HANDOFF_OPTION_SELECTED` event still has no business-code caller in the bounded direct-reference scan. Durable local storage and actual analytics or subscription requests remain unresolved.

## EntryOnboarding path used during the RM session

The APK contains a third flow, distinct from the generic `hg.i` questionnaire and HandoffV1. The RM screenshots `captures/rm-app-firstlaunch/screen-step2.png` through `screen-step4.png` show the EntryOnboarding questions. The resource table maps `entry_ob_q1_bored` to “When I'm bored” and `entry_ob_q2_3_6` to “3–6 hours”; `entry_ob_q1_title` and `entry_ob_q2_title` are their question titles. The enum `Lng/r` stores the question IDs `q1_when` and `q2_screen_time`. `Lng/e0` contains the Q1 choice ID `bored`; `Lng/d0` contains the Q2 choice ID `3_6`. The resource-reference scan maps the corresponding resource IDs to `Lng/l;->h`, which builds EntryOnboarding choice rows. These IDs and labels establish which flow those RM screens belong to; they do not establish analytics execution.

`jg.n.c(jg.j)` dispatches `ENTRY_ONBOARDING_SCREEN_SHOWN` with the active screen ID when the route changes. `jg.n.c(jg.f)` is the `OnAnswer(questionId, optionIds)` reducer. It checks the question ID and filters the submitted choices against the current question's valid option IDs. It rejects multiple picks for questions whose `Lng/r.n` flag is false. It updates the answer map in `jg.l`, derives an `EntryAnswers` model (`Lng/h`), computes the associated `Lng/p` estimate, and replaces the ViewModel's `StateFlow` state. When the selected set changes, it calls `oc.d` with `ENTRY_ONBOARDING_OPTION_SELECTED` and a JSON payload containing:

```text
screen   = current question ID (for example q1_when)
option   = toggled option ID (for example bored)
selected = whether that option is now selected
picks    = comma-joined current option IDs for the question
```

Thus, if the option handlers ran for the RM's two synthetic choices, their event payloads would include `screen=q1_when, option=bored, selected=true, picks=bored` and `screen=q2_screen_time, option=3_6, selected=true, picks=3_6`. `jg.n.c(jg.h)` also dispatches `ENTRY_ONBOARDING_CONTINUE_CLICKED` with the active screen ID when a valid continue action is handled. These are outbound-capable analytics calls; no event or request was captured during the RM session.

The completion coroutine `hi.l0.invokeSuspend` dispatches `ENTRY_ONBOARDING_COMPLETED` with a JSON payload containing only the final `limit` answer. The q1/q2 choices do not appear in that completion event; their only traced answer-bearing analytics payload is the per-option selection event above. A bounded direct DEX field-reference scan found the completion event's code reference in `Lhi/l0;->invokeSuspend`, plus its enum initializer and accessor. The health question remained unanswered on the RM, so this completion path was not observed at runtime.

The inspected option reducer updates the ViewModel state and dispatches analytics; it contains no direct Room, SQLite, Android Preferences, or DataStore write. This bounded path does not rule out persistence elsewhere. Full `apkanalyzer` class outputs used for this trace are retained under `../scratch/entry_jg_n.smali`, `entry_jg_l.smali`, `entry_hi_l0.smali`, `entry_jg_f.smali`, `entry_jg_h.smali`, `entry_ng_r.smali`, `entry_ng_e0.smali`, `entry_ng_d0.smali`, and `entry_ng_l.smali`; the literal resource cross-reference is `apkanalyzer_onboarding_resource_refs.json`.

## Answer handler

In `eh.e.w(hg.i, List, String, String)`, the code filters selected values against the question's accepted list, joins accepted values with commas, and calls `F(question.n, joinedAnswers)`. If the selected values contain `other` and the free-text answer is nonblank, it calls `F(question.n + "_other", trimmedText)`.

It then constructs an event object with these fields:

```text
question     = hg.i.e
answer       = comma-joined accepted answers
answer_count = number of selected answers
answer_text  = trimmed free text when present
placement    = caller-supplied placement
```

The event key passed to `oc.d.a` is `kc.a.y2`, whose declared event code is `ONBOARDING_QUESTION_ANSWERED` and display name is `Onboarding Question: Answered`.

## Analytics and subscription SDK calls

`eh.e.F(key, value)` forwards a typed string property to `n9.z0.h(...)` and also calls `di.m.h(key, value)`. `di.m.h` stores the pair in an in-memory `ConcurrentHashMap`; if RevenueCat is configured, it calls `Purchases.setAttributes` with that pair. This establishes an SDK call path, not a captured request.

The event is passed to `oc.d.a`, which schedules asynchronous analytics work. `oc.d` is constructed with `lc.b` (which holds a `FirebaseAnalytics` instance) and `pc.a`; the analytics worker contains Firebase and Meta queue paths. The event queue's runtime flags and actual network requests were not observed.

`n9.z0.h` also has a branch that forwards string properties to `lc.b.f`, whose worker reaches the Firebase Analytics implementation. The concrete mode of the `n9.z0` object injected into this answer handler was not resolved, so this property path is recorded as a candidate rather than a confirmed per-answer Firebase call.

No direct Room, SQLite, or Android Preferences write appears in the inspected `eh.e.w`, `eh.e.F`, or `di.m.h` bodies. This bounded trace does not establish that no other code persists the answers locally. A device traffic capture is still required to prove which queued analytics or subscription values leave the phone.
