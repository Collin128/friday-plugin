# How to manually exercise friday-deals

> Since this skill has no automated tests in v1 (per the plugin's prompt-only design — see `CONVENTIONS.md`), the way to validate it works is to invoke it manually in Cowork against a few hand-constructed signals.

## Setup

1. Create a test Google Sheet using the SHARED CRM template. Don't use your real CRM.
2. Add 3–5 fake rows across MEET / DISCO with known `Company` + `Name`. Include at least one with a deliberately-similar Company name (e.g. `Coalesce` and `Coalesce.io`) to stress ambiguity.
3. Set `friday-deals`-relevant rows manually so you know exactly what should match.

## Exercise 1 — clean domain match

Tell Claude in Cowork:

> "Pretend the following Gmail thread just landed in my inbox. Use friday-deals to tell me what it matches.
>
> ```json
> {paste the contents of example-gmail-thread.json}
> ```
>
> My test Sheet is at {test_sheet_url}."

Expected output: `matched` to the row you set up, `match_strategy: "domain"`.

## Exercise 2 — apex / subdomain match

Same payload as Exercise 1 but change the sender email to `priya@mail.coalesce.com` (a subdomain).

Expected: `matched`, `match_strategy: "apex"`.

## Exercise 3 — free-email name match

Use the transcript example (`example-transcript.md`). Tell Claude:

> "Pretend this Fireflies transcript just dropped. Use friday-deals to match it."

Expected: `matched`, `match_strategy: "name"`.

## Exercise 4 — ambiguity

Add two pipeline rows with identical `Company` and `Name` (e.g. one in MEET, one in DISCO). Re-run Exercise 1.

Expected: `ambiguous` with both rows as candidates. The orchestrator should write Activity Log `applied=N`.

## Exercise 5 — unmatched

Change the sender email to a domain you don't have any row for (e.g. `engineer@vendoroptimal.io`) and the sender name to a name you don't have (`Maya Chen`).

Expected: `unmatched`. The orchestrator would next hand this signal to `friday-heuristics`.

## What to look for

For each exercise, verify:

- Claude correctly identifies the counterparty (i.e. drops the user's own email from `participants`).
- The match strategy returned is the one specified above.
- Ambiguous cases are NOT auto-picked.
- Unmatched cases produce a clean handoff to `friday-heuristics` (no fabricated match).

File observed discrepancies as issues against the plugin repo. Spec divergences also belong in the source repo's `implementation-notes.html`.
