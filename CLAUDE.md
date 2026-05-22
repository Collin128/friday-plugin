# CLAUDE.md

> Auto-loaded brief for AI sessions on this repo. Keep it short.

## What this is

Friday — a Claude Cowork plugin. Reads the user's Gmail + Calendar + Fireflies each morning, maintains a personal CRM in a Google Sheet. Ports the worker logic of the FollowUp web app (in the user's `nurture` repo) into a Cowork-native plugin.

## Active milestone — v1 (per-PR rollout)

Decided 2026-05-22: one PR per phase, single commit per PR. Twelve phases. Don't bundle.

- Plan: `docs/superpowers/plans/2026-05-22-friday-cowork-plugin.md` (lives in the source `nurture` repo, not here).
- Per-phase progress: tracked in the source repo's `implementation-notes.html`.
- Source spec: `nurture` repo `docs/superpowers/specs/2026-05-22-friday-cowork-plugin-design.md`.

When a phase ships:
1. Open the PR; squash to a single commit at merge.
2. Update `implementation-notes.html` in the source repo.
3. Stop. Don't pull the next phase forward.

## Repo orientation

- `.claude-plugin/plugin.json` — manifest.
- `skills/<name>/SKILL.md` — one per skill; markdown with YAML frontmatter.
- `skills/<name>/references/` — bundled reference docs (Sales Guide, MEDDPICC rubric, fixtures).
- `commands/`, `agents/` — empty in v1; reserved.
- `CONVENTIONS.md` — filesystem layout, frontmatter rules, skill body templates.
- `docs/INSTALL.md` — end-user install steps (lands in Phase 12).

## Skills cheat sheet

| Skill | Role | Phase |
|---|---|---|
| `friday-setup` | One-time install ritual | 2 |
| `friday-backfill` | Sequential 52-week walk | 6 |
| `friday-sweep` | Daily orchestrator | 7 |
| `follow-up-friday` | Weekly stale-deal top-5 | 8 |
| `friday-review` | Interactive review walk-through | 10 |
| `friday-funnels` | Pipeline stage taxonomies + transitions | 3 |
| `friday-meddpicc` | MEDDPICC scoring rubric | 3 |
| `friday-heuristics` | Opportunity-ID rules h1–h6 + noise filters | 5 |
| `friday-deals` | Signal → row matching (entity resolution) | 4 |
| `friday-commitments` | iWill / theyWill extraction | 5 |
| `friday-draft` | 3 archetypes + 8 writing invariants | 9 |
| `friday-sheet` | Canonical schema + write discipline | 2 |

## Execution discipline ("go slow and build this correctly")

Inherited from the source repo. In practice:

1. **Plan before code.** Per-phase plans are in the source repo's plan doc. Ground them against the spec (the spec is the source of truth — re-read it before each phase).
2. **Stay narrow.** Don't add features, refactors, abstractions, retries, error handling, or "improvements" beyond what the phase requires. Three similar lines is better than a premature abstraction.
3. **Verify before claiming done.** Each phase has a `Manual test` task. Run it before commit. A skill that "looks right in markdown" hasn't been verified — exercise it in Cowork.
4. **Confirm before shared-state actions.** A user approving a push or PR on one phase is not approval for the next. Push, PR creation, force-push, branch deletion — confirm first unless explicitly authorized for the current scope.

If you catch yourself rationalizing "just this once" against any of the above, that thought is the signal to stop and re-read this section.

## Branch + commit conventions

- Branch name: `phase-N-<short-noun>`, under 30 chars (e.g. `phase-2-sheet-setup`).
- Commit subject: `<type>(<scope>): present-tense subject under 70 chars`. Same style as the source repo's git log (`feat(plugin): ...`, `docs(skill): ...`).
- Body: one paragraph for the why, one paragraph for the what.
- Always `Co-Authored-By: Claude <noreply@anthropic.com>`.

## When in doubt

Re-read `CONVENTIONS.md`. Re-read the most recent merged PR. Match the pattern.
