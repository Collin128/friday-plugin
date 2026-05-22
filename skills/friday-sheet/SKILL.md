---
name: friday-sheet
description: |
  Canonical Google Sheet schema and write discipline for the Friday plugin.
  Every skill that reads or writes the user's Sheet consults this skill for
  column definitions and write rules. Not invoked directly by the user —
  it's a reference loaded by other skills.
---

# friday-sheet

This skill is the source of truth for the Friday Sheet: which tabs exist, which columns each tab has, what types they hold, and the discipline every write must follow. Other skills (`friday-sweep`, `friday-backfill`, `friday-review`, `friday-deals`, etc.) consult this skill before reading or writing.

## When to invoke

Loaded as reference by every skill that touches the Sheet. Never invoked directly by a user. If the user asks about the Sheet schema, an orchestrator skill consults this and answers.

## Identifying the user's Sheet

Each scheduled-task prompt embeds the user's Sheet URL (or Sheet ID). The plugin does not store this anywhere; it lives in the `/schedule` task string the user pasted at install time. If a skill cannot find a Sheet URL in its prompt, it should ask the user before guessing.

To read or write the Sheet, use the Google Sheets connector tools that the user authorized in their Claude account. Native connector tools are not redeclared by this plugin.

## Tabs

Six tabs total. Four are user-facing pipeline tabs (unchanged from the user's existing template). Two are Friday-managed.

### MEET, DISCO, MANAGE, NURTURE (pipeline tabs — user-facing)

Same columns across all four:

| Column | Type | Owner | Notes |
|---|---|---|---|
| `Company` | string | user | never overwritten by Friday |
| `MEDDPICC Score` | percent (computed) | Friday | `SCORE / 16`. Friday recomputes when any underlying score changes. |
| `Opp Stage` | dropdown (pipeline-specific) | Friday-suggests / user-confirms | See § Stage taxonomies. |
| `Next Action` | string ≤ 100 chars | Friday | the one-line "what's next" |
| `Next Action Date` | date | Friday | when the action is due |
| `Name` | string | user | the champion / counterparty; never overwritten by Friday |
| `Notes` | free-form | user | never overwritten by Friday |
| `Metric / M` | `<label> + 0\|1\|2` | Friday-suggests | MEDDPICC dimension; see `friday-meddpicc` |
| `Economic Decision Maker / E` | `<label> + 0\|1\|2` | Friday-suggests | |
| `Decision Criteria / DC` | `<label> + 0\|1\|2` | Friday-suggests | |
| `Decision Process / DP` | `<label> + 0\|1\|2` | Friday-suggests | |
| `Paper Process / P` | `<label> + 0\|1\|2` | Friday-suggests | |
| `Identified Pain / I` | `<label> + 0\|1\|2` | Friday-suggests | |
| `Champion / CH` | `<label> + 0\|1\|2` | Friday-suggests | |
| `Competition / CP` | `<label> + 0\|1\|2` | Friday-suggests | |
| `SCORE` | int 0..16 | Friday | sum of the eight MEDDPICC scores |

### Triage (Friday-managed; user reviews and graduates)

Friday adds rows; the user moves them out via `friday-review`.

| Column | Type | Notes |
|---|---|---|
| `discovered_at` | timestamp | when Friday surfaced this |
| `evidence_link` | URL | Gmail thread URL or Calendar event URL or Fireflies transcript URL |
| `company` | string | best guess from email domain / signature |
| `name` | string | person you exchanged with |
| `signal_kind` | enum | `h1 \| h2 \| h4 \| h5 \| h6 \| meeting-held-no-follow` |
| `suggested_pipeline` | enum | `MEET \| NURTURE` (Friday's guess) |
| `suggested_next_action` | string | one-line draft |
| `confidence` | enum | `low \| medium \| high` |
| `status` | enum | `pending \| accepted \| dismissed \| snoozed` |
| `decided_at` | timestamp | when the user moved this out of triage |

### Activity Log (Friday-managed; append-only)

Every Sheet write produces one Activity Log row. Append-only.

| Column | Type | Notes |
|---|---|---|
| `timestamp` | UTC ISO 8601 | when the change happened |
| `tab` | string | which tab was touched, or `Triage` |
| `row_company` | string | identifier of the affected row |
| `row_name` | string | identifier of the affected row |
| `action_kind` | enum | `stage_change \| next_action_update \| meddpicc_update \| signal_match \| draft_generated \| note_added \| triage_added \| stale_resurface \| backfill_week_complete` |
| `summary` | string | one-line description of the change |
| `evidence_link` | URL | the email / event / transcript that justified it |
| `applied` | `Y \| N` | high-confidence = applied; low-confidence = logged only, surfaced in `friday-review` |
| `reverted_at` | timestamp | if the user manually reverted the change |

`MAX(timestamp)` on Activity Log where `action_kind != 'backfill_week_complete'` is Friday's "last successful sweep" pointer. There is no separate counter file.

## Stage taxonomies (per pipeline)

| Pipeline | Stages |
|---|---|
| MEET | 0: Cold • 1: Approaching • 2: Connected • 3: Meeting Booked • 4: Meeting Held • 5: Moved to Disco • 6: FOAD |
| DISCO | 1: Qualify • 2: Discovery • 3: Solution Review • 4: Solution Validation • 5: Verbal • 6: Closed-Won • 7: Closed-Lost-Nurture • 7: Closed-Lost-Competitor • 7: Closed-Lost-FOAD |
| MANAGE | 1: Onboarding • 2: Adopting • 3: Wildly Successful (customer-success specific) |
| NURTURE | 0: Cold (monthly cadence) |

The canonical definitions of each stage (what counts as "Solution Validation", when does MEET 3 become DISCO 1, etc.) live in `friday-funnels` / `references/sales-guide.md`.

## Write discipline

Every skill that mutates the Sheet follows these rules without exception.

1. **Never delete a row.** Friday only adds or updates. If a row is wrong, the user deletes it manually — Friday does not delete.
2. **Never overwrite `Company`, `Name`, or `Notes`.** User-owned columns. If Friday wants to suggest a change to these, it writes to Activity Log with `applied=N` and `action_kind=note_added` and waits for `friday-review`.
3. **Writable columns:** `Next Action`, `Next Action Date`, `Opp Stage`, the eight MEDDPICC label+score pairs, `MEDDPICC Score`, `SCORE`. That's the entire write surface on the pipeline tabs.
4. **Every Sheet write produces one Activity Log row** with `timestamp`, `tab`, `row_company`, `row_name`, `action_kind`, `summary`, `evidence_link`, `applied`. No silent writes.
5. **Confidence policy:**
   - **High confidence** = applies the change to the pipeline row AND writes Activity Log with `applied=Y`. Example: a calendar event "Discovery call with Acme" + an existing Acme row at MEET stage 3 (Meeting Booked) → move to MEET stage 4 (Meeting Held).
   - **Low confidence** = does NOT apply the change. Writes Activity Log with `applied=N` and a `summary` explaining what Friday saw but isn't sure about. The user reviews and either applies or rejects in `friday-review`.
6. **Multiple-dimension MEDDPICC change at once** = low confidence (`applied=N`). Forces user review. A single dimension going 0 → 2 with clear evidence is fine.
7. **Triage rows are always added with `status=pending`**. Friday never auto-graduates a Triage row into a pipeline tab — only `friday-review` (user-driven) moves a row out of Triage.
8. **`friday-review` is the only place pending changes get applied.** The daily sweep is non-interactive. If a skill is in doubt, defer to review.

## Reading the Sheet

Skills typically need three reads at the start of a sweep:

1. **All four pipeline tabs** — to build the in-memory match index (`Company` + `Name` → row) for `friday-deals`.
2. **Triage tab** — to know which candidates are already pending (avoid duplicates).
3. **Activity Log tab** — to compute `last_sweep_at` and for the matching skill's idempotency check (don't re-process an `evidence_link` already in the Log).

Cache the read result in working memory for the duration of the skill invocation. Don't re-read the Sheet between rows of the same signal batch.

## last_sweep_at

```
last_sweep_at = MAX(Activity Log timestamp where action_kind != 'backfill_week_complete')
```

Fall back to 24h ago if the Activity Log is empty (handles day-1-after-setup).

If `last_sweep_at` is more than 7 days old, run the sweep with a 7-day window and surface `"Friday was idle for N days — consider re-running friday-backfill if you want full coverage."` in the output.

## Examples

### Example 1: appending a stage change to Activity Log

Calendar event "Discovery call with Acme" landed today. Existing MEET row for Acme at stage 3 (Meeting Booked). High confidence → apply.

Activity Log row to append:

| timestamp | tab | row_company | row_name | action_kind | summary | evidence_link | applied |
|---|---|---|---|---|---|---|---|
| `2026-05-22T13:14:00Z` | `MEET` | `Acme` | `Drew Houston` | `stage_change` | `MEET 3 → 4 (calendar event "Discovery call with Acme" today)` | `https://calendar.google.com/event?eid=...` | `Y` |

Then update the MEET row's `Opp Stage` cell from `3: Meeting Booked` to `4: Meeting Held`.

### Example 2: adding a new Triage row

Inbound email from `priya@coalesce.com`, no existing row matches `coalesce.com` in any pipeline. h1 fires (unanswered outbound question 14 days ago to `priya@coalesce.com`).

Triage row to append:

| discovered_at | evidence_link | company | name | signal_kind | suggested_pipeline | suggested_next_action | confidence | status | decided_at |
|---|---|---|---|---|---|---|---|---|---|
| `2026-05-22T13:14:00Z` | `https://mail.google.com/...` | `Coalesce` | `Priya Patel` | `h1` | `MEET` | `Re-ask the pricing-tier question; she didn't see the original.` | `high` | `pending` | (empty) |

Then append a paired Activity Log row with `tab=Triage`, `action_kind=triage_added`, `applied=Y` (the Triage row was added — that change itself is high confidence, even though Triage is a pending state).
