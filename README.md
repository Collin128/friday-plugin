# Friday

A [Claude Cowork](https://support.claude.com/en/articles/12012173-get-started-with-claude-cowork) plugin. Reads your Gmail, Calendar, and Fireflies transcripts every morning and maintains a personal CRM for you in a Google Sheet. You bring the deals — Friday tends them.

## What it does

Two jobs.

**Opportunity identification.** Each daily sweep, Friday asks: *who am I in conversation with that isn't yet in my pipeline?* When it finds someone — a question you asked that never got answered, a meeting you held but never followed up on, a thread that went silent after you sent a pricing nudge — it drops them in a Triage tab for you to graduate into MEET or NURTURE, dismiss, or snooze.

**Follow-up reminders.** Friday watches every row already in your Sheet. If `Next Action Date` lapses, the row surfaces. If you committed to sending something three weeks ago and haven't, the row surfaces. If a NURTURE contact has gone untouched for a month, the row surfaces. Each morning you open Claude Desktop and see exactly what needs attention today.

**And one more — the Friday ritual.** Every Friday morning a separate scheduled task fires `follow-up-friday`: a focused, five-deal nudge list of the warm deals that have gone quietly cold (no touches in > 30 days), ranked by MEDDPICC score so the most rescuable ones rise to the top. Each pick comes with a suggested reconnect draft.

## How it works

Friday is a Claude Cowork plugin — twelve composable skills plus reference docs. State lives entirely in your Google Sheet (the scheduled-task session is fresh each run; nothing relies on in-session memory). Native first-party connectors only — Gmail, Google Calendar, Fireflies, Google Drive — authorized once at the Claude account level. No backend, no accounts, no shared infrastructure.

```
USER'S MACHINE (Cowork on Claude Desktop)

  /schedule (daily preset, fresh session per run)
       │
       ▼
  friday-sweep ─────► reads Sheet ─────────────► Google Sheets (your Drive)
       │                                              ▲
       │ via native connectors                        │ writes pipeline updates +
       ▼                                              │ Activity Log + Triage rows
  Gmail / Calendar / Fireflies                        │
       │                                              │
       ▼                                              │
  friday-deals  ──► match signal to row              │
  friday-heuristics ── new candidates ──────────────►│
  friday-funnels ── stage suggestions ──────────────►│
  friday-meddpicc ── score updates ─────────────────►│
  friday-commitments ── overdue reminders ──────────►│
       │
       ▼
  Cowork "Scheduled tasks" page  ◄────  you open Claude Desktop in the morning
       │
       ▼
  you invoke friday-review (interactive walk through today's actions)
```

## Install

See [`docs/INSTALL.md`](docs/INSTALL.md) for the full walk-through with screenshots. Quick install — pick the path that matches where you're installing from.

### Claude Code (CLI) — install from the marketplace

This repo doubles as its own marketplace via `.claude-plugin/marketplace.json`. Two commands:

```shell
/plugin marketplace add Collin128/friday-plugin
/plugin install friday@collin128-friday
```

Then `/reload-plugins` (or restart) to activate. See the [Claude Code plugin-marketplaces docs](https://code.claude.com/docs/en/plugin-marketplaces) for marketplace mechanics.

### Claude Cowork — install via the plugins panel

In Claude Desktop's Cowork tab → **Customize** → **Browse plugins** → use the "add custom plugin" / "from URL" flow and point at:

```
https://github.com/Collin128/friday-plugin
```

Cowork will register the marketplace and let you install Friday. See the [Cowork plugins help article](https://support.claude.com/en/articles/13837440-use-plugins-in-claude-cowork) for the current UI flow.

### Local development (edit SKILL.md files in place)

Clone, add the marketplace by local path:

```bash
git clone https://github.com/Collin128/friday-plugin.git ~/web/friday-plugin
```

Then in Claude Code:

```shell
/plugin marketplace add ~/web/friday-plugin
/plugin install friday@collin128-friday
```

Edits to `skills/<name>/SKILL.md` show up after `/reload-plugins`.

### After install (any path)

1. Authorize Gmail, Google Calendar, Fireflies, and Google Drive in your Claude account (Settings → Connectors). Drive needs WRITE access.
2. In Cowork, say `set up Friday`.
3. Follow the prompts: pick "have a template URL" or "set up from scratch" (Path B walks you through making the Sheet manually), paste your Sheet URL, wait for backfill, paste the two `/schedule` strings.
4. Open Claude Desktop tomorrow morning. Your first briefing will be on the Scheduled tasks page.

## The Sheet

Friday operates on a six-tab Google Sheet:

- **MEET** / **DISCO** / **MANAGE** / **NURTURE** — your four pipelines. You own `Company`, `Name`, and `Notes`. Friday writes `Next Action`, `Next Action Date`, `Opp Stage`, the eight MEDDPICC dimensions, and `SCORE`.
- **Triage** — Friday-managed queue of new candidates for you to graduate, dismiss, or snooze.
- **Activity Log** — append-only audit trail. Every change Friday writes (or suggests) has one row here with `evidence_link` back to the email, calendar event, or transcript that justified it.

Schema details and write discipline live in `skills/friday-sheet/SKILL.md`.

## Skills

| Skill | Role |
|---|---|
| `friday-setup` | One-time install ritual — Sheet copy, /schedule strings. |
| `friday-backfill` | Sequential 52-week walk through Gmail / Calendar / Fireflies. |
| `friday-sweep` | Daily reactive sweep. Fires from `/schedule`. |
| `follow-up-friday` | Weekly Friday-morning ritual — top 5 stale-deal nudges. |
| `friday-review` | Interactive walk-through; the only place pending changes get applied. |
| `friday-funnels` | Four pipelines + stage taxonomies + transition rules. |
| `friday-meddpicc` | 0/1/2 scoring rubric per dimension. |
| `friday-heuristics` | Opportunity-ID rules h1–h6 + meeting-held-no-follow + noise filters. |
| `friday-deals` | Signal → row matching (entity resolution). |
| `friday-commitments` | iWill / theyWill / followupBy extraction from outbound + transcripts. |
| `friday-draft` | Three follow-up archetypes + the 8 writing invariants. |
| `friday-sheet` | Canonical schema + write discipline (consulted by every other skill). |

Each lives in `skills/<name>/SKILL.md`. Reference docs in `skills/<name>/references/`.

## Conventions

See [`CONVENTIONS.md`](CONVENTIONS.md) for filesystem layout, SKILL.md frontmatter format, and skill body templates. See [`CLAUDE.md`](CLAUDE.md) for the discipline (one PR per phase, prompt-only v1, don't bundle).

## Testing — honest gaps

**No automated test suite in v1.** Reasons:

- Cowork's native Gmail / Calendar / Fireflies connectors don't have a usable sandbox or fixture mode that a plugin can hook into.
- Real-account testing is the only way to validate matching + heuristics end-to-end.

What *is* in place:

- Sub-skills with branching logic (`friday-deals`, `friday-heuristics`, `friday-commitments`) ship with fixture files under `skills/<skill>/references/fixtures/` and a `how-to-exercise.md` walking you through manual tests against a sandbox Sheet.
- The plugin was dogfooded against the author's own Cowork install with a 90-day backfill + spot-check of 20 Triage rows before any public release.

If you find a behavior that drifts from the documented intent, please open an issue. v1 has no test coverage — every bug report is informative.

## Future work (deferred from v1)

- **Batched parallel backfill.** Sequential 52-week takes 30–60 minutes. If that's consistently slow, a `friday-week-scanner` sub-agent in `agents/` is the next lever.
- **Python helper scripts** for deterministic helpers (entity resolution branching, composite-score math, top-5 ranking). Cowork's local Linux VM makes these viable; v1 is prompt-only to keep one surface per skill.
- **Per-deal commentary memory.** Wrap the plugin in a Cowork *project* so memory persists across sessions; have `friday-sweep` build per-deal qualitative context. Requires opting into project memory.
- **Mobile push.** Cowork's mobile feature could let you trigger `friday-review` from your phone.
- **Sentiment / red-flag detection.** Look for "going dark" signals beyond date-based decay — tone shifts, slower replies, missed meetings.

## References

- [Get started with Claude Cowork](https://support.claude.com/en/articles/12012173-get-started-with-claude-cowork)
- [Schedule recurring tasks in Claude Cowork](https://support.claude.com/en/articles/13854387-schedule-recurring-tasks-in-claude-cowork)
- [Use plugins in Claude Cowork](https://support.claude.com/en/articles/13837440-use-plugins-in-claude-cowork)
- [Plugins reference (manifest, skills, commands, agents, hooks)](https://code.claude.com/docs/en/plugins-reference)
- [The $500M MEDDPICC secrets revealed (Predictable Revenue)](https://predictablerevenue.com/blog/500m-meddpicc-secrets-revealed-how-zendesk-is-able-to-forecast-revenue-within-1)

## License

MIT. See [`LICENSE`](LICENSE).
