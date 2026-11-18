# Progress observed-time metric design

## Intent

Add a daily **Time spent** value beside **Total Count** in Progress Day. The value should help users understand how long supported short-form feeds were observed on screen, without pretending that event counts reveal watch duration.

## Source and product scope

- **User-approved Sync Scroll requirement:** add a time observation and rename the count label to “Total Count.”
- **User-approved definition:** time accumulates only while a recognized Instagram Reels or YouTube Shorts feed is observed in the foreground; exclude uncertain gaps and never infer duration from counts.
- **Proposal:** show this metric only in the selected Day summary for this change. Leave Week layout unchanged until requested.

The metric describes observed feed presence. It cannot establish that a video played or that the user watched it attentively. It does not use count-event timestamps or estimated reel lengths.

## Approaches considered

1. **Use count-event timestamps or count-based duration.** Rejected: timestamps show when items were counted, not how long a feed stayed visible. A per-item duration multiplier would fabricate time.
2. **Measure recognized foreground-feed time.** Selected: use monotonic elapsed time between successful feed-visibility checks for selected supported packages. This produces an approximate local observation; a brief exit between checks may be missed, so the value must not be described as exact playback or attention time.
3. **Measure playback time.** Rejected for this scope: the Accessibility signals in the current detector do not establish media playback state.

## Behavior

- Replace the Progress Day total label “Reels and Shorts counted” with **Total Count**.
- Present **Total Count** and **Time spent** as two aligned metrics in the existing borderless Day summary surface.
- Accumulate time only while Accessibility consent and service access are active, the screen is interactive, and the foreground package/version has a recognized feed marker for a selected app through its validated profile or the already-consented Instagram/YouTube estimate path.
- Recheck the active root on a short interval while a feed is recognized. A time check inspects only package identity and feed-marker resource IDs; it does not traverse labels or collect item identity. Credit only intervals bounded by successful foreground-feed observations, using monotonic elapsed time. Do not backfill a gap after an app switch, unrecognized root, screen-off state, service interruption/death, consent/access loss, package/version/selection change, or timezone/day-boundary change.
- Store only a daily aggregate of observed duration. Do not store per-item time, feed text, media, or raw accessibility labels. Keep count timestamps as a separate seven-day feature.
- Show `—` when no duration observation is available, including older days. Do not backfill legacy durations. Format nonzero observations as concise elapsed time; do not imply second-level precision.
- Update the in-app tracking disclosure and require affirmative consent to the expanded measurement purpose before collecting duration. The existing Accessibility permission remains user controlled; overlay access is not required for this metric.

## Storage and presentation constraints

- Add a Room migration that preserves all existing rows and leaves legacy duration unknown.
- Expose an optional observed-duration value through the typed Android-to-Flutter Progress response and Dart model.
- Keep the UI monochrome, accessible at large text sizes, and borderless. TalkBack should announce both metric names and values together.
- Update PRD, SRS, `AGENTS.md`, `context.md`, and `progress.md` with the final behavior and evidence.

## Acceptance evidence

- A selected recognized feed accumulates observed time while it remains foregrounded.
- Leaving the feed or losing monitoring/access stops accumulation without crediting the uncertain interval.
- Stationary feed presence can accumulate time even without a new count event; count totals and counted-time rows remain unchanged by duration sampling.
- No duration is derived from count totals, item dwell threshold, or assumed reel length.
- Legacy days show unavailable duration, and database migration preserves existing totals and exact count timestamps.
- Updated disclosure and consent gate duration collection; overlay permission is not required.
- Day summary presents “Total Count” and “Time spent” accessibly without adding borders.

## Calls left to implementation

- Use a brief, battery-conscious periodic root check while a recognized feed is active; commit only bounded intervals and display rounded minutes (or “<1 min” for a nonzero value below one minute).
- Store only the local-day aggregate; do not add a duration graph or per-app duration rows.
