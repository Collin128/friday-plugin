# Installing Friday

A step-by-step install for the Friday Claude Cowork plugin.

## Prerequisites

- Claude Desktop with Cowork enabled.
- A Google account with Gmail, Calendar, and Drive.
- A Fireflies account (optional but recommended — Friday uses transcripts for meeting follow-ups and MEDDPICC signal).

## Step 1 — install the plugin in Cowork

> _Screenshot: `docs/screenshots/01-plugin-install.png` — TBD after first real install._

Open Claude Desktop. In the Cowork plugins panel, install the `friday` plugin. Cowork will pull the manifest from this repo (or from a marketplace listing once published) and register the twelve skills.

After install, you should see `friday-setup`, `friday-sweep`, `follow-up-friday`, `friday-review`, `friday-backfill`, and seven sub-skills (`friday-deals`, `friday-heuristics`, `friday-funnels`, `friday-meddpicc`, `friday-commitments`, `friday-draft`, `friday-sheet`) listed in the plugin's skill catalog.

## Step 2 — authorize the connectors

> _Screenshot: `docs/screenshots/02-connectors.png` — TBD._

In Claude Desktop, open Settings → Connectors. Authorize:

- **Gmail** — read access to your mailbox.
- **Google Calendar** — read access to your events.
- **Google Drive** — read AND write access. Friday writes to your CRM Sheet.
- **Fireflies** — read access to your meeting transcripts.

These are authorized at your Claude account level. The plugin does not redeclare them in a `.mcp.json` — it relies on your native account authorization.

If any of the four is missing, the corresponding signals are skipped. Friday will run with reduced coverage rather than failing.

## Step 3 — run the setup ritual

> _Screenshot: `docs/screenshots/03-setup.png` — TBD._

In Cowork, type the natural-language phrase (not a slash command):

> set up Friday

> **Don't type `/friday-setup`.** Cowork's slash invocation path is unreliable for plugin skills — it stalls silently or errors out. Cowork matches the skill's natural-language `description:` field, so plain phrasing is the reliable path. Other triggers that work: "install Friday", "get Friday going".

Claude will invoke `friday-setup`. The ritual:

1. **Opens the SHARED CRM Sheet template** in your browser. Click "Make a copy" — name your copy whatever you want; `Friday CRM` is a good default.
2. **Asks you to paste the new Sheet URL** back into the Cowork chat. Paste it.
3. **Verifies the six tabs exist** in your copy: MEET, DISCO, MANAGE, NURTURE, Triage, Activity Log.
4. **Runs `friday-backfill`** — walks 52 weeks of your Gmail / Calendar / Fireflies, seeding Triage with anything that looks like a missed opportunity. Takes 30–60 minutes. You can close Claude Desktop and come back; backfill resumes where it left off.
5. **Prints the two `/schedule` strings** at the end (see Step 4).

## Step 4 — paste the /schedule strings

> _Screenshot: `docs/screenshots/04-schedule.png` — TBD._

The setup ritual prints two recurring task definitions. Open Cowork's `/schedule` UI and paste each. They look like:

**Daily morning briefing:**

```
Frequency: daily
Time: 8:00 am   ← change to fit your morning
Folder: <the Drive folder containing your Friday Sheet>
Task: run friday-sweep using sheet <YOUR_SHEET_URL>
```

**Weekly Friday-morning ritual:**

```
Frequency: weekly
Day: Friday
Time: 9:00 am
Folder: <same folder>
Task: run follow-up-friday using sheet <YOUR_SHEET_URL>
```

Save each. From here on out, Friday runs daily.

## Step 5 — first morning

> _Screenshot: `docs/screenshots/05-first-briefing.png` — TBD._

Tomorrow morning at the time you set, Cowork fires `friday-sweep`. Open Claude Desktop and look at the Scheduled tasks page. You'll see something like:

```
Friday — morning briefing for 2026-05-23

🟡 Overdue today (3)
  • Acme — Drew Houston — DISCO 3 — Next action: send security questionnaire — 2 days overdue
  • Coalesce — Priya Patel — MEET 4 — Next action: send follow-up email — overdue today
  • Glean — Arvind Jain — DISCO 5 — Next action: nudge on contract — 5 days overdue

🆕 New candidates in Triage (4)
  Top 3 by confidence:
  • vendoroptimal.io — Maya Chen — h6 (pricing silence) — high
  • acme.com — Sara Bose — meeting-held-no-follow — high
  • coalesce.com — Priya Patel — h1 (unanswered outbound) — high
  (1 more in the Triage tab.)

🔄 Pipeline updates (2)
  • Applied: 1
  • Pending review: 1

→ Say "review Friday" to walk through it.
```

## Step 6 — walk it

Say `review Friday`. Claude invokes `friday-review` and walks you through each item — overdue rows first, then Triage candidates, then any low-confidence pending changes. For each item you can send/snooze/skip/graduate/dismiss. Typically takes 5–10 minutes.

Done. The Sheet is now in a coherent state. Tomorrow morning, the cycle repeats.

## Step 7 — the Friday ritual

Every Friday morning at the time you set (9 AM by default), `follow-up-friday` fires. You'll see a top-5 stale-deal nudge list with suggested reconnect drafts:

```
🟡 Follow-up Friday — 2026-05-22

5 deals went quiet. Top to bottom: most rescuable first.

1. Acme — Drew Houston — DISCO 4 — 34 days quiet — SCORE 14/16
   Subject: Q3 timing
   Drew, you mentioned wanting this in place before Q3 — is that still
   the target window? Happy to just close the thread if priorities moved.
   [send] [snooze 2w] [skip]

2. ...
```

Same `friday-review` flow to act on it.

## Troubleshooting

### "Backfill is taking forever"

Run a 90-day window first. Re-invoke `friday-setup` and when it asks about backfill, say "90 days only" — that takes ~5–10 minutes and is enough to dogfood the matching + heuristics.

### "Friday isn't picking up my latest email"

Cowork's catch-up rule: if Claude Desktop was closed at the scheduled trigger time, Cowork skips and runs *exactly one* catch-up on next wake. If you've been offline for more than a day, the catch-up runs with a 24-hour window. If you've been offline for more than 7 days, `friday-sweep` uses a 7-day window and surfaces "Friday was idle for N days — consider re-running `friday-backfill` if you want full coverage."

### "A column got renamed in my Sheet and now things are weird"

Friday refuses to write to a tab whose schema has drifted. It'll surface "Sheet schema mismatch on tab X" in the morning briefing. Either rename the column back, or update the schema in `friday-sheet/SKILL.md` to match your new column name.

### "Friday is matching the wrong person"

Use `friday-review` to fix it. For ambiguous matches (multiple rows could match a signal), Friday flags the Activity Log with `applied=N` and surfaces it in the review queue — you pick the right row, or merge the duplicate rows.

### "I want to test before pointing Friday at my real CRM"

Use a copy of the template as a test Sheet. Run a 90-day backfill against it. Spot-check 20 Triage rows. If the output matches your gut, swap the `/schedule` task to your real Sheet URL.

## Uninstalling

Remove the plugin in Cowork's plugins panel. Delete the two `/schedule` tasks. Your Sheet is yours to keep (or delete) — Friday wrote into it but the data is plain Sheet rows.
