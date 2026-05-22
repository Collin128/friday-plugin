# example-transcript.md

> Sanitized Fireflies transcript snippet showing a name-only (Strategy 3) match because the counterparty's email is on a free-email domain.

## Expected match

```json
{
  "status": "matched",
  "pipeline": "MEET",
  "row_company": "Coalesce",
  "row_name": "Priya Patel",
  "match_strategy": "name"
}
```

## Assumed pipeline rows

| tab | Company | Name | Opp Stage |
|---|---|---|---|
| MEET | Coalesce | Priya Patel | 3: Meeting Booked |

## Assumed user email

`you@yourcompany.com`

## Transcript metadata

- `kind`: `fireflies`
- `evidence_link`: `https://app.fireflies.ai/view/TRANSCRIPT_ID_PLACEHOLDER`
- `title`: `Coalesce <> YourCo intro`
- `participants`:
  - `{ "email": "you@yourcompany.com", "name": "You" }`
  - `{ "email": "priyapatel@gmail.com", "name": "Priya Patel" }`

## Why this hits Strategy 3 (name)

`priyapatel@gmail.com` is on a free-email domain (`gmail.com`), so domain strategies 1 and 2 are skipped. Strategy 3 normalizes the counterparty name `Priya Patel` against the existing MEET row's `Name` column (also `Priya Patel`) — exact match, single row → matched.

## Transcript excerpt (sanitized)

```
[00:01:12] Priya: I'm hopeful — the team has been frustrated with our current vendor.
[00:01:45] You: Got it. What's the timeline for making a decision?
[00:02:10] Priya: Probably end of next month. We need this in place before Q3 kicks off.
[00:02:40] Priya: I'll loop in Sarah next week — she owns budget for this.
```

## What an orchestrator does next

After `friday-deals` returns matched, the orchestrator:

1. Reads the existing MEET row's `Opp Stage` = `3: Meeting Booked`. The transcript implies the meeting happened (Stage 4). Consult `friday-funnels` § MEET transitions → 3 → 4 (high confidence, applied).
2. Reads the transcript for MEDDPICC signals. "I'll loop in Sarah next week — she owns budget" suggests E (Economic Decision Maker) might move 0 → 1. Consult `friday-meddpicc` § E. Apply if single-dimension change.
3. Writes two Activity Log rows: one for the stage change (`applied=Y`), one for the E delta (`applied=Y` if single dimension).
