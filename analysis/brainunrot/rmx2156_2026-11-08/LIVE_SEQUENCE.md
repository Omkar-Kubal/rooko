# BrainUnrot count observations by route

Date: 2026-11-08  
Device: RMX2156, Android 12 / API 31  
BrainUnrot: `0.0.1` (version code `5`)  
Instagram: `454.0.0.54.77`  
YouTube: `21.44.534`

## Setup observed

- BrainUnrot's Accessibility service was enabled in Android Settings and present in `dumpsys accessibility` as a bound `BrainRotty` service. Its declared event types included `TYPE_VIEW_SCROLLED`, `TYPE_WINDOW_CONTENT_CHANGED`, and `TYPE_WINDOW_STATE_CHANGED`; no crashed service was listed. Its process remained running.
- `GET_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` app-ops reported `allow`.
- The investigator did not change permissions or app settings. The user had completed BrainUnrot onboarding before this sequence.
- Baseline dashboard total was `Reels today: 0`.

## Method and privacy boundary

The original tests used Android VIEW links for app home or presumed short-form routes. Their swipes were sent at the screen center (`540,1800` to `540,600`, 500 ms), and the target package/activity was checked where noted. BrainUnrot was brought to the foreground after a case and its dashboard total was read. Those initial tests did not collect feed pixels, text, Accessibility node trees, app logs, or the app database; their temporary screenshots contained only BrainRotty's dashboard and were deleted. In the later visually verified Reels run, the scrcpy mirror was viewed transiently to confirm the route and distinct settled advances. The Shorts follow-up used ADB frames resized in memory without saving them. No feed frames or item content were saved to project files or transcribed into this ledger; only item ordinals, action timing, and aggregate counts are retained.

The user clarified that the initial Instagram swipes were in the home section, not the Reels viewer. The `/reels/` and `/shorts` URLs plus generic main-activity names did not prove short-form navigation. Instagram rows in the original ledger are home-feed observations; YouTube rows are app-foreground observations with an unverified route. A later user-confirmed Reels run is recorded separately below. Swipe commands are not proof that each gesture advanced to a distinct item.

## Sequence ledger

| Case | App route and foreground | Input | Dashboard count | Observation |
|---|---|---|---:|---|
| Instagram presumed-Reels entry | `https://www.instagram.com/reels/`; intent reported `UrlHandlerActivity`, focus `InstagramMainActivity` | ~2 s dwell, one swipe, ~2 s dwell | 0 → 0 | User later confirmed the activity was the home section, not Reels. |
| YouTube presumed-Shorts entry | `https://www.youtube.com/shorts`; intent reported YouTube `MainActivity` | ~2 s dwell, one swipe, ~2 s dwell | 0 → 2 | Route was not independently verified; do not attribute this delta to Shorts. |
| Instagram home dwell | `https://www.instagram.com/`; focus `InstagramMainActivity` | 3.5 s, no swipe | 2 → 2 | No count during this no-swipe home dwell. |
| YouTube home dwell | `https://www.youtube.com/`; focus `InternalMainActivity` | 3.5 s, no swipe | 2 → 2 | No count during this no-swipe app dwell. |
| Instagram home-feed transitions | `/reels/` intent; focus `InstagramMainActivity` | 1.5 s, swipe; 1.5 s; swipe; 0.25 s; swipe; 1.5 s | 2 → 2 | User confirmed home-section swipes; no increment. |
| YouTube unverified-route mixed dwell | `/shorts` intent; focus `InternalMainActivity` | 1.5 s initial; 3.5 s stationary; swipe; 1.5 s; swipe; 0.25 s; swipe; 1.5 s | 2 → 2 | No increment; exact route unknown. |
| Instagram home-feed re-entry | `/reels/` intent, focus `InstagramMainActivity` | 5 s load wait, 2 s dwell, one swipe, 2.5 s dwell | 2 → 2 | Home section; no increment. |
| YouTube unverified-route re-entry | `/shorts` intent; focus `InternalMainActivity` | 5 s load wait, 2 s dwell, one swipe, 2.5 s dwell | 2 → 2 | No increment; exact route unknown. |
| YouTube repeated transitions | `/shorts` intent; focus `InternalMainActivity` | Five swipes, each followed by ~1.5 s | 2 → 2 | No increment; exact route unknown. |
| Instagram home-feed transitions | `/reels/` intent; focus `InstagramMainActivity` | Five swipes, each followed by ~1.5 s | 2 → 3 | One increment across five home-section swipes. |
| Instagram home-feed repeat | `/reels/` intent; focus `InstagramMainActivity` | Same five-swipe, ~1.5 s spacing | 3 → 3 | No repeat increment. |
| YouTube declared Shorts action | `com.google.android.youtube.action.open.shorts`; reported `MainActivity`, focus `InternalMainActivity` | ~3 s wait, one swipe, ~2 s wait | 3 → 3 | Manifest-declared action was used; exact visible screen still unverified. |
| YouTube declared Shorts repeat | Same explicit action and generic activity | Five swipes, each followed by ~1.5 s | 3 → 3 | No increment; exact visible screen still unverified. |

## Supervised Instagram Reels follow-up (2026-11-08)

| Case | Route evidence | Input | Dashboard count | Observation |
|---|---|---|---:|---|
| First Reels attempt (later corrected) | The user initially said the actual Reels viewer was open. ADB focus was `InstagramMainActivity`, which is generic. The user later said the sequence did not scroll through Reels. | Five ADB upward-swipe commands from `(540,1800)` to `(540,600)`, 450 ms each, followed by 2 s dwell. | 3 → 4 | Do not treat as a verified swipe or item-transition run. The one-count increase may have occurred on viewer entry or another event. |

The count of `3` was the last dashboard value observed before the user opened Reels. After the five swipes, BrainUnrot was brought to the foreground and its dashboard showed `4`. Only that dashboard was captured; the temporary dashboard image was deleted. No feed screenshot, text, hierarchy, or media was captured during this attempt. REA's screenshot provider again failed because its Windows worker could not access `C:\Windows\Temp`; a direct ADB screenshot was used only after verifying BrainUnrot's dashboard had focus.

### Second Instagram navigation and swipe attempt

| Case | Route evidence | Input | Dashboard count | Observation |
|---|---|---|---:|---|
| Reels-tab coordinate attempt | Instagram was launched; an ADB tap was sent to `(324,2220)`, the presumed Reels-tab position. The reported activity stayed `InstagramMainActivity`, so the tab state was not independently verified. | Five ADB upward-swipe commands from `(540,1800)` to `(540,600)`, 300 ms each, with 2 s dwell. | 4 → 10 | Six-count increase across launch/tab navigation plus the five swipe commands. The user has been asked whether they observed visible Reel advances; route and ground truth remain unresolved. |

BrainUnrot's dashboard was the only screen captured for the final total. The temporary image was deleted. No Instagram pixels, text, media, or hierarchy were retained.

### Reels navigation probes before the bounded sample

| Probe | Input | Visible/count result | Treatment |
|---|---|---|---|
| Entry and first mirror scroll | Instagram Reels was visually confirmed. A drag did not advance; a subsequent wheel-style scroll produced a transient black/offer screen. The BrainRotty Pro offer was closed with its X; no purchase was made. | The Reels overlay showed `11` after returning to the viewer; the last dashboard total was `10`. | Entry/scroll contribution is not separable. Exploratory only. |
| Wheel scroll and settling | One wheel-style scroll (`scrollY=-500`), then no input for 3 s and another 3 s. | Counter `11 → 12` immediately, then `13` during the first hold while the view was between items, then `14` after the second hold when a different item was settled. | Three increments followed one wheel input while the feed was moving/settling. It may have passed multiple items; do not treat as a one-item transition. |
| Long touchscreen swipe | `(540,1900) → (540,500)`, 300 ms, then 2 s. | Counter `14 → 15` immediately and `16` after 2 s, with the feed settling on another item. | Transition length may have crossed more than one item. Exploratory only; excluded from the bounded sample. |

### Visually verified Instagram Reels sequence

The scrcpy mirror visibly showed Instagram's Reels header and selected Reels tab. This sequence used short ADB touchscreen swipes; each distinct settled item was visually checked, but no feed screenshots or content were saved to project files. BrainUnrot's floating aggregate was read from the overlay. The count was `16` before this bounded sample.

| Transition | Touch input | Visible result | Counter before → after 2 s | Count result |
|---|---|---|---:|---|
| 1 | 540,2000 → 540,1100; 250 ms | Distinct next item settled | 16 → 17 | +1 (appeared during dwell) |
| Stationary control | No input; 2 s | Same item remained | 17 → 17 | No repeat |
| 2 | Same short swipe | Distinct next item settled | 17 → 17 | Missed |
| 3 | Same short swipe | Distinct next item settled | 17 → 18 | +1 (appeared during dwell) |
| 4 | Same short swipe | Distinct next item settled | 18 → 19 | +1 (appeared during dwell) |
| 5 | Same short swipe | Distinct next item settled | 19 → 19 | Missed |
| 6 | Same short swipe | Distinct next item settled | 19 → 21 | +2 (20 immediate, 21 by 2 s) |
| 7 | Same short swipe | Distinct next item settled | 21 → 22 | +1 |
| Unsuccessful gesture | Same short swipe | Same item remained | 22 → 22 | No transition; excluded |
| 8 | 540,2000 → 540,900; 250 ms | Distinct next item settled | 22 → 22 | Missed |
| Ambiguous movement | 540,2000 → 540,900; 250 ms | View changed within the same creator's feed segment; distinct item was not established | 22 → 23 | +1; excluded from the ten-item tally |
| 9 | 540,2100 → 540,400; 200 ms | Distinct next item settled | 23 → 23 | Missed |
| 10 | 540,2000 → 540,900; 250 ms | Distinct next item settled | 23 → 25 | +2 (24 immediate, 25 by 2 s) |
| Stationary control | No input; 2 s | Same item remained | 25 → 25 | No repeat |

Across the ten visually verified distinct-item advances, four produced exactly one count, four produced no count within 2 seconds, and two produced two counts. The aggregate rose by 8 across those ten transitions (`16 → 25` includes the separate ambiguous movement's +1). The sample is small and uses one device/account/version, but it demonstrates both missed and duplicate counts in this run. One failed swipe and one ambiguous movement are reported separately.

## Visually verified YouTube Shorts follow-up (2026-11-08)

An exploratory Shorts pass before the bounded run visually identified eight distinct advances while the overlay went from `27` to `35`. One sponsored item did not increment and one additional increment appeared during an apparently stationary interval. Individual transition deltas from that exploratory pass were not retained, so it is excluded from the table below.

The subsequent pass began on BrainRotty's dashboard at `35`, stable before YouTube was opened. The YouTube Shorts action first opened YouTube Home; tapping the visible Shorts tab opened the Shorts viewer. The first settled Short showed `36` before any swipe. The pass then used ADB touchscreen swipes, with transient in-memory screen previews after each gesture to confirm a distinct settled Short and read the overlay. The previews were not written to project files or retained as images. The capture and tool latency put each check several seconds after the swipe; this pass does not measure exact count latency. Content, creator names, and captions are intentionally omitted from the ledger.

| Step | Visible result | Counter before → settled check | Treatment |
|---|---|---:|---|
| Viewer entry | First Short visible; no swipe | 35 → 36 | First-item increment observed; exact timing unknown |
| 1 | Distinct ordinary Short | 36 → 37 | +1 |
| Stationary control | Same Short, no input | 37 → 37 | No repeat |
| 2 | Distinct ordinary Short | 37 → 38 | +1 |
| 3 | Distinct sponsored Short | 38 → 38 | +0 |
| 4 | Distinct ordinary Short | 38 → 39 | +1 |
| 5 | Distinct ordinary Short | 39 → 40 | +1 |
| 6 | Distinct sponsored Short | 40 → 40 | +0 |
| 7 | Distinct ordinary Short | 40 → 41 | +1 |
| Unsuccessful gesture | Scene changed within the same Short; item identity stayed the same | 41 → 41 | Excluded from transition tally |
| 8 | Distinct ordinary Short after a stronger swipe | 41 → 42 | +1 |
| 9 | Distinct sponsored Short | 42 → 43 | +1 coincident with sponsored item; attribution is aggregate-only |
| 10 | Distinct ordinary Short | 43 → 44 | +1 |
| Stationary control | Same Short, no input | 44 → 44 | No repeat |
| Revisit attempt | Scene changed within the same Short | 44 → 44 | Excluded |
| Revisit 1 | Returned to previously viewed sponsored Short 9 | 44 → 44 | No repeat |
| Revisit 2 | Returned to previously viewed ordinary Short 8 | 44 → 44 | No repeat |
| YouTube Home control | Home tab visually confirmed; three feed scrolls, then BrainRotty dashboard | 44 → 44 | No count outside Shorts in this control |

Seven of seven distinct ordinary Shorts added exactly one count in this bounded sequence. The three sponsored Shorts coincided with deltas `0`, `0`, and `1`; the app's static ad path excludes correctly identified ads from the displayed total, so the last delta is a possible recognition or timing error, not a proven ad classification trace. The ten advances together added eight counts (`36 → 44`). The two stationary checks, two verified revisits, and three YouTube Home scrolls did not add counts. The first-item `35 → 36` change is outside the ten-transition tally. No private app database, raw Accessibility tree, or feed text was collected.

## Interpretation

- The no-swipe home/app dwells did not change the total.
- The first YouTube `/shorts` intent produced two counts, but the route was not confirmed, so this is not evidence of Shorts counting.
- Instagram home-feed tests remained unchanged in several batches, then added one count during a five-swipe batch. The identical home-feed repeat added none.
- The installed YouTube manifest declares `com.google.android.youtube.action.open.shorts`. Using it for one- and five-swipe batches did not change the total, but the reported/focused activity remained generic `MainActivity`/`InternalMainActivity`.
- The service was enabled and bound during the extended run, so a disabled or crashed Accessibility service does not explain the later zero deltas.
- The count deltas cannot be mapped to Reels/Shorts items. They could reflect generic home-feed detection, route ambiguity, token de-duplication, event sampling, asynchronous aggregation, or an app detector defect; this run cannot distinguish those causes.
- The user later reported that the first swipe commands did not scroll through Reels; that `3 → 4` batch is not evidence of swipe counting. A second batch followed a tap at the presumed Reels-tab coordinate and produced `4 → 10`, but the tab selection and visible advances were not verified, so it remains exploratory.
- Once the mirror visibly confirmed Reels, a bounded ten-transition sample showed four exact-one increments, four misses, and two double increments. One separate ambiguous movement added a count; two stationary controls showed no repeat. This is direct evidence that the installed BrainUnrot version did not count one-per-visible-Reel consistently under this sequence.
- A later visually confirmed Shorts run showed an entry increment and seven exact-one increments across seven ordinary Shorts. Three sponsored Shorts coincided with two zero deltas and one +1. Two revisits and YouTube Home scrolls added none. The app did better on ordinary Shorts in this small run, but the inconsistent sponsored handling and earlier exploratory delay still prevent an exact-count claim.

## Evidence limits and next probe

The dashboard exposes one aggregate `Reels today` value, not a per-app breakdown. The original `0 → 2` and `2 → 3` changes came from app use whose short-form route was not established. The first later `3 → 4` attempt was reported by the user as not having scrolled; the `4 → 10` run used a presumed tab coordinate and remains unverified. The visually verified ten-transition sample then showed both misses and double counts. It is preliminary evidence of unreliable behavior on this exact build/device, not a population accuracy estimate.

For a stronger accuracy estimate, repeat with a fresh daily baseline, more labeled items, and additional app/device versions while retaining only ordinals and aggregate deltas. Instagram Reels and YouTube Shorts were verified visually in this pass even though Android reported generic main activities. TikTok, Facebook, and Snapchat were not live-tested on this device.
