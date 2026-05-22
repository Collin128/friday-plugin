---
name: follow-up-friday
description: |
  Weekly Friday-morning ritual. Surfaces the top 5 deals across all
  pipelines that have gone > 30 days without activity, ranked by
  MEDDPICC SCORE × time-since-touch. Each pick gets a suggested
  reconnect draft. Invoked by Cowork's /schedule weekly task; also
  manually invokable.
---

# follow-up-friday

The Friday ritual. Distinct from `friday-sweep`:

- `friday-sweep` is **reactive** — "what happened since yesterday."
- `follow-up-friday` is **proactive** — "which warm deals are quietly dying."

Capped at 5 deals on purpose. The same "five minutes, done" forcing function that the user's original FollowUp web app uses. An unbounded list gets scrolled past; a top-5 list gets dispatched.

## When to invoke

- Weekly via the `/schedule` task: `"run follow-up-friday using sheet <SHEET_URL>"`, scheduled for Friday morning.
- Manually if the user says "do my follow-ups", "run Friday ritual", "what's gone cold", or invokes the existing `/follow-up-friday` slash convention.

## Inputs

- The user's Sheet URL.
- Account context (the user's own email).
- Cached read of all four pipeline tabs + Activity Log.

## Algorithm

### 1. Read the Sheet

Read MEET, DISCO, MANAGE, NURTURE + Activity Log. Skip Triage — this ritual is about existing pipeline rows, not new candidates.

### 2. Compute days_since_activity for every pipeline row

For each row in the four pipelines:

```
days_since_activity = max(0, today - most_recent_of(
    last_outbound_to_row,            # any Gmail outbound to the row's domain or Name
    last_inbound_from_row,            # any Gmail inbound from the row's domain or Name
    last_calendar_event_with_row,    # any Calendar event with the row's counterparty
    last_activity_log_entry_for_row  # any Activity Log row referencing this Company + Name
))
```

If no activity is on record (a brand-new row not yet touched), use the row's `Next Action Date` or, as a last resort, the row's creation date (the earliest Activity Log entry for the row).

### 3. Filter to stale rows

Keep only rows where:

- `days_since_activity > 30`, AND
- `Opp Stage` is NOT a terminal stage:
  - MEET 6 (FOAD)
  - DISCO 6 (Closed-Won), DISCO 7 (Closed-Lost-* — any variant)

(MANAGE and NURTURE have no terminal stages — every row is fair game.)

### 4. Rank by composite score

For each candidate row:

```
meddpicc_pct = SCORE / 16                            # range 0..1
freshness    = min(1, days_since_activity / 60)      # caps at 60 days
composite    = meddpicc_pct * freshness
```

Sort descending by `composite`. The formula favors **high-MEDDPICC deals that just crossed the staleness threshold** — the most rescuable, most regrettable-to-lose ones. A 90-day-stale row at 8/16 MEDDPICC outranks a 35-day-stale row at 2/16, but is outranked by a 35-day-stale row at 14/16.

For DISCO rows where MEDDPICC SCORE is meaningful: use the formula as-is.
For MEET / MANAGE / NURTURE rows where MEDDPICC isn't scored: substitute `meddpicc_pct = 0.5` (treat as neutral middle). This keeps the freshness signal but doesn't fabricate qualification confidence.

### 5. Take the top 5

Cap at 5. If fewer than 5 candidates exist, surface all of them. If exactly 0 — that's a valid result (see § Output edge cases).

### 6. Dedupe against prior weeks

For each candidate, check the Activity Log for a `stale_resurface` row with the same `row_company` + `row_name` AND `timestamp > today - 14 days`. If found, drop this candidate from the surface list (it was surfaced recently — surfacing the same deal every Friday until the user does something is annoying, not useful).

If de-duping leaves fewer than 5 candidates, take the next-ranked rows from step 5 to refill (up to 5 total). If the entire stale-deal set has been surfaced in the last 14 days, that's a "you're caught up" result — see § Output edge cases.

### 7. Generate drafts

For each of the (≤ 5) picked rows, invoke [[friday-draft]] with the `low-context-reconnect` archetype. The draft context payload:

```json
{
  "person": {
    "name": "<row.Name>",
    "company": "<row.Company>",
    "relationship_type": "<inferred from domain>"
  },
  "last3Threads": [<up to 3 most recent threads, oldest snippet excerpted>],
  "priorFollowupsSent": 0,
  "suggestedSubject": null
}
```

`friday-draft` returns a 2–3 line nudge email.

### 8. Write the output

Render to the Scheduled tasks page:

```
🟡 Follow-up Friday — {today_date}

5 deals went quiet. Top to bottom: most rescuable first.

1. Acme — Drew Houston — DISCO 4 — 34 days quiet — SCORE 14/16
   Subject: Q3 timing
   Drew, you mentioned wanting this in place before Q3 — is that still
   the target window, or has it slipped? Happy to just close the thread
   if priorities moved.
   [send] [snooze 2w] [skip]

2. Coalesce — Priya Patel — DISCO 3 — 41 days quiet — SCORE 9/16
   ...

3. ...
```

Per row: Company, Name, Stage, days_since_activity, SCORE, the draft (subject + body), inline actions. The actions ("send", "snooze", "skip") are interactive in `friday-review`.

### 9. Log stale_resurface rows

For each surfaced row, append one Activity Log entry:

- `action_kind` = `stale_resurface`
- `applied` = `N` (the draft hasn't been sent yet)
- `summary` = `"Follow-up Friday top {rank} — {Company} ({days_since_activity}d quiet, SCORE {N}/16)"`
- `evidence_link` = empty (this isn't tied to a Gmail/Calendar URL)

These rows are how step 6 dedupes next week.

## Output edge cases

- **Zero candidates** (no stale rows OR everyone was surfaced in the last 14 days): print one line: `"Follow-up Friday — {today_date} — Nothing stale this week. Either everyone is fresh, or you've already been surfaced. Nice."`
- **Fewer than 5 candidates** (e.g. only 2 stale deals exist after the 30d/non-terminal filter): print "Follow-up Friday — 2 deals went quiet" and surface both. Don't pad with dimmer candidates just to hit 5.
- **All candidates have SCORE = 0** (pipeline rows without MEDDPICC populated): still surface them. Annotate `"(no MEDDPICC scored yet)"` next to the SCORE field.

## State written

- Activity Log: one `stale_resurface` row per surfaced deal (with `applied=N`).

That's it. `follow-up-friday` doesn't modify pipeline rows directly — the user's actions in `friday-review` (or directly sending the draft via their Gmail client) drive the next state changes.

## Why a separate orchestrator instead of folding into friday-sweep

- **Different cadence** (weekly vs daily) → distinct `/schedule` entries make the user's intent explicit.
- **Different output shape** (top-5 ranked nudge list vs today's overdue + Triage delta).
- **Different mental model** — the Friday ritual is a named recurring practice; the daily sweep is a passive briefing.
- **Easier to iterate** the ranking and draft generation independently.

## Why cap at 5

Forcing function. If the list is unbounded, the user scrolls past it. Capping at 5 makes the ritual completable in under 10 minutes — the same five-minutes-done promise that drove the original FollowUp design. If the top 5 are dispatched and the user has appetite for more, they can re-invoke the skill on demand.

## Failure modes

- **Drive connector revoked** → same as `friday-sweep`: refuse to mutate, surface "reauthorize Drive."
- **MEDDPICC SCORE column missing on a row** → treat as `SCORE=0`, surface anyway, annotate `"(no MEDDPICC scored yet)"`.
- **friday-draft fails on a row** → surface the row with `"(draft unavailable — see `friday-review` to generate)"` in place of the draft body. Don't drop the row.
- **All candidates already de-duped** → see § Output edge cases.

## See also

- [[friday-draft]] — generates the reconnect drafts
- [[friday-sheet]] — schema + write discipline
- [[friday-funnels]] — terminal-stage list (the filter in step 3)
- [[friday-review]] — where the user actually sends / snoozes / skips
- [[friday-sweep]] — the daily reactive counterpart
