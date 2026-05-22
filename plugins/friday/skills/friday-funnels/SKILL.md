---
name: friday-funnels
description: |
  Called by friday-sweep, friday-backfill, and friday-review when a signal
  suggests a stage transition. Codifies the four pipelines (MEET, DISCO,
  MANAGE, NURTURE) and the stage definitions inside each. Not invoked
  directly by the user.
---

# friday-funnels

The four-pipeline taxonomy and the rules for moving a deal between stages. Grounded in the Predictable Revenue Four Funnels framework and the user's own Sales Guide.

## When to invoke

Called by an orchestrator skill (`friday-sweep`, `friday-backfill`, `friday-review`) whenever there's a signal that *might* be a stage transition:

- A calendar event happened that matches an existing pipeline row.
- An email arrived that matches an existing pipeline row.
- A Fireflies transcript exists for a meeting with the row's counterparty.
- A commitment came due (or didn't) — see `friday-commitments`.

The orchestrator passes in: the pipeline row's current `Opp Stage`, the new signal (kind + summary + evidence_link), and any extracted commitments. `friday-funnels` returns: the suggested new stage (or "stay"), the confidence, and a one-line reason that becomes the Activity Log `summary`.

## The four pipelines

| Pipeline | Purpose | Cadence |
|---|---|---|
| **MEET** | Top-of-funnel relationships. People you've started a conversation with — outbound, inbound, or warm intro — who haven't yet entered active discovery. | weekly review |
| **DISCO** | Active sales process. From "qualified" through "verbal" to "closed". This is where MEDDPICC scoring matters most. | weekly review |
| **MANAGE** | Existing customers. Customer success, expansion, renewal. | monthly review |
| **NURTURE** | Cold relationships you want to stay warm with. Podcast guests, dormant prospects, former champions who moved companies. | monthly touch |

A deal is in **exactly one** pipeline at a time. Transitions across pipelines (e.g. MEET 5 → DISCO 1, DISCO 6 → MANAGE 1, anything → NURTURE) are explicit moves with their own rules below.

## Stage taxonomies

(Mirrors `friday-sheet` § Stage taxonomies — kept here for self-contained reference.)

### MEET

| Stage | Name | Means |
|---|---|---|
| 0 | Cold | You have their email but no exchange yet. Probably from an event, intro request, or warm referral that hasn't activated. |
| 1 | Approaching | First outbound sent. No reply yet. |
| 2 | Connected | Two-way exchange has happened — at least one inbound from them. Conversation exists but no meeting scheduled. |
| 3 | Meeting Booked | A discovery call is on the calendar. |
| 4 | Meeting Held | The discovery call happened. Follow-up window is open. |
| 5 | Moved to Disco | Promoted into the DISCO pipeline. (This row gets archived in MEET, a new row is added in DISCO.) |
| 6 | FOAD | "F-off and die" — the relationship is dead and they're not even worth NURTURE. |

### DISCO

| Stage | Name | Means |
|---|---|---|
| 1 | Qualify | Confirmed they have the problem and might buy a solution. Beginning MEDDPICC scoring. |
| 2 | Discovery | Active discovery — uncovering pain, metrics, decision process. |
| 3 | Solution Review | You've presented a solution; they're evaluating. |
| 4 | Solution Validation | They've validated the solution fits — technical sign-off, security review, etc. |
| 5 | Verbal | Verbal commitment. Paper process is the only thing in the way. |
| 6 | Closed-Won | Signed. Move to MANAGE. |
| 7 | Closed-Lost-Nurture | Lost, but worth staying warm with → move to NURTURE. |
| 7 | Closed-Lost-Competitor | Lost to a competitor. NURTURE only if there's reason to believe they'll switch. |
| 7 | Closed-Lost-FOAD | Lost and don't bother. No NURTURE follow-up. |

### MANAGE

| Stage | Name | Means |
|---|---|---|
| 1 | Onboarding | First 30–90 days post-close. Focus: time-to-value. |
| 2 | Adopting | Steady-state usage. Focus: retention, expansion signal-gathering. |
| 3 | Wildly Successful | The customer is a reference, an expansion conversation, or both. |

### NURTURE

| Stage | Name | Means |
|---|---|---|
| 0 | Cold (monthly cadence) | Friday surfaces these once a month for a low-stakes touch. Not actively trying to close anything. |

## Stage-transition rules

Each rule says: **given an existing row in stage X and signal Y, suggest stage Z with confidence C.** Confidence governs `applied=Y` vs `applied=N` per [[friday-sheet]] § Write discipline.

### MEET transitions

- **0 → 1** when: an outbound email is sent from the user to the row's counterparty for the first time. Confidence: high.
- **1 → 2** when: an inbound reply from the counterparty is received. Confidence: high.
- **2 → 3** when: a calendar event is created with the counterparty as an attendee, and the event time is in the future. Confidence: high.
- **3 → 4** when: the calendar event's `start` time has passed AND the event was not cancelled. Confidence: high.
- **4 → 5** when: the user explicitly says "promote to DISCO" in `friday-review`. Friday does NOT auto-promote MEET 4 → DISCO 1; the user owns this decision. Confidence: N/A (manual).
- **any → 6 (FOAD)** when: the user explicitly marks this in `friday-review`. Confidence: N/A (manual).

### DISCO transitions (suggested only — user approves substantial moves)

- **1 → 2** when: a discovery meeting has been held AND notes/transcript exist AND at least three MEDDPICC dimensions have non-zero scores. Confidence: medium.
- **2 → 3** when: a transcript or email indicates the user has shared a proposal, demo, or solution document. Confidence: medium.
- **3 → 4** when: an email or transcript shows the counterparty has internally validated the solution (e.g. "we like it, just need security review"). Confidence: low — verbal validation is easy to misread.
- **4 → 5** when: the user explicitly says "we got a verbal" in `friday-review` OR a transcript contains an unambiguous commitment phrase ("we're moving forward", "let's get a contract drafted"). Confidence: low (treat as suggestion).
- **5 → 6 (Closed-Won)** when: the user explicitly marks in `friday-review`. Confidence: N/A (manual).
- **any → 7 (Closed-Lost-*)** when: the user explicitly marks in `friday-review`. Confidence: N/A (manual).

### MANAGE transitions

- **1 → 2** when: 60 days have passed since the row was added AND no `Next Action` is overdue. Confidence: medium.
- **2 → 3** when: the user explicitly marks in `friday-review`. Confidence: N/A (manual).

### Cross-pipeline transitions

- **MEET 5 → DISCO 1**: the user explicitly promotes via `friday-review`. Friday creates a new DISCO row, copies `Company` / `Name` / `Notes`, sets `Opp Stage = 1`, and updates the MEET row's stage to 5.
- **DISCO 6 → MANAGE 1**: same pattern.
- **DISCO 7 → NURTURE 0**: same pattern, but only if the user picked Closed-Lost-Nurture (not the Competitor or FOAD variants).
- **Any row → NURTURE**: the user can move any row to NURTURE via `friday-review`. Friday adds a NURTURE row and updates the original row's stage to its terminal stage.

## Confidence policy summary

Per [[friday-sheet]] § Write discipline:

- **High** → apply the change, Activity Log `applied=Y`.
- **Medium** → apply the change, Activity Log `applied=Y`, BUT include "review-recommended" in the summary.
- **Low** → do NOT apply. Activity Log `applied=N`, surfaced in `friday-review`.
- **N/A (manual)** → never apply automatically. Only the user can move this stage in `friday-review`.

## Examples

### Example 1: MEET 3 → 4 (high confidence)

Existing row: `Company=Acme`, `Name=Drew Houston`, `Opp Stage=3: Meeting Booked`.
Signal: calendar event "Discovery call with Acme" with `start=2026-05-22T14:00:00Z` (in the past as of sweep time), `status=confirmed` (not cancelled).

→ Stage: `4: Meeting Held`. Confidence: high. Apply. Summary: "MEET 3 → 4 (calendar event 'Discovery call with Acme' on 2026-05-22 — completed)."

### Example 2: DISCO 3 → 4 (low confidence)

Existing row: `Company=Coalesce`, `Name=Priya Patel`, `Opp Stage=3: Solution Review`.
Signal: email from Priya containing "We've reviewed the proposal internally — looks promising, just need to loop in security and procurement."

→ Suggested stage: `4: Solution Validation`. Confidence: low (the wording is favorable but not a hard validation). DO NOT apply. Activity Log `applied=N`, surfaced in `friday-review`.

### Example 3: MEET 4 → DISCO 1 (manual)

Existing row: `Company=Glean`, `Name=Arvind Jain`, `Opp Stage=4: Meeting Held`.
Signal: transcript from yesterday's call shows clear qualification signals (budget, timeline, named decision-maker).

→ Friday writes Activity Log `applied=N` with `summary="Possible MEET → DISCO promotion: qualification signals in transcript. Confirm in friday-review."` Friday does NOT promote. The user owns the cross-pipeline move.

## References

- `references/four-funnels.md` — the Predictable Revenue framework that grounds the four-pipeline split.
- `references/sales-guide.md` — the user's own canonical stage definitions and language. This is the source-of-truth document; the rules in this skill defer to it when they conflict.
