# Progress Week redesign

## Intent

Help someone understand the distribution of their combined Reels and Shorts counts across seven days in one glance. The selected visual is [the Week concept](../../../assets/design/ux-06-progress-week-selected.png). It is an illustrative mockup, not source data or a replacement for approved Rook art.

## Chosen layout

- Keep the existing Progress top navigation, Week/Month selector, and period arrows.
- Place one prominent combined week total and its label above a seven-column bar chart. Each recorded day shows its exact count and weekday/date; bar height and neutral brightness reflect that day's share of the week's maximum. No app attribution, estimate labels, grid lines, or duplicate total card appear in Week.
- A missing date has no bar or count. A stored zero-count day shows `0` without a bar. Future dates with no record stay blank. A period with no saved day records shows the existing Rook empty state.
- Put the most recent qualifying personal-best day, if any, after the chart as a compact callout with the approved Victorious Rook, date, and count. The existing verification rules remain authoritative.
- Month retains its heatmap, legend, separate total card, and current personal-best presentation.

## Constraints and acceptance

Use stored combined counts only; do not infer time, health, streaks, goals, or reliability. Use the canonical monochrome palette and existing typography/spacing tokens in Light, Dark, and AMOLED. Preserve date navigation, large-text layout, semantics, and reduced-motion Rook behavior. Verify a populated week, zero and missing days, personal best, empty week, and Month regression. Inspect on RMX2156 without opening live feeds.
