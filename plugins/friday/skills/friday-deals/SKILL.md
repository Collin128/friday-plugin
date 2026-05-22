---
name: friday-deals
description: |
  Called by friday-sweep and friday-backfill on every incoming signal
  (Gmail thread, Calendar event, Fireflies transcript). Matches the
  signal to an existing pipeline row by Company + Name, handling domain
  aliases, free-email domains, and ambiguity. Not invoked directly by
  the user.
---

# friday-deals

The matching layer. Given a signal (an email thread, a calendar event, a meeting transcript), `friday-deals` returns one of:

- **Matched** to a specific pipeline row in MEET / DISCO / MANAGE / NURTURE.
- **Ambiguous** — multiple rows could match. Don't pick; log to Activity Log with `applied=N` and surface in `friday-review`.
- **Unmatched** — no pipeline row matches. Hand the signal to `friday-heuristics` to decide if it belongs in Triage.

## When to invoke

Called by `friday-sweep` and `friday-backfill` on every incoming signal *before* any heuristic evaluation. The matching outcome determines the next step:

```
signal → friday-deals → matched ──→ apply stage / MEDDPICC update
                     → ambiguous → log applied=N + surface in review
                     → unmatched → friday-heuristics → maybe Triage
```

Never invoked directly by the user.

## Inputs

The orchestrator passes:

1. The signal (Gmail thread, Calendar event, or Fireflies transcript) including:
   - `kind`: `gmail | calendar | fireflies`
   - `evidence_link`: the canonical URL for this signal
   - `participants`: array of `{ email, name? }` for all parties
   - `subject` (gmail/calendar) or `title` (fireflies)
   - `body` (gmail) or `description` (calendar) or `summary` (fireflies)
   - `direction` (gmail only): `inbound | outbound`
2. The cached read of all four pipeline tabs from the current sweep (`Company`, `Name` for every row).
3. The user's own email address (from Cowork account context — see § Counterparty detection).

## Outputs

A structured result the orchestrator can act on:

- **matched**: `{ status: "matched", pipeline: "MEET|DISCO|MANAGE|NURTURE", row_company: "...", row_name: "...", match_strategy: "domain|apex|name|alias" }`
- **ambiguous**: `{ status: "ambiguous", candidates: [{ pipeline, row_company, row_name }, ...], reason: "..." }`
- **unmatched**: `{ status: "unmatched", counterparty: { email, name?, domain? } }`

## Counterparty detection

Before any matching, identify the **counterparty** — the not-the-user person/people in the signal:

1. Read the user's own email address from Cowork account context (the connector knows who the authenticated user is).
2. Compute the user's domain via § Domain extraction below.
3. From the signal's `participants`, drop any participant whose email equals the user's email OR whose email's domain equals the user's domain. The remainder is the counterparty set.
4. If the counterparty set is empty (all-internal signal), return `{ status: "unmatched", reason: "all-internal" }` — the orchestrator should skip this signal.

## Matching strategies (in order)

### Strategy 1: Exact domain match

For each counterparty email:

1. Extract the domain via § Domain extraction.
2. If the domain is in the free-email list (see § Free-email domains), SKIP this strategy and continue to strategy 2 (name match). Free-email domains are too generic to identify a company.
3. Look for pipeline rows where `Company` normalizes to a value that contains the domain's apex or vice versa. Normalization:
   - Lowercase both sides.
   - Strip "Inc", "LLC", "Ltd", "Corp", "Co.", commas, periods.
   - Compare both the full domain and the apex (e.g. `predictablerevenue.com` AND `predictablerevenue`).
4. If exactly one row matches → return **matched** with `match_strategy: "domain"`.
5. If multiple rows match → check for additional disambiguation via name match (§ Strategy 2 narrowing). If still ambiguous → return **ambiguous**.

### Strategy 2: Apex / subdomain match

If exact-domain didn't match, try the apex (strip subdomains):

- `mail.predictablerevenue.com` → apex `predictablerevenue.com`.
- `sales.zendesk.com` → apex `zendesk.com`.

Re-run strategy 1 with the apex domain. If a single row matches → return **matched** with `match_strategy: "apex"`.

### Strategy 3: Name match

If domain strategies didn't match (or the counterparty's email is on a free-email domain):

1. For each counterparty's `name` (if present):
   - Normalize: lowercase, trim whitespace, strip non-letter characters except spaces.
   - Look for pipeline rows whose `Name` column normalizes to a match (exact, or one is a substring of the other with at least 5 characters of overlap).
2. If exactly one row matches → return **matched** with `match_strategy: "name"`.
3. If multiple rows match → return **ambiguous**.

### Strategy 4: Alias match

If none of the above matched and the counterparty's email is on a non-free domain, check the Activity Log for prior `signal_match` entries where the same counterparty email appeared. If a prior match exists for an email at the same domain → return **matched** by alias to the row indicated in that prior log entry, with `match_strategy: "alias"`. This handles the case where Sarah at Acme uses `sarah@acme.com` AND `sarah.harvey@gmail.com` for different threads — Friday remembers via Activity Log that both belong to the same row.

## Ambiguity handling

When more than one pipeline row matches a signal, DO NOT PICK. Return `{ status: "ambiguous", candidates: [...], reason: "..." }`.

The orchestrator then:

1. Writes one Activity Log row with:
   - `action_kind = signal_match`
   - `applied = N`
   - `summary = "Ambiguous: signal could match <pipeline1>:<company1>:<name1> OR <pipeline2>:<company2>:<name2>. Resolve in friday-review."`
   - `evidence_link = the signal's URL`
2. Does NOT update any pipeline row.

The user resolves the ambiguity in `friday-review` — picks the right row, or declares the signal doesn't match either, or merges the two rows.

## Idempotency

Before returning a match, check the Activity Log for a prior `signal_match` row with the same `evidence_link`. If found:

- If the prior log says `applied=Y` and matched the same row → return matched with no new Activity Log write (the orchestrator skips writing duplicate logs).
- If the prior log says `applied=N` (ambiguous) → re-evaluate: maybe the user has added a disambiguating row since then. If still ambiguous, don't write a new log either.

This guarantees that re-running `friday-backfill` on a previously-processed week is safe — no double-writes.

## Domain extraction

```
domainOf(email):
  at = lastIndexOf("@")
  if at < 0: return null
  return lowercase(email[at+1:])
```

Free-email domains are skipped from domain matching but NOT skipped from name matching.

## Free-email domains

```
gmail.com, yahoo.com, hotmail.com, outlook.com, icloud.com,
protonmail.com, aol.com, me.com, live.com
```

If a counterparty's domain is in this list, the matcher treats the domain as **non-identifying**. Skip domain strategies for that participant and rely on name match alone (Strategy 3).

## Examples

### Example 1: clean domain match (matched)

Signal: inbound Gmail thread from `priya@coalesce.com`.
Existing rows include MEET row `Company=Coalesce`, `Name=Priya Patel`.

→ Strategy 1 matches on domain `coalesce.com` ↔ `Coalesce`. Single row. Return `{ status: "matched", pipeline: "MEET", row_company: "Coalesce", row_name: "Priya Patel", match_strategy: "domain" }`.

### Example 2: subdomain apex match (matched)

Signal: inbound email from `priya@mail.coalesce.com` (a subdomain).
Existing MEET row `Company=Coalesce`.

→ Strategy 1 doesn't match `mail.coalesce.com` to `Coalesce` exactly. Strategy 2 falls back to apex `coalesce.com` → matches. Return `{ status: "matched", pipeline: "MEET", row_company: "Coalesce", row_name: "Priya Patel", match_strategy: "apex" }`.

### Example 3: free-email + name match (matched)

Signal: inbound Gmail thread from `priyapatel@gmail.com`, sender name = `Priya Patel`.
Existing MEET row `Company=Coalesce`, `Name=Priya Patel`.

→ Strategy 1 skipped (gmail.com is free-email). Strategy 3 matches on name normalization. Return `{ status: "matched", pipeline: "MEET", row_company: "Coalesce", row_name: "Priya Patel", match_strategy: "name" }`.

### Example 4: ambiguous (don't pick)

Signal: inbound from `john@acme.com`, sender name = `John Smith`.
Existing rows:
- MEET `Company=Acme`, `Name=John Smith`
- DISCO `Company=Acme`, `Name=John Smith`

→ Strategy 1 matches both rows. Return `{ status: "ambiguous", candidates: [{ pipeline: "MEET", ... }, { pipeline: "DISCO", ... }], reason: "Same Company + Name in both MEET and DISCO. Likely the deal was promoted from MEET to DISCO but the MEET row wasn't archived." }`.

The orchestrator writes Activity Log `applied=N`. User resolves in `friday-review`.

### Example 5: unmatched (heuristics next)

Signal: inbound from `engineer@vendoroptimal.io`, sender name = `Maya Chen`.
No pipeline row matches `vendoroptimal.io` or `Maya Chen` or any apex variant.

→ Return `{ status: "unmatched", counterparty: { email: "engineer@vendoroptimal.io", name: "Maya Chen", domain: "vendoroptimal.io" } }`.

The orchestrator hands this to `friday-heuristics` to decide if it's a Triage candidate.

## References

- `references/fixtures/example-gmail-thread.json` — sanitized Gmail signal payload, annotated with expected match.
- `references/fixtures/example-transcript.md` — sanitized Fireflies transcript snippet, annotated with expected match.
- `references/fixtures/how-to-exercise.md` — one-paragraph manual-exercise guide for testing this skill in Cowork.

## See also

- [[friday-sheet]] — schema + write discipline for the rows being matched
- [[friday-heuristics]] — invoked when this skill returns `unmatched`
- [[friday-funnels]] — invoked when this skill returns `matched` and a stage transition might apply
- [[friday-meddpicc]] — invoked when this skill returns `matched` and a DISCO row might have a score change
