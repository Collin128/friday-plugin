---
name: friday-backfill
description: |
  Sequential 52-week walk through the user's Gmail + Calendar + Fireflies
  history. Invoked by friday-setup at install time, or directly by the
  user (e.g. "re-run backfill"). Checkpoints via Activity Log so it
  resumes on interruption. Idempotent.
---

# friday-backfill

The seed step. Friday is most useful once it has 52 weeks of context — which heuristics fire, which rows graduate from Triage, which deals look stale. `friday-backfill` walks the user's history one week at a time, applying the same matching + classification pipeline as the daily sweep.

## When to invoke

- Automatically: by `friday-setup` step 4 (first-time install).
- Manually: when the user says "re-run backfill", "rebuild Friday's history", "backfill another year", etc.

Never invoked by a scheduled task. Backfill is interactive enough that the user starts it deliberately — `friday-sweep` is what runs daily.

## Inputs

- The user's Sheet URL (passed in by `friday-setup`, or asked from the user if invoked manually).
- Optional: a custom window (e.g. "backfill the last 90 days" — useful for dogfooding before going full 52w).

## The walk

Walk the window `[today - N weeks, today]` in weekly chunks, oldest → newest. For each week W:

1. **Resume check.** Read the Activity Log. If there's already a `backfill_week_complete` row for week W (matched by `summary` containing the week's start date), skip — this week is already done. Move to W+1.
2. **Pull signals for week W:**
   - Gmail messages where `internalDate` falls in W.
   - Calendar events where `start` falls in W.
   - Fireflies transcripts where `date` falls in W.
3. **Process each signal in deterministic order** (Gmail oldest → newest, then Calendar oldest → newest, then Fireflies oldest → newest):
   - Invoke [[friday-deals]]. If matched: consult [[friday-funnels]] for stage transitions and [[friday-meddpicc]] for score updates (DISCO only). If unmatched: consult [[friday-heuristics]].
   - Invoke [[friday-commitments]] on every outbound message and every transcript where the user was a participant.
   - Write the corresponding Sheet rows + Activity Log entries per [[friday-sheet]] § Write discipline.
4. **Week checkpoint:** append one Activity Log row:
   - `timestamp` = now
   - `tab` = `Activity Log`
   - `row_company` = `(backfill)`
   - `row_name` = `(backfill)`
   - `action_kind` = `backfill_week_complete`
   - `summary` = `"Backfill week of YYYY-MM-DD complete — N signals processed, M Triage rows added, K row updates."`
   - `evidence_link` = empty
   - `applied` = `Y`
5. **Progress output:** print one line to the user:
   - `"Week N of 52 done — X candidates, Y row updates. (~T minutes remaining at current pace.)"`
6. Move to W+1.

## Resume semantics

On any invocation:

1. Read the Activity Log.
2. Find the most recent `backfill_week_complete` row.
3. The next week to process is the one immediately after the date in that row's summary.
4. If no `backfill_week_complete` rows exist, start from `today - 52 weeks`.

This guarantees that interrupting backfill mid-run (user closes Claude Desktop, machine sleeps, network blip) is safe — the next invocation resumes at the next week.

## Idempotency within a week

If backfill is interrupted *mid-week* (e.g. partway through processing week W's signals), the next invocation re-runs the whole of week W. This is safe because:

- [[friday-deals]] checks the Activity Log for a prior `signal_match` with the same `evidence_link` before writing. Re-processed signals don't produce duplicate Activity Log rows.
- [[friday-heuristics]] checks for a prior `triage_added` Activity Log row with the same `evidence_link`. Re-processed signals don't produce duplicate Triage rows.
- [[friday-commitments]] checks for a prior extraction and reuses it.

The "all writes go through evidence_link-keyed dedupe" invariant is what makes resumability cheap.

## Estimated runtime

- ~30–60 minutes for a full 52-week backfill, sequential.
- Dominant cost is the LLM call per outbound message + per transcript (commitment extraction). Skipping cost dominates the rest.
- Token cost: scales linearly with the user's outbound volume. For a typical knowledge worker (~10 outbound emails/day, 5 meetings/week) → roughly 10k LLM calls over 52 weeks at ~150 tokens each = ~1.5M tokens total.

If the user wants a faster run, suggest a 90-day window first:

> "Run friday-backfill with a 90-day window to dogfood — that takes ~5–10 minutes and surfaces enough Triage rows to spot-check whether the matching looks right."

## State written

- Pipeline-row updates (stage changes, MEDDPICC score updates) per [[friday-funnels]] / [[friday-meddpicc]] confidence policy.
- Triage rows for unmatched signals that hit a heuristic.
- Activity Log rows: one per signal processed + one `backfill_week_complete` per week.

## Output

Streaming progress: one line per week. Final summary:

```
Backfill complete (52 weeks, 18,432 signals processed).

  • 73 Triage rows added — review with `friday-review`
  • 14 pipeline row stage updates (all applied — see Activity Log)
  • 8 MEDDPICC score deltas (3 applied, 5 pending review)
  • Wall time: 47 minutes
```

## Failure modes

- **User closes Claude Desktop mid-run** → next invocation resumes at next week. Tell the user this is expected; nothing was lost.
- **A connector (Gmail / Calendar / Fireflies) is revoked mid-run** → log to Activity Log: `applied=N`, `summary="Connector X became unavailable during backfill of week of YYYY-MM-DD. Resume after re-authorizing."`. Then stop. Don't continue with degraded connectors during backfill (the goal is comprehensive seeding — partial coverage during the seed is a worse user experience than stopping).
- **A specific week's signal batch exceeds reasonable size** (e.g. > 10k Gmail messages — should never happen for a single user) → log warning, process the first 5k by `internalDate`, write `backfill_week_complete` with a note that the week was capped, move on.
- **Sheet write fails** → retry once with backoff. If the second attempt fails, stop and surface "Sheet write failed during backfill week of YYYY-MM-DD — check Drive connector status and retry."

## See also

- [[friday-setup]] — invokes this skill at install time
- [[friday-sweep]] — daily reactive counterpart; uses the same matching pipeline on a 1-day window
- [[friday-deals]] — invoked on every signal
- [[friday-heuristics]] — invoked on every unmatched signal
- [[friday-commitments]] — invoked on every outbound + every transcript
- [[friday-sheet]] — schema + write discipline (every backfill write goes through here)
