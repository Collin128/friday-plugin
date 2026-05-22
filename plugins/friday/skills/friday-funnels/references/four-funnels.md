# The Four Funnels framework

> Reference doc, bundled with the `friday-funnels` skill. Summarizes the Predictable Revenue Four Funnels framework that grounds the MEET / DISCO / MANAGE / NURTURE pipelines.
>
> This is a short orientation. The canonical text lives in the user's Sales Guide (see `sales-guide.md`).

## The premise

Every revenue pipeline pulls from one of four sources. They have different cadences, different conversion rates, and different motions. Lumping them together hides where revenue is actually coming from.

| Funnel | Predictable Revenue name | This plugin's pipeline | Source of demand |
|---|---|---|---|
| Inbound | "Nets" | **MEET** (then DISCO) | Demand comes to you — content, referrals, inbound demo requests. |
| Outbound | "Spears" | **MEET** (then DISCO) | You generate demand — outbound emails, cold calls, LinkedIn. |
| Existing customers | "Farming" | **MANAGE** | Expansion, renewal, advocacy. |
| Warm relationships | "Seeds" | **NURTURE** | Long-cycle warm contacts — podcast guests, dormant prospects, advisors. |

In this plugin we don't separate Inbound from Outbound at the pipeline level — both flow into **MEET** and (when qualified) into **DISCO**. The distinction matters for *attribution* and for *which heuristics fire*, but stage transitions are the same regardless of source.

## Why this matters for Friday

- **MEET pipeline**: high-volume, fast-cycle. Friday's heuristics h1, h2, h5, h6, and `meeting-held-no-follow` fire most often here — these are the "did this conversation just die?" signals.
- **DISCO pipeline**: low-volume, slow-cycle. MEDDPICC scoring is the dominant signal. Friday surfaces these on the daily sweep when `Next Action Date` lapses or when a commitment goes overdue (h4).
- **MANAGE pipeline**: existing customers. Friday's job is to make sure you're not letting a wildly-successful customer drift away from you — different from prospect work.
- **NURTURE pipeline**: monthly cadence. The `follow-up-friday` weekly ritual is the main interaction surface for this pipeline — that's where stale NURTURE deals get a top-5 nudge.

## See also

- `sales-guide.md` — the user's canonical stage definitions and language.
- The Predictable Revenue book and blog: [predictablerevenue.com](https://predictablerevenue.com/).
