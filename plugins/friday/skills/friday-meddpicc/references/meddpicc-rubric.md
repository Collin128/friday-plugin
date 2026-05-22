# MEDDPICC scoring rubric — extended

> Reference doc, bundled with the `friday-meddpicc` skill. Per-dimension probing questions and additional context. The SKILL.md is the operational rubric; this is the supporting material.

## The eight dimensions, in question form

For each dimension, here's the question that, when answered with conviction, justifies a `2`.

| Dim | Probing question | What a `2` looks like |
|---|---|---|
| **M** — Metrics | "What specific number changes for them after they buy?" | The counterparty quotes a target metric and a baseline. "We need to cut handoff time from 4 hours to 30 minutes." |
| **E** — Economic Decision Maker | "Who, by name, has budget authority to say yes?" | Named, actively engaged in conversations with the user. |
| **DC** — Decision Criteria | "What three things matter most when they evaluate?" | A written or stated short list, in their words, that the user can echo back. |
| **DP** — Decision Process | "Who reviews, when, in what order, with what timeline?" | A mapped sequence: this person reviews, then security, then legal, then signature — usually 4–6 weeks. |
| **P** — Paper Process | "What's the legal/procurement path?" | The user has been pointed to the procurement portal, has the MSA template, or knows the named legal contact. |
| **I** — Identified Pain | "What is current pain costing them in concrete terms?" | A quote in their words + a cost. "We're losing $X/quarter because of this." |
| **CH** — Champion | "Who's selling the user internally when the user isn't in the room?" | Actively looping in stakeholders, repeating the user's pitch, flagging risks early. |
| **CP** — Competition | "Who else is in this deal, and what differentiates the user?" | Named competitors + specific differentiation. |

## Common scoring mistakes

- **Confusing friendly with championing.** A friendly contact who returns emails on time is a `1`, not a `2`. The `2` is someone visibly selling the user internally.
- **Counting "we're looking at options" as `CP=1`.** It is — but generic statements without named competitors stay at `1`, never `2`.
- **Inflating M because the user wrote a business case.** The user's business case is not the same as the counterparty agreeing to specific metrics. Counterparty must engage with the numbers for a `2`.
- **Scoring DP as `2` based on a single name.** "Sarah signs off" isn't a process. The `2` is a mapped sequence with timelines.

## When scores stagnate

If a deal sits at a sub-50% MEDDPICC score for more than 30 days, that's a signal worth surfacing in `friday-review`. The plugin doesn't automatically demote the row, but the daily sweep notes when a row's `SCORE` has been unchanged for 30 days and `Next Action Date` is overdue — that's a candidate for the user to re-qualify or move to Closed-Lost-Nurture.

## Why MEDDPICC matters more than stage

In DISCO, the stage tells you where the deal *is*; MEDDPICC tells you whether the deal will actually close. A DISCO 4 (Solution Validation) row with a SCORE of 4/16 is a much shakier deal than a DISCO 2 (Discovery) row with a SCORE of 12/16. `follow-up-friday`'s stale-deal ranker weights MEDDPICC SCORE × time-since-touch precisely because the highest-MEDDPICC deals that go cold are the most rescuable ones.
