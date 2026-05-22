---
name: friday-sweep
description: |
  Daily reactive sweep. Reads new Gmail / Calendar / Fireflies signals
  since last_sweep_at, matches them to pipeline rows or surfaces them
  in Triage, and prints the morning briefing on Cowork's Scheduled
  tasks page. Invoked daily by /schedule with the user's Sheet URL.
---

# friday-sweep

The daily heartbeat. Every morning, Cowork's `/schedule` fires `friday-sweep`. The skill reads new signals since `last_sweep_at`, runs them through the matching + classification pipeline, writes the resulting updates to the Sheet, and prints the morning briefing.

Each scheduled run is a **fresh session** with no memory of prior runs. All durable state — what's been processed, what's pending — lives in the Sheet. `MAX(Activity Log timestamp)` is the pointer.

## When to invoke

- Daily via the `/schedule` task the user pasted at install time: `"run friday-sweep using sheet <SHEET_URL>"`.
- Manually if the user says "run today's sweep" or similar.

Cowork's catch-up rule: if the machine was asleep or Claude Desktop was closed at trigger time, Cowork skips and runs **exactly one** catch-up on next wake. This skill must therefore be idempotent — derive "what's new" from `MAX(Activity Log timestamp)`, never from a counter the scheduler manages.

## Inputs

- The user's Sheet URL (embedded in the `/schedule` task string).
- Cached account context (the user's own email from the Cowork account).

## Steps

### 1. Read the Sheet

Read all six tabs in one batch (per [[friday-sheet]] § Reading the Sheet):

- MEET, DISCO, MANAGE, NURTURE → for the match index
- Triage → for dedupe + the "M new candidates" count
- Activity Log → for `last_sweep_at` and idempotency

Cache the read in working memory for the rest of the sweep.

### 2. Compute last_sweep_at

```
last_sweep_at = MAX(Activity Log timestamp WHERE action_kind != 'backfill_week_complete')
```

- If the Activity Log is empty: fall back to `now - 24h`. This is the day-1-after-setup case.
- If `last_sweep_at` is more than 7 days old: run the sweep with a 7-day window and surface a note in the output (see § Output).

### 3. Pull new signals

Using the native connectors, pull signals with `timestamp > last_sweep_at`:

- Gmail messages: filter `internalDate > last_sweep_at`. Both `inbound` and `outbound`.
- Calendar events: filter `updated > last_sweep_at`. Past, present, future events all count if updated.
- Fireflies transcripts: filter `date > last_sweep_at`.

### 4. Process signals in deterministic order

Order: Gmail oldest → newest, then Calendar oldest → newest, then Fireflies oldest → newest. Deterministic order means re-running the same sweep produces the same Activity Log timing.

For each signal:

1. Invoke [[friday-deals]].
2. **If matched**:
   - For DISCO rows: consult [[friday-meddpicc]] on signal-relevant dimensions. Apply or log per write discipline.
   - Consult [[friday-funnels]] for stage-transition signals (calendar event happening on a Meeting Booked row, etc.). Apply or log per write discipline.
   - For outbound messages and transcripts: invoke [[friday-commitments]] to extract iWill/theyWill, write to Activity Log.
   - For overdue iWill commitments on the matched row: surface in the morning briefing's "actions overdue today" section.
3. **If unmatched**:
   - Invoke [[friday-heuristics]]. If a rule fires, write a Triage row + Activity Log entry.
4. **If ambiguous**: per [[friday-deals]] § Ambiguity handling — Activity Log `applied=N`, surface in `friday-review`.
5. Every signal produces *at least* one Activity Log row, even if it's a `signal_match` with `applied=N` for an unactionable signal. This is the dedupe key for the next sweep.

### 5. Compute today's actionable rows

After processing all new signals:

1. For each row in MEET / DISCO / MANAGE / NURTURE, check:
   - `Next Action Date ≤ today` (overdue)
   - AND `Opp Stage` is NOT one of the terminal stages:
     - MEET 6 (FOAD)
     - DISCO 6 (Closed-Won), DISCO 7 (any Closed-Lost variant)
     - (MANAGE and NURTURE have no terminal stages)
2. Collect these into the "actions overdue today" list.

### 6. Produce the morning briefing

Write the structured output to the Scheduled tasks page:

```
Friday — morning briefing for {today_date}

🟡 Overdue today ({N})

  • Acme — Drew Houston — DISCO 3 — Next action: send security questionnaire — 2 days overdue
  • Coalesce — Priya Patel — MEET 4 — Next action: send follow-up email — overdue today
  • ... up to 10, prioritized by days_overdue desc

🆕 New candidates in Triage ({M})

  Top 3 by confidence:
  • coalesce.com — Priya Patel — h6 (pricing silence) — high
  • glean.com — Arvind Jain — meeting-held-no-follow — high
  • vendoroptimal.io — Maya Chen — h1 (unanswered outbound) — high
  ({M - 3} more in the Triage tab.)

🔄 Pipeline updates ({K})

  • Applied: {A} (stage changes + MEDDPICC deltas with high confidence)
  • Pending review: {P} (low-confidence — review with `friday-review`)

→ Say "review Friday" or run `friday-review` to walk through it.
```

### 7. Adjust output for edge cases

- **Nothing to report** (zero overdue, zero new Triage, zero pipeline updates): print `"Friday — {today_date} — Nothing new today. Inbox is calm."`. Decision rationale: surface a one-line "all quiet" signal rather than silence, so the user knows the sweep ran successfully.
- **`last_sweep_at` > 7 days old**: prepend the briefing with `"⚠️ Friday was idle for {N} days. Showing the last 7 days only. Consider re-running `friday-backfill` if you want full coverage."`
- **One or more connectors failed**: append a footer `"Connector status: Gmail ✓ · Calendar ✓ · Fireflies ✗ (re-authorize in Settings)"`. Sweep still runs with the available connectors.

## State written

- Stage changes + MEDDPICC deltas on pipeline rows (high-confidence applied; low-confidence logged-only).
- Triage rows for new candidates (always `status=pending`).
- Activity Log: one row per signal processed.

## Output

The morning briefing in § 6, written to Cowork's Scheduled tasks page. Per [[friday-sheet]] § Reading the Sheet, the briefing is the user-visible artifact — the Sheet is the durable state.

## Failure modes

- **Sheet URL invalid or Drive connector revoked** → refuse to mutate anything. Write one Activity Log row if possible. Output: `"❌ Could not access Sheet at {url}. Reauthorize Google Drive in Settings → Connectors and re-run."` and stop.
- **Gmail / Calendar / Fireflies connector revoked** → continue with the remaining connectors. Log which connector is missing. Output a footer noting the partial coverage.
- **Sheet schema drifted** (user renamed a column or tab) → refuse to write to the affected tab. Log to Activity Log `applied=N` per affected write attempt. Output: `"⚠️ Sheet schema mismatch on tab {tab}: expected column '{col}' not found. No writes performed on this tab today."` No auto-healing.
- **`last_sweep_at` > 7 days old** → run with 7-day window (see § 7 edge cases).
- **Same signal seen twice** (e.g. Gmail returns the same message via a connector quirk) → [[friday-deals]] / [[friday-heuristics]] idempotency dedupes by `evidence_link`. No double-writes.
- **A heuristic / matcher LLM call errors** → log to Activity Log `applied=N`, `summary="Error processing {evidence_link}: {error}"`. Continue with remaining signals. Don't fail the whole sweep on one bad signal.

## See also

- [[friday-sheet]] — schema + write discipline + last_sweep_at definition
- [[friday-deals]] — matching layer invoked on every signal
- [[friday-heuristics]] — invoked on every unmatched signal
- [[friday-funnels]] / [[friday-meddpicc]] — invoked on matched rows for stage / score updates
- [[friday-commitments]] — invoked on every outbound + transcript
- [[friday-review]] — what the user invokes to walk through the briefing's pending items
- [[follow-up-friday]] — the weekly Friday-morning counterpart; distinct cadence + output
