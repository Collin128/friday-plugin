---
name: friday-review
description: |
  Use when the user says "review Friday", "what do I need to follow up on",
  "do my follow-ups", "clear my queue", or wants to walk through today's
  overdue rows, pending Triage candidates, and low-confidence Activity
  Log entries. The ONLY skill that applies pending changes to the Sheet.
---

# friday-review

The interactive cleanup ritual. `friday-sweep` is non-interactive — it surfaces; `friday-review` is the *only* place pending changes get applied.

## When to invoke

- User says: "review Friday", "what do I need to follow up on", "do my follow-ups", "clear my queue", "go through Triage", "walk me through today".
- After the user opens Claude Desktop and sees the morning briefing from `friday-sweep`, they invoke this skill to actually act on it.
- After `follow-up-friday` produces the weekly top 5, the user can invoke `friday-review` to interact with each (send, snooze, skip).

## Inputs

- The user's Sheet URL (ask if not in the prompt — the user typically just says "review Friday" without specifying).
- Account context (the user's own email).

## Steps

### 1. Read the Sheet

All six tabs cached for the duration of the review session — see [[friday-sheet]] § Reading the Sheet.

### 2. Compute today's worklist

Three queues, presented in this order:

1. **Overdue rows** — pipeline rows where `Next Action Date ≤ today` AND `Opp Stage` is not a terminal stage. Sorted by `days_overdue` desc (most overdue first).
2. **Pending Triage rows** — Triage rows where `status=pending`. Sorted by `discovered_at` desc (most recent first).
3. **Pending Activity Log entries** — Activity Log rows where `applied=N` AND no `reverted_at`. Sorted by `timestamp` desc.

If a queue is empty, skip its section in the walk.

### 3. Walk the worklist

Present the user with a summary first:

```
Friday review — {today_date}

You have:
  • {N} overdue rows
  • {M} pending Triage candidates
  • {K} low-confidence Activity Log entries to confirm

Walk through them? (yes / skip-overdue / triage-only / log-only)
```

Then for each item in each queue (one at a time), present the item and a menu of actions. The user picks; the skill writes the result; the skill moves to the next item.

### 4a. Overdue row — per-item actions

```
{N of {total}} — Overdue 3 days

  Pipeline: DISCO
  Company: Acme
  Name: Drew Houston
  Stage: 4: Solution Validation
  Next Action: send security questionnaire
  Next Action Date: 2026-05-19 (3 days ago)

  Recent activity:
    • 2026-05-19 — Outbound email "Re: SOC2 timing"
    • 2026-05-15 — Meeting "Acme — security review"

  Actions:
    s  send / draft an outbound (invokes friday-draft)
    n  update Next Action + Next Action Date
    p  move to next stage (suggests DISCO 5 — Verbal)
    z  snooze 1 week (push Next Action Date out)
    x  mark stage Closed-Lost-Nurture (moves to NURTURE)
    k  skip — leave as-is, will reappear tomorrow
```

For each action, write the corresponding Sheet update + Activity Log row per [[friday-sheet]] write discipline.

- **`s` send/draft** → invoke [[friday-draft]] with the inferred archetype (commitment / meeting / reconnect). Present the subject + body. Offer: `[send via Gmail] [edit] [rewrite with feedback]`. On send, write a `next_action_update` row (Next Action becomes "sent {subject} on {today}") and an Activity Log entry with `action_kind=draft_generated, applied=Y`. Don't actually send — the user copies the draft into Gmail; Friday is suggestion-only on the send side.
- **`n` update Next Action** → prompt for new text + date. Write the cell + Activity Log `next_action_update, applied=Y`.
- **`p` advance stage** → suggest the next stage per [[friday-funnels]] § Stage taxonomies. Confirm with the user. Write the cell + Activity Log `stage_change, applied=Y`.
- **`z` snooze 1w** → bump `Next Action Date` by 7 days. Write Activity Log `next_action_update, applied=Y, summary="Snoozed 1 week"`.
- **`x` mark Closed-Lost-Nurture** → set `Opp Stage` to the terminal stage, ADD a NURTURE row for the same Company + Name (no Notes copy). Write two Activity Log entries.
- **`k` skip** → no Sheet write. The row will reappear in tomorrow's `friday-sweep` overdue list.

### 4b. Pending Triage row — per-item actions

```
{N of {total}} — Triage candidate

  signal_kind: h6 (pricing silence)
  Company: Coalesce
  Name: Priya Patel
  discovered_at: 2026-05-21 (1 day ago)
  Suggested pipeline: MEET
  Suggested next action: "Sent pricing deck 7 days ago — no reply. Acknowledge silence; offer an honest out."
  evidence_link: https://mail.google.com/...

  Actions:
    g  graduate — add a row in {MEET / DISCO / MANAGE / NURTURE} at stage {N}
    d  dismiss — mark dismissed, don't surface again
    z  snooze 2 weeks — push discovered_at window
    e  edit — change company, name, signal_kind, or suggested_next_action
    o  open the evidence link
    k  skip — leave as pending, walk to next
```

On `g` graduate: prompt for pipeline + stage. Validate the stage against [[friday-funnels]] § Stage taxonomies. Add the new pipeline row (Company, Name, Opp Stage; leave Notes empty for the user to fill). Update the Triage row's `status=accepted` and `decided_at=now`. Write paired Activity Log entries.

On `d` dismiss: update Triage row `status=dismissed`, `decided_at=now`. Write Activity Log `triage_added → status:dismissed, applied=Y`.

On `z` snooze: set `discovered_at = today + 14 days`. Activity Log entry. The Triage row remains pending but won't resurface in this review session.

On `e` edit: prompt for the field to edit, write the new value to the Triage row, then re-present the row for the next action.

### 4c. Pending Activity Log entry — per-item actions

```
{N of {total}} — Low-confidence change

  action_kind: meddpicc_update
  Tab: DISCO
  Row: Acme — Drew Houston
  Summary: "Possible CH demotion 2 → 1 (champion no longer copied on internal threads)"
  evidence_link: https://mail.google.com/...
  Logged: 2026-05-21

  Actions:
    a  apply — write the change to the pipeline row
    r  reject — mark reverted_at, don't apply
    e  edit-and-apply — modify the suggested change before applying
    o  open the evidence link
    k  skip
```

On `a` apply: write the suggested update to the pipeline row. Update the Activity Log row's `applied=Y` (mutates the original row — per [[friday-sheet]], this is the one mutation we allow on Activity Log: flipping `applied` from N to Y when the user approves a pending change). Write a paired Activity Log row noting the apply.

On `r` reject: set `reverted_at=now` on the Activity Log row. No Sheet mutation.

On `e` edit-and-apply: prompt for the modified value, then apply.

### 5. Final summary

After walking the queue (or after the user says "stop"):

```
Friday review complete.

  Overdue rows: {N actioned} / {M total}
    - {A drafts generated, B advanced, C snoozed, D skipped}
  Triage: {N graduated, M dismissed, K snoozed, L skipped}
  Pending changes: {N applied, M rejected, K skipped}

Skipped items will reappear in tomorrow's sweep.
```

## State written

Everything written through this skill goes through [[friday-sheet]] discipline. The unique-to-review writes:

- Flipping Activity Log `applied=N` → `applied=Y` when the user approves a pending change.
- Setting `decided_at` on Triage rows.
- Setting `reverted_at` on Activity Log rows the user rejects.

These are the only places where Activity Log rows are mutated rather than appended. Everywhere else is append-only.

## Output

The streaming per-item walk. Final summary in § 5.

## Failure modes

- **User says "stop" or "pause" mid-walk** → write the final summary based on actions taken so far. Remaining items stay in their current state.
- **`friday-draft` errors during `s` send/draft action** → surface to user, offer to skip-and-continue. Don't fail the whole review.
- **Sheet write fails on apply** → retry once. If still failing, surface "Sheet write failed — change not applied. Try again later." Continue with next item.
- **No items in any queue** → print "Friday review — nothing to review. Inbox is calm." and exit.

## See also

- [[friday-sweep]] — produces the morning briefing that motivates this review
- [[follow-up-friday]] — its top 5 deals are reviewed inline (each pick can be sent, snoozed, or skipped via this skill's actions)
- [[friday-draft]] — invoked on `s` send/draft
- [[friday-sheet]] — write discipline; this skill is the only place applied=N flips to applied=Y
- [[friday-funnels]] / [[friday-meddpicc]] — consulted when staging an advance or applying a pending score change
