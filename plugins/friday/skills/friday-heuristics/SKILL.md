---
name: friday-heuristics
description: |
  Called by friday-sweep and friday-backfill for signals that did NOT
  match an existing pipeline row (per friday-deals). Evaluates the
  opportunity-ID rules h1, h2, h4, h5, h6, and meeting-held-no-follow,
  and produces Triage rows with confidence. Also filters out automation
  and all-internal noise. Not invoked directly by the user.
---

# friday-heuristics

The opportunity-ID engine. When a signal lands and `friday-deals` returns `unmatched`, this skill decides: is this a candidate the user should know about, or noise to discard?

Ported from `worker/services/candidateGeneration.ts` and `worker/services/messageFilters.ts` in the FollowUp repo.

## When to invoke

Called by `friday-sweep` and `friday-backfill` only when `friday-deals` returned `{ status: "unmatched", counterparty: {...} }` AND the signal passed the noise filters (§ Noise filters). Never invoked directly by a user.

## Inputs

The orchestrator passes:

- The unmatched signal (with `kind`, `evidence_link`, `participants`, `subject/title`, `body/description/summary`, `direction`).
- The detected counterparty (from `friday-deals` § Counterparty detection).
- The relationship-type guess for the counterparty's domain (if known) — see § Relationship-type tuning.
- The full Activity Log read for idempotency.
- The cached Triage rows (avoid duplicates by `evidence_link` or `(company, name, signal_kind)`).

## Outputs

Zero, one, or two candidate Triage rows. Each candidate carries:

```
{
  signal_kind: "h1|h2|h4|h5|h6|meeting-held-no-follow",
  confidence: "low|medium|high",
  company: "<best guess from domain or signature>",
  name: "<counterparty name>",
  suggested_pipeline: "MEET" | "NURTURE",
  suggested_next_action: "<one-line draft>"
}
```

The orchestrator writes Triage rows + paired Activity Log entries with `applied=Y` (the Triage add itself is high-confidence; the *contents* of the Triage row are what the user evaluates).

## Noise filters (apply BEFORE evaluating any rule)

If any of the following are true, return zero candidates immediately:

### isAutomation

Drop the signal if any of:

- Sender's local-part (left of `@`) matches an automation prefix: `noreply`, `no-reply`, `donotreply`, `do-not-reply`, `notifications`, `notification`, `mailer`, `mailer-daemon`, `postmaster`, `automated`, `system`, `alerts`, `alert`, `updates`, `info`, `newsletter`.
- Sender's local-part *contains* one of `noreply`, `no-reply`, `donotreply`, `do-not-reply` (substring match — catches `jobs-noreply@...`, `messaging-noreply@...`, etc.).
- Sender's domain ends in: `.linkedin.com`, `.github.com`, `.stripe.com`, `.calendly.com`, `.docusign.com`, `.atlassian.net`.
- Sender's domain is exactly: `notifications.google.com`, `mail.notion.so`.
- Gmail folder/category is one of: `CATEGORY_PROMOTIONS`, `CATEGORY_UPDATES`, `CATEGORY_FORUMS`, `SPAM`, `JUNK`.

### isAllInternal

Drop the signal if all participants' email domains equal the user's own domain. Friday is for tending external relationships — internal threads are out of scope.

### Out-of-office

If the sender's domain is known to be OOO (e.g. their last reply was an auto-reply containing OOO phrases like "out of the office until..."), defer all heuristics on this person until the OOO window passes.

## The seven heuristics

Each rule has: a precondition, a confidence assignment, and the Triage row it produces. The orchestrator dedupes when multiple rules would fire on the same person — keep the highest-confidence one.

### h1 — Unanswered outbound question

**Precondition:**

- Signal kind = `gmail`, direction = `outbound`.
- The last 300 characters of the body contain a `?`.
- The "wait" threshold has elapsed (see § Relationship-type tuning).
- No inbound from the counterparty has arrived since the outbound was sent.

**Confidence:** `high` (was 75 in FollowUp; high-equivalent here).

**Triage row produced:**

- `signal_kind`: `h1`
- `suggested_pipeline`: `MEET`
- `suggested_next_action`: "Re-ask the question; they may not have seen the original. {paraphrased question}"

### h2 — Unanswered inbound question

**Precondition:**

- Signal kind = `gmail`, direction = `inbound`.
- The last 300 characters of the body contain a `?`.
- At least 2 days have passed.
- Either the user has not replied OR the reply is shorter than 100 characters (proxy for "didn't actually answer").
- There exists at least one prior outbound to this counterparty from the user (confirms a real conversation, not a stranger).

**Confidence:** `high` (was 80 in FollowUp).

**Triage row produced:**

- `signal_kind`: `h2`
- `suggested_pipeline`: `MEET`
- `suggested_next_action`: "Answer the question — they asked '{paraphrased question}' and you haven't responded substantively."

### h4 — Overdue theyWill commitment

**Precondition:**

- Signal kind = `gmail`, direction = `outbound`.
- Body extracted `theyWill` commitments (via `friday-commitments`) is non-empty.
- Either `followupBy` has passed, OR `followupBy` is null AND the outbound is more than 7 days old.
- No inbound from the counterparty has arrived since.

**Confidence:** `medium` (was 70 in FollowUp).

**Triage row produced:**

- `signal_kind`: `h4`
- `suggested_pipeline`: `MEET`
- `suggested_next_action`: "They committed to '{theyWill item}' by {followupBy or '7+ days ago'}. Nudge them."

### h5 — Thread death

**Precondition:**

- Thread has ≥ 3 total messages.
- The most recent message in the thread is outbound from the user.
- That outbound is ≥ 7 days old.
- No inbound has arrived since.

**Confidence:** `medium` (was 65 in FollowUp).

**Triage row produced:**

- `signal_kind`: `h5`
- `suggested_pipeline`: `MEET`
- `suggested_next_action`: "Active thread went silent. Last touch was your message {N} days ago."

> Note: h5 overlaps with h1. Per the source, h1 (confidence 75) wins when both fire on the same person — drop h5 in that case.

### h6 — Pricing / proposal silence

**Precondition:**

- Signal kind = `gmail`, direction = `outbound`.
- Body contains, as a word-boundary match (case-insensitive), any of: `pricing`, `proposal`, `quote`, `estimate`, `order form`, `sow`, `msa`, `dpa`.
- At least 5 days have passed.
- No inbound from the counterparty since.

**Confidence:** `high` (was 85 in FollowUp).

**Triage row produced:**

- `signal_kind`: `h6`
- `suggested_pipeline`: `MEET`
- `suggested_next_action`: "Sent {pricing artifact} {N} days ago — no reply. Acknowledge silence; offer an honest out."

### meeting-held-no-follow

**Precondition:**

- Signal kind = `calendar` (event) OR `fireflies` (transcript) where the event/meeting `start` was ≥ 14 days ago.
- The event is non-recurring.
- No outbound from the user to this counterparty has been sent since `start`.

**Confidence:** `high` (was 80 in FollowUp).

**Triage row produced:**

- `signal_kind`: `meeting-held-no-follow`
- `suggested_pipeline`: `MEET`
- `suggested_next_action`: "Met on {date} ({event title}) — no outbound since. Send a follow-up."

### iWill follow-up (high-context-commitment)

> Strictly speaking this rule is for MATCHED rows, not unmatched signals — it's evaluated by `friday-funnels` / `friday-commitments` when a matched row has an overdue iWill. Documented here for completeness so the rule set in one place mirrors `gatherHighContext` in the source.

**Precondition:**

- Outbound message with `iWill` commitments.
- ≥ 7 days have passed.
- No newer outbound to that person.

**Confidence:** `high` (was 85 in FollowUp).

**Action:** the orchestrator writes a `next_action_update` Activity Log row on the matched pipeline row, surfacing the overdue iWill commitment in the next sweep's "actions overdue today" output. No Triage row.

## Relationship-type tuning (for h1 timer)

The "long enough to wait" threshold for h1 depends on what kind of relationship the counterparty represents:

| Relationship type | Threshold for h1 |
|---|---|
| `prospect` / `investor` | 2 days (high cadence expected) |
| `customer` / `friend` | 7 days (lower cadence) |
| unknown / other | 4 days (default) |

Relationship type is inferred from the counterparty's domain via heuristics: known prospect domains (paste your relationship-domains list into [[friday-sheet]]'s extended notes — TBD before publishing), free-email domains default to `unknown`, the user's own domain is `internal` (signal already filtered).

## Composite score (used by orchestrator for ranking, NOT by this skill)

When the orchestrator has more candidates than it can surface, it ranks by:

```
recencyScore = exp(-ageInDays / 90)              # half-life 90 days
interactionScore = min(1, interaction_count / 50)  # saturates at 50
composite = 0.6 * recencyScore + 0.4 * interactionScore
```

`interaction_count` is the count of prior messages between the user and the counterparty. This formula is ported verbatim from `computeCompositeScore` in `candidateGeneration.ts` and is used by `follow-up-friday` for the weekly top-5 ranker. The daily sweep does NOT cap candidates — it surfaces all of them.

## Deduping when multiple rules fire on one person

If h1 and h5 both fire on the same person:

- h1 wins (higher confidence in the source).

If h6 and h5 both fire:

- h6 wins (pricing-specific is more actionable).

General rule: pick the single highest-confidence rule per person per signal. Don't add two Triage rows for the same counterparty in the same sweep.

## Idempotency

Before producing a Triage row, check:

1. Is there already a Triage row with the same `evidence_link` AND `status=pending`? → don't duplicate.
2. Is there already an Activity Log row with `action_kind=triage_added`, same `evidence_link`, regardless of current Triage status? → don't duplicate (the user may have dismissed or graduated; respect that decision).

## Examples

### Example 1: h1 fires (high confidence)

Counterparty: `priya@coalesce.com`, relationship type unknown (default 4-day threshold).
Outbound on 2026-05-16: "Hey Priya — does the per-seat price scale linearly past 500 seats?"
No inbound since. Today is 2026-05-22. 6 days > 4-day default threshold.

→ Produce one Triage row with `signal_kind=h1`, `confidence=high`, `suggested_next_action="Re-ask the per-seat pricing question; she may not have seen the original."`

### Example 2: noise filter drops a LinkedIn notification

Inbound from `messaging-noreply@linkedin.com`. Sender's domain matches the `.linkedin.com` suffix rule.

→ Drop. No Triage row, no Activity Log row. Move on.

### Example 3: h2 fires (high confidence)

Counterparty: `arvind@glean.com`. Prior outbound exists.
Inbound on 2026-05-19: "...and on the integration side — do you support OIDC out of the box, or only SAML?"
User's reply on 2026-05-21 is 32 chars: "Good question, let me check." → shorter than 100. 3 days > 2-day threshold.

→ Produce Triage row with `signal_kind=h2`, `confidence=high`, `suggested_next_action="Answer the OIDC support question — your last reply was a placeholder."`

### Example 4: h6 fires (high confidence)

Outbound on 2026-05-15 with body containing "Attaching our **pricing** deck for your review." No inbound since. Today is 2026-05-22. 7 days > 5-day threshold.

→ Produce Triage row with `signal_kind=h6`, `confidence=high`, `suggested_next_action="Sent pricing deck 7 days ago — no reply. Acknowledge silence; offer an honest out."`

### Example 5: meeting-held-no-follow

Calendar event "Discovery — Coalesce" on 2026-05-05. Today 2026-05-22 (17 days). Non-recurring. No outbound to anyone at coalesce.com since 2026-05-05.

→ Produce Triage row with `signal_kind=meeting-held-no-follow`, `confidence=high`, `suggested_next_action="Met on 2026-05-05 (Discovery — Coalesce) — no outbound since. Send a follow-up."`

## See also

- [[friday-deals]] — invoked first; only unmatched signals reach this skill
- [[friday-commitments]] — extracts the iWill / theyWill payload that h4 needs
- [[friday-sheet]] — Triage row schema + Activity Log discipline
- [[follow-up-friday]] — uses the same composite score for weekly stale-deal ranking
