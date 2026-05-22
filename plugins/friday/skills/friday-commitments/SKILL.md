---
name: friday-commitments
description: |
  Called by friday-sweep, friday-backfill, and friday-heuristics on
  outbound emails and meeting transcripts to extract iWill / theyWill
  commitments and follow-up dates. Powers h4 (overdue theyWill) and
  the iWill nudge. Not invoked directly by the user.
---

# friday-commitments

Pulls structured commitments out of an outbound message body or a meeting transcript. The schema is identical across email and transcript — `iWill`, `theyWill`, `followupBy`.

Ported from `worker/services/commitments.ts` in the FollowUp repo.

## When to invoke

Called by an orchestrator skill (`friday-sweep`, `friday-backfill`) on every OUTBOUND message or every meeting transcript where the user was a participant. Never called on inbound messages — those don't represent the user's commitments.

For email, only the BODY is examined (not subject, not headers, not signature). For transcripts, the user's spoken portions are the priority but the counterparty's commitments are also extracted (those become `theyWill` items).

## Inputs

The orchestrator passes:

- `body`: the message body text, or the transcript text (already deduped + cleaned).
- `kind`: `gmail` | `fireflies` — informs the prompt slightly (transcripts are looser language).
- `direction`: `outbound` only for gmail.

## Outputs

A structured payload:

```json
{
  "iWill": [
    "send the pricing deck this week",
    "follow up after the security review"
  ],
  "theyWill": [
    "intro me to Sarah",
    "share the architecture diagram by Friday"
  ],
  "followupBy": "2026-05-30"
}
```

Field rules:

- `iWill`: short imperative sentences (≤ 12 words each) describing what the **sender** committed to.
- `theyWill`: same shape but for what the **recipient/counterparty** committed to.
- `followupBy`: ISO 8601 date (`YYYY-MM-DD`) when the sender plans to follow up. `null` if no date is explicit.
- Empty arrays + `null` followupBy is a valid result — many messages have no commitments.

## Extraction prompt (the system prompt used by this skill)

When invoking the LLM, use this system prompt verbatim. Same shape as `worker/services/commitments.ts:16-21`:

```
You extract concrete commitments from outbound business emails (or meeting
transcripts where the speaker is the user). Return STRICT JSON with keys:

  iWill:       array of short imperative sentences for what the SENDER
               committed to (<= 12 words each, no markdown)
  theyWill:    array of short imperative sentences for what the RECIPIENT
               committed to (<= 12 words each)
  followupBy:  an ISO-8601 date string (YYYY-MM-DD) when the sender will
               follow up, or null if unclear

If the input is transactional/newsletter/no commitments, return empty
arrays and null followupBy.
```

Then pass the body or transcript text with: `"EMAIL:\n\n{body}\n\nReturn only JSON."` (or `"TRANSCRIPT:..."` for fireflies).

## Skip conditions

- **Direction is inbound (gmail)**: skip. Inbound messages contain the counterparty's commitments, not the user's. Those get inferred when the orchestrator processes the corresponding outbound (if any) or directly by `friday-heuristics` h4 logic.
- **Body length < 10 characters**: skip. Set `iWill=[]`, `theyWill=[]`, `followupBy=null` and move on. No LLM call needed.
- **Sender domain is in the automation list** (per [[friday-heuristics]] § Noise filters): skip.
- **Already extracted** (idempotency): check Activity Log for a prior `signal_match` row with the same `evidence_link` and a populated `extractedCommitments`. If found, reuse — don't re-extract.

## Examples

### Example 1: clear iWill + followupBy

Body:

> "Thanks for the call — really enjoyed walking through the architecture.
>
> I'll get the security questionnaire over to you by Friday so your team can start their review. Talk Monday?"

Output:

```json
{
  "iWill": ["send security questionnaire by Friday"],
  "theyWill": [],
  "followupBy": "2026-05-29"
}
```

### Example 2: theyWill only

Body:

> "Appreciate the demo. To move forward we'll need ROI numbers for our internal review. Can you share the case study you mentioned with the 40% reduction number? We'll loop in Maya from finance once we have it."

Output:

```json
{
  "iWill": [],
  "theyWill": ["loop in Maya from finance once they have the case study"],
  "followupBy": null
}
```

> Note: in this message the SENDER (user) is asking for something — that's not an iWill, it's a request. The counterparty's "we'll loop in Maya" is the only commitment.

### Example 3: transactional → empty

Body:

> "Your invoice for May has been generated. View it at https://..."

Output:

```json
{
  "iWill": [],
  "theyWill": [],
  "followupBy": null
}
```

### Example 4: meeting transcript with both sides committing

Transcript excerpt:

> [00:32] You: "I'll write up the integration scope by Wednesday."
> [00:48] Priya: "Got it — once I have that, I'll get it in front of our architecture council on Friday and circle back."

Output:

```json
{
  "iWill": ["write up integration scope by Wednesday"],
  "theyWill": ["present scope to architecture council on Friday and circle back"],
  "followupBy": "2026-05-27"
}
```

## How extracted commitments are used

- **iWill** drives the "iWill follow-up" rule in [[friday-heuristics]] § iWill follow-up. If 7+ days pass with no newer outbound to the same person, surface the matched row in the next sweep's "actions overdue today" output.
- **theyWill** drives [[friday-heuristics]] § h4 (overdue theyWill commitment). If `followupBy` passes (or 7 days pass without a `followupBy`) and no inbound has arrived, surface as a Triage row.
- **followupBy** sets the `Next Action Date` field on a matched pipeline row when the matched row has no existing `Next Action Date`. Per [[friday-sheet]] write discipline, this is a `next_action_update` Activity Log row with `applied=Y`.

## Failure modes

- **LLM returns malformed JSON**: log to Activity Log with `applied=N`, `summary="Commitment extraction returned non-JSON for {evidence_link}"`. Do not block the sweep — the rest of the matching pipeline continues.
- **LLM returns a JSON shape that doesn't match** (missing keys, wrong types): same as above — `applied=N` Activity Log entry, skip.

## See also

- [[friday-heuristics]] — h4 (overdue theyWill) consumes the output of this skill
- [[friday-sheet]] — Activity Log discipline + writeable columns (`Next Action Date`)
