---
name: sync-scroll-product-contract
description: Use when planning or changing Rooko product scope, requirements, roadmap, user flows, or product copy; keeps reverse-engineering evidence distinct from approved requirements and preserves the free Android-first end scope.
---

# Rooko product contract

Use this skill for product decisions. The PRD and SRS define Rooko; REA artifacts describe what was observed in a different app.

## Required reading

1. Read `docs/PRD.md` and `docs/SRS.md` before proposing scope or changing requirements.
2. Read only the relevant material in `analysis/` when using reverse-engineering evidence.
3. Check existing requirements and decision notes before adding a duplicate or contradicting a settled decision.

## Workflow

1. State the user problem and the affected PRD section, SRS ID, milestone, or screen.
2. Label each input as one of: **REA observation**, **user-approved Rooko requirement**, **proposal**, or **open decision**.
3. Check the change against the end-version scope, Android platform target, priorities, free-feature rule, and privacy boundaries.
4. Describe user-visible behavior, failure or empty states, and acceptance evidence. Do not copy another app's wording or interface.
5. Update the PRD/SRS and cross-references together when requirements change. Keep `analysis/` evidence intact.

## Product contract

- Final app scope is the end version defined in `docs/PRD.md`; use its milestones to sequence delivery rather than silently dropping end-state features.
- Every feature is free. Do not introduce paywalls, paid entitlements, advertising, or purchase-based access.
- The product is Android-first. Web scaffolding is for preview and tooling.
- Competitive framing is about progress against a user's own verified progress. Daily limits, interruptions, and overrides are deferred, and saved legacy limit values are inert. Never reward more viewing, guilt the user, diagnose them, or promise unsupported time savings.
- Rook is an original minimal brain mascot with Ready, Strained, Injured, Queasy, Vomiting, Recovering, Victorious, and Sleeping states. Count poses use fixed combined-count bands; Today alone uses Sleeping/Recovering and Progress alone uses Victorious. State language describes Rook, not the user; respect animation and reduced-motion requirements.
- Keep REA observations and confidence limits explicit. An observed behavior in the reference app is not automatically a Rooko requirement.

## Deliverable

Return a concise requirement change or product brief with: source classification, affected PRD/SRS references, user-visible behavior, acceptance evidence, privacy/free-scope check, and unresolved decisions. For document edits, link each changed requirement to the relevant evidence or decision.
