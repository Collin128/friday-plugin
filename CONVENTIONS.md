# CONVENTIONS.md

Filesystem layout, SKILL.md frontmatter rules, and skill body templates for the Friday plugin. Update whenever a convention changes.

## Filesystem layout

```
friday-plugin/
├── .claude-plugin/
│   └── plugin.json              manifest
├── CLAUDE.md                    discipline + milestone state
├── CONVENTIONS.md               this file
├── README.md                    user-facing landing (Phase 12)
├── LICENSE                      MIT
├── .gitignore
├── skills/
│   ├── friday-setup/SKILL.md
│   ├── friday-backfill/SKILL.md
│   ├── friday-sweep/SKILL.md
│   ├── follow-up-friday/SKILL.md
│   ├── friday-review/SKILL.md
│   ├── friday-funnels/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── four-funnels.md
│   │       └── sales-guide.md
│   ├── friday-meddpicc/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── meddpicc-rubric.md
│   ├── friday-heuristics/SKILL.md
│   ├── friday-deals/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── fixtures/
│   ├── friday-commitments/SKILL.md
│   ├── friday-draft/SKILL.md
│   └── friday-sheet/SKILL.md
├── commands/                    empty in v1
├── agents/                      empty in v1
└── docs/
    ├── INSTALL.md               (Phase 12)
    └── screenshots/             (Phase 12)
```

## SKILL.md frontmatter

Every SKILL.md starts with:

```yaml
---
name: friday-<thing>
description: |
  One-line trigger phrase the user might say, then a brief sentence about what
  this skill does. Used by Claude to decide when to invoke. Be specific.
---
```

Rules:
- `name` matches the directory name exactly. Kebab-case.
- `description` MUST mention either (a) the user-visible trigger ("run friday-sweep", "set up Friday"), or (b) the orchestrator skill that calls it ("called by friday-sweep when a stage transition is detected").
- If a sub-skill is only callable from another skill, the description says so explicitly so the model doesn't try to invoke it directly.

## Skill body — orchestrator template

For `friday-setup`, `friday-backfill`, `friday-sweep`, `follow-up-friday`, `friday-review`:

```markdown
# <Skill name>

<One paragraph: what this skill does, when it runs, what state it touches.>

## Inputs

<What the user provides, what the connector returns, what the Sheet looks like coming in.>

## Steps

1. <Concrete numbered step.>
2. ...

## State written

<What rows are added/modified in the Sheet. Always reference friday-sheet for write discipline.>

## Output

<What the scheduled-task page shows / what the user sees.>

## Failure modes

<Specific failure rows from the spec § "Error modes". One bullet per mode + what the skill does.>

## See also

- [[friday-sheet]] — schema + write discipline
- [[other sub-skill]] — why it's relevant
```

## Skill body — sub-skill template

For `friday-funnels`, `friday-meddpicc`, `friday-heuristics`, `friday-deals`, `friday-commitments`, `friday-draft`, `friday-sheet`:

```markdown
# <Skill name>

<One paragraph: what this codifies, who calls it.>

## When to invoke

<Trigger conditions. For sub-skills only callable from an orchestrator, say so.>

## Definitions / rules

<The actual content — stage definitions, scoring rubric, matching rules, etc.>

## Examples

<2-3 worked examples showing inputs and outputs.>

## References

<Pointers to bundled reference docs, if any.>
```

## Sheet write discipline (referenced from every skill that touches the Sheet)

Canonical statement lives in `skills/friday-sheet/SKILL.md`. Reminders:

- Never delete a row.
- Never overwrite `Company`, `Name`, or `Notes`. User-owned columns.
- Every Sheet write produces a corresponding Activity Log row with `timestamp`, `tab`, `row_company`, `row_name`, `action_kind`, `summary`, `evidence_link`, `applied`.
- Low-confidence updates: `applied=N`. They appear in `friday-review` but don't mutate the row until approved.
- `MAX(timestamp)` on Activity Log is the "last successful sweep" pointer — never a separate counter file.

## v1 is prompt-only

No Python helper scripts in v1. Cowork's local Linux VM makes scripts viable as a v1.1 lever if a specific skill drifts in real use (see plan § Tech stack).
