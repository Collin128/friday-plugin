---
name: friday-meddpicc
description: |
  Called by friday-sweep, friday-backfill, and friday-review when a signal
  suggests a MEDDPICC score change on a DISCO row. Codifies the 0/1/2
  scoring rubric per dimension and the evidence each score requires.
  Not invoked directly by the user.
---

# friday-meddpicc

The MEDDPICC scoring rubric. Eight dimensions, each scored `0`, `1`, or `2`. `SCORE` = sum (max 16). `MEDDPICC Score` percent = `SCORE / 16`.

## When to invoke

Called by an orchestrator skill (`friday-sweep`, `friday-backfill`, `friday-review`) whenever there's a signal that *might* change one of the eight MEDDPICC dimensions on a DISCO row. The orchestrator passes in: the existing scores, the new signal (an email body, a transcript excerpt, a meeting summary), and any extracted commitments. `friday-meddpicc` returns: the suggested score deltas, the confidence, and a one-line reason per dimension that becomes Activity Log entries.

MEDDPICC scoring is **DISCO-only**. MEET, MANAGE, and NURTURE rows ignore MEDDPICC.

## The eight dimensions

| Dim | Name | Question it answers |
|---|---|---|
| **M** | Metrics | What measurable business outcome does the counterparty get from buying? |
| **E** | Economic Decision Maker (Buyer) | Who has the budget authority to say yes? |
| **DC** | Decision Criteria | What criteria will they use to evaluate? |
| **DP** | Decision Process | What's the actual process — who's involved, what steps, what timeline? |
| **P** | Paper Process | What does the legal/procurement side look like? |
| **I** | Identified Pain | What's the specific pain that's costing them now? |
| **CH** | Champion | Who inside the account is actively selling internally on the user's behalf? |
| **CP** | Competition | Who else is in the running? What's the user's differentiation? |

## Scoring rubric

Each dimension uses the same 0/1/2 scale:

- **0 — unknown / unstated.** No evidence in any conversation, email, or transcript.
- **1 — surfaced.** The dimension has come up; you have a working hypothesis but no confirmation.
- **2 — confirmed.** Direct, specific evidence from the counterparty.

### M — Metrics

| Score | Evidence required |
|---|---|
| 0 | No mention of business outcomes or numbers. |
| 1 | Generic outcomes mentioned ("we want to grow revenue", "reduce churn") without specific numbers. |
| 2 | Specific, quantified outcome ("we need to cut onboarding time from 4 weeks to 1") OR the user has shared a number-backed business case with the counterparty's tacit agreement. |

### E — Economic Decision Maker

| Score | Evidence required |
|---|---|
| 0 | No named decision-maker. |
| 1 | A name has been mentioned ("Sarah owns this budget") but the user has not met them. |
| 2 | The user has been in a meeting or thread with the named economic buyer AND that person has actively engaged. |

### DC — Decision Criteria

| Score | Evidence required |
|---|---|
| 0 | No discussion of what they'll evaluate on. |
| 1 | Criteria mentioned in passing ("we care about ease of integration") but no written/agreed list. |
| 2 | Explicit, agreed-upon criteria — either in writing or stated unambiguously in a transcript. |

### DP — Decision Process

| Score | Evidence required |
|---|---|
| 0 | No discussion of how they decide. |
| 1 | Some process surfaced ("we'll need security to look at this") but the full path is unclear. |
| 2 | A clear sequence: who reviews, what gates, what timeline. Mapped end-to-end. |

### P — Paper Process

| Score | Evidence required |
|---|---|
| 0 | No mention of procurement, legal, or contracting. |
| 1 | They've alluded to it ("our legal team is fast") but the user hasn't seen the actual process. |
| 2 | The user has visibility into the actual paper process — MSA template requested, legal contact named, procurement system identified. |

### I — Identified Pain

| Score | Evidence required |
|---|---|
| 0 | No pain articulated. The counterparty is "exploring." |
| 1 | Pain surfaced in conversation but the user can't quote the specific cost of it ("they said they're frustrated with current workflow"). |
| 2 | The counterparty has stated specific, current pain in their own words AND attached a cost to it ("we lose 6 hours/week on this; that's $30k/year"). |

### CH — Champion

| Score | Evidence required |
|---|---|
| 0 | No champion. The user is alone on the inside. |
| 1 | Someone is friendly and helpful but hasn't actively advocated for the user. |
| 2 | The champion is *actively selling* for the user internally — looping in stakeholders, repeating the user's pitch in their own words, flagging risks early. |

### CP — Competition

| Score | Evidence required |
|---|---|
| 0 | The user doesn't know if there are competitors in the deal. |
| 1 | The counterparty has mentioned looking at alternatives ("we're talking to a few options") but not named them or shared details. |
| 2 | Named competitors are known AND the user has explicit differentiation against each. |

## Demotion rules

A score can drop if new evidence undermines a prior assumption:

- **2 → 1**: a stronger signal contradicts the previous justification. (Example: CH was 2 because "Sarah was actively advocating"; new email shows Sarah is no longer copied on internal threads.)
- **1 → 0**: a key person leaves, a project pauses, or the counterparty explicitly de-prioritizes. (Example: I was 1 because pain was mentioned; new transcript says "this isn't urgent anymore.")

Demotions are always low-confidence (`applied=N`). The user reviews in `friday-review`.

## Multi-dimension change rule

If a single signal would cause more than one dimension to change in one sweep, treat the entire score update as **low-confidence** (`applied=N`). The signal is rich enough to deserve human review; the bot should not apply multiple deltas at once. The user can apply each delta individually in `friday-review`.

Exception: a single signal can demote multiple dimensions simultaneously if a deal is dying (e.g. champion leaves → CH drops AND I drops AND E drops). In that case still mark `applied=N`; the user confirms the deal is dying before the row is updated.

## Recomputing SCORE and MEDDPICC Score

Whenever any dimension's numeric value changes (whether applied or not), the orchestrator recomputes:

```
SCORE = sum of the eight 0|1|2 values  (range 0..16)
MEDDPICC Score = SCORE / 16             (percent, e.g. 0.50 = 50%)
```

These only get written to the Sheet when the underlying change is applied (`applied=Y`).

## Examples

### Example 1: I goes 0 → 2 (high confidence)

Existing row: `I = Identified Pain · 0`.
Signal: transcript excerpt — "We're losing four senior engineers a quarter to recruiter outreach because we have no way to mute LinkedIn at scale. That's costing us roughly $400k in replacement hires per year. We need a solution by end of Q2."

→ Suggested: `I = 2`. Confidence: high. Apply. Activity Log summary: "I: 0 → 2 (transcript: $400k/year cost, EOQ2 deadline). One dimension changed — applied."

### Example 2: CH and E both go 0 → 2 in one signal (low confidence — multi-dimension)

Existing row: `CH = 0`, `E = 0`.
Signal: meeting transcript shows Sarah (VP Eng) actively advocating + naming Maya (CFO) as the one who signs off.

→ Suggested: `CH = 2` AND `E = 1` (Maya is named but the user hasn't met her). Confidence: low — TWO dimensions changing on one signal. Activity Log `applied=N` for both. Summary: "Possible CH: 0 → 2 (Sarah actively advocating) AND E: 0 → 1 (Maya named as decision-maker). Confirm in friday-review."

### Example 3: Demotion of CH (low confidence)

Existing row: `CH = 2`.
Signal: a thread that previously had the champion (Sarah) copied no longer includes her; the new internal contact is someone the user doesn't know.

→ Suggested: `CH = 1`. Confidence: low (the omission could be procedural, not a signal). Activity Log `applied=N`. Summary: "Possible CH demotion: 2 → 1 (champion no longer copied on internal threads). Confirm in friday-review."

## References

- `references/meddpicc-rubric.md` — extended scoring rubric and per-dimension probing questions.
- [The $500M MEDDPICC secrets revealed (Predictable Revenue)](https://predictablerevenue.com/blog/500m-meddpicc-secrets-revealed-how-zendesk-is-able-to-forecast-revenue-within-1) — the canonical write-up.
