---
name: friday-setup
description: |
  Use when the user says "set up Friday", installs the Friday plugin for
  the first time, or asks how to install Friday. Opens the SHARED CRM
  template, captures the new Sheet URL, runs friday-backfill, and prints
  the two /schedule strings the user needs to paste into Cowork.
---

# friday-setup

The one-time install ritual for Friday. Runs end-to-end in a single Cowork session.

## When to invoke

The user says any of:

- "set up Friday"
- "install Friday"
- "get Friday going"
- "how do I start with this plugin"

## Steps

### 1. Get the user a Sheet to work with

Two paths. Ask the user:

> "Do you have a copy of the SHARED CRM template, or should we set one up from scratch?"

**Path A — they have a template URL.** The author of this plugin maintains a SHARED CRM template; the link is:

> `<SHARED_CRM_TEMPLATE_URL>` *(placeholder — replace before any non-author install)*

Tell the user: "Click this link, then click Make a copy. Name your copy whatever you want — `Friday CRM` is a good default." Wait for them to paste the new Sheet URL.

**Path B — no template URL (first-time author dogfood, or template not yet shared).** Walk the user through creating a Sheet manually:

1. Open https://sheets.google.com and create a new blank Sheet. Name it `Friday CRM`.
2. Add six tabs named exactly: `MEET`, `DISCO`, `MANAGE`, `NURTURE`, `Triage`, `Activity Log`.
3. For each of MEET / DISCO / MANAGE / NURTURE, paste this header row in row 1 (use the exact column names from [[friday-sheet]] § Pipeline tabs):

   ```
   Company | MEDDPICC Score | Opp Stage | Next Action | Next Action Date | Name | Notes | Metric / M | Economic Decision Maker / E | Decision Criteria / DC | Decision Process / DP | Paper Process / P | Identified Pain / I | Champion / CH | Competition / CP | SCORE
   ```

4. For `Triage`, paste this header row:

   ```
   discovered_at | evidence_link | company | name | signal_kind | suggested_pipeline | suggested_next_action | confidence | status | decided_at
   ```

5. For `Activity Log`, paste this header row:

   ```
   timestamp | tab | row_company | row_name | action_kind | summary | evidence_link | applied | reverted_at
   ```

6. Paste the URL of the new Sheet back to Friday.

Either path ends with a Sheet URL captured. Validate it in step 2.

### 2. Capture the new Sheet URL

Ask the user to paste the new Sheet URL. Validate the URL shape:

- Must start with `https://docs.google.com/spreadsheets/d/`
- Must contain a Sheet ID (the path segment after `/d/`)

If the URL doesn't validate, ask once more. If still invalid, stop and tell the user "I couldn't recognize that as a Google Sheet URL — please paste the URL from the address bar with the Sheet open."

### 3. Verify Sheet structure

Use the Google Sheets connector to read the tab names from the new Sheet. Expected tabs: `MEET`, `DISCO`, `MANAGE`, `NURTURE`, `Triage`, `Activity Log` — see [[friday-sheet]] for the canonical schema.

If any of the six tabs is missing, tell the user which ones, then stop. Do not attempt to create the missing tabs — Friday never modifies Sheet structure.

If the Triage tab or Activity Log tab is empty (no header row), write the header row per the schema in [[friday-sheet]].

### 4. Run friday-backfill

Tell the user:

> "I'm now going to walk the last 52 weeks of your Gmail, Calendar, and Fireflies and seed Triage with anything that looks like a missed opportunity. This usually takes 30–60 minutes. Feel free to close Claude Desktop and come back — backfill will pick up where it left off if interrupted."

Then invoke [[friday-backfill]] with the captured Sheet URL.

When `friday-backfill` completes, it prints its own final summary (see [[friday-backfill]] § Output). The setup skill simply waits for that summary, then continues to step 5. If the user interrupts backfill (closes Claude Desktop, etc.), re-invoking `friday-setup` resumes from the last `backfill_week_complete` checkpoint — no data lost.

### 5. Print the two /schedule strings

The user needs to paste TWO recurring task definitions into Cowork's `/schedule` UI. Present them as copy-paste blocks:

```
/schedule  (daily morning briefing)

Frequency: daily
Time: 8:00 am   ← change to whatever fits your morning
Folder: <the Drive folder containing your Friday Sheet>
Task:
   run friday-sweep using sheet <PASTE_THE_USER_SHEET_URL_HERE>
```

```
/schedule  (weekly Friday-morning ritual)

Frequency: weekly
Day: Friday
Time: 9:00 am   ← change to whatever fits your Friday
Folder: <same folder as above>
Task:
   run follow-up-friday using sheet <PASTE_THE_USER_SHEET_URL_HERE>
```

Replace `<PASTE_THE_USER_SHEET_URL_HERE>` with the URL captured in step 2 — don't make the user re-paste.

Tell the user: "Paste each of these into Cowork's `/schedule` UI. Once both are saved, you're done. Your first daily briefing will land tomorrow morning at the time you set."

### 6. Confirm setup complete

Print a one-paragraph summary:

> "Friday is set up. Your Sheet is at `<sheet URL>`. The Triage tab has `<N>` candidates from the last 52 weeks for you to review — say 'review Friday' or run `friday-review` to walk through them. Your daily briefings start tomorrow morning."

## State written

- Activity Log header row (if absent before setup).
- Triage header row (if absent before setup).
- Everything `friday-backfill` writes during step 4.

## Output

The two `/schedule` strings + a one-paragraph "Friday is set up" summary.

## Failure modes

- **User pastes an invalid Sheet URL twice in a row** → stop, print "I couldn't recognize that as a Google Sheet URL. Open the Sheet in your browser, copy the URL from the address bar, and re-run `friday-setup`."
- **One of the six expected tabs is missing** → stop, print which tabs are missing, point the user back at the SHARED CRM template.
- **Google Drive connector not authorized** → tell the user "I don't see Google Drive authorized in your Claude account. Open Settings → Connectors and authorize Google Drive, then re-run `friday-setup`."
- **Backfill is interrupted (e.g. user closes Claude Desktop mid-step-4)** → on next invocation of `friday-setup`, detect existing Activity Log entries with `action_kind=backfill_week_complete` and offer to resume backfill instead of restarting.

## See also

- [[friday-sheet]] — canonical schema + write discipline
- [[friday-backfill]] — the 52-week walk invoked in step 4
- [[friday-sweep]] — daily orchestrator referenced in the `/schedule` string
- [[follow-up-friday]] — weekly Friday ritual referenced in the second `/schedule` string
